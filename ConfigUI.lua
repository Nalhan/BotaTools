local _, BOTA = ...
local DF = _G["DetailsFramework"]

BOTA.ConfigUI = {}

-- Window dimensions
local window_width = 1000
local window_height = 600
local header_offset = 100

-- Templates
local options_text_template = DF:GetTemplate("font", "OPTIONS_FONT_TEMPLATE")
local options_dropdown_template = DF:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
local options_switch_template = DF:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")
local options_slider_template = DF:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE")
local options_button_template = DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")

-- Tabs configuration
local TABS_LIST = {
    { name = "Eating",      text = "Eating" },
    { name = "Consumables", text = "Consumables" },
    { name = "Currencies",  text = "Currencies" },
    { name = "Enchants",    text = "Enchants" },
}

local BaseFrame

function BOTA.ConfigUI:Init()
    -- Initialize saved vars table if needed
    if not BOTASV then BOTASV = {} end

    local panel_options = {
        UseStatusBar = true,
        scale = 1.0,
    }
    BOTASV.UI = BOTASV.UI or panel_options

    -- Create BaseFrame
    BaseFrame = DF:CreateSimplePanel(UIParent, window_width, window_height, "|cFF00FFFFBota|rTools", "BOTAMainFrame",
        BOTASV.UI)
    BaseFrame:SetPoint("CENTER")
    BaseFrame:SetFrameStrata("HIGH")
    DF:BuildStatusbarAuthorInfo(BaseFrame.StatusBar, _, "bota")
    DF:CreateScaleBar(BaseFrame, BOTASV.UI)
    BaseFrame:SetScale(BOTASV.UI.scale or 1.0)
    BaseFrame:Hide()

    -- Create the tab container
    local tabContainer = DF:CreateTabContainer(BaseFrame, "BotaTools", "BOTA_TabsTemplate", TABS_LIST, {
        width = window_width - 10,
        height = window_height - 50,
        backdrop_color = { 0, 0, 0, 0.2 },
        backdrop_border_color = { 0.1, 0.1, 0.1, 0.4 }
    })
    tabContainer:SetPoint("TOPLEFT", BaseFrame, "TOPLEFT", 5, -25)

    -- Get tab frames
    local eating_tab = tabContainer:GetTabFrameByName("Eating")
    local consumables_tab = tabContainer:GetTabFrameByName("Consumables")
    local currencies_tab = tabContainer:GetTabFrameByName("Currencies")
    local enchants_tab = tabContainer:GetTabFrameByName("Enchants")

    -- Mapping table after frames are created
    local tabFrameMapping = {
        [1] = eating_tab,
        [2] = consumables_tab,
        [3] = currencies_tab,
        [4] = enchants_tab,
    }

    -- Set the hook after container is created
    tabContainer.hookList.OnSelectIndex = function(container, tabButton)
        local index = container.CurrentIndex
        local tabFrame = tabFrameMapping[index]
        local tabName = TABS_LIST[index].name

        if tabName == "Eating" and BOTA.Eating.OnTabShown then
            BOTA.Eating:OnTabShown(tabFrame)
        elseif tabName == "Consumables" and BOTA.Consumables.OnTabShown then
            BOTA.Consumables:OnTabShown(tabFrame)
        elseif tabName == "Currencies" and BOTA.Currencies.OnTabShown then
            BOTA.Currencies:OnTabShown(tabFrame)
        elseif tabName == "Enchants" and BOTA.Enchants.OnTabShown then
            BOTA.Enchants:OnTabShown(tabFrame)
        end
    end

    -- Build options tables from modules
    local eating_options = BOTA.Eating:BuildOptions()
    local consumables_options = BOTA.Consumables:BuildOptions()
    local currencies_options = BOTA.Currencies:BuildOptions()
    local enchants_options = BOTA.Enchants:BuildOptions()

    -- Build callbacks
    local eating_callback = BOTA.Eating:BuildCallback()
    local consumables_callback = BOTA.Consumables:BuildCallback()
    local currencies_callback = BOTA.Currencies:BuildCallback()
    local enchants_callback = BOTA.Enchants:BuildCallback()

    -- Build options menu for each tab
    DF:BuildMenu(eating_tab, eating_options, 10, -header_offset, window_height - header_offset, false,
        options_text_template, options_dropdown_template, options_switch_template, true,
        options_slider_template, options_button_template, eating_callback, { width = 300 })

    DF:BuildMenu(consumables_tab, consumables_options, 10, -header_offset, window_height - header_offset, false,
        options_text_template, options_dropdown_template, options_switch_template, true,
        options_slider_template, options_button_template, consumables_callback, { width = 300 })

    DF:BuildMenu(currencies_tab, currencies_options, 10, -header_offset, window_height - header_offset, false,
        options_text_template, options_dropdown_template, options_switch_template, true,
        options_slider_template, options_button_template, currencies_callback, { width = 300 })

    DF:BuildMenu(enchants_tab, enchants_options, 10, -header_offset, window_height - header_offset, false,
        options_text_template, options_dropdown_template, options_switch_template, true,
        options_slider_template, options_button_template, enchants_callback, { width = 300 })

    -- Initial call for first tab
    if tabContainer.hookList.OnSelectIndex then
        tabContainer.hookList.OnSelectIndex(tabContainer)
    end

    -- Store references
    self.tabContainer = tabContainer
    self.BaseFrame = BaseFrame
end

function BOTA.ConfigUI:Toggle()
    if not BaseFrame then return end -- Should happen after Init

    if BaseFrame:IsShown() then
        BaseFrame:Hide()
    else
        BaseFrame:Show()
    end
end
