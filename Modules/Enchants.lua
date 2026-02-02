local _, BOTA = ...
local DF = _G["DetailsFramework"]

-- Initialize module namespace
BOTA.Enchants = BOTA.Enchants or {}

-- Import libraries
local AceComm = LibStub("AceComm-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")



-- Module state
local ENCHANT_SLOTS = {
    { id = 1,  name = "Head" },
    { id = 3,  name = "Shoulder" },
    { id = 5,  name = "Chest" },
    { id = 7,  name = "Legs" },
    { id = 8,  name = "Feet" },
    { id = 11, name = "Ring 1" },
    { id = 12, name = "Ring 2" },
    { id = 16, name = "MH" },
    { id = 17, name = "OH" },
}

-- Module state
BOTA.Enchants.scanResults = {}
BOTA.Enchants.tableFrame = nil

---------------------------------------------------------------------------
-- Saved Variables Initialization
---------------------------------------------------------------------------

function BOTA.Enchants:InitSavedVars()
    BOTASV = BOTASV or {}
    BOTASV.Enchants = BOTASV.Enchants or {}
end

---------------------------------------------------------------------------
-- Helper Functions
---------------------------------------------------------------------------

-- Extract enchant ID from item link
local function GetEnchantID(itemLink)
    if not itemLink then return nil end
    -- Item link format: |cffffffff|Hitem:itemID:enchantID:...|h[name]|h|r
    local enchantID = itemLink:match("item:%d+:(%d+)")
    if enchantID and tonumber(enchantID) and tonumber(enchantID) > 0 then
        return tonumber(enchantID)
    end
    return nil
end

-- Scan player for enchants and item links
function BOTA.Enchants:GetPlayerEnchants()
    local results = {}
    local itemLinks = {}

    for _, slotData in ipairs(ENCHANT_SLOTS) do
        local slotID = slotData.id
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local enchantID = GetEnchantID(itemLink)
            local _, _, _, equipLoc = C_Item.GetItemInfoInstant(itemLink)

            if slotID == 17 and (equipLoc == "INVTYPE_SHIELD" or equipLoc == "INVTYPE_HOLDABLE") then
                results[slotID] = nil            -- Treated as non-enchantable (-)
            else
                results[slotID] = enchantID or 0 -- 0 means no enchant
            end
            itemLinks[slotID] = itemLink
        else
            results[slotID] = nil -- nil means no item in slot
            itemLinks[slotID] = nil
        end
    end

    return results, itemLinks
end

---------------------------------------------------------------------------
-- Communication Logic
---------------------------------------------------------------------------

function BOTA.Enchants:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= "BotaEnchants" then return end

    local success, msgType, data = AceSerializer:Deserialize(message)
    if not success then return end

    if msgType == "REQ_STATUS" then
        self:SendStatus(distribution, sender)
    elseif msgType == "RESP_STATUS" then
        self.scanResults[sender] = data
        self:RefreshTable()
    end
end

function BOTA.Enchants:SendStatus(distribution, target)
    local results, itemLinks = self:GetPlayerEnchants()
    local _, class = UnitClass("player")
    local data = {
        class = class,
        enchants = results,
        itemLinks = itemLinks
    }

    local serialized = AceSerializer:Serialize("RESP_STATUS", data)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        AceComm:SendCommMessage("BotaEnchants", serialized, channel)
    elseif target then
        AceComm:SendCommMessage("BotaEnchants", serialized, "WHISPER", target)
    end
end

function BOTA.Enchants:ScanRaid()
    self:InitSavedVars()
    wipe(self.scanResults)
    self:RefreshTable()
    local serialized = AceSerializer:Serialize("REQ_STATUS", nil)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        AceComm:SendCommMessage("BotaEnchants", serialized, channel)
    else
        -- Self-test
        local _, class = UnitClass("player")
        local playerName = UnitName("player")
        local results, itemLinks = self:GetPlayerEnchants()

        self.scanResults[playerName] = {
            class = class,
            enchants = results,
            itemLinks = itemLinks
        }
        self:RefreshTable()
    end
end

function BOTA.Enchants:InjectTestData()
    self:InitSavedVars()
    wipe(self.scanResults)

    local classes = BOTA.ClassList

    for i = 1, 15 do
        local player = "TestPlayer" .. i
        local class = classes[math.random(1, #classes)]
        self.scanResults[player] = {
            class = class,
            enchants = {},
            itemLinks = {}
        }

        for _, slotData in ipairs(ENCHANT_SLOTS) do
            local roll = math.random(1, 10)
            if slotData.id == 17 and math.random(1, 2) == 1 then
                -- 50% chance for OH to be a shield/holdable (non-enchantable)
                self.scanResults[player].enchants[slotData.id] = nil
            elseif roll <= 1 then
                self.scanResults[player].enchants[slotData.id] = nil
            elseif roll <= 3 then
                self.scanResults[player].enchants[slotData.id] = 0
            else
                self.scanResults[player].enchants[slotData.id] = 6643 -- Mock ID
            end
        end
    end
    self:RefreshTable()
end

-- Specific OnEnter for enchant cells
function BOTA.Enchants:OnEnterEnchant(self)
    if not self or self.enchantID == nil then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    if self.enchantID == 0 then
        GameTooltip:AddLine("Missing Enchant", 1, 0, 0)
    else
        -- Try Transmog API (returns name, hyperlink, sourceText)
        local name = C_TransmogCollection.GetIllusionStrings(self.enchantID)

        if name and name ~= "" then
            GameTooltip:AddLine(name, 1, 1, 1)
        else
            GameTooltip:AddLine("Enchant ID: " .. self.enchantID, 1, 0.8, 0)
        end
    end
    GameTooltip:Show()
end

---------------------------------------------------------------------------
-- Enable/Disable
---------------------------------------------------------------------------

function BOTA.Enchants:Enable()
    self:InitSavedVars()
    AceComm:RegisterComm("BotaEnchants", function(prefix, message, distribution, sender)
        BOTA.Enchants:OnCommReceived(prefix, message, distribution, sender)
    end)
end

---------------------------------------------------------------------------
-- Table Display Logic
---------------------------------------------------------------------------

function BOTA.Enchants:CreateTable(parent)
    if self.tableFrame then
        self.tableFrame:SetParent(parent)
        self.tableFrame:Show()
        return self.tableFrame
    end

    -- Container frame to hold headers and scrollbox
    local container = BOTA:CreateTabContainer(parent, "BotaEnchantsContainer")
    container.headers = {}

    -- Scrollbox Row Creation
    local createLineFunc = function(self, index)
        local parentFrame = self.widget or self
        local line = CreateFrame("Frame", "$parentLine" .. index, parentFrame)
        line:SetSize(self:GetWidth(), 24)

        -- Explicit positioning like CDMSpellHooks
        line:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -((index - 1) * 24))

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
                    BOTA.Enchants:UpdateRow(line, playerName)
                    if index % 2 == 0 then line.bg:Show() else line.bg:Hide() end
                end
            end
        end
    end

    local scrollBox = DF:CreateScrollBox(container, "$parentScrollBox", refreshFunc, {}, container:GetWidth() - 25,
        container:GetHeight() - 30, 16, 24)
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

function BOTA.Enchants:UpdateRow(row, player)
    local scanResults = self.scanResults or {}
    local data = scanResults[player]
    local class = data and data.class
    row.name:SetText(BOTA:FormatPlayerName(player, class))



    local columnWidth = 50
    local xOffset = 150

    for j, slotData in ipairs(ENCHANT_SLOTS) do
        local cell = row.cells[j]
        if not cell then
            cell = CreateFrame("Frame", nil, row)
            cell:SetSize(columnWidth, 24)
            cell:EnableMouse(true)

            local icon = cell:CreateTexture(nil, "ARTWORK")
            icon:SetSize(16, 16)
            icon:SetPoint("CENTER")
            cell.icon = icon

            local text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            text:SetPoint("CENTER")
            cell.text = text

            cell:SetScript("OnEnter", function(s) self:OnEnterEnchant(s) end)
            cell:SetScript("OnLeave", BOTA.OnLeave)

            row.cells[j] = cell
        end

        cell:SetPoint("LEFT", row, "LEFT", xOffset + (j - 1) * columnWidth, 0)

        local enchants = data and data.enchants
        local enchantID = enchants and enchants[slotData.id]
        local itemLinks = data and data.itemLinks
        local itemLink = itemLinks and itemLinks[slotData.id]

        cell.itemLink = itemLink
        cell.enchantID = enchantID

        if enchantID == nil then
            cell.icon:Hide()
            cell.text:SetText("|cff888888-|r")
            cell.text:Show()
        elseif enchantID == 0 then
            cell.text:Hide()
            cell.icon:SetTexture("Interface/RaidFrame/ReadyCheck-NotReady")
            cell.icon:Show()
        else
            cell.text:Hide()
            cell.icon:SetTexture("Interface/RaidFrame/ReadyCheck-Ready")
            cell.icon:Show()
        end
        cell:Show()
    end

    -- Hide unused cells (if ENCHANT_SLOTS changes)
    for k = #ENCHANT_SLOTS + 1, #row.cells do
        row.cells[k]:Hide()
    end
end

function BOTA.Enchants:RefreshTable()
    if not self.tableFrame then
        return
    end

    local container = self.tableFrame
    local scanResults = self.scanResults or {}

    -- Build player list
    local players = {}
    for p in pairs(scanResults) do
        table.insert(players, p)
    end
    table.sort(players)

    local columnWidth = 50
    local xOffset = 150

    -- Hide existing headers
    for _, header in ipairs(container.headers or {}) do
        header:Hide()
    end

    -- Create/update headers
    for i, slotData in ipairs(ENCHANT_SLOTS) do
        local header = container.headers[i]
        if not header then
            header = CreateFrame("Button", nil, container.headerFrame)
            header:SetSize(columnWidth, 30)
            header:SetScript("OnEnter", function(self)
                if self.slotName then
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(self.slotName, 1, 1, 1)
                    GameTooltip:Show()
                end
            end)
            header:SetScript("OnLeave", function() GameTooltip:Hide() end)

            local name = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            name:SetPoint("CENTER")
            name:SetJustifyH("CENTER")
            header.name = name

            container.headers[i] = header
        end

        header:SetPoint("TOPLEFT", container.headerFrame, "TOPLEFT", xOffset + (i - 1) * columnWidth, 0)
        header.name:SetText(slotData.name)
        header.slotName = slotData.name
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

function BOTA.Enchants:BuildOptions()
    self:InitSavedVars()

    return {
        {
            type = "label",
            get = function() return "Enchants Tracker" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },

        -- Scan Button
        {
            type = "execute",
            name = "Scan Raid",
            desc = "Request enchant status from all raid members",
            func = function()
                BOTA.Enchants:ScanRaid()
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
        {
            type = "execute",
            name = "Debug: Test Data",
            desc = "Inject test data for players",
            func = function()
                BOTA.Enchants:InjectTestData()
            end,
            spacement = true,
        },

    }
end

function BOTA.Enchants:BuildCallback()
    return function()
        -- Callback when menu is refreshed/closed
    end
end

-- Hook to create table after tab is shown
function BOTA.Enchants:OnTabShown(tabFrame)
    self:CreateTable(tabFrame)
    self:RefreshTable()
end
