--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

addon:NewEncounterModule('Blackwing Descent/Maloriak')
	:AgainstMobs(41378)
	:WatchAuras(77699, 92978, 92979, 92980, { range = 5, duration = 30 }) -- Flash Freeze
	:WatchAuras(77760, 92975, 92976, 92977, { range = 5 }) -- Biting Chill

addon:NewEncounterModule('Blackwing Descent/Magmaw')
	:AgainstMobs(41570)
	:WatchAuras(91913, 94678, 94679, { range = 5, duration = 10 }) -- Parasitic Infection

addon:NewEncounterModule('Blackwing Descent/Atramedes')
	:AgainstMobs(41442)
	:WatchAuras(78092) -- Tracking

addon:NewEncounterModule('Blackwing Descent/Omnotron Defense System')
	:AgainstMobs(42180, 42178, 42179, 42166)
	:WatchAuras(80094, { duration = 20 }) -- Fixate
	:WatchAuras(79888, 91431, 91432, 91433, { range = 20, duration = 10 }) -- Lightning Conductor
	:WatchAuras(79501, 92035, 92036, 92037, { duration = 4 }) -- Acquiring Target

