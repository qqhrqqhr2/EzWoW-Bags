local _, ns = ...
local frame = CreateFrame("Frame")
local events = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "BAG_UPDATE_DELAYED", "BAG_UPDATE", "ITEM_LOCK_CHANGED",
    "GET_ITEM_INFO_RECEIVED", "PLAYER_MONEY", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BAG_CONTAINER_UPDATE", "BANK_TABS_CHANGED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_ITEM_LIST_UPDATE", "REPLICATE_ITEM_LIST_UPDATE",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_COOLDOWN",
    "QUEST_ACCEPTED", "QUEST_REMOVED" }
for _, event in ipairs(events) do pcall(frame.RegisterEvent, frame, event) end
-- Default bag replacement. The Blizzard bag functions are never replaced (other default UI code
-- calls them); they are post-hooked, and the default player bag frames hide themselves on show.
-- Post-hooks of nested calls run before the outer one, so the hooks only record what happened and
-- the last (outermost) call of the same frame decides once on the next update: B, Shift+B and
-- the bag buttons toggle this window exactly once even when the default code opens bags internally.
local bagHook = { pending = nil, openedBy = nil, combatPending = false }
local function inCombat() return InCombatLockdown and InCombatLockdown() end
local function locked(f) return inCombat() and type(f.IsProtected) == "function" and f:IsProtected() end
local function frameToken(f)
    if type(f) ~= "table" then return nil end
    local name = type(f.GetName) == "function" and f:GetName()
    return name or f
end
local function resolveBagHook(self)
    self:SetScript("OnUpdate", nil)
    local p = bagHook.pending; bagHook.pending = nil
    local w = ns.window
    -- ns.Show/ns.Hide wait for the end of combat when the window is protected.
    if not p or not ns.cfg.replace or not w then return end
    if p.kind == "toggle" then
        bagHook.openedBy = nil
        if p.wasShown then ns.Hide() else ns.Show("bags") end
    elseif p.kind == "open" then
        -- Same rule as the default UI: only an opener that found the bags closed may close them again.
        if not w:IsShown() then bagHook.openedBy = p.source; ns.Show("bags") end
    elseif p.kind == "close" then
        local owner = bagHook.openedBy
        if p.source and owner ~= true and owner ~= p.source then return end
        bagHook.openedBy = nil
        ns.Hide()
    end
end
local resolver = CreateFrame("Frame")
-- Default bag frames opened on purpose from this window's bag buttons: left open until they close.
local allowed = {}
local function noteBagCall(kind, source)
    if bagHook.allow or not ns.cfg.replace or not ns.window then return end
    local p = bagHook.pending
    if not p then
        p = { wasShown = ns.window:IsShown() }; bagHook.pending = p
        resolver:SetScript("OnUpdate", resolveBagHook)
    end
    p.kind, p.source = kind, source
end
-- Player bags 0-4 and the reagent bag. On the old bank layout bag 5 is a bank bag, so it is left alone there.
local function playerBag(id)
    if type(id) ~= "number" then return false end
    if id >= 0 and id <= 4 then return true end
    return id == ns.API.ReagentBag() and ns.API.ModernBank() and true or false
end
local function blizzardBagID(f)
    local fn = f.GetBagID or f.GetID
    if type(fn) ~= "function" then return nil end
    local ok, id = pcall(fn, f)
    return ok and id or nil
end
local function isPlayerBagFrame(f)
    return f == _G.ContainerFrameCombinedBags or playerBag(blizzardBagID(f))
end
local function suppressBlizzardBag(f)
    if bagHook.allow then allowed[f] = true; return end
    if allowed[f] then return end
    if not ns.cfg.replace or not f:IsShown() or not isPlayerBagFrame(f) then return end
    -- Container frames are normally not protected; if one is, wait until combat ends.
    if locked(f) then bagHook.combatPending = true; return end
    f:Hide()
    return true
end
local function blizzardBagFrames()
    local list = {}
    if _G.ContainerFrameCombinedBags then list[#list + 1] = _G.ContainerFrameCombinedBags end
    for i = 1, math.max(tonumber(NUM_CONTAINER_FRAMES) or 0, 13) do
        local f = _G["ContainerFrame" .. i]
        if f then list[#list + 1] = f end
    end
    return list
end
-- Called at login, when the option changes and after combat. With handOver, default bags that had
-- to stay open during combat are replaced by this window.
function ns.ApplyBagReplacement(handOver)
    bagHook.combatPending = false
    if not ns.cfg.replace then
        bagHook.pending, bagHook.openedBy = nil, nil; resolver:SetScript("OnUpdate", nil)
        return
    end
    local hidden = false
    for _, f in ipairs(blizzardBagFrames()) do hidden = suppressBlizzardBag(f) or hidden end
    if handOver and hidden and ns.window and not ns.window:IsShown() and not locked(ns.window) then ns.Show("bags") end
end
local function replaceBags()
    local function hook(name, handler)
        if type(_G[name]) == "function" then pcall(hooksecurefunc, name, handler) end
    end
    hook("ToggleBag", function(id) if playerBag(id) then noteBagCall("toggle") end end)
    hook("ToggleBackpack", function() noteBagCall("toggle") end)
    hook("ToggleAllBags", function() noteBagCall("toggle") end)
    hook("OpenBackpack", function(f) noteBagCall("open", frameToken(f)) end)
    hook("OpenAllBags", function(f) noteBagCall("open", frameToken(f)) end)
    hook("CloseBackpack", function(f) noteBagCall("close", frameToken(f)) end)
    hook("CloseAllBags", function(f) noteBagCall("close", frameToken(f)) end)
    for _, f in ipairs(blizzardBagFrames()) do
        if type(f.HookScript) == "function" then
            pcall(f.HookScript, f, "OnShow", suppressBlizzardBag)
            pcall(f.HookScript, f, "OnHide", function(self) allowed[self] = nil end)
        end
    end
    ns.ApplyBagReplacement()
end
-- Opens (or closes) one bag in the default bag frame, even while this window replaces the default bags.
function ns.ToggleBlizzardBag(bag)
    if type(bag) ~= "number" or type(ToggleBag) ~= "function" then return false end
    bagHook.allow = true
    local ok
    if bag == ns.API.Keyring() and type(ToggleKeyRing) == "function" then ok = pcall(ToggleKeyRing)
    else ok = pcall(ToggleBag, bag) end
    bagHook.allow = nil
    return ok
end
local function tooltips()
    GameTooltip:HookScript("OnTooltipCleared", function(tip) ns.ClearTooltipItem(tip) end)
    local function secret(value) return issecretvalue and issecretvalue(value) end
    local function append(tip, data)
        -- Mainline passes tooltip data; tip:GetItem() may be missing on this client.
        local id = type(data) == "table" and not secret(data.id) and tonumber(data.id) or nil
        if not id and type(tip.GetItem) == "function" then
            local ok, _, link = pcall(tip.GetItem, tip)
            if ok and type(link) == "string" and not secret(link) then id = tonumber(link:match("item:(%d+)")) end
        end
        if id then ns.AddTooltipInfo(tip, id) end
    end
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip, data) if tip == GameTooltip then append(tip, data) end end)
    else pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", append) end
end
local function init()
    ns.InitDB()
    ns.History.Init()
    ns.Auction.SyncPrices()
    ns.ScanStorage("bags")
    ns.CreateWindow()
    if ns.cfg.position and #ns.cfg.position == 4 then
        local p = ns.cfg.position
        ns.window:ClearAllPoints(); ns.window:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    elseif ns.cfg.growUp then
        ns.window:ClearAllPoints(); ns.window:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -40, 100)
    end
    replaceBags(); tooltips(); ns.Auction.InstallHook()
    SLASH_EZWOWBAGS1, SLASH_EZWOWBAGS2 = "/ezbags", "/ezb"
    SlashCmdList.EZWOWBAGS = function(text)
        text = (text or ""):lower():match("^%s*(.-)%s*$")
        if text == "settings" then ns.ToggleOptions()
        elseif text == "bank" then ns.Show("bank")
        elseif text == "scan" then ns.Auction.Start("full")
        elseif text == "debug" then
            local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
            local ok, version = false, nil
            if type(getMeta) == "function" then ok, version = pcall(getMeta, ns.name, "Version") end
            ns.Print((ok and version or "?") .. " · bank=" .. (ns.API.ModernBank() and "tabs" or "legacy") .. " · keyring=" .. ns.API.Keyring()
                .. " · legacyAH=" .. tostring(type(QueryAuctionItems) == "function")
                .. " · replicate=" .. tostring(C_AuctionHouse and type(C_AuctionHouse.ReplicateItems) == "function" or false)
                .. " · nativeRows=" .. ns.Auction.NativeCount())
            ns.Print(ns.Auction.status or "—")
            local job = ns.Auction.job
            if job then ns.Print("waiting=" .. tostring(job.waiting) .. " · reading=" .. tostring(job.reading) .. " · index=" .. tostring(job.index) .. "/" .. tostring(job.count) .. " · retries=" .. tostring(job.retryPass)) end
        else ns.Toggle() end
    end
    ns.ready = true
    ns.WarmSecureSlots("bags")
end
frame:SetScript("OnEvent", function(_, event, arg, success)
    if event == "PLAYER_LOGIN" then init(); return end
    if not ns.ready then return end
    if event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED"
        or event == "PLAYERBANKSLOTS_CHANGED" or event == "BAG_CONTAINER_UPDATE" or event == "BANK_TABS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"
        or event == "QUEST_ACCEPTED" or event == "QUEST_REMOVED" then
        ns.Dirty()
        -- A new or bigger bag (or bank tab) needs more item buttons; built out of combat.
        if event == "BAG_CONTAINER_UPDATE" or event == "BANK_TABS_CHANGED" then
            ns.WarmSecureSlots("bags"); ns.WarmSecureSlots("bank")
        end
    elseif event == "BAG_UPDATE_COOLDOWN" then ns.viewDirty = true
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        if success ~= false then
            ns.PriceCatalog.MetadataReady(arg)
            if ns.waitingInventory[arg] then ns.waitingInventory[arg] = nil; ns.Dirty() end
            if ns.visiblePriceWaiting and ns.visiblePriceWaiting[arg] then ns.visiblePriceWaiting[arg] = nil; ns.viewDirty = true end
        end
    elseif event == "PLAYER_MONEY" then
        local char = ns.db.characters[ns.player]; if char then char.money = GetMoney() end; ns.Refresh()
    elseif event == "BANKFRAME_OPENED" then
        local wasShown = ns.window:IsShown()
        -- the window stays on the tab it shows (bags, bank or prices); the bank tab is
        -- one click away. Opened by the bank itself, it starts on the tab used last.
        ns.state.bank = true; ns.ScanStorage("bank"); ns.WarmSecureSlots("bank")
        if wasShown then ns.Refresh() else ns.Show() end
        -- Opened for the bank: closing the bank (with any frame argument) closes it again.
        if ns.cfg.replace and not wasShown then bagHook.openedBy = true end
    elseif event == "BANKFRAME_CLOSED" then
        -- Never rescan now: bank APIs may already return zero slots after the close event.
        ns.state.bank = false; ns.moveQueue = nil; ns.Refresh()
    elseif event == "AUCTION_HOUSE_SHOW" then ns.state.auction = true; ns.Refresh()
    elseif event == "AUCTION_HOUSE_CLOSED" then ns.state.auction = false; ns.Auction.replicaReady = nil; ns.Auction.Stop()
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then ns.Auction.Results(false)
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then ns.Auction.Results(true)
    elseif event == "PLAYER_REGEN_DISABLED" then ns.moveQueue = nil; ns.Refresh()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if bagHook.combatPending then ns.ApplyBagReplacement(true) end
        ns.AfterCombat()
        ns.WarmSecureSlots("bags"); ns.WarmSecureSlots("bank")
    elseif event == "PLAYER_LOGOUT" then ns.ScanStorage("bags"); if ns.state.bank then ns.ScanStorage("bank") end
    elseif event == "MERCHANT_SHOW" then ns.state.merchant = true; ns.Merchant.OnShow()
    elseif event == "MERCHANT_CLOSED" then ns.state.merchant = false; ns.Merchant.OnClosed(); ns.moveQueue = nil; ns.Refresh()
    elseif event == "MAIL_SHOW" then ns.state.mail = true
    elseif event == "MAIL_CLOSED" then ns.state.mail = false; ns.moveQueue = nil; ns.Refresh()
    elseif event == "TRADE_SHOW" then ns.state.trade = true
    elseif event == "TRADE_CLOSED" then ns.state.trade = false; ns.moveQueue = nil; ns.Refresh() end
end)
local elapsed, scanElapsed, shareElapsed = 0, 0, 0
frame:SetScript("OnUpdate", function(_, dt)
    if not ns.ready then return end
    elapsed, scanElapsed, shareElapsed = elapsed + dt, scanElapsed + dt, shareElapsed + dt
    ns.PriceCatalog.Tick()
    ns.History.Tick()
    if ns.priceScrollDirty then ns.priceScrollDirty = false; ns.Refresh() end
    if ns.Auction.syncWork then ns.Auction.SyncPrices(); shareElapsed = 0
    elseif shareElapsed >= 1 then shareElapsed = 0; ns.Auction.SyncPrices() end
    if elapsed >= .15 then
        elapsed = 0
        ns.TickMove()
        if ns.dirty then
            ns.dirty = false; ns.ScanStorage("bags")
            if ns.state.bank then ns.ScanStorage("bank") end
            ns.viewDirty = true
        end
        if ns.viewDirty then ns.viewDirty = false; ns.Refresh() end
    end
    if scanElapsed >= .1 then scanElapsed = 0; ns.Auction.Tick() end
end)
ns.eventFrame = frame
