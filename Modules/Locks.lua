local _, ns = ...
-- Locked items (by item ID) are never sold to vendors, moved by bulk actions or put up for auction
-- by this addon. Locks are kept per character; an account-wide list applies to every character.
local L = {}; ns.Locks = L
local ACCOUNT = "*"
local function lists()
    if not ns.db then return nil end
    if type(ns.db.locks) ~= "table" then ns.db.locks = {} end
    return ns.db.locks
end
local function list(key, create)
    local all = lists()
    if not all then return nil end
    local t = all[key]
    if type(t) ~= "table" then
        if not create then return nil end
        t = {}; all[key] = t
    end
    return t
end
-- Returns "char", "account" or nil.
function L.Kind(id, charKey)
    id = tonumber(id)
    if not id or not ns.cfg or not ns.cfg.itemLock then return nil end
    local own = list(charKey or ns.player, false)
    if own and own[id] then return "char" end
    local account = list(ACCOUNT, false)
    if account and account[id] then return "account" end
    return nil
end
function L.IsLocked(id, charKey) return L.Kind(id, charKey) ~= nil end
-- accountWide: toggles the account-wide lock instead of this character's.
function L.Toggle(id, accountWide)
    id = tonumber(id)
    if not id or not ns.cfg.itemLock then return end
    local t = list(accountWide and ACCOUNT or ns.player, true)
    if t[id] then t[id] = nil else t[id] = true end
    -- A character lock and an account lock of the same item: unlocking removes both.
    if not t[id] then
        local other = list(accountWide and ns.player or ACCOUNT, false)
        if other then other[id] = nil end
    end
    local name = ns.API.Info(id) or ("#" .. id)
    local key = t[id] and (accountWide and "lockAccountOn" or "lockOn") or "lockOff"
    ns.Print(string.format(ns.Text(key), name))
    ns.viewDirty = true
end
function L.ClearAll()
    local all = lists()
    if not all then return end
    all[ns.player], all[ACCOUNT] = nil, nil
    ns.viewDirty = true
end
function L.Count()
    local n = 0
    for _, key in ipairs({ ns.player, ACCOUNT }) do
        for _ in pairs(list(key, false) or {}) do n = n + 1 end
    end
    return n
end
