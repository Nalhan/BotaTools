local _, BOTA = ...
local DF = _G["DetailsFramework"]


-- init base panel
local base_width = 1000
local base_height = 600

local base_frame = DF:CreateSimplePanel(UIParent, base_width, base_height, "|cFF00FFFFBota|r Tools", "BOTA",
    {
        UseStatusBar = true
    })
base_frame:SetPoint("CENTER")
base_frame:SetFrameStrata("HIGH")
DF:BuildStatusbarAuthorInfo(base_frame.StatusBar, _, "x |cFF00FFFFBota|r")
DF:CreateScaleBar(base_frame, BOTASV.ConfigUI)
base_frame:SetScale(BOTASV.ConfigUI.Scale)

BOTA.ConfigUI = {}
BOTA.ConfigUI.BaseFrame = base_frame
