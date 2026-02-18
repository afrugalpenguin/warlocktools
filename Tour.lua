local WT = WarlockTools
local Tour = {}
WT:RegisterModule("Tour", Tour)

local TOUR_VERSION = 1

local BG_COLOR = { 0.08, 0.08, 0.12, 0.98 }
local BORDER_COLOR = { 0.58, 0.51, 0.79, 1 }
local welcomeFrame = nil
local tooltipFrame = nil
local currentStep = 0
local isRunning = false

local function CreateWelcomeFrame()
    local f = CreateFrame("Frame", "WarlockToolsTourWelcome", UIParent, "BackdropTemplate")
    f:SetSize(320, 260)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], BG_COLOR[4])
    f:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
    f:Hide()

    tinsert(UISpecialFrames, "WarlockToolsTourWelcome")

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(64, 64)
    logo:SetPoint("TOP", 0, -20)
    logo:SetTexture("Interface\\AddOns\\WarlockTools\\warlocktools")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", logo, "BOTTOM", 0, -12)
    title:SetText("|cff9482c9Welcome to WarlockTools!|r")

    local subtitle = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -10)
    subtitle:SetPoint("LEFT", f, "LEFT", 20, 0)
    subtitle:SetPoint("RIGHT", f, "RIGHT", -20, 0)
    subtitle:SetJustifyH("CENTER")
    subtitle:SetWordWrap(true)
    subtitle:SetText("Let us show you around. We'll highlight the key features so you can get started quickly.")

    local startBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    startBtn:SetSize(120, 26)
    startBtn:SetPoint("BOTTOM", f, "BOTTOM", -70, 16)
    startBtn:SetText("Start Tour")
    f.startBtn = startBtn

    local noBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    noBtn:SetSize(120, 26)
    noBtn:SetPoint("BOTTOM", f, "BOTTOM", 70, 16)
    noBtn:SetText("No Thanks")
    f.noBtn = noBtn

    return f
end

local function CreateTooltipFrame()
    local f = CreateFrame("Frame", "WarlockToolsTour", UIParent, "BackdropTemplate")
    f:SetSize(280, 140)
    f:SetFrameStrata("TOOLTIP")
    f:SetBackdrop({
        bgFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 1,
    })
    f:SetBackdropColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], BG_COLOR[4])
    f:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
    f:Hide()

    tinsert(UISpecialFrames, "WarlockToolsTour")

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 12, -10)
    f.title = title

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 12, -32)
    desc:SetPoint("TOPRIGHT", -12, -32)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    f.desc = desc

    local counter = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    counter:SetPoint("BOTTOMLEFT", 12, 10)
    f.counter = counter

    local skipBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    skipBtn:SetSize(70, 22)
    skipBtn:SetPoint("BOTTOMRIGHT", -12, 8)
    skipBtn:SetText("Skip Tour")
    skipBtn:SetNormalFontObject("GameFontNormalSmall")
    f.skipBtn = skipBtn

    local nextBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    nextBtn:SetSize(60, 22)
    nextBtn:SetPoint("RIGHT", skipBtn, "LEFT", -6, 0)
    nextBtn:SetText("Next")
    nextBtn:SetNormalFontObject("GameFontNormalSmall")
    f.nextBtn = nextBtn

    return f
end

local glowFrame = nil

local function CreateGlowFrame()
    local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    f:SetFrameStrata("TOOLTIP")
    f:SetBackdrop({
        edgeFile = "Interface\\BUTTONS\\WHITE8X8",
        edgeSize = 2,
    })
    f:SetBackdropBorderColor(0.58, 0.51, 0.79, 1)
    f:Hide()
    local ag = f:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1)
    fade:SetToAlpha(0.3)
    fade:SetDuration(0.8)
    fade:SetSmoothing("IN_OUT")
    f.pulse = ag
    return f
end

local function ShowGlow(frame)
    if not glowFrame then glowFrame = CreateGlowFrame() end
    local pad = 4
    glowFrame:SetParent(frame)
    glowFrame:ClearAllPoints()
    glowFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", -pad, pad)
    glowFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", pad, -pad)
    glowFrame:SetFrameLevel(frame:GetFrameLevel() + 10)
    glowFrame:Show()
    glowFrame.pulse:Play()
end

local function HideGlow()
    if glowFrame then
        glowFrame.pulse:Stop()
        glowFrame:Hide()
    end
end

local steps = {
    {
        title = "The HUD",
        desc = "This is your HUD \226\128\148 it shows how many soul shards, healthstones, soulstones, and other stones you're carrying at a glance.",
        setup = function()
            local hud = WarlockToolsHUD
            if hud and not hud:IsShown() then hud:Show() end
            return hud
        end,
        teardown = function() end,
    },
    {
        title = "Healthstone Creation",
        desc = "This panel tracks your shard economy during group sessions. It shows how many healthstones you need vs what you have, and whether you have enough shards.",
        setup = function()
            local sm = WT.modules["SoulManager"]
            if sm then
                sm:UpdateSessionProgress()
                WarlockToolsHSCreation:Show()
            end
            return WarlockToolsHSCreation
        end,
        teardown = function()
            if WarlockToolsHSCreation and WarlockToolsHSCreation:IsShown() then
                WarlockToolsHSCreation:Hide()
            end
        end,
    },
    {
        title = "The Popup Menu",
        desc = "This is the spell popup \226\128\148 use it to quickly summon demons, create stones, buff yourself, or cast utility spells. Bind a key in Options to open it.",
        setup = function()
            local popup = WarlockToolsPopup
            if not popup then return nil end
            popup:ClearAllPoints()
            popup:SetPoint("CENTER", UIParent, "CENTER")
            popup:SetBackdrop({
                bgFile = "Interface\\BUTTONS\\WHITE8X8",
                edgeFile = "Interface\\BUTTONS\\WHITE8X8",
                edgeSize = 1,
            })
            popup:SetBackdropColor(BG_COLOR[1], BG_COLOR[2], BG_COLOR[3], BG_COLOR[4])
            popup:SetBackdropBorderColor(BORDER_COLOR[1], BORDER_COLOR[2], BORDER_COLOR[3], BORDER_COLOR[4])
            popup:Show()
            return popup
        end,
        teardown = function()
            local popup = WarlockToolsPopup
            if not popup then return end
            popup:SetBackdrop(nil)
            if popup:IsShown() then popup:Hide() end
        end,
    },
    {
        title = "Options",
        desc = "Customise WarlockTools here \226\128\148 button sizes, HUD layout, whisper keywords, and more. Open anytime with /wlt options.",
        setup = function()
            local opts = WT.modules["Options"]
            if opts then opts:Show() end
            return WarlockToolsOptions
        end,
        teardown = function()
            local opts = WT.modules["Options"]
            if opts then opts:Hide() end
        end,
    },
}

local function PositionTooltip(targetFrame)
    tooltipFrame:ClearAllPoints()
    local _, targetBottom = targetFrame:GetCenter()
    if targetBottom and targetBottom < 200 then
        tooltipFrame:SetPoint("BOTTOM", targetFrame, "TOP", 0, 10)
    else
        tooltipFrame:SetPoint("TOP", targetFrame, "BOTTOM", 0, -10)
    end
end

local function ShowStep(index)
    local step = steps[index]
    if not step then return end

    if currentStep > 0 and steps[currentStep] then
        steps[currentStep].teardown()
    end
    HideGlow()

    currentStep = index

    local targetFrame = step.setup()

    if not targetFrame then
        if index < #steps then
            ShowStep(index + 1)
        else
            Tour:Stop()
        end
        return
    end

    ShowGlow(targetFrame)

    tooltipFrame.title:SetText("|cffFFD200" .. step.title .. "|r")
    tooltipFrame.desc:SetText(step.desc)
    tooltipFrame.counter:SetText(string.format("Step %d of %d", index, #steps))

    if index == #steps then
        tooltipFrame.nextBtn:SetText("Finish")
    else
        tooltipFrame.nextBtn:SetText("Next")
    end

    local descHeight = tooltipFrame.desc:GetStringHeight()
    tooltipFrame:SetHeight(descHeight + 80)

    PositionTooltip(targetFrame)
    tooltipFrame:Show()
end

local function BeginSteps()
    if not tooltipFrame then
        tooltipFrame = CreateTooltipFrame()
        tooltipFrame.nextBtn:SetScript("OnClick", function()
            if currentStep < #steps then
                ShowStep(currentStep + 1)
            else
                Tour:Stop()
                WarlockToolsDB.tourVersion = TOUR_VERSION
            end
        end)
        tooltipFrame.skipBtn:SetScript("OnClick", function()
            Tour:Stop()
            WarlockToolsDB.tourVersion = TOUR_VERSION
        end)
        tooltipFrame:SetScript("OnHide", function()
            if isRunning then
                Tour:Stop()
            end
        end)
    end
    currentStep = 0
    ShowStep(1)
end

function Tour:Start()
    if isRunning then return end
    if InCombatLockdown() then return end
    isRunning = true
    if not welcomeFrame then
        welcomeFrame = CreateWelcomeFrame()
        welcomeFrame.startBtn:SetScript("OnClick", function()
            welcomeFrame.startingTour = true
            welcomeFrame:Hide()
            welcomeFrame.startingTour = nil
            BeginSteps()
        end)
        welcomeFrame.noBtn:SetScript("OnClick", function()
            welcomeFrame:Hide()
            Tour:Stop()
            WarlockToolsDB.tourVersion = TOUR_VERSION
        end)
        welcomeFrame:SetScript("OnHide", function()
            if isRunning and currentStep == 0 and not welcomeFrame.startingTour then
                Tour:Stop()
            end
        end)
    end
    welcomeFrame:Show()
end

function Tour:Stop()
    if not isRunning then return end
    isRunning = false
    if currentStep > 0 and steps[currentStep] then
        steps[currentStep].teardown()
    end
    HideGlow()
    if welcomeFrame then welcomeFrame:Hide() end
    if tooltipFrame then tooltipFrame:Hide() end
    currentStep = 0
end

function Tour:OnEvent(event, ...)
    if event == "PLAYER_REGEN_DISABLED" then
        if isRunning then
            Tour:Stop()
            print("|cff9482c9WarlockTools|r Tour cancelled (entering combat). Type |cffFFD200/wlt tour|r to restart.")
        end
    end
end

function Tour:Init()
    WT:RegisterEvents("PLAYER_REGEN_DISABLED")
    if not WarlockToolsDB.tourVersion or WarlockToolsDB.tourVersion < TOUR_VERSION then
        WarlockToolsDB.showSessionOnLogin = false
        C_Timer.After(2, function()
            Tour:Start()
        end)
    end
end
