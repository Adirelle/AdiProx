--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('Group', 'AceEvent-3.0')

function mod:OnEnable()
	self:RegisterMessage('AdiProx_GroupChanged', "Update")
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

--------------------------------------------------------------------------------
-- Party widgets
--------------------------------------------------------------------------------

local partyWidgetProto, parentProto = addon.NewWidgetType('player_blip', 'abstract')
partyWidgetProto.frameLevel = 8

local AceEvent = LibStub('AceEvent-3.0')

function partyWidgetProto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(8, 8)

	local icon = frame:CreateTexture(nil, "OVERLAY")
	icon:SetPoint("CENTER")
	self.Icon = icon
	
	local targetRing = addon:CreateTexture(frame, nil, "OVERLAY")
	targetRing:SetTexture("ring")
	targetRing:SetPoint("CENTER")
	targetRing:SetSize(16, 16)
	self.TargetRing = targetRing

	local name = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
	name:SetPoint("BOTTOM", icon, "CENTER", 0, 8)
	self.Name = name

	return frame
end

function partyWidgetProto:Update()
	local unit = self.unit
	if not unit then return end
	local r, g, b = addon.ParseColor(select(2, UnitClass(unit)))

	local name = self.Name
	name:SetText(UnitName(unit))
	name:SetTextColor(r, g, b, 0.75)
	self:OnAlertChanged()

	local symbol = GetRaidTargetIndex(unit)
	local icon = self.Icon
	if symbol and symbol > 0 then
		icon:SetTexture([[Interface\TargetingFrame\UI-RaidTargetingIcon_]]..symbol)
		icon:SetTexCoord(0, 1, 0, 1)
		icon:SetVertexColor(1, 1, 1, 1)
		icon:SetSize(8, 8)
	else
		icon:SetTexture([[Interface\Minimap\PartyRaidBlips]])
		icon:SetTexCoord(0.875, 1, 0.25, 0.5)
		icon:SetVertexColor(r, g, b, 1)
		icon:SetSize(16, 16)
	end
	
	self:PLAYER_TARGET_CHANGED()
end

function partyWidgetProto:OnPositionChanged()
	local unit = self.position and self.position.unit
	if unit ~= self.unit then
		self:Debug('OnPositionChanged', unit)
		if unit and not self.unit then
			AceEvent.RegisterEvent(self, 'UNIT_NAME_UPDATE', 'OnUnitEvent')
			AceEvent.RegisterEvent(self, 'RAID_TARGET_UPDATE', 'Update')
			AceEvent.RegisterEvent(self, 'PARTY_MEMBERS_CHANGED', 'Update')
			AceEvent.RegisterEvent(self, 'PLAYER_TARGET_CHANGED')
		elseif not unit and self.unit then
			AceEvent.UnregisterEvent(self, 'UNIT_NAME_UPDATE')
			AceEvent.UnregisterEvent(self, 'RAID_TARGET_UPDATE')
			AceEvent.UnregisterEvent(self, 'PARTY_MEMBERS_CHANGED')
			AceEvent.UnregisterEvent(self, 'PLAYER_TARGET_CHANGED')
		end
		self.unit = unit
		self:Update()
	end
end

function partyWidgetProto:OnAlertChanged()
	if self.alert then
		self.Name:Show()
	else
		self.Name:Hide()
	end
end

function partyWidgetProto:PLAYER_TARGET_CHANGED()
	if self.unit and UnitIsUnit(self.unit, "target") then
		self.TargetRing:Show()
		self:SetImportant(true)
	else
		self.TargetRing:Hide()
		self:SetImportant(false)
	end
end

function partyWidgetProto:OnUnitEvent(event, unit)
	if unit == self.unit then
		return self:Update()
	end
end

