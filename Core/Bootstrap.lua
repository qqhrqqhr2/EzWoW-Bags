local addon, ns = ...
_G.EzWoW_Bags = ns
ns.name = addon
ns.defaults = {
    replace = true, columns = 12, sectionColumns = 2, size = 30,
    scale = 1, opacity = .96, view = "sections", merge = true,
    itemLevel = true, labels = true, emptySlots = false, newSection = false,
    itemSort = "name", sectionSort = "name", growUp = false,
    language = "auto", categories = {}, custom = {}, assignments = {},
}
ns.state = { bank = false, auction = false, merchant = false, mail = false, trade = false }
ns.newItems, ns.seen = {}, {}

function ns.Copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for k, v in pairs(value) do out[k] = ns.Copy(v) end
    return out
end

function ns.InitDB()
    local db = type(EzWoW_BagsDB) == "table" and EzWoW_BagsDB or {}
    db.settings = type(db.settings) == "table" and db.settings or {}
    for k, v in pairs(ns.defaults) do
        if type(db.settings[k]) ~= type(v) then db.settings[k] = ns.Copy(v) end
    end
    for _, key in ipairs({ "characters", "markets" }) do
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
    if s.view ~= "sections" and s.view ~= "grid" and s.view ~= "list" then s.view = "sections" end
    if (db.version or 1) < 2 and ns.API.ModernBank() then
        for _, char in pairs(db.characters) do
            if char.bank then char.legacyBank, char.bank = char.bank, nil end
        end
    end
    db.version = 2
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
