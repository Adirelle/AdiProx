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
mod:SetDefaultModuleLibraries('LibCombatLogEvent-1.0', 'AceEvent-3.0', 'AceTimer-3.0')

function moduleProto:OnEnable()
	if self.auras then
		self:RegisterCombatLobEvent('SPELL_AURA_APPLIED', 'OnAuraApplied')
		self:RegisterCombatLobEvent('SPELL_AURA_APPLIED_DOSE', 'OnAuraApplied')
		self:RegisterCombatLobEvent('SPELL_AURA_REFRESH', 'OnAuraApplied')
		self:RegisterCombatLobEvent('SPELL_AURA_REMOVED', 'OnAuraRemoved')
	end
	if self.spellCasts then
		self.currentCast = wipe(self.currentCast or {})
		self:RegisterCombatLobEvent('SPELL_CAST_START')
		self:RegisterCombatLobEvent('SPELL_CAST_SUCCESS')
	end
	if self.PostEnable then
		self:PostEnable()
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
			end
			-- DO SOMETHING
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

-- Quite ugly, but quick
local UnitGUID, GetNumRaidMembers, GetNumPartyMembers = UnitGUID, GetNumRaidMembers, GetNumPartyMembers
function moduleProto:MobGUIDToUnit(guid)
	if not guid then return
	elseif UnitGUID("boss1") == guid then return "boss1"
	elseif UnitGUID("boss2") == guid then return "boss2"
	elseif UnitGUID("boss3") == guid then return "boss3"
	elseif UnitGUID("boss4") == guid then return "boss4"
	elseif UnitGUID("target") == guid then return "target"
	elseif UnitGUID("focus") == guid then return "focus"
	elseif GetNumRaidMembers() > 0 then
		for i = 1, GetNumRaidMembers() do
			if UnitGUID("raidtarget"..i) == guid then return "raidtarget"..i end
		end
	elseif GetNumPartyMembers() > 0 then
		for i = 1, GetNumPartyMembers() do
			if UnitGUID("partytarget"..i) == guid then return "partytarget"..i end
		end
	end
end

function moduleProto:GetSpellCastTarget(args)
	local unit = self:MobGUIDToUnit(args.sourceGUID)
	if not unit then return end
	local target = gsub(unit.."target", "(%d+)target$", "target%1")	
	args.destName = UnitName(target)
	args.destGUID = UnitGUID(target)
	return self:OnSpellCast(args.event, args)
end

function moduleProto:SPELL_CAST_START(event, args)
	if self.spellCasts[args.spellId] then
		wipe(self.currentCast)
		for k, v in pairs(args) do
			self.currentCast[k] = v
		end
		self:ScheduleTimer("GetSpellCastTarget", 0.1, self.currentCast)
	end	
end

function moduleProto:SPELL_CAST_SUCCESS(event, args)
	if self.spellCasts[args.spellId]  then
		return self:OnSpellCast(event, args)
	end
end

function moduleProto:OnSpellCast(event, args)
	local spell = self.spellCasts[args.spellId] 
	if spell then
		local position = addon:GetUnitPosition(arg.destGUID)
		if position then
			local key = "spell"..args.spellId
			local widget = position:GetWidget(key)
			if not widget then
				-- DO SOMETHING
			end
			if self.PostSpellCast then
				self:PostSpellCast(event, args, position, widget)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Encounter widgets
--------------------------------------------------------------------------------

local reticleProto, parentProto = addon.NewWidgetType("reticle", "abstract")

function reticleProto:OnCreateFrame(parent)
	local frame = 
end