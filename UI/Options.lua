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
        line:SetPoint("TOPLEFT", 20, -y - 18); line:SetWidth(400)
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
        local b = UI.Check(f, "", ns.cfg[key], function(value)
            ns.cfg[key] = value
            if key == "replace" and ns.ApplyBagReplacement then ns.ApplyBagReplacement() end
            ns.Refresh()
        end)
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
    check("replace", "기본 가방 대체", "Replace default bags", "B 키와 가방 버튼이 기본 가방 대신 이 창을 엽니다. 바로 적용됩니다.", "B and the bag buttons open this window instead of the default bags. Applies immediately.")
    check("merge", "묶음 합계 표시", "Combine stacks", "같은 아이템의 수량을 합칩니다. 클릭은 첫 묶음을 조작합니다.", "Combine identical item counts. Clicking acts on the first stack.")
    endChecks()
    section("상인", "Merchant")
    check("autoSellJunk", "회색 잡템 자동 판매", "Auto-sell grey junk",
        "상점 창을 열면 가방의 회색(하급) 잡템을 모두 팔고 받은 금액을 알려 줍니다. Shift를 누른 채 상점을 열면 건너뜁니다.",
        "Sells every grey item in your bags when a merchant opens and reports the gold. Hold Shift while opening the merchant to skip.")
    check("autoRepair", "장비 자동 수리", "Auto-repair gear",
        "수리할 수 있는 상인을 열면 착용·가방의 모든 장비를 수리합니다. Shift를 누른 채 상점을 열면 건너뜁니다.",
        "Repairs all worn and carried gear at a merchant who can repair. Hold Shift while opening the merchant to skip.")
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
        if ns.LayoutLocked() then ns.Print(ns.Text("combat")); return end
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
    y = y + 40
    -- Second column: auction house helpers and item lock.
    local X, y2 = 440, 70
    local function section2(ko, en)
        local text = label(ko, en, X, y2)
        text:SetFontObject("GameFontNormal"); text:SetTextColor(unpack(UI.Theme.accent))
        local line = f:CreateTexture(nil, "ARTWORK")
        line:SetColorTexture(.204, .298, .357, .85); line:SetHeight(1)
        line:SetPoint("TOPLEFT", X, -y2 - 18); line:SetPoint("TOPRIGHT", -20, -y2 - 18)
        y2 = y2 + 26
    end
    local function check2(key, ko, en, hintKo, hintEn, after)
        local b = UI.Check(f, "", ns.cfg[key], function(value)
            ns.cfg[key] = value
            if after then after(value) end
            ns.Refresh()
        end)
        b:SetPoint("TOPLEFT", X - 2, -y2); b.label:SetWidth(360)
        f.controls[key] = b
        bind(function() b.label:SetText(optionLabel(ko, en)); b:SetChecked(ns.cfg[key]) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:AddLine(optionLabel(hintKo, hintEn), 1, 1, 1, true); GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        y2 = y2 + 26
    end
    section2("경매장", "Auction house")
    check2("ahSell", "판매 도우미 (Alt+클릭)", "Sell helper (Alt+click)",
        "경매장이 열려 있을 때 가방 아이템을 Alt+클릭하면 경매장 판매 창에 올리고 현재 최저가보다 조금 낮은 가격을 채웁니다. 등록 버튼은 직접 누릅니다.",
        "With the auction house open, Alt+click a bag item to place it in the auction house sell frame with a price just under the current lowest. You press the post button yourself.")
    check2("ahBuyPanel", "경매장 옆 구매 창", "Buy panel next to the auction house",
        "경매장을 열면 옆에 검색·구매 창을 엽니다. 가방 아이템 Alt+오른쪽 클릭, 시세 탭 오른쪽 클릭으로 검색합니다. 모든 구매는 확인 창에서 한 번 더 눌러야 합니다.",
        "Opens a search and buy panel beside the auction house. Alt+right-click a bag item or right-click a row in the price tab to search. Every purchase needs a click in a confirm dialog.",
        function() ns.AuctionTrade.ApplyOptions() end)
    check2("tooltipTrend", "툴팁에 시세 추세", "Price trend on tooltips",
        "아이템 툴팁에 최근 시세와 7일 평균 대비 변화(▲/▼)를 한 줄로 보여 줍니다.",
        "Shows the latest price and its change against the 7-day average (▲/▼) in one tooltip line.")
    local function label2(ko, en, yy) return label(ko, en, X, yy, 190) end
    label2("가격 낮추기", "Undercut", y2 + 6)
    local mode = UI.Button(f, "", 90, function()
        ns.cfg.ahUndercutMode = ns.cfg.ahUndercutMode == "percent" and "copper" or "percent"; ns.UpdateOptions()
    end)
    mode:SetPoint("TOPLEFT", X + 196, -y2)
    local amount = UI.Edit(f, 70, 24); amount:SetPoint("LEFT", mode, "RIGHT", 6, 0)
    local unit = UI.Label(f, ""); unit:SetPoint("LEFT", amount, "RIGHT", 6, 0)
    local function commit(self)
        local v = tonumber(self:GetText())
        if v and v == v then
            if ns.cfg.ahUndercutMode == "percent" then ns.cfg.ahUndercutPercent = math.max(0, math.min(50, math.floor(v * 10 + .5) / 10))
            else ns.cfg.ahUndercutCopper = math.max(0, math.min(10000000, math.floor(v))) end
        end
        ns.UpdateOptions()
    end
    amount:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    amount:SetScript("OnEditFocusLost", commit)
    bind(function()
        local percent = ns.cfg.ahUndercutMode == "percent"
        mode.text:SetText((percent and "%" or optionLabel("동", "Copper")) .. "  ⇄")
        unit:SetText(percent and "%" or optionLabel("동", "Copper"))
        if not amount:HasFocus() then amount:SetText(tostring(percent and ns.cfg.ahUndercutPercent or ns.cfg.ahUndercutCopper)) end
    end)
    y2 = y2 + 30
    do
        label2("시세 기록 보관 (일)", "Keep price history (days)", y2 + 5)
        local value = UI.Label(f, ""); value:SetPoint("TOPLEFT", X + 220, -y2 - 5); value:SetWidth(110); value:SetJustifyH("CENTER")
        local function adjust(delta)
            ns.cfg.historyDays = math.max(30, math.min(120, ns.cfg.historyDays + delta)); ns.UpdateOptions()
        end
        local minus = UI.Button(f, "-", 22, function() adjust(-10) end); minus:SetPoint("TOPLEFT", X + 196, -y2); minus:SetHeight(20)
        local plus = UI.Button(f, "+", 22, function() adjust(10) end); plus:SetPoint("TOPLEFT", X + 334, -y2); plus:SetHeight(20)
        bind(function() value:SetText(tostring(ns.cfg.historyDays)) end)
        y2 = y2 + 34
    end
    section2("아이템 잠금", "Item lock")
    check2("itemLock", "아이템 잠금 사용", "Use item lock",
        "잠근 아이템은 회색 잡템 자동 판매, 분류 이동(상인·우편·거래), 경매장 판매 도우미에서 빠집니다.",
        "Locked items are skipped by auto-selling junk, category moves (vendor, mail, trade) and the auction sell helper.")
    local clear = UI.Button(f, "", 186, function() ns.Locks.ClearAll(); ns.UpdateOptions(); ns.Refresh() end)
    clear:SetPoint("TOPLEFT", X, -y2)
    bind(function() clear.text:SetText(optionLabel("모든 잠금 해제", "Unlock all") .. " (" .. ns.Locks.Count() .. ")") end)
    y2 = y2 + 34
    local help = label("가방 아이템 클릭:\nCtrl+Alt+클릭 – 잠금/해제 (이 캐릭터)\nCtrl+Alt+오른쪽 클릭 – 계정 전체 잠금/해제\n경매장에서 Alt+클릭 – 판매 창에 올리기\n경매장에서 Alt+오른쪽 클릭 – 구매 창에서 찾기\n시세 탭: 클릭 – 그래프, 오른쪽 클릭 – 경매장에서 찾기",
        "Bag item clicks:\nCtrl+Alt+click – lock/unlock (this character)\nCtrl+Alt+right-click – lock/unlock for all characters\nAt the auction house, Alt+click – put into the sell frame\nAt the auction house, Alt+right-click – find in the buy panel\nPrice tab: click – graph, right-click – search the auction house",
        X, y2, 380)
    help:SetTextColor(unpack(UI.Theme.muted)); help:SetSpacing(3)
    y2 = y2 + 108
    f:SetWidth(840)
    f:SetHeight(math.max(y, y2) + 10)
    ns.UpdateOptions()
end
