local WT = WarlockTools
local OPT = {}
WT:RegisterModule("Options", OPT)

local optionsFrame = nil

local BG_COLOR = { 0.08, 0.08, 0.12, 0.98 }
local BORDER_COLOR = { 0.58, 0.51, 0.79, 1 }
local HEADER_COLOR = "|cffFFD200"
local ACCENT_COLOR = { 0.58, 0.51, 0.79 }

local TAB_HEIGHT = 24
local TAB_PAD = 4
local FRAME_WIDTH = 420
local FRAME_HEIGHT = 400

local function CreateHeader(parent, text, yOffset)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    label:SetText(HEADER_COLOR .. text .. "|r")
    local line = parent:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset - 14)
    line:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset - 14)
    line:SetColorTexture(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.4)
    return yOffset - 22
end

local function CreateCheckbox(parent, label, dbKey, yOffset, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    local cbText = cb.text or (cb.GetName and cb:GetName() and _G[cb:GetName() .. "Text"])
    if cbText then
        cbText:SetText(label)
        cbText:SetFontObject("GameFontHighlight")
    else
        local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        text:SetText(label)
    end
    cb:SetChecked(WarlockToolsDB[dbKey])
    cb:SetScript("OnClick", function(self)
        local checked = not not self:GetChecked()
        WarlockToolsDB[dbKey] = checked
        if onChange then onChange(checked) end
    end)
    return yOffset - 28
end

local function CreateSlider(parent, label, dbKey, minVal, maxVal, step, yOffset, onChange)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    text:SetText(label)
    local valueText = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, yOffset - 16)
    slider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -14, yOffset - 16)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local low = slider.Low or _G[slider:GetName() .. "Low"]
    local high = slider.High or _G[slider:GetName() .. "High"]
    local sliderText = slider.Text or _G[slider:GetName() .. "Text"]
    if low then low:SetText("") end
    if high then high:SetText("") end
    if sliderText then sliderText:SetText("") end
    local currentVal = WarlockToolsDB[dbKey]
    slider:SetValue(currentVal)
    local function FormatValue(val)
        if step < 1 then return string.format("%.2f", val) end
        return tostring(math.floor(val + 0.5))
    end
    valueText:SetText(FormatValue(currentVal))
    slider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / step + 0.5) * step
        WarlockToolsDB[dbKey] = value
        valueText:SetText(FormatValue(value))
        if onChange then onChange(value) end
    end)
    return yOffset - 42
end

local MOUSE_BUTTON_MAP = {
    LeftButton = "BUTTON1",
    RightButton = "BUTTON2",
    MiddleButton = "BUTTON3",
    Button4 = "BUTTON4",
    Button5 = "BUTTON5",
}

local function GetModifiedKey(key)
    local mods = ""
    if IsShiftKeyDown() then mods = mods .. "SHIFT-" end
    if IsControlKeyDown() then mods = mods .. "CTRL-" end
    if IsAltKeyDown() then mods = mods .. "ALT-" end
    return mods .. key
end

local function CreateKeybind(parent, label, dbKey, yOffset)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, yOffset)
    text:SetText(label)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(120, 22)
    btn:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -12, yOffset + 2)
    btn:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.15, 0.15, 0.15, 1)
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    local btnText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    btnText:SetPoint("CENTER")
    local waiting = false
    local function UpdateLabel()
        local key = WarlockToolsDB[dbKey]
        btnText:SetText(key or "|cff666666Not bound|r")
    end
    local function StopCapture(self)
        waiting = false
        self:SetScript("OnKeyDown", nil)
        self:SetScript("OnMouseDown", nil)
        self:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        self:EnableKeyboard(false)
        self:EnableMouse(true)
        UpdateLabel()
    end
    local function ApplyKey(self, key)
        WarlockToolsDB[dbKey] = key
        local pm = WT.modules["PopupMenu"]
        if pm and pm.ApplyKeybind then pm:ApplyKeybind() end
        StopCapture(self)
    end
    local function OnCaptureKey(self, key)
        if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
            or key == "LALT" or key == "RALT" then
            return
        end
        if key == "ESCAPE" then
            StopCapture(self)
        else
            ApplyKey(self, GetModifiedKey(key))
        end
    end
    local function OnCaptureMouse(self, mouseBtn)
        local wowKey = MOUSE_BUTTON_MAP[mouseBtn]
        if wowKey then
            ApplyKey(self, GetModifiedKey(wowKey))
        end
    end
    UpdateLabel()
    btn:SetScript("OnClick", function(self, click)
        if waiting then return end
        if click == "RightButton" then
            WarlockToolsDB[dbKey] = nil
            local pm = WT.modules["PopupMenu"]
            if pm and pm.ApplyKeybind then pm:ApplyKeybind() end
            UpdateLabel()
            return
        end
        waiting = true
        btnText:SetText("|cffFFD200Press a key...|r")
        self:SetBackdropBorderColor(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 1)
        self:EnableKeyboard(true)
        self:SetScript("OnKeyDown", OnCaptureKey)
        self:SetScript("OnMouseDown", OnCaptureMouse)
    end)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    return yOffset - 28
end

local function CreateKeywordEditor(parent, yOffset)
    local headerY = CreateHeader(parent, "Whisper Keywords", yOffset)
    yOffset = headerY
    local keywordFrame = CreateFrame("Frame", nil, parent)
    keywordFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, yOffset)
    keywordFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, yOffset)
    keywordFrame:SetHeight(120)
    local rows = {}
    local function RefreshKeywords()
        for _, row in ipairs(rows) do row:Hide() end
        local keywords = WarlockToolsDB.whisperKeywords
        for i, kw in ipairs(keywords) do
            local row = rows[i]
            if not row then
                row = CreateFrame("Frame", nil, keywordFrame)
                row:SetHeight(22)
                row:SetPoint("TOPLEFT", keywordFrame, "TOPLEFT", 0, -((i - 1) * 24))
                row:SetPoint("TOPRIGHT", keywordFrame, "TOPRIGHT", 0, -((i - 1) * 24))
                local kwText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                kwText:SetPoint("LEFT", 4, 0)
                row.kwText = kwText
                local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                removeBtn:SetSize(20, 20)
                removeBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
                removeBtn:SetText("x")
                removeBtn:SetNormalFontObject("GameFontNormalSmall")
                row.removeBtn = removeBtn
                rows[i] = row
            end
            row.kwText:SetText(kw)
            row.removeBtn:SetScript("OnClick", function()
                tremove(WarlockToolsDB.whisperKeywords, i)
                RefreshKeywords()
            end)
            row:Show()
        end
        keywordFrame:SetHeight(math.max(24, #keywords * 24 + 30))
    end
    local addBox = CreateFrame("EditBox", nil, keywordFrame, "InputBoxTemplate")
    addBox:SetSize(120, 20)
    addBox:SetAutoFocus(false)
    addBox:SetFontObject("GameFontHighlightSmall")
    addBox:EnableMouse(true)
    local addBtn = CreateFrame("Button", nil, keywordFrame, "UIPanelButtonTemplate")
    addBtn:SetSize(50, 22)
    addBtn:SetText("Add")
    addBtn:SetNormalFontObject("GameFontNormalSmall")
    local function RepositionAdd()
        local count = #WarlockToolsDB.whisperKeywords
        local addY = -(count * 24)
        addBox:ClearAllPoints()
        addBox:SetPoint("TOPLEFT", keywordFrame, "TOPLEFT", 4, addY - 2)
        addBtn:ClearAllPoints()
        addBtn:SetPoint("LEFT", addBox, "RIGHT", 6, 0)
    end
    local function DoAddKeyword()
        local newKW = strtrim(addBox:GetText())
        if newKW ~= "" then
            tinsert(WarlockToolsDB.whisperKeywords, newKW)
            addBox:SetText("")
            addBox:ClearFocus()
            RefreshKeywords()
            RepositionAdd()
        end
    end
    addBtn:SetScript("OnClick", DoAddKeyword)
    addBox:SetScript("OnEnterPressed", DoAddKeyword)
    addBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    RefreshKeywords()
    RepositionAdd()
    local totalHeight = (#WarlockToolsDB.whisperKeywords * 24) + 30
    return yOffset - totalHeight
end

local function BuildGeneralContent(parent)
    local y = -8
    y = CreateHeader(parent, "HUD", y)
    y = CreateCheckbox(parent, "Show HUD", "hudVisible", y, function(checked)
        if WarlockToolsHUD then
            if checked then WarlockToolsHUD:Show() else WarlockToolsHUD:Hide() end
        end
    end)
    y = CreateCheckbox(parent, "Vertical HUD", "hudVertical", y, function()
        local sm = WT.modules["SoulManager"]
        if sm and sm.RebuildHUD then sm:RebuildHUD() end
    end)
    y = CreateCheckbox(parent, "Show Spellstone/Firestone on HUD", "hudShowExtras", y, function()
        local sm = WT.modules["SoulManager"]
        if sm and sm.RebuildHUD then sm:RebuildHUD() end
    end)
    y = y - 6
    y = CreateSlider(parent, "HUD Button Size", "hudButtonSize", 24, 48, 2, y, function()
        local sm = WT.modules["SoulManager"]
        if sm and sm.RebuildHUD then sm:RebuildHUD() end
    end)
    y = CreateHeader(parent, "Healthstone Creation", y - 6)
    y = CreateCheckbox(parent, "Show Healthstone Creation on Login", "showSessionOnLogin", y)
    y = CreateHeader(parent, "Popup Menu", y - 6)
    y = CreateKeybind(parent, "Toggle Keybind", "popupKeybind", y)
    y = CreateCheckbox(parent, "Release to Cast", "popupReleaseMode", y, function()
        local pm = WT.modules["PopupMenu"]
        if pm then pm:UpdateReleaseMode() end
    end)
    y = CreateCheckbox(parent, "Close Popup on Cast", "popupCloseOnCast", y, function()
        local pm = WT.modules["PopupMenu"]
        if pm then pm:UpdateCloseOnCast() end
    end)
    y = CreateCheckbox(parent, "Open at Fixed Position", "popupFixedPosition", y, function()
        local pm = WT.modules["PopupMenu"]
        if pm then pm:UpdateFixedPosition() end
    end)
    y = CreateHeader(parent, "Popup Categories", y - 6)
    local categoryItems = {
        { label = "Show Buffs",   key = "buffs" },
        { label = "Show Stones",  key = "stones" },
        { label = "Show Demons",  key = "demons" },
        { label = "Show Utility", key = "utility" },
    }
    for _, item in ipairs(categoryItems) do
        local catKey = item.key
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, y)
        local cbText = cb.text or (cb.GetName and cb:GetName() and _G[cb:GetName() .. "Text"])
        if cbText then
            cbText:SetText(item.label)
            cbText:SetFontObject("GameFontHighlight")
        else
            local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
            text:SetText(item.label)
        end
        cb:SetChecked(WarlockToolsDB.popupCategories[catKey])
        cb:SetScript("OnClick", function(self)
            WarlockToolsDB.popupCategories[catKey] = not not self:GetChecked()
            local pm = WT.modules["PopupMenu"]
            if pm and pm.Rebuild then pm:Rebuild() end
        end)
        y = y - 28
    end
    parent:SetHeight(math.abs(y) + 8)
end

local function BuildTradeContent(parent)
    local y = -8
    y = CreateHeader(parent, "Auto-Reply", y)
    y = CreateCheckbox(parent, "Enable Auto-Reply", "autoReply", y)
    y = CreateCheckbox(parent, "Listen for Party Chat Requests", "listenPartyChat", y)
    y = CreateKeywordEditor(parent, y - 6)
    y = CreateHeader(parent, "Trade", y - 6)
    y = CreateCheckbox(parent, "Auto-Place Items in Trade", "autoPlaceItems", y)
    y = CreateSlider(parent, "Healthstones Per Person", "healthstonesPerPerson", 1, 5, 1, y)
    parent:SetHeight(math.abs(y) + 8)
end

local function BuildAppearanceContent(parent)
    local y = -8
    y = CreateHeader(parent, "Button Sizes", y)
    y = CreateSlider(parent, "Popup Button Size", "popupButtonSize", 28, 48, 2, y, function()
        local pm = WT.modules["PopupMenu"]
        if pm and pm.Rebuild then pm:Rebuild() end
    end)
    y = CreateHeader(parent, "Queue", y - 6)
    y = CreateSlider(parent, "Max Queue Display", "maxQueueDisplay", 5, 20, 1, y, function()
        local th = WT.modules["TradeHelper"]
        if th and th.RebuildQueue then th:RebuildQueue() end
    end)
    y = CreateHeader(parent, "Opacity", y - 6)
    y = CreateSlider(parent, "Session Background Opacity", "sessionBgAlpha", 0.0, 1.0, 0.05, y, function()
        if WarlockToolsHSCreation then
            WarlockToolsHSCreation:SetBackdropColor(0, 0, 0, WarlockToolsDB.sessionBgAlpha)
        end
    end)
    parent:SetHeight(math.abs(y) + 8)
end

local categoryDefs = {
    { name = "General",      builder = BuildGeneralContent },
    { name = "Trade Helper", builder = BuildTradeContent },
    { name = "Appearance",   builder = BuildAppearanceContent },
}

local function BuildOptionsLayout(parent, topOffset, contentWidth)
    local layout = {
        tabs = {},
        contentFrames = {},
        activeCategory = nil,
    }
    local tabBarY = topOffset - TAB_HEIGHT - TAB_PAD
    local sepLine = parent:CreateTexture(nil, "ARTWORK")
    sepLine:SetHeight(1)
    sepLine:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, tabBarY)
    sepLine:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -8, tabBarY)
    sepLine:SetColorTexture(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.3)
    local contentArea = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    contentArea:SetPoint("TOPLEFT", parent, "TOPLEFT", 6, tabBarY - 4)
    contentArea:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -26, 6)
    local function ShowCategory(index)
        if layout.activeCategory == index then return end
        layout.activeCategory = index
        for i, tab in ipairs(layout.tabs) do
            if i == index then
                tab:SetBackdropColor(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.3)
                tab:SetBackdropBorderColor(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.6)
            else
                tab:SetBackdropColor(0.1, 0.1, 0.14, 0.8)
                tab:SetBackdropBorderColor(0.25, 0.25, 0.3, 0.8)
            end
        end
        contentArea:SetScrollChild(layout.contentFrames[index])
        for i, frame in ipairs(layout.contentFrames) do
            if i == index then frame:Show() else frame:Hide() end
        end
    end
    local tabX = 8
    for i, def in ipairs(categoryDefs) do
        local tab = CreateFrame("Button", nil, parent, "BackdropTemplate")
        tab:SetHeight(TAB_HEIGHT)
        tab:SetBackdrop({
            bgFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeFile = "Interface\\BUTTONS\\WHITE8X8",
            edgeSize = 1,
        })
        local tabLabel = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        tabLabel:SetPoint("CENTER", 0, 0)
        tabLabel:SetText(def.name)
        tab.label = tabLabel
        local textWidth = tabLabel:GetStringWidth()
        tab:SetWidth(textWidth + 20)
        tab:SetPoint("TOPLEFT", parent, "TOPLEFT", tabX, topOffset)
        tabX = tabX + textWidth + 20 + TAB_PAD
        tab:SetScript("OnEnter", function(self)
            if layout.activeCategory ~= i then
                self:SetBackdropColor(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.15)
            end
        end)
        tab:SetScript("OnLeave", function(self)
            if layout.activeCategory ~= i then
                self:SetBackdropColor(0.1, 0.1, 0.14, 0.8)
            end
        end)
        tab:SetScript("OnClick", function() ShowCategory(i) end)
        tinsert(layout.tabs, tab)
        local content = CreateFrame("Frame", nil, contentArea)
        local w = contentWidth or parent:GetWidth() - 36
        if w < 100 then w = 340 end
        content:SetWidth(w)
        content:SetHeight(FRAME_HEIGHT)
        content:Hide()
        def.builder(content)
        tinsert(layout.contentFrames, content)
    end
    ShowCategory(1)
    layout.ShowCategory = ShowCategory
    return layout
end

local function CreateOptionsFrame()
    local f = CreateFrame("Frame", "WarlockToolsOptions", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:SetClampedToScreen(true)
    f:Hide()
    f:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], BG_COLOR[4])
    f:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
    tinsert(UISpecialFrames, "WarlockToolsOptions")
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff9482c9WarlockTools Options|r")
    local titleLine = f:CreateTexture(nil, "ARTWORK")
    titleLine:SetHeight(1)
    titleLine:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -32)
    titleLine:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -32)
    titleLine:SetColorTexture(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.5)
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    BuildOptionsLayout(f, -36, FRAME_WIDTH - 36)
    return f
end

function OPT:Toggle()
    if not optionsFrame then optionsFrame = CreateOptionsFrame() end
    if optionsFrame:IsShown() then optionsFrame:Hide() else optionsFrame:Show() end
end

function OPT:Show()
    if not optionsFrame then optionsFrame = CreateOptionsFrame() end
    optionsFrame:Show()
end

function OPT:Hide()
    if optionsFrame then optionsFrame:Hide() end
end

function OPT:RegisterBlizzardOptions()
    local panel = CreateFrame("Frame")
    panel.name = "WarlockTools"
    local initialized = false
    panel:SetScript("OnShow", function(self)
        if initialized then return end
        initialized = true
        local title = self:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 16, -16)
        title:SetText("|cff9482c9WarlockTools|r")
        local titleLine = self:CreateTexture(nil, "ARTWORK")
        titleLine:SetHeight(1)
        titleLine:SetPoint("TOPLEFT", self, "TOPLEFT", 16, -38)
        titleLine:SetPoint("TOPRIGHT", self, "TOPRIGHT", -16, -38)
        titleLine:SetColorTexture(ACCENT_COLOR[1], ACCENT_COLOR[2], ACCENT_COLOR[3], 0.5)
        BuildOptionsLayout(self, -44)
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function OPT:Init()
    self:RegisterBlizzardOptions()
end
