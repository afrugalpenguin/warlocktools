WarlockTools = {}
WarlockTools.modules = {}
WarlockTools.version = "1.1.1"
WarlockTools.initialized = false

function WarlockTools:PropagateDrag(child)
    child:RegisterForDrag("LeftButton")
    child:HookScript("OnDragStart", function(self)
        local parent = self:GetParent()
        parent:StartMoving()
    end)
    child:HookScript("OnDragStop", function(self)
        local parent = self:GetParent()
        parent:StopMovingOrSizing()
        if parent.SavePosition then parent:SavePosition() end
    end)
end

local frame = CreateFrame("Frame")

local defaults = {
    hudVisible = true,
    hudX = 0,
    hudY = 0,
    hudPoint = "CENTER",
    whisperKeywords = { "healthstone", "hs", "summon", "lock", "warlock" },
    healthstonesPerPerson = 1,
    autoReply = true,
    queueVisible = true,
    hudButtonSize = 32,
    hudVertical = false,
    popupColumns = 5,
    popupCloseOnCast = true,
    autoPlaceItems = true,
    listenPartyChat = false,
    popupButtonSize = 36,
    maxQueueDisplay = 10,
    popupBgAlpha = 0.85,
    sessionBgAlpha = 0.9,
    showSessionOnLogin = false,
    popupKeybind = nil,
    hudShowExtras = true,
    popupReleaseMode = true,
    popupFixedPosition = false,
    popupFixedX = 0.5,
    popupFixedY = 0.5,
    popupCategories = { buffs = true, stones = true, demons = true, utility = true },
}

function WarlockTools:RegisterModule(name, mod)
    self.modules[name] = mod
end

function WarlockTools:InitDB()
    WarlockToolsDB = WarlockToolsDB or {}
    for k, v in pairs(defaults) do
        if WarlockToolsDB[k] == nil then
            if type(v) == "table" then
                WarlockToolsDB[k] = {}
                for dk, dv in pairs(v) do
                    WarlockToolsDB[k][dk] = dv
                end
            else
                WarlockToolsDB[k] = v
            end
        elseif type(v) == "table" and type(WarlockToolsDB[k]) == "table" then
            for dk, dv in pairs(v) do
                if WarlockToolsDB[k][dk] == nil then
                    WarlockToolsDB[k][dk] = dv
                end
            end
        end
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addon = ...
        if addon == "WarlockTools" then
            local _, englishClass = UnitClass("player")
            if englishClass ~= "WARLOCK" then
                self:UnregisterEvent("ADDON_LOADED")
                return
            end
            WarlockTools:InitDB()
            WarlockTools.Masque:Init()
            for name, mod in pairs(WarlockTools.modules) do
                if mod.Init then
                    mod:Init()
                end
            end
            WarlockTools.initialized = true
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    end
    if not WarlockTools.initialized then return end
    for name, mod in pairs(WarlockTools.modules) do
        if mod.OnEvent then
            mod:OnEvent(event, ...)
        end
    end
end)

function WarlockTools:RegisterEvents(...)
    for i = 1, select("#", ...) do
        frame:RegisterEvent(select(i, ...))
    end
end

SLASH_WARLOCKTOOLS1 = "/warlocktools"
SLASH_WARLOCKTOOLS2 = "/wlt"
SlashCmdList["WARLOCKTOOLS"] = function(msg)
    local cmd = strlower(strtrim(msg))
    if cmd == "popup" then
        local pm = WarlockTools.modules["PopupMenu"]
        if pm then WarlockTools_TogglePopup() end
    elseif cmd == "hud" then
        local sm = WarlockTools.modules["SoulManager"]
        if sm then sm:ToggleHUD() end
    elseif cmd == "summon" then
        local sm = WarlockTools.modules["SoulManager"]
        if sm then sm:ToggleHSCreation() end
    elseif cmd == "queue" then
        local th = WarlockTools.modules["TradeHelper"]
        if th then th:ToggleQueue() end
    elseif cmd == "whatsnew" then
        local wn = WarlockTools.modules["WhatsNew"]
        if wn then wn:Show() end
    elseif cmd == "options" then
        local opts = WarlockTools.modules["Options"]
        if opts then opts:Toggle() end
    elseif cmd == "config" then
        print("|cff9482c9WarlockTools|r config:")
        print("  HUD visible: " .. tostring(WarlockToolsDB.hudVisible))
        print("  Auto-reply: " .. tostring(WarlockToolsDB.autoReply))
        print("  Healthstones/person: " .. WarlockToolsDB.healthstonesPerPerson)
        print("  Keywords: " .. table.concat(WarlockToolsDB.whisperKeywords, ", "))
    elseif cmd == "tour" then
        local tour = WarlockTools.modules["Tour"]
        if tour then tour:Start() end
    else
        local wn = WarlockTools.modules["WhatsNew"]
        if wn and wn:ShouldShow() then
            wn:Show()
        else
            print("|cff9482c9WarlockTools|r commands:")
            print("  /wlt popup - Toggle spell menu")
            print("  /wlt hud - Toggle HUD")
            print("  /wlt summon - Healthstone creation")
            print("  /wlt queue - Toggle trade queue")
            print("  /wlt options - Open options panel")
            print("  /wlt whatsnew - View changelog")
            print("  /wlt config - Show config")
            print("  /wlt tour - Start onboarding tour")
        end
    end
end
