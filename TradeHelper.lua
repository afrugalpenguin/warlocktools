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

local function NotifyHSCreation()
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
            NotifyHSCreation()
            return
        end
    end
    tinsert(queue, { name = name, request = request })
    self:UpdateQueueDisplay()
    NotifyHSCreation()

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
    NotifyHSCreation()
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

    -- Healthstone creation shortcut button
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
        if sm then sm:ToggleHSCreation() end
    end)
    sessBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Open Healthstone Creation")
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
