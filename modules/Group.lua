--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local classColors

local mod = addon:NewModule('Group', 'AceEvent-3.0')

function mod:OnInitialize()
	if CUSTOM_CLASS_COLORS then
		classColors = CUSTOM_CLASS_COLORS
		classColors:RegisterCallback(function() if self:IsEnabled() then self:Update() end end)
	else
		classColors = RAID_CLASS_COLORS
	end
end

function mod:OnEnable()
	self:RegisterMessage('AdiProx_GroupChanged', "Update")
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
local AceEvent = LibStub('AceEvent-3.0')

function partyWidgetProto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(8, 8)

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	self.Icon = icon

	local name = frame:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Small")
	name:SetPoint("BOTTOM", icon, "CENTER", 0, 8)
	self.Name = name

	return frame
end

function partyWidgetProto:Update()
	local unit = self.unit
	if not unit then return end
	local _, class = UnitClass(unit)
	local color = classColors[class]

	local name = self.Name
	name:SetText(UnitName(unit))
	if color then
		name:SetTextColor(color.r, color.g, color.b)
	end
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
		if color then
			icon:SetVertexColor(color.r, color.g, color.b ,1)
		end
		icon:SetSize(16, 16)
	end
end

function partyWidgetProto:OnPositionChanged()
	local unit = self.position and self.position.unit
	if unit ~= self.unit then
		self:Debug('OnPositionChanged', unit)
		if unit and not self.unit then
			AceEvent.RegisterEvent(self, 'UNIT_NAME_UPDATE', 'OnUnitEvent')
			AceEvent.RegisterEvent(self, 'RAID_TARGET_UPDATE', 'Update')
			AceEvent.RegisterEvent(self, 'PARTY_MEMBERS_CHANGED', 'Update')
		elseif not unit and self.unit then
			AceEvent.UnregisterEvent(self, 'UNIT_NAME_UPDATE')
			AceEvent.UnregisterEvent(self, 'RAID_TARGET_UPDATE')
			AceEvent.UnregisterEvent(self, 'PARTY_MEMBERS_CHANGED')
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

function partyWidgetProto:OnUnitEvent(event, unit)
	if unit == self.unit then
		return self:Update()
	end
end
