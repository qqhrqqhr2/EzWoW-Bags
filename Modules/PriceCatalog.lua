local _, ns = ...
local Catalog = {}; ns.PriceCatalog = Catalog
-- Use item class IDs, never the positional indexes of legacy auction menus.
local classes = { {2,"무기","Weapon","equipment"}, {4,"방어구","Armor","equipment"},
    {1,"가방","Container","bags"}, {0,"소모품","Consumable","consumable"},
    {7,"직업용품","Trade Goods","materials"}, {9,"제조법","Recipe","recipe"},
    {6,"투사체","Projectile","other"}, {11,"화살통","Quiver","bags"},
    {3,"보석","Gem","materials"}, {12,"퀘스트","Quest","quest"}, {15,"기타","Miscellaneous","other"} }
function Catalog.Categories()
    local out = { {name = ns.T("show") .. " · " .. ns.T("grid"), icon = "prices"} }
    local classInfo = (C_Item and C_Item.GetItemClassInfo) or GetItemClassInfo
    local subInfo = (C_Item and C_Item.GetItemSubClassInfo) or GetItemSubClassInfo
    local subs = (C_AuctionHouse and C_AuctionHouse.GetAuctionItemSubClasses) or GetAuctionItemSubClasses
    local ko = ns.cfg.language == "koKR" or (ns.cfg.language == "auto" and GetLocale() == "koKR")
    for _, row in ipairs(classes) do
        local id = row[1]
        out[#out + 1] = {class = id, name = classInfo and classInfo(id) or row[ko and 2 or 3], icon = row[4]}
        if Catalog.class == id and subInfo then
            local ids = {}
            if subs then
                local ok, values = pcall(function() return {subs(id)} end)
                if ok then ids = type(values[1]) == "table" and values[1] or values end
            else
                for sub = 0, 20 do
                    local ok, label = pcall(subInfo, id, sub)
                    if ok and label and label ~= "" then ids[#ids + 1] = sub end
                end
            end
            for _, sub in ipairs(ids) do
                if type(sub) == "number" then
                    local label = subInfo(id, sub)
                    if label and label ~= "" then out[#out + 1] = {class = id, sub = sub, name = "  " .. label, icon = row[4]} end
                end
            end
        end
    end
    return out
end
function Catalog.Select(class, sub)
    Catalog.class, Catalog.sub = class, sub
    ns.scroll:SetVerticalScroll(0); ns.Refresh()
end
-- Price rows have their own cache. Building the catalog must never rescan physical bags.
function Catalog.Get(query)
    query = query or ""
    local revision = ns.Auction.revision or 0
    local current = Catalog.current
    if current and current.market == ns.market and current.revision == revision and current.query == query and current.language == ns.cfg.language and current.class == Catalog.class and current.sub == Catalog.sub then return current end
    local c = { market = ns.market, revision = revision, query = query, language = ns.cfg.language, class = Catalog.class, sub = Catalog.sub, ids = {}, rows = {}, cursor = 1, waiting = {}, seen = {} }
    Catalog.current = c
    local market = ns.db.markets[ns.market]
    for id in pairs(market and market.items or {}) do c.ids[#c.ids + 1] = id end
    table.sort(c.ids)
    if query:match("^%s*$") and c.class == nil then
        c.rows, c.done = c.ids, true -- No item-info requests are needed just to list prices.
    else
        c.predicate, c.error = ns.Search.Compile(query)
        c.done = not c.predicate
        c.startAt = GetTime() + .2 -- Debounce typing before querying item metadata.
    end
    return c
end
function Catalog.MetadataReady(id)
    local c = Catalog.current
    if not c or not c.waiting[id] then return end
    c.waiting[id] = nil
    c.ids[#c.ids + 1] = id; c.done = false
end
function Catalog.Tick()
    local c = Catalog.current
    if not c or c.done or ns.mode ~= "prices" or not ns.window or not ns.window:IsShown() then return end
    if c.startAt and GetTime() < c.startAt then return end
    local start = debugprofilestop and debugprofilestop()
    local processed, changed = 0, false
    while c.cursor <= #c.ids and processed < 16 do
        local id = c.ids[c.cursor]
        local entry = ns.Enrich({ id = id, count = 1 })
        if entry.name == "#" .. id then c.waiting[id] = true end
        if not c.seen[id] and (c.class == nil or entry.classID == c.class) and (c.sub == nil or entry.subClassID == c.sub) and c.predicate(entry) then
            c.rows[#c.rows + 1] = id; c.seen[id] = true; changed = true
        end
        c.cursor, processed = c.cursor + 1, processed + 1
        if start and debugprofilestop() - start >= 1.5 then break end
    end
    c.done = c.cursor > #c.ids
    if changed or c.done then ns.viewDirty = true end
end
