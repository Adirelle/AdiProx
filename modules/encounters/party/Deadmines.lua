--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

-- Deadmines
addon:NewEncounterModule('Deadmines')
	:InMaps("TheDeadmines")
	:WatchAuras(90962, 90963, 90396, 90397, { range = 8 }) -- Whirling Blades

addon:NewEncounterModule('Deadmines - Foe Reaper')
	:AgainstMobs(43778)
	:WatchSpellCasts(88495, { range = 8, static = true, atEnd = true }) -- Harvest

addon:NewEncounterModule('Deadmines - Helix')
	:AgainstMobs(47296, 47297)
	:WatchAuras(88352, { range = 8, duration = 10 }) -- Chest Bomb

