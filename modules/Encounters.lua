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
		if not enabled and hasBoss and module.mobs then
			for i, mob in pairs(module.mobs) do
				if mobUnits[mob] then
					enable = true
					break
				end
			end
		end

		-- Enable/disable as needed
		if enable then
			if not module:IsEnabled() then
				self:Debug('Enabling encounter', module)
				module:Enable()
			end
		elseif module:IsEnabled() then
			self:Debug('Disabling encounter', module)
			module:Disable()
		end
	end
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local band = bit.band
local schools = {
	PHYSICAL = SCHOOL_MASK_PHYSICAL,
	HOLY     = SCHOOL_MASK_HOLY,
	FIRE     = SCHOOL_MASK_FIRE,
	NATURE   = SCHOOL_MASK_NATURE,
	FROST    = SCHOOL_MASK_FROST,
	SHADOW   = SCHOOL_MASK_SHADOW,
	ARCANE   = SCHOOL_MASK_ARCANE,
}
local function GetSchoolColor(spellSchool)
	if spellSchool then
		for school, mask in pairs(schools) do
			if band(spellSchool, mask) ~= 0 then
				return school
			end
		end
	end
end

local function GetDebuffColor(spellId)
	return (select(5, GetSpellInfo(spellId)))
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

-- Definition helpers

local function MergeList(self, key, ...)
	local t = self[key]
	if not t then
		t = {}
		self[key] = t
	end
	for i = 1, select('#', ...) do
		tinsert(t, (select(i, ...)))
	end
	return self
end

local DEFAULT_DEF = {}
local function MergeData(self, key, ...)
	local t = self[key]
	if not t then
		t = {}
		self[key] = t
	end
	local n = select('#', ...)
	local data = select(n, ...)
	if type(data) == "table" then
		n = n - 1
	else
		data = DEFAULT_DEF
	end
	for i = 1, n do
		t[select(i, ...)] = data
	end
	return self
end

function moduleProto:AgainstMobs(...) return MergeList(self, "mobs", ...) end
function moduleProto:InMaps(...) return MergeList(self, "maps", ...) end

function moduleProto:WatchAuras(...) return MergeData(self, "auras", ...) end
function moduleProto:WatchSpellCasts(...) return MergeData(self, "spellCasts", ...) end

-- Enabling

function moduleProto:OnEnable()
	if self.auras then
		self:Debug('Watching auras')
		self:RegisterCombatLogEvent('SPELL_AURA_APPLIED')
		self:RegisterCombatLogEvent('SPELL_AURA_APPLIED_DOSE', 'SPELL_AURA_APPLIED')
		self:RegisterCombatLogEvent('SPELL_AURA_REFRESH', 'SPELL_AURA_APPLIED')
		self:RegisterCombatLogEvent('SPELL_AURA_REMOVED')
	end
	if self.spellCasts then
		self:Debug('Watching spell casts')
		self.currentCast = wipe(self.currentCast or {})
		self:RegisterCombatLogEvent('SPELL_CAST_START')
		self:RegisterCombatLogEvent('SPELL_CAST_SUCCESS')
	end
	if self.PostEnable then
		self:PostEnable()
	end
end

function moduleProto:PlaceMarker(key, target, static, markerType, color, radius, duration)
	if not target then return end
	self:Debug('PlaceMarker(', "key=", key, "target=", target, "static=", static, "type=", markerType, "color=", color, "radius=", radius, "duration=", duration, ')')
	local position = addon:GetUnitPosition(target)
	if not position then
		self:Debug('PlaceMarker: no position for', target, ', giving up')
		return
	end
	if static then
		position = position:GetStaticPosition()
	end
	local widget = position:GetWidget(key)
	self:Debug('PlaceMarker: position=', position, 'existingMarker=', marker)
	local reverse = radius and radius < 0
	if reverse then
		radius = -radius
	end
	if not widget then
		self:Debug('PlaceMarker: creating a new marker')
		widget = self:AcquireWidget(markerType or (radius and "encounter_proximity") or "encounter_reticle", radius, duration, color)
		widget:SetImportant(true)
		position:Attach(key, widget)
	else
		self:Debug('PlaceMarker: refreshing the existing marker')
		widget:Refresh(radius, duration)
	end
	widget:SetAlertRadius(radius, reverse)
	return widget, position
end

function moduleProto:SPELL_AURA_APPLIED(event, args)
	local aura = self.auras[args.spellId]
	if aura then
		local color = aura.color or GetDebuffColor(args.spellId) or GetSchoolColor(args.spellSchool)
		local widget, position = self:PlaceMarker("aura"..args.spellId, args.destGUID, aura.static, aura.marker, color, aura.range, aura.duration)
		if widget and self.PostAuraApplied then
			self:PostAuraApplied(event, args, position, widget)
		end
	end
end

function moduleProto:SPELL_AURA_REMOVED(event, args)
	if self.auras[args.spellId] then
		local position = addon:GetUnitPosition(args.destGUID)
		if position then
			local widget = position:Detach("aura"..args.spellId)
			if widget and self.PostAuraRemoved then
				self:PostAuraRemoved(event, args, position, widget)
			end
		end
	end
end

function moduleProto:SPELL_CAST_START(event, args)
	local spell = self.spellCasts[args.spellId]
	if spell then
		wipe(self.currentCast)
		for k, v in pairs(args) do
			self.currentCast[k] = v
		end
		self:ScheduleTimer("GetSpellCastTarget", spell.targetDelay or 0.1, self.currentCast)
	end
end

function moduleProto:SPELL_CAST_SUCCESS(event, args)
	if self.spellCasts[args.spellId] then
		return self:OnSpellCast(event, args, 1)
	end
end

function moduleProto:GetSpellCastTarget(args)
	local unit = self:MobGUIDToUnit(args.sourceGUID) or addon.GetGUIDUnit(args.sourceGUID)
	if not unit then return end
	local target = gsub(unit.."target", "(%d+)target$", "target%1")
	if target == "playertarget" then target = "target" end
	local duration = (select(6, UnitCastingInfo(unit)) or 0) / 1000 - GetTime()
	args.destName = UnitName(target)
	args.destGUID = UnitGUID(target)
	if self.spellCasts[args.spellId].atEnd then
		self:ScheduleTimer("OnSpellCastEnd", duration, args)
	else
		self:OnSpellCast(args.event, args, duration)
	end
end

function moduleProto:OnSpellCastEnd(args)
	return self:OnSpellCast(args.event, args, 1)
end

function moduleProto:OnSpellCast(event, args, duration)
	local spell = self.spellCasts[args.spellId]
	if spell then
		local color = spell.color or GetSchoolColor(args.spellSchool) or GetDebuffColor(args.spellID)
		local widget, position = self:PlaceMarker("spell"..args.spellId, args.destGUID, spell.static, spell.marker, color, spell.range, spell.duration or duration)
		if widget and self.PostSpellCast then
			self:PostSpellCast(event, args, position, widget)
		end
	end
end

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

--------------------------------------------------------------------------------
-- Base widget
--------------------------------------------------------------------------------

local encounterProto, parentProto = addon.NewWidgetType("encounter", "abstract")
encounterProto.frameLevel = 4

function encounterProto:OnAcquire(texture, radius, duration, color)
	self.duration, self.radius = nil, nil
	parentProto.OnAcquire(self)
	self.color = color
	self:AcquireAnimation("main", texture, radius, color)
	self:Refresh(radius, duration)
end

function encounterProto:Refresh(radius, duration)
	self:SetDuration(duration)
	self:SetRadius(radius)
end

function encounterProto:SetRadius(radius)
	radius = radius or self.defaultRadius
	if self.radius ~= radius then
		self.radius = radius
		self:OnRadiusChanged(radius)		
	end
	return self
end

function encounterProto:SetDuration(duration)
	if self.duration ~= duration then
		self.duration = duration
		self:OnDurationChanged(duration)		
	end
	return parentProto.SetDuration(self, duration)
end

function encounterProto:OnAlertChanged()
	local color = self.alert and "RED" or self.color
	for _, anim in pairs(self.animations) do
		anim:SetColor(color)
	end
end

--------------------------------------------------------------------------------
-- Reticle widget
--------------------------------------------------------------------------------

local reticleProto, parentProto = addon.NewWidgetType("encounter_reticle", "encounter")
reticleProto.defaultRadius = 24

function reticleProto:OnAcquire(radius, duration, color)
	parentProto.OnAcquire(self, "targeting", radius, duration, color)
	self:GetAnimation("main"):Rotate(360, 2)
end

function reticleProto:OnRadiusChanged(radius)
	for _, anim in pairs(self.animations) do
		anim:SetSize(radius)
	end
end

function reticleProto:OnDurationChanged(duration)
	self:Debug("OnDurationChanged", duration)
	if duration then
		local anim = self:GetAnimation("duration") or self:AcquireAnimation("duration", "smallcircle", self.radius, self.color)
		anim:Pulse(-0.5, duration)
	else
		self:ReleaseAnimation("duration")
	end
end

--------------------------------------------------------------------------------
-- Proximity widget
--------------------------------------------------------------------------------

local rangeProto, parentProto = addon.NewWidgetType("encounter_proximity", "encounter")

function rangeProto:OnAcquire(radius, duration, color)
	self.pixelsPerYard = nil
	parentProto.OnAcquire(self, "highlight", radius, duration, color)
end

function rangeProto:OnRadiusChanged(radius)
	addon.forceUpdate = true
end

function rangeProto:OnDurationChanged(duration)
	local anim = self:GetAnimation("main")
	if duration then
		anim:SetTexture("timer"):Rotate(-360, duration)
	else
		anim:SetTexture("highlight"):Rotate(nil, nil)
	end
end

function rangeProto:SetPoint(x, y, pixelsPerYard, ...)
	parentProto.SetPoint(self, x, y, pixelsPerYard, ...)
	if pixelsPerYard ~= self.pixelsPerYard then
		self.pixelsPerYard = pixelsPerYard
		local size = 2 * self.radius * pixelsPerYard
		for _, anim in pairs(self.animations) do
			anim:SetSize(size)
		end
	end
end
