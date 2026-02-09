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

    local scrollParams = {
        width = 460,
        height = 320,
        line_height = 14,
        read_only = true,
        bg_color = { 0, 0, 0, 0.4 },
    }

    local editor = DF:NewSpecialLuaEditorEntry(f, 460, 320, "Editor", "BotaChangelogEditor", true)
    editor:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    editor:SetText(self:GetChangelogText())
    editor:EnableMouse(false) -- Make it read-only-ish by not focusing? DF Editor is usually editable.
    -- Actually, DF doesn't have a simple multi-line label with scroll.
    -- Let's use a standard scroll frame with a font string if DF's editor is too heavy/editable.
    -- But for now, let's try to just disable the editbox part if possible, or just let them edit it (it won't save).
    -- Better yet, let's just use a simple HTML frame or similar.

    -- Re-implementing with simple ScrollFrame + FontString for read-only text
    editor:Hide() -- Hide the editor we just made

    local scrollFrame = CreateFrame("ScrollFrame", "$parentScroll", f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 40)

    -- Hide scroll bar
    if scrollFrame.ScrollBar then
        scrollFrame.ScrollBar:Hide()
        scrollFrame.ScrollBar:SetScript("OnShow", function(self) self:Hide() end)
    end

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(460, 1000)
    scrollFrame:SetScrollChild(content)

    local text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    text:SetWidth(450)
    text:SetJustifyH("LEFT")
    text:SetText(self:GetChangelogText())

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

    if BOTASV.lastVersion ~= currentVersion then
        self:Show()
        BOTASV.lastVersion = currentVersion
    end
end
