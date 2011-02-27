--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

addon:NewEncounterModule("Lost City of the Tol'vir")
	:InMaps("LostCityofTolvir")
	:WatchAuras(82768, 82769, { range = 8 }) -- Infectious Plague

addon:NewEncounterModule("Lost City of the Tol'vir/Lockmaw")
	:InMaps("LostCityofTolvir")
	:AgainstMobs(43614)
	:WatchAuras(81690, 89998) -- Scent of Blood	
	:WatchAuras(81630, 90004, { range = 5 }) -- Vicious Poison

addon:NewEncounterModule("Lost City of the Tol'vir/High Prophet Barim")
	:InMaps("LostCityofTolvir")
	:AgainstMobs(43612)
	:WatchAuras(82255) -- Soul Sever
	
--@debug@
addon:NewEncounterModule("Lost City of the Tol'vir/General Husam")
	:InMaps("LostCityofTolvir")
	:AgainstMobs(44577)
	:WatchSpellCasts(83113) -- Bad Intentions
--@end-debug@	

