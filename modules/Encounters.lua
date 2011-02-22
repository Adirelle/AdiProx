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
	self:UpdateModules()
end

function mod:PostDisable()
	LibMapData.UnregisterAllCallbacks(self)
	wipe(self.eventRegistry)
end

local bossIDs = {}
function mod:UpdateModules()

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
	for _, module in self:IterateModules()		
		local enable = false
		
		-- Check map-related modules
		if module.maps then
			local map = GetMapInfo()
			for i, zone in pairs(module.zones) do
				if zone == map then
					enable = true
					break
				end
			end
		end
		
		-- Check boss-related modules
		if not enabled and hasBoss and module.bosses then
			for i, mob in pairs(module.bosses) do
				if bossIDs[mob] then				
					enable = true
					break
				end
			end
		end
		
		-- Enable/disable as needed
		if enable and not module:IsEnabled() then
			module:Enable()
		elseif not enable and module:IsEnabled() then
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

function moduleProto:OnDisable()
	addon.moduleProto.OnDisable(self)
	self:UnregisterAllCombatLogEvents()
end

--------------------------------------------------------------------------------
-- Combat listening
--------------------------------------------------------------------------------

mod.callbacks = LibStub('CallbackHandler-1.0'):New(moduleProto, "RegisterCombatLogEvent", "UnregisterCombatLogEvent", "UnregisterAllCombatLogEvents")

mod.eventRegistry = {}

function mod.callbacks:OnUsed(_, event)
	if not next(mod.eventRegistry) then
		mod:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	end
	mod.eventRegistry[event] = true
end

function mod.callbacks:OnOnused(_, event)
	mod.eventRegistry[event] = nil
	if not next(mod.eventRegistry) then
		mod:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	end
end

function mod:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, ...)
	if self.eventRegistry[event] then
		mod.callbacks:Fire(event, ...)
	end
end
