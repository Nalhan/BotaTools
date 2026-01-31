---@class BotaTools : AceAddon, AceConsole, AceEvent, AceComm, AceSerializer
---@field db AceDB.Schema
---@field options table

---@class Enchants : AceModule, AceEvent, AceComm, AceSerializer
---@field scanResults table<string, table<number, number>>

local addonName, addonTable = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local Enchants = addon:NewModule("Enchants", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0") ---@cast Enchants Enchants

Enchants.scanResults = {}
Enchants.options = nil

-- Slot IDs to check for enchants
local ENCHANT_SLOTS = {
    [1] = "Head",
    [3] = "Shoulder",
    [5] = "Chest",
    [7] = "Legs",
    [8] = "Feet",
    [11] = "Finger 1",
    [12] = "Finger 2",
    [16] = "Mainhand",
    [17] = "Offhand",
}

function Enchants:OnEnable()
    self:RegisterComm("BotaEnchants", "OnCommReceived")
end

function Enchants:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= "BotaEnchants" then return end

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

-- Extract enchant ID from item link
local function GetEnchantID(itemLink)
    if not itemLink then return nil end
    -- Item link format: |cffffffff|Hitem:itemID:enchantID:...|h[name]|h|r
    local enchantID = itemLink:match("item:%d+:(%d+)")
    if enchantID and tonumber(enchantID) and tonumber(enchantID) > 0 then
        return tonumber(enchantID)
    end
    return nil
end

function Enchants:SendStatus(distribution, target)
    local results = {}
    local itemLinks = {}

    for slotID, slotName in pairs(ENCHANT_SLOTS) do
        local itemLink = GetInventoryItemLink("player", slotID)
        if itemLink then
            local enchantID = GetEnchantID(itemLink)
            results[slotID] = enchantID or 0 -- 0 means no enchant
            itemLinks[slotID] = itemLink
        else
            results[slotID] = nil -- nil means no item in slot
            itemLinks[slotID] = nil
        end
    end

    local _, class = UnitClass("player")
    local data = {
        class = class,
        enchants = results,
        itemLinks = itemLinks
    }

    local serialized = self:Serialize("RESP_STATUS", data)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        self:SendCommMessage("BotaEnchants", serialized, channel)
    elseif target then
        self:SendCommMessage("BotaEnchants", serialized, "WHISPER", target)
    end
end

function Enchants:ScanRaid()
    self.scanResults = {}
    local serialized = self:Serialize("REQ_STATUS", nil)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        self:SendCommMessage("BotaEnchants", serialized, channel)
    else
        -- Self-test for solo debugging
        local _, class = UnitClass("player")
        self.scanResults[UnitName("player")] = {
            class = class,
            enchants = {}
        }

        self.scanResults[UnitName("player")].itemLinks = {}

        for slotID, slotName in pairs(ENCHANT_SLOTS) do
            local itemLink = GetInventoryItemLink("player", slotID)
            if itemLink then
                local enchantID = GetEnchantID(itemLink)
                self.scanResults[UnitName("player")].enchants[slotID] = enchantID or 0
                self.scanResults[UnitName("player")].itemLinks[slotID] = itemLink
            else
                self.scanResults[UnitName("player")].enchants[slotID] = nil
                self.scanResults[UnitName("player")].itemLinks[slotID] = nil
            end
        end

        self:Refresh()
        AceConfigRegistry:NotifyChange(addonName)
    end
end

function Enchants:InjectTestData()
    self.scanResults = {}

    local classes = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "DEATHKNIGHT", "SHAMAN", "MAGE", "WARLOCK",
        "MONK", "DRUID", "DEMONHUNTER", "EVOKER" }

    for i = 1, 30 do
        local player = "TestPlayer-" .. i
        local class = classes[math.random(1, #classes)]
        self.scanResults[player] = {
            class = class,
            enchants = {}
        }

        for slotID in pairs(ENCHANT_SLOTS) do
            -- Randomly assign: nil (no item), 0 (no enchant), or enchant ID
            local roll = math.random(1, 10)
            if roll <= 1 then
                -- 10% chance: no item in slot
                self.scanResults[player].enchants[slotID] = nil
            elseif roll <= 3 then
                -- 20% chance: item but no enchant
                self.scanResults[player].enchants[slotID] = 0
            else
                -- 70% chance: has enchant (use realistic enchant IDs)
                local enchantIDs = { 6643, 6647, 6648, 6649, 6650, 7460, 7461, 7462, 7463 }
                self.scanResults[player].enchants[slotID] = enchantIDs[math.random(1, #enchantIDs)]
            end
        end
    end

    self:Refresh()
    AceConfigRegistry:NotifyChange(addonName)
end

function Enchants:Refresh()
    if self.options and self.options.args and self.options.args.table then
        local widget = self.options.args.table.dialogControl
        if widget and widget.UpdateData then
            widget:UpdateData()
        end
    end
end

function Enchants:GetOptions()
    local options = {
        name = "Enchants",
        handler = self,
        type = "group",
        args = {
            scan = {
                type = "execute",
                name = "Scan Raid",
                desc = "Request enchant status from all raid members",
                func = function() self:ScanRaid() end,
                order = 1,
            },
            debug = {
                type = "execute",
                name = "Debug: 30 Players",
                desc = "Inject test data for 30 players",
                func = function() self:InjectTestData() end,
                order = 2,
            },
            table = {
                type = "description",
                name = "",
                width = "full",
                dialogControl = "BotaTools_EnchantsTable",
                order = 10,
            },
        },
    }

    self.options = options
    return options
end
