local _, ns = ...
local API = ns.API
function ns.DropCursorIntoBag(bag)
    if not API.UsableSnapshot() or API.InCombat() then return end
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return end
    local valid = false
    for _, candidate in ipairs(API.Bags(ns.storage)) do if candidate == bag then valid = true; break end end
    if not valid or API.Slots(bag) == 0 then return end
    local inv = API.BagInventory(bag)
    local put = bag == 0 and PutItemInBackpack or (bag == API.Keyring() and PutKeyInKeyRing)
    if put then put(); ns.Dirty(); return end
    if inv and PutItemInBag then PutItemInBag(inv); ns.Dirty(); return end
    local _, _, _, _, _, _, _, _, location = API.Info(id)
    if inv and EquipCursorItem and (location == "INVTYPE_BAG" or location == "INVTYPE_REAGENTBAG") then
        EquipCursorItem(inv); ns.Dirty(); return
    end
    -- Never swap an occupied slot or discard a rejected item from the cursor.
    local pickup = API.Container("PickupContainerItem")
    if pickup then
        for slot = 1, API.Slots(bag) do
            if not API.Item(bag, slot) then pickup(bag, slot); ns.Dirty(); return end
        end
    end
end
function ns.AssignItem(category)
    local exists = false
    for _, c in ipairs(ns.cfg.custom) do if c.id == category then exists = true; break end end
    if not exists then return end
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return end
    ns.cfg.assignments[id] = category
    ClearCursor(); ns.Refresh()
end
function ns.RemoveCategory(id)
    for i, c in ipairs(ns.cfg.custom) do if c.id == id then table.remove(ns.cfg.custom, i); break end end
    for item, category in pairs(ns.cfg.assignments) do if category == id then ns.cfg.assignments[item] = nil end end
    ns.cfg.categories[id], ns.filterCategory = nil, nil
    if ns.customPredicates then ns.customPredicates[id] = nil end
    ns.Refresh()
end
function ns.AddCategory(name, query)
    name = (name or ""):match("^%s*(.-)%s*$")
    if name == "" or #name > 80 then return nil, ns.Text("nameLength") end
    if #ns.cfg.custom >= 40 then return nil, ns.Text("maxCategories") end
    local _, err = ns.Search.Compile(query or "")
    if err then return nil, err end
    local id = "custom:" .. tostring(time()) .. ":" .. tostring(#ns.cfg.custom + 1)
    ns.cfg.custom[#ns.cfg.custom + 1] = { id = id, name = name, query = query or "" }
    ns.Refresh()
    return id
end
function ns.BeginMove(category, target)
    if not API.UsableSnapshot() or API.InCombat() then return end
    if target == "bank" and not ns.state.bank then return end
    if target == "mail" and not ns.state.mail then return end
    if target == "trade" and not ns.state.trade then return end
    if target == "merchant" and not ns.state.merchant then return end
    local queue = {}
    for _, raw in ipairs(ns.Snapshot() and ns.Snapshot().items or {}) do
        -- Locked items stay put when a category goes to a vendor, the mail or a trade.
        local locked = target ~= "bank" and ns.Locks.IsLocked(raw.id)
        -- Skip items already attached or held (client lock) and soulbound items the mail won't take.
        if not locked and (target == "mail" or target == "trade") then
            local live = API.Item(raw.bag, raw.slot)
            locked = (live and live.locked) or (target == "mail" and raw.bound)
        end
        if not locked and ns.Category(ns.Enrich(ns.Copy(raw))) == category then
            -- Merchant batches (a category the player picked) only include common/poor, non-quest,
            -- unassigned items with a vendor price that are not refundable.
            if target ~= "merchant" or ((raw.quality or 1) <= 1 and not raw.quest
                and not ns.cfg.assignments[raw.id] and (raw.sellPrice or 0) > 0 and API.Sellable(raw.bag, raw.slot)) then
                queue[#queue + 1] = ns.Copy(raw)
            end
        end
    end
    ns.moveQueue = #queue > 0 and { items = queue, index = 1, target = target, player = ns.player, storage = ns.storage } or nil
    ns.Refresh()
end
-- The client refused the attachment (soulbound for trade, conjured for mail...): put it back and go on.
local function skipRejected(q, e)
    ClearCursor()
    ns.Print(ns.T("stop") .. ": " .. tostring(e.name))
    q.index = q.index + 1
    if q.index > #q.items then ns.moveQueue = nil end
    ns.Refresh()
end
function ns.NextMove()
    local q = ns.moveQueue
    if not q or q.pending or API.InCombat() or API.CursorBusy() then return end
    if q.storage ~= ns.storage or ns.selected ~= ns.player then ns.moveQueue = nil; ns.Refresh(); return end
    local e = q.items[q.index]
    if not e then ns.moveQueue = nil; ns.Refresh(); return end
    if q.target == "mail" or q.target == "trade" then
        -- an entry attached by hand meanwhile is skipped instead of dropping the whole queue
        local cur = API.Item(e.bag, e.slot)
        if cur and cur.locked then
            q.index = q.index + 1
            if q.index > #q.items then ns.moveQueue = nil end
            ns.Refresh(); return
        end
    end
    if not API.CanAct(e) then ns.moveQueue = nil; ns.Refresh(); return end
    local fn = API.Container("PickupContainerItem")
    local attach
    if q.target == "bank" then
        if not ns.state.bank then return end
        local free = false
        for _, bag in ipairs(API.Bags(q.storage == "bank" and "bags" or "bank")) do
            local slots, family = API.Free(bag)
            if (slots or 0) > 0 and (family or 0) == 0 then free = true; break end
        end
        if not free then ns.Print(ns.Text("noSpace")); return end
        API.Use(e)
    elseif q.target == "merchant" then
        if not ns.state.merchant or ns.storage ~= "bags" then return end
        API.Use(e)
    elseif q.target == "mail" then
        if not ns.state.mail or ns.storage ~= "bags" or not fn or not ClickSendMailItemButton then return end
        local empty
        for i = 1, ATTACHMENTS_MAX_SEND or 12 do
            if not GetSendMailItem(i) then empty = i; break end
        end
        if not empty then return end
        attach = empty
        fn(e.bag, e.slot); ClickSendMailItemButton(empty)
        if API.CursorBusy() then return skipRejected(q, e) end
    elseif q.target == "trade" then
        if not ns.state.trade or ns.storage ~= "bags" or not fn or not ClickTradeButton then return end
        local empty
        for i = 1, 6 do if not GetTradePlayerItemInfo(i) then empty = i; break end end
        if not empty then return end
        attach = empty
        fn(e.bag, e.slot); ClickTradeButton(empty)
        if API.CursorBusy() then return skipRejected(q, e) end
    else return end
    -- A successful API call does not prove the server moved the item. Wait for a bag change.
    q.pending = { item = e, deadline = GetTime() + 5, attach = attach }
    ns.Dirty()
end
-- Mail and trade attachments stay in their bag slot, only locked. Count it moved once the slot shows it.
local function attached(q, pending, live)
    if not pending.attach or not live or not live.locked then return false end
    local get = (q.target == "mail" and GetSendMailItemLink) or (q.target == "trade" and GetTradePlayerItemLink) or nil
    local link = type(get) == "function" and get(pending.attach) or nil
    if type(link) ~= "string" or type(pending.item.link) ~= "string" then return false end
    return link:match("item:(%-?%d+)") == pending.item.link:match("item:(%-?%d+)")
end
function ns.TickMove()
    local q = ns.moveQueue
    if not q or not q.pending then return end
    local pending = q.pending
    local live = API.Item(pending.item.bag, pending.item.slot)
    if not live or live.link ~= pending.item.link or live.count ~= pending.item.count or attached(q, pending, live) then
        q.pending = nil; q.index = q.index + 1
        if q.index > #q.items then ns.moveQueue = nil end
        ns.Dirty()
    elseif GetTime() > pending.deadline then
        q.pending = nil
        ns.Print(ns.T("stop") .. ": " .. pending.item.name)
        ns.Refresh()
    end
end
