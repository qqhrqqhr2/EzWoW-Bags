local _, ns = ...
local AH = {}; ns.Auction = AH
local function now() return GetTime() end
function AH.Changed()
    AH.revision = (AH.revision or 0) + 1
    ns.viewDirty = true
end
function AH.Message(message, quiet)
    AH.status = message
    if not quiet then ns.Print(message) end
    ns.Refresh()
end
function AH.NativeCount()
    if not C_AuctionHouse or not C_AuctionHouse.GetNumReplicateItems then return 0 end
    local ok, count = pcall(C_AuctionHouse.GetNumReplicateItems)
    return ok and tonumber(count) or 0
end
function AH.TooltipActive()
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if loaded then return loaded("EzWoW-Tooltip") and true or false end
    return _G.EzWoW_Tooltip ~= nil
end
local function syncPricesWork()
    if not ns.db or not AH.TooltipActive() or type(EzWoW_TooltipDB) ~= "table" then return end
    local tooltip = EzWoW_TooltipDB
    tooltip.auctionPrices = type(tooltip.auctionPrices) == "table" and tooltip.auctionPrices or {}
    tooltip.auctionTimes = type(tooltip.auctionTimes) == "table" and tooltip.auctionTimes or {}
    tooltip.EzWoWBagsPriceScopes = type(tooltip.EzWoWBagsPriceScopes) == "table" and tooltip.EzWoWBagsPriceScopes or {}
    local market = ns.db.markets[ns.market] or { items = {} }
    market.items = market.items or {}
    local changed, latest, keys = false, market.updatedTime or 0, {}
    local processed = 0
    local function yieldBatch()
        processed = processed + 1
        if processed >= 128 or (AH.syncSliceStart and debugprofilestop() - AH.syncSliceStart >= 1.5) then
            processed = 0; coroutine.yield()
        end
    end
    for key, unit in pairs(tooltip.auctionPrices) do
        local id, price = tonumber(key), tonumber(unit)
        if id and id > 0 and price and price > 0 then
            keys[id] = key
            local stamp = tonumber(tooltip.auctionTimes[key])
            local old = market.items[id]
            local scope = tooltip.EzWoWBagsPriceScopes[id]
            local otherMarket = scope and scope.market ~= ns.market and scope.unit == price and scope.time == stamp
            -- Tooltip owns collection while enabled. On same-second ties its committed quote wins.
            if not otherMarket and (not old or (stamp and (not old.time or stamp >= old.time))) then
                if not old or old.unit ~= price or old.time ~= stamp then
                    market.items[id] = { unit = price, time = stamp, source = "EzWoW Tooltip", mode = "shared" }
                    changed = true
                end
                if not scope or scope.market ~= ns.market or scope.unit ~= price or scope.time ~= stamp then
                    tooltip.EzWoWBagsPriceScopes[id] = { market = ns.market, unit = price, time = stamp }
                end
            end
            if not otherMarket then latest = math.max(latest, stamp or 0) end
        end
        yieldBatch()
    end
    for id, price in pairs(market.items) do
        local key = keys[id] or id
        local oldStamp = tonumber(tooltip.auctionTimes[key])
        local scope = tooltip.EzWoWBagsPriceScopes[id]
        if not tooltip.auctionPrices[key] or (scope and scope.market ~= ns.market) or (price.time and (not oldStamp or price.time > oldStamp)) then
            tooltip.auctionPrices[key], tooltip.auctionTimes[key] = price.unit, price.time
            tooltip.EzWoWBagsPriceScopes[id] = { market = ns.market, unit = price.unit, time = price.time }
            changed = true
        end
        latest = math.max(latest, price.time or 0)
        yieldBatch()
    end
    if latest > 0 then market.updatedTime = latest end
    if latest > (tonumber(tooltip.auctionLastScan) or 0) then tooltip.auctionLastScan = latest end
    ns.db.markets[ns.market] = market
    if changed then AH.Changed() end
end
function AH.SyncPrices()
    local source = EzWoW_TooltipDB
    if not ns.db or not AH.TooltipActive() or type(source) ~= "table" then AH.syncWork = nil; return end
    local context = AH.syncContext
    if AH.syncWork and (not context or context.market ~= ns.market or context.source ~= source or context.prices ~= source.auctionPrices or context.times ~= source.auctionTimes) then AH.syncWork = nil end
    if not AH.syncWork then
        source.auctionPrices = type(source.auctionPrices) == "table" and source.auctionPrices or {}
        source.auctionTimes = type(source.auctionTimes) == "table" and source.auctionTimes or {}
        AH.syncContext = { market = ns.market, source = source, prices = source.auctionPrices, times = source.auctionTimes }
        AH.syncWork = coroutine.create(syncPricesWork)
    end
    AH.syncSliceStart = debugprofilestop and debugprofilestop()
    local ok, err = coroutine.resume(AH.syncWork)
    if not ok then AH.syncWork = nil; AH.status = tostring(err); return end
    if coroutine.status(AH.syncWork) == "dead" then AH.syncWork = nil end
end
local function legacyEntry(index)
    local name, _, count, _, _, _, r7, _, r9, r10, _, _, _, _, _, _, itemID, complete = GetAuctionItemInfo("list", index)
    local link = GetAuctionItemLink and GetAuctionItemLink("list", index)
    itemID = tonumber(itemID) or (link and tonumber(link:match("item:(%d+)")))
    -- Older tuple has minBid at 7, buyout at 9; current tuple has levelColHeader at 7.
    local buyout = type(r7) == "number" and r9 or r10
    return name, count, buyout, itemID, complete
end
function AH.DecodeLegacy(index) return legacyEntry(index) end
function AH.Stop(message)
    AH.job = nil
    if message then AH.status = message; ns.Print(message) end
    ns.Refresh()
end
local function finish()
    local job = AH.job
    if not job then return end
    local market = ns.db.markets[ns.market] or { items = {} }
    market.items = market.items or {}
    local stamp, count = job.snapshotTime or time(), 0
    if job.snapshotTime == false then stamp = nil end -- Pre-existing native results may have an unknown age.
    for id, price in pairs(job.result) do
        if not job.filter or job.filter[id] then
            local previous = market.items[id]
            if not previous or (stamp and (not previous.time or stamp >= previous.time)) then
                market.items[id] = { unit = price, time = stamp, mode = job.mode }
            end
            count = count + 1
        end
    end
    if count == 0 then AH.Stop(ns.Text("ahEmpty")); return end
    if job.mode == "full" and stamp then market.fullScan = stamp end
    if job.replicate then market.replicaTime, market.replicaCount = stamp, job.count end
    ns.db.markets[ns.market] = market
    AH.Changed()
    local message = ns.T("done") .. ": " .. tostring(count)
    if (job.skipped or 0) > 0 then message = message .. " · " .. ns.Text("ahPartial") .. " " .. job.skipped end
    if job.passive then AH.status = message; AH.Stop() else AH.Stop(message) end
end
local function requestReplicate(job)
    local api = C_AuctionHouse
    if api.IsThrottledMessageSystemReady and not api.IsThrottledMessageSystemReady() then
        AH.status = ns.Text("ahBusy"); return
    end
    job.pendingReplicate, job.waiting = nil, true
    local ok, err = pcall(api.ReplicateItems)
    if not ok then AH.Stop(tostring(err)); return end
    local market = ns.db.markets[ns.market] or { items = {} }
    market.requested = time(); ns.db.markets[ns.market] = market
    AH.status = ns.Text("ahWaiting")
end
function AH.IsOpen()
    return ns.state.auction or (AuctionHouseFrame and AuctionHouseFrame:IsShown()) or (AuctionFrame and AuctionFrame:IsShown())
end
local function sendQuery(job)
    if not ns.state.auction then AH.Stop(); return end
    local can, all = CanSendAuctionQuery()
    if (job.mode == "full" and not all) or (job.mode ~= "full" and not can) then return end
    local name = job.mode == "bags" and job.queue[job.queueIndex] or ""
    if not name then finish(); return end
    if #name > 63 then AH.Stop(ns.Text("ahUnsupported")); return end
    job.waiting, job.pending, job.deadline = true, false, now() + 30
    AH.sending = true
    local ok, err = pcall(QueryAuctionItems, name, nil, nil, job.page, nil, nil, job.mode == "full", job.mode == "bags", nil)
    AH.sending = false
    if not ok then AH.Stop(tostring(err)) end
end
function AH.Start(mode)
    if AH.TooltipActive() then
        AH.SyncPrices(); AH.Message(ns.Text("ahShared"), true); return
    end
    if AH.job then return end
    if not AH.IsOpen() then AH.Message(ns.Text("ahClosed")); return end
    ns.state.auction = true
    AH.status = ns.Text("ahWaiting")
    mode = mode == "bags" and "bags" or "full"
    if C_AuctionHouse and C_AuctionHouse.ReplicateItems and C_AuctionHouse.GetReplicateItemInfo and C_AuctionHouse.GetNumReplicateItems then
        local market = ns.db.markets[ns.market]
        local job = { mode = mode, replicate = true, pendingReplicate = true, result = {}, deadline = now() + 30 }
        if mode == "bags" then
            job.filter = {}
            local char = ns.db.characters[ns.player]
            for _, e in ipairs(char and char.bags and char.bags.items or {}) do job.filter[e.id] = true end
        end
        local nativeCount = AH.NativeCount()
        if nativeCount > 0 then
            job.pendingReplicate, job.waiting = nil, true; AH.job = job
            if not AH.replicaReady then
                AH.replicaTime = market and market.replicaCount == nativeCount and market.replicaTime or false
            end
            AH.status = ns.Text("ahCached")
            AH.Results(true, true) -- Reuse this open session's native snapshot, including its original time.
        else AH.job = job; requestReplicate(job) end
    else
        if not QueryAuctionItems or not CanSendAuctionQuery or not GetAuctionItemInfo or not GetNumAuctionItems then AH.Message(ns.Text("ahUnsupported")); return end
        local can, all = CanSendAuctionQuery()
        if (mode == "full" and not all) or (mode ~= "full" and not can) then AH.Message(ns.Text("ahBusy")); return end
        local job = { mode = mode, result = {}, queue = {}, queueIndex = 1, page = 0 }
        if mode == "bags" then
            local seen = {}
            local char = ns.db.characters[ns.player]
            for _, e in ipairs(char and char.bags and char.bags.items or {}) do
                local name = ns.API.Info(e.link)
                if name and not seen[name] then seen[name] = true; job.queue[#job.queue + 1] = name end
            end
            table.sort(job.queue)
        end
        AH.job = job; sendQuery(job)
    end
    ns.Refresh()
end
function AH.Results(replicate, cached)
    local job = AH.job
    -- The event can precede the payload. A zero-length intermediate result is not completion.
    if replicate and AH.NativeCount() <= 0 then return end
    if replicate and ns.state.auction then
        if not cached then AH.replicaReady, AH.replicaTime = true, time() end
        -- Share the result of Tooltip or the native UI's full scan without making a second request.
        if not job and AH.TooltipActive() then return end
        if not job then
            job = { mode = "full", replicate = true, waiting = true, result = {}, passive = true }
            AH.job = job
        elseif job.pendingReplicate then job.pendingReplicate, job.waiting = nil, true end
        if not cached and job.replicate then job.snapshotTime = AH.replicaTime end
    end
    if not job or not job.waiting or not not job.replicate ~= not not replicate then return end
    local count, total
    if replicate then count = C_AuctionHouse.GetNumReplicateItems(); total = count
    else count, total = GetNumAuctionItems("list") end
    if (count or 0) == 0 and (total or 0) > 0 then return end
    job.waiting, job.reading = false, true
    job.count, job.total, job.index, job.retry = count or 0, total or count or 0, 1, 0
    job.pendingRows, job.retryPass = {}, 0
    job.pageResult, job.deadline = {}, now() + 30
    if replicate then job.snapshotTime = AH.replicaTime else job.snapshotTime = nil end
end
local function readRow(j, index)
    local function read()
        if not j.replicate then return legacyEntry(index) end
        local a = { C_AuctionHouse.GetReplicateItemInfo(index - 1) }
        local id = tonumber(a[17])
        if not id and C_AuctionHouse.GetReplicateItemLink then
            local link = C_AuctionHouse.GetReplicateItemLink(index - 1)
            id = link and tonumber(link:match("item:(%d+)"))
        end
        return a[1], a[3], a[10], id, a[18]
    end
    local ok, _, count, buyout, id = pcall(read)
    if not ok or not id or type(count) ~= "number" or type(buyout) ~= "number" then return false end
    if count > 0 and buyout > 0 then
        local unit = buyout / count
        if not j.pageResult[id] or unit < j.pageResult[id] then j.pageResult[id] = unit end
    end
    return true
end
function AH.Tick()
    local j = AH.job
    if not j then return end
    if AH.TooltipActive() then AH.Stop(ns.Text("ahShared")); AH.SyncPrices(); return end
    if not ns.state.auction then AH.Stop(); return end
    if j.deadline and now() > j.deadline then AH.Stop(ns.Text("timeout")); return end
    if j.pendingReplicate then requestReplicate(j); return end
    if j.pending then sendQuery(j); return end
    if j.replicate and j.waiting and AH.NativeCount() > 0 then
        -- Also poll: other addons can receive the native result before our event handler runs.
        AH.Results(true); j = AH.job
    end
    if not j.reading then return end
    if j.retryAt then
        if now() < j.retryAt then return end
        j.retryAt = nil; j.retryPass = j.retryPass + 1
        local pending = {}
        for _, index in ipairs(j.pendingRows) do if not readRow(j, index) then pending[#pending + 1] = index end end
        j.pendingRows = pending
    end
    local limit = math.min(j.count, j.index + 199)
    while j.index <= limit do
        if not readRow(j, j.index) then j.pendingRows[#j.pendingRows + 1] = j.index end
        j.index, j.retry = j.index + 1, 0
    end
    j.deadline = now() + 30 -- Large full scans may take longer than one network timeout in total.
    if ns.window and ns.window:IsShown() and ns.mode == "prices" then
        ns.window.status:SetText(ns.T("scan") .. " · " .. math.min(j.index - 1, j.count) .. "/" .. j.count)
    end
    if j.index <= j.count then return end
    if #j.pendingRows > 0 and j.retryPass < 3 then j.retryAt = now() + .5; return end
    j.skipped = (j.skipped or 0) + #j.pendingRows
    for id, price in pairs(j.pageResult) do
        if not j.result[id] or price < j.result[id] then j.result[id] = price end
    end
    j.reading = false
    if j.mode == "bags" and not j.replicate then
        if (j.page + 1) * 50 < j.total and j.count > 0 then j.page = j.page + 1
        else j.queueIndex, j.page = j.queueIndex + 1, 0 end
        if not j.queue[j.queueIndex] then finish(); return end
        j.pending, j.deadline = true, now() + 30
    else finish() end
end
function AH.InstallHook()
    if QueryAuctionItems and hooksecurefunc then
        hooksecurefunc("QueryAuctionItems", function()
            if AH.job and not AH.sending and not AH.job.replicate then AH.Stop(ns.T("stop")) end
        end)
    end
end
