local addonName, addon = ...
local BotaTools = LibStub("AceAddon-3.0"):GetAddon(addonName)
local Debug = BotaTools:NewModule("Debug", "AceConsole-3.0")
local AceGUI = LibStub("AceGUI-3.0")

function Debug:OnInitialize()
    self:RegisterChatCommand("botadump", "DumpTooltipData")
end

local function tableToString(t, indent)
    indent = indent or ""
    local str = ""
    if type(t) ~= "table" then
        return indent .. tostring(t) .. "\n"
    end

    for k, v in pairs(t) do
        if type(v) == "table" then
            str = str .. indent .. k .. ":\n"
            str = str .. tableToString(v, indent .. "  ")
        else
            str = str .. indent .. k .. ": " .. tostring(v) .. "\n"
        end
    end
    return str
end

function Debug:DumpTooltipData(input)
    if not input or input == "" then
        self:Print("Usage: /botadump <Item Link/ID> or /botadump currency <ID>")
        return
    end

    -- Check for currency sub-command
    local sub, rest = input:match("^(%S+)%s+(%d+)$")
    if sub == "currency" and rest then
        local id = tonumber(rest)
        local data = C_CurrencyInfo.GetCurrencyInfo(id)
        if data then
            local dumpStr = "Dump for CurrencyID: " .. id .. "\n\n"
            dumpStr = dumpStr .. tableToString(data)
            BotaTools:ShowCopyWindow("BotaTools Currency Dump", dumpStr)
        else
            self:Print("No data returned for Currency ID: " .. id)
        end
        return
    end

    -- Default: Item Logic
    local itemId = tonumber(input)
    if not itemId then
        -- Try to extract ID from link
        local _, _, id = string.find(input, "item:(%d+)")
        itemId = tonumber(id)
    end

    if not itemId then
        self:Print("Invalid Item ID, Link, or Sub-command.")
        return
    end

    if C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local data = C_TooltipInfo.GetItemByID(itemId)
        if data then
            local dumpStr = "Dump for ItemID: " .. itemId .. "\n\n"
            dumpStr = dumpStr .. tableToString(data)
            BotaTools:ShowCopyWindow("BotaTools Item Dump", dumpStr)
        else
            self:Print("No data returned from C_TooltipInfo.GetItemByID")
        end
    else
        self:Print("C_TooltipInfo APIs not available.")
    end
end
