---@class BotaTools : AceAddon, AceConsole, AceEvent, AceComm, AceSerializer
---@field db AceDB.Schema
---@field options table

---@class Consumables : AceModule, AceEvent, AceComm, AceSerializer
---@field scanResults table<string, table<number, number>>

local addonName, addonTable = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")


local Consumables = addon:NewModule("Consumables", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0") ---@cast Consumables Consumables

Consumables.scanResults = {}
Consumables.options = nil -- This will hold the reference to the consumables part of the options table

function Consumables:OnEnable()
    self:RegisterComm("BotaConsumables", "OnCommReceived")
end

function Consumables:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= "BotaConsumables" then return end

    local success, type, data = self:Deserialize(message)
    if not success then return end

    if type == "REQ_STATUS" then
        self:SendStatus(distribution, sender)
    elseif type == "RESP_STATUS" then
        self.scanResults[sender] = data
        self:Refresh()
        AceConfigRegistry:NotifyChange(addonName)
    end
end

function Consumables:SendStatus(distribution, target)
    local results = {}
    if addon.db.profile.trackedItems then
        for itemId in pairs(addon.db.profile.trackedItems) do
            results[itemId] = GetItemCount(itemId)
        end
    end

    local serialized = self:Serialize("RESP_STATUS", results)

    -- If request came from group, reply to group. If whisper, reply to whisper.
    -- Actually, simpler logic: Always reply to GROUP if in group, else WHISPER?
    -- The plan said "Broadcast to RAID".

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        self:SendCommMessage("BotaConsumables", serialized, channel)
    elseif target then
        self:SendCommMessage("BotaConsumables", serialized, "WHISPER", target)
    end
end

function Consumables:ScanRaid()
    self.scanResults = {} -- Clear previous results
    local serialized = self:Serialize("REQ_STATUS", nil)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        self:SendCommMessage("BotaConsumables", serialized, channel)
    else
        -- Self-test for solo debugging
        self.scanResults[UnitName("player")] = {}
        if addon.db.profile.trackedItems then
            for itemId in pairs(addon.db.profile.trackedItems) do
                self.scanResults[UnitName("player")][itemId] = GetItemCount(itemId)
            end
        end
        self:Refresh()
        AceConfigRegistry:NotifyChange(addonName)
    end
end

function Consumables:GetOptions()
    local options = {
        name = "Consumables",
        handler = self,
        type = "group",
        childGroups = "tab",
        args = {
            settings = {
                name = "Settings",
                type = "group",
                order = 1,
                args = {
                    addItem = {
                        name = "Add Item ID",
                        desc = "Add an item ID to track.",
                        type = "input",
                        order = 1,
                        set = function(info, val)
                            local id = tonumber(val)
                            if id then
                                addon.db.profile.trackedItems[id] = true
                                self:Refresh()
                                AceConfigRegistry:NotifyChange(addonName)
                            end
                        end,
                    },
                    trackedList = {
                        name = "Tracked Items",
                        type = "group",
                        inline = true,
                        order = 2,
                        args = {},
                    },
                },
            },
            status = {
                name = "Raid Status",
                type = "group",
                order = 2,
                args = {
                    scan = {
                        name = "Scan Raid",
                        type = "execute",
                        order = 0,
                        func = function() self:ScanRaid() end,
                    },
                    results = {
                        name = "Results Table",
                        type = "description",
                        dialogControl = "BotaTools_ConsumableTable",
                        order = 1,
                        width = "full",
                    }
                },
            },
        },
    }

    self.options = options
    return options
end

function Consumables:Refresh()
    if not self.options then return end

    -- 1. Refresh Tracked Items List
    self.options.args.settings.args.trackedList.args = {}
    if addon.db.profile.trackedItems then
        for itemId in pairs(addon.db.profile.trackedItems) do
            local itemName = "Item " .. itemId

            -- Try to get name from C_Item
            local info = C_Item.GetItemInfo(itemId)
            if info and info.itemName then
                itemName = info.itemName
            elseif GetItemInfo then -- Legacy fallback
                local name = GetItemInfo(itemId)
                if name then itemName = name end
            end

            self.options.args.settings.args.trackedList.args["item" .. itemId] = {
                name = itemName,
                type = "description",
                width = "double",
                order = itemId,
            }
            self.options.args.settings.args.trackedList.args["delete" .. itemId] = {
                name = "Delete",
                type = "execute",
                width = "half",
                order = itemId + 0.1,
                func = function()
                    addon.db.profile.trackedItems[itemId] = nil
                    self:Refresh()
                    AceConfigRegistry:NotifyChange(addonName)
                end,
            }
        end
    end

    -- 2. Refresh Status Table
    -- The custom widget (BotaTools_ConsumableTable) handles drawing the results.
    -- We just need to trigger an update if the widget is active.
    -- Calling NotifyChange will cause the widget to refresh via SetLabel/OnAcquire if open.
    AceConfigRegistry:NotifyChange(addonName)
end
