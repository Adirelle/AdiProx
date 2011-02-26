--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local mod = addon:NewModule('Player')

function mod:OnEnable()
	self:Debug('OnEnable')
	addon:GetUnitPosition("player"):Attach("reticle", self:AcquireWidget("player_reticle"))
end

--------------------------------------------------------------------------------
-- Player reticle widget
--------------------------------------------------------------------------------

local proto, parentProto = addon.NewWidgetType('player_reticle', 'abstract')
proto.frameLevel = 10

function proto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)

	local arrow = frame:CreateTexture(nil, "OVERLAY")
	arrow:SetTexture([[Interface\Minimap\MinimapArrow]])
	arrow:SetSize(32, 32)
	arrow:SetPoint("CENTER")

	local text = frame:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small")
	text:SetTextColor(0.7, 0.7, 0.7, 0.5)
	text:SetPoint("BOTTOMRIGHT")
	self.Text = text

	self.Ticks = {}
	for i, v in ipairs{{1,0}, {0,1}, {-1, 0}, {0, -1}} do
		local dx, dy = unpack(v)
		for dist = 20, addon.MAX_ZOOM, 20 do
			local tick = frame:CreateTexture(nil, "BACKGROUND")
			local size, light = 5, 0.7
			if dist == 40 then
				size, light = 9, 1
			end
			tick.dist = dist
			tick:SetTexture(light, light, light, 0.5)
			if dx ~= 0 then
				tick:SetSize(1, size)
			else
				tick:SetSize(size, 1)
			end
			tick.x, tick.y = dist * dx, dist * dy
			self.Ticks[tick] = true
		end
	end

	return frame
end

function proto:SetPoint(x, y, pixelsPerYard, distance, zoomRange)	
	if pixelsPerYard ~= self.pixelsPerYard then
		self.pixelsPerYard = pixelsPerYard
		for tick in pairs(self.Ticks) do
			if tick.dist <= zoomRange then
				tick:SetPoint("CENTER", tick.x * pixelsPerYard, tick.y * pixelsPerYard)
				tick:Show()
			else
				tick:Hide()
			end
		end
	end
	if zoomRange ~= self._zoomRange then
		self._zoomRange = zoomRange
		self.Text:SetFormattedText("%dm", ceil(zoomRange))
	end
end
