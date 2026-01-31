local Type, Version = "BotaTools_TrackedCurrencyList", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local addonName = ...
local BotaTools = LibStub("AceAddon-3.0"):GetAddon(addonName)

local pairs, ipairs, table_insert, table_sort = pairs, ipairs, table.insert, table.sort
local CreateFrame, UIParent = CreateFrame, UIParent
local GameTooltip = GameTooltip

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Currency_OnEnter(frame)
    if not frame.currencyId then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetCurrencyByID(frame.currencyId)
    GameTooltip:Show()
end

local function Currency_OnLeave(frame)
    GameTooltip:Hide()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self:SetHeight(40)
        self:UpdateData()
        -- Handle potential async loading
        self.frame:SetScript("OnUpdate", function() self:UpdateData() end)
    end,

    ["OnRelease"] = function(self)
        self.frame:SetScript("OnUpdate", nil)
        if self.rows then
            for _, row in ipairs(self.rows) do row:Hide() end
        end
    end,

    ["OnWidthSet"] = function(self, width)
        self:UpdateData()
    end,

    ["SetLabel"] = function(self, text)
        self:UpdateData()
    end,

    ["UpdateData"] = function(self)
        local trackedCurrencies = BotaTools.db.profile.trackedCurrencies
        if not trackedCurrencies then return end

        if self.rows then
            for _, row in ipairs(self.rows) do row:Hide() end
        end
        self.rows = self.rows or {}

        local trackedList = {}
        for id in pairs(trackedCurrencies) do table_insert(trackedList, id) end
        table_sort(trackedList)

        local topOffset = 30 -- Room for the Export button
        local rowHeight = 40
        local yOffset = -topOffset

        for i, currencyId in ipairs(trackedList) do
            local row = self.rows[i]
            local width = self.frame:GetWidth()
            if not width or width < 10 then width = 400 end

            if not row then
                row = CreateFrame("Frame", nil, self.frame)
                row:SetSize(width, rowHeight)
                row:EnableMouse(true)
                row:SetScript("OnEnter", Currency_OnEnter)
                row:SetScript("OnLeave", Currency_OnLeave)

                -- Subtle Background
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints()
                bg:SetColorTexture(1, 1, 1, 0.03)
                row.bg = bg

                -- Icon
                local iconBtn = CreateFrame("Frame", nil, row)
                iconBtn:SetSize(32, 32)
                iconBtn:SetPoint("LEFT", 8, 0)

                local tex = iconBtn:CreateTexture(nil, "ARTWORK")
                tex:SetAllPoints()
                iconBtn.texture = tex
                row.iconBtn = iconBtn

                -- Name
                local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
                name:SetPoint("LEFT", iconBtn, "RIGHT", 10, 0)
                name:SetJustifyH("LEFT")
                row.name = name

                -- Delete Button
                local delete = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
                delete:SetSize(60, 22)
                delete:SetPoint("RIGHT", -5, 0)
                delete:SetText("Remove")
                delete:SetScript("OnClick", function()
                    BotaTools.db.profile.trackedCurrencies[row.currencyId] = nil
                    BotaTools:GetModule("Currencies"):Refresh()
                end)
                row.delete = delete

                self.rows[i] = row
            end

            row.currencyId = currencyId

            local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)

            if info then
                row.iconBtn.texture:SetTexture(info.iconFileID or 134400)
                local displayName = string.format("%s (ID: %d)", info.name, currencyId)

                -- Color based on quality if available (Currencies usually quality 1-4)
                -- But GetCurrencyInfo uses `quality` Enum.
                local r, g, b, hex = GetItemQualityColor(info.quality or 1)

                row.name:SetText("|c" .. (hex or "ffffffff") .. displayName .. "|r")
            else
                row.name:SetText("Unknown Currency ID: " .. currencyId)
            end

            row:SetWidth(width)
            row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, yOffset)
            row:Show()
            yOffset = yOffset - rowHeight
        end

        local totalHeight = math.abs(yOffset)
        self:SetHeight(math.max(40, totalHeight))
    end,

    -- Required for AceConfig description type compatibility
    ["SetText"] = function(self, text) end,
    ["SetDisabled"] = function(self, disabled) end,
    ["SetFontObject"] = function(self, font) end,
    ["SetImage"] = function(self, path, ...) end,
    ["SetImageSize"] = function(self, width, height) end,
    ["SetColor"] = function(self, r, g, b) end,
}

local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:SetWidth(400) -- Default width

    -- Export Button
    local export = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    export:SetSize(120, 22)
    export:SetPoint("TOPLEFT", 5, -2)
    export:SetText("Export All IDs")
    export:SetScript("OnClick", function()
        local trackedCurrencies = BotaTools.db.profile.trackedCurrencies
        if not trackedCurrencies then return end

        local ids = {}
        for id in pairs(trackedCurrencies) do table.insert(ids, id) end
        table.sort(ids)

        local text = table.concat(ids, "\n")
        BotaTools:ShowCopyWindow("Export Tracked Currency IDs", text)
    end)
    frame.exportBtn = export

    local widget = {
        frame = frame,
        type  = Type
    }

    AceGUI:RegisterAsWidget(widget)

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
