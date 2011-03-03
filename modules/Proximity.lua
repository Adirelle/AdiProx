--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('Proximity', 'AceConsole-3.0')

function mod:PostInitialize()
	self:RegisterChatCommand("aprox", "ChatCommand", true)
	LibStub('AceEvent-3.0').RegisterMessage(self.name, 'AdiProx_SetProximity', function(...) return self:AdiProx_SetProximity(...) end)
	self.userRange, self.modRange = nil, nil
end

function mod:ShouldEnable()
	if self.core.moduleProto.ShouldEnable(self) then
		return self.userRange or self.modRange
	end
end

function mod:SetRange(attr, value)
	value = tonumber(value)
	if value == 0 then
		value = nil
	end
	if value ~= self[attr] then
		self:Debug('SetRange(', attr, value, ')')
		self[attr] = value
		if self:UpdateEnabledState() then
			self:UpdateRange()
		end
	end
end

function mod:ChatCommand(value)
	return self:SetRange('userRange', value)
end

function mod:AdiProx_SetProximity(_, value)
	return self:SetRange('modRange', value)
end

function mod:UpdateRange()
	local range = self.userRange or self.modRange
	self:Debug('UpdateRange:', range)
	local pos = addon:GetUnitPosition("player")
	local widget = pos:GetWidget("proximity")
	if widget then
		widget:SetRange(range)
		self:Debug('UpdatingRange:')
	else
		pos:Attach("proximity", self:AcquireWidget("proximity", range))
	end
end

--------------------------------------------------------------------------------
-- Proximity widget
--------------------------------------------------------------------------------

local proximityProto, parentProto = addon.NewWidgetType("proximity", "abstract")
proximityProto.layerLevel = 2

function proximityProto:OnAcquire(range)
	self.pixelsPerYard, self.range = nil, nil
	parentProto.OnAcquire(self)
	self:SetRange(range)
end

function proximityProto:CreateFrame(parent)
	local t = addon:CreateTexture(parent, nil, "OVERLAY")
	t:SetTexture("radius_lg")
	return t
end

function proximityProto:SetRange(range)
	local reverse = range < 0
	if reverse then
		range = -range
	end
	self:SetAlertRadius(range, reverse)
	if self.range ~= range then
		self.range = range
		self.pixelsPerYard = nil
		addon.forceUpdate = true
	end
	return self
end

function proximityProto:OnAlertChanged()
	if self.alert then
		self.frame:SetVertexColor(1, 0, 0)
	else
		self.frame:SetVertexColor(0, 1, 0)
	end
end

function proximityProto:SetPoint(x, y, pixelsPerYard, ...)
	parentProto.SetPoint(self, x, y, pixelsPerYard, ...)
	if pixelsPerYard ~= self.pixelsPerYard then
		self.pixelsPerYard = pixelsPerYard
		local size = 2 * self.range * pixelsPerYard
		self.frame:SetSize(size, size)
	end
end
