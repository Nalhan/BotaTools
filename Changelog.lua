local _, BOTA = ...
local DF = _G["DetailsFramework"]

BOTA.Changelog = {}

function BOTA.Changelog:GetChangelogText()
    return BOTA.ChangelogData or "No changelog data available."
end

function BOTA.Changelog:CreateFrame()
    if self.frame then return self.frame end

    local f = DF:CreateSimplePanel(UIParent, 500, 400, "BotaTools Changelog", "BotaChangelogFrame")
    f:SetFrameStrata("DIALOG")
    f:SetPoint("CENTER")

    local scrollFrame = CreateFrame("ScrollFrame", "$parentScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

    -- Hide scroll bar
    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:Hide()
        scrollFrame.ScrollBar:SetScript("OnShow", function(self) self:Hide() end)
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(460, 10) -- Height updated below
    scrollFrame:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    text:SetWidth(450)
    text:SetJustifyH("LEFT")
    text:SetText(self:GetChangelogText())

    -- Dynamic Resizing: Calculate height based on content
    local contentHeight = text:GetStringHeight()
    content:SetHeight(contentHeight + 10)

    local targetHeight = contentHeight + 80 -- 30 (header) + 40 (footer) + 10 (padding)
    targetHeight = math.max(200, math.min(600, targetHeight))
    f:SetHeight(targetHeight)

    -- Add Close Button
    local closeButton = DF:CreateButton(f, function() f:Hide() end, 100, 20, "Close", nil, nil, nil, nil, nil, true)
    closeButton:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    closeButton:SetTemplate(DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))

    self.frame = f
    return f
end

function BOTA.Changelog:Show()
    local f = self:CreateFrame()
    f:Show()
end

function BOTA.Changelog:Init()
    local currentVersion = C_AddOns.GetAddOnMetadata("BotaTools", "Version")

    if not BOTASV then BOTASV = {} end

    BOTA:DebugLog("[Changelog] Init. Last: " .. tostring(BOTASV.lastVersion) .. " Current: " .. tostring(currentVersion))

    if BOTASV.lastVersion ~= currentVersion then
        BOTA:DebugLog("[Changelog] Version mismatch, showing frame (delayed).")
        C_Timer.After(3, function()
            self:Show()
        end)
        BOTASV.lastVersion = currentVersion
    end
end
