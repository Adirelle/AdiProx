--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('Group', 'AceEvent-3.0')

mod.default_db = {
	profile = {
		hideInCombat = true,
		highlightTarget = true,
		trackTarget = true,
		targetColor = { 0.98, 1.0, 0.36, 1.0 },
		showSymbols = true,
		trackSymbols = {
			['*'] = false
		},
		highlightFocus = true,
		trackFocus = true,
		focusColor = { 0.38, 1.0, 0.1, 1.0 },
	}
}

local prefs

function mod:PostEnable()
	prefs = self.db.profile
	self:RegisterMessage('AdiProx_GroupChanged', 'Update')
	self:RegisterMessage('AdiProx_ClassColorsChanged', 'Update')
	self:Update()
end

function mod:Update()
	local prefix, size = addon.groupType, addon.groupSize
	for i = 1, size do
		local unit = prefix..i
		if not UnitIsUnit(unit, "player") then
			local pos = addon:GetUnitPosition(unit)
			if not pos:GetWidget("player_blip") then
				pos:Attach("player_blip", self:AcquireWidget("player_blip"))
			end
		end
	end
end

function mod.GetOptions()
	return {
		name = L['Party/raid'],
		type = 'group',
		args = {
			hideInCombat = {
				name = L['Hide in combat'],
				type = 'toggle',
				order = 8,
			},
			target = {
				name = L['Target'],
				type = 'group',
				inline = true,
				order = 10,
				args = {
					highlightTarget = {
						name = L['Highlight'],
						type = 'toggle',
						order = 10,
					},
					trackTarget = {
						name = L['Track'],
						type = 'toggle',
						order = 20,
					},
					targetColor = {
						name = L['Highlight color'],
						type = 'color',
						hasAlpha = true,
						disabled = function() return not prefs.highlightTarget end,
					},
				}
			},
			focus = {
				name = L['Focus'],
				type = 'group',
				inline = true,
				order = 20,
				args = {
					highlightFocus = {
						name = L['Highlight'],
						type = 'toggle',
						order = 10,
					},
					trackFocus = {
						name = L['Track'],
						type = 'toggle',
						order = 20,
					},
					focusColor = {
						name = L['Highlight color'],
						type = 'color',
						hasAlpha = true,
						disabled = function() return not prefs.highlightFocus end,
					},					
				}
			},
			symbols = {
				name = L['Raid symbols'],
				type = 'group',			
				inline = true,
				order = 30,
				args = {
					showSymbols = {
						name = L['Show'],
						type = 'toggle',
						order = 10,
					},
					trackSymbols = {
						name = L['Track'],
						type = 'multiselect',
						values = {
							RAID_TARGET_1,
							RAID_TARGET_2,
							RAID_TARGET_3,
							RAID_TARGET_4,
							RAID_TARGET_5,
							RAID_TARGET_6,
							RAID_TARGET_7,
							RAID_TARGET_8,
						},
						order = 20,
					},
				},
			},
		},
	}
end

--------------------------------------------------------------------------------
-- Party widgets
--------------------------------------------------------------------------------

local partyWidgetProto, parentProto = addon.NewWidgetType('player_blip', 'abstract')
partyWidgetProto.layerLevel = 1

local AceEvent = LibStub('AceEvent-3.0')

function partyWidgetProto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(8, 8)

	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("CENTER")
	self.Icon = icon
	
	local highlight = addon:CreateTexture(frame, nil, "OVERLAY")
	highlight:SetTexture("smallcircle")
	highlight:SetPoint("CENTER")
	highlight:SetSize(16, 16)
	self.Highlight = highlight

	return frame
end

function partyWidgetProto:Update()
	local unit = self.unit
	if not unit then return end

	local symbol = prefs.showSymbols and GetRaidTargetIndex(unit)
	local icon = self.Icon
	if symbol then
		icon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcon_]]..symbol)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetVertexColor(1, 1, 1)
		icon:SetSize(12, 12)
	else
		icon:SetTexture([[Interface\Minimap\PartyRaidBlips]])
		icon:SetTexCoord(0.875, 1, 0.25, 0.5)
		icon:SetVertexColor(addon.ParseColor(select(2, UnitClass(unit))))
		icon:SetSize(16, 16)
	end
	
	return self:UpdateStatus()
end

function partyWidgetProto:OnConfigChanged()
	self:UpdateEvents()
	self:Update()
end

function partyWidgetProto:UpdateEvents()
	local unit = self.unit
	if not self.unit then
		AceEvent.UnregisterEvent(self, 'PARTY_MEMBERS_CHANGED')
		AceEvent.UnregisterEvent(self, 'PLAYER_TARGET_CHANGED')
		AceEvent.UnregisterEvent(self, 'PLAYER_FOCUS_CHANGED')
		AceEvent.UnregisterEvent(self, 'RAID_TARGET_UPDATE')
		return
	end
	AceEvent.RegisterEvent(self, 'PARTY_MEMBERS_CHANGED', 'Update')			
	if prefs.highlightTarget then
		AceEvent.RegisterEvent(self, 'PLAYER_TARGET_CHANGED', 'UpdateStatus')
	else
		AceEvent.UnregisterEvent(self, 'PLAYER_TARGET_CHANGED')
	end
	if prefs.highlightFocus then
		AceEvent.RegisterEvent(self, 'PLAYER_FOCUS_CHANGED', 'UpdateStatus')
	else
		AceEvent.UnregisterEvent(self, 'PLAYER_FOCUS_CHANGED')
	end	
	if prefs.showSymbols then		
		AceEvent.RegisterEvent(self, 'RAID_TARGET_UPDATE', 'Update')
	else
		AceEvent.UnregisterEvent(self, 'RAID_TARGET_UPDATE')
	end
end

function partyWidgetProto:UpdateStatus()
	local unit = self.unit
	if not unit then return end
	local isTarget, isFocus = UnitIsUnit(unit, "target"), UnitIsUnit(unit, "focus")
	local highlight, color
	if isTarget and prefs.highlightTarget then
		highlight, color = true, prefs.targetColor
	elseif isFocus and prefs.highlightFocus then
		highlight, color = true, prefs.focusColor
	end
	if highlight then
		self.Highlight:SetVertexColor(unpack(color))
		self.Highlight:Show()
	else
		self.Highlight:Hide()
	end
	self:SetImportant((isTarget and prefs.trackTarget) or (isFocus and prefs.trackFocus) or (prefs.trackSymbols[GetRaidTargetIndex(unit) or "none"]))
end

function partyWidgetProto:OnPositionChanged()
	local unit = self.position and self.position.unit
	if unit ~= self.unit then
		self:Debug('OnPositionChanged', unit)
		self.unit = unit
		self:UpdateEvents()
		if unit then		
			self:Update()
		end
	end
end

function partyWidgetProto:ShouldBeShown(onEdge)
	return self:IsActive() and (not prefs.hideInCombat or not UnitAffectingCombat("player") or self.important or self.position:GetAlert() or self.position.important)
end

