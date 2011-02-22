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
end

function addon:NewEncounterModule(...)
	return mod:NewModule(...)
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
	for _, module in self:IterateModules()do	
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
mod:SetDefaultModuleLibraries('AceEvent-3.0')

function moduleProto:OnDisable()
	addon.moduleProto.OnDisable(self)
	self:UnregisterAllCombatLogEvents()
end

--------------------------------------------------------------------------------
-- Combat listening
--------------------------------------------------------------------------------

local callbacks = LibStub('CallbackHandler-1.0'):New(moduleProto, "RegisterCombatLogEvent", "UnregisterCombatLogEvent", "UnregisterAllCombatLogEvents")

local eventRegistry = {}

function callbacks:OnUsed(_, event)
	if not next(eventRegistry) then
		mod:Debug('Registered COMBAT_LOG_EVENT_UNFILTERED')
		mod:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	end
	eventRegistry[event] = true
end

function callbacks:OnOnused(_, event)
	eventRegistry[event] = nil
	if not next(eventRegistry) then
		mod:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
		mod:Debug('Unregistered COMBAT_LOG_EVENT_UNFILTERED')
	end
end

local evt = {}
local fillers = {}

function mod:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, ...)
	if eventRegistry[event] then
		callbacks:Fire(event, fillers[event](evt, event, ...))
	end
end

-- Dynamically build functions to fill the event table
do
	local prefixes = {
		SWING = "",
		RANGE = ",spellId,spellName,spellSchool",
		SPELL = ",spellId,spellName,spellSchool",
		SPELL_PERIODIC = ",spellId,spellName,spellSchool",
		SPELL_BUILDING = ",spellId,spellName,spellSchool",
		ENVIRONMENTAL = ",environmentalType",
	}
	local suffixes = {
		DAMAGE = ",amount,overkill,school,resisted,blocked,absorbed,critical,glancing,crushing",
		MISSED = ",missType,amountMissed",
		HEAL = ",amount,overhealing,absorbed,critical",
		ENERGIZE = ",amount,powerType",
		DRAIN = ",amount,powerType,extraAmount",
		LEECH = ",amount,powerType,extraAmount",
		INTERRUPT = ",extraSpellID,extraSpellName,extraSchool",
		DISPEL = ",extraSpellID,extraSpellName,extraSchool,auraType",
		DISPEL_FAILED = ",extraSpellID,extraSpellName,extraSchool",
		STOLEN = ",extraSpellID,extraSpellName,extraSchool,auraType",
		EXTRA_ATTACKS = ",amount",
		AURA_APPLIED = ",auraType",
		AURA_REMOVED= ",auraType",
		AURA_APPLIED_DOSE = ",auraType,amount",
		AURA_REMOVED_DOSE = ",auraType,amount",
		AURA_REFRESH = ",auraType",
		AURA_BROKEN = ",auraType",
		AURA_BROKEN_SPELL = ",extraSpellID,extraSpellName,extraSchool,auraType",
		CAST_START = "",
		CAST_SUCCESS = "",
		CAST_FAILED	= ",failedType",
		INSTAKILL = "",
		DURABILITY_DAMAGE = "",
		DURABILITY_DAMAGE_ALL = "",
		CREATE = "",
		SUMMON = "",
		RESURRECT = "",
	}

	-- Build filler functions based on the argument list
	local fillerByArgs = setmetatable({}, {__index = function(self, args)
		local body = format("return function(e,%s) wipe(e) e.%s = %s return e end", args, gsub(args, ",", ",e."), args)
		local result = loadstring(body, args)()
		self[args] = result
		return result
	end})
	
	-- Build filler by event
	setmetatable(fillers, {__index = function(self, event)
		local args = "event,sourceGUID,sourceName,sourceFlags,destGUID,destName,destFlags"
		for prefix, prefixArgs in pairs(prefixes) do
			local len = strlen(prefix)
			if substr(event, 1, len) == prefix then
				local suffixArgs = suffixes[substr(event, len + 2)]
				if suffixArgs then
					args = args..prefixArgs..suffixArgs
					break
				end
			end
		end
		local filler = fillerByArgs[args]
		self[event] = filler
		return filler
	end})

	-- Enforced aliases
	fillers.DAMAGE_SHIELD = fillers.SPELL_DAMAGE
	fillers.DAMAGE_SPLIT = fillers.SPELL_DAMAGE
	fillers.DAMAGE_SHIELD_MISSED = fillers.SPELL_MISSED
end

