local Type, Version = "BotaTools_EnchantsTable", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local addonName = ...
local BotaTools = LibStub("AceAddon-3.0"):GetAddon(addonName)

-- Lua APIs
local pairs, ipairs, next = pairs, ipairs, next
local table_insert, table_sort = table.insert, table.sort
local math_max = math.max

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent
local GameTooltip = GameTooltip

-- Slot IDs and names (must match Enchants.lua)
local ENCHANT_SLOTS = {
    { id = 1,  name = "Head" },
    { id = 3,  name = "Shoulder" },
    { id = 5,  name = "Chest" },
    { id = 7,  name = "Legs" },
    { id = 8,  name = "Feet" },
    { id = 11, name = "Finger 1" },
    { id = 12, name = "Finger 2" },
    { id = 16, name = "Mainhand" },
    { id = 17, name = "Offhand" },
}

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Header_OnEnter(frame)
    if not frame.slotName then return end
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:SetText(frame.slotName, 1, 1, 1)
    GameTooltip:Show()
end

local function Header_OnLeave(frame)
    GameTooltip:Hide()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self:UpdateData()
    end,

    ["OnRelease"] = function(self)
    end,

    ["SetLabel"] = function(self, text)
    end,

    ["SetText"] = function(self, text)
    end,

    ["SetDisabled"] = function(self, disabled)
    end,

    ["SetFontObject"] = function(self, font)
    end,

    ["SetImage"] = function(self, path, ...)
    end,

    ["SetImageSize"] = function(self, width, height)
    end,

    ["SetColor"] = function(self, r, g, b)
    end,

    ["UpdateData"] = function(self)
        local Enchants = BotaTools:GetModule("Enchants")
        if not Enchants then return end

        local scanResults = Enchants.scanResults or {}

        -- 1. Headers
        if self.headers then
            for _, header in ipairs(self.headers) do header:Hide() end
        end
        self.headers = self.headers or {}

        local columnWidth = 50
        local xOffset = 150
        local totalContentWidth = xOffset + #ENCHANT_SLOTS * columnWidth

        for i, slotData in ipairs(ENCHANT_SLOTS) do
            local header = self.headers[i]
            if not header then
                header = CreateFrame("Button", nil, self.frame)
                header:SetSize(columnWidth, 30)
                header:SetScript("OnEnter", Header_OnEnter)
                header:SetScript("OnLeave", Header_OnLeave)

                local name = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                name:SetPoint("CENTER")
                name:SetJustifyH("CENTER")
                header.name = name

                self.headers[i] = header
            end

            header:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xOffset + (i - 1) * columnWidth, 0)
            header.name:SetText(slotData.name)
            header.slotName = slotData.name
            header:Show()
        end

        -- 2. Rows
        if self.rows then
            for _, row in ipairs(self.rows) do row:Hide() end
        end
        self.rows = self.rows or {}

        local players = {}
        for p in pairs(scanResults) do table_insert(players, p) end
        table_sort(players)

        local rowHeight = 24
        local yOffset = -35

        for i, player in ipairs(players) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, self.frame)
                row:SetHeight(rowHeight)

                local tex = row:CreateTexture(nil, "BACKGROUND")
                tex:SetAllPoints()
                tex:SetColorTexture(1, 1, 1, 0.05)
                row.bg = tex

                local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                name:SetPoint("LEFT", 5, 0)
                name:SetWidth(140)
                name:SetJustifyH("LEFT")
                row.name = name

                row.cells = {}
                self.rows[i] = row
            end

            row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, yOffset + (i - 1) * (-rowHeight))
            row:SetWidth(math_max(self.frame:GetWidth(), totalContentWidth))

            local data = scanResults[player]
            local class = data and data.class
            local color = class and RAID_CLASS_COLORS[class]

            if color then
                row.name:SetText(string.format("|cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255,
                    player))
            else
                row.name:SetText(player)
            end

            if i % 2 == 0 then row.bg:Show() else row.bg:Hide() end

            -- Cells
            for j, slotData in ipairs(ENCHANT_SLOTS) do
                local cell = row.cells[j]
                if not cell then
                    -- Create interactive frame instead of font string
                    cell = CreateFrame("Frame", nil, row)
                    cell:SetSize(columnWidth, rowHeight)
                    cell:EnableMouse(true)

                    -- Texture for ready check icons
                    local icon = cell:CreateTexture(nil, "ARTWORK")
                    icon:SetSize(16, 16)
                    icon:SetPoint("CENTER")
                    cell.icon = icon

                    -- Text for dash (no item)
                    local text = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                    text:SetPoint("CENTER")
                    text:SetJustifyH("CENTER")
                    cell.text = text

                    cell:SetScript("OnEnter", function(self)
                        if self.itemLink then
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetHyperlink(self.itemLink)
                            GameTooltip:Show()
                        end
                    end)

                    cell:SetScript("OnLeave", function(self)
                        GameTooltip:Hide()
                    end)

                    row.cells[j] = cell
                end

                cell:SetPoint("LEFT", row, "LEFT", xOffset + (j - 1) * columnWidth, 0)

                local enchants = data and data.enchants
                local enchantID = enchants and enchants[slotData.id]
                local itemLinks = data and data.itemLinks
                local itemLink = itemLinks and itemLinks[slotData.id]

                -- Store itemLink for tooltip
                cell.itemLink = itemLink

                if enchantID == nil then
                    -- No item in slot
                    cell.icon:Hide()
                    cell.text:SetText("|cff888888-|r")
                    cell.text:Show()
                elseif enchantID == 0 then
                    -- Item but no enchant - Red X
                    cell.text:Hide()
                    cell.icon:SetTexture("Interface/RaidFrame/ReadyCheck-NotReady")
                    cell.icon:Show()
                else
                    -- Has enchant - Green checkmark
                    cell.text:Hide()
                    cell.icon:SetTexture("Interface/RaidFrame/ReadyCheck-Ready")
                    cell.icon:Show()
                end
                cell:Show()
            end

            for k = #ENCHANT_SLOTS + 1, #row.cells do row.cells[k]:Hide() end
            row:Show()
        end

        local totalHeight = math_max(50, -yOffset + (#players * rowHeight))
        self:SetHeight(totalHeight)
        self:SetWidth(totalContentWidth)
    end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()

    local widget = {
        frame = frame,
        type = Type
    }

    AceGUI:RegisterAsWidget(widget)

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
