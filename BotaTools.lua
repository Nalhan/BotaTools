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
local addon = AceAddon:NewAddon(addonName, "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceSerializer-3.0")
addon.name = addonName

-- Addon state for UI optimization
addon.searchFilter = ""
addon.currentPage = 1
addon.pageSize = 15 -- Smaller page size for faster redraws

-- Default settings
local defaults = {
    profile = {
        eatingLines = {
            { text = "Om nom nom...",        weight = 10 },
            { text = "Tastes like chicken!", weight = 10 },
        },
        enableEatingChat = true,
        onlyGuildGroup = false,
        spellIDs = {
            [192002] = true, -- Food/Drink
            [185710] = true, -- Food/Drink
            [462175] = true, -- Food/Drink
            [450770] = true, -- Food/Drink
        },
    },
}

function addon:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("BotaToolsDB", defaults, true)

    -- DATA MIGRATION: Convert string-based lines to object-based lines
    for i, line in ipairs(self.db.profile.eatingLines) do
        if type(line) == "string" then
            self.db.profile.eatingLines[i] = { text = line, weight = 10 }
        end
    end

    -- Register configuration options (deferred until after DB init)
    self:SetupOptions()

    -- Initial import of official lines
    self:ImportOfficialLines(true) -- silentIfNone = true

    -- Register slash commands
    local openConfig = function()
        AceConfigDialog:Open(addonName)
    end
    self:RegisterChatCommand("botatools", openConfig)
    self:RegisterChatCommand("bota", openConfig)
end

function addon:ImportOfficialLines(silentIfNone)
    if not addonTable.OfficialLines then
        if not silentIfNone then
            self:Print("Error: Official lines data not found.")
        end
        return
    end

    local importedCount = 0
    for _, officialLine in ipairs(addonTable.OfficialLines) do
        -- Check if text already exists to avoid duplicates
        local exists = false
        for _, existingLine in ipairs(self.db.profile.eatingLines) do
            if existingLine.text == officialLine.text then
                exists = true
                break
            end
        end

        if not exists then
            table.insert(self.db.profile.eatingLines, {
                text = officialLine.text,
                weight = officialLine.weight or 10
            })
            importedCount = importedCount + 1
        end
    end

    if importedCount > 0 then
        self:Print(string.format("Imported %d new official lines.", importedCount))
        self:RefreshLineList()
        AceConfigRegistry:NotifyChange(addonName)
    elseif not silentIfNone then
        self:Print("No new official lines to import.")
    end
end

function addon:SetupOptions()
    local options = {
        name = "BotaTools",
        handler = addon,
        type = "group",
        childGroups = "tab",
        args = {
            desc = {
                name = "BotaTools Configuration",
                type = "description",
                order = 0,
            },
            collection = {
                name = "Meme Collection",
                type = "group",
                order = 1,
                args = {
                    enableEatingChat = {
                        name = "Enable Eating Chat",
                        desc = "Say a random line when you start eating.",
                        type = "toggle",
                        set = function(info, val) self.db.profile.enableEatingChat = val end,
                        get = function(info) return self.db.profile.enableEatingChat end,
                        order = 1,
                    },
                    onlyGuildGroup = {
                        name = "Only in Guild Group",
                        desc = "Only say a line if you are in a group with other guild members.",
                        type = "toggle",
                        set = function(info, val) self.db.profile.onlyGuildGroup = val end,
                        get = function(info) return self.db.profile.onlyGuildGroup end,
                        order = 1.5,
                    },
                    importOfficial = {
                        name = "Import Official Lines",
                        desc = "Import the latest set of official eating lines from Data.lua.",
                        type = "execute",
                        func = function() self:ImportOfficialLines() end,
                        order = 2,
                    },
                    addLine = {
                        name = "Add New Line",
                        desc = "Enter a new text line to add to the collection.",
                        type = "input",
                        width = "full",
                        multiline = true,
                        set = function(info, val)
                            if val and val:trim() ~= "" then
                                table.insert(self.db.profile.eatingLines, { text = val:trim(), weight = 10 })
                                self:Print("Added line: " .. val:trim())
                                self:RefreshLineList()
                                AceConfigRegistry:NotifyChange(addonName)
                            end
                        end,
                        order = 3,
                    },
                    searchMemes = {
                        name = "Search Memes",
                        desc = "Filter the meme list by text.",
                        type = "input",
                        order = 4,
                        width = "double",
                        get = function() return addon.searchFilter end,
                        set = function(info, val)
                            addon.searchFilter = val:lower()
                            addon.currentPage = 1 -- Reset to page 1 on search
                            self:RefreshLineList()
                            AceConfigRegistry:NotifyChange(addonName)
                        end,
                    },
                    paginationHeader = {
                        name = "Pagination",
                        type = "header",
                        order = 5,
                    },
                    prevPage = {
                        name = "Previous",
                        type = "execute",
                        order = 6,
                        width = "half",
                        func = function()
                            addon.currentPage = math.max(1, addon.currentPage - 1)
                            self:RefreshLineList()
                            AceConfigRegistry:NotifyChange(addonName)
                        end,
                        disabled = function() return addon.currentPage <= 1 end,
                    },
                    jumpPage = {
                        name = "Jump to Page",
                        type = "select",
                        order = 7,
                        width = "normal",
                        values = function()
                            local filtered = {}
                            local search = addon.searchFilter
                            for _, line in ipairs(self.db.profile.eatingLines) do
                                if search == "" or line.text:lower():find(search, 1, true) then
                                    table.insert(filtered, line)
                                end
                            end
                            local totalPages = math.max(1, math.ceil(#filtered / addon.pageSize))
                            local vals = {}
                            for i = 1, totalPages do
                                vals[i] = "Page " .. i
                            end
                            return vals
                        end,
                        get = function() return addon.currentPage end,
                        set = function(info, val)
                            addon.currentPage = val
                            self:RefreshLineList()
                            AceConfigRegistry:NotifyChange(addonName)
                        end,
                    },
                    nextPage = {
                        name = "Next",
                        type = "execute",
                        order = 8,
                        width = "half",
                        func = function()
                            local filtered = {}
                            local search = addon.searchFilter
                            for _, line in ipairs(self.db.profile.eatingLines) do
                                if search == "" or line.text:lower():find(search, 1, true) then
                                    table.insert(filtered, line)
                                end
                            end
                            local totalPages = math.max(1, math.ceil(#filtered / addon.pageSize))
                            addon.currentPage = math.min(totalPages, addon.currentPage + 1)
                            self:RefreshLineList()
                            AceConfigRegistry:NotifyChange(addonName)
                        end,
                        disabled = function()
                            local filteredCount = 0
                            local search = addon.searchFilter
                            for _, line in ipairs(self.db.profile.eatingLines) do
                                if search == "" or line.text:lower():find(search, 1, true) then
                                    filteredCount = filteredCount + 1
                                end
                            end
                            local totalPages = math.max(1, math.ceil(filteredCount / addon.pageSize))
                            return addon.currentPage >= totalPages
                        end,
                    },
                    pageStatus = {
                        name = function()
                            local filteredCount = 0
                            local search = addon.searchFilter
                            for _, line in ipairs(self.db.profile.eatingLines) do
                                if search == "" or line.text:lower():find(search, 1, true) then
                                    filteredCount = filteredCount + 1
                                end
                            end
                            local totalPages = math.max(1, math.ceil(filteredCount / addon.pageSize))
                            return string.format("|cffffff00Page %d of %d|r (%d lines total)", addon.currentPage,
                                totalPages, filteredCount)
                        end,
                        type = "description",
                        order = 9,
                        width = "full",
                    },
                    lineList = {
                        name = "Eating Lines",
                        type = "group",
                        inline = true,
                        order = 10,
                        args = {},
                    },
                }
            },
            triggers = {
                name = "Spell Triggers",
                type = "group",
                order = 2,
                args = {
                    addSpell = {
                        name = "Add New Spell ID",
                        desc = "Enter a spell ID or drop a spell/item link here to add a trigger.",
                        type = "input",
                        set = function(info, val)
                            -- Extract ID from link or raw input
                            local idString = val:match("spell:(%d+)") or val:match("item:(%d+)") or val:match("(%d+)")
                            if idString then
                                local id = tonumber(idString)
                                -- If it's an item link, try to find the associated spell ID
                                if id and val:match("item:") then
                                    local itemSpell = C_Item.GetItemSpell(id)
                                    if itemSpell then
                                        id = itemSpell
                                    end
                                end

                                if id then
                                    self.db.profile.spellIDs[id] = true
                                    self:Print("Added spell ID trigger: " .. tostring(id))
                                    self:RefreshSpellList()
                                    AceConfigRegistry:NotifyChange(addonName)
                                end
                            end
                        end,
                        order = 1,
                    },
                    spellList = {
                        name = "Spell ID Triggers",
                        type = "group",
                        inline = true,
                        order = 2,
                        args = {},
                    }
                }
            }
        },
    }

    self.options = options

    -- Initial refresh
    self:RefreshLineList()
    self:RefreshSpellList()

    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, "BotaTools")
end

-- Dynamically populate the list of lines with optimization
function addon:RefreshLineList()
    if not self.options then return end

    local lines = self.db.profile.eatingLines
    local filtered = {}
    local search = addon.searchFilter

    -- 1. Filter
    for i, lineObj in ipairs(lines) do
        if search == "" or lineObj.text:lower():find(search, 1, true) then
            -- Keep track of original index for deletion
            table.insert(filtered, { obj = lineObj, originalIndex = i })
        end
    end

    -- 2. Paginate
    local pageSize = addon.pageSize
    local totalPages = math.max(1, math.ceil(#filtered / pageSize))
    if addon.currentPage > totalPages then addon.currentPage = totalPages end

    local startIndex = (addon.currentPage - 1) * pageSize + 1
    local endIndex = math.min(startIndex + pageSize - 1, #filtered)

    -- 3. Render Slice
    self.options.args.collection.args.lineList.args = {}
    for i = startIndex, endIndex do
        local entry = filtered[i]
        local lineObj = entry.obj
        local originalIndex = entry.originalIndex

        self.options.args.collection.args.lineList.args["group" .. originalIndex] = {
            type = "group",
            name = "",
            inline = true,
            order = i,
            args = {
                line = {
                    name = lineObj.text,
                    type = "description",
                    order = 1,
                    width = 2.1,
                },
                actions = {
                    type = "group",
                    name = "",
                    inline = true,
                    order = 2,
                    width = 0.9,
                    args = {
                        weight = {
                            name = "Weight",
                            desc = "How likely this line is to be selected (1-100).",
                            type = "input",
                            width = 0.6,
                            get = function(info) return tostring(lineObj.weight) end,
                            set = function(info, val)
                                local n = tonumber(val)
                                if n then
                                    lineObj.weight = math.max(1, math.min(100, n))
                                end
                                AceConfigRegistry:NotifyChange(addonName)
                            end,
                            order = 1,
                        },
                        delete = {
                            name = "Delete",
                            type = "execute",
                            image = "Interface\\RaidFrame\\ReadyCheck-NotReady",
                            imageWidth = 20,
                            imageHeight = 20,
                            func = function()
                                table.remove(self.db.profile.eatingLines, originalIndex)
                                self:RefreshLineList()
                                AceConfigRegistry:NotifyChange(addonName)
                            end,
                            order = 2,
                            width = 0.3,
                        },
                    },
                }
            },
        }
    end
end

-- Dynamically populate the list of spell IDs
function addon:RefreshSpellList()
    if not self.options then return end
    self.options.args.triggers.args.spellList.args = {}
    local i = 0
    for spellId in pairs(self.db.profile.spellIDs) do
        i = i + 1
        local currentSpellId = spellId -- local copy for closure

        -- Fetch spell info for display
        local spellInfo = C_Spell.GetSpellInfo(currentSpellId)
        local name = (spellInfo and spellInfo.name) or ("Unknown (" .. currentSpellId .. ")")
        local icon = (spellInfo and spellInfo.iconID) or 134400 -- Question mark icon

        self.options.args.triggers.args.spellList.args["spell" .. currentSpellId] = {
            name = name,
            desc = "Spell ID: " .. currentSpellId,
            type = "description",
            image = icon,
            imageWidth = 24,
            imageHeight = 24,
            order = i * 10,
            width = "double",
        }
        self.options.args.triggers.args.spellList.args["deleteSpell" .. currentSpellId] = {
            name = "Delete",
            type = "execute",
            func = function()
                self.db.profile.spellIDs[currentSpellId] = nil
                self:RefreshSpellList()
                AceConfigRegistry:NotifyChange(addonName)
            end,
            order = i * 10 + 1,
            width = "half",
        }
    end
end

function addon:OnEnable()
    self:RegisterEvent("UNIT_AURA")
    self:RegisterComm("BotaTools", "OnCommReceived")
end

function addon:OnDisable()
    -- Disable addon features
end

-- --- Core Logic ---

local isEating = false

-- Helper to check if the group constitutes a "Guild Group"
-- Returns true if the player is in a guild and there is at least one other guild member in the group.
function addon:IsGuildGroup()
    local guildName = GetGuildInfo("player")
    if not guildName then return false end

    local prefix = IsInRaid() and "raid" or "party"
    local count = GetNumGroupMembers()

    if count <= 1 then return false end -- Solo is not a group

    for i = 1, count - 1 do
        local unit = prefix .. i
        if unit ~= "player" then -- Should be redundant but safe
            local unitGuild = GetGuildInfo(unit)
            if unitGuild == guildName then
                return true
            end
        end
    end
    return false
end

function addon:UNIT_AURA(event, unit)
    if unit ~= "player" or InCombatLockdown() then return end

    local hasFood = false

    -- Check for buffs acting as food
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end

        -- Match by spell ID as requested
        if self.db.profile.spellIDs[aura.spellId] then
            hasFood = true
            break
        end
    end

    if hasFood and not isEating then
        isEating = true
        if self.db.profile.enableEatingChat then
            self:SayRandomLine()
        end
    elseif not hasFood and isEating then
        isEating = false
    end
end

function addon:SayRandomLine()
    local lines = self.db.profile.eatingLines
    if #lines == 0 then return end

    -- Guard against combat or messaging lockdown in Midnight
    -- Also guard against open-world SAY protection (only allowed in instances)
    if InCombatLockdown() or (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) or not IsInInstance() then
        if not IsInInstance() then
            self:Print("Eating chat suppressed: SAY is blocked outside of instances.")
        else
            self:Print("Eating chat suppressed: In combat or messaging lockdown.")
        end
        return
    end

    -- Guild Group Check
    if self.db.profile.onlyGuildGroup then
        if not self:IsGuildGroup() then
            return -- Silently fail if not in a guild group
        end
    end

    -- WEIGHTED SELECTION LOGIC
    local totalWeight = 0
    for _, lineObj in ipairs(lines) do
        totalWeight = totalWeight + (lineObj.weight or 10)
    end

    local roll = math.random(totalWeight)
    local currentSum = 0
    local selectedText = "..."

    for _, lineObj in ipairs(lines) do
        currentSum = currentSum + (lineObj.weight or 10)
        if roll <= currentSum then
            selectedText = lineObj.text
            break
        end
    end

    -- Midnight API: C_ChatInfo.SendChatMessage
    if C_ChatInfo and C_ChatInfo.SendChatMessage then
        C_ChatInfo.SendChatMessage(selectedText, "SAY")
    else
        -- Fallback for legacy/other versions
        SendChatMessage(selectedText, "SAY")
    end
end

-- --- Sharing Logic ---

function addon:ShareLine(lineObj)
    if not (GetGuildInfo("player")) then
        self:Print("Cannot share: Not in a guild.")
        return
    end

    local data = self:Serialize(lineObj)
    self:SendCommMessage("BotaTools", data, "GUILD")
    self:Print("Shared line with guild: " .. lineObj.text)
end

function addon:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= "BotaTools" then return end
    if sender == UnitName("player") then return end -- Ignore self

    local success, lineObj = self:Deserialize(message)
    if not success then return end

    -- Add to database if not exists (check text)
    local exists = false
    for _, v in ipairs(self.db.profile.eatingLines) do
        if v.text == lineObj.text then
            exists = true
            break
        end
    end

    if not exists then
        table.insert(self.db.profile.eatingLines, lineObj)
        self:Print("Received new eating line from " .. sender .. ": " .. lineObj.text)
        self:RefreshLineList()
        AceConfigRegistry:NotifyChange(addonName)
    end
end
