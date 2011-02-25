--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

addon:NewEncounterModule('Test')
	:InMaps("Orgrimmar")
	-- Restokin-based tests
	:WatchAuras(33763) -- Lifebloom
	:WatchSpellCasts(18562, { range = 9, static = true, duration = 7.5 }) -- Swiftmend
	:WatchSpellCasts(5185) -- Healing Touch
	:WatchSpellCasts(8936, { duration = 6, atEnd = true }) -- Regrowth

