local _, ns = ...
-- Auction price history for the price graph: per market and item one compact string of
-- "time:minUnit:quantity" records in ascending time order, separated by ";" - one record per
-- lookup (the lowest unit price seen then). Quantity may be empty when it is unknown.
-- Older saves kept one record per day ("day:minUnit:quantity"); a first field below
-- DAY_LIMIT is such a day number and is still read.
local H = {}; ns.History = H
local queue, head, tail = {}, 1, 0
local cache = {}
local DAY = 86400
local DAY_LIMIT = 1000000      -- first field below this: a day number (old one-per-day records)
local SAME_LOOKUP = 300        -- records this close together are one lookup: the later one is kept
local MAX_POINTS = 200         -- records kept per item (the oldest go first)
local function recordDay(first)
    first = tonumber(first)
    if not first then return nil end
    if first < DAY_LIMIT then return first end
    return math.floor(first / DAY)
end

function H.Day(stamp) return math.floor((tonumber(stamp) or time()) / DAY) end
function H.Keep() return math.max(30, math.min(120, tonumber(ns.cfg and ns.cfg.historyDays) or 60)) end
local function store(create)
    if not ns.db then return nil end
    if type(ns.db.history) ~= "table" then ns.db.history = {} end
    local m = ns.db.history[ns.market]
    if type(m) ~= "table" then
        if not create then return nil end
        m = {}; ns.db.history[ns.market] = m
    end
    return m
end
-- Removes leading records older than minDay; nil when nothing is left.
local function prune(s, minDay)
    while s and s ~= "" do
        local day = recordDay(s:match("^(%d+)"))
        if not day or day >= minDay then return s end
        local cut = s:find(";", 1, true)
        if not cut then return nil end
        s = s:sub(cut + 1)
    end
    return nil
end
function H.Record(id, unit, qty, stamp)
    id, unit, qty = tonumber(id), tonumber(unit), tonumber(qty)
    if not id or not unit or unit <= 0 or unit ~= unit then return end
    unit = math.floor(unit + .5)
    qty = qty and qty > 0 and math.floor(qty) or nil
    stamp = math.floor(tonumber(stamp) or time())
    local today, day = H.Day(), H.Day(stamp)
    local minDay = today - H.Keep() + 1
    if day < minDay or day > today + 1 then return end
    local m = store(true)
    if not m then return end
    local s = m[id]
    local record = stamp .. ":" .. unit .. ":" .. (qty or "")
    if type(s) ~= "string" or s == "" then m[id] = record; cache[id] = nil; return end
    local cut = s:match(".*();")
    local last = cut and s:sub(cut + 1) or s
    local lastFirst, _, lastQty = last:match("^(%d+):(%d+):(%d*)$")
    lastFirst = tonumber(lastFirst)
    if not lastFirst then
        m[id] = record
    elseif lastFirst >= DAY_LIMIT and stamp - lastFirst >= 0 and stamp - lastFirst < SAME_LOOKUP then
        -- The same lookup reported again: the later price replaces it.
        m[id] = (cut and s:sub(1, cut) or "") .. stamp .. ":" .. unit .. ":" .. (qty or lastQty or "")
    elseif (lastFirst >= DAY_LIMIT and stamp > lastFirst) or (lastFirst < DAY_LIMIT and day >= lastFirst) then
        s = prune(s .. ";" .. record, minDay) or record
        -- keep at most MAX_POINTS records
        local count = select(2, s:gsub(";", ";")) + 1
        while count > MAX_POINTS do
            local at = s:find(";", 1, true)
            if not at then break end
            s = s:sub(at + 1); count = count - 1
        end
        m[id] = s
    else return end -- Older than what is stored: the history only grows forward.
    cache[id] = nil
end
-- Many records arrive at once after a full scan; they are written a few per frame.
function H.Queue(id, unit, qty, stamp)
    tail = tail + 1
    queue[tail] = { id, unit, qty, stamp or time() }
end
function H.Tick()
    if not ns.db then return end
    if head <= tail then
        local clock = debugprofilestop
        local start, done = clock and clock(), 0
        while head <= tail do
            local r = queue[head]; queue[head] = nil; head = head + 1
            H.Record(r[1], r[2], r[3], r[4]); done = done + 1
            if (start and clock() - start >= 2) or (not start and done >= 200) then break end
        end
        if head > tail then queue, head, tail = {}, 1, 0; ns.viewDirty = true end
        return
    end
    if H.maintenance then
        local ok = coroutine.resume(H.maintenance)
        if not ok or coroutine.status(H.maintenance) == "dead" then H.maintenance = nil end
    end
end
-- Login: copy existing prices once, then drop records older than the kept number of days.
function H.Init()
    if type(ns.db.history) ~= "table" then ns.db.history = {} end
    if type(ns.db.historySeeded) ~= "table" then ns.db.historySeeded = {} end
    if not ns.db.historySeeded[ns.market] then
        ns.db.historySeeded[ns.market] = true
        local market = ns.db.markets[ns.market]
        for id, p in pairs(market and market.items or {}) do
            if type(p) == "table" and p.time then H.Queue(id, p.unit, nil, p.time) end
        end
    end
    H.maintenance = coroutine.create(function()
        local m = store(false)
        if not m then return end
        local minDay, n, ids = H.Day() - H.Keep() + 1, 0, {}
        for id in pairs(m) do ids[#ids + 1] = id end
        for _, id in ipairs(ids) do
            local s = m[id]
            local kept = type(s) == "string" and prune(s, minDay) or nil
            if kept ~= s then m[id] = kept; cache[id] = nil end
            n = n + 1
            if n % 200 == 0 then coroutine.yield() end
        end
    end)
end
-- Ascending list of { day, t, price, qty } for one item (cached until the item's string changes).
-- day: the whole day number; t: the time in days (fraction included) for the graph's x axis.
function H.Points(id)
    id = tonumber(id)
    local m = id and store(false)
    local s = m and m[id]
    if type(s) ~= "string" then return {} end
    local c = cache[id]
    if c and c.s == s and c.market == ns.market then return c.points end
    local points = {}
    for d, p, q in s:gmatch("(%d+):(%d+):(%d*)") do
        local first = tonumber(d)
        local day = recordDay(first)
        -- an old one-per-day record sits in the middle of its day
        local t = first < DAY_LIMIT and (first + 0.5) or (first / DAY)
        points[#points + 1] = { day = day, t = t, price = tonumber(p), qty = tonumber(q) }
    end
    cache[id] = { s = s, market = ns.market, points = points }
    return points
end
-- Average daily minimum over the given number of days before (and not including) `beforeDay`.
function H.Average(id, days, beforeDay)
    local points = H.Points(id)
    beforeDay = beforeDay or (H.Day() + 1)
    local sum, n = 0, 0
    for _, p in ipairs(points) do
        if p.day < beforeDay and p.day >= beforeDay - days then sum, n = sum + p.price, n + 1 end
    end
    return n > 0 and sum / n or nil, n
end
H.TREND_DAYS = 7
-- Latest price and its change against the average of the 7 days before it.
function H.Trend(id)
    local points = H.Points(id)
    local last = points[#points]
    if not last then return nil end
    local base = H.Average(id, H.TREND_DAYS, last.day)
    local pct = base and base > 0 and (last.price - base) / base * 100 or nil
    return last.price, pct, last
end
-- Short colored trend text, e.g. "▲8% (7일)". Nil without enough history.
function H.TrendText(id)
    local _, pct = H.Trend(id)
    if not pct then return nil end
    local days = string.format(ns.Text("trendDays"), H.TREND_DAYS)
    local rounded = math.floor(math.abs(pct) + .5)
    local body
    if rounded < 1 then body = "|cffa7b9c5―0%|r"
    elseif pct > 0 then body = "|cff7ddc8a▲" .. rounded .. "%|r"
    else body = "|cffe87c70▼" .. rounded .. "%|r" end
    return body .. " |cff8398a6" .. days .. "|r"
end
-- Whole line for tooltips that show no other auction price: "시세 12은 ▲8% (7일)".
function H.TrendLine(id)
    local price = H.Trend(id)
    if not price then return nil end
    local trend = H.TrendText(id)
    return "|cffa7b9c5" .. ns.T("prices") .. "|r " .. ns.MoneyShort(price) .. (trend and ("  " .. trend) or "")
end
-- Exported for EzWoW - Tooltip, which appends the trend to its own auction price line.
function ns.PriceTrendText(itemID)
    if not ns.db or not ns.cfg or not ns.cfg.tooltipTrend then return nil end
    local ok, text = pcall(H.TrendText, itemID)
    return ok and text or nil
end
