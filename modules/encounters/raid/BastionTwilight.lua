--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

addon:NewEncounterModule('The Bastion of Twilight/Valiona and Theralion')
	:InMaps("TheBastionofTwilight")
	:AgainstMobs(45992, 45993)
	:WatchAuras(86788, 92876, 92877, 92878, { range = -10, duration = 15 }) -- Blackout
	:WatchAuras(92861, 86013, 92859, { range = 8, duration = 6 }) -- Twilight Meteorite
	:WatchAuras(86622, 95639, 95640, 95641, { range = 15, duration = 20 }) -- Engulfing Magic
	:WatchSpellCasts(92900, 86369, 92899, 92898, { range = -8, duration = 2 }) -- Twilight Blast

