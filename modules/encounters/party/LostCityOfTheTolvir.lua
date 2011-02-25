--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

addon:NewEncounterModule('Lost City Of The Tolvir')
	:InMaps("LostCityofTolvir")
	:WatchAuras(82768, 82769, { range = 8 }) -- Infectious Plague

addon:NewEncounterModule('Lost City Of The Tolvir - Lockmaw')
	:AgainstMobs(43614)
	:WatchAuras(81690, 89998) -- Scent of Blood	
	:WatchAuras(81630, 90004, { range = 5 }) -- Vicious Poison

