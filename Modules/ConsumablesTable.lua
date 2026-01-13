local Type, Version = "BotaTools_ConsumableTable", 1
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
local C_Item = C_Item

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Header_OnEnter(frame)
    if not frame.itemId then return end
    GameTooltip:SetOwner(frame, "ANCHOR_TOP")
    GameTooltip:SetItemByID(frame.itemId)
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
        self:SetHeight(300) -- Default height
        self:SetWidth(400)  -- Default width
        self:UpdateData()
    end,

    ["OnRelease"] = function(self)
        -- Release logic if needed (clearing children)
    end,

    ["SetLabel"] = function(self, text)
        -- Ignore label for now, or use it as caption
    end,

    ["SetText"] = function(self, text)
        -- Used by AceConfig description type
    end,

    ["SetDisabled"] = function(self, disabled)
        -- Used by AceConfig
    end,

    -- Robustness: Add other potential methods called by AceConfigDialog for descriptions/labels
    ["SetFontObject"] = function(self, font)
        -- No-op
    end,

    ["SetImage"] = function(self, path, ...)
        -- No-op
    end,

    ["SetImageSize"] = function(self, width, height)
        -- No-op
    end,

    ["SetColor"] = function(self, r, g, b)
        -- No-op
    end,

    ["UpdateData"] = function(self)
        local Consumables = BotaTools:GetModule("Consumables")
        if not Consumables then return end

        local trackedItems = BotaTools.db.profile.trackedItems
        local scanResults = Consumables.scanResults or {}

        -- 1. Headers (Icons)
        if self.headers then
            for _, header in ipairs(self.headers) do header:Hide() end
        end
        self.headers = self.headers or {}

        local trackedList = {}
        if trackedItems then
            for id in pairs(trackedItems) do table_insert(trackedList, id) end
            table_sort(trackedList) -- consistent order by ID
        end

        local headerSize = 24
        local xOffset = 150 -- Start after name column

        for i, itemId in ipairs(trackedList) do
            local header = self.headers[i]
            if not header then
                header = CreateFrame("Button", nil, self.content)
                header:SetSize(headerSize, headerSize)
                header:SetScript("OnEnter", Header_OnEnter)
                header:SetScript("OnLeave", Header_OnLeave)

                local tex = header:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints()
                header.texture = tex

                self.headers[i] = header
            end

            header:SetPoint("TOPLEFT", self.content, "TOPLEFT", xOffset + (i - 1) * (headerSize + 5), 0)

            local itemInfo = C_Item.GetItemInfo(itemId)
            -- if itemInfo is nil (async load), using C_Item.GetItemIconByID or waiting?
            -- C_Item.GetItemIcon can work with ID usually immediately?
            -- Actually C_Item.GetItemIconByID isn't classic/retail unified always.
            -- GetItemIcon(itemId) works standard.
            local icon = GetItemIcon(itemId) or 134400
            header.texture:SetTexture(icon)
            header.itemId = itemId
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

        local rowHeight = 20
        local yOffset = -30 -- Below headers

        for i, player in ipairs(players) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, self.content)
                row:SetSize(self.content:GetWidth(), rowHeight)

                local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                name:SetPoint("LEFT", 0, 0)
                name:SetWidth(140)
                name:SetJustifyH("LEFT")
                row.name = name

                row.cells = {}
                self.rows[i] = row
            end

            row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, yOffset + (i - 1) * (-rowHeight))
            row.name:SetText(player)

            -- Cells
            local counts = scanResults[player]
            for j, itemId in ipairs(trackedList) do
                local cell = row.cells[j]
                if not cell then
                    cell = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    cell:SetWidth(headerSize)
                    cell:SetJustifyH("CENTER")
                    row.cells[j] = cell
                end

                cell:SetPoint("LEFT", row, "LEFT", xOffset + (j - 1) * (headerSize + 5), 0)

                local count = counts[itemId] or 0
                if count > 0 then
                    cell:SetText("|cff00ff00" .. count .. "|r")
                else
                    cell:SetText("|cffff0000" .. count .. "|r")
                end
                cell:Show()
            end

            -- Hide unused cells for this row
            for k = #trackedList + 1, #row.cells do
                row.cells[k]:Hide()
            end

            row:Show()
        end

        -- Adjust Content Height
        local totalHeight = math_max(300, -yOffset + (#players * rowHeight))
        self.content:SetHeight(totalHeight)
    end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()

    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -10)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 10)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(400, 300)
    scrollFrame:SetScrollChild(content)

    local widget = {
        frame = frame,
        content = content,
        type = Type
    }

    AceGUI:RegisterAsWidget(widget)

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
