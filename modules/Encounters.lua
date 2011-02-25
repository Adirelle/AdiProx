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

local function GetMobID(guid)
	if guid then
	-- 0x??A?BBBBB??????? with B being the NPC id if the GUID type (A) is either 3 or B
		local mobID = strmatch(guid, "0x%x%x[3B]%x(%x%x%x%x%x)%x%x%x%x%x%x%x")
		if mobID then
			return tonumber(mobID, 16)
		end
	end
end

local mobUnits = {}
function mod:UpdateModules(event)
	self:Debug('UpdateModules', event)

	-- Fetch boss IDS from boss units, if any
	wipe(mobUnits)
	local hasBoss = false
	for i = 1, 4 do
		local mobID = GetMobID(UnitGUID("boss"..i))
		if mobID then
			mobUnits[mobID] = "boss"..i
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
				if mobUnits[mob] then				
					self:Debug('Module', module, 'enabled for', mobUnits[mob])
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

function moduleProto:OnEnable()
	if self.auras then
		self:RegisterCombatLobEvent('SPELL_AURA_APPLIED', 'OnAuraApplied')
		self:RegisterCombatLobEvent('SPELL_AURA_REFRESH', 'OnAuraApplied')
		self:RegisterCombatLobEvent('SPELL_AURA_REMOVED', 'OnAuraRemoved')
	end
	if self.PostEnable then
		self:PostEnable()
	end
end

function moduleProto:GetMobUnit(mobID)
	if mobUnits[mobID] then
		return mobUnits[mobID]
	elseif GetMobID(UnitGUID("target")) == mobID then
		return "target"
	elseif GetMobID(UnitGUID("focus")) == mobID then
		return "focus"
	end
end

function moduleProto:OnAuraApplied(event, args)
	local aura = self.auras[args.spellId]
	if aura then
		local position = addon:GetUnitPosition(arg.destGUID)
		if position then
			local key = "aura"..args.spellId
			local widget = position:GetWidget(key)
			if not widget then
				-- DO SOMETHING
			elseif event == "SPELL_AURA_REFRESH" then
				-- DO SOMETHING
			end
			if self.PostAuraApplied then
				self:PostAuraApplied(event, args, position, widget)
			end
		end
	end
end

function moduleProto:OnAuraRemoved(event, args)
	if self.auras[args.spellId] then
		local position = addon:GetUnitPosition(arg.destGUID)
		if position then
			local widget = position:Detach("aura"..args.spellId)
			if self.PostAuraRemoved then
				self:PostAuraRemoved(event, args, position, widget)
			end
		end
	end
end

