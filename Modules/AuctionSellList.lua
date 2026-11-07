local _, ns = ...
-- Auction house sell list: every bag item that can go to the auction house, with check boxes.
-- The checked items are put into the auction house's own sell frame one at a time with an
-- undercut price (the same helper as Alt+click). Each one is posted by a click: the post button
-- here or the auction house's own one. After a post the next item is loaded by itself.
local T = ns.AuctionTrade
if not T then return end
local S = {}; ns.AuctionSellList = S
local API = ns.API
local ROW_H = 24
local F                 -- list frame, laid over the auction panel
local items = {}        -- rows of the current list
local checked = {}      -- item ID -> true (kept in the saved variables once loaded)
local function loadChecked()
    if ns.db and type(ns.db.ahSellChecked) ~= "table" then ns.db.ahSellChecked = {} end
    if ns.db then checked = ns.db.ahSellChecked end
end
local offset = 0
local run               -- { queue, index, current }
local SCAN_AT = 0

local function secret(v) return issecretvalue and issecretvalue(v) end
local function num(v) if secret(v) then return nil end return tonumber(v) end
local function now() return GetTime() end
local function txt(key, ...) if select("#", ...) > 0 then return string.format(ns.Text(key), ...) end return ns.Text(key) end

local function bagList()
    local bags = { 0, 1, 2, 3, 4 }
    local reagent = API.ReagentBag()
    if reagent then bags[#bags + 1] = reagent end
    return bags
end

local function itemName(id, link)
    local name = API.Info(link or id)
    return name or ("#" .. tostring(id))
end

-- total count of an item in the bags
local function bagCount(id)
    local total = 0
    for _, bag in ipairs(bagList()) do
        for slot = 1, API.Slots(bag) do
            local it = API.Item(bag, slot)
            if it and it.id == id then total = total + (it.count or 1) end
        end
    end
    return total
end

-- the bag slot holding this item now (the saved one first: bags may have moved)
local function findItem(id, bag, slot)
    local it = bag and API.Item(bag, slot)
    if it and it.id == id then return bag, slot end
    for _, b in ipairs(bagList()) do
        for s = 1, API.Slots(b) do
            local x = API.Item(b, s)
            if x and x.id == id and not x.locked then return b, s end
        end
    end
end

local function vendorPrice(id)
    return num((select(11, API.Info(id)))) or 0
end

local function recentAverage(id)
    local H = ns.History
    local avg = H and H.Average and H.Average(id, H.TREND_DAYS, H.Day())
    return avg and avg > 0 and avg or nil
end

function S.Scan()
    loadChecked()
    wipe(items)
    local a = C_AuctionHouse
    if not (a and ItemLocation and C_Item and C_Item.DoesItemExist) then return end
    local byCommodity = {}
    for _, bag in ipairs(bagList()) do
        for slot = 1, API.Slots(bag) do
            local it = API.Item(bag, slot)
            local quality = it and num(it.quality)
            -- grey items go to the vendor; locked items are never offered
            if it and it.id and (quality == nil or quality > 0) and not ns.Locks.IsLocked(it.id) then
                local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
                local valid
                if a.IsSellItemValid then
                    local ok, v = pcall(a.IsSellItemValid, loc, false)
                    valid = ok and v and true or false
                else
                    valid = not it.bound
                end
                if valid then
                    local commodity = T.IsCommodity(loc)
                    local row = commodity and byCommodity[it.id]
                    if row then
                        row.count = row.count + (it.count or 1)
                    else
                        row = { id = it.id, bag = bag, slot = slot, link = it.link, icon = it.icon, quality = quality,
                            count = it.count or 1, commodity = commodity, name = itemName(it.id, it.link) }
                        -- recent auction price hardly above the shop price: the shop is the better buyer
                        local vendor, avg = vendorPrice(it.id), recentAverage(it.id)
                        row.vendorBetter = vendor > 0 and avg ~= nil and avg < vendor * 1.15
                        if commodity then byCommodity[it.id] = row end
                        items[#items + 1] = row
                    end
                end
            end
        end
    end
    table.sort(items, function(x, y)
        if x.name ~= y.name then return x.name < y.name end
        return (x.bag * 100 + x.slot) < (y.bag * 100 + y.slot)
    end)
    SCAN_AT = now()
end

local function checkedCount()
    local n = 0
    for _, r in ipairs(items) do if checked[r.id] then n = n + 1 end end
    return n
end

---------------------------------------------------------------------------
-- Selling the checked items one by one
---------------------------------------------------------------------------
local function setStatus(text)
    if F then F.status:SetText(text or "") end
end

local function maxQuantity()
    local f = T.ActiveSellFrame()
    local input = f and f.QuantityInput
    local button = input and input.MaxButton
    if button and type(button.Click) == "function" then pcall(button.Click, button) end
end

local function finish(message)
    run = nil
    S.Scan()
    S.Render()
    setStatus(message)
end

local function loadNext()
    if not run then return end
    run.current = nil
    while run.index < #run.queue do
        run.index = run.index + 1
        local r = run.queue[run.index]
        local bag, slot = findItem(r.id, r.bag, r.slot)
        if bag and T.Sell(bag, slot) then
            run.current = { id = r.id, name = r.name, before = bagCount(r.id), loadedAt = now() }
            if r.commodity and C_Timer then C_Timer.After(.4, maxQuantity) end
            S.Render()
            return
        end
    end
    finish(txt("sellListDone"))
end

-- the current item left the bags (posted): on to the next one
local function posted()
    if not (run and run.current) then return end
    run.current = nil
    S.Render()
    if C_Timer then C_Timer.After(.6, loadNext) else loadNext() end
end

function S.Start()
    if not T.IsOpen() then ns.Print(ns.Text("ahNeedOpen")); return end
    local queue = {}
    for _, r in ipairs(items) do if checked[r.id] then queue[#queue + 1] = r end end
    if #queue == 0 then return end
    run = { queue = queue, index = 0 }
    loadNext()
end

function S.Stop()
    if run then finish(nil) end
end

-- posts the item now in the sell frame (this click is the player's own)
function S.Post()
    if not (run and run.current) then return end
    local f = T.ActiveSellFrame()
    if not f then setStatus(ns.Text("sellNoFrame")); return end
    if type(f.PostItem) == "function" and pcall(f.PostItem, f) then return end
    local button = f.PostButton
    if button and type(button.Click) == "function" then pcall(button.Click, button) end
end

local function priceReady()
    local info = T.SellInfo()
    if info and info.announced then return true end
    return run and run.current and now() - run.current.loadedAt > 3 or false
end

---------------------------------------------------------------------------
-- List frame
---------------------------------------------------------------------------
local function rowButton(i)
    F.rows = F.rows or {}
    local b = F.rows[i]
    if b then return b end
    local UI = ns.UI
    b = UI.Button(F, "", 276, function(self)
        local r = items[self.index]
        if not r or run then return end
        checked[r.id] = not checked[r.id] or nil
        S.Render()
    end)
    b:SetHeight(ROW_H - 2); b.text:Hide()
    b.tick = UI.Tick(b, 14); b.tick:SetPoint("LEFT", 6, 0)
    UI.FlatRow(b)
    b.icon2 = b:CreateTexture(nil, "ARTWORK"); b.icon2:SetSize(16, 16); b.icon2:SetPoint("LEFT", 24, 0); b.icon2:SetTexCoord(.07, .93, .07, .93)
    b.left = UI.Label(b, "", 11); b.left:SetPoint("LEFT", 44, 0); b.left:SetWidth(120); if b.left.SetWordWrap then b.left:SetWordWrap(false) end
    b.mid = UI.Label(b, "", 10); b.mid:SetPoint("LEFT", 160, 0); b.mid:SetWidth(36); b.mid:SetJustifyH("RIGHT")
    b.mid:SetTextColor(unpack(UI.Theme.muted))
    b.right = UI.Label(b, "", 10); b.right:SetPoint("RIGHT", -8, 0); b.right:SetWidth(76); b.right:SetJustifyH("RIGHT")
    b.right:SetTextColor(1, .88, .55, 1)
    b:HookScript("OnEnter", function(self)
        local r = items[self.index]
        if not r then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if ns.HoldTooltipTag then ns.HoldTooltipTag(GameTooltip) end
        if r.link then GameTooltip:SetHyperlink(r.link) else GameTooltip:SetItemByID(r.id) end
        if r.vendorBetter then GameTooltip:AddLine(ns.Text("sellListVendorTip"), .91, .64, .29, true) end
        if ns.NoteTooltipLines then ns.NoteTooltipLines(GameTooltip) end   -- this panel is ours: always name it
        if ns.ReleaseTooltipTag then ns.ReleaseTooltipTag(GameTooltip) end
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    F.rows[i] = b
    return b
end

local function visibleRows()
    return math.max(4, math.floor((F:GetHeight() - 152) / ROW_H))
end

local function recentPrice(r)
    local avg = recentAverage(r.id)
    if r.vendorBetter then return "|cffe8a24a" .. ns.Text("sellListVendor") .. "|r" end
    return avg and ns.MoneyShort(avg) or "|cff6f7f8a-|r"
end

function S.Render()
    if not (F and F:IsShown()) then return end
    local UI = ns.UI
    F.all.text:SetText(ns.Text("sellListAll"))
    F.none.text:SetText(ns.Text("sellListNone"))
    F.rescan.text:SetText(ns.Text("sellListRescan"))
    F.headLeft:SetText(ns.T("name"))
    F.headMid:SetText(ns.Text("buyQty"))
    F.headRight:SetText(ns.Text("sellListPrice"))
    local count = visibleRows()
    offset = math.max(0, math.min(offset, math.max(0, #items - count)))
    for i = 1, count do
        local b = rowButton(i)
        local index = offset + i
        local r = items[index]
        if r then
            b.index = index
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 12, -60 - (i - 1) * ROW_H); b:SetWidth(F:GetWidth() - 24)
            b.tick:SetChecked(checked[r.id])
            b.icon2:SetTexture(r.icon)
            local color = r.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[r.quality]
            b.left:SetText(color and color.hex and (color.hex .. r.name .. "|r") or r.name)
            b.mid:SetText("×" .. r.count)
            b.right:SetText(recentPrice(r))
            local current = run and run.current and run.current.id == r.id
            UI.PaintRow(b, index, current)
            b:SetAlpha((run and not current and not checked[r.id]) and .45 or 1)
            b:Show()
        else
            b:Hide()
        end
    end
    for i = count + 1, #(F.rows or {}) do F.rows[i]:Hide() end

    local selected = checkedCount()
    F.start:SetShown(not run)
    F.post:SetShown(run ~= nil)
    F.skip:SetShown(run ~= nil)
    F.stop:SetShown(run ~= nil)
    F.all:SetEnabled(not run); F.none:SetEnabled(not run); F.rescan:SetEnabled(not run)
    F.barBg:SetShown(run ~= nil); F.bar:SetShown(run ~= nil)
    if run then
        local width = (F.barBg:GetWidth() or 0)
        local done = math.max(0, run.index - (run.current and 1 or 0))
        F.bar:SetWidth(math.max(1, width * done / math.max(1, #run.queue)))
        UI.Primary(F.post, run.current ~= nil and priceReady())
        local cur = run.current
        F.post.text:SetText(ns.Text("sellListPost"))
        F.skip.text:SetText(ns.Text("sellListSkip"))
        F.stop.text:SetText(ns.Text("sellListStop"))
        if cur then
            local step = string.format("%d/%d · %s", run.index, #run.queue, cur.name)
            setStatus(step .. "\n" .. (priceReady() and ns.Text("sellListReady") or ns.Text("sellListWaitPrice")))
        end
    else
        F.start.text:SetText(txt("sellListStart", selected))
        UI.Primary(F.start, selected > 0)
        if #items == 0 then setStatus(ns.Text("sellListEmpty"))
        elseif not F.status:GetText() or F.status:GetText() == "" then setStatus(ns.Text("sellListHint")) end
    end
end

function S.Create(P)
    local UI = ns.UI
    F = UI.Frame("Frame", nil, P)
    F:SetPoint("TOPLEFT", 1, -36); F:SetPoint("BOTTOMRIGHT", -1, 1)
    UI.Surface(F)
    F:SetFrameLevel(P:GetFrameLevel() + 10)
    F:EnableMouse(true)
    -- "select all" leaves out what sells better at a shop
    F.all = UI.Button(F, "", 86, function()
        for _, r in ipairs(items) do if not r.vendorBetter then checked[r.id] = true end end
        S.Render()
    end)
    F.all:SetPoint("TOPLEFT", 11, -6); F.all:SetHeight(22)
    F.none = UI.Button(F, "", 86, function() for _, r in ipairs(items) do checked[r.id] = nil end; S.Render() end)
    F.none:SetPoint("LEFT", F.all, "RIGHT", 6, 0); F.none:SetHeight(22)
    F.rescan = UI.Button(F, "", 86, function() S.Scan(); S.Render() end)
    F.rescan:SetPoint("LEFT", F.none, "RIGHT", 6, 0); F.rescan:SetHeight(22)
    UI.HeadBand(F, -37)
    F.headLeft = UI.Label(F, "", 10); F.headLeft:SetPoint("TOPLEFT", 56, -42); F.headLeft:SetTextColor(unpack(UI.Theme.muted))
    F.headMid = UI.Label(F, "", 10); F.headMid:SetPoint("TOPLEFT", 158, -42); F.headMid:SetWidth(50); F.headMid:SetJustifyH("RIGHT")
    F.headMid:SetTextColor(unpack(UI.Theme.muted))
    F.headRight = UI.Label(F, "", 10); F.headRight:SetPoint("TOPRIGHT", -18, -42); F.headRight:SetJustifyH("RIGHT")
    F.headRight:SetTextColor(unpack(UI.Theme.muted))
    F.footLine = F:CreateTexture(nil, "BORDER"); F.footLine:SetHeight(1)
    F.footLine:SetPoint("BOTTOMLEFT", 12, 82); F.footLine:SetPoint("BOTTOMRIGHT", -12, 82)
    F.footLine:SetColorTexture(UI.Theme.border[1], UI.Theme.border[2], UI.Theme.border[3], 1)
    F.barBg = F:CreateTexture(nil, "ARTWORK"); F.barBg:SetHeight(4)
    F.barBg:SetPoint("BOTTOMLEFT", 12, 40); F.barBg:SetPoint("BOTTOMRIGHT", -12, 40)
    F.barBg:SetColorTexture(UI.Theme.input[1], UI.Theme.input[2], UI.Theme.input[3], 1)
    F.bar = F:CreateTexture(nil, "OVERLAY"); F.bar:SetHeight(4); F.bar:SetPoint("LEFT", F.barBg, "LEFT")
    F.bar:SetColorTexture(unpack(UI.Theme.accent))
    F.status = UI.Label(F, "", 11); F.status:SetPoint("BOTTOMLEFT", 12, 48); F.status:SetWidth(284)
    F.status:SetJustifyV("BOTTOM"); F.status:SetTextColor(unpack(UI.Theme.muted))
    F.start = UI.Button(F, "", 284, function() S.Start() end)
    F.start:SetPoint("BOTTOMLEFT", 12, 10); F.start:SetHeight(24)
    F.post = UI.Button(F, "", 120, function() S.Post() end)
    F.post:SetPoint("BOTTOMLEFT", 12, 10); F.post:SetHeight(24)
    F.skip = UI.Button(F, "", 76, function() loadNext() end)
    F.skip:SetPoint("LEFT", F.post, "RIGHT", 6, 0); F.skip:SetHeight(24)
    F.stop = UI.Button(F, "", 76, function() S.Stop() end)
    F.stop:SetPoint("LEFT", F.skip, "RIGHT", 6, 0); F.stop:SetHeight(24)
    F:EnableMouseWheel(true)
    F:SetScript("OnMouseWheel", function(_, delta) offset = math.max(0, offset - delta * 3); S.Render() end)
    F:SetScript("OnShow", function() if not run then S.Scan() end; S.Render() end)
    F:Hide()

    P.sellToggle = UI.Button(P, "", 76, function() S.Toggle() end)
    P.sellToggle:SetPoint("TOPRIGHT", -32, -6); P.sellToggle:SetHeight(22)
    P.sellToggle.text:SetText(ns.Text("sellListButton"))
end

function S.Toggle()
    if not F then return end
    if F:IsShown() then
        if run then S.Stop() end
        F:Hide()
    else
        F:Show()
    end
    local P = T.GetPanel()
    if P and P.sellToggle then ns.UI.Selected(P.sellToggle, F:IsShown()) end
end

-- the list is laid over the auction panel when that is first made
local create = T.CreatePanel
T.CreatePanel = function(...)
    create(...)
    local P = T.GetPanel()
    if P and not P.sellToggle then S.Create(P) end
end

---------------------------------------------------------------------------
-- Events: a post finished, the auction house closed
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
for _, event in ipairs({ "AUCTION_HOUSE_AUCTION_CREATED", "AUCTION_HOUSE_CLOSED", "BAG_UPDATE_DELAYED" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event)
    if not ns.ready then return end
    if event == "AUCTION_HOUSE_CLOSED" then
        run = nil
        if F then F:Hide() end
        local P = T.GetPanel()
        if P and P.sellToggle then ns.UI.Selected(P.sellToggle, false) end
    elseif event == "AUCTION_HOUSE_AUCTION_CREATED" then
        posted()
    elseif event == "BAG_UPDATE_DELAYED" then
        -- a post that the event above did not report: the item count went down
        if run and run.current and bagCount(run.current.id) < run.current.before then posted()
        elseif not run and F and F:IsShown() and now() - SCAN_AT > .5 then S.Scan(); S.Render() end
    end
end)
local tick = 0
events:SetScript("OnUpdate", function(_, elapsed)
    tick = tick + (elapsed or 0)
    if tick < .25 then return end
    tick = 0
    if run and run.current and F and F:IsShown() then S.Render() end
end)
