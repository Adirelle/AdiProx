--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

addon:NewEncounterModule('Grim Batol/Erudax')
	:InMaps("GrimBatol")
	:AgainstMobs(40484)
	:WatchSpellCasts(75861, 91079, { range = 10, static = true }) -- Binding Shadows

