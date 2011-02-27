--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

addon:NewEncounterModule('The Vortex Pinnacle/Altarius')
	:InMaps("Skywall")
	:AgainstMobs(43873)
	:WatchSpellCasts(88308, 93989, { targetDelay = 0.2 }) -- Chilling Breath

