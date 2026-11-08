local _, ns = ...
-- Auction house helpers for the modern auction house frame:
--  * sell: Alt+click a bag item puts it into the auction house's own sell frame and fills an
--    undercut price; the player still presses the auction house's own post button.
--  * buy: a small panel next to the auction house lists offers cheapest first; every purchase
--    needs a click on a confirm dialog that shows item, quantity and total.
local T = {}; ns.AuctionTrade = T
local API = ns.API
local ROW_H = 24
local state = { view = "browse", query = "", browse = {}, rows = {}, offset = 0 }
local sell, purchase, pendingQuery, P, D
local last = { key = nil, at = 0 }

local function api() return C_AuctionHouse end
local function ahFrame() return _G.AuctionHouseFrame end
local function now() return GetTime() end
local function secret(v) return issecretvalue and issecretvalue(v) end
local function num(v) if secret(v) then return nil end return tonumber(v) end
local function say(message) ns.Print(message) end
local function fmt(key, ...) return string.format(ns.Text(key), ...) end
-- The auction house window being shown is what counts: the "opened" event can
-- reach this file before the one that sets ns.state.auction.
function T.IsOpen()
    local f = ahFrame()
    return ns.ready and f ~= nil and f:IsShown() and true or false
end
local function itemName(id)
    local name = id and API.Info(id)
    return name or (id and ("#" .. id)) or "?"
end
local function itemIcon(id)
    if not id then return nil end
    local _, _, _, _, icon = API.Instant(id)
    return icon
end
local function vendorPrice(id)
    if not id then return 0 end
    return num((select(11, API.Info(id)))) or 0
end
local function priceSorts()
    local order = Enum and Enum.AuctionHouseSortOrder
    return { { sortOrder = order and order.Price or 0, reverseSort = false } }
end
local function plainName(v)
    if type(v) ~= "string" or secret(v) or v == "" then return nil end
    return v
end

-- Requests wait for the auction house's own message throttle.
local function throttleReady()
    local a = api()
    return not a.IsThrottledMessageSystemReady or a.IsThrottledMessageSystemReady()
end
function T.Send(fn)
    if not T.IsOpen() then return false end
    if not throttleReady() then pendingQuery = fn; T.SetStatus(ns.Text("ahThrottled")); return true end
    pendingQuery = nil
    local ok, err = pcall(fn)
    if not ok then T.SetStatus(tostring(err)) end
    return ok
end

---------------------------------------------------------------------------
-- Sell helper
---------------------------------------------------------------------------
function T.Undercut(lowest)
    if ns.cfg.ahUndercutMode == "percent" then
        return math.floor(lowest * (1 - (tonumber(ns.cfg.ahUndercutPercent) or 0) / 100))
    end
    return lowest - (tonumber(ns.cfg.ahUndercutCopper) or 0)
end
local function isCommodity(loc)
    local a = api()
    if a.GetItemCommodityStatus and Enum and Enum.ItemCommodityStatus then
        local ok, status = pcall(a.GetItemCommodityStatus, loc)
        if ok and status == Enum.ItemCommodityStatus.Commodity then return true end
        if ok and status == Enum.ItemCommodityStatus.Item then return false end
    end
    local ok, key = pcall(a.GetItemKeyFromItem, loc)
    local info = ok and key and a.GetItemKeyInfo and a.GetItemKeyInfo(key)
    return info and info.isCommodity and true or false
end
local function activeSellFrame()
    local f = ahFrame()
    local c, i = f and f.CommoditiesSellFrame, f and f.ItemSellFrame
    if c and c:IsShown() then return c, true end
    if i and i:IsShown() then return i, false end
end
local function sellFrameItem(f)
    if not f or type(f.GetItem) ~= "function" then return nil end
    local ok, loc = pcall(f.GetItem, f)
    if not ok or type(loc) ~= "table" or type(loc.GetBagAndSlot) ~= "function" then return nil end
    local ok2, bag, slot = pcall(loc.GetBagAndSlot, loc)
    if ok2 then return bag, slot end
end
local function priceAmount(f)
    local input = f and f.PriceInput
    if input and type(input.GetAmount) == "function" then
        local ok, v = pcall(input.GetAmount, input)
        if ok then return num(v) end
    end
end
-- Fills the auction house's own price box. The box may not accept copper; then whole silver.
local function setPrice(f, amount, vendor)
    local input = f and f.PriceInput
    if not input or type(input.SetAmount) ~= "function" then return nil end
    pcall(input.SetAmount, input, amount)
    local got = priceAmount(f)
    if got and got ~= amount then
        local silver = math.max(100, math.floor(amount / 100) * 100)
        if vendor and silver < vendor then silver = math.ceil(vendor / 100) * 100 end
        pcall(input.SetAmount, input, silver)
        amount = priceAmount(f) or silver
    end
    for _, method in ipairs({ "UpdateTotalPrice", "UpdatePostState" }) do
        if type(f[method]) == "function" then pcall(f[method], f) end
    end
    return amount
end
-- Offers the sell frame searched for, cheapest first. Nil while they have not arrived.
local function sellOffers(p)
    local a = api()
    local rows, total = {}, 0
    if p.commodity then
        if not p.itemID or not a.GetNumCommoditySearchResults then return nil end
        local n = num(a.GetNumCommoditySearchResults(p.itemID)) or 0
        local full = a.HasFullCommoditySearchResults and a.HasFullCommoditySearchResults(p.itemID)
        if n == 0 and not p.seenEvent and not full then return nil end
        for i = 1, math.min(n, 30) do
            local r = a.GetCommoditySearchResultInfo(p.itemID, i)
            local price, qty = r and num(r.unitPrice), r and num(r.quantity) or 0
            if price and price > 0 then
                local owned = num(r.numOwnerItems) or 0
                rows[#rows + 1] = { price = price, qty = qty, own = owned > 0 and owned >= qty }
                total = total + qty
            end
        end
        total = num(a.GetCommoditySearchResultsQuantity and a.GetCommoditySearchResultsQuantity(p.itemID)) or total
    else
        if not p.itemKey or not a.GetNumItemSearchResults then return nil end
        local n = num(a.GetNumItemSearchResults(p.itemKey)) or 0
        if n == 0 and not p.seenEvent then return nil end
        for i = 1, math.min(n, 60) do
            local r = a.GetItemSearchResultInfo(p.itemKey, i)
            local buyout, qty = r and num(r.buyoutAmount), math.max(1, r and num(r.quantity) or 1)
            if buyout and buyout > 0 then
                rows[#rows + 1] = { price = math.floor(buyout / qty + .5), qty = qty, own = r.containsOwnerItem and true or false }
                total = total + qty
            end
        end
        table.sort(rows, function(x, y) return x.price < y.price end)
    end
    return rows, total
end
local function applySell(p)
    local rows, total = sellOffers(p)
    if not rows then return false end
    local f = p.frame
    local vendor = vendorPrice(p.itemID)
    local first, price, note = rows[1], nil, nil
    if first then
        ns.Auction.RecordQuote(p.itemID, first.price, total)
        if first.own then price, note = first.price, fmt("sellOwn", ns.MoneyShort(first.price))
        else price = math.max(1, T.Undercut(first.price)) end
    else note = ns.Text("sellNoListings") end
    if price then
        local floored = vendor > 0 and price < vendor
        if floored then price = vendor end
        price = setPrice(f, price, vendor) or price
        if not note then note = fmt("sellPrice", ns.MoneyShort(price), ns.MoneyShort(first.price)) end
        if floored then note = note .. " · " .. fmt("sellVendor", ns.MoneyShort(vendor)) end
    end
    local shown = price or priceAmount(f)
    local avg = ns.History.Average(p.itemID, ns.History.TREND_DAYS, ns.History.Day())
    local warn = avg and shown and shown < avg * .7 and fmt("sellWarn", ns.MoneyShort(avg), math.floor((1 - shown / avg) * 100 + .5))
    if not p.announced then
        p.announced = true
        say(itemName(p.itemID) .. ": " .. note)
        if warn then say("|cffe87c70" .. warn .. "|r") end
    end
    T.SetStatus(note .. (warn and ("\n|cffe87c70" .. warn .. "|r") or ""))
    return true
end
function T.Sell(bag, slot)
    if not ns.cfg.ahSell or not T.IsOpen() then return false end
    local a = api()
    if not a or not ItemLocation or not C_Item or not C_Item.DoesItemExist then return false end
    local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not loc or not C_Item.DoesItemExist(loc) then return false end
    local lockedID = C_Item.GetItemID and C_Item.GetItemID(loc)
    if ns.Locks.IsLocked(lockedID) then say(string.format(ns.Text("lockBlocked"), itemName(lockedID))); return true end
    if a.IsSellItemValid then
        local ok, valid = pcall(a.IsSellItemValid, loc, true)
        if ok and not valid then say(ns.Text("sellInvalid")); return true end
    end
    local f = ahFrame()
    local placed = false
    if type(f.SetPostItem) == "function" then
        local ok, result = pcall(f.SetPostItem, f, loc)
        placed = ok and result ~= false
    end
    if not placed then
        local commodity = isCommodity(loc)
        local target = commodity and f.CommoditiesSellFrame or f.ItemSellFrame
        local modes = _G.AuctionHouseFrameDisplayMode
        if target and modes and type(target.SetItem) == "function" and type(f.SetDisplayMode) == "function" then
            placed = pcall(f.SetDisplayMode, f, commodity and modes.CommoditiesSell or modes.ItemSell)
                and pcall(target.SetItem, target, loc)
        end
    end
    if not placed then say(ns.Text("sellNoFrame")); return true end
    local frame, commodity = activeSellFrame()
    if not frame then say(ns.Text("sellNoFrame")); return true end
    local okKey, itemKey = pcall(a.GetItemKeyFromItem, loc)
    sell = { bag = bag, slot = slot, itemID = C_Item.GetItemID and C_Item.GetItemID(loc), itemKey = okKey and itemKey or nil,
        commodity = commodity, frame = frame, started = now(), deadline = now() + 8 }
    return true
end
local function sellTick()
    local p = sell
    if not p then return end
    local t = now()
    if not T.IsOpen() or t > p.deadline or not p.frame:IsShown() then sell = nil; return end
    -- Posted, cleared or replaced: the frame no longer holds this item.
    if type(p.frame.GetItem) == "function" then
        local bag, slot = sellFrameItem(p.frame)
        if bag ~= p.bag or slot ~= p.slot then sell = nil; return end
    end
    if p.applyAt and t >= p.applyAt then
        p.applyAt = nil; applySell(p)
    elseif not p.announced and not p.seenEvent and t - p.started > 1.5 then
        -- The frame may reuse results it already has without a new search.
        p.applyAt = t
    end
end
local function sellResultsEvent(itemID, itemKey)
    local p = sell
    if not p then return end
    local id = itemID or (type(itemKey) == "table" and num(itemKey.itemID))
    if id and id == p.itemID then
        p.seenEvent = true
        p.applyAt = now() + .1 -- after the auction house frame filled its own default price
    end
end

---------------------------------------------------------------------------
-- Buy panel
---------------------------------------------------------------------------
function T.SetStatus(text)
    state.status = text
    if P and P:IsShown() then P.status:SetText(text or "") end
end
local function keyInfo(itemKey)
    local a = api()
    if not itemKey or not a.GetItemKeyInfo then return nil end
    local ok, info = pcall(a.GetItemKeyInfo, itemKey)
    return ok and type(info) == "table" and info or nil
end
function T.Browse(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    if text == "" then return end
    if not T.IsOpen() then say(ns.Text("ahNeedOpen")); return end
    T.ShowPanel(true)
    if P.search:GetText() ~= text then P.search:SetText(text) end
    state.view, state.query, state.browse, state.offset, state.waitBrowse = "browse", text, {}, 0, true
    T.SetStatus(ns.Text("buySearching"))
    T.Send(function()
        api().SendBrowseQuery({ searchString = text, sorts = priceSorts(), filters = {}, itemClassFilters = {} })
    end)
    T.RenderPanel()
end
function T.Detail(itemKey, itemID)
    if not itemKey or not T.IsOpen() then return end
    T.ShowPanel(true)
    local info = keyInfo(itemKey)
    state.view, state.key, state.itemID, state.rows, state.offset = "detail", itemKey, itemID or num(itemKey.itemID), {}, 0
    state.commodity = info and info.isCommodity
    state.waitDetail = true
    T.SetStatus(ns.Text("buySearching"))
    T.Send(function() api().SendSearchQuery(itemKey, priceSorts(), true) end)
    T.RenderPanel()
end
-- From the Bags window: Alt+right-click on a bag item.
function T.SearchBagItem(bag, slot)
    if not T.IsOpen() then say(ns.Text("ahNeedOpen")); return true end
    local loc = ItemLocation and ItemLocation:CreateFromBagAndSlot(bag, slot)
    if not loc or not C_Item.DoesItemExist(loc) then return false end
    local ok, itemKey = pcall(api().GetItemKeyFromItem, loc)
    if not ok or not itemKey then return false end
    T.Detail(itemKey, C_Item.GetItemID and C_Item.GetItemID(loc))
    return true
end
-- From the price list: only the item ID is known, so search by name and open the matching row.
function T.SearchItemID(id)
    if not T.IsOpen() then say(ns.Text("ahNeedOpen")); return end
    local name = API.Info(id)
    if not name then say(ns.Text("buyNoName")); return end
    state.autoDetail = id
    T.Browse(name)
end
local function readBrowse()
    local a = api()
    local ok, results = pcall(a.GetBrowseResults)
    if not ok or type(results) ~= "table" then return end
    local rows = {}
    for _, r in ipairs(results) do
        local key = r.itemKey
        local id = key and num(key.itemID)
        local price = num(r.minPrice)
        if id and price and price > 0 then
            rows[#rows + 1] = { itemKey = key, itemID = id, price = price, qty = num(r.totalQuantity) or 0, own = r.containsOwnerItem and true or false }
        end
    end
    table.sort(rows, function(x, y) if x.price ~= y.price then return x.price < y.price end return x.itemID < y.itemID end)
    state.browse = rows
    if state.autoDetail then
        for _, row in ipairs(rows) do
            if row.itemID == state.autoDetail then state.autoDetail = nil; T.Detail(row.itemKey, row.itemID); return end
        end
        state.autoDetail = nil
    end
    T.SetStatus(#rows == 0 and ns.Text("buyNoResults") or nil)
    T.RenderPanel()
end
local function ownerOf(r)
    local owners = r and r.owners
    if type(owners) ~= "table" then return nil end
    local name = plainName(owners[1])
    if name and #owners > 1 then name = name .. " +" .. (#owners - 1) end
    return name
end
local function readCommodity(itemID)
    local a = api()
    local n = num(a.GetNumCommoditySearchResults(itemID)) or 0
    local rows, total = {}, 0
    for i = 1, n do
        local r = a.GetCommoditySearchResultInfo(itemID, i)
        local price, qty = r and num(r.unitPrice), r and num(r.quantity) or 0
        if price and price > 0 and qty > 0 then
            local owned = num(r.numOwnerItems) or 0
            rows[#rows + 1] = { price = price, qty = qty, owner = ownerOf(r), own = owned > 0 and owned >= qty, owned = owned, auctionID = r.auctionID }
            total = total + qty
        end
    end
    total = num(a.GetCommoditySearchResultsQuantity and a.GetCommoditySearchResultsQuantity(itemID)) or total
    state.commodity, state.rows, state.total = true, rows, total
    if rows[1] then ns.Auction.RecordQuote(itemID, rows[1].price, total) end
end
local function readItems(itemKey)
    local a = api()
    local n = num(a.GetNumItemSearchResults(itemKey)) or 0
    local rows, total = {}, 0
    for i = 1, n do
        local r = a.GetItemSearchResultInfo(itemKey, i)
        local buyout, qty = r and num(r.buyoutAmount), math.max(1, r and num(r.quantity) or 1)
        if buyout and buyout > 0 and r.auctionID then
            -- buyoutAmount is the price of one (the game's own list shows it as the unit
            -- price); an auction of several costs that times its quantity
            rows[#rows + 1] = { price = buyout, total = buyout * qty, qty = qty, owner = ownerOf(r),
                own = r.containsOwnerItem and true or false, auctionID = r.auctionID, link = plainName(r.itemLink) }
            total = total + qty
        end
    end
    table.sort(rows, function(x, y) return x.price < y.price end)
    state.commodity, state.rows, state.total = false, rows, total
    if rows[1] then ns.Auction.RecordQuote(state.itemID, rows[1].price, total) end
end
local function detailEvent(itemID, itemKey)
    if state.view ~= "detail" or not P or not P:IsShown() then return end
    if itemID then
        if itemID ~= state.itemID then return end
        readCommodity(itemID)
    else
        local id = type(itemKey) == "table" and num(itemKey.itemID)
        if not id or id ~= state.itemID then return end
        readItems(itemKey)
    end
    state.waitDetail = false
    T.SetStatus(#state.rows == 0 and ns.Text("buyNoResults") or nil)
    if #state.rows > 0 then T.UpdateEstimate() end
    T.RenderPanel()
end

---------------------------------------------------------------------------
-- Purchase confirm dialog
---------------------------------------------------------------------------
local function closeDialog()
    if D and D:IsShown() then D:Hide() end
end
local function cancelPurchase()
    local p = purchase
    purchase = nil
    if p and p.kind == "commodity" and not p.sent and api().CancelCommoditiesPurchase then pcall(api().CancelCommoditiesPurchase) end
end
local function updateDialog()
    local p = purchase
    if not D or not p then return end
    local UI = ns.UI
    D.icon:SetTexture(itemIcon(p.itemID) or "Interface\\Icons\\INV_Misc_QuestionMark")
    D.name:SetText(itemName(p.itemID))
    local qtyText = ns.Text("buyQty") .. ": |cffffffff" .. p.qty .. "|r"
    if p.queue and #p.queue > 1 then
        qtyText = qtyText .. "  |cffa7b9c5" .. string.format(ns.Text("buyStep"), p.step, #p.queue, p.queueQty,
            ns.MoneyShort(p.queueTotal)) .. "|r"
    end
    D.qty:SetText(qtyText)
    local ready = p.total ~= nil
    if ready then
        -- an item auction carries its own price (p.unit); a commodity's comes from the total
        D.unit:SetText(ns.Text("buyUnit") .. ": " .. ns.Money(p.unit or math.floor(p.total / math.max(1, p.qty) + .5)))
        D.total:SetText(ns.Text("buyTotal") .. ": " .. ns.Money(p.total))
    else
        D.unit:SetText(ns.Text("buyChecking")); D.total:SetText("")
    end
    local enough = ready and GetMoney() >= p.total
    local warn = ready and not enough and ns.Text("buyNoMoney") or ""
    if ready and enough then
        local H = ns.History
        local avg = H and H.Average and H.Average(p.itemID, H.TREND_DAYS, H.Day())
        local unit = p.unit or p.total / math.max(1, p.qty)
        if avg and avg > 0 and unit > avg * 1.5 then
            warn = string.format(ns.Text("buyPricey"), ns.MoneyShort(avg), math.floor((unit / avg - 1) * 100 + .5))
        end
    end
    D.warn:SetText(warn)
    D.buy:SetEnabled(enough and not p.sent)
    D.buy:SetAlpha(enough and 1 or .4)
    D.buy.text:SetText(ns.Text("buyConfirm")); D.cancel.text:SetText(ns.Text("buyCancel"))
    D.title:SetText(ns.Text("buyConfirmTitle"))
    D.title:SetTextColor(unpack(UI.Theme.accent))
end
local function createDialog()
    local UI = ns.UI
    D = UI.Frame("Frame", "EzWoWBagsBuyConfirm", UIParent)
    D:SetSize(340, 190); D:SetPoint("CENTER", 0, 120); D:SetFrameStrata("DIALOG"); D:SetToplevel(true)
    D:EnableMouse(true); D:SetClampedToScreen(true)
    UI.Surface(D)
    D.line = D:CreateTexture(nil, "ARTWORK"); D.line:SetPoint("TOPLEFT", 1, -32); D.line:SetPoint("TOPRIGHT", -1, -32)
    D.line:SetHeight(2); D.line:SetColorTexture(unpack(UI.Theme.accent))
    D.title = UI.Label(D, "", 14); D.title:SetPoint("TOPLEFT", 14, -10)
    D.icon = D:CreateTexture(nil, "ARTWORK"); D.icon:SetSize(36, 36); D.icon:SetPoint("TOPLEFT", 14, -44)
    D.icon:SetTexCoord(.07, .93, .07, .93)
    D.name = UI.Label(D, "", 13); D.name:SetPoint("TOPLEFT", 58, -46); D.name:SetWidth(266)
    D.qty = UI.Label(D, "", 12); D.qty:SetPoint("TOPLEFT", 58, -66)
    D.unit = UI.Label(D, "", 12); D.unit:SetPoint("TOPLEFT", 14, -92); D.unit:SetWidth(312)
    D.total = UI.Label(D, "", 14); D.total:SetPoint("TOPLEFT", 14, -114); D.total:SetWidth(312)
    D.total:SetTextColor(1, .88, .55)
    D.warn = UI.Label(D, "", 11); D.warn:SetPoint("TOPLEFT", 14, -136); D.warn:SetTextColor(unpack(UI.Theme.warn))
    D.buy = UI.Button(D, "", 150, function()
        local p = purchase
        if not p or p.sent or not p.total or GetMoney() < p.total then return end
        local a = api()
        local ok
        if p.kind == "commodity" then ok = pcall(a.ConfirmCommoditiesPurchase, p.itemID, p.qty)
        else ok = pcall(a.PlaceBid, p.auctionID, p.total) end
        p.sent = true
        if not ok then say(ns.Text("buyFailed")); purchase = nil end
        -- a queue of auctions keeps the dialog for the next one (one click each)
        if not (ok and p.queue and p.step < #p.queue) then D:Hide() else updateDialog() end
    end)
    D.buy:SetPoint("BOTTOMLEFT", 14, 12)
    D.cancel = UI.Button(D, "", 150, function() D:Hide() end)
    D.cancel:SetPoint("BOTTOMRIGHT", -14, 12)
    D:SetScript("OnHide", function() if purchase and not purchase.sent then cancelPurchase() end end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "EzWoWBagsBuyConfirm" end
    D:Hide()
end
local function openDialog(p)
    if purchase and not purchase.sent then cancelPurchase() end
    purchase = p
    if not D then createDialog() end
    updateDialog(); D:Show(); D:Raise()
end
function T.Buy(index)
    local row = state.rows[index]
    if not row or not T.IsOpen() then return end
    if row.own then say(ns.Text("buyOwn")); return end
    if state.commodity then
        local qty
        if IsShiftKeyDown and IsShiftKeyDown() then
            qty = 0
            for i = 1, index do local r = state.rows[i]; if not r.own then qty = qty + r.qty - (r.owned or 0) end end
        else qty = tonumber(P.qty:GetText()) or 1 end
        qty = math.max(1, math.floor(qty))
        if state.total and state.total > 0 then qty = math.min(qty, state.total) end
        local a = api()
        if not a.StartCommoditiesPurchase then return end
        local ok = pcall(a.StartCommoditiesPurchase, state.itemID, qty)
        if not ok then say(ns.Text("buyFailed")); return end
        openDialog({ kind = "commodity", itemID = state.itemID, qty = qty })
    else
        if not api().PlaceBid then return end
        openDialog({ kind = "item", itemID = state.itemID, qty = row.qty, total = row.total, unit = row.price, auctionID = row.auctionID, link = row.link })
    end
end
-- The cheapest offers that make up qty (own offers left out).
-- Returns the rows (with how many of each), the quantity found and its total price.
local function cheapestRows(qty)
    local picked, got, total = {}, 0, 0
    for _, r in ipairs(state.rows) do
        if got >= qty then break end
        local free = r.qty - (r.owned or 0)
        if not r.own and free > 0 then
            if state.commodity then
                local take = math.min(free, qty - got)
                picked[#picked + 1] = r; got = got + take; total = total + take * r.price
            else
                -- an auction is bought whole
                picked[#picked + 1] = r; got = got + r.qty; total = total + (r.total or r.price * r.qty)
            end
        end
    end
    return picked, got, total
end
function T.UpdateEstimate()
    if not P or state.view ~= "detail" then return end
    local qty = math.max(1, math.floor(tonumber(P.qty:GetText()) or 1))
    local _, got, total = cheapestRows(qty)
    if got == 0 then T.SetStatus(nil); return end
    local text = string.format(ns.Text("buyCheapestEst"), got, ns.MoneyShort(total))
    if got < qty then text = text .. "\n" .. string.format(ns.Text("buyCheapestShort"), got) end
    T.SetStatus(text)
end
function T.BuyCheapest()
    if not T.IsOpen() or state.view ~= "detail" then return end
    local qty = math.max(1, math.floor(tonumber(P.qty:GetText()) or 1))
    local picked, got, total = cheapestRows(qty)
    if got == 0 then say(ns.Text("buyNoResults")); return end
    if state.commodity then
        local a = api()
        if not a.StartCommoditiesPurchase then return end
        qty = math.min(qty, got)
        -- the game fills a commodity purchase from the cheapest offers itself
        local ok = pcall(a.StartCommoditiesPurchase, state.itemID, qty)
        if not ok then say(ns.Text("buyFailed")); return end
        openDialog({ kind = "commodity", itemID = state.itemID, qty = qty })
    else
        if not api().PlaceBid then return end
        local first = picked[1]
        openDialog({ kind = "item", itemID = state.itemID, qty = first.qty, total = first.total, unit = first.price, auctionID = first.auctionID,
            link = first.link, queue = picked, step = 1, queueQty = got, queueTotal = total })
    end
end
local function purchaseDone(success)
    local p = purchase
    if success and p and p.queue and p.step < #p.queue then
        p.step = p.step + 1
        local r = p.queue[p.step]
        p.qty, p.total, p.unit, p.auctionID, p.link, p.sent = r.qty, r.total, r.price, r.auctionID, r.link, false
        if D then updateDialog(); D:Show(); D:Raise() end
        return
    end
    say(ns.Text(success and "buyDone" or "buyFailed"))
    purchase = nil; closeDialog()
    if state.view == "detail" and state.key and T.IsOpen() then T.Detail(state.key, state.itemID) end
end

---------------------------------------------------------------------------
-- Panel frame
---------------------------------------------------------------------------
local function row(i)
    P.list = P.list or {}
    local b = P.list[i]
    if b then return b end
    local UI = ns.UI
    b = UI.Button(P, "", 276, function(self, mouse)
        if state.view == "browse" then
            local r = state.browse[self.index]
            if r then T.Detail(r.itemKey, r.itemID) end
        else T.Buy(self.index) end
    end)
    b:SetHeight(ROW_H - 2); b.text:Hide()
    UI.FlatRow(b)
    b.icon2 = b:CreateTexture(nil, "ARTWORK"); b.icon2:SetSize(16, 16); b.icon2:SetPoint("LEFT", 4, 0); b.icon2:SetTexCoord(.07, .93, .07, .93)
    b.left = UI.Label(b, "", 11); b.left:SetPoint("LEFT", 24, 0); b.left:SetWidth(130); if b.left.SetWordWrap then b.left:SetWordWrap(false) end
    b.mid = UI.Label(b, "", 10); b.mid:SetPoint("LEFT", 150, 0); b.mid:SetWidth(40); b.mid:SetJustifyH("RIGHT")
    b.mid:SetTextColor(unpack(UI.Theme.muted))
    b.right = UI.Label(b, "", 11); b.right:SetPoint("RIGHT", -8, 0); b.right:SetWidth(84); b.right:SetJustifyH("RIGHT")
    b:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local r = state.view == "browse" and state.browse[self.index] or state.rows[self.index]
        local id = state.view == "browse" and r and r.itemID or state.itemID
        if ns.HoldTooltipTag then ns.HoldTooltipTag(GameTooltip) end
        if r and r.link then GameTooltip:SetHyperlink(r.link) elseif id then GameTooltip:SetItemByID(id) end
        if state.view == "detail" and r then
            if r.owner then GameTooltip:AddLine(ns.Text("buySeller") .. ": " .. r.owner, .65, .72, .78) end
            GameTooltip:AddLine(state.commodity and ns.Text("buyHintCommodity") or ns.Text("buyHintItem"), .94, .72, .42, true)
        end
        if ns.NoteTooltipLines then ns.NoteTooltipLines(GameTooltip) end   -- this panel is ours: always name it
        if ns.ReleaseTooltipTag then ns.ReleaseTooltipTag(GameTooltip) end
        GameTooltip:Show()
    end)
    b:HookScript("OnLeave", function() GameTooltip:Hide() end)
    P.list[i] = b
    return b
end
local function visibleRows()
    return math.max(4, math.floor((P:GetHeight() - 176) / ROW_H))
end
function T.RenderPanel()
    if not P or not P:IsShown() then return end
    local UI = ns.UI
    P.title:SetText(ns.Text("buyTitle"))
    P.go.text:SetText(ns.T("search"))
    P.back.text:SetText("← " .. ns.Text("buyBack"))
    P.qtyLabel:SetText(ns.Text("buyQty"))
    local detail = state.view == "detail"
    local list = detail and state.rows or state.browse
    P.back:SetShown(detail)
    P.qtyLabel:SetShown(detail); P.qty:SetShown(detail)
    P.shiftHint:Hide()
    P.cheapest:SetShown(detail); P.cheapest.text:SetText(ns.Text("buyCheapestBtn"))
    if detail then UI.Primary(P.cheapest, #state.rows > 0) end
    P.itemLabel:ClearAllPoints()
    if detail then
        P.itemLabel:SetPoint("LEFT", P.back, "RIGHT", 8, 0)
        P.itemLabel:SetText(itemName(state.itemID) .. (state.total and state.total > 0 and ("  |cffa7b9c5×" .. state.total .. "|r") or ""))
    else
        P.itemLabel:SetPoint("TOPLEFT", 12, -74)
        P.itemLabel:SetText(state.query ~= "" and (state.query .. "  |cffa7b9c5" .. #state.browse .. "|r") or ns.Text("buyIntro"))
    end
    P.headLeft:SetText(detail and ns.Text("buyUnit") or ns.T("name"))
    P.headMid:SetText(ns.Text("buyQty"))
    P.headRight:SetText(detail and ns.Text("buySeller") or ns.Text("buyUnit"))
    local count = visibleRows()
    state.offset = math.max(0, math.min(state.offset, math.max(0, #list - count)))
    for i = 1, count do
        local b = row(i)
        local index = state.offset + i
        local r = list[index]
        if r then
            b.index = index
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 12, -148 - (i - 1) * ROW_H); b:SetWidth(P:GetWidth() - 24)
            if detail then
                b.icon2:Hide()
                b.left:ClearAllPoints(); b.left:SetPoint("LEFT", 6, 0)
                b.left:SetText(ns.MoneyShort(r.price))
                b.mid:SetText(r.qty)
                b.right:SetText(r.own and ("|cff7ddc8a" .. ns.Text("buyOwnShort") .. "|r") or (r.owner or ""))
            else
                local info = keyInfo(r.itemKey)
                b.icon2:SetTexture((info and info.iconFileID) or itemIcon(r.itemID)); b.icon2:Show()
                b.left:ClearAllPoints(); b.left:SetPoint("LEFT", 24, 0)
                local q = info and num(info.quality)
                local color = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
                local name = (info and plainName(info.itemName)) or itemName(r.itemID)
                b.left:SetText(color and color.hex and (color.hex .. name .. "|r") or name)
                b.mid:SetText(r.qty)
                b.right:SetText(ns.MoneyShort(r.price))
            end
            UI.PaintRow(b, index, false); b:Show()
        else b:Hide() end
    end
    for i = count + 1, #(P.list or {}) do P.list[i]:Hide() end
    P.status:SetText(state.status or "")
end
function T.CreatePanel()
    local UI = ns.UI
    local ah = ahFrame()
    P = UI.Frame("Frame", "EzWoWBagsAuctionPanel", UIParent)
    P:SetSize(310, 520); P:EnableMouse(true); P:SetClampedToScreen(true)
    UI.Surface(P)
    P.brand = P:CreateTexture(nil, "ARTWORK"); P.brand:SetSize(20, 20); P.brand:SetPoint("TOPLEFT", 10, -7)
    P.brand:SetTexture("Interface\\AddOns\\EzWoW-Bags\\Media\\Icon")
    P.title = UI.Label(P, "", 13); P.title:SetPoint("TOPLEFT", 36, -11); P.title:SetTextColor(unpack(UI.Theme.accent))
    P.line = P:CreateTexture(nil, "ARTWORK"); P.line:SetPoint("TOPLEFT", 1, -33); P.line:SetPoint("TOPRIGHT", -1, -33)
    P.line:SetHeight(2); P.line:SetColorTexture(unpack(UI.Theme.accent))
    P.close = UI.CloseButton(P, function() P.dismissed = true; P:Hide() end)
    P.close:ClearAllPoints(); P.close:SetPoint("TOPRIGHT", -6, -5); P.close:SetSize(22, 22)
    P.search = UI.Edit(P, 200); P.search:SetPoint("TOPLEFT", 12, -42)
    P.search:SetScript("OnEnterPressed", function(self) self:ClearFocus(); T.Browse(self:GetText()) end)
    P.go = UI.Button(P, "", 76, function() P.search:ClearFocus(); T.Browse(P.search:GetText()) end)
    P.go:SetPoint("LEFT", P.search, "RIGHT", 6, 0)
    P.back = UI.Button(P, "", 74, function()
        state.view, state.offset, state.status = "browse", 0, nil; T.RenderPanel()
    end)
    P.back:SetPoint("TOPLEFT", 12, -72); P.back:SetHeight(22)
    P.itemLabel = UI.Label(P, "", 12); P.itemLabel:SetWidth(200); if P.itemLabel.SetWordWrap then P.itemLabel:SetWordWrap(false) end
    P.qtyLabel = UI.Label(P, "", 11); P.qtyLabel:SetPoint("TOPLEFT", 14, -106)
    P.qty = UI.Edit(P, 56, 22); P.qty:SetPoint("TOPLEFT", 64, -100); P.qty:SetNumeric(true); P.qty:SetText("1")
    P.qty:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    P.qty:SetScript("OnTextChanged", function(_, user) if user then T.UpdateEstimate() end end)
    P.cheapest = UI.Button(P, "", 150, function() P.qty:ClearFocus(); T.BuyCheapest() end)
    P.cheapest:SetPoint("LEFT", P.qty, "RIGHT", 8, 0); P.cheapest:SetHeight(22)
    P.shiftHint = UI.Label(P, "", 10); P.shiftHint:SetPoint("LEFT", P.qty, "RIGHT", 8, 0); P.shiftHint:SetWidth(170)
    P.shiftHint:SetTextColor(unpack(UI.Theme.muted))
    UI.HeadBand(P, -127)
    P.headLeft = UI.Label(P, "", 10); P.headLeft:SetPoint("TOPLEFT", 18, -132); P.headLeft:SetTextColor(unpack(UI.Theme.muted))
    P.headMid = UI.Label(P, "", 10); P.headMid:SetPoint("TOPLEFT", 150, -132); P.headMid:SetWidth(52); P.headMid:SetJustifyH("RIGHT")
    P.headMid:SetTextColor(unpack(UI.Theme.muted))
    P.headRight = UI.Label(P, "", 10); P.headRight:SetPoint("TOPRIGHT", -18, -132); P.headRight:SetJustifyH("RIGHT")
    P.headRight:SetTextColor(unpack(UI.Theme.muted))
    P.status = UI.Label(P, "", 11); P.status:SetPoint("BOTTOMLEFT", 12, 10); P.status:SetWidth(286)
    P.status:SetJustifyV("BOTTOM"); P.status:SetTextColor(unpack(UI.Theme.muted))
    P:EnableMouseWheel(true)
    P:SetScript("OnMouseWheel", function(_, delta)
        state.offset = math.max(0, state.offset - delta * 3); T.RenderPanel()
    end)
    P:SetScript("OnShow", function() T.RenderPanel() end)
    P:Hide()
    if ah then T.Dock(ah) end
end
-- for the sell list: the panel it lives in, and the item being sold right now
function T.GetPanel() return P end
-- the item open in the buy panel (its listings view), for the price tab
function T.CurrentItemID() return state.view == "detail" and tonumber(state.itemID) or nil end
function T.SellInfo() return sell end
function T.ActiveSellFrame() return activeSellFrame() end
function T.IsCommodity(loc) return isCommodity(loc) end

function T.Dock(ah)
    if not P or not ah then return end
    P:ClearAllPoints(); P:SetPoint("TOPLEFT", ah, "TOPRIGHT", 4, 0)
    local h = ah:GetHeight()
    if h and h > 300 then P:SetHeight(h) end
    -- above the bag window, which often stands right of the auction house
    P:SetFrameStrata("DIALOG")
    if P.SetToplevel then P:SetToplevel(true) end
    P:Raise()
end
-- force: opened for a search even when the panel is not shown automatically.
function T.ShowPanel(force)
    if not T.IsOpen() then return end
    if not P then T.CreatePanel() end
    if not force and (not ns.cfg.ahBuyPanel or P.dismissed) then return end
    P.dismissed = nil
    T.Dock(ahFrame())
    if not P:IsShown() then P:Show() end
end
-- The game's own auction list: an item picked there opens here too (and in the
-- price window). The game has already sent its search, so no query of our own
-- goes out - its results reach this panel through the same events.
local function searchResultsReady(itemKey, itemID, commodity)
    local a = api()
    if commodity then
        local ok, n = pcall(a.GetNumCommoditySearchResults, itemID)
        return ok and (num(n) or 0) > 0
    end
    local ok, n = pcall(a.GetNumItemSearchResults, itemKey)
    return ok and (num(n) or 0) > 0
end
function T.Follow(itemKey)
    if type(itemKey) ~= "table" or not T.IsOpen() then return end
    T.ShowPanel()
    if not (P and P:IsShown()) then return end
    local itemID = num(itemKey.itemID)
    if not itemID then return end
    local info = keyInfo(itemKey)
    state.view, state.key, state.itemID, state.rows, state.offset = "detail", itemKey, itemID, {}, 0
    state.commodity = info and info.isCommodity
    state.waitDetail = true
    T.SetStatus(ns.Text("buySearching"))
    T.RenderPanel()
    -- results the game already had arrive with no new event: read them shortly
    C_Timer.After(0.5, function()
        if not (state.waitDetail and state.itemID == itemID) then return end
        if not searchResultsReady(itemKey, itemID, state.commodity) then return end
        if state.commodity then detailEvent(itemID, nil) else detailEvent(nil, itemKey) end
    end)
end

local function hookFrame()
    local ah = ahFrame()
    if not ah or T.hooked then return ah ~= nil end
    T.hooked = true
    if type(ah.SelectBrowseResult) == "function" then
        hooksecurefunc(ah, "SelectBrowseResult", function(_, browseResult)
            local key = type(browseResult) == "table" and browseResult.itemKey
            if key and ns.ready then pcall(T.Follow, key) end
        end)
    end
    ah:HookScript("OnShow", function() if ns.ready and ns.cfg.ahBuyPanel then T.ShowPanel() end end)
    ah:HookScript("OnHide", function() if P then P:Hide() end; closeDialog() end)
    return true
end
local function onShow(tries)
    if not ns.ready then return end
    if not hookFrame() then
        if (tries or 0) < 20 and C_Timer then C_Timer.After(.1, function() onShow((tries or 0) + 1) end) end
        return
    end
    if P then P.dismissed = nil end
    if ns.cfg.ahBuyPanel then T.ShowPanel() end
end
function T.ApplyOptions()
    if not P then return end
    if ns.cfg.ahBuyPanel then T.ShowPanel() elseif P:IsShown() and state.view == "browse" and state.query == "" then P:Hide() end
end

---------------------------------------------------------------------------
-- Clicks on bag items
---------------------------------------------------------------------------
-- Ctrl+Alt+click: lock / unlock (right button: account-wide).
-- With the auction house open, Alt+click: sell; Alt+right-click: search in the buy panel.
-- True when handled.
function T.OnBagClick(bag, slot, mouse)
    if not ns.ready or type(bag) ~= "number" or type(slot) ~= "number" or not API.IsPlayerBag(bag) then return false end
    local alt, ctrl, shift = IsAltKeyDown and IsAltKeyDown(), IsControlKeyDown and IsControlKeyDown(), IsShiftKeyDown and IsShiftKeyDown()
    if not alt or shift then return false end
    if ctrl and not ns.cfg.itemLock then return false end
    if not ctrl and not T.IsOpen() then return false end
    local key = bag .. ":" .. slot .. ":" .. tostring(mouse) .. (ctrl and ":lock" or "")
    -- The same physical click can arrive through more than one hook.
    if last.key == key and now() - last.at < .3 then return true end
    last.key, last.at = key, now()
    if ctrl then
        local item = API.Item(bag, slot)
        if item and item.id then ns.Locks.Toggle(item.id, mouse == "RightButton") end
        return true
    end
    if mouse == "RightButton" then return T.SearchBagItem(bag, slot) end
    return T.Sell(bag, slot)
end
if type(HandleModifiedItemClick) == "function" and hooksecurefunc then
    hooksecurefunc("HandleModifiedItemClick", function(_, itemLocation)
        if not ns.ready or type(itemLocation) ~= "table" or type(itemLocation.IsBagAndSlot) ~= "function" then return end
        local ok, isBag = pcall(itemLocation.IsBagAndSlot, itemLocation)
        if not ok or not isBag then return end
        local ok2, bag, slot = pcall(itemLocation.GetBagAndSlot, itemLocation)
        if not ok2 then return end
        local mouse = GetMouseButtonClicked and GetMouseButtonClicked() or "LeftButton"
        T.OnBagClick(bag, slot, mouse)
    end)
end

-- Shift+click on an item (bags, chat links, ...) puts its name in the buy
-- panel's search box and searches, like the game's own search box: when that
-- box has the focus, or when the panel is open and no chat line is being typed.
local function chatTyping()
    local box = (ChatEdit_GetActiveWindow and ChatEdit_GetActiveWindow())
        or (ChatFrameUtil and ChatFrameUtil.GetActiveWindow and ChatFrameUtil.GetActiveWindow())
    return box ~= nil and box:IsShown()
end
local function linkToSearch(link)
    if not (P and P:IsShown() and P.search) or type(link) ~= "string" or secret(link) then return end
    if not P.search:HasFocus() and chatTyping() then return end
    local name = link:match("%[(.-)%]")
    if not name or name == "" then return end
    -- one click can reach both hooks
    if P.lastLinkName == name and now() - (P.lastLinkAt or 0) < 0.3 then return end
    P.lastLinkName, P.lastLinkAt = name, now()
    P.search:SetText(name)
    P.search:ClearFocus()
    T.Browse(name)
end
for _, owner in ipairs({ _G, ChatFrameUtil or {} }) do
    local fnName = owner == _G and "ChatEdit_InsertLink" or "InsertLink"
    if type(owner[fnName]) == "function" then
        hooksecurefunc(owner, fnName, function(link) pcall(linkToSearch, link) end)
    end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
for _, event in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "AUCTION_HOUSE_THROTTLED_SYSTEM_READY",
    "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
    "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "ITEM_KEY_ITEM_INFO_RECEIVED",
    "COMMODITY_PRICE_UPDATED", "COMMODITY_PRICE_UNAVAILABLE", "COMMODITY_PURCHASE_SUCCEEDED", "COMMODITY_PURCHASE_FAILED",
    "AUCTION_HOUSE_PURCHASE_COMPLETED", "AUCTION_HOUSE_SHOW_ERROR", "PLAYER_MONEY" }) do
    pcall(events.RegisterEvent, events, event)
end
events:SetScript("OnEvent", function(_, event, a1, a2)
    if not ns.ready then return end
    if event == "AUCTION_HOUSE_SHOW" then ns.state.auction = true; onShow(0)
    elseif event == "AUCTION_HOUSE_CLOSED" then
        sell, pendingQuery, state.autoDetail = nil, nil, nil
        closeDialog(); cancelPurchase()
        if P then P:Hide() end
    elseif event == "AUCTION_HOUSE_THROTTLED_SYSTEM_READY" then
        if pendingQuery then local fn = pendingQuery; pendingQuery = nil; T.Send(fn) end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        if state.waitBrowse and P and P:IsShown() and state.view == "browse" then
            if event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then state.status = nil end
            readBrowse()
        end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        local id = num(a1); sellResultsEvent(id, nil); detailEvent(id, nil)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        sellResultsEvent(nil, a1); detailEvent(nil, a1)
    elseif event == "ITEM_KEY_ITEM_INFO_RECEIVED" then
        if P and P:IsShown() then T.RenderPanel() end
    elseif event == "COMMODITY_PRICE_UPDATED" then
        local p = purchase
        if p and p.kind == "commodity" and not p.sent then
            p.total = num(a2) or (num(a1) and num(a1) * p.qty)
            updateDialog()
        end
    elseif event == "COMMODITY_PRICE_UNAVAILABLE" then
        if purchase and purchase.kind == "commodity" and not purchase.sent then
            say(ns.Text("buyUnavailable")); purchase = nil; closeDialog()
        end
    elseif event == "COMMODITY_PURCHASE_SUCCEEDED" then
        if purchase and purchase.kind == "commodity" then purchaseDone(true) end
    elseif event == "COMMODITY_PURCHASE_FAILED" then
        if purchase and purchase.kind == "commodity" then purchaseDone(false) end
    elseif event == "AUCTION_HOUSE_PURCHASE_COMPLETED" then
        if purchase and purchase.kind == "item" then purchaseDone(true) end
    elseif event == "AUCTION_HOUSE_SHOW_ERROR" then
        if purchase and purchase.sent then purchaseDone(false) end
    elseif event == "PLAYER_MONEY" then
        if purchase and not purchase.sent then updateDialog() end
    end
end)
events:SetScript("OnUpdate", function()
    if sell then sellTick() end
end)
