local WT = WarlockTools
local WN = {}
WT:RegisterModule("WhatsNew", WN)

local whatsNewFrame = nil

local changelog = {
    {
        version = "1.1.2",
        features = {},
        fixes = {
            "Fixed popup not dismissible via keybind when using fixed-position mode",
            "Fixed popup staying visible when toggling off fixed-position mode",
            "Toggling on fixed-position mode now immediately shows popup for repositioning",
        },
    },
    {
        version = "1.1.1",
        features = {},
        fixes = {
            "Fixed popup closing immediately in release mode when fixed-position is enabled, preventing drag repositioning",
        },
    },
    {
        version = "1.1.0",
        features = {
            "Open at Fixed Position option for popup menu",
            "Popup is draggable when fixed-position mode is enabled; position persists across sessions",
        },
        fixes = {},
    },
    {
        version = "1.0.1",
        features = {},
        fixes = {
            "Hide Demon Skin from popup menu when Demon Armor is known",
        },
    },
    {
        version = "1.0.0",
        features = {
            "Initial release: HUD, popup spell menu, trade helper, healthstone creation",
            "Shard/healthstone/soulstone/spellstone/firestone tracking",
            "Whisper queue with auto-reply and trade distribution",
            "X-layout popup with buffs, stones, demons, utility quadrants",
            "Release-to-cast mode with keybind support",
            "Tabbed options panel with Blizzard integration",
            "Masque button skinning support",
            "Onboarding tour",
        },
        fixes = {},
    },
}

function WN:GetChangelog()
    return changelog
end

function WN:ShouldShow()
    local currentVersion = WT.version
    local lastSeen = WarlockToolsDB.lastSeenVersion
    return lastSeen == nil or lastSeen ~= currentVersion
end

function WN:MarkAsSeen()
    WarlockToolsDB.lastSeenVersion = WT.version
end

local function CreateWhatsNewFrame()
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:SetAllPoints()
    overlay:SetFrameStrata("FULLSCREEN_DIALOG")
    overlay:SetFrameLevel(199)
    overlay:EnableMouse(true)
    local overlayTex = overlay:CreateTexture(nil, "BACKGROUND")
    overlayTex:SetAllPoints()
    overlayTex:SetColorTexture(0, 0, 0, 0.5)
    overlay:Hide()

    local f = CreateFrame("Frame", "WarlockToolsWhatsNew", UIParent, "BackdropTemplate")
    f:SetSize(420, 360)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 50)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetFrameLevel(200)
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
    f:SetBackdropColor(0.08, 0.08, 0.12, 0.98)
    f:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)

    tinsert(UISpecialFrames, "WarlockToolsWhatsNew")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText("|cff9482c9What's New in WarlockTools v" .. WT.version .. "|r")
    f.title = title

    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -36)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -36)
    line:SetColorTexture(0.58, 0.51, 0.79, 0.5)

    local scrollFrame = CreateFrame("ScrollFrame", "WarlockToolsWhatsNewScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -42)
    scrollFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 44)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(scrollFrame:GetWidth(), 1)
    scrollFrame:SetScrollChild(scrollChild)
    f.scrollChild = scrollChild

    local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btn:SetSize(100, 26)
    btn:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    btn:SetText("Got it!")
    btn:SetScript("OnClick", function()
        WN:Hide()
    end)

    f.overlay = overlay
    return f
end

local function PopulateChangelog(frame)
    local children = { frame.scrollChild:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    local scrollWidth = frame.scrollChild:GetWidth()
    if scrollWidth < 10 then scrollWidth = 370 end
    local yOffset = 0

    for i, entry in ipairs(changelog) do
        local header = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        header:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 0, yOffset)
        header:SetWidth(scrollWidth)
        header:SetJustifyH("LEFT")
        if entry.version == WT.version then
            header:SetText("|cffFFCC00Version " .. entry.version .. " (Current)|r")
        else
            header:SetText("|cff888888Version " .. entry.version .. "|r")
        end
        yOffset = yOffset - 20

        if entry.features and #entry.features > 0 then
            local label = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 4, yOffset)
            label:SetText("|cff9482c9Features:|r")
            yOffset = yOffset - 16
            for _, feat in ipairs(entry.features) do
                local text = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                text:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 12, yOffset)
                text:SetWidth(scrollWidth - 20)
                text:SetJustifyH("LEFT")
                text:SetText("|cffcccccc-|r " .. feat)
                local height = text:GetStringHeight()
                yOffset = yOffset - height - 2
            end
            yOffset = yOffset - 4
        end

        if entry.fixes and #entry.fixes > 0 then
            local label = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            label:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 4, yOffset)
            label:SetText("|cff88ff88Fixes:|r")
            yOffset = yOffset - 16
            for _, fix in ipairs(entry.fixes) do
                local text = frame.scrollChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                text:SetPoint("TOPLEFT", frame.scrollChild, "TOPLEFT", 12, yOffset)
                text:SetWidth(scrollWidth - 20)
                text:SetJustifyH("LEFT")
                text:SetText("|cffcccccc-|r " .. fix)
                local height = text:GetStringHeight()
                yOffset = yOffset - height - 2
            end
            yOffset = yOffset - 4
        end

        yOffset = yOffset - 12
    end

    frame.scrollChild:SetHeight(math.abs(yOffset))
end

function WN:Show()
    if not whatsNewFrame then
        whatsNewFrame = CreateWhatsNewFrame()
    end
    whatsNewFrame.title:SetText("|cff9482c9What's New in WarlockTools v" .. WT.version .. "|r")
    PopulateChangelog(whatsNewFrame)
    whatsNewFrame.overlay:Show()
    whatsNewFrame:Show()
end

function WN:Hide()
    if whatsNewFrame then
        whatsNewFrame:Hide()
        whatsNewFrame.overlay:Hide()
    end
    self:MarkAsSeen()
end

function WN:IsShown()
    return whatsNewFrame and whatsNewFrame:IsShown()
end
