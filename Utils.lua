local addonName, addonTable = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)

--[[-----------------------------------------------------------------------------
Shared Utilities
-------------------------------------------------------------------------------]]

--- Scrapes quality icon atlas Name from tooltip
function addon:GetQualityTexture(itemId)
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
function addon:GetCraftingRank(link, itemId)
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
function addon:FormatLargeNumber(number)
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
function addon:ShowCopyWindow(title, text)
    local AceGUI = LibStub("AceGUI-3.0")
    local frame = AceGUI:Create("Frame")
    frame:SetTitle(title)
    frame:SetCallback("OnClose", function(widget) AceGUI:Release(widget) end)
    frame:SetLayout("Fill")
    frame:SetWidth(500)
    frame:SetHeight(400)

    local editBox = AceGUI:Create("MultiLineEditBox")
    editBox:SetLabel("")
    editBox:SetText(text)
    editBox:DisableButton(true)
    editBox:SetFocus()
    frame:AddChild(editBox)
end
