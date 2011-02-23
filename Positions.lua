--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L
local LibMapData = LibStub('LibMapData-1.0')

--------------------------------------------------------------------------------
-- Acquiring positions
--------------------------------------------------------------------------------

local activePositions = {}

function addon:IterateActivePositions()
	return pairs(activePositions)
end

local function AcquirePosition(meta, ...)
	local heap = meta.__index.heap
	local position = next(heap)
	if not position then
		position = setmetatable({}, meta)
		position:OnCreate()
	else
		heap[position] = nil
	end
	activePositions[position] = true
	position:OnAcquire(...)
	return position
end

--------------------------------------------------------------------------------
-- Abstract position
--------------------------------------------------------------------------------

local positionProto = { Debug = addon.Debug  }
local positionMeta = { __index = positionProto }

function positionProto:OnCreate()
	self.widgets = {}
end

function positionProto:OnAcquire()
	self:Debug('Acquired')
end

function positionProto:Release()
	if activePositions[self] then
		activePositions[self] = nil
		for name, widget in pairs(self.widgets) do
			self.widgets[name] = nil
			widget:SetPosition(nil)
		end
		self:OnRelease()
		self.heap[self] = true
	end
end

function positionProto:OnRelease()
	self:Debug('Released')
end

function positionProto:Attach(name, widget)
	local oldWidget = self.widgets[name]
	if oldWidget ~= widget then
		self.widgets[name] = widget
		if oldWidget then
			oldWidget:SetPosition(nil)
		end
		if widget then
			widget:SetPosition(self)
		end
		return true
	end
end

function positionProto:Detach(widget)
	for name, w in pairs(self.widgets) do
		if w == widget then
			self.widgets[name] = nil
			widget:SetPosition(nil)
			return true
		end
	end
end

function positionProto:GetWidget(name)
	return self.widgets[name]
end

function positionProto:IterateWidgets()
	return pairs(self.widgets)
end

function positionProto:SetAlertCondition(distance, invert)
	self.alertDistance, self.alertInvert = distance, invert
end

function positionProto:GetAlertCondition()
	return self.alertDistance, self.alertInvert
end

function positionProto:SetAlert(alert)
	if alert ~= self.alert then
		self.alert = alert
		for name, widget in pairs(self.widgets) do
			widget:SetAlert(alert)
		end
	end
end

local cos, sin, max, abs = math.cos, math.sin, math.max, math.abs
function positionProto:UpdateRelativeCoords(playerX, playerY, rotangle, maxZoomRange)
	local state, distance, zoomRange, relX, relY = "invalid"
	local mapX, mapY = self:GetMapCoords()
	if mapX and mapY then
		local dx, dy
		distance, dx, dy = LibMapData:Distance(addon.currentMap, addon.currentFloor, playerX, playerY, mapX, mapY)
		relX = (dx * cos(rotangle)) - (-1 * dy * sin(rotangle))
		relY = (dx * sin(rotangle)) + (-1 * dy * cos(rotangle))
		zoomRange = max(abs(relX), abs(relY))
		if zoomRange <= maxZoomRange then
			state = "in_range"
		else
			local f = maxZoomRange / zoomRange
			state, relX, relY = "on_edge", relX * f, relY * f			
		end
	end
	self.state, self.distance, self.zoomRange, self.relX, self.relY = state, distance, zoomRange, relX, relY
	return state, distance, zoomRange
end

function positionProto:UpdateWidgets(pixelsPerYard, now)
	local hasImportant = false
	for name, widget in pairs(self.widgets) do
		widget:OnUpdate(now)
		if widget:IsImportant() then
			hasImportant = true
		end
	end
	if self.state == "invalid" or self.state == "on_edge" and not hasImportant then
		for name, widget in pairs(self.widgets) do
			widget:Hide()
		end
	else
		local distance, x, y = self.distance, self.relX * pixelsPerYard, self.relY * pixelsPerYard
		for name, widget in pairs(self.widgets) do
			if widget:ShouldBeShown() then
				widget:Show()
				widget:SetPoint(x, y, pixelsPerYard, distance)
			else
				widget:Hide()
			end
		end
		return hasImportant
	end
end

--------------------------------------------------------------------------------
-- Static position
--------------------------------------------------------------------------------

local staticPositionProto = setmetatable({ heap = {} }, positionMeta)
local staticPositionMeta = { __index = staticPositionProto }

function staticPositionProto:OnAcquire(x, y, map, floor)
	assert(type(x) == "number")
	assert(type(y) == "number")
	if not map then
		self.map, self.floor = addon.currentMap, addon.currentFloor
	else
		self.map, self.floor = map, floor
	end
	self.x = x
	self.y = y
	positionProto.OnAcquire(self)
end

function staticPositionProto:Detach(widget)
	if positionProto.Detach(self, widget) then
		if not next(self.widgets) then
			self:Release()
		end
		return true
	end
end

function staticPositionProto:GetName()
	return format('static(%.2f,%.2f,%s,%s)', (self.x or 0), (self.y or 0), tostring(self.map), tostring(self.floor))
end

function staticPositionProto:GetMapCoords()
	if self.map == addon.currentMap and self.floor == addon.currentFloor then
		return self.x, self.y
	end
end

function addon:GetStaticPosition(x, y, map, floor)
	return AcquirePosition(staticPositionMeta, x, y, map, floor)
end

--------------------------------------------------------------------------------
-- Unit position
--------------------------------------------------------------------------------

local unitPositions = {}
local AceEvent = LibStub('AceEvent-3.0')

local unitPositionProto = setmetatable({ heap = {} }, positionMeta)
local unitPositionMeta = { __index = unitPositionProto }

function unitPositionProto:OnAcquire(unit)
	assert(type(unit) == "string", "UnitPosition: invalid unit"..tostring(unit))
	unitPositions[unit] = self
	self.unit = unit
	positionProto.OnAcquire(self)
end

function unitPositionProto:OnRelease()
	unitPositions[self.unit] = nil
	positionProto.OnRelease(self)
end

function unitPositionProto:GetName()
	return format("unit(%s)", tostring(self.unit))
end

function unitPositionProto:GetMapCoords()
	local unit = self.unit
	if UnitIsConnected(unit) and UnitInPhase(unit) then
		local x, y = GetPlayerMapPosition(unit)
		if x ~= 0 and y ~= 0 then
			return x, y
		end
	end
end

function unitPositionProto:GetStaticPosition()
	return AcquirePosition(staticPositionMeta, self:GetMapCoords())
end

--------------------------------------------------------------------------------
-- Player position
--------------------------------------------------------------------------------

local playerPositionProto = setmetatable({}, unitPositionMeta)
local playerPositionMeta = { __index = playerPositionProto }

function playerPositionProto:OnAcquire()
	unitPositionProto.OnAcquire(self, "player")
	self.visible, self.distance, self.relX, self.relY = true, 0, 0, 0
end

function playerPositionProto:UpdateRelativeCoords(playerX, playerY, rotangle)
	return true, 0
end

--------------------------------------------------------------------------------
-- Group and unit handling
--------------------------------------------------------------------------------

local GetNumRaidMembers, GetNumPartyMembers, UnitGUID, UnitExists = GetNumRaidMembers, GetNumPartyMembers, UnitGUID, UnitExists

local guidToUnit = {}

setmetatable(unitPositions, { __index = function(t, unit)
	if unit then
		local position = AcquirePosition(unit == "player" and playerPositionMeta or unitPositionMeta, unit)
		t[unit] = position
		return position
	end
end})

function addon.GetGUIDUnit(guid)
	return guid and guidToUnit[guid]
end

function addon.GetNormalizedUnit(unit)
	return guidToUnit[unit and UnitGUID(unit)]
end

function addon:GetUnitPosition(unit)
	return unitPositions[guidToUnit[unit and UnitGUID(unit) or unit]]
end

function addon:PARTY_MEMBERS_CHANGED()
	local groupType, groupSize = "raid", GetNumRaidMembers()
	if groupSize == 0 then
		groupType, groupSize = "party", GetNumPartyMembers()
		if groupSize == 0 then
			groupType = "none"
		end
	end
	if groupType ~= self.groupType or groupSize ~= self.groupSize then
		wipe(guidToUnit)
		for i = 1, groupSize do
			local unit = groupType .. i
			guidToUnit[UnitGUID(unit)] = unit
		end
		guidToUnit[UnitGUID("player")] = "player"
		for unit, position in pairs(unitPositions) do
			if position == false then
				unitPositions[unit] = nil
			elseif (not UnitExists(unit) or unit ~= guidToUnit[UnitGUID(unit)]) then
				position:Release()
			end
		end
		self.groupType, self.groupSize = groupType, groupSize
		self:SendMessage('AdiProx_GroupChanged')
	end
end


