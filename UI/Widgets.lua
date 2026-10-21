local _, ns = ...
local UI = {}; ns.UI = UI
local white = "Interface\\Buttons\\WHITE8X8"
UI.Theme = {
    bg = { .071, .094, .122, .97 }, panel = { .114, .157, .192, .96 }, input = { .047, .067, .086, .96 }, border = { .204, .298, .357, 1 },
    text = { .929, .957, .969, 1 }, muted = { .655, .725, .773, 1 }, accent = { .94, .72, .42, 1 },
}
UI.Sizes = { titleIcon = 28, buttonIcon = 16, close = 22, button = 24, bagButton = 36 }
UI.icons = {
    bags = "Interface\\Buttons\\Button-Backpack-Up", bank = "Interface\\Icons\\INV_Misc_Bag_10_Blue",
    prices = "Interface\\Icons\\INV_Misc_Coin_01", settings = "Interface\\AddOns\\EzWoW-Bags\\Media\\gear",
    characters = "Interface\\Icons\\INV_Helmet_03", keys = "Interface\\Icons\\INV_Misc_Key_03",
    equipment = "Interface\\Icons\\INV_Chest_Plate04", consumable = "Interface\\Icons\\INV_Potion_51",
    materials = "Interface\\Icons\\INV_Fabric_Linen_01", recipe = "Interface\\Icons\\INV_Scroll_03",
    quest = "Interface\\Icons\\INV_Misc_Book_09", other = "Interface\\Icons\\INV_Misc_Bag_10",
    junk = "Interface\\Icons\\INV_Misc_Bone_01", new = "Interface\\Icons\\INV_Misc_EngGizmos_17",
    custom = "Interface\\Icons\\INV_Misc_Note_01", stop = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
}
function UI.CategoryIcon(id) return UI.icons[id or "bags"] or UI.icons.custom end
local classCoords = {
    WARRIOR={0,.25,0,.25}, MAGE={.25,.5,0,.25}, ROGUE={.5,.75,0,.25}, DRUID={.75,1,0,.25},
    HUNTER={0,.25,.25,.5}, SHAMAN={.25,.5,.25,.5}, PRIEST={.5,.75,.25,.5}, WARLOCK={.75,1,.25,.5}, PALADIN={0,.25,.5,.75},
}
local raceCoords = { Human={0,.125,0,.25}, Dwarf={.125,.25,0,.25}, Gnome={.25,.375,0,.25}, NightElf={.375,.5,0,.25},
    Tauren={0,.125,.25,.5}, Scourge={.125,.25,.25,.5}, Troll={.25,.375,.25,.5}, Orc={.375,.5,.25,.5} }
function UI.CharacterIcons(button, character)
    character = character or {}
    UI.SetIcon(button, nil)
    if not button.raceIcon then button.raceIcon = button:CreateTexture(nil, "ARTWORK"); button.raceIcon:SetSize(UI.Sizes.buttonIcon, UI.Sizes.buttonIcon); button.raceIcon:SetPoint("LEFT", 27, 0) end
    button.icon:SetTexCoord(0,1,0,1); button.raceIcon:SetTexCoord(0,1,0,1)
    local class, race = character.class, character.race
    if class then
        button.icon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
        button.icon:SetTexCoord(unpack((CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[class]) or classCoords[class] or {0,1,0,1}))
    end
    if race then
        local atlasRace = race == "Scourge" and "undead" or race:lower()
        local atlas = "raceicon128-" .. atlasRace .. "-" .. (character.sex == 3 and "female" or "male")
        if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then button.raceIcon:SetAtlas(atlas)
        else
            local coords = raceCoords[race] or {0,.125,0,.25}
            local offset = character.sex == 3 and .5 or 0
            button.raceIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Races")
            button.raceIcon:SetTexCoord(coords[1], coords[2], coords[3] + offset, coords[4] + offset)
        end
    end
    button.icon:SetShown(class ~= nil); button.raceIcon:SetShown(race ~= nil)
    button.text:ClearAllPoints(); button.text:SetPoint("LEFT", 49, 0); button.text:SetWidth(button:GetWidth() - 57); button.text:SetJustifyH("LEFT")
end
function UI.Surface(frame, r, g, b, a)
    if frame.SetBackdrop then
        frame:SetBackdrop({ bgFile = white, edgeFile = white, edgeSize = 1 })
        frame:SetBackdropColor(r or UI.Theme.bg[1], g or UI.Theme.bg[2], b or UI.Theme.bg[3], a or UI.Theme.bg[4])
        frame:SetBackdropBorderColor(unpack(UI.Theme.border))
    else
        local bg = frame:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(r or UI.Theme.bg[1], g or UI.Theme.bg[2], b or UI.Theme.bg[3], a or UI.Theme.bg[4])
    end
end
function UI.Frame(kind, name, parent)
    return CreateFrame(kind or "Frame", name, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
end
function UI.Label(parent, text, size)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f:SetText(text or ""); f:SetJustifyH("LEFT")
    f:SetTextColor(unpack(UI.Theme.text))
    if size then local font, _, flags = f:GetFont(); f:SetFont(font, size, flags) end
    return f
end
function UI.SetIcon(button, texture)
    if not button.icon then
        button.icon = button:CreateTexture(nil, "ARTWORK"); button.icon:SetSize(UI.Sizes.buttonIcon, UI.Sizes.buttonIcon); button.icon:SetPoint("LEFT", 7, 0)
    end
    button.icon:SetTexture(texture); button.icon:SetShown(texture ~= nil)
    button.text:ClearAllPoints()
    button.text:SetPoint("LEFT", texture and 29 or 7, 0)
    button.text:SetWidth(button:GetWidth() - (texture and 36 or 14))
    button.text:SetJustifyH(texture and "LEFT" or "CENTER")
end
function UI.Selected(button, selected)
    button.selected = selected and true or false
    if not button.selectionLine then
        button.selectionLine = button:CreateTexture(nil, "OVERLAY")
        button.selectionLine:SetPoint("BOTTOMLEFT", 1, 1); button.selectionLine:SetPoint("BOTTOMRIGHT", -1, 1); button.selectionLine:SetHeight(3)
        button.selectionLine:SetColorTexture(unpack(UI.Theme.accent))
    end
    button.selectionLine:SetShown(button.selected)
    if button.selected then
        button:SetBackdropColor(.31, .225, .135, 1); button:SetBackdropBorderColor(unpack(UI.Theme.accent))
        button.text:SetTextColor(1, .88, .65, 1)
    else
        button:SetBackdropColor(unpack(UI.Theme.panel)); button:SetBackdropBorderColor(unpack(UI.Theme.border))
        button.text:SetTextColor(unpack(UI.Theme.muted))
    end
end
function UI.Chrome(frame, title)
    UI.Surface(frame)
    frame.headerBg = frame:CreateTexture(nil, "BACKGROUND"); frame.headerBg:SetPoint("TOPLEFT", 1, -1); frame.headerBg:SetPoint("TOPRIGHT", -1, -1)
    frame.headerBg:SetHeight(37); frame.headerBg:SetColorTexture(unpack(UI.Theme.panel))
    frame.brandIcon = frame:CreateTexture(nil, "ARTWORK"); frame.brandIcon:SetSize(UI.Sizes.titleIcon, UI.Sizes.titleIcon); frame.brandIcon:SetPoint("TOPLEFT", 14, -5)
    frame.brandIcon:SetTexture("Interface\\AddOns\\EzWoW-Bags\\Media\\Icon")
    title:ClearAllPoints(); title:SetPoint("TOPLEFT", 48, -12); title:SetFontObject("GameFontNormalLarge"); title:SetTextColor(unpack(UI.Theme.accent))
    frame.brandLine = frame:CreateTexture(nil, "ARTWORK"); frame.brandLine:SetPoint("TOPLEFT", 14, -38)
    frame.brandLine:SetPoint("TOPRIGHT", -14, -38); frame.brandLine:SetHeight(2); frame.brandLine:SetColorTexture(unpack(UI.Theme.accent))
end
function UI.Button(parent, text, width, callback, icon)
    local b = UI.Frame("Button", nil, parent); b:SetSize(width or 80, UI.Sizes.button)
    UI.Surface(b, unpack(UI.Theme.panel))
    b.text = UI.Label(b, text); b.text:SetPoint("CENTER"); b.text:SetWidth((width or 80) - 8); b.text:SetJustifyH("CENTER")
    b:SetScript("OnClick", callback)
    b:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(UI.Theme.accent)); self:SetBackdropColor(.18, .24, .30, 1)
    end)
    b:SetScript("OnLeave", function(self)
        UI.Selected(self, self.selected)
    end)
    if icon then UI.SetIcon(b, icon) end
    return b
end
function UI.Edit(parent, width, height)
    local e = UI.Frame("EditBox", nil, parent); e:SetSize(width, height or 25)
    UI.Surface(e, unpack(UI.Theme.input)); e:SetFontObject("GameFontHighlightSmall")
    e:SetTextInsets(8, 8, 2, 2); e:SetAutoFocus(false)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    return e
end
function UI.CloseButton(parent, callback)
    local button = UI.Button(parent, "×", UI.Sizes.close, callback)
    button:SetHeight(UI.Sizes.close); button:SetPoint("TOPRIGHT", -10, -9)
    return button
end
function UI.Check(parent, text, checked, callback)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate"); b:SetSize(24, 24)
    b:SetChecked(checked)
    b.label = UI.Label(b, text); b.label:SetPoint("LEFT", b, "RIGHT", 4, 0)
    b:SetScript("OnClick", function(self) callback(self:GetChecked() and true or false) end)
    return b
end
function ns.SelectCharacter(key)
    ns.selected, ns.moveQueue, ns.filterCategory = key, nil, nil
    ns.Refresh()
end
function UI.Menu(title, entries)
    local menu = ns.menu
    if not menu then
        menu = UI.Frame("Frame", nil, UIParent); ns.menu = menu
        menu.buttons = {}; menu.label = UI.Label(menu, ""); menu.label:SetPoint("TOPLEFT", 12, -12)
        UI.Surface(menu)
    end
    menu:SetFrameStrata("DIALOG"); menu:SetSize(280, 42 + #entries * 28)
    menu:ClearAllPoints(); menu:SetPoint("CENTER"); menu.label:SetText(title)
    for i, entry in ipairs(entries) do
        local b = menu.buttons[i]
        if not b then
            b = UI.Button(menu, "", 256, function(self) menu:Hide(); self.callback() end)
            b:SetPoint("TOPLEFT", 12, -34 - (i - 1) * 28); menu.buttons[i] = b
        end
        b:SetWidth(356); b.text:SetText(entry[1]); b.callback = entry[2]
        if entry[3] then UI.CharacterIcons(b, entry[3])
        else UI.SetIcon(b, nil); if b.raceIcon then b.raceIcon:Hide() end end
        b:Show()
    end
    for i = #entries + 1, #menu.buttons do menu.buttons[i]:Hide() end
    menu:Show()
    menu:SetWidth(380)
end
function ns.CharacterMenu()
    local menu = ns.characterCombo
    if menu and menu:IsShown() then menu:Hide(); return end
    if not menu then
        menu = UI.Frame("Frame", "EzWoWBagsCharacterCombo", ns.window); ns.characterCombo = menu
        UI.Surface(menu); menu:SetFrameStrata("DIALOG"); menu:EnableMouse(true)
        menu.buttons, menu.offset = {}, 0
        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseWheel", function(self, delta)
            self.offset = math.max(0, math.min(math.max(0, #self.keys - 8), self.offset - delta))
            self:Hide(); ns.CharacterMenu()
        end)
        menu:SetScript("OnHide", function() UI.Selected(ns.window.character, false) end)
        pcall(menu.RegisterEvent, menu, "GLOBAL_MOUSE_DOWN")
        menu:SetScript("OnEvent", function(self)
            if self:IsShown() and MouseIsOver and not MouseIsOver(self) and not MouseIsOver(ns.window.character) then self:Hide() end
        end)
        UISpecialFrames[#UISpecialFrames + 1] = "EzWoWBagsCharacterCombo"
        ns.window:HookScript("OnHide", function() menu:Hide() end)
    end
    local keys = {}
    for key, c in pairs(ns.db.characters) do if c.realm == ns.realm then keys[#keys + 1] = key end end
    table.sort(keys)
    menu.keys = keys
    menu.offset = math.max(0, math.min(menu.offset, math.max(0, #keys - 8)))
    local count, width = math.min(8, #keys), ns.window.character:GetWidth()
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", ns.window.character, "BOTTOMLEFT", 0, -2)
    menu:SetSize(width, count * 28 + 8)
    for i = 1, count do
        local b = menu.buttons[i]
        if not b then
            b = UI.Button(menu, "", width - 8, function(self) menu:Hide(); ns.SelectCharacter(self.key) end)
            b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 28); menu.buttons[i] = b
        end
        b.key = keys[menu.offset + i]; b:SetWidth(width - 8)
        b.text:SetText(b.key); UI.CharacterIcons(b, ns.db.characters[b.key])
        UI.Selected(b, b.key == ns.selected); b:Show()
    end
    for i = count + 1, #menu.buttons do menu.buttons[i]:Hide() end
    UI.Selected(ns.window.character, true); menu:Show()
end
function ns.CategoryMenu(id)
    local cfg = ns.CategoryConfig(id)
    local entries = {
        { (cfg.pinned and "✓ " or "") .. ns.T("pin"), function() cfg.pinned = not cfg.pinned; ns.Refresh() end },
        { ns.T("hide"), function() cfg.hidden = true; ns.filterCategory = nil; ns.Refresh() end },
        { ns.T("disable"), function() cfg.disabled = true; ns.filterCategory = nil; ns.Refresh() end },
    }
    for i, category in ipairs(ns.cfg.custom) do
        if category.id == id then
            local index = i
            entries[#entries + 1] = { "↑ " .. ns.T("custom"), function()
                if index > 1 then ns.cfg.custom[index], ns.cfg.custom[index - 1] = ns.cfg.custom[index - 1], ns.cfg.custom[index] end
                ns.Refresh()
            end }
            entries[#entries + 1] = { ns.T("search") .. " → " .. ns.T("custom"), function()
                local query = ns.window.search:GetText()
                local _, err = ns.Search.Compile(query)
                if err then ns.Print(err) else category.query = query; ns.Refresh() end
            end }
            entries[#entries + 1] = { "− " .. ns.T("custom"), function() ns.RemoveCategory(id) end }
            break
        end
    end
    if ns.API.UsableSnapshot() then
        for _, target in ipairs({ "bank", "mail", "trade", "merchant" }) do
            local key = target
            if ns.state[target] and (target == "bank" or ns.storage == "bags") then
                entries[#entries + 1] = { ns.T("move") .. " → " .. (target == "bank" and ns.T("bank") or target), function() ns.BeginMove(id, key) end }
            end
        end
    end
    entries[#entries + 1] = { ns.T("close"), function() end }
    UI.Menu(ns.CategoryName(id), entries)
end
