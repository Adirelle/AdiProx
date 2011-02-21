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

local positionProto = {}
local positionMeta = { __index = positionProto }

positionProto.Debug = addon.Debug

function positionProto:OnCreate()
	self.widgets = {}
end

function positionProto:OnAcquire()
end

function positionProto:Release()
	if activePositions[self] then
		activePositions[self] = nil
		for widget in pairs(self.widgets) do
			self:Detach(widget)
		end
		self:OnRelease()
		self.heap[self] = true
	end
end

function positionProto:OnRelease()
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
	end
end

local cos, sin = math.cos, math.sin, math.sqrt
function positionProto:UpdateRelativeCoords(playerX, playerY, rotangle)
	local mapX, mapY = self:GetMapCoords()
	if mapX and mapY then
		local dx, dy
		self.distance, dx, dy = LibMapData:Distance(addon.currentMap, addon.currentFloor, playerX, playerY, mapX, mapY)
		self.relX = (dx * cos(rotangle)) - (-1 * dy * sin(rotangle))
		self.relY = (dx * sin(rotangle)) + (-1 * dy * cos(rotangle))
		self.visible = true
	else
		self.visible = false
	end
	return self.visible, self.distance
end

function positionProto:UpdateWidgets(elapsed, pixelsPerYard)
	local showMe = false
	if self.visible then
		local alert, distance = self.alert, self.distance
		local x, y = self.relX * pixelsPerYard, self.relY * pixelsPerYard
		for name, widget in pairs(self.widgets) do
			widget:SetAlert(alert)
			local show, important = widget:OnUpdate(x, y, distance, elapsed, pixelsPerYard)
			if show then
				if important then
					showMe = true
				end
				widget:Show()
			else
				widget:Hide()
			end
		end
	else
		for name, widget in pairs(self.widgets) do
			widget:Hide()
		end
	end
	return showMe
end

--------------------------------------------------------------------------------
-- Static position
--------------------------------------------------------------------------------

local staticPositionProto = setmetatable({ heap = {} }, positionMeta)
local staticPositionMeta = { __index = staticPositionProto }

function staticPositionProto:OnAcquire(x, y, map, floor)
	assert(type(x) == "number")
	assert(type(y) == "number")
	positionProto.OnAcquire(self)
	if not map then
		self.map, self.floor = addon.currentMap, addon.currentFloor
	else
		self.map, self.floor = map, floor
	end
	self.x = x
	self.y = y
end

function staticPositionProto:Detach(widget)
	if positionProto.Detach(self, widget) then
		if not next(self.widgets) then
			self:Release()
		end
		return true
	end
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
	assert(type(unit) == "string")
	positionProto.OnAcquire(self)
	unitPositions[unit] = self
	self.unit = unit
	AceEvent.RegisterEvent(self, 'PARTY_MEMBERS_CHANGED')
end

function unitPositionProto:OnRelease()
	unitPositions[self.unit] = nil
	AceEvent.UnregisterAllEvents(self)
end

function unitPositionProto:PARTY_MEMBERS_CHANGED()
	if not UnitExists(self.unit) then
		return self:Release()
	end
end

function unitPositionProto:GetMapCoords()
	local unit = self.unit
	if UnitIsVisible(unit) and UnitIsConnected(unit) then
		local x, y = GetPlayerMapPosition(self.unit)
		if x ~= 0 and y ~= 0 then
			return x, y
		end
	end
end

function unitPositionProto:CreateStaticCoords()
	return addon:AcquirePlayerPosition(self:GetMapCoords())
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

local guidToUnit = {}

setmetatable(unitPositions, { __index = function(t, unit)
	local position = false
	if unit == "player" then
		position = AcquirePosition(playerPositionMeta, "player")
	elseif unit then
		position = AcquirePosition(unitPositionMeta, unit)
	end
	t[unit] = position
	return position
end})

function addon.GetNormalizedUnit(unit)
	return guidToUnit[unit and UnitGUID(unit)]
end

function addon:GetUnitPosition(unit)
	return unitPositions[guidToUnit[unit and UnitGUID(unit)]]
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
		self.groupType, self.groupSize = groupType, groupSize
		self:SendMessage('AdiProx_GroupChanged')
	end
end


