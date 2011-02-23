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

function mod:OnEnable()
	self:RegisterCombatLogEvent('SPELL_AURA_APPLIED')
	self:RegisterCombatLogEvent('SPELL_AURA_REMOVED')
	self:RegisterCombatLogEvent('SPELL_CAST_SUCCESS')
end

function mod:SPELL_AURA_APPLIED(_, event)
	self:Debug('SPELL_AURA_APPLIED', _, event)
	if event.spellId == 33763 then
		local pos = addon:GetUnitPosition(event.destGUID)
		if pos and not pos:GetWidget("lifebloom") then
			pos:Attach("lifebloom", self:AcquireWidget("range", [[SPELLS\CIRCLE]], 5, 1, 0, 1, 0, 1, "ADD"):SetImportant(true))
		end
	end
end

function mod:SPELL_AURA_REMOVED(_, event)
	if event.spellId == 33763 then
		local pos = addon:GetUnitPosition(event.destGUID)
		local widget = pos and pos:GetWidget("lifebloom")
		if widget then
			widget:Release()
		end
	end
end

function mod:SPELL_CAST_SUCCESS(_, event)
	if event.spellId == 18562 then
		local pos = addon:GetUnitPosition(event.destGUID)
		if pos then
			local widget = self:AcquireWidget("range", [[SPELLS\WHITERINGTHIN128]], 9, 1, 0, 1, 0, 1, "ADD"):SetDuration(7.5):SetImportant(true)
			pos:GetStaticPosition():Attach("swiftmend", widget)
		end
	end
end

