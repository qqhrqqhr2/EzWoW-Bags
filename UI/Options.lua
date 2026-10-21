local _, ns = ...
local UI = ns.UI
local optionLabel = function(ko, en) return ns.Lang(ko, en) end
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
    if ns.menu then ns.menu:Hide() end
    if ns.characterCombo then ns.characterCombo:Hide() end
    ns.UpdateOptions(); ns.Refresh()
    if ns.options and ns.options.language then ns.LanguageDropdown.Refresh(ns.options.language) end
end
local comboColors = { bg = UI.Theme.bg, border = UI.Theme.border, accent = UI.Theme.accent, text = UI.Theme.text }
function ns.ToggleOptions()
    if ns.options then ns.UpdateOptions(); ns.options:SetShown(not ns.options:IsShown()); return end
    local f = UI.Frame("Frame", "EzWoWBagsOptions", UIParent); ns.options = f
    f.bindings, f.controls = {}, {}
    f:SetSize(420, 600); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); UI.Surface(f)
    f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UISpecialFrames[#UISpecialFrames + 1] = "EzWoWBagsOptions"
    local function bind(update) f.bindings[#f.bindings + 1] = update end
    local function label(ko, en, x, y, width)
        local text = UI.Label(f, ""); text:SetPoint("TOPLEFT", x, -y)
        if width then text:SetWidth(width) end
        bind(function() text:SetText(optionLabel(ko, en)) end)
        return text
    end
    local title = UI.Label(f, "", 15); f.title = title; UI.Chrome(f, title)
    bind(function()
        title:SetText("EzWoW - Bags")
        f.subtitle:SetText(ns.T("settings") .. " · " .. ns.Text("subtitle"))
    end)
    UI.CloseButton(f, function() f:Hide() end)
    local y = 70
    -- section heading: accent title with a thin line under it (same as the other EzWoW settings)
    local function section(ko, en)
        local text = label(ko, en, 20, y)
        text:SetFontObject("GameFontNormal"); text:SetTextColor(unpack(UI.Theme.accent))
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(.204, .298, .357, .85); line:SetHeight(1)
        line:SetPoint("TOPLEFT", 20, -y - 18); line:SetPoint("TOPRIGHT", -20, -y - 18)
        y = y + 26
    end
    section("일반", "General")
    f.languageLabel = label("언어", "Language", 20, y + 6, 180)
    f.language = UI.Button(f, "", 182, nil)
    f.language:SetPoint("TOPLEFT", 218, -y)
    local languageItems = {}
    for i, value in ipairs(ns.languages) do
        languageItems[i] = { value = value, text = function() return languageName(value) end }
    end
    ns.LanguageDropdown.Attach(f.language, {
        items = languageItems, colors = comboColors, window = f,
        get = function() return ns.cfg.language end,
        set = function(value) ns.SetLanguage(value) end,
    })
    bind(function() f.language.text:SetText(languageName(ns.cfg.language) .. "  ▾") end)
    y = y + 30
    local column = 0
    local function check(key, ko, en, hintKo, hintEn)
        local b = UI.Check(f, "", ns.cfg[key], function(value) ns.cfg[key] = value; ns.Refresh() end)
        b:SetPoint("TOPLEFT", column == 0 and 18 or 216, -y)
        b.label:SetWidth(166)
        f.controls[key] = b
        bind(function() b.label:SetText(optionLabel(ko, en)); b:SetChecked(ns.cfg[key]) end)
        if hintKo then
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(optionLabel(hintKo, hintEn), 1, 1, 1, true); GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        column = 1 - column
        if column == 0 then y = y + 26 end
    end
    local function endChecks() if column == 1 then column = 0; y = y + 26 end; y = y + 8 end
    check("replace", "기본 가방 대체", "Replace default bags", "다음 로그인 또는 /reload 후 적용됩니다.", "Applies after login or /reload.")
    check("merge", "묶음 합계 표시", "Combine stacks", "같은 아이템의 수량을 합칩니다. 클릭은 첫 묶음을 조작합니다.", "Combine identical item counts. Clicking acts on the first stack.")
    endChecks()
    section("아이콘 표시", "Item icons")
    check("labels", "아이템 용도", "Purpose labels")
    check("itemLevel", "장비 레벨", "Equipment levels")
    check("emptySlots", "빈 칸 개별 표시", "Individual free slots")
    check("newSection", "새 아이템 분류", "New item category")
    endChecks()
    section("보기", "View")
    local function choice(key, ko, en, values)
        label(ko, en, 20, y + 6, 190)
        local b = UI.Button(f, "", 182, nil)
        b:SetPoint("TOPLEFT", 218, -y); f.controls[key] = b
        local choices = {}
        for i, value in ipairs(values) do choices[i] = { value = value, text = function() return ns.T(value) end } end
        local list = ns.LanguageDropdown.Attach(b, {
            items = choices, colors = comboColors, window = f,
            get = function() return ns.cfg[key] end,
            set = function(value) ns.cfg[key] = value; ns.UpdateOptions(); ns.Refresh() end,
        })
        -- the shared combo marks language boxes with .languageList; this one is a plain choice box
        b.languageList, b.choiceList = nil, list
        bind(function() b.text:SetText(ns.T(tostring(ns.cfg[key])) .. "  ▾") end)
        y = y + 28
    end
    choice("view", "보기", "View", { "sections", "grid", "list" })
    choice("itemSort", "아이템 정렬", "Item sorting", { "quality", "name" })
    choice("sectionSort", "분류 정렬", "Category sorting", { "name", "size" })
    y = y + 2
    local function number(key, ko, en, lo, hi, step)
        label(ko, en, 20, y + 5, 190)
        local value = UI.Label(f, ""); value:SetPoint("TOPLEFT", 244, -y - 5); value:SetWidth(130); value:SetJustifyH("CENTER")
        local function adjust(delta)
            ns.cfg[key] = math.floor(math.max(lo, math.min(hi, ns.cfg[key] + delta)) * 100 + .5) / 100
            ns.UpdateOptions(); ns.Refresh()
        end
        local minus = UI.Button(f, "-", 22, function() adjust(-step) end); minus:SetPoint("TOPLEFT", 218, -y); minus:SetHeight(20)
        local plus = UI.Button(f, "+", 22, function() adjust(step) end); plus:SetPoint("TOPLEFT", 378, -y); plus:SetHeight(20)
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
    y = y + 8
    section("분류·창", "Categories & window")
    local restore = UI.Button(f, "", 186, function()
        for _, category in pairs(ns.cfg.categories) do category.hidden, category.disabled = nil, nil end
        ns.Refresh()
    end); restore:SetPoint("TOPLEFT", 20, -y)
    bind(function() restore.text:SetText(optionLabel("숨김·꺼진 분류 복원", "Restore categories")) end)
    local anchor = UI.Button(f, "", 186, function()
        ns.cfg.growUp = false; ns.window:ClearAllPoints()
        ns.window:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 40, -100)
        ns.ResizeWindow(ns.window:GetWidth(), ns.window:GetHeight())
    end); anchor:SetPoint("TOPLEFT", 214, -y)
    bind(function() anchor.text:SetText(optionLabel("창 위치 초기화", "Reset position")) end)
    y = y + 34
    label("분류 이름", "Category name", 20, y, 120)
    label("검색식", "Search expression", 146, y, 220)
    y = y + 16
    local name = UI.Edit(f, 120); name:SetPoint("TOPLEFT", 20, -y); f.categoryName = name
    local query = UI.Edit(f, 216); query:SetPoint("TOPLEFT", 146, -y); query:SetText(ns.window.search:GetText()); f.categoryQuery = query
    local add = UI.Button(f, "+", 28, function()
        local id, err = ns.AddCategory(name:GetText(), query:GetText())
        if id then name:SetText(""); query:SetText("") else ns.Print(err) end
    end); add:SetPoint("TOPLEFT", 372, -y)
    y = y + 32
    local hint = label("검색식을 비우면 아이템을 끌어 놓아 지정합니다.", "Leave the query empty to assign items by dragging.", 20, y, 380)
    hint:SetHeight(28); hint:SetTextColor(unpack(UI.Theme.muted))
    f:SetHeight(y + 40)
    ns.UpdateOptions()
end
