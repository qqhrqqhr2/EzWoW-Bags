local _, ns = ...

-- The "EzWoW - ..." name line at the end of tooltip additions is drawn small.
-- Shared by the EzWoW addons: the first one loaded sets it up.
if not (_G.EzWoWTooltipTagSizer and _G.EzWoWTooltipTagSizer.version == 3) then
    local sizer = {}
    sizer.version = 3
    _G.EzWoWTooltipTagSizer = sizer
    local smallFont
    local original = setmetatable({}, { __mode = "k" })   -- font string -> its own font object
    local function tagFont()
        if not smallFont and CreateFont then
            smallFont = _G.EzWoWTooltipTagFont or CreateFont("EzWoWTooltipTagFont")
            smallFont:CopyFontObject(GameTooltipTextSmall or GameTooltipText)
            local path, _, flags = smallFont:GetFont()
            if path then smallFont:SetFont(path, 8, flags) end
        end
        return smallFont
    end
    local function isTag(text)
        if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return false end
        return text:find("^EzWoW %- ") ~= nil
    end
    local function fit(fs, tag)
        if not fs then return end
        if tag then
            if not original[fs] then original[fs] = fs:GetFontObject() or GameTooltipText end
            if tagFont() then fs:SetFontObject(smallFont) end
            fs:SetTextColor(0.5, 0.5, 0.5)
        elseif original[fs] then
            fs:SetFontObject(original[fs])
            original[fs] = nil
        end
    end
    function sizer.Refit(tip)
        local name = tip and tip.GetName and tip:GetName()
        if type(name) ~= "string" then return end
        local ok, count = pcall(tip.NumLines, tip)
        if not ok or type(count) ~= "number" or (issecretvalue and issecretvalue(count)) then return end
        for i = 1, count do
            local right = _G[name .. "TextRight" .. i]
            if right then fit(right, isTag(right:GetText())) end
            -- line 1 is the tooltip's title: a left "EzWoW - ..." there stays big
            local left = _G[name .. "TextLeft" .. i]
            if left then fit(left, i > 1 and isTag(left:GetText())) end
        end
    end
    local function restore(tip)
        local name = tip and tip.GetName and tip:GetName()
        if type(name) ~= "string" then return end
        local rightPrefix, leftPrefix = name .. "TextRight", name .. "TextLeft"
        for fs, font in pairs(original) do
            local fsName = fs.GetName and fs:GetName()
            if type(fsName) == "string" and (fsName:find(rightPrefix, 1, true) == 1 or fsName:find(leftPrefix, 1, true) == 1) then
                fs:SetFontObject(font)
                original[fs] = nil
            end
        end
    end
    for _, tip in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2 }) do
        if tip then
            pcall(hooksecurefunc, tip, "Show", function(self) pcall(sizer.Refit, self) end)
            pcall(tip.HookScript, tip, "OnTooltipCleared", function(self) pcall(restore, self) end)
        end
    end
end
local UI, API = ns.UI, ns.API
local items, headers, sidebar, bagButtons = {}, {}, {}, {}
-- Live bag/bank slots use Blizzard's secure item button so right-click can use potions,
-- food and other items (also in combat). It sits invisibly on top of the drawn slot.
local secureSlots, holders, secureCount = {}, {}, 0
-- Our own data for the template buttons and the shared tooltip is kept outside those frames.
local slotVisual = setmetatable({}, { __mode = "k" })
local tooltipItem = setmetatable({}, { __mode = "k" })
-- Attribution line under this addon's block on a game tooltip: once per display, only after
-- this addon really added lines. While a hover of this addon's own window is still adding its
-- extra lines (same frame), the line waits until those are in.
local TAG_TITLE = "EzWoW - Bags"
local tagDone = setmetatable({}, { __mode = "k" })
local tagPending = setmetatable({}, { __mode = "k" })
local tagHooked = setmetatable({}, { __mode = "k" })
local tagHold, tagHoldTime
local function tooltipLineCount(tip)
    if type(tip) ~= "table" or type(tip.NumLines) ~= "function" then return nil end
    local ok, n = pcall(tip.NumLines, tip)
    if not ok or (issecretvalue and issecretvalue(n)) or type(n) ~= "number" then return nil end
    return n
end
function ns.NoteTooltipLines(tip)
    if type(tip) ~= "table" then return end
    if not tagHooked[tip] and type(tip.HookScript) == "function" then
        tagHooked[tip] = true
        pcall(tip.HookScript, tip, "OnTooltipCleared", function(t) tagDone[t] = nil; tagPending[t] = nil end)
    end
    tagPending[tip] = true
end
function ns.FlushTooltipTag(tip)
    if type(tip) ~= "table" or not tagPending[tip] or tagDone[tip] then return false end
    if tagHold == tip and tagHoldTime == GetTime() then return false end
    if type(tip.AddDoubleLine) ~= "function" then return false end
    tagPending[tip] = nil
    tagDone[tip] = true
    tip:AddDoubleLine(" ", TAG_TITLE, 0, 0, 0, 0.5, 0.5, 0.5)
    return true
end
function ns.HoldTooltipTag(tip) tagHold, tagHoldTime = tip, GetTime() end
function ns.ReleaseTooltipTag(tip)
    if tagHold == tip then tagHold, tagHoldTime = nil, nil end
    return ns.FlushTooltipTag(tip)
end
local function bagHolder(bag)
    local h = holders[bag]
    if not h then
        h = CreateFrame("Frame", nil, ns.content); h:SetID(bag); h:SetAllPoints(ns.content)
        holders[bag] = h
    end
    return h
end
local function hideRegion(region)
    if type(region) == "table" and region.SetAlpha then region:SetAlpha(0) end
end
-- Stack total for a live slot of this window; added with the item lines (before the
-- attribution line) and again whenever the template refreshes the tooltip.
local function secureSlotStacks(tip)
    if tip ~= GameTooltip or type(tip.GetOwner) ~= "function" then return end
    local ok, owner = pcall(tip.GetOwner, tip)
    local visual = ok and type(owner) == "table" and slotVisual[owner]
    local e = visual and visual.entry
    if e and e.sources and #e.sources > 1 then
        tip:AddLine("Σ " .. e.count .. " · " .. string.format(ns.Text("stacks"), #e.sources), .65, .72, .78)
    end
end
-- Only when the item lines did not run for this display (then the stack line is added here).
local function secureExtras(self)
    if tooltipItem[GameTooltip] or not GameTooltip:IsOwned(self) then return end
    local visual = slotVisual[self]
    local e = visual and visual.entry
    if e and e.sources and #e.sources > 1 then
        GameTooltip:AddLine("Σ " .. e.count .. " · " .. string.format(ns.Text("stacks"), #e.sources), .65, .72, .78)
        GameTooltip:Show()
    end
end
-- If the window ever reports itself protected, in combat it can't be moved, resized, scaled,
-- shown or hidden; then combat updates only change counts, icons and cooldowns, and the full
-- layout runs again once combat ends. Otherwise existing item buttons are re-anchored freely.
function ns.LayoutLocked()
    local f = ns.window
    if not f or not (InCombatLockdown and InCombatLockdown()) then return false end
    return type(f.IsProtected) == "function" and f:IsProtected() and true or false
end
local function secureSlot(bag, slot)
    local key = bag .. ":" .. slot
    local b = secureSlots[key]
    if b ~= nil then return b or nil end
    -- A button made in combat can't use items, so new ones are only made out of combat (the
    -- pool below is built ahead of time); the next layout after combat adds any missing ones.
    if API.InCombat() then ns.layoutPending = true; return nil end
    secureCount = secureCount + 1
    local name = "EzWoWBagsSlot" .. secureCount
    local ok, button = pcall(CreateFrame, "ItemButton", name, bagHolder(bag), "ContainerFrameItemButtonTemplate")
    if not ok or not button then ok, button = pcall(CreateFrame, "Button", name, bagHolder(bag), "ContainerFrameItemButtonTemplate") end
    if not ok or not button then secureSlots[key] = false; return nil end
    button:SetID(slot)
    for _, region in ipairs({ button.icon, button.IconBorder, button.IconOverlay, button.IconOverlay2, button.Count, button.Stock,
        button.searchOverlay, button.ItemContextOverlay, button.NewItemTexture, button.BattlepayItemTexture, button.JunkIcon,
        button.UpgradeIcon, button.IconQuestTexture, button.ExtendedSlot, button.ItemSlotBackground, button.BagIndicator,
        _G[name .. "IconTexture"], _G[name .. "Count"], _G[name .. "IconQuestTexture"] }) do hideRegion(region) end
    if button.GetNormalTexture then hideRegion(button:GetNormalTexture()) end
    -- Post-hook only: the template's own tooltip refresh keeps running untouched.
    if type(button.UpdateTooltip) == "function" then hooksecurefunc(button, "UpdateTooltip", secureExtras) end
    button:HookScript("OnEnter", secureExtras)
    -- Post-hook: Alt / Ctrl+Alt clicks (auction helpers, item lock); the template's own click already ran.
    button:HookScript("OnClick", function(self, mouse)
        local parent = self:GetParent()
        if parent and parent.GetID then ns.AuctionTrade.OnBagClick(parent:GetID(), self:GetID(), mouse) end
    end)
    button:Hide()
    secureSlots[key] = button
    return button
end
-- Builds the item buttons for every slot of the current bags (and the bank once it was
-- opened) out of combat, a few per frame, so a first opening in combat has usable slots.
local warmQueue, warmQueued, warmHead, warmTail, warmFrame = {}, {}, 1, 0, nil
local WARM_BUDGET_MS, WARM_FALLBACK_COUNT = 4, 8
local function warmStep(self)
    if API.InCombat() then self:SetScript("OnUpdate", nil); return end -- resumed after combat
    local clock = type(debugprofilestop) == "function" and debugprofilestop or nil
    local start, made = clock and clock(), 0
    while warmQueue[warmHead] do
        local job = warmQueue[warmHead]
        warmQueue[warmHead] = nil; warmHead = warmHead + 1
        local key = job.bag .. ":" .. job.slot
        warmQueued[key] = nil
        if secureSlots[key] == nil then secureSlot(job.bag, job.slot); made = made + 1 end
        if clock then
            if clock() - start >= WARM_BUDGET_MS then return end
        elseif made >= WARM_FALLBACK_COUNT then return end
    end
    warmQueue, warmHead, warmTail = {}, 1, 0
    self:SetScript("OnUpdate", nil)
end
function ns.WarmSecureSlots(storage)
    if not ns.content then return end
    if storage == "bank" and not ns.state.bank then return end
    for _, bag in ipairs(API.Bags(storage or "bags")) do
        for slot = 1, API.Slots(bag) do
            local key = bag .. ":" .. slot
            if secureSlots[key] == nil and not warmQueued[key] then
                warmQueued[key] = true
                warmTail = warmTail + 1
                warmQueue[warmTail] = { bag = bag, slot = slot }
            end
        end
    end
    if API.InCombat() or not warmQueue[warmHead] then return end
    warmFrame = warmFrame or CreateFrame("Frame")
    warmFrame:SetScript("OnUpdate", warmStep)
end
local function updateCooldown(b, source, empty)
    local cooldown = b.Cooldown or _G[b:GetName() .. "Cooldown"]
    if cooldown and not empty then
        local fn = API.Container("GetContainerItemCooldown")
        local start, duration, enable = 0, 0, 0
        if fn then start, duration, enable = fn(source.bag, source.slot) end
        local secret = issecretvalue and (issecretvalue(start) or issecretvalue(duration) or issecretvalue(enable))
        if secret then
            -- Secret cooldowns (combat) cannot be compared; let the widget handle them.
            if cooldown.SetCooldown then pcall(cooldown.SetCooldown, cooldown, start, duration) end
        elseif CooldownFrame_Set then CooldownFrame_Set(cooldown, start or 0, duration or 0, enable)
        elseif cooldown.SetCooldown and (duration or 0) > 0 then cooldown:SetCooldown(start, duration) end
    elseif cooldown and cooldown.Clear then cooldown:Clear() end
end
local function attachSecure(visual, e)
    local source = e and (e.sources and e.sources[1] or e)
    local b = source and source.bag and source.slot and API.UsableSnapshot() and secureSlot(source.bag, source.slot)
    if visual.secure and visual.secure ~= b then
        if slotVisual[visual.secure] == visual then slotVisual[visual.secure] = nil end
        visual.secure = nil
    end
    visual:EnableMouse(not b)
    if not b then return end
    local previous = slotVisual[b]
    if previous and previous ~= visual and previous.secure == b then previous.secure = nil; previous:EnableMouse(true) end
    slotVisual[b], visual.secure = visual, b
    b:ClearAllPoints(); b:SetAllPoints(visual)
    b:SetFrameLevel(visual:GetFrameLevel() + 4)
    updateCooldown(b, source, e.empty)
    b:Show()
end
-- Buttons stay shown between redraws (hiding them would close an open stack-split box).
local function hideUnusedSecure()
    for _, b in pairs(secureSlots) do
        local visual = b and slotVisual[b]
        if b and b:IsShown() and not (visual and visual:IsShown() and visual.secure == b) then
            b:Hide()
            if visual and visual.secure == b then visual.secure = nil end
            slotVisual[b] = nil
        end
    end
end
local function stamp(value)
    return value and date("%m-%d %H:%M", value) or "—"
end
function ns.ResizeWindow(width, height, scale)
    local f = ns.window
    local left, top = f:GetLeft(), f:GetTop()
    local oldScale = f:GetEffectiveScale()
    if scale then f:SetScale(scale) end
    if left and top then
        -- GetLeft/GetTop and anchor offsets use this frame's scaled coordinates.
        local newScale, rootScale = f:GetEffectiveScale(), UIParent:GetEffectiveScale()
        local x = (left * oldScale - (UIParent:GetLeft() or 0) * rootScale) / newScale
        local y = (top * oldScale - (UIParent:GetBottom() or 0) * rootScale) / newScale
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
        ns.cfg.position = { "TOPLEFT", "BOTTOMLEFT", x, y }
    end
    if f:GetWidth() ~= width then f:SetWidth(width) end
    if f:GetHeight() ~= height then f:SetHeight(height) end
end
-- The recipe addon of this suite lists where a reagent is used; then this line is left out.
function ns.RecipeAddonShowsUses()
    local pr = _G.EzWoW_ProfessionRecipes
    if type(pr) ~= "table" then
        local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded
        if type(isLoaded) ~= "function" or not isLoaded("EzWoW-ProfessionRecipes") then return false end
        return true
    end
    return not (type(pr.DB) == "table" and pr.DB.reagentTooltip == false)
end
function ns.AddTooltipInfo(tip, id)
    if not id or not ns.db or tooltipItem[tip] == id then return end
    tooltipItem[tip] = id
    local linesBefore = tooltipLineCount(tip)
    ns.AddTooltipItemLines(tip, id)
    secureSlotStacks(tip)
    local linesAfter = tooltipLineCount(tip)
    if linesBefore and linesAfter and linesAfter > linesBefore then
        ns.NoteTooltipLines(tip)
        ns.FlushTooltipTag(tip)
    end
end
function ns.AddTooltipItemLines(tip, id)
    local uses, names = ns.ReagentUses[id], {}
    for _, skill in ipairs(uses or {}) do names[#names + 1] = ns.ProfessionText(skill) end
    if #names > 0 and not ns.RecipeAddonShowsUses() then tip:AddLine(ns.T("materials") .. ": " .. table.concat(names, ", "), .94, .72, .42, true) end
    local lock = ns.Locks.Kind(id)
    if lock then tip:AddLine("|TInterface\\PetBattles\\PetBattle-LockIcon:12:12:0:0|t " .. ns.Text(lock == "account" and "lockedAccount" or "locked"), 1, .82, .4) end
    local price = ns.Price(id)
    local trend = ns.cfg.tooltipTrend and ns.History.TrendText(id)
    if price and not ns.Auction.TooltipActive() then
        tip:AddDoubleLine(ns.T("prices") .. " / 1" .. (trend and ("  " .. trend) or ""), ns.Money(price.unit), .94, .72, .42, 1, .82, .4)
        tip:AddLine(ns.T("cached") .. ": " .. stamp(price.time), .65, .72, .78)
    elseif trend and not ns.TooltipShowsTrend() then
        local line = ns.History.TrendLine(id)
        if line then tip:AddLine(line, .94, .72, .42) end
    end
    for _, row in ipairs(ns.CachedCounts(id)) do
        tip:AddDoubleLine(row.key:match("^(.-) %- ") or row.key,
            ns.T("bags") .. " " .. row.bags .. " · " .. ns.T("bank") .. " " .. row.bank,
            .65, .72, .78, .9, .94, .96)
        if row.bankTime then tip:AddLine("  " .. ns.T("bank") .. ": " .. stamp(row.bankTime), .5, .58, .62) end
    end
end
function ns.ClearTooltipItem(tip) tooltipItem[tip] = nil end
-- EzWoW - Tooltip shows its own auction price line and appends this addon's trend to it.
function ns.TooltipShowsTrend()
    if not ns.Auction.TooltipActive() then return false end
    local tooltip = _G.EzWoW_Tooltip
    if type(tooltip) ~= "table" or not tooltip.appendsBagsTrend then return false end
    local item = type(tooltip.db) == "table" and type(tooltip.db.item) == "table" and tooltip.db.item or ns.TooltipMerchantSettings()
    return not (item and item.showAuctionPrice == false)
end
local function enterItem(self)
    local e = self.entry
    if not e or e.empty then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    ns.HoldTooltipTag(GameTooltip)
    if API.UsableSnapshot() then GameTooltip:SetBagItem(e.bag, e.slot)
    elseif e.link then GameTooltip:SetHyperlink(e.link) end
    ns.AddTooltipInfo(GameTooltip, e.id)
    if not API.UsableSnapshot() then GameTooltip:AddLine(ns.Text("readonly"), 1, .75, .35) end
    if e.sources and #e.sources > 1 then GameTooltip:AddLine("Σ " .. e.count .. " · " .. string.format(ns.Text("stacks"), #e.sources), .65, .72, .78) end
    ns.ReleaseTooltipTag(GameTooltip)
    GameTooltip:Show()
end
local function clickItem(self, mouse)
    if ns.mode == "prices" and self.priceID then ns.PriceCatalog.Click(self.priceID, mouse); return end
    local e = self.entry
    if not e or not API.UsableSnapshot() then return end
    if not e.empty and e.bag and IsAltKeyDown and IsAltKeyDown() then
        local source = e.sources and e.sources[1] or e
        if ns.AuctionTrade.OnBagClick(source.bag, source.slot, mouse) then return end
    end
    if e.empty then
        if API.CursorBusy() and not API.InCombat() and not API.Item(e.bag, e.slot) then
            local fn = API.Container("PickupContainerItem"); if fn then fn(e.bag, e.slot) end
        end
        return
    end
    if IsShiftKeyDown and IsShiftKeyDown() then
        if HandleModifiedItemClick then HandleModifiedItemClick(e.link) end
        return
    end
    local source = e.sources and e.sources[1] or e
    if mouse == "RightButton" then API.Use(source) else API.Pickup(source) end
end
local function itemButton(index)
    if items[index] then return items[index] end
    local b = UI.Frame("Button", nil, ns.content); items[index] = b
    UI.Surface(b, .08, .11, .14)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetPoint("TOPLEFT", 2, -2); b.icon:SetTexCoord(.07, .93, .07, .93)
    b.tag = UI.Label(b, "", 10); b.tag:SetPoint("TOPLEFT", 3, -3)
    b.tag:SetTextColor(.3, 1, .65)
    b.count = UI.Label(b, "", 12); b.count:SetPoint("BOTTOMRIGHT", -3, 3)
    -- item level sits at the top (stack counts are bottom-right) so the two never look alike
    b.level = UI.Label(b, "", 10); b.level:SetPoint("TOPRIGHT", b.icon, "TOPRIGHT", -1, -1)
    b.name = UI.Label(b, ""); b.name:SetPoint("LEFT", b, "LEFT", 44, 0)
    b.money = UI.Label(b, "", 12); b.money:SetPoint("RIGHT", -10, 0); b.money:SetWidth(215); b.money:SetJustifyH("RIGHT")
    b.priceAge = UI.Label(b, "", 9); b.priceAge:SetTextColor(unpack(UI.Theme.muted))
    b.fresh = UI.Label(b, "●", 10); b.fresh:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMLEFT", 1, 0); b.fresh:SetTextColor(.35, 1, .65)
    b.lock = b:CreateTexture(nil, "OVERLAY", nil, 2); b.lock:SetSize(12, 12); b.lock:SetPoint("BOTTOMLEFT", b.icon, "BOTTOMLEFT", 0, 0)
    b.lock:SetTexture("Interface\\PetBattles\\PetBattle-LockIcon"); b.lock:Hide()
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp"); b:RegisterForDrag("LeftButton")
    b:SetScript("OnClick", clickItem)
    b:SetScript("OnDragStart", function(self) clickItem(self, "LeftButton") end)
    b:SetScript("OnReceiveDrag", function(self) clickItem(self, "LeftButton") end)
    b:SetScript("OnEnter", enterItem)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return b
end
local function renderItem(e, index, x, y, width, height, list)
    local b = itemButton(index); b.entry, b.priceID = e, nil
    b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, -y); b:SetSize(width, height)
    b.icon:SetSize(height - 4, height - 4); b.icon:SetTexture(e.icon or "Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    b.icon:SetAlpha(e.empty and .18 or (e.locked and .45 or 1))
    local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality or 1]
    b:SetBackdropBorderColor(c and c.r or .2, c and c.g or .3, c and c.b or .35, 1)
    b.count:SetText((e.count or 0) > 1 and e.count or "")
    b.tag:SetWidth(list and 36 or width - 5); b.tag:SetText(ns.cfg.labels and not e.empty and ns.ItemTag(e) or "")
    b.level:SetText(ns.cfg.itemLevel and not e.empty and API.IsEquipment(e) and e.level or "")
    b.level:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
    b.fresh:SetShown(not e.empty and e.bag ~= nil and ns.storage == "bags" and ns.selected == ns.player and ns.newItems[e.id] == true)
    b.name:SetText(list and (e.name or ns.T("empty")) or ""); b.name:SetWidth(math.max(0, width - 95))
    b.name:ClearAllPoints(); b.name:SetPoint("LEFT", height + 6, 0)
    b.money:SetText(""); b.priceAge:Hide()
    b.lock:SetShown(not e.empty and e.id ~= nil and ns.Locks.IsLocked(e.id, ns.selected))
    b:Show()
    attachSecure(b, e)
end
local function renderHeader(section, index, x, y, width)
    local b = headers[index]
    if not b then
        b = UI.Button(ns.content, "", width, function(self, mouse)
            if mouse == "RightButton" then ns.CategoryMenu(self.category)
            else local c = ns.CategoryConfig(self.category); c.collapsed = not c.collapsed; ns.Refresh() end
        end)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnReceiveDrag", function(self) ns.AssignItem(self.category) end)
        b.summary = UI.Label(b, "", 10); b.summary:SetPoint("BOTTOMLEFT", 29, 4); b.summary:SetTextColor(unpack(UI.Theme.accent))
        headers[index] = b
    end
    local compact = width < 260 and (section.value or 0) > 0
    local height = compact and 40 or 23
    b.category = section.id; b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, -y); b:SetSize(width, height)
    b.text:SetWidth(width - 12); b.text:SetJustifyH("LEFT")
    local cfg = ns.CategoryConfig(section.id)
    b.text:SetText((cfg.collapsed and "+ " or "− ") .. (cfg.pinned and "★ " or "") .. section.name .. " · " .. section.count
        .. (not compact and (section.value or 0) > 0 and ("   ≈ " .. ns.Money(section.value)) or ""))
    UI.SetIcon(b, UI.CategoryIcon(section.id)); UI.Selected(b, ns.filterCategory == section.id)
    b.summary:SetShown(compact)
    if compact then
        b.text:ClearAllPoints(); b.text:SetPoint("TOPLEFT", 29, -4)
        b.summary:SetWidth(width - 36); b.summary:SetText("≈ " .. ns.Money(section.value))
    end
    b:Show()
    return height
end
function ns.CreateWindow()
    local f = UI.Frame("Frame", "EzWoWBagsWindow", UIParent); ns.window = f
    f:SetSize(850, 610); f:SetScale(ns.cfg.scale); f:SetPoint("CENTER"); f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    UI.Surface(f)
    f:SetScript("OnDragStart", function(self) if not ns.LayoutLocked() then self:StartMoving() end end)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if ns.LayoutLocked() then ns.layoutPending = true; return end
        ns.ResizeWindow(self:GetWidth(), self:GetHeight())
    end)
    f.title = UI.Label(f, "EzWoW - Bags", 15); UI.Chrome(f, f.title)
    local close = UI.CloseButton(f, function() ns.Hide() end)
    local opts = UI.Button(f, ns.T("settings"), 80, function() ns.ToggleOptions() end); opts:SetPoint("RIGHT", close, "LEFT", -6, 0)
    f.optionsButton = opts
    f.character = UI.Button(f, "", 210, function() ns.CharacterMenu() end); f.character:SetPoint("TOPLEFT", 16, -101)
    UI.SetIcon(opts, UI.icons.settings); UI.SetIcon(f.character, UI.icons.characters)
    f.tabs = {}
    for i, mode in ipairs({ "bags", "bank", "prices" }) do
        local key = mode
        local b = UI.Button(f, ns.T(mode), 104, function()
            ns.mode = key; if key ~= "prices" then ns.storage = key end
            ns.moveQueue, ns.filterCategory = nil, nil; ns.scroll:SetVerticalScroll(0); ns.Refresh()
        end)
        b:SetPoint("TOPLEFT", 16 + (i - 1) * 111, -65); b:SetHeight(28); UI.SetIcon(b, UI.icons[mode]); f.tabs[mode] = b
    end
    f.search = UI.Edit(f, 360); f.search:SetPoint("TOPRIGHT", -16, -66)
    f.search:SetScript("OnTextChanged", function() ns.filterCategory = nil; if ns.scroll then ns.scroll:SetVerticalScroll(0); ns.Refresh() end end)
    f.search:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM"); GameTooltip:AddLine(ns.Text("help"), 1, 1, 1, true); GameTooltip:Show()
    end)
    f.search:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.status = UI.Label(f, ""); f.status:SetPoint("TOPLEFT", 16, -137); f.status:SetWidth(810)
    f.sideScroll = CreateFrame("ScrollFrame", nil, f)
    f.sideScroll:SetPoint("TOPLEFT", 12, -158); f.sideScroll:SetSize(130, 407)
    f.sidebar = UI.Frame("Frame", nil, f.sideScroll); f.sidebar:SetSize(130, 407); UI.Surface(f.sidebar, .07, .11, .14)
    f.sideScroll:SetScrollChild(f.sidebar); f.sideScroll:EnableMouseWheel(true)
    f.sideScroll:SetScript("OnMouseWheel", function(self, delta)
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 54)))
    end)
    ns.scroll = CreateFrame("ScrollFrame", "EzWoWBagsScroll", f, "UIPanelScrollFrameTemplate")
    ns.scroll:SetPoint("TOPLEFT", 148, -159); ns.scroll:SetPoint("BOTTOMRIGHT", -28, 100)
    ns.scroll:HookScript("OnVerticalScroll", function() if ns.mode == "prices" then ns.priceScrollDirty = true end end)
    ns.content = CreateFrame("Frame", nil, ns.scroll); ns.content:SetSize(626, 1); ns.scroll:SetScrollChild(ns.content)
    f.emptyMessage = UI.Label(ns.content, ""); f.emptyMessage:SetPoint("TOPLEFT", 12, -16); f.emptyMessage:SetWidth(580)
    f.footer = UI.Label(f, ""); f.footer:SetPoint("BOTTOMLEFT", 16, 73); f.footer:SetWidth(800)
    f.queue = UI.Label(f, ""); f.queue:SetPoint("BOTTOMLEFT", 16, 46); f.queue:SetWidth(610)
    f.next = UI.Button(f, ns.T("next"), 140, function() ns.NextMove() end); f.next:SetPoint("BOTTOMRIGHT", -16, 40)
    f.cancel = UI.Button(f, ns.T("stop"), 65, function() ns.moveQueue = nil; ns.Refresh() end); f.cancel:SetPoint("RIGHT", f.next, "LEFT", -5, 0)
    f.scan = UI.Button(f, ns.T("scan"), 155, function() ns.Auction.Start("full") end); f.scan:SetPoint("BOTTOMLEFT", 16, 40)
    f.bagScan = UI.Button(f, ns.T("bagScan"), 155, function() ns.Auction.Start("bags") end); f.bagScan:SetPoint("LEFT", f.scan, "RIGHT", 6, 0)
    f.stopScan = UI.Button(f, ns.T("stop"), 70, function() ns.Auction.Stop() end); f.stopScan:SetPoint("LEFT", f.bagScan, "RIGHT", 6, 0)
    f.clearNew = UI.Button(f, ns.T("new") .. " ✓", 130, function() ns.newItems = {}; ns.Refresh() end); f.clearNew:SetPoint("BOTTOMRIGHT", -16, 10)
    f.buyBank = UI.Button(f, "+ " .. ns.T("bank"), 130, function()
        if ns.state.bank and not API.InCombat() and BuyBankSlot then BuyBankSlot() end
    end); f.buyBank:SetPoint("BOTTOMRIGHT", -16, 10)
    f.sort = UI.Button(f, ns.Text("sort"), 90, function() ns.SortStorage() end); f.sort:SetPoint("BOTTOMRIGHT", -152, 10)
    f.sort:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:AddLine(ns.Text("sortHelp"), 1, 1, 1, true); GameTooltip:Show()
    end)
    f.sort:HookScript("OnLeave", function() GameTooltip:Hide() end)
    UI.SetIcon(f.scan, UI.icons.prices); UI.SetIcon(f.bagScan, UI.icons.bags); UI.SetIcon(f.stopScan, UI.icons.stop)
    UI.SetIcon(f.next, UI.icons.bags); UI.SetIcon(f.cancel, UI.icons.stop)
    UI.SetIcon(f.clearNew, UI.icons.new); UI.SetIcon(f.buyBank, UI.icons.bank); UI.SetIcon(f.sort, UI.icons.bags)
    f:SetScript("OnHide", function() ns.moveQueue = nil; if ns.menu then ns.menu:Hide() end; GameTooltip:Hide() end)
    if UISpecialFrames then UISpecialFrames[#UISpecialFrames + 1] = "EzWoWBagsWindow" end
    f:Hide()
end
local function renderSidebar(sections)
    local prices = ns.mode == "prices"
    local all = { { id = false, name = ns.T("show") .. " · " .. ns.T("grid") } }
    for _, s in ipairs(sections) do all[#all + 1] = s end
    if prices then all = ns.PriceCatalog.Categories() end
    -- Show all category choices even while one is selected.
    if not prices and ns.filterCategory then
        local selected = ns.filterCategory; ns.filterCategory = nil
        sections = ns.BuildModel(ns.Snapshot(), ns.window.search:GetText())
        ns.filterCategory = selected
        all = { all[1] }; for _, s in ipairs(sections) do all[#all + 1] = s end
    end
    for i, section in ipairs(all) do
        local b = sidebar[i]
        if not b then
            b = UI.Button(ns.window.sidebar, "", 118, function(self, mouse)
                if ns.mode == "prices" then ns.PriceCatalog.Select(self.priceClass, self.priceSub)
                elseif mouse == "RightButton" and self.category then ns.CategoryMenu(self.category)
                else ns.filterCategory = self.category; ns.scroll:SetVerticalScroll(0); ns.Refresh() end
            end)
            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnReceiveDrag", function(self) if ns.mode ~= "prices" and self.category then ns.AssignItem(self.category) end end)
            sidebar[i] = b
        end
        b.category = section.id; b:ClearAllPoints(); b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 27)
        b.priceClass, b.priceSub = section.class, section.sub
        b.text:SetText(section.name .. (section.count and ("  " .. section.count) or "")); b.text:SetJustifyH("LEFT")
        UI.SetIcon(b, UI.CategoryIcon(prices and section.icon or section.id))
        local selected = ns.filterCategory == section.id
        if prices then selected = section.class == ns.PriceCatalog.class and section.sub == ns.PriceCatalog.sub end
        UI.Selected(b, selected); b:Show()
    end
    for i = #all + 1, #sidebar do sidebar[i]:Hide() end
    ns.window.sidebar:SetHeight(math.max(1, #all * 27 + 12))
    ns.sidebarHeight = #all * 27 + 12
end
local function renderBags(snapshot)
    local ordered = ns.BagBarContainers(snapshot, ns.storage)
    local summary = ns.FreeSpace(snapshot, ns.storage)
    for i, bag in ipairs(ordered) do
        local b = bagButtons[i]
        if not b then
            b = UI.Button(ns.window, "", UI.Sizes.bagButton, function(self)
                ns.DropCursorIntoBag(self.bag)
            end)
            b:SetHeight(UI.Sizes.bagButton); b.text:Hide()
            b.bagIcon = b:CreateTexture(nil, "ARTWORK"); b.bagIcon:SetPoint("TOPLEFT", 3, -3); b.bagIcon:SetPoint("BOTTOMRIGHT", -3, 3)
            b.freeText = UI.Label(b, "", 11); b.freeText:SetPoint("BOTTOMRIGHT", -3, 3)
            b.freeText:SetTextColor(1, 1, 1, 1)
            b:SetScript("OnReceiveDrag", b:GetScript("OnClick"))
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                ns.HoldTooltipTag(GameTooltip)
                local inv = API.BagInventory(self.bag)
                if inv and API.UsableSnapshot() then
                    GameTooltip:SetInventoryItem("player", inv)
                else GameTooltip:AddLine(ns.T("empty") .. ": " .. self.free) end
                local label = self.kind == "keys" and ns.Text("keyring") or (self.kind == "reagent" and ns.T("materials") .. " " .. ns.T("bags")) or (self.bag == 0 and ns.Text("backpack")) or ns.T(ns.storage)
                GameTooltip:AddLine(label .. " · " .. ns.T("empty") .. ": " .. self.free .. "/" .. self.slots, .94, .72, .42)
                if self.bag == 0 then GameTooltip:AddLine(ns.T("empty") .. " (" .. ns.T("bags") .. "): " .. self.totalFree, .94, .72, .42) end
                ns.ReleaseTooltipTag(GameTooltip)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            bagButtons[i] = b
        end
        b.bag, b.free, b.slots, b.kind, b.totalFree = bag.bag, bag.free, bag.slots, ns.BagKind(bag, ns.storage), summary.total
        b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", 16 + (i - 1) * 41, 10)
        local liveIcon = API.UsableSnapshot() and API.BagIcon(bag.bag)
        b.bagIcon:ClearAllPoints(); b.bagIcon:SetPoint("TOPLEFT", 3, -3); b.bagIcon:SetPoint("BOTTOMRIGHT", -3, 3)
        b.bagIcon:SetTexCoord(0, 1, 0, 1)
        b.bagIcon:SetTexture(liveIcon or bag.icon or (bag.bag == API.Keyring() and UI.icons.keys) or (bag.bag == 0 and UI.icons.bags) or UI.icons.other)
        if b.kind == "keys" then
            b.bagIcon:SetTexture(UI.icons.keys)
        end
        b.freeText:SetText(b.kind == "keys" and "" or (bag.bag == 0 and ("(" .. summary.total .. ")")) or bag.free)
        b:SetBackdropBorderColor(unpack(UI.Theme.accent)); b:Show()
    end
    for i = #ordered + 1, #bagButtons do bagButtons[i]:Hide() end
end
function ns.BagLayout()
    local lanes = ns.cfg.view == "sections" and ns.cfg.sectionColumns or 1
    local columns, step = ns.cfg.columns, ns.cfg.size + 4
    local layout = { lanes = lanes, columns = {}, widths = {}, offsets = {} }
    local contentWidth = columns * step - lanes * 4 + (lanes - 1) * 10
    layout.width = math.max(500, contentWidth + 176)
    layout.contentWidth = layout.width - 176
    local spare = layout.contentWidth - contentWidth
    local x = 0
    for lane = 1, lanes do
        local count = math.floor(columns / lanes) + (lane <= columns % lanes and 1 or 0)
        local extra = math.floor(spare / lanes) + (lane <= spare % lanes and 1 or 0)
        layout.columns[lane] = count
        layout.widths[lane] = count * step - 4 + extra
        layout.offsets[lane] = x
        x = x + layout.widths[lane] + 10
    end
    return layout
end
-- Uses the game's own sort (bags, or the bank while it is open); out of combat only.
local function sorter()
    if not C_Container or ns.selected ~= ns.player or ns.mode == "prices" then return nil end
    if ns.storage == "bags" then return C_Container.SortBags end
    if ns.storage == "bank" and ns.state.bank then return C_Container.SortBankBags end
    return nil
end
function ns.SortStorage()
    local fn = sorter()
    if type(fn) ~= "function" then return end
    if API.InCombat() then ns.Print(ns.Text("combat")); return end
    ns.moveQueue = nil
    pcall(fn)
end
local function footerText(snapshot)
    local char = ns.db.characters[ns.selected] or {}
    local space = ns.FreeSpace(snapshot, ns.storage)
    -- The game's own free count may leave profession bags out; then they are listed after it
    -- instead of inside the brackets, so the numbers always add up.
    local extra = {}
    if space.reagent > 0 then extra[#extra + 1] = ns.T("materials") .. " " .. space.reagent end
    if space.special > 0 then extra[#extra + 1] = ns.Text("special") .. " " .. space.special end
    local freeText = ns.T("empty") .. ": " .. space.total
    if #extra > 0 then
        if space.total == space.general + space.reagent + space.special then
            table.insert(extra, 1, ns.Text("general") .. " " .. space.general)
            freeText = freeText .. " (" .. table.concat(extra, " · ") .. ")"
        else
            freeText = freeText .. " · " .. table.concat(extra, " · ")
        end
    end
    if space.keys > 0 then freeText = freeText .. " · " .. ns.Text("keyring") .. " " .. space.keys end
    return ns.Money(char.money) .. "    " .. freeText
end
-- Combat update: no anchors, sizes, scale, Show or Hide; counts, icons and cooldowns only.
local function renderCombat(f)
    ns.layoutPending = true
    if ns.mode == "prices" then return end
    f.footer:SetText(footerText(ns.Snapshot()))
    if not API.UsableSnapshot() then return end
    for _, b in ipairs(items) do
        local e = b.entry
        if b:IsShown() and e and not e.empty then
            local total, locked = 0, false
            for _, source in ipairs(e.sources or { e }) do
                local live = source.bag and source.slot and API.Item(source.bag, source.slot)
                if live and live.id == e.id then
                    total = total + (live.count or 0)
                    locked = locked or live.locked
                end
            end
            e.count = total
            b.count:SetText(total > 1 and total or "")
            b.icon:SetAlpha(total == 0 and .18 or (locked and .45 or 1))
            if b.secure then
                local source = e.sources and e.sources[1] or e
                updateCooldown(b.secure, source, total == 0)
            end
        end
    end
end
function ns.Render()
    local f = ns.window
    if not f or not ns.cfg then return end
    if ns.LayoutLocked() then renderCombat(f); return end
    ns.layoutPending = false
    local layout = ns.BagLayout()
    local desiredWidth = layout.width
    ns.ResizeWindow(desiredWidth, f:GetHeight(), ns.cfg.scale)
    f:SetAlpha(ns.cfg.opacity)
    f.character:SetWidth(desiredWidth - 32); f.character.text:SetWidth(desiredWidth - 88)
    f.search:SetWidth(desiredWidth - 374); f.status:SetWidth(desiredWidth - 32)
    f.footer:SetWidth(desiredWidth - 32); f.queue:SetWidth(desiredWidth - 250); f.emptyMessage:SetWidth(desiredWidth - 64)
    f.title:SetText("EzWoW - Bags")
    f.subtitle:SetText(ns.Text("subtitle"))
    f.optionsButton.text:SetText(ns.T("settings"))
    f.scan.text:SetText(ns.T("scan")); f.bagScan.text:SetText(ns.T("bagScan"))
    f.next.text:SetText(ns.T("next")); f.cancel.text:SetText(ns.T("stop"))
    f.clearNew.text:SetText(ns.T("new") .. " ✓")
    f.character.text:SetText(ns.selected .. " ▾")
    UI.CharacterIcons(f.character, ns.db.characters[ns.selected])
    for key, button in pairs(f.tabs) do
        local selected = (ns.mode or "bags") == key
        button.text:SetText((selected and "✓ " or "") .. ns.T(key)); UI.Selected(button, selected)
    end
    for _, b in ipairs(items) do b:Hide() end
    for _, b in ipairs(headers) do b:Hide() end
    local snapshot = ns.Snapshot()
    local prices = ns.mode == "prices"
    local model, err = {}, nil
    if not prices then model, err = ns.BuildModel(snapshot, f.search:GetText()) end
    f.sideScroll:Show()
    local graphID = prices and ns.PriceCatalog.selected or nil
    local graphHeight = graphID and (ns.PriceGraph.HEIGHT + 8) or 0
    local layoutKey = prices and (graphID and "graph" or "prices") or "bags"
    if f.priceLayout ~= layoutKey then
        f.priceLayout = layoutKey
        ns.scroll:ClearAllPoints(); ns.scroll:SetPoint("TOPLEFT", 148, -159 - graphHeight); ns.scroll:SetPoint("BOTTOMRIGHT", -28, 100)
    end
    if graphID and not f.graph then
        f.graph = ns.PriceGraph.Create(f)
        f.graph:SetPoint("TOPLEFT", 148, -159); f.graph:SetPoint("TOPRIGHT", -16, -159)
    end
    if f.graph then f.graph:SetShown(graphID ~= nil) end
    if prices then
        for _, b in ipairs(bagButtons) do b:Hide() end
        renderSidebar({})
    else renderSidebar(model); renderBags(snapshot) end
    local readOnly = not API.UsableSnapshot()
    f.status:SetText(err and (ns.Text("queryError") .. err) or
        ((readOnly and ns.Text("readonly") .. " · " or "") .. ns.T(ns.storage) .. " · " .. stamp(snapshot and snapshot.time)))
    if not snapshot and ns.storage == "bank" then f.status:SetText(ns.Text("bankUnknown")) end
    local free = #(snapshot and snapshot.free or {})
    f.footer:SetText(footerText(snapshot))
    f.scan:SetShown(prices); f.bagScan:SetShown(prices); f.stopScan:SetShown(prices)
    local job = ns.Auction.job
    local shared = ns.Auction.TooltipActive()
    f.scan:SetEnabled(not shared); f.bagScan:SetEnabled(not shared); f.stopScan:SetEnabled(not shared and job ~= nil)
    f.scan:SetAlpha(shared and .4 or 1); f.bagScan:SetAlpha(shared and .4 or 1)
    local progress = job and (job.reading and (" " .. job.index .. "/" .. job.count) or " …") or ""
    f.stopScan.text:SetText(ns.T("stop") .. progress)
    local q = ns.moveQueue
    f.next:SetShown(q ~= nil); f.cancel:SetShown(q ~= nil); f.queue:SetText("")
    if q then
        local e = q.items[q.index]
        f.queue:SetText(ns.T("move") .. " → " .. q.target .. "  " .. q.index .. "/" .. #q.items .. "  " .. (e and e.name or ns.T("done")) .. (q.pending and " …" or ""))
    end
    f.clearNew:SetShown(ns.storage == "bags" and not prices)
    f.sort.text:SetText(ns.Text("sort"))
    local sortFn = sorter()
    f.sort:SetShown(type(sortFn) == "function")
    local fullBank = GetNumBankSlots and select(2, GetNumBankSlots())
    f.buyBank:SetShown(not API.ModernBank() and ns.storage == "bank" and ns.selected == ns.player and ns.state.bank and not prices and not fullBank)
    if f.buyBank:IsShown() and GetBankSlotCost then f.buyBank.text:SetText("+ " .. ns.Money(GetBankSlotCost())) end
    local n, h, size, gap = 0, 0, ns.cfg.size, 4
    local width = layout.contentWidth
    if ns.content:GetWidth() ~= width then ns.content:SetWidth(width) end
    if prices then
        local market = ns.db.markets[ns.market]
        f.status:SetText(ns.realm .. " · " .. (shared and ns.Text("ahShared") or ns.Auction.status or (job and (ns.T("scan") .. " …") or (ns.T("cached") .. " · " .. stamp(market and (market.updatedTime or market.fullScan))))))
        f.footer:SetText(ns.T("prices") .. " · " .. ns.market)
        local catalog = ns.PriceCatalog.Get(f.search:GetText())
        ns.visiblePriceWaiting = {}
        h = #catalog.rows * 42
        local first = math.max(1, math.min(#catalog.rows, math.floor(ns.scroll:GetVerticalScroll() / 42) + 1))
        local visible = math.min(18, math.ceil(math.min(610, ns.scroll:GetHeight()) / 42) + 2)
        for index = first, math.min(#catalog.rows, first + visible - 1) do
            local id = catalog.rows[index]
            local p = market.items[id]
            local e = ns.Enrich({ id = id, count = 1 })
            if e.name == "#" .. id then ns.visiblePriceWaiting[id] = true end
            n = n + 1; renderItem(e, n, 0, (index - 1) * 42, width - 4, 38, true)
            items[n].entry = nil -- Price catalog is always read-only and has no physical bag location.
            items[n]:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetItemByID(self.priceID)
                ns.AddTooltipInfo(GameTooltip, self.priceID); GameTooltip:Show()
            end)
            items[n].priceID = e.id
            if id == ns.PriceCatalog.selected then items[n]:SetBackdropBorderColor(unpack(UI.Theme.accent)) end
            items[n].name:SetText(e.name); items[n].name:SetWidth(math.max(100, width - 190))
            items[n].name:ClearAllPoints(); items[n].name:SetPoint("TOPLEFT", 44, -5)
            items[n].money:SetText(ns.Money(p.unit))
            items[n].money:SetWidth(125)
            items[n].priceAge:ClearAllPoints(); items[n].priceAge:SetPoint("BOTTOMLEFT", 44, 5); items[n].priceAge:SetText(stamp(p.time)); items[n].priceAge:Show()
        end
        if graphID and f.graph then ns.PriceGraph.Draw(f.graph, graphID) end
        if catalog.error then f.status:SetText(ns.Text("queryError") .. catalog.error)
        elseif not catalog.done then f.status:SetText(ns.T("search") .. " … " .. (catalog.cursor - 1) .. "/" .. #catalog.ids) end
        f.footer:SetText(ns.T("prices") .. " · " .. #catalog.rows .. " · " .. ns.market .. "   |cff8398a6" .. ns.Text("priceClickHint") .. "|r")
    else
        ns.visiblePriceWaiting = nil
        if ns.cfg.view == "grid" or ns.cfg.view == "list" then
            local combined = { id = "all", name = ns.T(ns.storage), count = 0, items = {} }
            for _, s in ipairs(model) do for _, e in ipairs(s.items) do combined.items[#combined.items + 1] = e; combined.count = combined.count + e.count end end
            model = { combined }
        end
        local lanes, heights = layout.lanes, {}
        for i = 1, lanes do heights[i] = 0 end
        local headerCount = 0
        for _, section in ipairs(model) do
            local lane = 1
            for i = 2, lanes do if heights[i] < heights[lane] then lane = i end end
            local x, y = layout.offsets[lane], heights[lane]
            local laneWidth = layout.widths[lane]
            headerCount = headerCount + 1
            local headerHeight = renderHeader(section, headerCount, x, y, laneWidth)
            y = y + headerHeight + 5
            if not ns.CategoryConfig(section.id).collapsed then
                local list = ns.cfg.view == "list"
                local cols = list and 1 or layout.columns[lane]
                local height = list and 38 or size
                for i, e in ipairs(section.items) do
                    n = n + 1; renderItem(e, n, x + ((i - 1) % cols) * (size + gap), y + math.floor((i - 1) / cols) * (height + gap), list and laneWidth or size, height, list)
                    items[n]:SetScript("OnEnter", enterItem)
                end
                y = y + math.ceil(#section.items / cols) * (height + gap)
            end
            heights[lane] = y + 12
        end
        h = 0; for _, height in ipairs(heights) do h = math.max(h, height) end
        if ns.cfg.emptySlots then
            -- keyring slots only take keys, so they are not drawn as free space
            local shown = 0
            for _, e in ipairs(snapshot and snapshot.free or {}) do
                if ns.BagKind(e, ns.storage) ~= "keys" then
                    shown = shown + 1; n = n + 1
                    local cols = ns.cfg.columns
                    renderItem(e, n, ((shown - 1) % cols) * (size + gap), h + math.floor((shown - 1) / cols) * (size + gap), size, size)
                    items[n]:SetScript("OnEnter", enterItem)
                end
            end
            h = h + math.ceil(shown / ns.cfg.columns) * (size + gap)
        end
    end
    if ns.content:GetHeight() ~= math.max(1, h + 12) then ns.content:SetHeight(math.max(1, h + 12)) end
    hideUnusedSecure()
    f.emptyMessage:SetShown(n == 0)
    if n == 0 then
        f.emptyMessage:SetText(prices and (ns.T("prices") .. ": 0\n\n" .. (shared and ns.Text("ahShared") or ns.Auction.status or (job and (ns.T("scan") .. " …") or ns.Text("ahClosed")))) or (err and ns.Text("queryError") .. err or ns.T("empty")))
    end
    local desiredHeight = math.max(399, math.min(669 + graphHeight, math.max(h + 270 + graphHeight, (ns.sidebarHeight or 0) + 265)))
    ns.ResizeWindow(desiredWidth, desiredHeight)
    if f.sideScroll:GetHeight() ~= math.max(100, desiredHeight - 258) then f.sideScroll:SetHeight(math.max(100, desiredHeight - 258)) end
end
-- Opening or closing the protected window waits for the end of combat.
function ns.Show(storage)
    if not ns.window then return end
    if ns.LayoutLocked() then
        if ns.window:IsShown() then ns.combatVisibility = nil
        else
            if storage then ns.storage, ns.mode = storage, storage end
            ns.combatVisibility = "show"
        end
        ns.layoutPending = true
        return
    end
    if storage then ns.storage, ns.mode = storage, storage end
    ns.combatVisibility = nil
    ns.window:Show(); ns.Refresh()
end
function ns.Hide()
    if not ns.window then return end
    if ns.LayoutLocked() then
        ns.combatVisibility = ns.window:IsShown() and "hide" or nil
        return
    end
    ns.combatVisibility = nil
    ns.window:Hide()
end
function ns.Toggle()
    if not ns.window then return end
    if ns.LayoutLocked() then
        local willShow = ns.window:IsShown()
        if ns.combatVisibility then willShow = ns.combatVisibility == "show" end
        if willShow then ns.Hide() else ns.Show("bags") end
        return
    end
    if ns.window:IsShown() then ns.Hide() else ns.Show("bags") end
end
-- After combat: open/close what was asked for, then redo the layout.
function ns.AfterCombat()
    local want = ns.combatVisibility
    ns.combatVisibility = nil
    if not ns.window or ns.LayoutLocked() then return end
    if want == "hide" then ns.window:Hide()
    elseif want == "show" then ns.window:Show() end
    if ns.layoutPending or want == "show" then ns.layoutPending = false; ns.Refresh() end
end
