local _, BOTA = ...
local DF = _G["DetailsFramework"]

-- Initialize module namespace
BOTA.Eating = BOTA.Eating or {}



-- Local state
local isEating = false
local cachedIsGuildGroup = false

-- Default settings
local defaults = {
    enableEatingChat = true,
    onlyGuildGroup = false,
    spellIDs = {
        -- match by name these buffs by default
        ["Well Fed"] = true,
        ["Food"] = true,
        ["Food & Drink"] = true,
    },
}

-- Initialize saved variables for this module
function BOTA.Eating:InitSavedVars()
    if not BOTASV then BOTASV = {} end
    if not BOTASV.Eating then
        BOTASV.Eating = CopyTable(defaults)
    end
    -- Ensure spellIDs table exists
    if not BOTASV.Eating.spellIDs then
        BOTASV.Eating.spellIDs = CopyTable(defaults.spellIDs)
    end
end

function BOTA.Eating:ResetDefaults()
    BOTASV.Eating = CopyTable(defaults)
    if self.managementList then
        self.managementList:Refresh()
    end
end

-- Helper to check if the group constitutes a "Guild Group"
function BOTA.Eating:UpdateGuildGroupCache()
    local guildName, _, _, _ = GetGuildInfo("player")
    if not guildName then
        cachedIsGuildGroup = false
        return
    end

    local prefix = IsInRaid() and "raid" or "party"
    local count = GetNumGroupMembers()

    if count <= 1 then
        cachedIsGuildGroup = false
        return
    end -- Solo is not a group

    local guildCount = 1
    for i = 1, count - 1 do
        if GetGuildInfo(prefix .. i) == guildName then
            guildCount = guildCount + 1
        end
    end

    cachedIsGuildGroup = guildCount >= (count * 0.8)

    BOTA:DebugLog("Guild group cache updated: " ..
        guildCount .. "/" .. count .. " (" .. (cachedIsGuildGroup and "Guild Group" or "Not a Guild Group") .. ")")
end

function BOTA.Eating:IsGuildGroup()
    return cachedIsGuildGroup
end

function BOTA.Eating:SayRandomLine()
    local lines = BOTA.OfficialLines or {}
    if #lines == 0 then return end

    -- Guard against combat or messaging lockdown
    if InCombatLockdown() or not IsInInstance() then
        if not IsInInstance() then
            BOTA:DebugLog("Eating chat suppressed: SAY is blocked outside of instances.")
        else
            BOTA:DebugLog("Eating chat suppressed: In combat or messaging lockdown.")
        end
        return
    end

    -- Guild Group Check
    if BOTASV.Eating.onlyGuildGroup then
        if not self:IsGuildGroup() then
            return -- Silently fail if not in a guild group
        end
    end

    -- Filter lines by weight
    local weightedPool = {}
    for _, line in ipairs(lines) do
        local weight = line.weight or 10
        for i = 1, weight do
            table.insert(weightedPool, line)
        end
    end

    if #weightedPool > 0 then
        local randomLine = weightedPool[math.random(#weightedPool)]
        SendChatMessage(randomLine.text, "SAY")
    end
end

function BOTA.Eating:OnUnitAura(unit)
    if unit ~= "player" or InCombatLockdown() then return end

    local hasFood = false

    -- Check for buffs acting as food triggers
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end

        if BOTASV.Eating.spellIDs[aura.spellId] or BOTASV.Eating.spellIDs[aura.name] then
            hasFood = true
            break
        end
    end

    if hasFood and not isEating then
        isEating = true
        if BOTASV.Eating.enableEatingChat then
            self:SayRandomLine()
        end
    elseif not hasFood and isEating then
        isEating = false
    end
end

function BOTA.Eating:Enable()
    self:InitSavedVars()

    -- Register for events
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_AURA")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")

    frame:SetScript("OnEvent", function(_, event, unit)
        if event == "UNIT_AURA" then
            BOTA.Eating:OnUnitAura(unit)
        elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
            BOTA.Eating:UpdateGuildGroupCache()
        end
    end)
    self.eventFrame = frame

    -- Initial cache update
    self:UpdateGuildGroupCache()
end

function BOTA.Eating:GetWeightColor(weight)
    if not weight then return "ffffff" end
    if weight == 100 then
        return "e5cc80" -- Heirloom
    elseif weight == 99 then
        return "e268a8" -- Artifact
    elseif weight >= 95 then
        return "ff8000" -- Legendary
    elseif weight >= 75 then
        return "a335ee" -- Epic
    elseif weight >= 50 then
        return "0070ff" -- Rare
    elseif weight >= 25 then
        return "1eff00" -- Uncommon
    else
        return "666666" -- Poor
    end
end

---------------------------------------------------------------------------
-- UI Options for LibDFramework
---------------------------------------------------------------------------

function BOTA.Eating:BuildOptions()
    local addSpellInput = ""

    return {
        -- Settings Section Header
        {
            type = "label",
            get = function() return "Eating Meme Settings" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
        },

        -- Enable Eating Chat Toggle
        {
            type = "toggle",
            boxfirst = true,
            name = "Enable Eating Chat",
            desc = "Say a random line when you start eating.",
            get = function() return BOTASV.Eating.enableEatingChat end,
            set = function(self, fixedparam, value)
                BOTASV.Eating.enableEatingChat = value
            end,
        },

        -- Only Guild Group Toggle
        {
            type = "toggle",
            boxfirst = true,
            name = "Only in Guild Group",
            desc = "Only say a line if you are in a group with other guild members.",
            get = function() return BOTASV.Eating.onlyGuildGroup end,
            set = function(self, fixedparam, value)
                BOTASV.Eating.onlyGuildGroup = value
            end,
            spacement = true, -- Add extra vertical space after this
        },

        -- Spell Triggers Section Header
        {
            type = "label",
            get = function() return "Aura Triggers" end,
            text_template = DF:GetTemplate("font", "ORANGE_FONT_TEMPLATE"),
            spacement = true,
            id = "AuraTriggersLabel",
        },
    }
end

function BOTA.Eating:BuildCallback()
    return function()
        -- Callback when menu is refreshed/closed
    end
end

function BOTA.Eating:CreateTable(parent)
    if self.tableFrame then
        self.tableFrame:SetParent(parent)
        self.tableFrame:Show()
        return self.tableFrame
    end

    local container = BOTA:CreateTabContainer(parent, "BotaEatingLinesContainer")

    local headers = {
        { name = "Meme Line", width = container:GetWidth() - 80 },
        { name = "Weight",    width = 60 },
    }

    local headerFrame = container.headerFrame

    local x = 0
    for _, h in ipairs(headers) do
        local label = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("LEFT", headerFrame, "LEFT", x + 5, 0)
        label:SetText(h.name)
        label:SetTextColor(1, 0.8, 0, 1)
        x = x + h.width
    end

    -- Row Creation
    local createLineFunc = function(self, index)
        local parentFrame = self.widget or self
        local line = CreateFrame("Frame", "$parentLine" .. index, parentFrame)
        line:SetSize(self:GetWidth(), 24)
        line:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, -((index - 1) * 24))
        line:SetFrameLevel(parentFrame:GetFrameLevel() + 20)

        local bg = line:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.2)
        line.bg = bg

        local text = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetPoint("LEFT", 5, 0)
        text:SetWidth(headers[1].width)
        text:SetJustifyH("LEFT")
        line.text = text

        local weight = line:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        weight:SetPoint("LEFT", headers[1].width + 5, 0)
        weight:SetWidth(headers[2].width)
        weight:SetJustifyH("CENTER")
        line.weightText = weight

        return line
    end

    -- Refresh Logic
    local refreshFunc = function(self, data, offset, totalLines)
        for i = 1, totalLines do
            local index = i + offset
            local lineData = data[index]
            local line = self:GetLine(i)
            if lineData then
                line:Show()
                line.text:SetText(lineData.text)
                line.weightText:SetText(lineData.weight or 10)

                local color = BOTA.Eating:GetWeightColor(lineData.weight)
                line.text:SetTextColor(tonumber(color:sub(1, 2), 16) / 255, tonumber(color:sub(3, 4), 16) / 255,
                    tonumber(color:sub(5, 6), 16) / 255)

                if index % 2 == 0 then line.bg:Show() else line.bg:Hide() end
            else
                line:Hide()
            end
        end
    end

    local scrollBox = DF:CreateScrollBox(container, "$parentScrollBox", refreshFunc, {}, container:GetWidth() - 25,
        container:GetHeight() - 30, 16, 24)
    scrollBox:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -30)
    DF:ReskinSlider(scrollBox)

    for i = 1, 16 do
        scrollBox:CreateLine(createLineFunc)
    end

    container.scrollBox = scrollBox
    scrollBox:SetFrameLevel(container:GetFrameLevel() + 5)
    scrollBox:Show()

    self.tableFrame = container
    container:Show()
    return container
end

function BOTA.Eating:RefreshTable()
    if self.tableFrame and self.tableFrame.scrollBox then
        local data = BOTA.OfficialLines or {}
        self.tableFrame.scrollBox:SetData(data)
        self.tableFrame.scrollBox:Refresh()
    end
end

function BOTA.Eating:OnTabShown(tabFrame)
    self:CreateTable(tabFrame)
    self:RefreshTable()

    -- Create Management List
    if not self.managementList then
        -- Add ID Section (directly above list)
        local addIDLabel = tabFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        local header = tabFrame.widgetids and tabFrame.widgetids["AuraTriggersLabel"]
        if header then
            addIDLabel:SetPoint("TOPLEFT", header.widget or header, "BOTTOMLEFT", 0, -10)
        else
            addIDLabel:SetPoint("TOPLEFT", tabFrame, "TOPLEFT", 10, -190)
        end
        addIDLabel:SetText("Add Aura (Name or ID):")

        local addIDEntry = DF:CreateTextEntry(tabFrame, function() end, 140, 20, "AddAuraEntry", nil, nil,
            DF:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE"))
        addIDEntry:SetPoint("LEFT", addIDLabel, "RIGHT", 5, 0)

        local funcAddAura = function()
            local value = addIDEntry:GetText():trim()
            if value == "" then return end

            local id = tonumber(value)
            if id then
                BOTASV.Eating.spellIDs[id] = true
                local spellInfo = C_Spell.GetSpellInfo(id)
                local name = spellInfo and spellInfo.name or tostring(id)
                print("|cFFD90B4FBotaTools|r: Added spell ID trigger: " .. name .. " (" .. id .. ")")
            else
                -- Treat as name
                BOTASV.Eating.spellIDs[value] = true
                print("|cFFD90B4FBotaTools|r: Added aura name trigger: " .. value)
            end
            addIDEntry:SetText("")
            self.managementList:Refresh()
        end

        addIDEntry:SetHook("OnEnterPressed", funcAddAura)

        local addButton = DF:CreateButton(tabFrame, funcAddAura, 20, 20)
        addButton:SetPoint("LEFT", addIDEntry, "RIGHT", 4, 0)
        addButton:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
        addButton:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
        addButton:SetHighlightTexture("Interface\\Buttons\\UI-PlusButton-Hilight")

        local callbacks = {
            OnRemove = function(index)
                if self.displayList and self.displayList[index] then
                    local id = self.displayList[index]
                    BOTASV.Eating.spellIDs[id] = nil
                    print("|cFFD90B4FBotaTools|r: Removed spell trigger ID: " .. id)

                    self.managementList:Refresh()
                end
            end,
            -- No OnMoveUp/Down for Eating
        }

        -- Proxy for displayList since we generate it on fly or cache it
        self.displayList = {}

        -- Custom Refresh on the frame to rebuild the list
        local originalCreate = BOTA.CreateManagementList
        -- Actually, BOTA:CreateManagementList returns a frame with a .scrollBox
        -- We can just pass a table that we update before calling refresh.

        local config = {
            width = 280,
            rowHeight = 24,
            topAnchor = addIDLabel,
            alignToBottom = self.tableFrame,
            nameProvider = function(id)
                if type(id) == "number" then
                    local info = C_Spell.GetSpellInfo(id)
                    return (info and info.name or "Unknown") .. " (" .. id .. ")"
                else
                    return id
                end
            end,
            iconProvider = function(id)
                if type(id) == "number" then
                    local info = C_Spell.GetSpellInfo(id)
                    return info and info.iconID
                end
                return nil
            end
        }

        self.managementList = BOTA:CreateManagementList(tabFrame, self.displayList, callbacks, config)

        -- Hook Refresh to update displayList
        local oldRefresh = self.managementList.Refresh
        self.managementList.Refresh = function(f)
            wipe(self.displayList)
            for id in pairs(BOTASV.Eating.spellIDs or {}) do
                table.insert(self.displayList, id)
            end
            table.sort(self.displayList, function(a, b)
                if type(a) ~= type(b) then
                    return type(a) < type(b)
                end
                return a < b
            end)
            oldRefresh(f)
        end

        self.managementList:Refresh()
    else
        self.managementList:Refresh()
    end
end
