local _, ns = ...
local Search = {}; ns.Search = Search
local rarity = { poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5,
    ["일반"] = 1, ["고급"] = 2, ["희귀"] = 3, ["영웅"] = 4, ["전설"] = 5 }
local function tokens(text)
    if #text > 512 then error("512 characters maximum", 0) end
    local out, i = {}, 1
    while i <= #text do
        local ch = text:sub(i, i)
        if ch:match("%s") then i = i + 1
        elseif ch == "(" or ch == ")" then out[#out + 1] = ch; i = i + 1
        else
            local value, quote = "", nil
            while i <= #text do
                ch = text:sub(i, i)
                if quote then
                    if ch == quote then quote = nil else value = value .. ch end
                elseif ch == '"' or ch == "'" then quote = ch
                elseif ch:match("%s") or ch == "(" or ch == ")" then break
                else value = value .. ch end
                i = i + 1
            end
            if quote then error("unclosed quote", 0) end
            if value ~= "" then out[#out + 1] = value end
        end
        if #out > 128 then error("too many terms", 0) end
    end
    return out
end
local function compare(a, op, b)
    if op == "=" or op == "==" then return a == b
    elseif op == "!=" or op == "~=" then return a ~= b
    elseif op == ">" then return a > b
    elseif op == "<" then return a < b
    elseif op == ">=" then return a >= b
    elseif op == "<=" then return a <= b end
    return false
end
local function term(value)
    local field, op, rhs = value:match("^([%a]+)([!~=<>]+)(.+)$")
    if not field then
        local needle = value:lower()
        return function(e) return (e.searchText or e.name or ""):lower():find(needle, 1, true) ~= nil end
    end
    field, rhs = field:lower(), rhs:lower()
    if op ~= "=" and op ~= "==" and op ~= "!=" and op ~= "~=" and op ~= ">" and op ~= "<" and op ~= ">=" and op ~= "<=" then error("invalid operator", 0) end
    if field == "name" or field == "type" then
        if op ~= "=" and op ~= "!=" and op ~= "~=" then error("text fields use = or !=", 0) end
        return function(e)
            local found = (e[field] or ""):lower():find(rhs, 1, true) ~= nil
            if op == "=" then return found end
            return not found
        end
    end
    local fields = { ilvl = "level", rarity = "quality", quality = "quality", count = "count", id = "id" }
    local key = fields[field]
    if not key then error("unknown field: " .. field, 0) end
    local number = tonumber(rhs) or (key == "quality" and rarity[rhs])
    if not number then error("invalid number or rarity: " .. rhs, 0) end
    return function(e) return compare(e[key] or -1, op, number) end
end
function Search.Compile(text)
    text = text or ""
    local ok, result = pcall(function()
        local ts, pos, depth = tokens(text), 1, 0
        local parseOr, parseAnd, parseAtom
        local function peek(word) return ts[pos] and ts[pos]:upper() == word end
        parseAtom = function()
            depth = depth + 1
            if depth > 24 then error("expression too deep", 0) end
            local node
            if peek("NOT") then
                pos = pos + 1; local child = parseAtom(); node = function(e) return not child(e) end
            elseif ts[pos] == "(" then
                pos = pos + 1; node = parseOr()
                if ts[pos] ~= ")" then error("missing )", 0) end
                pos = pos + 1
            else
                local word = ts[pos]
                if not word or word == ")" or peek("AND") or peek("OR") then error("missing search term", 0) end
                pos = pos + 1
                -- Also accept: ilvl > 50 and name = "Linen Cloth".
                if ts[pos] and ts[pos]:match("^[!~=<>]+$") then
                    if not ts[pos + 1] then error("missing field value", 0) end
                    word = word .. ts[pos] .. ts[pos + 1]; pos = pos + 2
                end
                node = term(word)
            end
            depth = depth - 1
            return node
        end
        parseAnd = function()
            local node = parseAtom()
            while ts[pos] and ts[pos] ~= ")" and not peek("OR") do
                if peek("AND") then pos = pos + 1 end
                local left, right = node, parseAtom()
                node = function(e) return left(e) and right(e) end
            end
            return node
        end
        parseOr = function()
            local node = parseAnd()
            while peek("OR") do
                pos = pos + 1; local left, right = node, parseAnd()
                node = function(e) return left(e) or right(e) end
            end
            return node
        end
        if #ts == 0 then return function() return true end end
        local root = parseOr()
        if ts[pos] then error("unexpected " .. ts[pos], 0) end
        return root
    end)
    if ok then return result end
    return nil, ns.TranslateError and ns.TranslateError(result) or result
end
