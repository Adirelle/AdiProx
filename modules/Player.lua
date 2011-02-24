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

function proto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints(parent)

	local arrow = frame:CreateTexture(nil, "ARTWORK")	
	arrow:SetTexture([[Interface\Minimap\MinimapArrow]])
	arrow:SetSize(32, 32)
	arrow:SetPoint("CENTER")
	
	local text = frame:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Small")
	text:SetTextColor(0.7, 0.7, 0.7, 0.5)
	text:SetPoint("BOTTOMRIGHT")
	self.Text = text

	self.ticks = {}
	for i, v in ipairs{{1,0}, {0,1}, {-1, 0}, {0, -1}} do
		local dx, dy = unpack(v)
		for dist = 20, addon.MAX_ZOOM, 20 do
			local tick = frame:CreateTexture(nil, "BACKGROUND")
			tick:SetTexture(0.7, 0.7, 0.7, 0.5)
			local size = dist == 40 and 9 or 5
			if dx ~= 0 then
				tick:SetSize(1, size)
			else
				tick:SetSize(size, 1)
			end
			tick.x, tick.y = dist * dx, dist * dy
			self.ticks[tick] = true
		end
	end

	return frame
end

function proto:SetPoint(x, y, pixelsPerYard, distance, zoomRange)	
	if pixelsPerYard ~= self.pixelsPerYard then
		self.pixelsPerYard = pixelsPerYard
		for tick in pairs(self.ticks) do
			tick:SetPoint("CENTER", tick.x * pixelsPerYard, tick.y * pixelsPerYard)
		end
	end
	self.Text:SetFormattedText("%dm", ceil(zoomRange))
end
