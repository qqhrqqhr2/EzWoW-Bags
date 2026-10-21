local _, ns = ...
local API = {}; ns.API = API
local function flag(value) return value == true or value == 1 end
function API.PlayerName()
    local first, second = UnitName("player")
    if NameUtil and type(NameUtil.FormatUnitNameForDisplay) == "function" then
        local ok, full = pcall(NameUtil.FormatUnitNameForDisplay, "player")
        if ok and type(full) == "string" and full ~= "" then return full end
    end
    local interface = GetBuildInfo and select(4, GetBuildInfo())
    if tonumber(interface) == 16001 and second and second ~= "" and second ~= GetRealmName() then
        return first .. " " .. second
    end
    if UnitFullName then
        local full = UnitFullName("player")
        if full and full ~= "" then return full end
    end
    return first
end
function API.Container(name)
    return (C_Container and C_Container[name]) or _G[name]
end
function API.Slots(bag)
    local fn = API.Container("GetContainerNumSlots")
    return fn and fn(bag) or 0
end
function API.Item(bag, slot)
    local fn = API.Container("GetContainerItemInfo")
    if not fn then return end
    local a, count, locked, quality, readable, lootable, link = fn(bag, slot)
    if type(a) == "table" then
        local getLink = API.Container("GetContainerItemLink")
        local itemLink = a.hyperlink or (getLink and getLink(bag, slot))
        local id = a.itemID or (itemLink and tonumber(itemLink:match("item:(%d+)")))
        itemLink = itemLink or (id and ("item:" .. id))
        return { icon = a.iconFileID, count = a.stackCount or 1, locked = flag(a.isLocked),
            quality = a.quality, link = itemLink, id = id, bound = flag(a.isBound) }
    end
    if not a then return end
    local getLink = API.Container("GetContainerItemLink")
    link = link or (getLink and getLink(bag, slot))
    return { icon = a, count = count or 1, locked = flag(locked), quality = quality,
        link = link, id = link and tonumber(link:match("item:(%d+)")) }
end
function API.Info(link)
    local fn = GetItemInfo or (C_Item and C_Item.GetItemInfo)
    if fn then return fn(link) end
end
function API.Instant(link)
    local fn = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
    if fn then return fn(link) end
end
function API.Keyring()
    return (Enum and Enum.BagIndex and Enum.BagIndex.Keyring) or KEYRING_CONTAINER or -2
end
function API.ReagentBag()
    return Enum and Enum.BagIndex and Enum.BagIndex.ReagentBag
end
function API.IsPlayerBag(bag)
    return type(bag) == "number" and ((bag >= 0 and bag <= 4) or bag == API.ReagentBag())
end
function API.ModernBank()
    return Enum and Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1 ~= nil
end
function API.BankType() return Enum and Enum.BankType and Enum.BankType.Character or 0 end
function API.BagInventory(bag)
    if API.ModernBank() and bag >= Enum.BagIndex.CharacterBankTab_1 then
        if bag > (Enum.BagIndex.CharacterBankTab_9 or Enum.BagIndex.CharacterBankTab_1 + 8) then return end
        -- The native Camelot button converts the returned zero-based inventory slot to Lua's index.
        if C_Bank and C_Bank.BankBagTypeAndIDToInvSlot then
            local slot = C_Bank.BankBagTypeAndIDToInvSlot(API.BankType(), bag - Enum.BagIndex.CharacterBankTab_1 + 1)
            return slot and slot + 1
        end
        return
    end
    if bag > 0 then
        local fn = API.Container("ContainerIDToInventoryID")
        if fn then
            local inv = fn(bag)
            if inv then return inv end
        end
        if bag <= 4 and GetInventorySlotInfo then return GetInventorySlotInfo("Bag" .. (bag - 1) .. "Slot") end
    end
end
function API.BagIcon(bag)
    if bag == API.Keyring() then return "Interface\\Icons\\INV_Misc_Key_03" end
    if bag == 0 then return API.ModernBank() and "Interface\\Icons\\ui-hud-actionbar-bag" or "Interface\\Buttons\\Button-Backpack-Up" end
    local inv = API.BagInventory(bag)
    if not inv then return end
    local icon = GetInventoryItemTexture and GetInventoryItemTexture("player", inv)
    if icon then return icon end
    local link = GetInventoryItemLink and GetInventoryItemLink("player", inv)
    if link then
        local _, _, _, _, instantIcon = API.Instant(link)
        if instantIcon then return instantIcon end
        local _, _, _, _, _, _, _, _, _, itemIcon = API.Info(link)
        return itemIcon
    end
end
local equipLocations = {}
for word in ("INVTYPE_HEAD INVTYPE_NECK INVTYPE_SHOULDER INVTYPE_BODY INVTYPE_CHEST INVTYPE_WAIST INVTYPE_LEGS INVTYPE_FEET INVTYPE_WRIST INVTYPE_HAND INVTYPE_FINGER INVTYPE_TRINKET INVTYPE_CLOAK INVTYPE_WEAPON INVTYPE_SHIELD INVTYPE_2HWEAPON INVTYPE_WEAPONMAINHAND INVTYPE_WEAPONOFFHAND INVTYPE_HOLDABLE INVTYPE_RANGED INVTYPE_THROWN INVTYPE_RANGEDRIGHT INVTYPE_RELIC INVTYPE_TABARD INVTYPE_ROBE"):gmatch("%S+") do equipLocations[word] = true end
function API.IsEquipment(e)
    return equipLocations[e.equipLoc] == true or ((not e.equipLoc or e.equipLoc == "") and (e.classID == 2 or e.classID == 4))
end
function API.Free(bag)
    local fn = API.Container("GetContainerNumFreeSlots")
    if fn then return fn(bag) end
    return 0, 0
end
function API.Bags(storage)
    if storage == "bank" then
        if API.ModernBank() then
            local out = {}
            local first = Enum.BagIndex.CharacterBankTab_1
            local last = Enum.BagIndex.CharacterBankTab_9 or first + 8
            for id = first, last do out[#out + 1] = id end
            return out
        end
        local out = { BANK_CONTAINER or -1 }
        for i = 5, 4 + (NUM_BANKBAGSLOTS or 7) do out[#out + 1] = i end
        return out
    end
    local out = { 0, 1, 2, 3, 4 }
    local reagent = API.ReagentBag()
    if reagent and reagent > 4 then out[#out + 1] = reagent end
    out[#out + 1] = API.Keyring()
    return out
end
function API.InCombat() return InCombatLockdown and InCombatLockdown() end
function API.CursorBusy() return GetCursorInfo and GetCursorInfo() ~= nil end
function API.UsableSnapshot()
    return ns.selected == ns.player and (ns.storage ~= "bank" or ns.state.bank)
end
function API.Matches(entry)
    local live = API.Item(entry.bag, entry.slot)
    return live and not live.locked and live.link == entry.link and live.count == entry.count
end
function API.CanAct(entry)
    if API.InCombat() then ns.Print(ns.Text("combat")); return false end
    if not API.UsableSnapshot() or not entry or entry.empty then return false end
    if not API.Matches(entry) then ns.Print(ns.Text("stale")); ns.Dirty(); return false end
    return true
end
function API.Use(entry)
    if not API.CanAct(entry) or API.CursorBusy() then return end
    local fn = API.Container("UseContainerItem")
    if fn then fn(entry.bag, entry.slot) end
end
function API.Pickup(entry)
    if not API.CanAct(entry) then return end
    local fn = API.Container("PickupContainerItem")
    if fn then fn(entry.bag, entry.slot) end
end
