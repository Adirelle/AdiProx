--[[
LibCombatLogEvent-1.0 - Combat log event dispatcher.
Copyright (C) 2011 Adirelle

All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice,
      this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice,
      this list of conditions and the following disclaimer in the documentation
      and/or other materials provided with the distribution.
    * Redistribution of a stand alone version is strictly prohibited without
      prior written authorization from the LibCombatLogEvent project manager.
    * Neither the name of the LibCombatLogEvent authors nor the names of its contributors
      may be used to endorse or promote products derived from this software without
      specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--]]

local MAJOR, MINOR = "LibCombatLogEvent-1.0", 1
assert(LibStub, MAJOR.." requires LibStub")
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- ----------------------------------------------------------------------------
-- Library data
-- ----------------------------------------------------------------------------

-- The frame that handles the event
lib.eventFrame = lib.eventFrame or CreateFrame("Frame")

-- Registered combat log events
lib.registeredEvents = lib.registeredEvents or {}

-- Objects that embed the library
lib.embeds = lib.embeds or {}

-- The callback handler
lib.callbacks = lib.callbacks or LibStub('CallbackHandler-1.0'):New(lib, "RegisterCombatLogEvent", "UnregisterCombatLogEvent", "UnregisterAllCombatLogEvents")

-- The event table, that will be filled with event arguments
lib.evt = lib.evt or {}

-- Functions to fill the event table, indexed by event arguments
lib.fillersByArgs = lib.fillersByArgs or {}

-- Functions to fill then event table, indexed by event names
lib.fillersByEvent = lib.fillersByEvent or {}

-- ----------------------------------------------------------------------------
-- Combat event dispatching
-- ----------------------------------------------------------------------------

local registeredEvents = lib.registeredEvents
local callbacks = lib.callbacks
local fillersByEvent = lib.fillersByEvent
local evt = lib.evt

-- Register COMBAT_LOG_EVENT_UNFILTERED when the first combat event is registered
function callbacks:OnUsed(_, event)
	if not next(registeredEvents) then
		lib.eventFrame:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	end
	registeredEvents[event] = true
end

-- Unregister COMBAT_LOG_EVENT_UNFILTERED when that last combat event is unregistered
function callbacks:OnUnused(_, event)
	registeredEvents[event] = nil
	if not next(registeredEvents) then
		lib.eventFrame:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	end
end

-- Dispatch the combat log event
lib.eventFrame:SetScript('OnEvent', function(_, _, _, event, ...)
	if registeredEvents[event] then
		callbacks:Fire(event, fillersByEvent[event](evt, event, ...))
	end
end)

-- ----------------------------------------------------------------------------
-- Event table fillers
-- ----------------------------------------------------------------------------

-- Arguments associated with each event name prefix
local prefixes = {
	SWING = "",
	RANGE = ",spellId,spellName,spellSchool",
	SPELL = ",spellId,spellName,spellSchool",
	SPELL_PERIODIC = ",spellId,spellName,spellSchool",
	SPELL_BUILDING = ",spellId,spellName,spellSchool",
	ENVIRONMENTAL = ",environmentalType",
}

-- Arguments associated with each event name suffix
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

-- Events that do not follow the prefix_suffix naming scheme
local aliases = {
	DAMAGE_SHIELD = "SPELL_DAMAGE",
	DAMAGE_SPLIT = "SPELL_DAMAGE",
	DAMAGE_SHIELD_MISSED = "SPELL_MISSED",
}

-- This is used to create the filler functions depending on the argument list
setmetatable(lib.fillersByArgs, {__index = function(self, args)
	local body = format("return function(e,%s) wipe(e) e.%s = %s return e end", args, gsub(args, ",", ",e."), args)
	local result = loadstring(body, args)()
	self[args] = result
	return result
end})

-- This is used to create the filler functions depending on the argument name
setmetatable(fillersByEvent, {__index = function(self, event)
	local args = "event,sourceGUID,sourceName,sourceFlags,destGUID,destName,destFlags"
	event = aliases[event] or event
	for prefix, prefixArgs in pairs(prefixes) do
		local len = strlen(prefix)
		if strsub(event, 1, len) == prefix then
			local suffixArgs = suffixes[strsub(event, len + 2)]
			if suffixArgs then
				args = args..prefixArgs..suffixArgs
				break
			end
		end
	end
	local filler = lib.fillersByArgs[args]
	self[event] = filler
	return filler
end})

-- ----------------------------------------------------------------------------
-- Mixin and embeding
-- ----------------------------------------------------------------------------

local embeds = lib.embeds
local mixins = { "RegisterCombatLogEvent", "UnregisterCombatLogEvent",
	"UnregisterAllCombatLogEvents" }

-- Inject our methods into the target
function lib:Embed(target)
	for _, name in pairs(mixins) do
		target[name] = lib[name]
	end
	embeds[target] = true
end

-- Unregister all events from the target
function lib:OnEmbedDisable(target)
	target:UnregisterAllCombatLogEvents()
end

-- Updated previously registered targets
for target in pairs(embeds) do
	lib:Embed(target)
end


