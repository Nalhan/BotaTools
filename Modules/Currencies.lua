local _, BOTA = ...
local DF = _G["DetailsFramework"]

-- Initialize module namespace
BOTA.Currencies = BOTA.Currencies or {}

-- Import libraries
local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")



-- Module state
BOTA.Currencies.scanResults = {}
BOTA.Currencies.tableFrame = nil
BOTA.Currencies.addCurrencyInput = ""

-- UI Constants
BOTA.Currencies.ScrollBoxConfig = {
    xOffset = 150,
    columnWidth = 80,
    rowHeight = 24,
}

local defaults = {
    trackedList = {
        3345,
        3347,
    },
}

---------------------------------------------------------------------------
-- Saved Variables Initialization
---------------------------------------------------------------------------

-- Initialize saved variables for this module
function BOTA.Currencies:InitSavedVars()
    if not BOTASV then BOTASV = {} end
    if not BOTASV.Currencies then BOTASV.Currencies = {} end

    -- Set defaults if missing
    for k, v in pairs(defaults) do
        if BOTASV.Currencies[k] == nil then
            BOTASV.Currencies[k] = v
        end
    end

    -- Migration: Convert trackedCurrencies (set) to trackedList (array)
    if BOTASV.Currencies.trackedCurrencies then
        if not BOTASV.Currencies.trackedList then
            BOTASV.Currencies.trackedList = {}
        end
        for id, _ in pairs(BOTASV.Currencies.trackedCurrencies) do
            local exists = false
            for _, trackedId in ipairs(BOTASV.Currencies.trackedList) do
                if trackedId == id then
                    exists = true
                    break
                end
            end
            if not exists then
                table.insert(BOTASV.Currencies.trackedList, id)
            end
        end
        table.sort(BOTASV.Currencies.trackedList)
        BOTASV.Currencies.trackedCurrencies = nil
    end

    -- Ensure trackedList exists
    BOTASV.Currencies.trackedList = BOTASV.Currencies.trackedList or {}
end

function BOTA.Currencies:ResetDefaults()
    BOTASV.Currencies = CopyTable(defaults)
    self:RefreshTable()
    if self.managementList then
        self.managementList:Refresh()
    end
end

---------------------------------------------------------------------------
-- Communication Logic
---------------------------------------------------------------------------

function BOTA.Currencies:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= "BotaCurrencies" then return end

    if BOTA.DebugMode then
        print("|cFF00FFFFBotaTools|r: [Currencies] OnCommReceived from " ..
            tostring(sender) .. " (" .. tostring(distribution) .. ")")
    end

    local success, msgType, data = AceSerializer:Deserialize(message)
    if not success then
        if BOTA.DebugMode then
            print("|cFF00FFFFBotaTools|r: [Currencies] Failed to deserialize message from " .. tostring(sender))
        end
        return
    end

    if BOTA.DebugMode then
        print("|cFF00FFFFBotaTools|r: [Currencies] Message Type: " .. tostring(msgType))
    end

    if msgType == "REQ_STATUS" then
        self:SendStatus(distribution, sender, data)
    elseif msgType == "RESP_STATUS" then
        self.scanResults[sender] = data
        self:RefreshTable()
    end
end

function BOTA.Currencies:SendStatus(distribution, target, requestedList)
    self:InitSavedVars()
    local results = {}
    local tracked = requestedList or BOTASV.Currencies.trackedList or {}

    for _, currencyId in ipairs(tracked) do
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
        if info then
            -- Struct: [1]=Quantity, [2]=TotalEarned, [3]=MaxQuantity(Cap)
            results[currencyId] = {
                info.quantity or 0,
                info.totalEarned or 0,
                info.maxQuantity or 0
            }
        end
    end

    local _, class = UnitClass("player")
    local data = {
        class = class,
        currencies = results
    }

    local serialized = AceSerializer:Serialize("RESP_STATUS", data)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        if BOTA.DebugMode then
            print("|cFF00FFFFBotaTools|r: [Currencies] Sending RESP_STATUS to channel: " .. channel)
        end
        AceComm:SendCommMessage("BotaCurrencies", serialized, channel)
    elseif target then
        if BOTA.DebugMode then
            print("|cFF00FFFFBotaTools|r: [Currencies] Sending RESP_STATUS to target: " .. tostring(target))
        end
        AceComm:SendCommMessage("BotaCurrencies", serialized, "WHISPER", target)
    end
end

function BOTA.Currencies:ScanRaid()
    self:InitSavedVars()
    wipe(self.scanResults)
    self:RefreshTable()

    local trackedList = BOTASV.Currencies.trackedList or {}
    local serialized = AceSerializer:Serialize("REQ_STATUS", trackedList)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        if BOTA.DebugMode then
            print("|cFF00FFFFBotaTools|r: [Currencies] Sending REQ_STATUS to channel: " .. channel)
        end
        AceComm:SendCommMessage("BotaCurrencies", serialized, channel)
    else
        -- Self-test
        local _, class = UnitClass("player")
        local playerName = UnitName("player")
        self.scanResults[playerName] = {
            class = class,
            currencies = {}
        }
        for _, id in ipairs(BOTASV.Currencies.trackedList or {}) do
            local info = C_CurrencyInfo.GetCurrencyInfo(id)
            if info then
                self.scanResults[playerName].currencies[id] = {
                    info.quantity or 0,
                    info.totalEarned or 0,
                    info.maxQuantity or 0
                }
            end
        end
        self:RefreshTable()
    end
end

function BOTA.Currencies:InjectTestData()
    self:InitSavedVars()
    wipe(self.scanResults)

    local tracked = BOTASV.Currencies.trackedList or {}

    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
        "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

    for i = 1, 15 do
        local player = "TestPlayer" .. i
        local class = classes[math.random(1, #classes)]
        self.scanResults[player] = {
            class = class,
            currencies = {}
        }
        for _, id in ipairs(tracked) do
            local cap = 5000
            local total = math.random(0, cap + 1000)
            local current = math.random(0, math.min(total, cap))
            self.scanResults[player].currencies[id] = { current, total, cap }
        end
    end
    self:RefreshTable()
end

---------------------------------------------------------------------------
-- Enable/Disable
---------------------------------------------------------------------------

function BOTA.Currencies:Enable()
    self:InitSavedVars()
    AceComm:RegisterComm("BotaCurrencies", function(prefix, message, distribution, sender)
        BOTA.Currencies:OnCommReceived(prefix, message, distribution, sender)
    end)
end

---------------------------------------------------------------------------
-- Table Display Logic
---------------------------------------------------------------------------

function BOTA.Currencies:CreateTable(parent)
    if self.tableFrame then
        self.tableFrame:SetParent(parent)
        self.tableFrame:Show()
        return self.tableFrame
    end

    -- Container frame to hold headers and scrollbox
    local container = CreateFrame("Frame", "BotaCurrenciesContainer", parent)
    container:SetSize(parent:GetWidth() - 330, 420)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 320, -90)
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel(parent:GetFrameLevel() + 10)

    container.headers = {}

    -- Header Frame
    local headerFrame = CreateFrame("Frame", nil, container)
    headerFrame:SetSize(container:GetWidth(), 30)
    headerFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    container.headerFrame = headerFrame

    -- Scrollbox Row Creation
    local createLineFunc = function(self, index)
        local parentFrame = self.widget or self
        local line = CreateFrame("Frame", "$parentLine" .. index, parentFrame)
        local rowHeight = BOTA.Currencies.ScrollBoxConfig.rowHeight
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
                    BOTA.Currencies:UpdateRow(line, playerName)
                    if index % 2 == 0 then line.bg:Show() else line.bg:Hide() end
                end
            end
        end
    end

    local scrollBox = DF:CreateScrollBox(container, "$parentScrollBox", refreshFunc, {}, container:GetWidth() - 25,
        container:GetHeight() - 30, 16, BOTA.Currencies.ScrollBoxConfig.rowHeight)
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

function BOTA.Currencies:UpdateRow(row, player)
    local scanResults = self.scanResults or {}
    local data = scanResults[player]
    local class = data and data.class
    local color = class and RAID_CLASS_COLORS[class]

    if color then
        row.name:SetText(string.format("|cff%02x%02x%02x%s|r", math.floor(color.r * 255), math.floor(color.g * 255),
            math.floor(color.b * 255), player))
    else
        row.name:SetText(player)
    end



    local trackedList = BOTASV.Currencies.trackedList or {}
    local config = BOTA.Currencies.ScrollBoxConfig

    for j, currencyId in ipairs(trackedList) do
        local cell = row.cells[j]
        if not cell then
            cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            cell:SetWidth(config.columnWidth)
            cell:SetJustifyH("LEFT")
            row.cells[j] = cell
        end

        cell:SetPoint("LEFT", row, "LEFT", config.xOffset + (j - 1) * config.columnWidth, 0)

        local currenciesData = data and data.currencies
        local cData = currenciesData and currenciesData[currencyId]

        if cData then
            local current = cData[1] or 0
            local formatted = BOTA.FormatLargeNumber and BOTA:FormatLargeNumber(current) or tostring(current)
            cell:SetText(formatted)
        else
            cell:SetText("|cff888888-|r")
        end
        cell:Show()
    end

    -- Hide unused cells
    for k = #trackedList + 1, #row.cells do
        row.cells[k]:Hide()
    end
end

function BOTA.Currencies:RefreshTable()
    if not self.tableFrame then
        return
    end

    local container = self.tableFrame
    local trackedCurrencies = BOTASV.Currencies.trackedCurrencies or {}
    local scanResults = self.scanResults or {}

    -- Build player list
    local players = {}
    for p in pairs(scanResults) do
        table.insert(players, p)
    end
    table.sort(players)

    -- Headers
    local trackedList = BOTASV.Currencies.trackedList or {}
    local config = BOTA.Currencies.ScrollBoxConfig

    -- Hide existing headers
    for _, header in ipairs(container.headers or {}) do
        header:Hide()
    end

    for i, currencyId in ipairs(trackedList) do
        local header = container.headers[i]
        if not header then
            header = CreateFrame("Button", nil, container.headerFrame)
            header:SetSize(config.columnWidth, 30)
            header:SetScript("OnEnter", function(self)
                if self.currencyId then
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetCurrencyByID(self.currencyId)
                    GameTooltip:Show()
                end
            end)
            header:SetScript("OnLeave", function() GameTooltip:Hide() end)

            local icon = header:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", 2, 0)
            header.icon = icon

            local name = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            name:SetPoint("LEFT", icon, "RIGHT", 4, 0)
            name:SetPoint("RIGHT", -2, 0)
            name:SetJustifyH("LEFT")
            header.name = name

            container.headers[i] = header
        end

        header:SetPoint("TOPLEFT", container.headerFrame, "TOPLEFT", config.xOffset + (i - 1) * config.columnWidth, 0)
        local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
        header.icon:SetTexture(info and info.iconFileID or 134400)
        header.name:SetText(info and info.name or "ID: " .. currencyId)
        header.currencyId = currencyId
        header:Show()
    end

    -- Update Scrollbox
    container.scrollBox:SetData(players)
    container.scrollBox:Refresh()

    -- Explicitly hide all lines if no players are left
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

function BOTA.Currencies:BuildOptions()
    self:InitSavedVars()

    return {
        {
            type = "label",
            get = function() return "Currency Tracker" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },


        -- Scan Button
        {
            type = "execute",
            name = "Scan Raid",
            desc = "Request currency status from all raid members",
            func = function()
                BOTA.Currencies:ScanRaid()
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
            spacement = true,
        },

        -- Debug Button
        {
            type = "execute",
            name = "Debug: Test Data",
            desc = "Inject test data for players",
            func = function()
                BOTA.Currencies:InjectTestData()
            end,
            spacement = true,
        },

        -- Management Header
        {
            type = "label",
            get = function() return "Manage Currencies" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
            spacement = true,
        },
    }
end

function BOTA.Currencies:BuildCallback()
    return function()
        -- Callback when menu is refreshed/closed
    end
end

-- Hook to create table after tab is shown
function BOTA.Currencies:OnTabShown(tabFrame)
    self:CreateTable(tabFrame)
    self:RefreshTable()

    -- Create Management List
    if not self.managementList then
        -- Add ID Section (directly above list)
        local addIDLabel = tabFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        addIDLabel:SetPoint("TOPLEFT", tabFrame, "TOPLEFT", 10, -260)
        addIDLabel:SetText("Add Currency ID:")

        local addIDEntry = DF:CreateTextEntry(tabFrame, function() end, 100, 20, "AddIDEntry", nil, nil,
            DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))
        addIDEntry:SetPoint("LEFT", addIDLabel, "RIGHT", 5, 0)
        addIDEntry:SetHook("OnEnterPressed", function()
            local id = tonumber(addIDEntry:GetText():match("(%d+)"))
            if id then
                local exists = false
                for _, existingId in ipairs(BOTASV.Currencies.trackedList) do
                    if existingId == id then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(BOTASV.Currencies.trackedList, id)
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
                for _, existingId in ipairs(BOTASV.Currencies.trackedList) do
                    if existingId == id then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(BOTASV.Currencies.trackedList, id)
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
                table.remove(BOTASV.Currencies.trackedList, index)
                self:RefreshTable()
            end,
            OnMoveUp = function(index)
                if index > 1 then
                    local list = BOTASV.Currencies.trackedList
                    list[index], list[index - 1] = list[index - 1], list[index]
                    self:RefreshTable()
                end
            end,
            OnMoveDown = function(index)
                local list = BOTASV.Currencies.trackedList
                if index < #list then
                    local list = BOTASV.Currencies.trackedList
                    list[index], list[index + 1] = list[index + 1], list[index]
                    self:RefreshTable()
                end
            end
        }

        local config = {
            width = 280,
            height = 260,
            rowHeight = 24,
            nameProvider = function(id)
                local info = C_CurrencyInfo.GetCurrencyInfo(id)
                return (info and info.name or "Unknown") .. " (" .. id .. ")"
            end,
            iconProvider = function(id)
                local info = C_CurrencyInfo.GetCurrencyInfo(id)
                return info and info.iconFileID
            end
        }

        self.managementList = BOTA:CreateManagementList(tabFrame, BOTASV.Currencies.trackedList, callbacks, config)
        self.managementList:SetPoint("TOPLEFT", addIDLabel, "BOTTOMLEFT", 0, -5)
    else
        self.managementList:Refresh()
    end
end
