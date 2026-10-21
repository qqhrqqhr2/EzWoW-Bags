local _, ns = ...
local frame = CreateFrame("Frame")
local events = { "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "BAG_UPDATE_DELAYED", "BAG_UPDATE", "ITEM_LOCK_CHANGED",
    "GET_ITEM_INFO_RECEIVED", "PLAYER_MONEY", "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "PLAYERBANKSLOTS_CHANGED", "BAG_CONTAINER_UPDATE", "BANK_TABS_CHANGED",
    "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_ITEM_LIST_UPDATE", "REPLICATE_ITEM_LIST_UPDATE",
    "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED", "TRADE_SHOW", "TRADE_CLOSED", "PLAYER_REGEN_DISABLED", "PLAYER_EQUIPMENT_CHANGED", "BAG_UPDATE_COOLDOWN" }
for _, event in ipairs(events) do pcall(frame.RegisterEvent, frame, event) end
local function replaceBags()
    if not ns.cfg.replace then return end
    -- Keep originals for non-player containers and callers explicitly targeting other bags.
    local originalToggle = ToggleBag
    ToggleBag = function(id, ...)
        if ns.API.IsPlayerBag(id) then ns.Toggle()
        elseif originalToggle then return originalToggle(id, ...) end
    end
    for _, name in ipairs({ "ToggleBackpack", "ToggleAllBags" }) do
        if type(_G[name]) == "function" then _G[name] = function() ns.Toggle() end end
    end
    for _, name in ipairs({ "OpenBackpack", "OpenAllBags" }) do
        if type(_G[name]) == "function" then _G[name] = function() ns.Show("bags") end end
    end
    for _, name in ipairs({ "CloseBackpack", "CloseAllBags" }) do
        if type(_G[name]) == "function" then _G[name] = function() if ns.window then ns.window:Hide() end end end
    end
end
local function tooltips()
    GameTooltip:HookScript("OnTooltipCleared", function(tip) tip.ezwowBagsID = nil end)
    local function append(tip)
        local _, link = tip:GetItem()
        if link then ns.AddTooltipInfo(tip, tonumber(link:match("item:(%d+)"))) end
    end
    if TooltipDataProcessor and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tip) if tip == GameTooltip then append(tip) end end)
    else pcall(GameTooltip.HookScript, GameTooltip, "OnTooltipSetItem", append) end
end
local function init()
    ns.InitDB()
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
        if text == "settings" then ns.ToggleOptions()
        elseif text == "bank" then ns.Show("bank")
        elseif text == "scan" then ns.Auction.Start("full")
        elseif text == "debug" then
            ns.Print("0.1.16 · bank=" .. (ns.API.ModernBank() and "tabs" or "legacy") .. " · keyring=" .. ns.API.Keyring()
                .. " · legacyAH=" .. tostring(type(QueryAuctionItems) == "function")
                .. " · replicate=" .. tostring(C_AuctionHouse and type(C_AuctionHouse.ReplicateItems) == "function" or false)
                .. " · nativeRows=" .. ns.Auction.NativeCount())
            ns.Print(ns.Auction.status or "—")
            local job = ns.Auction.job
            if job then ns.Print("waiting=" .. tostring(job.waiting) .. " · reading=" .. tostring(job.reading) .. " · index=" .. tostring(job.index) .. "/" .. tostring(job.count) .. " · retries=" .. tostring(job.retryPass)) end
        else ns.Toggle() end
    end
    ns.ready = true
end
frame:SetScript("OnEvent", function(_, event, arg, success)
    if event == "PLAYER_LOGIN" then init(); return end
    if not ns.ready then return end
    if event == "BAG_UPDATE_DELAYED" or event == "BAG_UPDATE" or event == "ITEM_LOCK_CHANGED"
        or event == "PLAYERBANKSLOTS_CHANGED" or event == "BAG_CONTAINER_UPDATE" or event == "BANK_TABS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then ns.Dirty()
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
        ns.state.bank = true; ns.ScanStorage("bank"); ns.Show("bank")
    elseif event == "BANKFRAME_CLOSED" then
        -- Never rescan now: bank APIs may already return zero slots after the close event.
        ns.state.bank = false; ns.moveQueue = nil; ns.Refresh()
    elseif event == "AUCTION_HOUSE_SHOW" then ns.state.auction = true; ns.Refresh()
    elseif event == "AUCTION_HOUSE_CLOSED" then ns.state.auction = false; ns.Auction.replicaReady = nil; ns.Auction.Stop()
    elseif event == "AUCTION_ITEM_LIST_UPDATE" then ns.Auction.Results(false)
    elseif event == "REPLICATE_ITEM_LIST_UPDATE" then ns.Auction.Results(true)
    elseif event == "PLAYER_REGEN_DISABLED" then ns.moveQueue = nil; ns.Refresh()
    elseif event == "PLAYER_LOGOUT" then ns.ScanStorage("bags"); if ns.state.bank then ns.ScanStorage("bank") end
    elseif event == "MERCHANT_SHOW" then ns.state.merchant = true
    elseif event == "MERCHANT_CLOSED" then ns.state.merchant = false; ns.moveQueue = nil; ns.Refresh()
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
