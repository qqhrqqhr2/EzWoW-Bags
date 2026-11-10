local _, ns = ...
-- Money log: each change of the player's money in the chat, with what it was for, and
-- (optional) a whisper to the trade partner listing what was traded.
-- What a change was for is noted from post-hooks of the game's own calls (never
-- replaced) and from events; a change with nothing noted shows as "other". Changes
-- close together share one line. Looted money is left out: the game prints it itself.
local MoneyLog = {}; ns.MoneyLog = MoneyLog

local WAIT, KEEP, NAMES = .6, 4, 3
local WHISPER_MAX = 250            -- bytes per whisper (the chat limit is 255)
local notes = {}                   -- { sign = 1 | -1 | 0 (either), label, text, count, quiet, time, keep }
local pending = { gain = 0, cost = 0 }
local money, flushing = nil, false
local muteGainUntil, muteCostUntil = 0, 0
local visit                        -- a merchant visit: { gain, cost, lines }

local function now() return GetTime and GetTime() or 0 end
local function enabled() return ns.cfg and ns.cfg.moneyLog ~= false end
local function after(delay, fn) if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end end
local function passOk(ok, ...)
    if ok then return ... end
    return nil
end
local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return passOk(pcall(fn, ...))
end
local function secret(value) return type(issecretvalue) == "function" and issecretvalue(value) and true or false end
local function hook(name, fn)
    if type(_G[name]) == "function" then hooksecurefunc(name, fn) end
end
local function hookTable(tbl, name, fn)
    if type(tbl) == "table" and type(tbl[name]) == "function" then hooksecurefunc(tbl, name, fn) end
end
local function itemLinkByID(id)
    id = tonumber(id)
    if not id then return nil end
    local getInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
    local _, link = call(getInfo, id)
    return type(link) == "string" and link or nil
end
-- "Name Surname" for a unit (the second value of UnitName is a surname here, or a realm)
local function unitDisplayName(unit)
    local first, second = call(UnitName, unit)
    if type(first) ~= "string" or first == "" then return nil end
    if secret(first) or secret(second) then return nil end
    if type(second) == "string" and second ~= "" and second ~= GetRealmName() then return first .. " " .. second end
    return first
end

-----------------------------------------------------------------------------
-- Notes: what the next money change is for
-----------------------------------------------------------------------------
function MoneyLog.Note(sign, label, text, count, quiet, keep)
    local n = { sign = sign, label = label, text = text, count = count, quiet = quiet, time = now(), keep = keep or KEEP }
    notes[#notes + 1] = n
    return n
end
-- The next changes this way are left out for a moment (they print their own line).
function MoneyLog.Mute(kind, seconds)
    local untilTime = now() + (seconds or 1)
    if kind == "gain" then muteGainUntil = math.max(muteGainUntil, untilTime)
    else muteCostUntil = math.max(muteCostUntil, untilTime) end
end
MoneyLog.gainMuted = nil   -- set by the merchant module while junk is being sold

-- Text for the notes of one direction; used notes are dropped (either-way notes stay
-- until they run out, e.g. a trade can move money both ways).
local function describe(sign)
    local t, keep, groups, order = now(), {}, {}, {}
    local any, quiet = false, true
    for _, n in ipairs(notes) do
        if t - n.time > n.keep then
            -- expired
        elseif n.sign == sign or n.sign == 0 then
            any = true
            if not n.quiet then quiet = false end
            local g = groups[n.label]
            if not g then g = { label = n.label, items = {} }; groups[n.label] = g; order[#order + 1] = g end
            if n.text then g.items[#g.items + 1] = n.text .. ((n.count or 1) > 1 and (" x" .. n.count) or "") end
            if n.sign == 0 then keep[#keep + 1] = n end
        else
            keep[#keep + 1] = n
        end
    end
    notes = keep
    if not any then return ns.Text("moneyOther"), false end
    if quiet then return nil, true end
    local parts = {}
    for _, g in ipairs(order) do
        local text = g.label
        if #g.items > 0 then
            local shown = {}
            for i = 1, math.min(#g.items, NAMES) do shown[i] = g.items[i] end
            text = text .. " " .. table.concat(shown, ", ")
            if #g.items > NAMES then text = text .. " " .. ns.Text("saleMore"):format(#g.items - NAMES) end
        end
        parts[#parts + 1] = text
    end
    return table.concat(parts, " · "), false
end

local function flush()
    flushing = false
    local gain, cost = pending.gain, pending.cost
    pending.gain, pending.cost = 0, 0
    if gain > 0 then
        local what, quiet = describe(1)
        if not quiet then
            ns.Print("|cff7fd07f+" .. ns.Money(gain) .. "|r  " .. what)
            if visit then visit.lines = visit.lines + 1 end
        end
    end
    if cost > 0 then
        local what, quiet = describe(-1)
        if not quiet then
            ns.Print("|cffe7a070-" .. ns.Money(cost) .. "|r  " .. what)
            if visit then visit.lines = visit.lines + 1 end
        end
    end
end

local function onMoney()
    local current = call(GetMoney) or 0
    local last = money
    money = current
    if not last or current == last then return end
    local delta = current - last
    if visit then
        if delta > 0 then visit.gain = visit.gain + delta else visit.cost = visit.cost - delta end
    end
    if not enabled() then return end
    if delta > 0 then
        if now() < muteGainUntil or (MoneyLog.gainMuted and MoneyLog.gainMuted()) then return end
        pending.gain = pending.gain + delta
    else
        if now() < muteCostUntil then return end
        pending.cost = pending.cost - delta
    end
    if not flushing then flushing = true; after(WAIT, flush) end
end

-----------------------------------------------------------------------------
-- Where money goes: hooks of the game's calls
-----------------------------------------------------------------------------
local function merchantOpen() return ns.state and ns.state.merchant end

hookTable(C_Container, "UseContainerItem", function(bag, slot)
    if not merchantOpen() or not ns.API then return end
    local item = ns.API.Item(bag, slot)
    if item and item.link then MoneyLog.Note(1, ns.Text("moneySell"), item.link, item.count or 1) end
end)
if not (C_Container and C_Container.UseContainerItem) then
    hook("UseContainerItem", function(bag, slot)
        if not merchantOpen() or not ns.API then return end
        local item = ns.API.Item(bag, slot)
        if item and item.link then MoneyLog.Note(1, ns.Text("moneySell"), item.link, item.count or 1) end
    end)
end
hook("BuyMerchantItem", function(index, quantity)
    local link = call(GetMerchantItemLink, index)
    local count = tonumber(quantity)
    if not count then
        local info = C_MerchantFrame and call(C_MerchantFrame.GetItemInfo, index)
        count = type(info) == "table" and tonumber(info.stackCount) or 1
    end
    MoneyLog.Note(-1, ns.Text("moneyBuy"), type(link) == "string" and link or nil, count)
end)
hook("BuybackItem", function(index)
    local link = call(GetBuybackItemLink, index)
    MoneyLog.Note(-1, ns.Text("spendBuyback"), type(link) == "string" and link or nil)
end)
hook("RepairAllItems", function() MoneyLog.Note(-1, ns.Text("spendRepair")) end)
hook("TakeTaxiNode", function(slot)
    local name = call(TaxiNodeName, slot)
    MoneyLog.Note(-1, ns.Text("moneyFlight"), type(name) == "string" and name or nil)
end)
hook("BuyTrainerService", function(index)
    local name = call(GetTrainerServiceInfo, index)
    MoneyLog.Note(-1, ns.Text("moneyTrainer"), type(name) == "string" and name or nil)
end)
hook("SendMail", function(recipient)
    MoneyLog.Note(-1, ns.Text("moneyMail"), type(recipient) == "string" and ("→ " .. recipient) or nil)
end)
local function mailSender(index)
    local _, _, sender, _, gold, cod = call(GetInboxHeaderInfo, index)
    return type(sender) == "string" and sender or nil, tonumber(gold) or 0, tonumber(cod) or 0
end
hook("TakeInboxMoney", function(index)
    local sender = mailSender(index)
    MoneyLog.Note(1, ns.Text("moneyMail"), sender)
end)
local function mailItem(index)
    local sender, gold, cod = mailSender(index)
    if cod > 0 then MoneyLog.Note(-1, ns.Text("moneyCOD"), sender) end
    if gold > 0 then MoneyLog.Note(1, ns.Text("moneyMail"), sender) end
end
hook("TakeInboxItem", mailItem)
hook("AutoLootMailItem", mailItem)
hookTable(C_AuctionHouse, "PostItem", function() MoneyLog.Note(-1, ns.Text("moneyAHDeposit")) end)
hookTable(C_AuctionHouse, "PostCommodity", function() MoneyLog.Note(-1, ns.Text("moneyAHDeposit")) end)
hookTable(C_AuctionHouse, "PlaceBid", function() MoneyLog.Note(-1, ns.Text("moneyAHBuy"), nil, nil, nil, 10) end)
hookTable(C_AuctionHouse, "ConfirmCommoditiesPurchase", function(itemID, quantity)
    MoneyLog.Note(-1, ns.Text("moneyAHBuy"), itemLinkByID(itemID), tonumber(quantity), nil, 10)
end)
hookTable(C_AuctionHouse, "CancelAuction", function() MoneyLog.Note(-1, ns.Text("moneyAHCancel")) end)
hook("ConfirmTalentWipe", function() MoneyLog.Note(-1, ns.Text("moneyRespec")) end)
hook("PurchaseSlot", function() MoneyLog.Note(-1, ns.Text("moneyBankSlot")) end)
hook("DepositGuildBankMoney", function() MoneyLog.Note(-1, ns.Text("moneyGuildBank")) end)
hook("WithdrawGuildBankMoney", function() MoneyLog.Note(1, ns.Text("moneyGuildBank")) end)

-----------------------------------------------------------------------------
-- Trade: the money line, and the whisper to the partner
-----------------------------------------------------------------------------
local trade                         -- { name (whisper), display, note, give, get, giveMoney, getMoney, accepted }

local function plainMoney(copper)
    copper = math.floor(tonumber(copper) or 0)
    local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. ns.Text("coinGold") end
    if s > 0 then parts[#parts + 1] = s .. ns.Text("coinSilver") end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. ns.Text("coinCopper") end
    return table.concat(parts, " ")
end
local function tradeItems(getLink, getInfo)
    local list = {}
    for i = 1, (MAX_TRADABLE_ITEMS or 6) do
        local link = call(getLink, i)
        if type(link) == "string" and link ~= "" then
            local _, _, count = call(getInfo, i)
            list[#list + 1] = { link = link, count = tonumber(count) or 1 }
        end
    end
    return list
end
local function snapshot()
    if not trade then return end
    trade.give = tradeItems(GetTradePlayerItemLink, GetTradePlayerItemInfo)
    trade.get = tradeItems(GetTradeTargetItemLink, GetTradeTargetItemInfo)
    trade.giveMoney = tonumber(call(GetPlayerTradeMoney)) or 0
    trade.getMoney = tonumber(call(GetTargetTradeMoney)) or 0
end
-- "[A] x2, [B], 1 gold 5 silver" pieces of one side
local function sidePieces(items, copper)
    local pieces = {}
    for _, it in ipairs(items or {}) do pieces[#pieces + 1] = it.link .. (it.count > 1 and (" x" .. it.count) or "") end
    if (copper or 0) > 0 then pieces[#pieces + 1] = plainMoney(copper) end
    return pieces
end
-- Whisper lines: one heading per side, cut so each line stays under the chat limit.
local function whisperLines(heading, pieces)
    local lines, line = {}, heading
    for i, piece in ipairs(pieces) do
        local add = (line == heading and "" or ", ") .. piece
        if #line + #add > WHISPER_MAX and line ~= heading then
            lines[#lines + 1] = line
            line = heading .. piece
        else
            line = line .. add
        end
    end
    lines[#lines + 1] = line
    return lines
end
local function sendWhisper(text, target)
    local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or _G.SendChatMessage
    if type(send) == "function" then pcall(send, text, "WHISPER", nil, target) end
end
local function tradeCompleted()
    local t = trade
    if not t or t.reported then return end
    t.reported = true
    local give = sidePieces(t.give, t.giveMoney)
    local get = sidePieces(t.get, t.getMoney)
    if #give == 0 and #get == 0 then return end
    local none = ns.Text("tradeNothing")
    if enabled() then
        ns.Print(ns.Text("tradeDone"):format(t.display or t.name or "?",
            #give > 0 and table.concat(give, ", ") or none, #get > 0 and table.concat(get, ", ") or none))
    end
    if ns.cfg and ns.cfg.tradeWhisper and t.name then
        local lines = {}
        for _, l in ipairs(whisperLines(ns.Text("tradeWhisperGive"), #give > 0 and give or { none })) do lines[#lines + 1] = l end
        for _, l in ipairs(whisperLines(ns.Text("tradeWhisperGet"), #get > 0 and get or { none })) do lines[#lines + 1] = l end
        for _, l in ipairs(lines) do sendWhisper(l, t.name) end
    end
end

-----------------------------------------------------------------------------
-- Events
-----------------------------------------------------------------------------
local frame = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_MONEY", "CHAT_MSG_MONEY", "QUEST_TURNED_IN", "MERCHANT_SHOW", "MERCHANT_CLOSED",
    "TRADE_SHOW", "TRADE_CLOSED", "TRADE_PLAYER_ITEM_CHANGED", "TRADE_TARGET_ITEM_CHANGED", "TRADE_MONEY_CHANGED",
    "TRADE_ACCEPT_UPDATE", "UI_INFO_MESSAGE", "UI_ERROR_MESSAGE", "CHAT_MSG_SYSTEM" }) do
    pcall(frame.RegisterEvent, frame, event)
end
frame:SetScript("OnEvent", function(_, event, a1, a2)
    if event == "PLAYER_MONEY" then onMoney()
    elseif event == "PLAYER_LOGIN" then money = call(GetMoney)
    elseif event == "CHAT_MSG_MONEY" then
        MoneyLog.Note(1, ns.Text("moneyLoot"), nil, nil, true)
    elseif event == "QUEST_TURNED_IN" then
        local title = C_QuestLog and call(C_QuestLog.GetTitleForQuestID, a1)
        MoneyLog.Note(1, ns.Text("moneyQuest"), type(title) == "string" and title or nil)
    elseif event == "MERCHANT_SHOW" then
        visit = { gain = 0, cost = 0, lines = 0 }
    elseif event == "MERCHANT_CLOSED" then
        local v = visit
        visit = nil
        if v and enabled() and (v.lines > 1 or (v.gain > 0 and v.cost > 0)) then
            after(WAIT + .1, function()
                ns.Print(ns.Text("merchantTotal"):format(ns.Money(v.gain), ns.Money(v.cost)))
            end)
        end
    elseif event == "TRADE_SHOW" then
        local name = call(UnitName, "NPC")
        if secret(name) then name = nil end
        trade = { name = type(name) == "string" and name ~= "" and name or nil, display = unitDisplayName("NPC") }
        trade.note = MoneyLog.Note(0, ns.Text("moneyTrade"), trade.display, nil, nil, 3600)
        snapshot()
    elseif event == "TRADE_PLAYER_ITEM_CHANGED" or event == "TRADE_TARGET_ITEM_CHANGED" or event == "TRADE_MONEY_CHANGED" then
        snapshot()
    elseif event == "TRADE_ACCEPT_UPDATE" then
        snapshot()
        if trade then trade.accepted = (a1 == 1 or a1 == true) and (a2 == 1 or a2 == true) end
    elseif event == "UI_INFO_MESSAGE" then
        if trade and ERR_TRADE_COMPLETE and a2 == ERR_TRADE_COMPLETE then tradeCompleted() end
    elseif event == "CHAT_MSG_SYSTEM" then
        if trade and ERR_TRADE_COMPLETE and a1 == ERR_TRADE_COMPLETE then tradeCompleted() end
    elseif event == "UI_ERROR_MESSAGE" then
        -- a trade that fails after both accepted (bags full ...) is not reported
        if trade then trade.failed = true end
    elseif event == "TRADE_CLOSED" then
        local t = trade
        if t then
            -- the trade's money lands just after the window closes: keep its note a little longer
            if t.note then t.note.time, t.note.keep = now(), 3 end
            -- no completion message seen: both sides had accepted and nothing failed
            if t.accepted then
                after(1, function() if trade == t and not t.failed then tradeCompleted() end end)
            end
            after(2, function() if trade == t then trade = nil end end)
        end
    end
end)
