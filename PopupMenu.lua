local WT = WarlockTools
local PM = {}
WT:RegisterModule("PopupMenu", PM)

local popup = nil
local buttons = {}
local labels = {}
local BUTTON_PADDING = 4
local BLOCK_GAP = 6

local function FindSpellInBook(targetName)
    local foundID
    local i = 1
    while true do
        local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not name then break end
        if name == targetName then
            local _, id = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
            foundID = id
        end
        i = i + 1
    end
    return foundID
end

BINDING_HEADER_WARLOCKTOOLS = "WarlockTools"
BINDING_NAME_WARLOCKTOOLS_POPUP = "Toggle Spell Menu"

function WarlockTools_TogglePopup()
    if not popup or InCombatLockdown() then return end
    if popup:IsShown() then
        popup:Hide()
    else
        PM:ShowAtCursor()
    end
end

local toggleBtn = nil

function PM:Init()
    self:CreateToggleButton()
    self:UpdateReleaseMode()
    self:CreatePopup()
    self:ApplyKeybind()
    self:UpdateCloseOnCast()
    WT:RegisterEvents("SPELLS_CHANGED", "PLAYER_REGEN_ENABLED")
end

function PM:CreateToggleButton()
    toggleBtn = CreateFrame("Button", "WarlockToolsPopupToggle", UIParent, "SecureActionButtonTemplate")
    RegisterAttributeDriver(toggleBtn, "state-combat", "[combat] 1; nil")
    toggleBtn:SetSize(1, 1)
    toggleBtn:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -100, 100)
    toggleBtn:RegisterForClicks("AnyDown", "AnyUp")

    function toggleBtn:WLT_PositionPopup()
        if popup then
            popup:ClearAllPoints()
            local x, y = GetCursorPosition()
            local scale = UIParent:GetEffectiveScale()
            popup:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
        end
    end

    SecureHandlerWrapScript(toggleBtn, "OnClick", toggleBtn, [[
        self:SetAttribute("type", nil)
        self:SetAttribute("typerelease", nil)

        local rm = self:GetAttribute("releasemode")
        local sp = self:GetAttribute("wltspell")
        local isOpen = self:GetAttribute("popupopen")
        local p = self:GetFrameRef("popup")

        if not rm then
            if p:IsShown() then
                p:Hide()
            else
                if not self:GetAttribute("state-combat") then
                    self:CallMethod("WLT_PositionPopup")
                else
                    p:ClearAllPoints()
                    p:SetPoint("CENTER")
                end
                p:Show()
            end
            return
        end

        if not isOpen then
            self:SetAttribute("wltspell", nil)
            self:SetAttribute("popupopen", 1)
            if not self:GetAttribute("state-combat") then
                self:CallMethod("WLT_PositionPopup")
            else
                p:ClearAllPoints()
                p:SetPoint("CENTER")
            end
            p:Show()
        elseif sp then
            self:SetAttribute("popupopen", nil)
            p:Hide()
            self:SetAttribute("pressAndHoldAction", 1)
            self:SetAttribute("type", "spell")
            self:SetAttribute("typerelease", "spell")
            self:SetAttribute("spell", sp)
            return "cast"
        else
            self:SetAttribute("popupopen", nil)
            p:Hide()
        end
    ]])
end

function PM:UpdateReleaseMode()
    if toggleBtn then
        toggleBtn:SetAttribute("releasemode", WarlockToolsDB.popupReleaseMode and true or nil)
    end
end

function PM:ApplyKeybind()
    if not toggleBtn then return end
    ClearOverrideBindings(toggleBtn)
    local key = WarlockToolsDB.popupKeybind
    if key then
        SetOverrideBindingClick(toggleBtn, true, key, "WarlockToolsPopupToggle")
    end
end

function PM:CreatePopup()
    popup = CreateFrame("Frame", "WarlockToolsPopup", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("DIALOG")
    popup:SetClampedToScreen(true)
    popup:Hide()
    popup:EnableMouse(false)

    tinsert(UISpecialFrames, "WarlockToolsPopup")

    popup:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.08, 0.08, 0.12, WarlockToolsDB.popupBgAlpha)
    popup:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)

    SecureHandlerSetFrameRef(toggleBtn, "popup", popup)

    popup:SetScript("OnHide", function()
        if not InCombatLockdown() then
            PM:ApplyKeybind()
            if toggleBtn then
                toggleBtn:SetAttribute("type", nil)
                toggleBtn:SetAttribute("spell", nil)
                toggleBtn:SetAttribute("wltspell", nil)
                toggleBtn:SetAttribute("popupopen", nil)
            end
        end
    end)

    self:BuildButtons()
end

local function CreateSpellButton(spell, prefix, index)
    local btnSize = WarlockToolsDB.popupButtonSize
    local btn = CreateFrame("Button", "WarlockTools" .. prefix .. "Btn" .. index, popup, "SecureActionButtonTemplate")
    btn:SetSize(btnSize, btnSize)

    btn:SetAttribute("type", "spell")
    local spellName, _, icon = GetSpellInfo(spell.spellID)
    btn:SetAttribute("spell", spellName)
    btn:RegisterForClicks("AnyUp", "AnyDown")

    local tmplNormal = btn:GetNormalTexture()
    if tmplNormal then
        tmplNormal:SetTexture(nil)
        tmplNormal:Hide()
    end

    local iconTex = btn:CreateTexture(nil, "ARTWORK")
    iconTex:SetPoint("TOPLEFT", 1, -1)
    iconTex:SetPoint("BOTTOMRIGHT", -1, 1)
    iconTex:SetTexture(icon)
    btn.icon = iconTex

    local normalTex, highlightTex
    if WT.Masque:IsEnabled() then
        normalTex = btn:CreateTexture(nil, "OVERLAY")
        normalTex:SetAllPoints()
        btn:SetNormalTexture(normalTex)
    else
        local border = btn:CreateTexture(nil, "BACKGROUND")
        border:SetAllPoints()
        border:SetColorTexture(0, 0, 0, 1)
    end

    highlightTex = btn:CreateTexture(nil, "HIGHLIGHT")
    highlightTex:SetAllPoints()
    highlightTex:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    highlightTex:SetBlendMode("ADD")
    btn:SetHighlightTexture(highlightTex)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(spell.spellID)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    SecureHandlerWrapScript(btn, "OnEnter", toggleBtn, [[
        if owner:GetAttribute("releasemode") then
            owner:SetAttribute("wltspell", self:GetAttribute("spell"))
        end
    ]])
    SecureHandlerWrapScript(btn, "OnLeave", toggleBtn, [[
        if owner:GetAttribute("releasemode") then
            owner:SetAttribute("wltspell", nil)
        end
    ]])

    SecureHandlerWrapScript(btn, "OnClick", toggleBtn, "", [[
        if owner:GetAttribute("closeOnCast") then
            local p = owner:GetFrameRef("popup")
            if p and p:IsShown() then
                p:Hide()
            end
        end
    ]])

    WT.Masque:AddButton("Popup", btn, {
        Icon = iconTex,
        Normal = normalTex,
        Highlight = highlightTex,
    })

    tinsert(buttons, btn)
    return btn
end

function PM:BuildButtons()
    for _, btn in ipairs(buttons) do btn:Hide() end
    wipe(buttons)
    for _, lbl in ipairs(labels) do lbl:Hide() end
    wipe(labels)

    local cats = WarlockToolsDB.popupCategories

    -- Buffs
    local buffSpells = {}
    if cats.buffs then
        for _, name in ipairs(WT.BUFF_NAMES) do
            local id = FindSpellInBook(name)
            if id then tinsert(buffSpells, { spellID = id }) end
        end
    end

    -- Stones
    local stoneSpells = {}
    if cats.stones then
        for _, name in ipairs(WT.STONE_NAMES) do
            local id = FindSpellInBook(name)
            if id then tinsert(stoneSpells, { spellID = id }) end
        end
    end

    -- Demons
    local demonSpells = {}
    if cats.demons then
        for _, demon in ipairs(WT.DEMONS) do
            if IsSpellKnown(demon.spellID) then
                tinsert(demonSpells, demon)
            end
        end
    end

    -- Utility
    local utilitySpells = {}
    if cats.utility then
        for _, name in ipairs(WT.UTILITY_NAMES) do
            local id = FindSpellInBook(name)
            if id then tinsert(utilitySpells, { spellID = id }) end
        end
    end

    local quadrants = {
        { spells = buffSpells,    prefix = "Buff",    label = "Buffs" },
        { spells = stoneSpells,   prefix = "Stone",   label = "Stones" },
        { spells = demonSpells,   prefix = "Demon",   label = "Demons" },
        { spells = utilitySpells, prefix = "Utility", label = "Utility" },
    }

    local btnSize = WarlockToolsDB.popupButtonSize
    local spacing = btnSize + BUTTON_PADDING
    local maxAbsX = 0
    local maxAbsY = 0
    local LABEL_GAP = 2

    for qIdx, q in ipairs(quadrants) do
        if #q.spells > 0 then
            local blockCols = WarlockToolsDB.popupColumns
            local cols = math.min(#q.spells, blockCols)
            local rows = math.ceil(#q.spells / blockCols)
            local blockW = cols * spacing
            local blockH = rows * spacing

            local col = 0
            local row = 0
            for i, spell in ipairs(q.spells) do
                local btn = CreateSpellButton(spell, q.prefix, i)

                local bx, by
                if qIdx == 1 then
                    bx = -BLOCK_GAP - blockW + col * spacing + btnSize / 2
                    by =  BLOCK_GAP + blockH - row * spacing - btnSize / 2
                elseif qIdx == 2 then
                    bx =  BLOCK_GAP + col * spacing + btnSize / 2
                    by =  BLOCK_GAP + blockH - row * spacing - btnSize / 2
                elseif qIdx == 3 then
                    bx = -BLOCK_GAP - blockW + col * spacing + btnSize / 2
                    by = -BLOCK_GAP - row * spacing - btnSize / 2
                else
                    bx =  BLOCK_GAP + col * spacing + btnSize / 2
                    by = -BLOCK_GAP - row * spacing - btnSize / 2
                end

                btn:ClearAllPoints()
                btn:SetPoint("CENTER", popup, "CENTER", bx, by)

                local edgeX = math.abs(bx) + btnSize / 2
                local edgeY = math.abs(by) + btnSize / 2
                if edgeX > maxAbsX then maxAbsX = edgeX end
                if edgeY > maxAbsY then maxAbsY = edgeY end

                col = col + 1
                if col >= blockCols then
                    col = 0
                    row = row + 1
                end
            end

            local lbl = popup:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            lbl:SetText(q.label)
            lbl:SetTextColor(0.58, 0.51, 0.79, 0.8)

            if qIdx == 1 then
                lbl:SetPoint("BOTTOMRIGHT", popup, "CENTER", -BLOCK_GAP, BLOCK_GAP + blockH + LABEL_GAP)
            elseif qIdx == 2 then
                lbl:SetPoint("BOTTOMLEFT", popup, "CENTER", BLOCK_GAP, BLOCK_GAP + blockH + LABEL_GAP)
            elseif qIdx == 3 then
                lbl:SetPoint("TOPRIGHT", popup, "CENTER", -BLOCK_GAP, -BLOCK_GAP - blockH - LABEL_GAP)
            else
                lbl:SetPoint("TOPLEFT", popup, "CENTER", BLOCK_GAP, -BLOCK_GAP - blockH - LABEL_GAP)
            end

            tinsert(labels, lbl)

            local labelEdgeY = BLOCK_GAP + blockH + LABEL_GAP + 12
            if labelEdgeY > maxAbsY then maxAbsY = labelEdgeY end
        end
    end

    WT.Masque:ReSkin("Popup")

    local EDGE_PADDING = 8
    if maxAbsX > 0 and maxAbsY > 0 then
        popup:SetSize((maxAbsX + EDGE_PADDING) * 2, (maxAbsY + EDGE_PADDING) * 2)
    else
        popup:SetSize(1, 1)
    end
end

function PM:ShowAtCursor()
    if InCombatLockdown() then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale

    popup:ClearAllPoints()
    popup:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    popup:Show()
end

function PM:UpdateCloseOnCast()
    if toggleBtn then
        toggleBtn:SetAttribute("closeOnCast", WarlockToolsDB.popupCloseOnCast and true or nil)
    end
end

function PM:Rebuild()
    if popup then
        self:BuildButtons()
    end
end

function PM:OnEvent(event, ...)
    if event == "SPELLS_CHANGED" then
        if popup then
            self:BuildButtons()
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if toggleBtn and not popup:IsShown() then
            toggleBtn:SetAttribute("type", nil)
            toggleBtn:SetAttribute("spell", nil)
            toggleBtn:SetAttribute("wltspell", nil)
            toggleBtn:SetAttribute("popupopen", nil)
        end
        PM:ApplyKeybind()
    end
end
