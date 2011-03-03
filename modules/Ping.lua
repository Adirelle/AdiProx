--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local LibMapData = LibStub('LibMapData-1.0')

local mod = addon:NewModule('Ping', 'AceEvent-3.0')

mod.default_db = {
	profile = {
		showName = true,
	}
}

local prefs

function mod:PostEnable()
	prefs = self.db.profile
	self:RegisterEvent('MINIMAP_PING')
	self:RegisterEvent('MINIMAP_UPDATE_ZOOM')
	self:MINIMAP_UPDATE_ZOOM()
end

function mod:GetOptions()
	return {
		args = {
			showName = {
				name = L['Show pinger name'],
				type = 'toggle',
			}
		}
	}
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
pingWidgetProto.layerLevel = 4

function pingWidgetProto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(16, 16)

	local name = frame:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Small")
	name:SetPoint("BOTTOM", frame, "CENTER", 0, 8)
	self.Name = name

	return frame
end

function pingWidgetProto:OnConfigChanged(...)
	parentProto.OnConfigChanged(self, ...)
	if prefs.showName then
		self.Name:Show()
	else
		self.Name:Hide()
	end
end

function pingWidgetProto:OnAcquire(x, y, sender)
	parentProto.OnAcquire(self)
	mod.widget = self
	
	local name = UnitName(sender)
	self.Name:SetText(name)
	self.Name:SetTextColor(addon.ParseColor(select(2, UnitClass(sender))))
	
	self:SetImportant(true):SetTracked(true):SetDuration(5)
	addon:GetStaticPosition(x, y):SetIgnoreAlert(true):Attach("ping", self)
	
	self:AcquireAnimation("reticle", "targeting", 16):Rotate(-360, 2)
	self:AcquireAnimation("circle", "targetcircle", 12):Pulse(1.5, 1)
end

function pingWidgetProto:OnRelease()
	parentProto.OnRelease(self)
	mod.widget = nil
end

