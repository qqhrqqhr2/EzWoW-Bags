-- Game Settings > AddOns page: a short description and a button that opens the settings window
local _, ns = ...
local UI = ns.UI
local PANEL_TITLE = "EzWoW - Bags"
local panel

local function register()
    if panel then return end
    panel = CreateFrame("Frame", "EzWoWBagsOptionsPanel", UIParent)
    panel.name = PANEL_TITLE

    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32); icon:SetPoint("TOPLEFT", 18, -18)
    icon:SetTexture("Interface\\AddOns\\EzWoW-Bags\\Media\\Icon")

    local heading = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    heading:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    heading:SetText(PANEL_TITLE)
    heading:SetTextColor(unpack(UI.Theme.accent))

    local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -14)
    desc:SetWidth(520); desc:SetJustifyH("LEFT")

    local open = UI.Button(panel, "", 220, function()
        if not (ns.options and ns.options:IsShown()) then ns.ToggleOptions() end
    end)
    open:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -18)

    local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -14)
    hint:SetTextColor(unpack(UI.Theme.muted))

    local function refresh()
        desc:SetText(ns.Text("subtitle"))
        open.text:SetText(ns.T("settings") .. " (/ezb settings)")
        hint:SetText(ns.Lang("채팅창에 /ezb settings를 입력해도 열립니다.", "Type /ezb settings in chat to open settings."))
    end
    panel:SetScript("OnShow", refresh)
    refresh()

    if Settings and type(Settings.RegisterCanvasLayoutCategory) == "function" and type(Settings.RegisterAddOnCategory) == "function" then
        local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, PANEL_TITLE)
        if ok and category then pcall(Settings.RegisterAddOnCategory, category) end
    elseif type(InterfaceOptions_AddCategory) == "function" then
        pcall(InterfaceOptions_AddCategory, panel)
    end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterAllEvents()
    pcall(register)
end)
