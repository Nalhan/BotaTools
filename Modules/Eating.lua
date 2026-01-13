---@class BotaTools : AceAddon, AceConsole, AceEvent, AceComm, AceSerializer
---@field db AceDB.Schema
---@field options table

---@class Eating : AceModule, AceEvent
---@field searchFilter string
---@field currentPage number
---@field pageSize number
---@field lastAddedName string|nil

local addonName, addonTable = ...
local addon = LibStub("AceAddon-3.0"):GetAddon(addonName)
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

-- Create the module
local Eating = addon:NewModule("Eating", "AceEvent-3.0") ---@cast Eating Eating

-- Module State
Eating.searchFilter = ""
Eating.currentPage = 1
Eating.pageSize = 50
Eating.lastAddedName = nil

local isEating = false

function Eating:OnEnable()
    self:RegisterEvent("UNIT_AURA")
end

-- Helper to check if the group constitutes a "Guild Group"
function Eating:IsGuildGroup()
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

function Eating:UNIT_AURA(event, unit)
    if unit ~= "player" or InCombatLockdown() then return end

    local hasFood = false

    -- Check for buffs acting as food
    for i = 1, 40 do
        local aura = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
        if not aura then break end

        -- Match by spell ID as requested
        if addon.db.profile.spellIDs[aura.spellId] then
            hasFood = true
            break
        end
    end

    if hasFood and not isEating then
        isEating = true
        if addon.db.profile.enableEatingChat then
            self:SayRandomLine()
        end
    elseif not hasFood and isEating then
        isEating = false
    end
end

function Eating:SayRandomLine()
    local lines = addonTable.OfficialLines or {}
    if #lines == 0 then return end

    -- Guard against combat or messaging lockdown in Midnight
    -- Also guard against open-world SAY protection (only allowed in instances)
    if InCombatLockdown() or (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) or not IsInInstance() then
        if not IsInInstance() then
            addon:Print("Eating chat suppressed: SAY is blocked outside of instances.")
        else
            addon:Print("Eating chat suppressed: In combat or messaging lockdown.")
        end
        return
    end

    -- Guild Group Check
    if addon.db.profile.onlyGuildGroup then
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

function Eating:GetWeightColor(weight)
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

function Eating:Refresh()
    self:RefreshLineList()
    self:RefreshSpellList()
end

function Eating:RefreshLineList()
    -- This function modifies the options table directly
    -- We need to ensure the options table exists and has the correct path
    if not addon.options then return end

    local lines = addonTable.OfficialLines or {}
    local filtered = {}
    local search = self.searchFilter

    -- 1. Filter
    for i, lineObj in ipairs(lines) do
        if search == "" or lineObj.text:lower():find(search, 1, true) then
            -- Keep track of original index
            table.insert(filtered, { obj = lineObj, originalIndex = i })
        end
    end

    -- 2. Paginate
    local pageSize = self.pageSize
    local totalPages = math.max(1, math.ceil(#filtered / pageSize))
    if self.currentPage > totalPages then self.currentPage = totalPages end

    local startIndex = (self.currentPage - 1) * pageSize + 1
    local endIndex = math.min(startIndex + pageSize - 1, #filtered)

    -- 3. Render Slice
    -- Update for nested path: addon.options.args.Eating.args.memes.args.lineList.args
    if addon.options.args.Eating and addon.options.args.Eating.args.memes and addon.options.args.Eating.args.memes.args.lineList then
        addon.options.args.Eating.args.memes.args.lineList.args = {}
        for i = startIndex, endIndex do
            local entry = filtered[i]
            local lineObj = entry.obj
            local originalIndex = entry.originalIndex
            local color = self:GetWeightColor(lineObj.weight)
            local displayName = string.format("|cff%s[%d]|r %s", color, lineObj.weight or 10, lineObj.text)

            addon.options.args.Eating.args.memes.args.lineList.args["group" .. originalIndex] = {
                type = "group",
                name = "",
                inline = true,
                order = i,
                args = {
                    line = {
                        name = displayName,
                        type = "description",
                        order = 1,
                        width = "full",
                    }
                },
            }
        end
    end
end

function Eating:RefreshSpellList()
    if addon.options.args.Eating and addon.options.args.Eating.args.settings and addon.options.args.Eating.args.settings.args.triggers then
        addon.options.args.Eating.args.settings.args.triggers.args.spellList.args = {}
        local i = 0
        for spellId in pairs(addon.db.profile.spellIDs) do
            i = i + 1
            local currentSpellId = spellId -- local copy for closure

            -- Fetch spell info for display
            local spellInfo = C_Spell.GetSpellInfo(currentSpellId)
            local baseName = (spellInfo and spellInfo.name) or "Unknown"
            local name = string.format("%s (%d)", baseName, currentSpellId)
            local icon = (spellInfo and spellInfo.iconID) or 134400 -- Question mark icon

            addon.options.args.Eating.args.settings.args.triggers.args.spellList.args["spell" .. currentSpellId] = {
                name = name,
                desc = "Spell ID: " .. currentSpellId,
                type = "description",
                image = icon,
                imageWidth = 24,
                imageHeight = 24,
                order = i * 10,
                width = "double",
            }
            addon.options.args.Eating.args.settings.args.triggers.args.spellList.args["deleteSpell" .. currentSpellId] = {
                name = "Delete",
                type = "execute",
                func = function()
                    addon.db.profile.spellIDs[currentSpellId] = nil
                    self:RefreshSpellList()
                    AceConfigRegistry:NotifyChange(addonName)
                end,
                order = i * 10 + 1,
                width = "half",
            }
        end
    end
end

function Eating:GetOptions()
    local options = {
        name = "Eating Meme Reborn",
        handler = self,
        type = "group",
        childGroups = "tab",
        args = {
            settings = {
                name = "Settings",
                type = "group",
                order = 1,
                args = {
                    enableEatingChat = {
                        name = "Enable Eating Chat",
                        desc = "Say a random line when you start eating.",
                        type = "toggle",
                        set = function(info, val) addon.db.profile.enableEatingChat = val end,
                        get = function(info) return addon.db.profile.enableEatingChat end,
                        order = 2,
                    },
                    onlyGuildGroup = {
                        name = "Only in Guild Group",
                        desc = "Only say a line if you are in a group with other guild members.",
                        type = "toggle",
                        set = function(info, val) addon.db.profile.onlyGuildGroup = val end,
                        get = function(info) return addon.db.profile.onlyGuildGroup end,
                        order = 3,
                    },
                    triggers = {
                        name = "Aura Triggers",
                        type = "group",
                        inline = true,
                        order = 4,
                        args = {
                            header = {
                                name = "Spell ID Triggers",
                                type = "header",
                                order = 0,
                            },
                            addSpell = {
                                name = "Add New Spell ID",
                                desc = "Enter a numeric spell ID to add a trigger.",
                                type = "input",
                                set = function(info, val)
                                    local id = tonumber(val:match("(%d+)"))
                                    if id then
                                        addon.db.profile.spellIDs[id] = true
                                        local spellInfo = C_Spell.GetSpellInfo(id)
                                        self.lastAddedName = (spellInfo and spellInfo.name) or tostring(id)
                                        addon:Print("Added spell ID trigger: " .. tostring(id))
                                        self:RefreshSpellList()
                                        AceConfigRegistry:NotifyChange(addonName)
                                    end
                                end,
                                order = 1,
                            },
                            lastAdded = {
                                name = function()
                                    if self.lastAddedName then
                                        return "|cff1eff00Last Added:|r " .. self.lastAddedName
                                    end
                                    return ""
                                end,
                                type = "description",
                                order = 1.1,
                            },
                            spellList = {
                                name = "Active Triggers",
                                type = "group",
                                inline = true,
                                order = 2,
                                args = {},
                            }
                        }
                    }
                }
            },
            memes = {
                name = "Meme Collection",
                type = "group",
                order = 2,
                args = {
                    header = {
                        name = "Meme Collection",
                        type = "header",
                        order = 0,
                    },
                    searchMemes = {
                        name = "Search Memes",
                        desc = "Filter the meme list by text.",
                        type = "input",
                        order = 1,
                        width = "double",
                        get = function() return self.searchFilter end,
                        set = function(info, val)
                            self.searchFilter = val:lower()
                            self.currentPage = 1 -- Reset to page 1 on search
                            self:RefreshLineList()
                            AceConfigRegistry:NotifyChange(addonName)
                        end,
                    },
                    spacer1 = {
                        name = "",
                        type = "description",
                        order = 1.5,
                        width = "full",
                    },
                    prevPage = {
                        name = "Previous",
                        type = "execute",
                        order = 2,
                        width = "half",
                        func = function()
                            self.currentPage = math.max(1, self.currentPage - 1)
                            self:RefreshLineList()
                            AceConfigRegistry:NotifyChange(addonName)
                        end,
                        disabled = function() return self.currentPage <= 1 end,
                    },
                    jumpPage = {
                        name = "Jump to Page",
                        type = "select",
                        order = 3,
                        width = "normal",
                        values = function()
                            local filtered = {}
                            local search = self.searchFilter
                            for _, line in ipairs(addonTable.OfficialLines or {}) do
                                if search == "" or line.text:lower():find(search, 1, true) then
                                    table.insert(filtered, line)
                                end
                            end
                            local totalPages = math.max(1, math.ceil(#filtered / self.pageSize))
                            local vals = {}
                            for i = 1, totalPages do
                                vals[i] = "Page " .. i
                            end
                            return vals
                        end,
                        get = function() return self.currentPage end,
                        set = function(info, val)
                            self.currentPage = val
                            self:RefreshLineList()
                            AceConfigRegistry:NotifyChange(addonName)
                        end,
                    },
                    nextPage = {
                        name = "Next",
                        type = "execute",
                        order = 4,
                        width = "half",
                        func = function()
                            local filtered = {}
                            local search = self.searchFilter
                            for _, line in ipairs(addonTable.OfficialLines or {}) do
                                if search == "" or line.text:lower():find(search, 1, true) then
                                    table.insert(filtered, line)
                                end
                            end
                            local totalPages = math.max(1, math.ceil(#filtered / self.pageSize))
                            self.currentPage = math.min(totalPages, self.currentPage + 1)
                            self:RefreshLineList()
                            AceConfigRegistry:NotifyChange(addonName)
                        end,
                        disabled = function()
                            local filteredCount = 0
                            local search = self.searchFilter
                            for _, line in ipairs(addonTable.OfficialLines or {}) do
                                if search == "" or line.text:lower():find(search, 1, true) then
                                    filteredCount = filteredCount + 1
                                end
                            end
                            local totalPages = math.max(1, math.ceil(filteredCount / self.pageSize))
                            return self.currentPage >= totalPages
                        end,
                    },
                    pageStatus = {
                        name = function()
                            local filteredCount = 0
                            local search = self.searchFilter
                            for _, line in ipairs(addonTable.OfficialLines or {}) do
                                if search == "" or line.text:lower():find(search, 1, true) then
                                    filteredCount = filteredCount + 1
                                end
                            end
                            local totalPages = math.max(1, math.ceil(filteredCount / self.pageSize))
                            return string.format("|cffffff00Page %d of %d|r (%d lines total)", self.currentPage,
                                totalPages, filteredCount)
                        end,
                        type = "description",
                        order = 5,
                        width = "full",
                    },
                    lineList = {
                        name = "Eating Lines",
                        type = "group",
                        inline = true,
                        order = 6,
                        args = {},
                    },
                }
            }
        }
    }
    return options
end
