local _, BOTA = ...

SLASH_BOTA1 = "/bota"
SLASH_BOTA2 = "/botatools"

SlashCmdList["BOTA"] = function(msg, editbox)
    BOTA:ToggleOptions()
end    