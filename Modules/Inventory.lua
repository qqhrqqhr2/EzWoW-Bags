local _, ns = ...
local API = ns.API
local scanTooltip
local tooltipCache = {}
ns.waitingInventory = {}
ns.professions = {
    [171] = { "연금", "Alchemy" }, [164] = { "대장", "Smithing" },
    [165] = { "가죽", "Leather" }, [197] = { "재봉", "Tailoring" },
    [202] = { "기공", "Engineering" }, [333] = { "마부", "Enchanting" },
    [185] = { "요리", "Cooking" }, [129] = { "응급", "First Aid" },
    [186] = { "채광", "Mining" }, [755] = { "보석", "Jewels" },
    [182] = { "약초", "Herbalism" }, [356] = { "낚시", "Fishing" }, [393] = { "무두", "Skinning" },
}
function ns.ProfessionText(id)
    local row = ns.professions[id]
    if not row then return tostring(id) end
    return row[(ns.cfg.language == "koKR" or (ns.cfg.language == "auto" and GetLocale() == "koKR")) and 1 or 2]
end
function ns.Enrich(e)
    local name, link, quality, level, _, itemType, subType, _, equipLoc, icon, sellPrice, classID, subClassID, bindType = API.Info(e.link or e.id)
    if not classID or not equipLoc then
        local _, instantType, instantSub, instantLoc, instantIcon, instantClass, instantSubclass = API.Instant(e.link or e.id)
        itemType, subType, equipLoc = itemType or instantType, subType or instantSub, equipLoc or instantLoc
        icon, classID, subClassID = icon or instantIcon, classID or instantClass, subClassID or instantSubclass
    end
    if not classID then
        local classFn = (C_Item and C_Item.GetItemClassInfo) or GetItemClassInfo
        if classFn then
            for _, id in ipairs({ 0, 2, 4, 7, 9, 12, 13 }) do
                if classFn(id) == itemType then classID = id; break end
            end
        end
    end
    e.link = e.link or link or ("item:" .. tostring(e.id))
    e.name, e.quality, e.level = name or e.name or ("#" .. e.id), quality or e.quality or 1, level or e.level or 0
    e.type, e.subType, e.classID, e.subClassID = itemType or e.type or "", subType or e.subType or "", classID or e.classID, subClassID or e.subClassID
    e.icon, e.equipLoc, e.sellPrice = icon or e.icon, equipLoc or e.equipLoc, sellPrice or e.sellPrice
    e.bindType = bindType or e.bindType
    local uses, text = ns.ReagentUses[e.id], {}
    if uses then for _, skill in ipairs(uses) do text[#text + 1] = ns.ProfessionText(skill) end end
    e.professionText = table.concat(text, "/")
    e.searchText = table.concat({ e.name, e.type, e.subType, e.professionText, e.quest and ns.T("quest") or "" }, " ")
    return e
end
local function tooltipFlags(e)
    local key = e.link .. ":" .. tostring(e.bound)
    local cached = tooltipCache[key]
    if cached then
        e.quest, e.bound, e.bindType = e.quest or cached.quest, e.bound or cached.bound, cached.bindType or e.bindType
        return
    end
    if not scanTooltip then
        scanTooltip = CreateFrame("GameTooltip", "EzWoWBagsScanner", UIParent, "GameTooltipTemplate")
    end
    scanTooltip:SetOwner(UIParent, "ANCHOR_NONE"); scanTooltip:ClearLines()
    scanTooltip:SetBagItem(e.bag, e.slot)
    local bind, bound = ITEM_BIND_ON_EQUIP, ITEM_SOULBOUND
    for i = 2, scanTooltip:NumLines() do
        local fs = _G["EzWoWBagsScannerTextLeft" .. i]
        local text = fs and fs:GetText()
        if text and (not issecretvalue or not issecretvalue(text)) then
            if bind and text == bind then e.bindType = 2 end
            if bound and text == bound then e.bound = true end
            if ITEM_BIND_QUEST and text == ITEM_BIND_QUEST then e.quest = true end
        end
    end
    scanTooltip:Hide()
    if e.name ~= "#" .. e.id then tooltipCache[key] = { quest = e.quest, bound = e.bound, bindType = e.bindType } end
end
function ns.ScanStorage(storage)
    if storage == "bank" and not ns.state.bank then return end
    local bagIDs = API.Bags(storage)
    if storage == "bank" then
        local total = 0
        for _, bag in ipairs(bagIDs) do total = total + API.Slots(bag) end
        if total == 0 then ns.Dirty(); return end -- Preserve the cache while payloads arrive.
    end
    local snapshot = { items = {}, free = {}, containers = {}, time = time(), layout = API.ModernBank() and "tabs" or "legacy" }
    local isBag = storage == "bags"
    for _, bag in ipairs(bagIDs) do
        local slots = API.Slots(bag)
        local free, family = API.Free(bag)
        if slots > 0 then
            local container = { bag = bag, slots = slots, free = free or 0, family = family or 0, icon = API.BagIcon(bag) }
            container.kind = ns.BagKind(container, storage)
            snapshot.containers[#snapshot.containers + 1] = container
        end
        for slot = 1, slots do
            local item = API.Item(bag, slot)
            if item and item.id and item.link then
                item.bag, item.slot = bag, slot
                local questFn = API.Container("GetContainerItemQuestInfo")
                if questFn then
                    local quest = questFn(bag, slot)
                    item.quest = type(quest) == "table" and (quest.isQuestItem == true or quest.isQuestItem == 1 or quest.questID ~= nil) or quest == true or quest == 1
                end
                ns.Enrich(item)
                if item.name == "#" .. item.id then ns.waitingInventory[item.id] = true end
                tooltipFlags(item)
                if isBag then
                    if ns.hasInitialScan and GetTime() >= (ns.baselineUntil or 0) and not ns.seen[item.id] then ns.newItems[item.id] = true end
                    ns.seen[item.id] = true
                end
                snapshot.items[#snapshot.items + 1] = item
            elseif not item then
                snapshot.free[#snapshot.free + 1] = { bag = bag, slot = slot, empty = true, count = 0, family = family or 0 }
            end
        end
    end
    if isBag then
        local total = API.Container("CalculateTotalNumberOfFreeBagSlots")
        if total then
            local ok, count = pcall(total)
            if ok and type(count) == "number" and count >= 0 then snapshot.totalFree = count end
        end
    end
    local char = ns.db.characters[ns.player] or { realm = ns.realm }
    char.guid = UnitGUID and UnitGUID("player") or char.guid
    if UnitClass then local _, class = UnitClass("player"); char.class = class end
    if UnitRace then local _, race = UnitRace("player"); char.race = race end
    if UnitSex then char.sex = UnitSex("player") end
    char[storage], char.money, char.seen = snapshot, GetMoney(), time()
    ns.db.characters[ns.player] = char
    if isBag then ns.hasInitialScan = true end
    return snapshot
end
function ns.BagKind(container, storage)
    if container.kind then return container.kind end
    if storage == "bags" then
        if container.bag == API.Keyring() then return "keys" end
        if container.bag == API.ReagentBag() then return "reagent" end
    end
    return (container.family or 0) ~= 0 and "special" or "general"
end
function ns.FreeSpace(snapshot, storage)
    local summary = { general = 0, reagent = 0, special = 0, keys = 0 }
    local containers = snapshot and snapshot.containers or {}
    if #containers > 0 then
        for _, container in ipairs(containers) do
            local kind = ns.BagKind(container, storage)
            summary[kind] = summary[kind] + (container.free or 0)
        end
    else
        for _, slot in ipairs(snapshot and snapshot.free or {}) do
            local kind = ns.BagKind(slot, storage)
            summary[kind] = summary[kind] + 1
        end
    end
    summary.total = summary.general + summary.reagent + summary.special
    if storage == "bags" and snapshot and snapshot.totalFree ~= nil then summary.total = snapshot.totalFree end
    return summary
end
function ns.BagBarContainers(snapshot, storage)
    local out = {}
    for _, container in ipairs(snapshot and snapshot.containers or {}) do out[#out + 1] = container end
    local function rank(container)
        local kind = ns.BagKind(container, storage)
        if kind == "keys" then return -2 end
        if kind == "reagent" then return -1 end
        return 4 - container.bag
    end
    table.sort(out, function(a, b)
        if storage == "bank" then return a.bag < b.bag end
        return rank(a) < rank(b)
    end)
    return out
end
function ns.Snapshot()
    local char = ns.db.characters[ns.selected]
    return char and char[ns.storage]
end
function ns.CachedCounts(id)
    local out = {}
    for key, char in pairs(ns.db.characters) do
        if char.realm == ns.realm then
            local bags, bank = 0, 0
            for _, e in ipairs(char.bags and char.bags.items or {}) do if e.id == id then bags = bags + e.count end end
            for _, e in ipairs(char.bank and char.bank.items or {}) do if e.id == id then bank = bank + e.count end end
            if bags + bank > 0 then out[#out + 1] = { key = key, bags = bags, bank = bank, bankTime = char.bank and char.bank.time } end
        end
    end
    table.sort(out, function(a, b) return a.key < b.key end)
    return out
end
function ns.Category(e)
    local assigned = ns.cfg.assignments[e.id]
    if assigned then
        for _, c in ipairs(ns.cfg.custom) do if c.id == assigned then return assigned end end
    end
    for _, c in ipairs(ns.cfg.custom) do
        if c.query and c.query ~= "" then
            ns.customPredicates = ns.customPredicates or {}
            local cached = ns.customPredicates[c.id]
            if not cached or cached.query ~= c.query then
                cached = { query = c.query, match = ns.Search.Compile(c.query) }
                ns.customPredicates[c.id] = cached
            end
            local match = cached.match
            if match and match(e) then return c.id end
        end
    end
    if ns.cfg.newSection and ns.storage == "bags" and ns.selected == ns.player and ns.newItems[e.id] then return "new" end
    if e.quest or e.classID == 12 then return "quest" end
    if e.bag == API.Keyring() or e.classID == 13 then return "keys" end
    if e.quality == 0 then return "junk" end
    if e.classID == 9 then return "recipe" end
    if API.IsEquipment(e) then return "equipment" end
    if e.classID == 0 then return "consumable" end
    if ns.ReagentUses[e.id] or e.classID == 7 then return "materials" end
    return "other"
end
function ns.ItemTag(e)
    if e.quest or e.classID == 12 then return ns.T("questTag") end
    if e.bindType == 2 and not e.bound then return ns.T("boe") end
    if e.classID == 9 then return ns.T("recipeTag") end
    return e.professionText or ""
end
