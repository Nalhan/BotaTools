local Type, Version = "BotaTools_ItemDropZone", 1
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local pairs, type = pairs, type
local CreateFrame, UIParent = CreateFrame, UIParent
local GetCursorInfo = GetCursorInfo
local ClearCursor = ClearCursor

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
    ["OnAcquire"] = function(self)
        self:SetHeight(80)
        self:SetFullWidth(true)
        self:SetLabel("Drag Items Here")
        self.frame:SetScript("OnUpdate", self.OnUpdate)
    end,

    ["OnRelease"] = function(self)
        self.frame:SetScript("OnUpdate", nil)
    end,

    ["SetLabel"] = function(self, text)
        self.labelText = text
        self.label:SetText(text or "Drag Items Here")
    end,

    ["SetCustomData"] = function(self, data)
        self.customData = data
    end,

    -- Required for AceConfig description type compatibility
    ["SetText"] = function(self, text) end,
    ["SetFontObject"] = function(self, font) end,
    ["SetImage"] = function(self, path, ...) end,
    ["SetImageSize"] = function(self, width, height) end,
    ["SetColor"] = function(self, r, g, b) end,

    ["OnUpdate"] = function(frame)
        local self = frame.obj
        local infoType, itemId = GetCursorInfo()
        local isOver = frame:IsMouseOver()

        if infoType == "item" and itemId then
            if isOver then
                -- Hovering over the zone with an item (Muted Green)
                frame.bg:SetColorTexture(0.2, 0.6, 0.2, 0.4)
                frame.border:SetColorTexture(0.4, 0.8, 0.4, 0.8)

                local itemName, _, _, _, _, _, _, _, _, itemIcon = GetItemInfo(itemId)
                if itemName and itemIcon then
                    frame.icon:SetTexture(itemIcon)
                    frame.icon:Show()
                    frame.label:SetText(itemName)
                else
                    -- Data not yet loaded, request it
                    C_Item.RequestLoadItemDataByID(itemId)
                    frame.icon:Hide()
                    frame.label:SetText("Loading Item...")
                end
            else
                -- Item is on cursor but not over zone (Yellow)
                frame.bg:SetColorTexture(1.0, 1.0, 0.0, 0.1)
                frame.border:SetColorTexture(1.0, 1.0, 0.0, 0.4)
                frame.icon:Hide()
                frame.label:SetText("Drop Item Here")
            end
        else
            -- Normal state
            frame.bg:SetColorTexture(1, 1, 1, 0.05)
            frame.border:SetColorTexture(1, 1, 1, 0.2)
            frame.icon:Hide()
            frame.label:SetText(self.labelText or "Drag Items Here")
        end
    end,

    ["OnMouseUp"] = function(frame)
        local infoType, itemId = GetCursorInfo()
        if infoType == "item" and itemId then
            ClearCursor()
            local self = frame.obj
            if self.customData and self.customData.onItemDropped then
                self.customData.onItemDropped(itemId)
            end
            self:Fire("OnItemDropped", itemId)
        end
    end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent)
    frame:Hide()
    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", methods.OnMouseUp)
    frame:SetScript("OnReceiveDrag", methods.OnMouseUp) -- Also handle explicit drag events

    -- Background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 0.05)
    frame.bg = bg

    -- Border (Flat look)
    local border = frame:CreateTexture(nil, "BORDER") -- Explicitly lower than ARTWORK/OVERLAY
    border:SetPoint("TOPLEFT")
    border:SetPoint("BOTTOMRIGHT")
    border:SetColorTexture(1, 1, 1, 0.2)
    frame.border = border

    -- Icon
    local icon = frame:CreateTexture(nil, "ARTWORK") -- Higher than BORDER
    icon:SetSize(32, 32)
    icon:SetPoint("CENTER", 0, 10)
    icon:Hide()
    frame.icon = icon

    -- Label
    local label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge") -- Highest layer
    label:SetPoint("CENTER", 0, -15)
    label:SetText("Drag Items Here")
    frame.label = label

    local widget = {
        frame = frame,
        label = label,
        type  = Type
    }

    AceGUI:RegisterAsWidget(widget)

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return widget
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
