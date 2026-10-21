local _, ns = ...
local UI = ns.UI
local function optionLabel(ko, en)
    local lang = ns.cfg.language
    return (lang == "koKR" or (lang == "auto" and GetLocale() == "koKR")) and ko or en
end
local languageNames = { koKR = "한국어", enUS = "English", deDE = "Deutsch", frFR = "Français",
    esES = "Español", ruRU = "Русский", zhCN = "简体中文", zhTW = "繁體中文" }
local function languageName(value)
    return languageNames[value] or optionLabel("자동 (게임 언어)", "Auto (game language)")
end
function ns.UpdateOptions()
    if not ns.options then return end
    for _, update in ipairs(ns.options.bindings) do update() end
end
function ns.SetLanguage(value)
    local valid = false
    for _, language in ipairs(ns.languages) do if value == language then valid = true; break end end
    if not valid then return end
    ns.cfg.language = value
    ns.PriceCatalog.current = nil
    if ns.languageCombo then ns.languageCombo:Hide() end
    if ns.menu then ns.menu:Hide() end
    if ns.characterCombo then ns.characterCombo:Hide() end
    ns.UpdateOptions(); ns.Refresh()
end
function ns.LanguageMenu()
    local menu, button = ns.languageCombo, ns.options.language
    if menu and menu:IsShown() then menu:Hide(); return end
    if not menu then
        menu = UI.Frame("Frame", "EzWoWBagsLanguageCombo", ns.options); ns.languageCombo = menu
        UI.Surface(menu); menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu:EnableMouse(true)
        menu.buttons = {}
        pcall(menu.RegisterEvent, menu, "GLOBAL_MOUSE_DOWN")
        menu:SetScript("OnEvent", function(self)
            if self:IsShown() and MouseIsOver and not MouseIsOver(self) and not MouseIsOver(button) then self:Hide() end
        end)
        UISpecialFrames[#UISpecialFrames + 1] = "EzWoWBagsLanguageCombo"
    end
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -2)
    menu:SetSize(button:GetWidth(), #ns.languages * 24 + 8)
    for i, value in ipairs(ns.languages) do
        local b = menu.buttons[i]
        if not b then
            b = UI.Button(menu, "", button:GetWidth() - 8, function(self) ns.SetLanguage(self.value) end)
            b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 24); b:SetHeight(24); menu.buttons[i] = b
        end
        b.value = value; b.text:SetText(languageName(value)); b.text:SetJustifyH("LEFT")
        UI.Selected(b, ns.cfg.language == value)
    end
    menu:Show()
end
function ns.ToggleOptions()
    if ns.options then ns.UpdateOptions(); ns.options:SetShown(not ns.options:IsShown()); return end
    local f = UI.Frame("Frame", "EzWoWBagsOptions", UIParent); ns.options = f
    f.bindings, f.controls = {}, {}
    f:SetSize(400, 488); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); UI.Surface(f)
    f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetScript("OnHide", function() if ns.languageCombo then ns.languageCombo:Hide() end end)
    UISpecialFrames[#UISpecialFrames + 1] = "EzWoWBagsOptions"
    local function bind(update) f.bindings[#f.bindings + 1] = update end
    local function label(ko, en, x, y, width)
        local text = UI.Label(f, ""); text:SetPoint("TOPLEFT", x, -y)
        if width then text:SetWidth(width) end
        bind(function() text:SetText(optionLabel(ko, en)) end)
        return text
    end
    local title = UI.Label(f, "", 15); f.title = title; UI.Chrome(f, title)
    bind(function() title:SetText("EzWoW - Bags / " .. ns.T("settings")) end)
    local close = UI.CloseButton(f, function() f:Hide() end)
    f.languageLabel = label("언어", "Language", 18, 54)
    f.language = UI.Button(f, "", 212, function() ns.LanguageMenu() end)
    f.language:SetPoint("TOPLEFT", 170, -48)
    bind(function() f.language.text:SetText(languageName(ns.cfg.language) .. "  ▾") end)
    local function check(key, ko, en, index, hintKo, hintEn)
        local b = UI.Check(f, "", ns.cfg[key], function(value) ns.cfg[key] = value; ns.Refresh() end)
        b:SetPoint("TOPLEFT", index % 2 == 0 and 16 or 208, -82 - math.floor(index / 2) * 24)
        b.label:SetWidth(index % 2 == 0 and 160 or 144)
        f.controls[key] = b
        bind(function() b.label:SetText(optionLabel(ko, en)); b:SetChecked(ns.cfg[key]) end)
        if hintKo then
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(optionLabel(hintKo, hintEn), 1, 1, 1, true); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end
    check("replace", "기본 가방 대체", "Replace default bags", 0, "다음 로그인 또는 /reload 후 적용됩니다.", "Applies after login or /reload.")
    check("merge", "묶음 합계 표시", "Combine stacks", 1, "같은 아이템의 수량을 합칩니다. 클릭은 첫 묶음을 조작합니다.", "Combine identical item counts. Clicking acts on the first stack.")
    check("labels", "아이템 용도", "Purpose labels", 2)
    check("itemLevel", "장비 레벨", "Equipment levels", 3)
    check("emptySlots", "빈 칸 개별 표시", "Individual free slots", 4)
    check("newSection", "새 아이템 분류", "New item category", 5)
    local y = 162
    local function cycle(key, ko, en, values)
        label(ko, en, 18, y + 6, 192)
        local b = UI.Button(f, "", 162, function()
            local index = 1
            for i, value in ipairs(values) do if value == ns.cfg[key] then index = i % #values + 1; break end end
            ns.cfg[key] = values[index]; ns.UpdateOptions(); ns.Refresh()
        end)
        b:SetPoint("TOPLEFT", 220, -y); f.controls[key] = b
        bind(function() b.text:SetText(ns.T(tostring(ns.cfg[key]))) end)
        y = y + 26
    end
    cycle("view", "보기", "View", { "sections", "grid", "list" })
    cycle("itemSort", "아이템 정렬", "Item sorting", { "quality", "name" })
    cycle("sectionSort", "분류 정렬", "Category sorting", { "name", "size" })
    y = y + 4
    local function number(key, ko, en, lo, hi, step)
        label(ko, en, 18, y + 5, 192)
        local value = UI.Label(f, ""); value:SetPoint("TOPLEFT", 248, -y - 5); value:SetWidth(106); value:SetJustifyH("CENTER")
        local function adjust(delta)
            ns.cfg[key] = math.floor(math.max(lo, math.min(hi, ns.cfg[key] + delta)) * 100 + .5) / 100
            ns.UpdateOptions(); ns.Refresh()
        end
        local minus = UI.Button(f, "−", 24, function() adjust(-step) end); minus:SetPoint("TOPLEFT", 220, -y); minus:SetHeight(22)
        local plus = UI.Button(f, "+", 24, function() adjust(step) end); plus:SetPoint("TOPLEFT", 358, -y); plus:SetHeight(22)
        f.controls[key] = { minus = minus, plus = plus, value = value }
        bind(function()
            local text = tostring(ns.cfg[key])
            if key == "columns" and ns.cfg.view == "sections" then
                local counts = ns.BagLayout().columns
                text = text .. " (" .. table.concat(counts, "+") .. ")"
            end
            value:SetText(text)
        end)
        y = y + 24
    end
    number("columns", "줄당 칸 수 (전체)", "Items per row (total)", 6, 20, 1)
    number("sectionColumns", "분류 열 수", "Category columns", 1, 3, 1)
    number("size", "아이콘 크기", "Icon size", 28, 56, 2)
    number("scale", "창 크기", "Window scale", .65, 1.4, .05)
    number("opacity", "불투명도", "Opacity", .4, 1, .05)
    local restore = UI.Button(f, "", 178, function()
        for _, category in pairs(ns.cfg.categories) do category.hidden, category.disabled = nil, nil end
        ns.Refresh()
    end); restore:SetPoint("TOPLEFT", 18, -370)
    bind(function() restore.text:SetText(optionLabel("숨김·꺼진 분류 복원", "Restore categories")) end)
    local anchor = UI.Button(f, "", 178, function()
        ns.cfg.growUp = false; ns.window:ClearAllPoints()
        ns.window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -100)
        ns.ResizeWindow(ns.window:GetWidth(), ns.window:GetHeight())
    end); anchor:SetPoint("TOPLEFT", 204, -370)
    bind(function() anchor.text:SetText(optionLabel("창 위치 초기화", "Reset position")) end)
    label("분류 이름", "Category name", 18, 402, 110)
    label("검색식", "Search expression", 136, 402, 210)
    local name = UI.Edit(f, 110); name:SetPoint("TOPLEFT", 18, -418); f.categoryName = name
    local query = UI.Edit(f, 210); query:SetPoint("TOPLEFT", 136, -418); query:SetText(ns.window.search:GetText()); f.categoryQuery = query
    local add = UI.Button(f, "+", 28, function()
        local id, err = ns.AddCategory(name:GetText(), query:GetText())
        if id then name:SetText(""); query:SetText("") else ns.Print(err) end
    end); add:SetPoint("TOPLEFT", 354, -418)
    local hint = label("검색식을 비우면 아이템을 끌어 놓아 지정합니다.", "Leave the query empty to assign items by dragging.", 18, 450, 364)
    hint:SetHeight(28)
    ns.UpdateOptions()
end
