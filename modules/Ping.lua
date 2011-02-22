--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('Ping', 'AceEvent-3.0')

local LibMapData = LibStub('LibMapData-1.0')

function mod:OnEnable()
	self:RegisterEvent('MINIMAP_PING')
	self:RegisterEvent('MINIMAP_UPDATE_ZOOM')
	self:MINIMAP_UPDATE_ZOOM()
end

function mod:MINIMAP_UPDATE_ZOOM()
	local zoom = Minimap:GetZoom()
	if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
		Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
	end
	self.minimapZoom = GetCVar("minimapZoom")+0 ~= Minimap:GetZoom() and "indoors" or "outdoors"
	Minimap:SetZoom(zoom)
end

local minimapSizes = {
	indoors = { 290, 230, 175, 119, 79, 49.8, },
	outdoors = { 450, 395, 326, 265, 198, 132 },
}

function mod:GetMinimapSize()
	local zoom = Minimap:GetZoom()
	if GetCVar("minimapZoom") == GetCVar("minimapInsideZoom") then
		Minimap:SetZoom(zoom < 2 and zoom + 1 or zoom - 1)
	end
	local size = minimapSizes[GetCVar("minimapZoom")+0 ~= Minimap:GetZoom() and "indoors" or "outdoors"][zoom + 1]
	Minimap:SetZoom(zoom)
	return size
end

local abs, atan2, cos, sin, sqrt = math.abs, math.atan2, math.cos, math.sin, math.sqrt
function mod:MINIMAP_PING(event, sender, dx, dy)
	if abs(dx) > 0.6 or abs(dy) > 0.6 then return end

	local px, py = GetPlayerMapPosition("player")
	if px == 0 and py == 0 then return end

	if GetCVarBool("rotateMinimap") then
		local bearing = GetPlayerFacing()
		local angle = atan2(dx, dy)
		local hyp = abs(sqrt((dx * dx) + (dy * dy)))
		dx = hyp * sin(angle - bearing)
		dy = hyp * cos(angle - bearing)
	end

	local diameter = self:GetMinimapSize()
	if self.widget then
		self.widget:Release()
	end
	
	local mx, my = LibMapData:YardsToPoint(addon.currentMap, addon.currentFloor, dx * diameter, dy * diameter)	
	self:AcquireWidget("minimap_ping", px + mx, py - my, sender)
end

--------------------------------------------------------------------------------
-- Ping widget
--------------------------------------------------------------------------------

local pingWidgetProto, parentProto = addon.NewWidgetType('minimap_ping', 'abstract')

function pingWidgetProto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(16, 16)

	local name = frame:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Small")
	name:SetPoint("BOTTOM", frame, "CENTER", 0, 8)
	self.Name = name

	return frame
end

function pingWidgetProto:OnAcquire(x, y, sender)
	parentProto.OnAcquire(self)
	mod.widget = self
	
	local name, color = UnitName(sender), addon:GetUnitColor(sender)
	self.Name:SetText(name)
	if color then
		self.Name:SetTextColor(color.r, color.g, color.b)
	else
		self.Name:SetTextColor(1, 1, 1)
	end
	
	self:SetImportant(true):SetDuration(5)
	addon:GetStaticPosition(x, y):Attach("ping", self)
	
	self.Icon1 = addon:AcquireAnimation(self.frame, [[Interface\Minimap\Ping\ping5]], 16, 1, 1, 1, 1, "ADD"):Rotate(-360, 2)
	self.Icon2 = addon:AcquireAnimation(self.frame, [[Interface\Minimap\Ping\ping2]], 12, 1, 1, 1, 1, "ADD"):Pulse(1.5, 1)
end

function pingWidgetProto:OnRelease()
	parentProto.OnRelease(self)
	self.Icon1:Release()
	self.Icon2:Release()
	mod.widget = nil
end

