--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

addon:NewEncounterModule('Halls of Origination/Water warden')
	:AgainstMobs(39802)
	:WatchAuras(77336, 91158) -- Bubble Bound

