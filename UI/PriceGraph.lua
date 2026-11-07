local _, ns = ...
-- Line graph of an item's daily minimum auction price over the last 30 days, with the listed
-- quantity as thin bars. Drawn with plain textures and line objects in the window's colors.
local G = {}; ns.PriceGraph = G
G.DAYS, G.HEIGHT = 30, 178
local PAD_L, PAD_R, PAD_T, PAD_B = 74, 14, 36, 22

local function pool(owner, key, make)
    owner[key] = owner[key] or {}
    local list = owner[key]
    local used = 0
    return function()
        used = used + 1
        local obj = list[used]
        if not obj then obj = make(); list[used] = obj end
        obj:Show()
        return obj
    end, function()
        for i = used + 1, #list do list[i]:Hide() end
    end
end
local function dayLabel(day) return date("%m/%d", day * 86400 + 43200) end

function G.Create(parent)
    local UI = ns.UI
    local f = UI.Frame("Frame", nil, parent)
    UI.Surface(f, .06, .085, .11, .98)
    f:SetHeight(G.HEIGHT)
    f.icon = f:CreateTexture(nil, "ARTWORK"); f.icon:SetSize(20, 20); f.icon:SetPoint("TOPLEFT", 8, -7)
    f.icon:SetTexCoord(.07, .93, .07, .93)
    f.title = UI.Label(f, "", 12); f.title:SetPoint("LEFT", f.icon, "RIGHT", 6, 0)
    if f.title.SetWordWrap then f.title:SetWordWrap(false) end
    f.summary = UI.Label(f, "", 11); f.summary:SetPoint("TOPRIGHT", -36, -11); f.summary:SetJustifyH("RIGHT")
    f.close = UI.Button(f, "×", 22, function() ns.PriceCatalog.selected = nil; ns.Refresh() end)
    f.close:SetPoint("TOPRIGHT", -6, -6); f.close:SetHeight(20)
    f.plot = CreateFrame("Frame", nil, f)
    f.plot:SetPoint("TOPLEFT", PAD_L, -PAD_T); f.plot:SetPoint("BOTTOMRIGHT", -PAD_R, PAD_B)
    f.empty = UI.Label(f, "", 11); f.empty:SetPoint("CENTER", f.plot, "CENTER"); f.empty:SetTextColor(unpack(UI.Theme.muted))
    f.hover = f.plot:CreateTexture(nil, "BACKGROUND", nil, 2); f.hover:SetColorTexture(.94, .72, .42, .12); f.hover:Hide()
    f:Hide()
    return f
end

local function showTip(zone)
    local f, p = zone.graph, zone.point
    f.hover:ClearAllPoints()
    f.hover:SetPoint("TOP", f.plot, "TOPLEFT", zone.x, 0); f.hover:SetPoint("BOTTOM", f.plot, "BOTTOMLEFT", zone.x, 0)
    f.hover:SetWidth(math.max(3, zone:GetWidth())); f.hover:Show()
    GameTooltip:SetOwner(zone, "ANCHOR_TOP")
    GameTooltip:AddLine(dayLabel(zone.day), 1, 1, 1)
    if p then
        GameTooltip:AddDoubleLine(ns.Text("graphPrice"), ns.Money(p.price), .65, .72, .78, 1, 1, 1)
        if p.qty then GameTooltip:AddDoubleLine(ns.Text("graphQty"), p.qty, .65, .72, .78, 1, 1, 1) end
    else GameTooltip:AddLine(ns.Text("graphNoRecord"), .65, .72, .78) end
    GameTooltip:Show()
end

function G.Draw(f, id)
    local UI = ns.UI
    local plot = f.plot
    local name = ns.API.Info(id)
    local _, _, _, _, icon = ns.API.Instant(id)
    f.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    f.title:SetText((name or ("#" .. id)) .. "  |cff8398a6" .. ns.Text("graphTitle") .. "|r")
    f.title:SetWidth(math.max(80, f:GetWidth() - 260))
    local today = ns.History.Day()
    local first = today - G.DAYS + 1
    local byDay, points = {}, {}
    for _, p in ipairs(ns.History.Points(id)) do
        if p.day >= first and p.day <= today then byDay[p.day] = p; points[#points + 1] = p end
    end
    local price, pct = ns.History.Trend(id)
    local trend = ns.History.TrendText(id)
    f.summary:SetText(price and (ns.MoneyShort(price) .. (trend and ("  " .. trend) or "")) or "")
    local width, height = plot:GetWidth(), plot:GetHeight()
    local nextTex, doneTex = pool(f, "textures", function() return plot:CreateTexture(nil, "ARTWORK") end)
    local nextLabel, doneLabel = pool(f, "labels", function()
        local l = UI.Label(f, "", 9); l:SetTextColor(unpack(UI.Theme.muted)); return l
    end)
    local nextLine, doneLine = pool(f, "lines", function()
        return plot.CreateLine and plot:CreateLine(nil, "OVERLAY") or plot:CreateTexture(nil, "OVERLAY")
    end)
    local nextZone, doneZone = pool(f, "zones", function()
        local z = CreateFrame("Frame", nil, plot); z.graph = f
        z:EnableMouse(true)
        z:SetScript("OnEnter", showTip)
        z:SetScript("OnLeave", function() f.hover:Hide(); GameTooltip:Hide() end)
        return z
    end)
    local function finish() doneTex(); doneLabel(); doneLine(); doneZone() end
    -- Frame: bottom axis and three price guides.
    local axis = nextTex(); axis:SetColorTexture(unpack(UI.Theme.border)); axis:ClearAllPoints()
    axis:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", 0, 0); axis:SetPoint("BOTTOMRIGHT", plot, "BOTTOMRIGHT", 0, 0); axis:SetHeight(1)
    if width <= 10 or height <= 10 then
        -- Not laid out yet (first show): draw again on the next update.
        f.empty:Hide(); finish()
        f.retries = (f.retries or 0) + 1
        if f.retries <= 5 then ns.viewDirty = true end
        return
    end
    f.retries = 0
    f.empty:SetShown(#points == 0)
    if #points == 0 then
        f.empty:SetText(ns.Text("graphEmpty"))
        finish(); return
    end
    local lo, hi = math.huge, 0
    for _, p in ipairs(points) do lo, hi = math.min(lo, p.price), math.max(hi, p.price) end
    if hi == lo then lo, hi = lo * .9, hi * 1.1 + 1 end
    local span = hi - lo
    lo, hi = math.max(0, lo - span * .12), hi + span * .12
    local maxQty = 0
    for _, p in ipairs(points) do maxQty = math.max(maxQty, p.qty or 0) end
    local step = width / (G.DAYS - 1)
    local function X(day) return (day - first) * step end
    local function Y(value) return (value - lo) / (hi - lo) * height end
    for i = 0, 2 do
        local value = lo + (hi - lo) * (i / 2)
        local guide = nextTex(); guide:SetColorTexture(.204, .298, .357, .45); guide:ClearAllPoints()
        guide:SetPoint("BOTTOMLEFT", plot, "BOTTOMLEFT", 0, Y(value)); guide:SetPoint("BOTTOMRIGHT", plot, "BOTTOMLEFT", width, Y(value)); guide:SetHeight(1)
        local label = nextLabel(); label:ClearAllPoints(); label:SetJustifyH("RIGHT"); label:SetWidth(PAD_L - 8)
        label:SetPoint("RIGHT", plot, "BOTTOMLEFT", -6, Y(value)); label:SetText(ns.MoneyShort(value, 9))
    end
    for _, day in ipairs({ first, first + math.floor(G.DAYS / 2), today }) do
        local label = nextLabel(); label:ClearAllPoints(); label:SetWidth(50); label:SetJustifyH("CENTER")
        label:SetPoint("TOP", plot, "BOTTOMLEFT", X(day), -4); label:SetText(dayLabel(day))
    end
    -- Quantity bars at the bottom (up to a third of the height).
    if maxQty > 0 then
        local barWidth = math.max(2, step * .45)
        for _, p in ipairs(points) do
            if p.qty and p.qty > 0 then
                local bar = nextTex(); bar:SetColorTexture(.29, .45, .55, .55); bar:ClearAllPoints()
                bar:SetSize(barWidth, math.max(1, p.qty / maxQty * height * .33))
                bar:SetPoint("BOTTOM", plot, "BOTTOMLEFT", X(p.day), 1)
            end
        end
    end
    -- Price line and points.
    local accent = UI.Theme.accent
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        local line = nextLine()
        if line.SetStartPoint then
            line:SetColorTexture(accent[1], accent[2], accent[3], .9); line:SetThickness(2)
            line:SetStartPoint("BOTTOMLEFT", plot, X(a.day), Y(a.price)); line:SetEndPoint("BOTTOMLEFT", plot, X(b.day), Y(b.price))
        else line:Hide() end
    end
    for _, p in ipairs(points) do
        local dot = nextTex(); dot:SetColorTexture(1, .86, .6, 1); dot:ClearAllPoints(); dot:SetSize(5, 5)
        dot:SetPoint("CENTER", plot, "BOTTOMLEFT", X(p.day), Y(p.price))
    end
    -- One hover column per day.
    for day = first, today do
        local zone = nextZone(); zone:ClearAllPoints()
        zone:SetSize(math.max(3, step), height)
        zone:SetPoint("BOTTOM", plot, "BOTTOMLEFT", X(day), 0)
        zone.day, zone.point, zone.x = day, byDay[day], X(day)
    end
    finish()
end
