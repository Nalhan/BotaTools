local _, BOTA = ...

--[[-----------------------------------------------------------------------------
Shared Utilities
-------------------------------------------------------------------------------]]

BOTA.ClassList = {
    "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT",
    "SHAMAN", "MAGE", "WARLOCK", "MONK", "DRUID", "DEMONHUNTER", "EVOKER"
}

--- Scrapes quality icon atlas Name from tooltip
function BOTA:GetQualityTexture(itemId)
    if not C_TooltipInfo or not C_TooltipInfo.GetItemByID then return end

    local data = C_TooltipInfo.GetItemByID(itemId)
    if not data or not data.lines then return end

    for _, line in ipairs(data.lines) do
        -- Check text for |A:atlasName:...|a pattern
        -- Example: Quality: |A:Professions-Icon-Quality-12-Tier2-Small:38:40:0:-1|a
        if line.leftText then
            local atlas = string.match(line.leftText, "|A:([%w%-]+):")
            -- We match 'Quality' OR 'Tier' to ensure it's a rank icon
            if atlas and (string.find(atlas, "Quality") or string.find(atlas, "Tier")) then
                return atlas
            end
        end

        -- Fallback: check structured args
        if line.args then
            for _, arg in ipairs(line.args) do
                if arg.atlasName and (string.find(arg.atlasName, "Quality") or string.find(arg.atlasName, "Tier")) then
                    return arg.atlasName
                end
            end
        end
    end
end

--- Returns numeric crafting rank (1-3)
function BOTA:GetCraftingRank(link, itemId)
    if not link and not itemId then return end

    local quality
    -- Try Reagent Quality by ID (Best for stateless IDs)
    if itemId and C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
        quality = C_TradeSkillUI.GetItemReagentQualityByItemInfo(itemId)
        if quality then return quality end
    end
    -- Try Crafting Quality by Link
    if link and C_TradeSkillUI and C_TradeSkillUI.GetItemCraftingQuality then
        quality = C_TradeSkillUI.GetItemCraftingQuality(link)
        if quality then return quality end
    end
    -- Item fallback
    if link and C_Item and C_Item.GetCraftingQualityID then
        quality = C_Item.GetCraftingQualityID(link)
        if quality then return quality end
    end

    return nil
end

--- Formats numbers (e.g., 1200 -> 1.2k)
function BOTA:FormatLargeNumber(number)
    if not number then return "0" end
    if number < 1000 then return tostring(number) end

    if number < 1000000 then
        local k = number / 1000
        if k >= 10 then
            return string.format("%.0fk", k)
        else
            return string.format("%.1fk", k):gsub("%.0k", "k")
        end
    end

    local m = number / 1000000
    if m >= 10 then
        return string.format("%.0fm", m)
    else
        return string.format("%.1fm", m):gsub("%.0m", "m")
    end
end

--- Shows a copy-paste window with the given text
function BOTA:ShowCopyWindow(title, text)
    local DF = _G["DetailsFramework"]

    -- Create a simple panel for copy-paste
    local frame = DF:CreateSimplePanel(UIParent, 500, 400, title, "BOTACopyWindow")
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")

    -- Create an editbox for the text
    local editbox = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    editbox:SetMultiLine(true)
    editbox:SetMaxLetters(99999)
    editbox:SetAutoFocus(false)
    editbox:SetFontObject(GameFontHighlightSmall)
    editbox:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    editbox:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 40)
    editbox:SetText(text)
    editbox:HighlightText()

    -- Scrollframe for the editbox
    local scrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 40)
    scrollFrame:SetScrollChild(editbox)

    -- Close button
    local closeButton = DF:CreateButton(frame, function() frame:Hide() end, 80, 25, "Close")
    closeButton:SetPoint("BOTTOM", frame, "BOTTOM", 0, 10)
end

--- Formats a player name with their class color
function BOTA:FormatPlayerName(name, class)
    if not name then return "" end
    if not class then return name end

    local color = RAID_CLASS_COLORS[class]
    if color then
        return string.format("|cff%02x%02x%02x%s|r",
            math.floor(color.r * 255),
            math.floor(color.g * 255),
            math.floor(color.b * 255),
            name)
    end
    return name
end

--- Creates a standard container frame for module tabs
-- @param parent The parent frame (usually the config window)
-- @param name Unique name for the frame
-- @return container The created container frame
function BOTA:CreateTabContainer(parent, name)
    local container = CreateFrame("Frame", name, parent)
    container:SetSize(parent:GetWidth() - 330, 420)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", 320, -90)
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel(parent:GetFrameLevel() + 10)

    -- Header Frame
    local headerFrame = CreateFrame("Frame", nil, container)
    headerFrame:SetSize(container:GetWidth(), 30)
    headerFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
    container.headerFrame = headerFrame

    return container
end

--- Shared OnEnter script for frames with itemId or itemLink
function BOTA.OnEnterItem(self)
    if not self then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

    if self.itemLink then
        GameTooltip:SetHyperlink(self.itemLink)
    elseif self.itemId then
        -- Use the C_TooltipInfo API if available (10.0+), or fallback (though SetItemByID is standard)
        if C_TooltipInfo and C_TooltipInfo.GetItemByID then
            GameTooltip:SetItemByID(self.itemId)
        else
            GameTooltip:SetHyperlink("item:" .. self.itemId)
        end
    end

    GameTooltip:Show()
end

--- Shared OnLeave script
function BOTA.OnLeave(self)
    GameTooltip:Hide()
end

--- Creates a management list with ScrollBox
-- @param parent The parent frame
-- @param items Ordered list of items (table of IDs or objects)
-- @param callbacks Table with { OnRemove=func(index), OnMoveUp=func(index), OnMoveDown=func(index) }
-- @param config Table with { width=300, height=200, rowHeight=20, nameProvider=func(item) }
function BOTA:CreateManagementList(parent, items, callbacks, config)
    local DF = _G["DetailsFramework"]
    config = config or {}
    local rowHeight = config.rowHeight or 24
    local width = config.width or 300
    local height = config.height or 200

    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(width, height)
    DF:ApplyStandardBackdrop(f)

    -- Calculate Line Amount
    local lineAmount = math.ceil(height / rowHeight) + 2

    -- Refresh Function (iterates lines)
    local refreshScroll = function(self, data, offset, totalLines)
        -- totalLines is the number of visible lines (capacity) passed by DF
        for i = 1, totalLines do
            local index = i + offset
            local itemData = data[index]

            -- CRITICAL: Only call GetLine if we have data.
            -- Calling GetLine(i) marks the frame as 'InUse', which causes DF to force :Show() it.
            -- If we don't call GetLine, the frame remains 'Use=nil' and DF :Hide()s it (or keeps it hidden).
            if itemData then
                local row = self:GetLine(i)
                if row then
                    -- Update Row
                    local labelText = itemData
                    if config.nameProvider then
                        labelText = config.nameProvider(itemData)
                    end
                    row.label:SetText(labelText)

                    -- Update Icon
                    if config.iconProvider then
                        local icon = config.iconProvider(itemData)
                        row.icon:SetTexture(icon or 134400)
                    else
                        row.icon:SetTexture(nil)
                    end

                    row.index = index

                    -- Buttons
                    row.remove:Show()

                    if callbacks.OnMoveUp then
                        row.upData:Show()
                        if index == 1 then row.upData:Disable() else row.upData:Enable() end
                    else
                        row.upData:Hide()
                    end

                    if callbacks.OnMoveDown then
                        row.downData:Show()
                        if index == #data then row.downData:Disable() else row.downData:Enable() end
                    else
                        row.downData:Hide()
                    end
                end
            end
        end
    end


    -- Row Creation Function
    local createRow = function(self, index)
        local row = CreateFrame("Frame", "$parentRow" .. index, self)
        row:SetSize(width - 20, rowHeight)
        row:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -((index - 1) * rowHeight))
        row:SetFrameLevel(self:GetFrameLevel() + 5) -- Ensure rows are on top

        -- Mouseover highlight
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.1)

        -- Icon
        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(rowHeight - 4, rowHeight - 4)
        icon:SetPoint("LEFT", row, "LEFT", 2, 0)
        row.icon = icon

        -- Label
        local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        label:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        label:SetWidth(width - 100)
        label:SetJustifyH("LEFT")
        row.label = label

        -- Remove Button (X)
        local remove = DF:CreateButton(row, function()
            if callbacks.OnRemove then
                callbacks.OnRemove(row.index)
                -- Force a data refresh if the callback modifies the table
                f:Refresh()
            end
        end, 18, 18)
        remove:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        remove:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
        remove:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
        remove:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
        row.remove = remove

        -- Down Button (v)
        local down = DF:CreateButton(row, function()
            if callbacks.OnMoveDown then
                callbacks.OnMoveDown(row.index)
                f:Refresh()
            end
        end, 18, 18)
        down:SetPoint("RIGHT", remove, "LEFT", -2, 0)
        down:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
        down:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
        down:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
        down:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        row.downData = down

        -- Up Button (^)
        local up = DF:CreateButton(row, function()
            if callbacks.OnMoveUp then
                callbacks.OnMoveUp(row.index)
                f:Refresh()
            end
        end, 18, 18)
        up:SetPoint("RIGHT", down, "LEFT", -2, 0)
        up:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Up")
        up:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Down")
        up:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollUp-Disabled")
        up:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
        row.upData = up

        return row
    end

    -- Create ScrollBox
    -- Args: parent, name, refreshFunc, data, width, height, lineAmount, lineHeight
    local scrollBox = DF:CreateScrollBox(f, "$parentScrollBox", refreshScroll, items, width, height, lineAmount,
        rowHeight)
    DF:ReskinSlider(scrollBox)
    f.scrollBox = scrollBox
    scrollBox:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    scrollBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    scrollBox:SetFrameLevel(f:GetFrameLevel() + 5) -- Ensure scrollbox is above container

    -- Create Lines
    for i = 1, lineAmount do
        scrollBox:CreateLine(createRow)
    end

    function f:Refresh()
        scrollBox:SetData(items)
        scrollBox:Refresh()
    end

    f:Refresh()
    return f
end
