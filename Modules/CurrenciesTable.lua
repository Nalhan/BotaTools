local Type, Version = "BotaTools_CurrenciesTable", 1
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
local C_CurrencyInfo = C_CurrencyInfo

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Header_OnEnter(frame)
    if not frame.currencyId then return end
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:SetCurrencyByID(frame.currencyId)
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
        local Currencies = BotaTools:GetModule("Currencies")
        if not Currencies then return end

        local trackedCurrencies = BotaTools.db.profile.trackedCurrencies
        local scanResults = Currencies.scanResults or {}

        -- 1. Headers (Icons)
        if self.headers then
            for _, header in ipairs(self.headers) do header:Hide() end
        end
        self.headers = self.headers or {}

        local trackedList = {}
        if trackedCurrencies then
            for id in pairs(trackedCurrencies) do table_insert(trackedList, id) end
            table_sort(trackedList)
        end

        local headerSize = 16   -- Small icon
        local columnWidth = 120 -- Increased from 100
        local xOffset = 150     -- Start after name column

        for i, currencyId in ipairs(trackedList) do
            local header = self.headers[i]
            if not header then
                header = CreateFrame("Button", nil, self.frame)
                header:SetSize(columnWidth, 40) -- Adjusted height for horizontal layout
                header:SetScript("OnEnter", Header_OnEnter)
                header:SetScript("OnLeave", Header_OnLeave)

                local tex = header:CreateTexture(nil, "ARTWORK")
                tex:SetSize(headerSize, headerSize)
                tex:SetPoint("LEFT", 5, 0) -- Icon on the left
                header.texture = tex

                local name = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                name:SetPoint("LEFT", tex, "RIGHT", 4, 0)
                name:SetPoint("RIGHT", -5, 0)
                name:SetJustifyH("LEFT")
                name:SetJustifyV("MIDDLE")
                name:SetWordWrap(true)
                header.name = name

                self.headers[i] = header
            end

            header:SetPoint("TOPLEFT", self.frame, "TOPLEFT", xOffset + (i - 1) * columnWidth, 0)

            local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
            header.texture:SetTexture(info and info.iconFileID or 134400)
            header.name:SetText(info and info.name or ("ID: " .. currencyId))
            header.currencyId = currencyId
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
        local yOffset = -45 -- Adjusted room for new header height

        for i, player in ipairs(players) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, self.frame)
                row:SetSize(self.frame:GetWidth(), rowHeight)

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
            for j, currencyId in ipairs(trackedList) do
                local cell = row.cells[j]
                if not cell then
                    cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") -- Smaller font for long strings
                    cell:SetWidth(columnWidth)
                    cell:SetJustifyH("CENTER")
                    row.cells[j] = cell
                end

                cell:SetPoint("LEFT", row, "LEFT", xOffset + (j - 1) * columnWidth, 0)

                local currencies = data and data.currencies
                local cData = currencies and
                    currencies[currencyId] -- [1]=Quantity, [2]=TotalEarned, [3]=MaxQuantity(Cap)

                if cData then
                    local current = cData[1] or 0
                    local earned = cData[2] or 0
                    local cap = cData[3] or 0

                    -- Display: Current / Earned / Cap
                    -- Color coding:
                    -- Red if current is 0?
                    -- Green if earned is at cap?
                    local earnedStr
                    if cap > 0 and earned >= cap then
                        earnedStr = "|cff00ff00" .. BotaTools:FormatLargeNumber(earned) .. "|r"
                    else
                        earnedStr = BotaTools:FormatLargeNumber(earned)
                    end

                    local text = string.format("%s/%s/%s",
                        BotaTools:FormatLargeNumber(current),
                        earnedStr,
                        BotaTools:FormatLargeNumber(cap)
                    )
                    cell:SetText(text)
                else
                    cell:SetText("|cff888888-|r")
                end
                cell:Show()
            end

            for k = #trackedList + 1, #row.cells do row.cells[k]:Hide() end
            row:Show()
        end

        local totalHeight = math_max(50, -yOffset + (#players * rowHeight))
        self:SetHeight(totalHeight)
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
