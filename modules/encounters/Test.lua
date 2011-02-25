--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local LibMapData = LibStub('LibMapData-1.0')

local mod = addon:NewEncounterModule('Test')
mod.maps = { "Orgrimmar" }

mod.auras = {
	-- Lifebloom
	[33763] = { duration = 10 },
	-- Regrowth
	[8936] = { range = 5 },
}

mod.spellCasts = {
	-- Swiftmend
	[18562] = { range = 9, static = true, duration = 7.5 },
	-- Healing Touch
	[5185] = { range = 8 },
}
