local _, BOTA = ...

SLASH_BOTA1 = "/bota"
SLASH_BOTA2 = "/botatools"

SlashCmdList["BOTA"] = function(msg, editbox)
    local command, rest = msg:match("^(%S*)%s*(.-)$")
    command = command and command:lower() or ""

    if command == "dump" then
        if BOTA.Debug and BOTA.Debug.DumpTooltipData then
            BOTA.Debug:DumpTooltipData(rest)
        else
            print("|cffff7d0aBotaTools|r: Debug module not loaded.")
        end
        return
    elseif command == "debug" then
        BOTA.DebugMode = not BOTA.DebugMode
        print("|cFF00FFFFBotaTools|r: Debug Mode " ..
            (BOTA.DebugMode and "|cff00ff00Enabled|r" or "|cffff0000Disabled|r"))
        return
    elseif command == "reset" then
        if BOTA.Eating and BOTA.Eating.ResetDefaults then BOTA.Eating:ResetDefaults() end
        if BOTA.Consumables and BOTA.Consumables.ResetDefaults then BOTA.Consumables:ResetDefaults() end
        if BOTA.Currencies and BOTA.Currencies.ResetDefaults then BOTA.Currencies:ResetDefaults() end

        print("|cFF00FFFFBotaTools|r: All settings have been reset to default.")
        return
    elseif command == "changelog" then
        if BOTA.Changelog and BOTA.Changelog.Show then
            BOTA.Changelog:Show()
        end
        return
    end

    -- Default to opening config
    BOTA.ConfigUI:Toggle()
end
