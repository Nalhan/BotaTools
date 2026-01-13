---@class BotaTools : AceAddon, AceConsole, AceEvent, AceComm, AceSerializer
---@field db AceDB.Schema
---@field options table

---@class Currencies : AceModule, AceEvent, AceComm, AceSerializer
---@field scanResults table<string, table<number, table>>

local addonName, addonTable = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

---@type Currencies
local Currencies = addon:NewModule("Currencies", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")

Currencies.scanResults = {}
Currencies.options = nil

function Currencies:OnEnable()
    self:RegisterComm("BotaCurrencies", "OnCommReceived")
    -- Ensure DB table exists
    if not addon.db.profile.trackedCurrencies then
        addon.db.profile.trackedCurrencies = {}
    end
end

function Currencies:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= "BotaCurrencies" then return end

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

function Currencies:SendStatus(distribution, target)
    local results = {}
    if addon.db.profile.trackedCurrencies then
        for currencyId in pairs(addon.db.profile.trackedCurrencies) do
            local info = C_CurrencyInfo.GetCurrencyInfo(currencyId)
            if info then
                -- Struct: [1]=Quantity, [2]=TotalEarned, [3]=MaxQuantity(Cap)
                results[currencyId] = {
                    info.quantity or 0,
                    info.totalEarned or 0,
                    info.maxQuantity or 0
                }
            end
        end
    end

    local _, class = UnitClass("player")
    local data = {
        class = class,
        currencies = results
    }

    local serialized = self:Serialize("RESP_STATUS", data)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        self:SendCommMessage("BotaCurrencies", serialized, channel)
    elseif target then
        self:SendCommMessage("BotaCurrencies", serialized, "WHISPER", target)
    end
end

function Currencies:ScanRaid()
    self.scanResults = {} -- Clear previous results
    local serialized = self:Serialize("REQ_STATUS", nil)

    if IsInGroup() then
        local channel = IsInRaid() and "RAID" or "PARTY"
        self:SendCommMessage("BotaCurrencies", serialized, channel)
    else
        -- Self-test for solo debugging
        local _, class = UnitClass("player")
        self.scanResults[UnitName("player")] = {
            class = class,
            currencies = {}
        }
        if addon.db.profile.trackedCurrencies then
            for id in pairs(addon.db.profile.trackedCurrencies) do
                local info = C_CurrencyInfo.GetCurrencyInfo(id)
                if info then
                    self.scanResults[UnitName("player")].currencies[id] = {
                        info.quantity or 0,
                        info.totalEarned or 0,
                        info.maxQuantity or 0
                    }
                end
            end
        end
        self:Refresh()
        AceConfigRegistry:NotifyChange(addonName)
    end
end

function Currencies:InjectTestData()
    self.scanResults = {}
    local tracked = {}
    if addon.db.profile.trackedCurrencies then
        for id in pairs(addon.db.profile.trackedCurrencies) do
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
            currencies = {}
        }
        for _, id in ipairs(tracked) do
            local info = C_CurrencyInfo.GetCurrencyInfo(id)
            -- Use actual cap if specified, otherwise fallback to 10000 for variety
            local cap = info and info.maxQuantity

            -- Randomize values for Current / Total Earned / Cap
            local total = math.random(0, cap + 500)
            local current = math.random(0, math.min(total, cap))

            self.scanResults[player].currencies[id] = { current, total, cap }
        end
    end
    self:Refresh()
    AceConfigRegistry:NotifyChange(addonName)
end

function Currencies:GetOptions()
    if not addon.db.profile.trackedCurrencies then
        addon.db.profile.trackedCurrencies = {}
    end
    local options = {
        name = "Currencies",
        handler = self,
        type = "group",
        childGroups = "tab",
        args = {
            settings = {
                name = "Settings",
                type = "group",
                order = 1,
                args = {
                    addCurrency = {
                        name = "Add Currency ID",
                        desc = "Add a currency ID to track.",
                        type = "input",
                        order = 1,
                        set = function(info, val)
                            local id = tonumber(val)
                            if id and C_CurrencyInfo.GetCurrencyInfo(id) then
                                addon.db.profile.trackedCurrencies[id] = true
                                self:Refresh()
                                AceConfigRegistry:NotifyChange(addonName)
                            end
                        end,
                    },
                    trackedList = {
                        name = "Tracked Currencies",
                        type = "description",
                        dialogControl = "BotaTools_TrackedCurrencyList",
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
                        dialogControl = "BotaTools_CurrenciesTable",
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

function Currencies:Refresh()
    if not self.options then return end
    AceConfigRegistry:NotifyChange(addonName)
end
