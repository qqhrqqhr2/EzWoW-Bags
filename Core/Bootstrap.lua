local addon, ns = ...
_G.EzWoW_Bags = ns
ns.name = addon
ns.defaults = {
    replace = true, columns = 12, sectionColumns = 2, size = 30,
    scale = 1, opacity = .96, view = "sections", merge = true,
    itemLevel = true, labels = true, emptySlots = false, newSection = false,
    itemSort = "name", sectionSort = "name", growUp = false,
    language = "auto", categories = {}, custom = {}, assignments = {},
    autoSellJunk = true, autoRepair = true,
    -- Auction house helpers
    ahSell = true, ahUndercutMode = "copper", ahUndercutCopper = 1, ahUndercutPercent = 1,
    ahBuyPanel = true, ahPriceTab = true, historyDays = 60, tooltipTrend = true,
    itemLock = true,
}
ns.state = { bank = false, auction = false, merchant = false, mail = false, trade = false }
ns.newItems, ns.seen = {}, {}

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = ns.Copy(v) end
    return out
end

-- EzWoW-Tooltip's saved item options for this character (its per-character profile when used).
function ns.TooltipMerchantSettings()
    local global = type(EzWoW_TooltipDB) == "table" and EzWoW_TooltipDB or nil
    if not global then return nil end
    local item = type(global.item) == "table" and global.item or {}
    local perChar = type(EzWoW_TooltipPerCharDB) == "table" and EzWoW_TooltipPerCharDB or nil
    if perChar and type(global.general) == "table" and global.general.SavedVariablesPerCharacter
        and type(perChar.item) == "table" then
        local merged = {}
        for k, v in pairs(item) do merged[k] = v end
        for k, v in pairs(perChar.item) do merged[k] = v end
        return merged
    end
    return item
end

function ns.InitDB()
    local db = type(EzWoW_BagsDB) == "table" and EzWoW_BagsDB or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    for k, v in pairs(ns.defaults) do
        if type(db.settings[k]) ~= type(v) then db.settings[k] = ns.Copy(v) end
    end
    for _, key in ipairs({ "characters", "markets", "history", "locks" }) do
        if type(db[key]) ~= "table" then db[key] = {} end
    end
    local s = db.settings
    local function clamp(k, lo, hi)
        local n = tonumber(s[k])
        if not n or n ~= n then n = ns.defaults[k] end
        s[k] = math.max(lo, math.min(hi, n))
    end
    clamp("columns", 6, 20); clamp("sectionColumns", 1, 3); clamp("size", 28, 56)
    clamp("scale", .65, 1.4); clamp("opacity", .4, 1)
    s.columns, s.sectionColumns, s.size = math.floor(s.columns), math.floor(s.sectionColumns), math.floor(s.size)
    clamp("ahUndercutCopper", 0, 10000000); clamp("ahUndercutPercent", 0, 50); clamp("historyDays", 30, 120)
    s.ahUndercutCopper, s.historyDays = math.floor(s.ahUndercutCopper), math.floor(s.historyDays)
    if s.ahUndercutMode ~= "copper" and s.ahUndercutMode ~= "percent" then s.ahUndercutMode = "copper" end
    if s.view ~= "sections" and s.view ~= "grid" and s.view ~= "list" then s.view = "sections" end
    if (db.version or 1) < 2 and ns.API.ModernBank() then
        for _, char in pairs(db.characters) do
            if char.bank then char.legacyBank, char.bank = char.bank, nil end
        end
    end
    db.version = 2
    -- One time: auto-sell and auto-repair used to be EzWoW-Tooltip options. Keep a choice made there.
    if not db.merchantMigrated then
        db.merchantMigrated = true
        local old = ns.TooltipMerchantSettings()
        for _, key in ipairs({ "autoSellJunk", "autoRepair" }) do
            if old and type(old[key]) == "boolean" then s[key] = old[key] end
        end
    end
    EzWoW_BagsDB, ns.db, ns.cfg = db, db, s
    ns.realm = GetRealmName()
    local first = UnitName("player")
    local name = ns.API.PlayerName()
    ns.player = name .. " - " .. ns.realm
    local guid = UnitGUID and UnitGUID("player")
    local oldKey = first .. " - " .. ns.realm
    -- Keep the old bank snapshot when upgrading from first-name-only keys.
    local old = db.characters[oldKey]
    if oldKey ~= ns.player and old and not db.characters[ns.player] and (not old.guid or old.guid == guid) then
        db.characters[ns.player], db.characters[oldKey] = old, nil
    end
    if guid then
        for key, char in pairs(db.characters) do
            if key ~= ns.player and char.guid == guid and not db.characters[ns.player] then
                db.characters[ns.player], db.characters[key] = char, nil
                break
            end
        end
    end
    ns.market = ns.realm .. ":" .. (UnitFactionGroup("player") or "Unknown")
    ns.selected, ns.storage = ns.player, "bags"
    ns.baselineUntil = GetTime() + 5
end

function ns.Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff72dbbeEzWoW Bags|r " .. tostring(message)) end
end

function ns.Money(value)
    value = math.floor(value or 0)
    local gold, silver, copper = math.floor(value / 10000), math.floor(value / 100) % 100, value % 100
    local function coin(number, kind)
        return number .. "|TInterface\\MoneyFrame\\UI-" .. kind .. "Icon:12:12:2:0|t"
    end
    return (gold > 0 and (coin(gold, "Gold") .. "  ") or "") .. coin(silver, "Silver") .. "  " .. coin(copper, "Copper")
end

-- Two coin units at most (gold+silver, silver+copper or copper), zero parts left out.
function ns.MoneyShort(value, size)
    value = math.floor(math.max(0, tonumber(value) or 0) + .5)
    size = size or 11
    local gold, silver, copper = math.floor(value / 10000), math.floor(value / 100) % 100, value % 100
    local function coin(number, kind)
        return number .. "|TInterface\\MoneyFrame\\UI-" .. kind .. "Icon:" .. size .. ":" .. size .. ":1:0|t"
    end
    local parts = {}
    if gold > 0 then
        parts[1] = coin(gold, "Gold")
        if silver > 0 then parts[2] = coin(silver, "Silver") end
    elseif silver > 0 then
        parts[1] = coin(silver, "Silver")
        if copper > 0 then parts[2] = coin(copper, "Copper") end
    else parts[1] = coin(copper, "Copper") end
    return table.concat(parts, " ")
end

function ns.Refresh()
    if ns.rendering then ns.viewDirty = true; return end
    if ns.window and ns.window:IsShown() then
        ns.rendering = true
        local ok, err = pcall(ns.Render)
        ns.rendering = false
        if not ok then error(err) end
    end
end

function ns.Dirty()
    ns.dirty = true
end
