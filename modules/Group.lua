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

function mod:OnDisable()
	self:ReleaseAllWidgets()
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

	local icon = frame:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("CENTER")
	self.icon = icon

	local name = frame:CreateFontstring(nil, "ARTWORK", "SystemFont_Shadow_Small")
	name:SetPoint("BOTTOM", icon, "CENTER", 0, 8)
	self.name = name

	return frame
end

function partyWidgetProto:Update()
	local unit = self.unit
	local _, class = UnitClass(unit)	
	local color = classColors[unit]
	
	self.name:SetText(UnitName(unit))
	self.name:SetTextColor(color.r, color.g, color.b)
	self:OnAlertChanged()
	
	local symbol = GetRaidTargetIndex(unit)
	if symbol and symbol > 0 then
		self.icon:SetTexture([[TargetingFrame\TargetingFrame\UI-RaidTargetingIcon_]]..symbol)
		self.icon:SetTexCoord(0, 1, 0, 1)
		self.icon:SetVertexColor(1, 1, 1, 1)
		self.icon:SetSize(16, 16)
	else
		self.icon:SetTexture([[Interface\Minimap\PartyRaidBlips]])
		self.icon:SetTexCoord(0.875, 1, 0.25, 0.5)
		self.icon:SetVertexColor(color.r, color.g, color.b ,1)
		self.icon:SetSize(32, 32)
	end
end

function partyWidgetProto:OnPositionChanged()
	local unit = self.position and self.position.unit
	if unit ~= self.unit then
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
		self.name:Show()
	else
		self.name:Hide()
	end
end

function partyWidgetProto:OnUnitEvent(event, unit)
	if unit == self.unit then
		return self:Update()
	end
end
