--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('Encounters')

local function GetSlug(name)
	return name and gsub(name, "%W+", "")
end

function addon:NewEncounterModule(name, ...)
	local instance, encounter = strsplit('/', name)
	local newMod = mod:NewModule(GetSlug(name), ...)
	newMod.instance = strtrim(instance)
	newMod.encounter = encounter and strtrim(encounter)
	return newMod 
end

function mod:GetOptions()
	local options = { args = { } }
	local BZ = LibStub('LibBabble-Zone-3.0', true)
	local BB = LibStub('LibBabble-Boss-3.0', true)
	local LBZ = BZ and BZ:GetUnstrictLookupTable() or {}
	local LBB = BZ and BB:GetUnstrictLookupTable() or {}
	local instances = {}
	for name, module in self:IterateModules() do
		local instance, encounter = module.instance, module.encounter
		local instanceOpts = instances[instance]
		if not instanceOpts then
			instanceOpts = {
				name = LBZ[instance] or instance,
				type = 'group',
				args = {},
			}
			instances[instance] = instanceOpts
			options.args[GetSlug(instance)] = instanceOpts
		end
		local rawOpts = module.GetOptions and module:GetOptions() or {}
		local opts = addon.DecorateOptions(module, rawOpts)
		opts.inline = true
		if encounter then
			opts.name = LBB[encounter] or encounter
			instanceOpts.args[GetSlug(encounter)] = opts
		else
			opts.name = L["General"]
			opts.order = 5
			instanceOpts.args.general = opts
		end
	end
	return options
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function GetMobID(guid)
	if guid then
	-- 0x??A?BBBBB??????? with B being the NPC id if the GUID type (A) is either 3 or B
		local mobID = strmatch(guid, "0x%x%x[3B]%x(%x%x%x%x%x)%x%x%x%x%x%x%x")
		if mobID then
			return tonumber(mobID, 16)
		end
	end
end

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

moduleProto.core = mod

moduleProto.default_db = { profile = { } }

mod:SetDefaultModulePrototype(moduleProto)
mod:SetDefaultModuleState(false)
mod:SetDefaultModuleLibraries('LibCombatLogEvent-1.0', 'AceEvent-3.0', 'AceTimer-3.0')

function moduleProto:ShouldEnable()
	if addon.moduleProto.ShouldEnable(self) then
		if self.maps and self.maps[GetMapInfo()] then
			return true
		end
		if self.mobs then
			for i = 1, 4 do
				local id = GetMobID(UnitGUID("boss"..i))
				if self.mobs[id] then
					return true
				end
			end
		end
	end
	return false
end

-- Definition helpers

local function MergeSet(self, key, ...)
	local t = self[key]
	if not t then
		t = {}
		self[key] = t
	end
	for i = 1, select('#', ...) do
		local value = select(i, ...)
		t[value] = true
	end
	return self
end

local function MergeDict(self, key, ...)
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
		data = {}
	end
	local spellId = ...
	data.spellId = spellId
	data.key = key..spellId
	self.default_db.profile[data.key] = true
	for i = 1, n do
		t[select(i, ...)] = data
	end
	return self
end

function moduleProto:AgainstMobs(...) return MergeSet(self, "mobs", ...) end
function moduleProto:InMaps(...) return MergeSet(self, "maps", ...) end

function moduleProto:WatchAuras(...) return MergeDict(self, "auras", ...) end
function moduleProto:WatchSpellCasts(...) return MergeDict(self, "spellCasts", ...) end

-- Enabling

function moduleProto:PostInitialize()
	local function UpdateEnabledState(...) return self:UpdateEnabledState(...) end
	self.RegisterEvent(self.name, 'PLAYER_ENTERING_WORLD', UpdateEnabledState)
	if self.mobs then
		self.RegisterEvent(self.name, 'INSTANCE_ENCOUNTER_ENGAGE_UNIT', UpdateEnabledState)
	end
	if self.maps then
		self.RegisterMessage(self.name, 'AdiProx_MapChanged', UpdateEnabledState)
	end
end

function moduleProto:PostEnable()
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

function moduleProto:GetAura(spellId)
	local aura = self.auras[spellId]
	if aura and self.db.profile[aura.key] then
		return aura
	end
end

function moduleProto:GetSpellCast(spellId)
	local spell = self.spellCasts[spellId]
	if spell and self.db.profile[spell.key] then
		return spell
	end
end

function moduleProto:SPELL_AURA_APPLIED(event, args)
	local aura = self:GetAura(args.spellId)
	if aura then
		local color = aura.color or GetDebuffColor(args.spellId) or GetSchoolColor(args.spellSchool)
		local widget, position = self:PlaceMarker(aura.key, args.destGUID, aura.static, aura.marker, color, aura.range, aura.duration)
		if widget and self.PostAuraApplied then
			self:PostAuraApplied(event, args, position, widget)
		end
	end
end

function moduleProto:SPELL_AURA_REMOVED(event, args)
	local aura = self:GetAura(args.spellId)
	if aura then
		local position = addon:GetUnitPosition(args.destGUID)
		if position then
			local widget = position:Detach(aura.key)
			if widget and self.PostAuraRemoved then
				self:PostAuraRemoved(event, args, position, widget)
			end
		end
	end
end

function moduleProto:SPELL_CAST_START(event, args)
	local spell = self:GetSpellCast(args.spellId)
	if spell then
		wipe(self.currentCast)
		for k, v in pairs(args) do
			self.currentCast[k] = v
		end
		self:ScheduleTimer("GetSpellCastTarget", spell.targetDelay or 0.1, self.currentCast)
	end
end

function moduleProto:SPELL_CAST_SUCCESS(event, args)
	if self:GetSpellCast(args.spellId) then
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
	if self:GetSpellCast(args.spellId).atEnd then
		self:ScheduleTimer("OnSpellCastEnd", duration, args)
	else
		self:OnSpellCast(args.event, args, duration)
	end
end

function moduleProto:OnSpellCastEnd(args)
	return self:OnSpellCast(args.event, args, 1)
end

function moduleProto:OnSpellCast(event, args, duration)
	local spell = self:GetSpellCast(args.spellId)
	if spell then
		local color = spell.color or GetSchoolColor(args.spellSchool) or GetDebuffColor(args.spellID)
		local widget, position = self:PlaceMarker(spell.key, args.destGUID, spell.static, spell.marker, color, spell.range, spell.duration or duration)
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

function moduleProto:GetOptions()
	local spells = {}
	if self.auras then
		for _, aura in pairs(self.auras) do
			if not spells[aura.key] then
				spells[aura.key] = {
					name = GetSpellInfo(aura.spellId) or ('#'..aura.spellId),
					type = 'toggle'
				}
			end
		end
	end
	if self.spellCasts then
		for _, spell in pairs(self.spellCasts) do
			if not spells[spell.key] then
				spells[spell.key] = {
					name = GetSpellInfo(spell.spellId) or ('#'..spell.spellId),
					type = 'toggle'
				}
			end
		end
	end
	if next(spells) then
		return { args = spells }
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
