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

    local _, class = UnitClass("player")
    local data = {
        class = class,
        items = results
    }

    local serialized = self:Serialize("RESP_STATUS", data)

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
        local _, class = UnitClass("player")
        self.scanResults[UnitName("player")] = {
            class = class,
            items = {}
        }
        if addon.db.profile.trackedItems then
            for itemId in pairs(addon.db.profile.trackedItems) do
                self.scanResults[UnitName("player")].items[itemId] = GetItemCount(itemId)
            end
        end
        self:Refresh()
        AceConfigRegistry:NotifyChange(addonName)
    end
end

function Consumables:InjectTestData()
    self.scanResults = {}
    local tracked = {}
    if addon.db.profile.trackedItems then
        for id in pairs(addon.db.profile.trackedItems) do
            table.insert(tracked, id)
        end
    end

    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
        "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

    for i = 1, 30 do
        local player = "TestPlayer-" .. i
        local class = classes[math.random(1, #classes)]
        self.scanResults[player] = {
            class = class,
            items = {}
        }
        for _, id in ipairs(tracked) do
            -- Even distribution across 5 buckets: 0, 1-Digit, 2-Digit, 3-Digit, 1k-9k
            local bucket = math.random(1, 5)
            local val
            if bucket == 1 then
                val = 0
            elseif bucket == 2 then
                val = math.random(1, 9)       -- 1 digit
            elseif bucket == 3 then
                val = math.random(10, 99)     -- 2 digits
            elseif bucket == 4 then
                val = math.random(100, 999)   -- 3 digits
            else
                val = math.random(1000, 9999) -- 4 digits (1k-9k)
            end
            self.scanResults[player].items[id] = val
        end
    end
    self:Refresh()
    AceConfigRegistry:NotifyChange(addonName)
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
                    dropzone = {
                        name = "Drop Zone",
                        type = "description",
                        dialogControl = "BotaTools_ItemDropZone",
                        order = 1.5,
                        width = "full",
                        -- Passing callback via 'arg' to avoid AceConfig validation error
                        arg = {
                            onItemDropped = function(itemId)
                                addon.db.profile.trackedItems[itemId] = true
                                Consumables:Refresh()
                                AceConfigRegistry:NotifyChange(addonName)
                            end,
                        },
                    },
                    trackedList = {
                        name = "Tracked Items",
                        type = "description",
                        dialogControl = "BotaTools_TrackedItemList",
                        order = 2,
                        width = "full",
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
                        width = "half",
                    },
                    debugdata = {
                        name = "Debug: 30 Players",
                        type = "execute",
                        order = 0.5,
                        func = function() self:InjectTestData() end,
                        width = "half",
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

    -- The custom widget (BotaTools_TrackedItemList) handles drawing the list.
    -- Calling NotifyChange will cause the widget to refresh via SetLabel/OnAcquire if open.
    AceConfigRegistry:NotifyChange(addonName)
end
