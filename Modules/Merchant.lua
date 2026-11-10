local _, ns = ...
local API = ns.API
-- Automatic junk selling and repair when a merchant opens (hold Shift while opening to skip).
local Merchant = {}; ns.Merchant = Merchant

local SELL_BATCH = 10            -- items sold per tick (the server rejects large single-frame bursts)
local SELL_INTERVAL = .25
local SWEEP_BASE_DELAY, SWEEP_MAX_DELAY = .4, 1.6
local SWEEP_MAX_PASSES, SWEEP_MAX_STALLS = 12, 3
local POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0

-- Selling is allowed by the merchant interaction, not by the frame: at MERCHANT_SHOW the merchant
-- window may not be shown yet, so the interaction is tracked here.
local merchantOpen = false
local current -- the running sweep; an older sweep stops when a new one starts

local function after(delay, fn)
    if C_Timer and C_Timer.After then C_Timer.After(delay, fn) else fn() end
end
local function eachBagSlot(fn)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, API.Slots(bag) do fn(bag, slot) end
    end
end
local function slotLink(bag, slot)
    local item = API.Item(bag, slot)
    return item and item.link or nil
end
-- A sellable grey item: link, stack, unit price. A grey item whose price is not cached yet
-- asks the client to load it and returns the 4th value true so it can be retried.
local function junkSlot(bag, slot)
    local item = API.Item(bag, slot)
    if not item or not item.link or item.locked or ns.Locks.IsLocked(item.id) then return nil end
    local _, _, infoQuality, _, _, _, _, _, _, _, sellPrice = API.Info(item.link)
    local quality = item.quality or infoQuality
    if quality ~= POOR then return nil end
    if sellPrice == nil then
        if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, item.link) end
        return nil, nil, nil, true
    end
    if sellPrice > 0 and API.Sellable(bag, slot) then return item.link, item.count or 1, sellPrice end
end
local function begin()
    current = { seen = {}, reported = false }
    return current
end
-- Counts sellable grey items (and slots whose quality is not known yet), remembering each one
-- so the report can tell what was really sold.
local function countJunk(sweep)
    local junk, unknown = 0, 0
    eachBagSlot(function(bag, slot)
        local item = API.Item(bag, slot)
        if not item or not item.id or ns.Locks.IsLocked(item.id) then return end
        if item.quality == nil then
            unknown = unknown + 1
        elseif item.quality == POOR and API.Sellable(bag, slot) then
            junk = junk + 1
            local key = bag * 1000 + slot
            if sweep and not sweep.seen[key] then
                local link, stack, price = junkSlot(bag, slot)
                if link then sweep.seen[key] = { bag = bag, slot = slot, link = link, stack = stack, price = price } end
            end
        end
    end)
    return junk, unknown
end
-- Prints the total of the items that actually left the bags and, when asked, what is left.
local function report(sweep, reportLeft)
    if not sweep or sweep.reported then return end
    sweep.reported = true
    local count, copper = 0, 0
    for _, rec in pairs(sweep.seen) do
        if slotLink(rec.bag, rec.slot) ~= rec.link then
            count, copper = count + rec.stack, copper + rec.price * rec.stack
        end
    end
    if count > 0 and copper > 0 then ns.Print(ns.Text("autoSellDone"):format(count, ns.Money(copper))) end
    if reportLeft and merchantOpen then
        local left = countJunk(nil)
        if left > 0 then ns.Print("|cffe77c70" .. ns.Text("autoSellLeft"):format(left) .. "|r") end
    end
    ns.Dirty()
end

-- Per-item selling for clients without the bulk junk-sell call.
function Merchant.SellOneByOne(isRetry)
    local sweep = begin()
    local queue, uncached = {}, false
    eachBagSlot(function(bag, slot)
        local link, stack, price, pending = junkSlot(bag, slot)
        if link then
            queue[#queue + 1] = { bag = bag, slot = slot, link = link }
            sweep.seen[bag * 1000 + slot] = { bag = bag, slot = slot, link = link, stack = stack, price = price }
        elseif pending then
            uncached = true
        end
    end)
    -- grey items whose price was not cached yet get one more pass once the data has loaded
    local retry = uncached and not isRetry
    local function finish()
        -- the server answers sell requests later: count what left the bags after a short wait
        after(1, function()
            if sweep ~= current then return end
            report(sweep, not retry)
            if retry and merchantOpen then Merchant.SellOneByOne(true) end
        end)
    end
    if #queue == 0 then return finish() end
    local use = API.Container("UseContainerItem")
    local cursor = 1
    local function step()
        if sweep ~= current then return end
        if not merchantOpen then return finish() end
        local sent = 0
        while cursor <= #queue and sent < SELL_BATCH do
            local q = queue[cursor]; cursor = cursor + 1
            -- re-check: the player (or another addon) may have sold or moved it already
            if use and junkSlot(q.bag, q.slot) == q.link then pcall(use, q.bag, q.slot); sent = sent + 1 end
        end
        if cursor <= #queue then after(SELL_INTERVAL, step) else finish() end
    end
    step()
end

-- Bulk junk sell. One SellAllJunkItems call is fire-and-forget: requests past the server rate
-- limit are dropped and items whose data is not cached yet are skipped, so re-count after each
-- pass and send again while the count keeps falling.
function Merchant.SellAll()
    local sweep = begin()
    sweep.passes, sweep.lastCount, sweep.stalls, sweep.delay = 0, math.huge, 0, SWEEP_BASE_DELAY
    local function pass()
        if sweep ~= current then return end
        if not merchantOpen then return report(sweep, false) end
        local junk, unknown = countJunk(sweep)
        if junk == 0 and unknown == 0 then return report(sweep, false) end
        sweep.passes = sweep.passes + 1
        if junk > sweep.lastCount then
            -- uncached slots turned into newly visible junk: progress, not a stall
            sweep.stalls, sweep.delay = 0, SWEEP_BASE_DELAY
        elseif junk == sweep.lastCount then
            -- nothing moved: an unsellable item or a dropped request, so back off before giving up
            sweep.stalls = sweep.stalls + 1
            sweep.delay = math.min(sweep.delay * 2, SWEEP_MAX_DELAY)
            if sweep.stalls >= SWEEP_MAX_STALLS then return report(sweep, true) end
        else
            sweep.stalls, sweep.delay = 0, SWEEP_BASE_DELAY
        end
        sweep.lastCount = junk
        if junk > 0 then pcall(C_MerchantFrame.SellAllJunkItems) end
        if sweep.passes >= SWEEP_MAX_PASSES then
            -- the last request is still in flight: check once more after it lands
            after(sweep.delay, function() if sweep == current then report(sweep, true) end end)
            return
        end
        after(sweep.delay, pass)
    end
    pass()
end

function Merchant.Repair()
    if type(CanMerchantRepair) ~= "function" or type(GetRepairAllCost) ~= "function" or type(RepairAllItems) ~= "function" then return end
    if not CanMerchantRepair() then return end
    local cost, canRepair = GetRepairAllCost()
    if not canRepair or not cost or cost <= 0 then return end
    if (GetMoney and GetMoney() or 0) >= cost then
        -- its own line below; the money log leaves this change out
        if ns.MoneyLog then ns.MoneyLog.Mute("cost", 1.5) end
        pcall(RepairAllItems)
        ns.Print(ns.Text("autoRepairDone"):format(ns.Money(cost)))
    else
        ns.Print("|cffe77c70" .. ns.Text("autoRepairNoGold") .. "|r")
    end
end

-- The money log leaves out what these two print themselves.
local function autoSelling() return current ~= nil and not current.reported end
if ns.MoneyLog then ns.MoneyLog.gainMuted = autoSelling end

function Merchant.OnShow()
    merchantOpen = true
    if IsShiftKeyDown and IsShiftKeyDown() then return end
    if ns.cfg.autoSellJunk then
        if C_MerchantFrame and C_MerchantFrame.SellAllJunkItems and C_Container and C_Container.GetContainerItemInfo
            and C_Timer and C_Timer.After then
            Merchant.SellAll()
        else
            Merchant.SellOneByOne()
        end
    end
    if ns.cfg.autoRepair then Merchant.Repair() end
end

function Merchant.OnClosed()
    merchantOpen = false
end
