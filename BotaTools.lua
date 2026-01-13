---@class BotaTools : AceAddon, AceConsole, AceEvent, AceComm, AceSerializer
---@field db AceDB.Schema
---@field options table

-- BotaTools Addon
local addonName, addonTable = ...

-- Load LibStub and Ace libraries
local AceAddon = LibStub("AceAddon-3.0")
local AceConsole = LibStub("AceConsole-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceEvent = LibStub("AceEvent-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceSerializer = LibStub("AceSerializer-3.0")
local AceComm = LibStub("AceComm-3.0")

-- Create addon using AceAddon
local addon = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0") ---@cast addon BotaTools
addon.name = addonName

-- Addon state
-- Modules will handle their own statet settings

-- Default settings
local defaults = {
    profile = {
        enableEatingChat = true,
        onlyGuildGroup = false,
        spellIDs = {
            [192002] = true, -- Food/Drink
            [185710] = true, -- Food/Drink
            [462175] = true, -- Food/Drink
            [450770] = true, -- Food/Drink
        },
        trackedItems = {
            [211880] = true, -- Algari Mana Oil (Example)
        },
    },
}

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BotaToolsDB", defaults, true)

    -- Register configuration options (deferred until after DB init)
    self:SetupOptions()

    -- Register slash commands
    local openConfig = function()
        AceConfigDialog:Open(addonName)
    end
    self:RegisterChatCommand("botatools", openConfig)
    self:RegisterChatCommand("bota", openConfig)
end

function addon:SetupOptions()
    local options = {
        name = "BotaTools",
        handler = addon,
        type = "group",
        childGroups = "tab",
        args = {}
    }

    -- Merge options from modules as top-level tabs
    for name, module in self:IterateModules() do
        if module.GetOptions then
            options.args[name] = module:GetOptions()
        end
    end

    self.options = options

    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, "BotaTools")

    -- Initialize module UIs
    for name, module in self:IterateModules() do
        -- Support generic refresh
        if module.Refresh then module:Refresh() end
    end
end
