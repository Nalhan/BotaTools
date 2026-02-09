local _, BOTA = ...

-- Initialize module namespace
BOTA.DebugMode = false

local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LDB and LibStub("LibDBIcon-1.0")

function BOTA:DebugLog(msg)
    if self.DebugMode then
        print("|cFFD90B4FBotaTools DEBUG|r: " .. tostring(msg))
    end
end

function BOTA:LDBInit()
    if LDB then
        local databroker = LDB:NewDataObject("BotaTools", {
            type = "launcher",
            label = "BotaTools",
            icon = [[Interface\Icons\INV_Misc_Food_15]],
            showInCompartment = true,
            OnClick = function(self, button)
                if button == "LeftButton" then
                    BOTA.ConfigUI:Toggle()
                end
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine("|cFF00FFFFBota|rTools", 0, 1, 1)
                tooltip:AddLine("|cFFCFCFCFLeft click|r: Show/Hide Options Window")
            end
        })

        if not BOTASV then BOTASV = {} end
        BOTASV.Minimap = BOTASV.Minimap or { hide = false }

        if databroker and not LDBIcon:IsRegistered("BotaTools") then
            LDBIcon:Register("BotaTools", databroker, BOTASV.Minimap)
            LDBIcon:AddButtonToCompartment("BotaTools")
        end

        self.databroker = databroker
    end
end

function BOTA:Init()
    -- Initialize saved variables
    if not BOTASV then
        BOTASV = {}
    end

    -- Initialize modules
    if BOTA.Eating and BOTA.Eating.Enable then BOTA.Eating:Enable() end
    if BOTA.Consumables and BOTA.Consumables.Enable then BOTA.Consumables:Enable() end
    if BOTA.Currencies and BOTA.Currencies.Enable then BOTA.Currencies:Enable() end
    if BOTA.Enchants and BOTA.Enchants.Enable then BOTA.Enchants:Enable() end
    if BOTA.Changelog and BOTA.Changelog.Init then BOTA.Changelog:Init() end

    -- Initialize the config UI
    if BOTA.ConfigUI and BOTA.ConfigUI.Init then
        BOTA.ConfigUI:Init()
    end

    -- Initialize minimap icon
    BOTA:LDBInit()

    print("|cFF00FFFFBota|rTools loaded. Type /bota to open settings.")
end

-- Initialize when addon is fully loaded
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "BotaTools" then
        BOTA:Init()
        self:UnregisterEvent("ADDON_LOADED")
    end
end)
