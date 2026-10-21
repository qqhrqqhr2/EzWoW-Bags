local _, ns = ...
function ns.CategoryName(id)
    for _, c in ipairs(ns.cfg.custom) do if c.id == id then return c.name end end
    return ns.T(id)
end
function ns.CategoryConfig(id)
    local cfg = ns.cfg.categories[id]
    if type(cfg) ~= "table" then cfg = {}; ns.cfg.categories[id] = cfg end
    return cfg
end
function ns.Price(id)
    local market = ns.db.markets[ns.market]
    return market and market.items and market.items[id]
end
function ns.BuildModel(snapshot, query)
    local predicate, err = ns.Search.Compile(query)
    if not predicate then return {}, err end
    local sections, map = {}, {}
    for _, raw in ipairs(snapshot and snapshot.items or {}) do
        local e = ns.Enrich(ns.Copy(raw))
        if predicate(e) then
            local cat = ns.Category(e)
            if ns.CategoryConfig(cat).disabled then cat = "other" end
            local cfg = ns.CategoryConfig(cat)
            if not cfg.hidden and (not ns.filterCategory or ns.filterCategory == cat) then
                local section = map[cat]
                if not section then
                    section = { id = cat, name = ns.CategoryName(cat), items = {}, count = 0, value = 0, priced = 0, merged = {}, pinned = cfg.pinned }
                    map[cat] = section; sections[#sections + 1] = section
                end
                section.count = section.count + e.count
                local price = ns.Price(e.id)
                if price then section.value = section.value + price.unit * e.count; section.priced = section.priced + e.count end
                -- Full item link preserves random suffix/enchant variants; bound and unbound stacks never merge.
                local mergeKey = e.link .. ":" .. tostring(e.bound) .. ":" .. tostring(e.bindType)
                local merged = ns.cfg.merge and section.merged[mergeKey]
                if merged then
                    merged.count = merged.count + e.count; merged.sources[#merged.sources + 1] = e
                else
                    e.sources = { raw }; section.items[#section.items + 1] = e; section.merged[mergeKey] = e
                end
            end
        end
    end
    local function sortItems(a, b)
        if ns.cfg.itemSort == "quality" and a.quality ~= b.quality then return a.quality > b.quality end
        if a.name ~= b.name then return a.name < b.name end
        if a.quality ~= b.quality then return a.quality > b.quality end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end
    for _, s in ipairs(sections) do table.sort(s.items, sortItems) end
    table.sort(sections, function(a, b)
        if not not a.pinned ~= not not b.pinned then return a.pinned == true end
        if ns.cfg.sectionSort == "size" and a.count ~= b.count then return a.count > b.count end
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return sections
end
