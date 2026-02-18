# WarlockTools Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Warlock utility addon for WoW TBC Anniversary Classic with HUD, popup spell menu, trade helper, and summon session — adapted from the MageTools architecture.

**Architecture:** Global `WarlockTools` table with module registration pattern, single event frame dispatching to registered modules. Class-gated to WARLOCK. All UI frames use BackdropTemplate and Masque integration where applicable.

**Tech Stack:** WoW Lua API (TBC Anniversary Classic, Interface 20505), SecureActionButtonTemplate, SecureHandlerWrapScript, C_Container API, Masque (optional dependency).

**Reference:** MageTools source at `C:\Users\russell\Documents\git\MageTools\` — use as reference for patterns but write all code fresh for Warlock.

---

### Task 1: TOC + Core.lua Bootstrap

**Files:**
- Create: `WarlockTools.toc`
- Create: `Core.lua`

**Step 1: Write WarlockTools.toc**

```toc
## Interface: 20505
## Title: WarlockTools
## Notes: Warlock utility addon — demons, stones, shard tracking, trade helper
## Author: FrugalPenguin
## Version: @project-version@
## SavedVariablesPerCharacter: WarlockToolsDB
## OptionalDeps: Masque
## X-Curse-Project-ID: PLACEHOLDER

Core.lua
WhatsNew.lua
Options.lua
Tour.lua
Data.lua
MasqueHelper.lua
PopupMenu.lua
SoulManager.lua
TradeHelper.lua
```

**Step 2: Write Core.lua**

Adapt from `MageTools\Core.lua`. Key changes:
- Global table: `WarlockTools`
- Class gate: `WARLOCK`
- Saved variable: `WarlockToolsDB`
- Addon color: `|cff9482c9`
- Slash commands: `/warlocktools`, `/wlt`
- DB defaults from design doc
- Slash subcommands: popup, hud, summon (was conjure), queue, whatsnew, options, config, tour

```lua
WarlockTools = {}
WarlockTools.modules = {}
WarlockTools.version = "1.0.0"

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
            self:UnregisterEvent("ADDON_LOADED")
        end
        return
    end
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
        if sm then sm:ToggleSummonSession() end
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
            print("  /wlt summon - Summon session")
            print("  /wlt queue - Toggle trade queue")
            print("  /wlt options - Open options panel")
            print("  /wlt whatsnew - View changelog")
            print("  /wlt config - Show config")
            print("  /wlt tour - Start onboarding tour")
        end
    end
end
```

**Step 3: Commit**

```
git add WarlockTools.toc Core.lua
git commit -m "feat: add TOC and Core.lua bootstrap"
```

---

### Task 2: MasqueHelper.lua

**Files:**
- Create: `MasqueHelper.lua`

**Step 1: Write MasqueHelper.lua**

Identical to MageTools version, with `WarlockTools` namespace.

```lua
local WT = WarlockTools

WT.Masque = {}
local MSQ = nil
local groups = {}

function WT.Masque:Init()
    local lib = LibStub and LibStub("Masque", true)
    if lib then
        MSQ = lib
    end
end

function WT.Masque:GetGroup(name)
    if not MSQ then return nil end
    if not groups[name] then
        groups[name] = MSQ:Group("WarlockTools", name)
    end
    return groups[name]
end

function WT.Masque:IsEnabled()
    return MSQ ~= nil
end

function WT.Masque:AddButton(groupName, button, data)
    local group = self:GetGroup(groupName)
    if group then
        group:AddButton(button, data)
    end
end

function WT.Masque:ReSkin(groupName)
    local group = self:GetGroup(groupName)
    if group then
        group:ReSkin()
    end
end
```

**Step 2: Commit**

```
git add MasqueHelper.lua
git commit -m "feat: add MasqueHelper with Masque wrapper"
```

---

### Task 3: Data.lua — Spell & Item Tables

**Files:**
- Create: `Data.lua`

**Step 1: Write Data.lua**

All warlock spell IDs and item IDs for TBC. Lookup set for bag scanning.

```lua
local WT = WarlockTools

-- Demon summoning spells
WT.DEMONS = {
    { spellID = 688,   name = "Summon Imp" },
    { spellID = 697,   name = "Summon Voidwalker" },
    { spellID = 712,   name = "Summon Succubus" },
    { spellID = 691,   name = "Summon Felhunter" },
    { spellID = 30146, name = "Summon Felguard" },  -- Demonology talent
}

-- Self-buff spells (names for FindSpellInBook lookup)
WT.BUFF_NAMES = {
    "Fel Armor",
    "Demon Armor",
    "Demon Skin",
    "Detect Invisibility",
    "Unending Breath",
    "Shadow Ward",
}

-- Group utility spells
WT.UTILITY_NAMES = {
    "Ritual of Summoning",
    "Ritual of Souls",
    "Eye of Kilrogg",
    "Sense Demons",
}

-- Stone creation spell names (for FindSpellInBook, highest rank auto-selected)
WT.STONE_NAMES = {
    "Create Healthstone",
    "Create Soulstone",
    "Create Spellstone",
    "Create Firestone",
}

-- Healthstone item IDs (all ranks + talent-improved variants, highest first)
-- Normal / Improved / Greater variants per rank
WT.HEALTHSTONE_ITEMS = {
    -- Rank 6 (Major)
    22103, -- Master Healthstone
    22105, -- Master Healthstone (Improved)
    22104, -- Master Healthstone (Greater)
    -- Rank 5
    9421,  -- Major Healthstone
    19013, -- Major Healthstone (Improved)
    19012, -- Major Healthstone (Greater)
    -- Rank 4
    5509,  -- Greater Healthstone
    19011, -- Greater Healthstone (Improved)
    19010, -- Greater Healthstone (Greater)
    -- Rank 3
    5512,  -- Healthstone
    19009, -- Healthstone (Improved)
    19008, -- Healthstone (Greater)
    -- Rank 2
    5511,  -- Lesser Healthstone
    19007, -- Lesser Healthstone (Improved)
    19006, -- Lesser Healthstone (Greater)
    -- Rank 1
    5512,  -- Minor Healthstone
    19005, -- Minor Healthstone (Improved)
    19004, -- Minor Healthstone (Greater)
}

-- Soulstone item IDs (all ranks, highest first)
WT.SOULSTONE_ITEMS = {
    22116, -- Master Soulstone
    16896, -- Major Soulstone
    16895, -- Greater Soulstone
    16893, -- Soulstone
    16892, -- Lesser Soulstone
    16891, -- Minor Soulstone
}

-- Spellstone item IDs (all ranks, highest first)
WT.SPELLSTONE_ITEMS = {
    28658, -- Master Spellstone
    13602, -- Greater Spellstone
    13603, -- Spellstone
    41191, -- Lesser Spellstone
}

-- Firestone item IDs (all ranks, highest first)
WT.FIRESTONE_ITEMS = {
    28657, -- Master Firestone
    13700, -- Greater Firestone
    13699, -- Firestone
    41170, -- Lesser Firestone
}

-- Soul Shard item ID
WT.SOUL_SHARD = 6265

-- Build lookup set for bag scanning
WT.ITEM_TYPE_SET = {}
WT.ITEM_TYPE_SET[WT.SOUL_SHARD] = "shard"
for _, id in ipairs(WT.HEALTHSTONE_ITEMS) do WT.ITEM_TYPE_SET[id] = "healthstone" end
for _, id in ipairs(WT.SOULSTONE_ITEMS) do WT.ITEM_TYPE_SET[id] = "soulstone" end
for _, id in ipairs(WT.SPELLSTONE_ITEMS) do WT.ITEM_TYPE_SET[id] = "spellstone" end
for _, id in ipairs(WT.FIRESTONE_ITEMS) do WT.ITEM_TYPE_SET[id] = "firestone" end
```

**Step 2: Commit**

```
git add Data.lua
git commit -m "feat: add Data.lua with warlock spell/item tables"
```

**Note:** The item IDs above are best-effort from known TBC data. Verify against TBC Anniversary in-game and correct any wrong IDs. The `ITEM_TYPE_SET` pattern means fixing an ID is a one-line change.

---

### Task 4: SoulManager.lua — HUD + Summon Session

**Files:**
- Create: `SoulManager.lua`

**Step 1: Write SoulManager.lua**

Adapt from `MageTools\ConjureManager.lua`. Key changes:
- Tracks 5 item types: shard, healthstone, soulstone, spellstone, firestone
- Spellstone/firestone toggleable via `hudShowExtras`
- Summon Session shows shard economy (not food/water stacks)
- Single "Create Healthstone" button (not food + water)

```lua
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
    self:CreateSummonSession()
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

-- Summon Session
function SM:CreateSummonSession()
    sessionFrame = CreateFrame("Frame", "WarlockToolsSummonSession", UIParent, "BackdropTemplate")
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

    tinsert(UISpecialFrames, "WarlockToolsSummonSession")

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
    title:SetText("|cff9482c9Summon Session|r")

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

function SM:ToggleSummonSession()
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
```

**Step 2: Commit**

```
git add SoulManager.lua
git commit -m "feat: add SoulManager with HUD and summon session"
```

---

### Task 5: PopupMenu.lua — Spell Popup

**Files:**
- Create: `PopupMenu.lua`

**Step 1: Write PopupMenu.lua**

Adapt from `MageTools\PopupMenu.lua`. Key changes:
- Four quadrants: Buffs (TL), Stones (TR), Demons (BL), Utility (BR)
- No gem-delete logic (simpler secure handler)
- Uses `WT.BUFF_NAMES`, `WT.STONE_NAMES`, `WT.DEMONS`, `WT.UTILITY_NAMES`
- Category keys: buffs, stones, demons, utility

```lua
local WT = WarlockTools
local PM = {}
WT:RegisterModule("PopupMenu", PM)

local popup = nil
local buttons = {}
local labels = {}
local BUTTON_PADDING = 4
local BLOCK_GAP = 6
local BLOCK_COLS = 99

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

    popup:SetBackdrop(nil)

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
            local cols = math.min(#q.spells, BLOCK_COLS)
            local rows = math.ceil(#q.spells / BLOCK_COLS)
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
                if col >= BLOCK_COLS then
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
```

**Step 2: Commit**

```
git add PopupMenu.lua
git commit -m "feat: add PopupMenu with X-layout spell grid"
```

---

### Task 6: TradeHelper.lua — Whisper Queue

**Files:**
- Create: `TradeHelper.lua`

**Step 1: Write TradeHelper.lua**

Adapt from `MageTools\TradeHelper.lua`. Key changes:
- Request types: `healthstone`, `summon`, `both`
- Keyword mapping: healthstone/hs -> healthstone, summon -> summon, lock/warlock -> healthstone
- Trade auto-place: healthstones only (summons are cast, not traded)
- Summon session shortcut icon uses soul shard icon

```lua
local WT = WarlockTools
local TH = {}
WT:RegisterModule("TradeHelper", TH)

local queue = {}
local queueFrame = nil
local queueButtons = {}
local pendingTrade = nil

function TH:Init()
    self:CreateQueueFrame()
    self:UpdateQueueDisplay()
    WT:RegisterEvents("CHAT_MSG_WHISPER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "TRADE_SHOW", "TRADE_CLOSED", "UI_INFO_MESSAGE")
end

function TH:GetQueueSize()
    return #queue
end

function TH:MatchKeyword(msg)
    msg = strlower(msg)
    local matched = {}
    for _, keyword in ipairs(WarlockToolsDB.whisperKeywords) do
        local lk = strlower(keyword)
        if strfind(msg, lk) then
            if lk == "healthstone" or lk == "hs" then
                matched.healthstone = true
            elseif lk == "summon" then
                matched.summon = true
            else
                matched.healthstone = true
            end
        end
    end
    if matched.healthstone and matched.summon then
        return "both"
    elseif matched.healthstone then
        return "healthstone"
    elseif matched.summon then
        return "summon"
    end
    return nil
end

local function NotifySummonSession()
    local sm = WT.modules["SoulManager"]
    if sm and sm.UpdateSessionIfShown then
        sm:UpdateSessionIfShown()
    end
end

function TH:AddToQueue(name, request)
    for _, entry in ipairs(queue) do
        if entry.name == name then
            entry.request = request
            self:UpdateQueueDisplay()
            NotifySummonSession()
            return
        end
    end
    tinsert(queue, { name = name, request = request })
    self:UpdateQueueDisplay()
    NotifySummonSession()

    if WarlockToolsDB.autoReply then
        local position = #queue
        local reqText = request
        if request == "both" then reqText = "healthstone and summon" end
        SendChatMessage("You're queued for " .. reqText .. ". " .. (position - 1) .. " ahead of you.", "WHISPER", nil, name)
    end

    if not queueFrame:IsShown() then
        queueFrame:Show()
    end
end

function TH:RemoveFromQueue(index)
    local entry = tremove(queue, index)
    if entry and WarlockToolsDB.autoReply then
        SendChatMessage("Enjoy!", "WHISPER", nil, entry.name)
    end
    self:UpdateQueueDisplay()
    NotifySummonSession()
    if #queue == 0 then
        queueFrame:Hide()
    end
end

function TH:FindHealthstone()
    local bestBag, bestSlot, bestCount = nil, nil, 0
    for bag = 0, NUM_BAG_SLOTS do
        local numSlots = C_Container.GetContainerNumSlots(bag)
        for slot = 1, numSlots do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.itemID then
                for _, validID in ipairs(WT.HEALTHSTONE_ITEMS) do
                    if info.itemID == validID then
                        if info.stackCount and info.stackCount > bestCount then
                            bestBag, bestSlot, bestCount = bag, slot, info.stackCount
                        end
                    end
                end
            end
        end
    end
    return bestBag, bestSlot
end

function TH:PlaceItemsInTrade(request)
    if request == "healthstone" or request == "both" then
        local bag, slot = self:FindHealthstone()
        if bag then
            C_Container.PickupContainerItem(bag, slot)
            ClickTradeButton(1)
        end
    end
    -- Summon requests don't place items in trade
end

function TH:CreateQueueFrame()
    queueFrame = CreateFrame("Frame", "WarlockToolsQueue", UIParent, "BackdropTemplate")
    queueFrame:SetSize(200, 40)
    queueFrame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
    queueFrame:SetFrameStrata("MEDIUM")
    queueFrame:SetClampedToScreen(true)
    queueFrame:SetMovable(true)
    queueFrame:EnableMouse(true)
    queueFrame:RegisterForDrag("LeftButton")
    queueFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    queueFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    queueFrame:Hide()

    tinsert(UISpecialFrames, "WarlockToolsQueue")

    queueFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    queueFrame:SetBackdropColor(0, 0, 0, 0.8)

    local title = queueFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -6)
    title:SetText("|cff9482c9Trade Queue|r")
    queueFrame.title = title

    -- Summon session shortcut button
    local sessBtn = CreateFrame("Button", nil, queueFrame)
    sessBtn:SetSize(14, 14)
    sessBtn:SetPoint("TOPRIGHT", queueFrame, "TOPRIGHT", -6, -4)
    local sessIcon = sessBtn:CreateTexture(nil, "ARTWORK")
    sessIcon:SetAllPoints()
    sessIcon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02")
    sessIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local sessHL = sessBtn:CreateTexture(nil, "HIGHLIGHT")
    sessHL:SetAllPoints()
    sessHL:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    sessHL:SetBlendMode("ADD")
    sessBtn:SetScript("OnClick", function()
        local sm = WT.modules["SoulManager"]
        if sm then sm:ToggleSummonSession() end
    end)
    sessBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Open Summon Session")
        GameTooltip:Show()
    end)
    sessBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    WT:PropagateDrag(sessBtn)

    for i = 1, WarlockToolsDB.maxQueueDisplay do
        local row = CreateFrame("Button", "WarlockToolsQueueRow" .. i, queueFrame, "SecureActionButtonTemplate")
        row:SetSize(180, 18)
        row:SetPoint("TOP", queueFrame, "TOP", 0, -8 - (i * 18))
        row:RegisterForClicks("AnyUp")
        row:SetAttribute("type1", "macro")

        local tmplNormal = row:GetNormalTexture()
        if tmplNormal then tmplNormal:SetTexture(nil); tmplNormal:Hide() end

        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", 6, 0)
        row.nameText = nameText

        local reqText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        reqText:SetPoint("RIGHT", -6, 0)
        row.reqText = reqText

        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

        row:SetScript("PostClick", function(self, button)
            if not queue[i] then return end
            if button == "RightButton" then
                TH:RemoveFromQueue(i)
            else
                pendingTrade = queue[i]
                print("|cff9482c9WarlockTools|r Targeting " .. queue[i].name .. ". Open trade to deliver.")
            end
        end)

        WT:PropagateDrag(row)
        row:Hide()
        tinsert(queueButtons, row)
    end
end

function TH:UpdateQueueDisplay()
    local maxDisplay = math.min(WarlockToolsDB.maxQueueDisplay, #queueButtons)
    local visibleCount = math.min(#queue, maxDisplay)
    for i = 1, maxDisplay do
        if i <= visibleCount then
            local entry = queue[i]
            queueButtons[i].nameText:SetText(entry.name)
            local reqLabel = entry.request
            if reqLabel == "both" then reqLabel = "hs+summon" end
            queueButtons[i].reqText:SetText("|cffaaaaaa" .. reqLabel .. "|r")
            queueButtons[i]:SetAttribute("macrotext1", "/target " .. entry.name)
            queueButtons[i]:Show()
        else
            queueButtons[i]:SetAttribute("macrotext1", "")
            queueButtons[i]:Hide()
        end
    end
    local height = 28 + (visibleCount * 18)
    queueFrame:SetSize(200, math.max(40, height))
end

function TH:RebuildQueue()
    if not queueFrame then return end
    local maxDisplay = WarlockToolsDB.maxQueueDisplay
    for i = #queueButtons + 1, maxDisplay do
        local row = CreateFrame("Button", "WarlockToolsQueueRow" .. i, queueFrame, "SecureActionButtonTemplate")
        row:SetSize(180, 18)
        row:SetPoint("TOP", queueFrame, "TOP", 0, -8 - (i * 18))
        row:RegisterForClicks("AnyUp")
        row:SetAttribute("type1", "macro")
        local tmplNormal = row:GetNormalTexture()
        if tmplNormal then tmplNormal:SetTexture(nil); tmplNormal:Hide() end
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        nameText:SetPoint("LEFT", 6, 0)
        row.nameText = nameText
        local reqText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        reqText:SetPoint("RIGHT", -6, 0)
        row.reqText = reqText
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row:SetScript("PostClick", function(self, button)
            if not queue[i] then return end
            if button == "RightButton" then
                TH:RemoveFromQueue(i)
            else
                pendingTrade = queue[i]
                print("|cff9482c9WarlockTools|r Targeting " .. queue[i].name .. ". Open trade to deliver.")
            end
        end)
        WT:PropagateDrag(row)
        row:Hide()
        tinsert(queueButtons, row)
    end
    self:UpdateQueueDisplay()
end

function TH:ToggleQueue()
    if queueFrame:IsShown() then
        queueFrame:Hide()
        WarlockToolsDB.queueVisible = false
    else
        queueFrame:Show()
        WarlockToolsDB.queueVisible = true
    end
end

function TH:OnEvent(event, ...)
    if event == "CHAT_MSG_WHISPER" then
        local msg, sender = ...
        local request = self:MatchKeyword(msg)
        if request then
            local name = strsplit("-", sender)
            self:AddToQueue(name, request)
        end
    elseif (event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER") then
        if WarlockToolsDB.listenPartyChat then
            local msg, sender = ...
            local request = self:MatchKeyword(msg)
            if request then
                local name = strsplit("-", sender)
                self:AddToQueue(name, request)
            end
        end
    elseif event == "TRADE_SHOW" then
        if pendingTrade and WarlockToolsDB.autoPlaceItems then
            self:PlaceItemsInTrade(pendingTrade.request)
        end
    elseif event == "UI_INFO_MESSAGE" then
        local _, msg = ...
        if msg == ERR_TRADE_COMPLETE then
            if pendingTrade then
                for i, entry in ipairs(queue) do
                    if entry.name == pendingTrade.name then
                        self:RemoveFromQueue(i)
                        break
                    end
                end
                pendingTrade = nil
            end
        end
    elseif event == "TRADE_CLOSED" then
        pendingTrade = nil
    end
end
```

**Step 2: Commit**

```
git add TradeHelper.lua
git commit -m "feat: add TradeHelper with whisper queue and trade distribution"
```

---

### Task 7: Options.lua — Settings Panel

**Files:**
- Create: `Options.lua`

**Step 1: Write Options.lua**

Adapt from `MageTools\Options.lua`. Key changes:
- Warlock purple accent color
- General tab: HUD settings with `hudShowExtras` toggle, summon session, popup categories (buffs/stones/demons/utility)
- Trade tab: healthstonesPerPerson slider instead of food/water stacks
- Appearance tab: same structure
- All frame/module references use WarlockTools namespace

```lua
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
    y = CreateHeader(parent, "Summon Session", y - 6)
    y = CreateCheckbox(parent, "Show Summon Session on Login", "showSessionOnLogin", y)
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
        if WarlockToolsSummonSession then
            WarlockToolsSummonSession:SetBackdropColor(0, 0, 0, WarlockToolsDB.sessionBgAlpha)
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
```

**Step 2: Commit**

```
git add Options.lua
git commit -m "feat: add Options panel with tabbed settings"
```

---

### Task 8: WhatsNew.lua — Changelog Modal

**Files:**
- Create: `WhatsNew.lua`

**Step 1: Write WhatsNew.lua**

Adapt from `MageTools\WhatsNew.lua`. Warlock purple, starts at v1.0.0.

```lua
local WT = WarlockTools
local WN = {}
WT:RegisterModule("WhatsNew", WN)

local whatsNewFrame = nil

local changelog = {
    {
        version = "1.0.0",
        features = {
            "Initial release: HUD, popup spell menu, trade helper, summon session",
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
```

**Step 2: Commit**

```
git add WhatsNew.lua
git commit -m "feat: add WhatsNew changelog modal"
```

---

### Task 9: Tour.lua — Onboarding Tour

**Files:**
- Create: `Tour.lua`

**Step 1: Write Tour.lua**

Adapt from `MageTools\Tour.lua`. Key changes:
- WarlockTools namespace and purple branding
- Step 1: HUD (shard/stone counts)
- Step 2: Summon Session
- Step 3: Popup Menu
- Step 4: Options
- Logo path: `Interface\\AddOns\\WarlockTools\\warlocktools`

```lua
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
        title = "Summon Session",
        desc = "This panel tracks your shard economy during group sessions. It shows how many healthstones you need vs what you have, and whether you have enough shards.",
        setup = function()
            local sm = WT.modules["SoulManager"]
            if sm then
                sm:UpdateSessionProgress()
                WarlockToolsSummonSession:Show()
            end
            return WarlockToolsSummonSession
        end,
        teardown = function()
            if WarlockToolsSummonSession and WarlockToolsSummonSession:IsShown() then
                WarlockToolsSummonSession:Hide()
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
```

**Step 2: Commit**

```
git add Tour.lua
git commit -m "feat: add onboarding tour"
```

---

### Task 10: Verify Item IDs and Final Polish

**Files:**
- Modify: `Data.lua` (fix any incorrect item IDs after in-game testing)

**Step 1: Verify all warlock item IDs in-game**

Log in on a Warlock in TBC Anniversary and verify:
- Create each rank of healthstone, check the item ID matches `WT.HEALTHSTONE_ITEMS`
- Check soulstone, spellstone, firestone item IDs similarly
- Use `/dump GetItemInfo(ITEMID)` or `/dump C_Container.GetContainerItemInfo(bag, slot)` to verify

**Step 2: Fix any incorrect IDs in Data.lua**

Update the item ID arrays with corrected values.

**Step 3: Test all features**

- `/wlt` — help text
- `/wlt hud` — toggle HUD, verify shard/stone counts
- `/wlt summon` — summon session, verify shard economy display
- `/wlt popup` — spell popup, verify all 4 quadrants
- `/wlt options` — settings panel, verify all controls work
- `/wlt queue` — trade queue (test with a friend whispering keywords)
- `/wlt tour` — onboarding tour
- `/wlt whatsnew` — changelog modal

**Step 4: Commit any fixes**

```
git add -A
git commit -m "fix: correct item IDs after in-game verification"
```

---

## Summary

| Task | Description | Files |
|------|------------|-------|
| 1 | TOC + Core.lua bootstrap | `WarlockTools.toc`, `Core.lua` |
| 2 | MasqueHelper | `MasqueHelper.lua` |
| 3 | Data layer (spells + items) | `Data.lua` |
| 4 | SoulManager (HUD + Summon Session) | `SoulManager.lua` |
| 5 | PopupMenu (X-layout spell grid) | `PopupMenu.lua` |
| 6 | TradeHelper (whisper queue) | `TradeHelper.lua` |
| 7 | Options panel | `Options.lua` |
| 8 | WhatsNew changelog | `WhatsNew.lua` |
| 9 | Onboarding tour | `Tour.lua` |
| 10 | In-game verification + item ID fixes | `Data.lua` |
