local WT = WarlockTools
local SM = {}
WT:RegisterModule("SoulManager", SM)

local hudFrame = nil
local sessionFrame = nil
local counts = { shard = 0, healthstone = 0, soulstone = 0, spellstone = 0, firestone = 0 }
local foundItem = { shard = nil, healthstone = nil, soulstone = nil, spellstone = nil, firestone = nil }
local hudButtons = {}

function SM:Init()
    self:ScanBags()
    self:CreateHUD()
    self:CreateHSCreation()
    if WarlockToolsDB.hudVisible then
        hudFrame:Show()
    else
        hudFrame:Hide()
    end
    WT:RegisterEvents("BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD")
end

function SM:ScanBags()
    counts.shard = 0
    counts.healthstone = 0
    counts.soulstone = 0
    counts.spellstone = 0
    counts.firestone = 0
    foundItem.shard = nil
    foundItem.healthstone = nil
    foundItem.soulstone = nil
    foundItem.spellstone = nil
    foundItem.firestone = nil
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                local itemType = WT.ITEM_TYPE_SET[info.itemID]
                if itemType then
                    counts[itemType] = counts[itemType] + (info.stackCount or 0)
                    if not foundItem[itemType] then
                        foundItem[itemType] = info.itemID
                    end
                end
            end
        end
    end
    self:UpdateDisplays()
end

function SM:GetCounts()
    return counts
end

function SM:UpdateDisplays()
    for _, btn in ipairs(hudButtons) do
        local count = counts[btn.itemType] or 0
        btn.countText:SetText(count > 0 and count or "0")
        local itemID = foundItem[btn.itemType] or btn.defaultItemID
        local icon = GetItemIcon(itemID)
        if icon then btn.icon:SetTexture(icon) end
    end

    if sessionFrame and sessionFrame:IsShown() then
        self:UpdateSessionProgress()
    end
end

function SM:CreateHUD()
    hudFrame = CreateFrame("Frame", "WarlockToolsHUD", UIParent, "BackdropTemplate")
    local btnSize = WarlockToolsDB.hudButtonSize
    local vertical = WarlockToolsDB.hudVertical
    hudFrame:SetSize(btnSize + 16, btnSize + 16)
    hudFrame:SetPoint(
        WarlockToolsDB.hudPoint or "CENTER",
        UIParent,
        WarlockToolsDB.hudPoint or "CENTER",
        WarlockToolsDB.hudX or 0,
        WarlockToolsDB.hudY or 0
    )
    hudFrame:SetFrameStrata("LOW")
    hudFrame:SetClampedToScreen(true)
    hudFrame:SetMovable(true)
    hudFrame:EnableMouse(true)
    hudFrame:RegisterForDrag("LeftButton")
    hudFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    hudFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SavePosition()
    end)
    function hudFrame:SavePosition()
        local point, _, _, x, y = self:GetPoint()
        WarlockToolsDB.hudPoint = point
        WarlockToolsDB.hudX = x
        WarlockToolsDB.hudY = y
    end

    hudFrame:SetBackdrop(nil)

    local categories = {
        { type = "shard",      itemID = WT.SOUL_SHARD },
        { type = "healthstone", items = WT.HEALTHSTONE_ITEMS },
        { type = "soulstone",  items = WT.SOULSTONE_ITEMS },
        { type = "spellstone", items = WT.SPELLSTONE_ITEMS, extra = true },
        { type = "firestone",  items = WT.FIRESTONE_ITEMS,  extra = true },
    }

    local visIndex = 0
    for _, cat in ipairs(categories) do
        local defaultID = cat.itemID or cat.items[1]
        local btn = CreateFrame("Button", "WarlockToolsHUD" .. cat.type, hudFrame)
        btn:SetSize(btnSize, btnSize)

        local iconPath = GetItemIcon(defaultID)
        local iconTex = btn:CreateTexture(nil, "BACKGROUND")
        iconTex:SetAllPoints()
        if iconPath then iconTex:SetTexture(iconPath) end
        btn.icon = iconTex

        local normalTex
        if WT.Masque:IsEnabled() then
            normalTex = btn:CreateTexture(nil, "OVERLAY")
            normalTex:SetAllPoints()
            btn:SetNormalTexture(normalTex)
        end

        local countText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
        countText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
        btn.countText = countText
        btn.itemType = cat.type
        btn.defaultItemID = defaultID
        btn.isExtra = cat.extra or false

        WT.Masque:AddButton("HUD", btn, {
            Icon = iconTex,
            Normal = normalTex,
        })

        WT:PropagateDrag(btn)
        tinsert(hudButtons, btn)

        if btn.isExtra and not WarlockToolsDB.hudShowExtras then
            btn:Hide()
        else
            visIndex = visIndex + 1
            btn:ClearAllPoints()
            if vertical then
                btn:SetPoint("TOP", hudFrame, "TOP", 0, -8 - ((visIndex - 1) * (btnSize + 2)))
            else
                btn:SetPoint("LEFT", hudFrame, "LEFT", 8 + ((visIndex - 1) * (btnSize + 2)), 0)
            end
        end
    end

    local numVisible = visIndex
    if vertical then
        hudFrame:SetSize(btnSize + 16, (btnSize * numVisible) + ((numVisible - 1) * 2) + 16)
    else
        hudFrame:SetSize((btnSize * numVisible) + ((numVisible - 1) * 2) + 16, btnSize + 16)
    end

    WT.Masque:ReSkin("HUD")
end

function SM:ToggleHUD()
    if hudFrame:IsShown() then
        hudFrame:Hide()
        WarlockToolsDB.hudVisible = false
        print("|cff9482c9WarlockTools|r HUD hidden.")
    else
        hudFrame:Show()
        WarlockToolsDB.hudVisible = true
        print("|cff9482c9WarlockTools|r HUD shown.")
    end
end

function SM:RebuildHUD()
    if not hudFrame then return end
    local btnSize = WarlockToolsDB.hudButtonSize
    local vertical = WarlockToolsDB.hudVertical
    local showExtras = WarlockToolsDB.hudShowExtras

    local visIndex = 0
    for _, btn in ipairs(hudButtons) do
        btn:SetSize(btnSize, btnSize)
        btn:ClearAllPoints()
        if btn.isExtra and not showExtras then
            btn:Hide()
        else
            btn:Show()
            visIndex = visIndex + 1
            if vertical then
                btn:SetPoint("TOP", hudFrame, "TOP", 0, -8 - ((visIndex - 1) * (btnSize + 2)))
            else
                btn:SetPoint("LEFT", hudFrame, "LEFT", 8 + ((visIndex - 1) * (btnSize + 2)), 0)
            end
        end
    end

    if vertical then
        hudFrame:SetSize(btnSize + 16, (btnSize * visIndex) + ((visIndex - 1) * 2) + 16)
    else
        hudFrame:SetSize((btnSize * visIndex) + ((visIndex - 1) * 2) + 16, btnSize + 16)
    end
end

-- Healthstone Creation
function SM:CreateHSCreation()
    sessionFrame = CreateFrame("Frame", "WarlockToolsHSCreation", UIParent, "BackdropTemplate")
    sessionFrame:SetSize(220, 160)
    sessionFrame:SetPoint("CENTER")
    sessionFrame:SetFrameStrata("HIGH")
    sessionFrame:SetClampedToScreen(true)
    sessionFrame:SetMovable(true)
    sessionFrame:EnableMouse(true)
    sessionFrame:RegisterForDrag("LeftButton")
    sessionFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    sessionFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    sessionFrame:Hide()

    tinsert(UISpecialFrames, "WarlockToolsHSCreation")

    sessionFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    sessionFrame:SetBackdropColor(0, 0, 0, WarlockToolsDB.sessionBgAlpha)

    local closeBtn = CreateFrame("Button", nil, sessionFrame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", sessionFrame, "TOPRIGHT", -2, -2)

    local title = sessionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cff9482c9Healthstone Creation|r")

    local groupText = sessionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    groupText:SetPoint("TOP", 0, -32)
    sessionFrame.groupText = groupText

    local shardText = sessionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    shardText:SetPoint("TOP", 0, -52)
    sessionFrame.shardText = shardText

    local hsText = sessionFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hsText:SetPoint("TOP", 0, -72)
    sessionFrame.hsText = hsText

    local statusText = sessionFrame:CreateFontString(nil, "OVERLAY", "GameFontGreen")
    statusText:SetPoint("TOP", 0, -96)
    sessionFrame.statusText = statusText

    -- Create Healthstone button (secure)
    local hsBtn = CreateFrame("Button", "WarlockToolsCreateHS", sessionFrame, "SecureActionButtonTemplate")
    hsBtn:SetSize(140, 28)
    hsBtn:SetPoint("BOTTOM", sessionFrame, "BOTTOM", 0, 12)
    hsBtn:SetAttribute("type", "spell")
    -- Find highest rank Create Healthstone at runtime
    local hsSpellName = GetSpellInfo(27230) -- Create Healthstone (Rank 6)
    if hsSpellName then
        hsBtn:SetAttribute("spell", hsSpellName)
    end
    hsBtn:RegisterForClicks("AnyUp", "AnyDown")
    local hsNormal = hsBtn:GetNormalTexture()
    if hsNormal then hsNormal:SetTexture(nil); hsNormal:Hide() end
    hsBtn:SetNormalFontObject("GameFontNormal")
    hsBtn:SetText("Create Healthstone")
    local hsBtnTex = hsBtn:CreateTexture(nil, "BACKGROUND")
    hsBtnTex:SetAllPoints()
    hsBtnTex:SetTexture("Interface\\Buttons\\UI-Panel-Button-Up")
    hsBtnTex:SetTexCoord(0, 0.625, 0, 0.6875)
    WT:PropagateDrag(hsBtn)
    sessionFrame.hsBtn = hsBtn
end

function SM:GetServingCount()
    local th = WT.modules["TradeHelper"]
    local queueSize = th and th:GetQueueSize() or 0
    return math.max(1, queueSize)
end

function SM:UpdateSessionProgress()
    local serving = self:GetServingCount()
    local neededHS = serving * WarlockToolsDB.healthstonesPerPerson

    sessionFrame.groupText:SetText("Serving: " .. serving)
    sessionFrame.shardText:SetText("Shards: " .. counts.shard)
    sessionFrame.hsText:SetText("Healthstones: " .. counts.healthstone .. " / " .. neededHS)

    if counts.healthstone >= neededHS then
        sessionFrame.statusText:SetText("Ready!")
    elseif counts.shard < (neededHS - counts.healthstone) then
        sessionFrame.statusText:SetText("Need more shards!")
    else
        sessionFrame.statusText:SetText("")
    end
end

function SM:UpdateSessionIfShown()
    if sessionFrame and sessionFrame:IsShown() then
        self:UpdateSessionProgress()
    end
end

function SM:ToggleHSCreation()
    if sessionFrame:IsShown() then
        sessionFrame:Hide()
    else
        self:UpdateSessionProgress()
        sessionFrame:Show()
    end
end

function SM:OnEvent(event, ...)
    if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
        self:ScanBags()
    elseif event == "PLAYER_ENTERING_WORLD" then
        local isInitialLogin, isReloadingUi = ...
        if isInitialLogin and WarlockToolsDB.showSessionOnLogin then
            self:UpdateSessionProgress()
            sessionFrame:Show()
        end
    end
end
