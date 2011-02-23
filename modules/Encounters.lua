--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local LibMapData = LibStub('LibMapData-1.0')

local mod = addon:NewModule('Encounters', 'AceEvent-3.0')

function mod:OnEnable()
	self:RegisterEvent('PLAYER_ENTERING_WORLD', 'UpdateModules')
	self:RegisterEvent('INSTANCE_ENCOUNTER_ENGAGE_UNIT', 'UpdateModules')
	LibMapData.RegisterCallback(self, 'MapChanged', 'UpdateModules')
	self:UpdateModules("OnEnable")
end

function mod:PostDisable()
	LibMapData.UnregisterAllCallbacks(self)
end

function addon:NewEncounterModule(...)
	return mod:NewModule(...)
end

local bossIDs = {}
function mod:UpdateModules(event)
	self:Debug('UpdateModules', event)

	-- Fetch boss IDS from boss units, if any
	wipe(bossIDs)
	local hasBoss = false
	for i = 1, 4 do
		local guid = UnitGUID("boss"..i)
		if guid then
			bossIDs[tonumber(strsub(guid, 7, 10), 16)] = UnitName("boss"..i)
			hasBoss = true
		end
	end
	
	-- Check each module
	for _, module in self:IterateModules()do	
		local enable = false
		
		-- Check map-related modules
		if module.maps then
			local map = GetMapInfo()
			for i, zone in pairs(module.maps) do
				if zone == map then
					self:Debug('Module', module, 'enabled in', zone)
					enable = true
					break
				end
			end
		end
		
		-- Check boss-related modules
		if not enabled and hasBoss and module.bosses then
			for i, mob in pairs(module.bosses) do
				if bossIDs[mob] then				
					self:Debug('Module', module, 'enabled for', bossIDs[mob])
					enable = true
					break
				end
			end
		end
		
		-- Enable/disable as needed
		if enable then
			if not module:IsEnabled() then
				module:Enable()
			end
		elseif module:IsEnabled() then
			module:Disable()
		end
	end
end

--------------------------------------------------------------------------------
-- Module prototype
--------------------------------------------------------------------------------

local moduleProto = {}
for k, v in pairs(addon.moduleProto) do
	moduleProto[k] = v
end

mod:SetDefaultModulePrototype(moduleProto)
mod:SetDefaultModuleState(false)
mod:SetDefaultModuleLibraries('LibCombatLogEvent-1.0')

