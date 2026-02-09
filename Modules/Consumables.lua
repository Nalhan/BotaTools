local _, BOTA = ...
local DF = _G["DetailsFramework"]

-- Initialize module namespace
BOTA.Consumables = BOTA.Consumables or {}

-- Import libraries
local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")



-- Module state
BOTA.Consumables.scanResults = {}
BOTA.Consumables.tableFrame = nil
BOTA.Consumables.addItemInput = ""

-- UI Constants
BOTA.Consumables.ScrollBoxConfig = {
    xOffset = 150,
    columnWidth = 40,
    rowHeight = 24,
}

local defaults = {
    --    trackedItems = nil, -- Deprecated
    trackedList = { -- Ordered list of item IDs
        224572,     -- Flask of Alchemical Chaos
        211880,     -- Algari Mana Oil
    },
}

-- Initialize saved variables for this module
function BOTA.Consumables:InitSavedVars()
    if not BOTASV then BOTASV = {} end
    if not BOTASV.Consumables then BOTASV.Consumables = {} end

    -- Set defaults if missing
    for k, v in pairs(defaults) do
        if BOTASV.Consumables[k] == nil then
            BOTASV.Consumables[k] = v
        end
    end

    -- Migration: Convert trackedItems (set) to trackedList (array)
    if BOTASV.Consumables.trackedItems then
        if not BOTASV.Consumables.trackedList then
            BOTASV.Consumables.trackedList = {}
        end
        for id, _ in pairs(BOTASV.Consumables.trackedItems) do
            local exists = false
            for _, trackedId in ipairs(BOTASV.Consumables.trackedList) do
                if trackedId == id then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(BOTASV.Consumables.trackedList, id)
            end
        end
        table.sort(BOTASV.Consumables.trackedList)
        BOTASV.Consumables.trackedItems = nil
    end

    -- Ensure trackedList exists
    BOTASV.Consumables.trackedList = BOTASV.Consumables.trackedList or {}
end

function BOTA.Consumables:ResetDefaults()
    BOTASV.Consumables = CopyTable(defaults)
    self:RefreshTable()
    if self.managementList then
        self.managementList:Refresh()
    end
end

---------------------------------------------------------------------------
-- Communication Logic
---------------------------------------------------------------------------

function BOTA.Consumables:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= "BotaConsumables" then return end

    BOTA:DebugLog("[Consumables] OnCommReceived from " .. tostring(sender) .. " (" .. tostring(distribution) .. ")")

    local success, msgType, data = AceSerializer:Deserialize(message)
    if not success then
        BOTA:DebugLog("[Consumables] Failed to deserialize message from " .. tostring(sender))
        return
    end

    BOTA:DebugLog("[Consumables] Message Type: " .. tostring(msgType))

    if msgType == "REQ_STATUS" then
        self:SendStatus(distribution, sender, data)
    elseif msgType == "RESP_STATUS" then
        self.scanResults[sender] = data
        self:RefreshTable()
    end
end

function BOTA.Consumables:SendStatus(distribution, target, requestedList)
    self:InitSavedVars()
    local results = {}
    local trackedList = requestedList or BOTASV.Consumables.trackedList or {}

    for _, itemId in ipairs(trackedList) do
        results[itemId] = C_Item.GetItemCount(itemId)
    end

    local _, class = UnitClass("player")
    local data = {
        class = class,
        items = results
    }

    local serialized = AceSerializer:Serialize("RESP_STATUS", data)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        BOTA:DebugLog("[Consumables] Sending RESP_STATUS to channel: " .. channel)
        AceComm:SendCommMessage("BotaConsumables", serialized, channel)
    elseif target then
        BOTA:DebugLog("[Consumables] Sending RESP_STATUS to target: " .. tostring(target))
        AceComm:SendCommMessage("BotaConsumables", serialized, "WHISPER", target)
    end
end

function BOTA.Consumables:ScanRaid()
    self:InitSavedVars()
    wipe(self.scanResults)
    self:RefreshTable()

    local trackedList = BOTASV.Consumables.trackedList or {}
    local serialized = AceSerializer:Serialize("REQ_STATUS", trackedList)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        BOTA:DebugLog("[Consumables] Sending REQ_STATUS to channel: " .. channel)
        AceComm:SendCommMessage("BotaConsumables", serialized, channel)
    else
        -- Self-test for solo
        local _, class = UnitClass("player")
        local playerName = UnitName("player")
        self.scanResults[playerName] = {
            class = class,
            items = {}
        }
        for _, itemId in ipairs(BOTASV.Consumables.trackedList or {}) do
            self.scanResults[playerName].items[itemId] = GetItemCount(itemId)
        end
        self:RefreshTable()
    end
end

function BOTA.Consumables:InjectTestData()
    self:InitSavedVars()
    wipe(self.scanResults)

    local tracked = BOTASV.Consumables.trackedList or {}

    local classes = BOTA.ClassList

    for i = 1, 20 do
        local player = "TestPlayer" .. i
        local class = classes[math.random(1, #classes)]
        self.scanResults[player] = {
            class = class,
            items = {}
        }
        for _, id in ipairs(tracked) do
            local bucket = math.random(1, 5)
            local val
            if bucket == 1 then
                val = 0
            elseif bucket == 2 then
                val = math.random(1, 9)
            elseif bucket == 3 then
                val = math.random(10, 99)
            elseif bucket == 4 then
                val = math.random(100, 999)
            else
                val = math.random(1000, 9999)
            end
            self.scanResults[player].items[id] = val
        end
    end
    self:RefreshTable()
end

---------------------------------------------------------------------------
-- Enable/Disable
---------------------------------------------------------------------------

function BOTA.Consumables:Enable()
    self:InitSavedVars()
    AceComm:RegisterComm("BotaConsumables", function(prefix, message, distribution, sender)
        BOTA.Consumables:OnCommReceived(prefix, message, distribution, sender)
    end)
end

---------------------------------------------------------------------------
-- Table Display Logic
---------------------------------------------------------------------------

function BOTA.Consumables:CreateTable(parent)
    if self.tableFrame then
        self.tableFrame:SetParent(parent)
        self.tableFrame:Show()
        return self.tableFrame
    end

    -- Container frame to hold headers and scrollbox
    local container = BOTA:CreateTabContainer(parent, "BotaConsumablesContainer")
    container.headers = {}

    -- Scrollbox Row Creation
    local createLineFunc = function(self, index)
        local parentFrame = self.widget or self
        local line = CreateFrame("Frame", "$parentLine" .. index, parentFrame)
        local rowHeight = BOTA.Consumables.ScrollBoxConfig.rowHeight
        line:SetSize(self:GetWidth(), rowHeight)

        -- Explicit positioning like CDMSpellHooks
        line:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -((index - 1) * rowHeight))

        -- FORCE Frame Level to be higher than scrollbox/container
        line:SetFrameLevel(parentFrame:GetFrameLevel() + 20)

        local bg = line:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.2)
        line.bg = bg

        local name = line:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        name:SetPoint("LEFT", 5, 0)
        name:SetWidth(140)
        name:SetJustifyH("LEFT")
        name:SetTextColor(1, 1, 1, 1) -- Ensure white text
        line.name = name

        line.cells = {}
        return line
    end

    -- Scrollbox Refresh
    local refreshFunc = function(self, data, offset, totalLines)
        for i = 1, totalLines do
            local index = i + offset
            local playerName = data[index]

            if playerName then
                local line = self:GetLine(i)
                if line then
                    line:Show()
                    BOTA.Consumables:UpdateRow(line, playerName)
                    if index % 2 == 0 then line.bg:Show() else line.bg:Hide() end
                end
            end
        end
    end

    local scrollBox = DF:CreateScrollBox(container, "$parentScrollBox", refreshFunc, {}, container:GetWidth() - 25,
        container:GetHeight() - 30, 16, BOTA.Consumables.ScrollBoxConfig.rowHeight)
    scrollBox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -30)
    DF:ReskinSlider(scrollBox)

    for i = 1, 16 do
        scrollBox:CreateLine(createLineFunc)
    end

    container.scrollBox = scrollBox
    scrollBox:SetFrameLevel(container:GetFrameLevel() + 5)
    scrollBox:Show()

    self.tableFrame = container
    container:Show()
    return container
end

function BOTA.Consumables:UpdateRow(row, player)
    local scanResults = self.scanResults or {}
    local data = scanResults[player]
    local class = data and data.class
    row.name:SetText(BOTA:FormatPlayerName(player, class))



    local trackedList = BOTASV.Consumables.trackedList or {}
    local config = BOTA.Consumables.ScrollBoxConfig

    for j, itemId in ipairs(trackedList) do
        local cell = row.cells[j]
        if not cell then
            cell = CreateFrame("Frame", nil, row)
            cell:SetSize(config.columnWidth, config.rowHeight)
            cell:EnableMouse(true)

            local text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("CENTER")
            cell.text = text

            cell:SetScript("OnEnter", BOTA.OnEnterItem)
            cell:SetScript("OnLeave", BOTA.OnLeave)

            row.cells[j] = cell
        end

        cell:SetPoint("LEFT", row, "LEFT", config.xOffset + (j - 1) * config.columnWidth, 0)
        cell.itemId = itemId

        local itemsData = data and data.items
        local count = itemsData and itemsData[itemId] or 0
        local formattedCount = BOTA:FormatLargeNumber(count) or tostring(count)

        if count > 0 then
            cell.text:SetText("|cff00ff00" .. formattedCount .. "|r")
        else
            cell.text:SetText("|cffff00000|r")
        end
        cell:Show()
    end

    -- Hide unused cells
    for k = #trackedList + 1, #row.cells do
        row.cells[k]:Hide()
    end
end

function BOTA.Consumables:RefreshTable()
    if not self.tableFrame then
        return
    end

    local container = self.tableFrame
    local trackedItems = BOTASV.Consumables.trackedItems or {}
    local scanResults = self.scanResults or {}

    -- Build player list
    local players = {}
    for p in pairs(scanResults) do
        table.insert(players, p)
    end
    table.sort(players)

    BOTA:DebugLog("Refreshed Consumables Table. Results count: " .. #players)

    -- Headers (in container.headerFrame)
    local trackedList = BOTASV.Consumables.trackedList or {}
    local config = BOTA.Consumables.ScrollBoxConfig
    -- No sort here, respect order

    -- Hide existing headers
    for _, header in ipairs(container.headers or {}) do
        header:Hide()
    end

    for i, itemId in ipairs(trackedList) do
        local header = container.headers[i]
        if not header then
            header = CreateFrame("Button", nil, container.headerFrame)
            header:SetSize(config.columnWidth, 30)
            header:SetScript("OnEnter", BOTA.OnEnterItem)
            header:SetScript("OnLeave", BOTA.OnLeave)

            local icon = header:CreateTexture(nil, "OVERLAY")
            icon:SetSize(20, 20)
            icon:SetPoint("CENTER")
            header.icon = icon

            container.headers[i] = header
        end

        header:SetPoint("TOPLEFT", container.headerFrame, "TOPLEFT", config.xOffset + (i - 1) * config.columnWidth, 0)
        local icon = C_Item.GetItemIconByID(itemId) or 134400
        header.icon:SetTexture(icon)
        header.itemId = itemId
        header:Show()
    end

    -- Update Scrollbox
    container.scrollBox:SetData(players)
    container.scrollBox:Refresh()

    -- Explicitly hide all lines if no players are left (DetailsFramework Refresh fallback)
    if #players == 0 then
        local lines = container.scrollBox.lines or {}
        for _, line in ipairs(lines) do
            line:Hide()
        end
    end
end

---------------------------------------------------------------------------
-- UI Options for LibDFramework
---------------------------------------------------------------------------

function BOTA.Consumables:BuildOptions()
    self:InitSavedVars()

    return {
        {
            type = "label",
            get = function() return "Consumables Tracker" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },


        -- Scan Button
        {
            type = "execute",
            name = "Scan Raid",
            desc = "Request consumable status from all raid members",
            func = function()
                BOTA.Consumables:ScanRaid()
            end,
        },

        -- Clear Results Button
        {
            type = "execute",
            name = "Clear Results",
            desc = "Clear all currently gathered scan results.",
            func = function()
                wipe(self.scanResults)
                self:RefreshTable()
            end,
        },

        -- Debug Button
        {
            type = "execute",
            name = "Debug: Test Data",
            desc = "Inject test data for 20 players",
            func = function()
                BOTA.Consumables:InjectTestData()
            end,
            spacement = true,
        },
        -- Management Header
        {
            type = "label",
            get = function() return "Manage Tracked Items" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
            spacement = true,
        },
    }
end

function BOTA.Consumables:BuildCallback()
    return function()
        -- Callback when menu is refreshed/closed
    end
end

-- Hook to create table after tab is shown
function BOTA.Consumables:OnTabShown(tabFrame)
    self:CreateTable(tabFrame)
    self:RefreshTable()

    -- Create Management List
    if not self.managementList then
        -- Add ID Section (directly above list)
        local addIDLabel = tabFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        addIDLabel:SetPoint("TOPLEFT", tabFrame, "TOPLEFT", 10, -260)
        addIDLabel:SetText("Add Item ID:")

        local addIDEntry = DF:CreateTextEntry(tabFrame, function() end, 100, 20, "AddIDEntry", nil, nil,
            DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))
        addIDEntry:SetPoint("LEFT", addIDLabel, "RIGHT", 5, 0)
        addIDEntry:SetHook("OnEnterPressed", function()
            local id = tonumber(addIDEntry:GetText():match("(%d+)"))
            if id then
                local exists = false
                for _, existingId in ipairs(BOTASV.Consumables.trackedList) do
                    if existingId == id then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(BOTASV.Consumables.trackedList, id)
                    addIDEntry:SetText("")
                    self:RefreshTable()
                    self.managementList:Refresh()
                end
            end
        end)

        local addButton = DF:CreateButton(tabFrame, function()
            local id = tonumber(addIDEntry:GetText():match("(%d+)"))
            if id then
                local exists = false
                for _, existingId in ipairs(BOTASV.Consumables.trackedList) do
                    if existingId == id then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(BOTASV.Consumables.trackedList, id)
                    addIDEntry:SetText("")
                    self:RefreshTable()
                    self.managementList:Refresh()
                end
            end
        end, 20, 20)
        addButton:SetPoint("LEFT", addIDEntry, "RIGHT", 4, 0)
        addButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
        addButton:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
        addButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")

        local callbacks = {
            OnRemove = function(index)
                table.remove(BOTASV.Consumables.trackedList, index)
                self:RefreshTable()
            end,
            OnMoveUp = function(index)
                if index > 1 then
                    local list = BOTASV.Consumables.trackedList
                    list[index], list[index - 1] = list[index - 1], list[index]
                    self:RefreshTable()
                end
            end,
            OnMoveDown = function(index)
                local list = BOTASV.Consumables.trackedList
                if index < #list then
                    local list = BOTASV.Consumables.trackedList
                    list[index], list[index + 1] = list[index + 1], list[index]
                    self:RefreshTable()
                end
            end
        }

        local config = {
            width = 280,
            height = 250,
            rowHeight = 24,
            nameProvider = function(id)
                return (C_Item.GetItemNameByID(id) or ("Item " .. id)) .. " (" .. id .. ")"
            end,
            iconProvider = function(id)
                return C_Item.GetItemIconByID(id)
            end
        }

        self.managementList = BOTA:CreateManagementList(tabFrame, BOTASV.Consumables.trackedList, callbacks, config)
        self.managementList:SetPoint("TOPLEFT", addIDLabel, "BOTTOMLEFT", 0, -5)
    else
        self.managementList:Refresh()
    end
end
