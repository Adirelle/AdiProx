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
	self.alert, self.ignoreAlert, self.important, self.showOnEdge, self.tracked = nil, nil, nil, nil, nil
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

function positionProto:Detach(toDetach, release)
	local name, widget
	if type(toDetach) == "string" then
		name, widget = toDetach, self.widgets[toDetach]
	else
		for key, value in pairs(self.widgets) do
			if value == toDetach then
				name, widget = key, value
				break
			end
		end
	end
	if widget then
		self.widgets[name] = nil
		if release then
			widget:Release()
		else
			widget:SetPosition(nil)
			return widget, name
		end
	end
end

function positionProto:GetWidget(name)
	return self.widgets[name]
end

function positionProto:IterateWidgets()
	return pairs(self.widgets)
end

function positionProto:UpdateAlerts(distance, defaultState)
	local ignore = self.ignoreAlert
	local alert = not ignore and defaultState or false
	for name, widget in pairs(self.widgets) do
		if not ignore and widget:TestAlert(distance) then
			widget:SetAlert(true)
			alert = true
		else
			widget:SetAlert(false)
		end
	end
	self:SetAlert(alert)
	return alert
end

function positionProto:SetAlert(alert)
	alert = not not alert
	if alert ~= self.alert then
		self.alert = alert
		addon.forceUpdate = true
	end
	return self
end

function positionProto:GetAlert()
	return self.alert
end

function positionProto:GetLabel()
	return nil
end

function positionProto:SetIgnoreAlert(ignore)
	ignore = not not ignore
	if self.ignoreAlert ~= ignore then
		self.ignoreAlert = ignore
		addon.forceUpdate = true
	end
	return self
end

function positionProto:GetIgnoreAlert()
	return self.ignoreAlert
end

local cos, sin, max, abs = math.cos, math.sin, math.max, math.abs
function positionProto:UpdateRelativeCoords(playerX, playerY, rotangle)
	local isValid, distance, zoomRange, relX, relY = false
	local mapX, mapY = self:GetMapCoords()
	if mapX and mapY then
		local dx, dy
		distance, dx, dy = LibMapData:Distance(addon.currentMap, addon.currentFloor, playerX, playerY, mapX, mapY)
		isValid = true
		relX = (dx * cos(rotangle)) - (-1 * dy * sin(rotangle))
		relY = (dx * sin(rotangle)) + (-1 * dy * cos(rotangle))
		zoomRange = max(abs(relX), abs(relY))
	end
	self.isValid, self.distance, self.zoomRange, self.relX, self.relY = isValid, distance, zoomRange, relX, relY
	return isValid, distance, zoomRange
end

function positionProto:UpdateFlags()
	local important, showOnEdge, tracked = false, false, false
	if self.isValid then
		for name, widget in pairs(self.widgets) do
			if widget:IsInAlert() then
				important, showOnEdge, tracked = true, true, true
				break
			else
				if widget:IsImportant() then
					important = true
				end
				if widget:IsShownOnEdge() then
					showOnEdge = true
				end
				if widget:IsTracked() then
					tracked = true
				end
			end
		end
	end
	self.important, self.showOnEdge, self.tracked = important, showOnEdge, tracked
	return important, tracked
end

function positionProto:IsInAlert()
	return self.alert
end

function positionProto:IsImportant()
	return self.important or self.alert
end

function positionProto:IsTracked()
	return self.tracked or self.alert
end

function positionProto:IsShownOnEdge()
	return self.showOnEdge or self.tracked or self.alert
end

local function DoLayoutWidget(self, x, y, pixelsPerYard, distance, zoomRange, onEdge)
	local showImportant
	for name, widget in pairs(self.widgets) do
		if widget:ShouldBeShown(onEdge) then
			widget:Show()
			widget:SetPoint(x, y, pixelsPerYard, distance, zoomRange, onEdge)
			if widget:IsImportant() then
				showImportant = true
			end
		else
			widget:Hide()
		end
	end
	return showImportant
end

function positionProto:LayoutWidgets(zoomRange, pixelsPerYard)
	if self.isValid then
		onEdge = self.zoomRange > zoomRange
		if not onEdge or self:IsShownOnEdge() then
			self.shown = true
			local x, y = self.relX * pixelsPerYard, self.relY * pixelsPerYard

			-- Show/hide the edge arrow
			if onEdge ~= self.onEdge then
				self.onEdge = onEdge
				if onEdge then
					if not self:GetWidget('edge_arrow') then
						self:Attach('edge_arrow', addon:AcquireWidget('edge_arrow'))
					end
				else
					self:Detach('edge_arrow', true)
				end
			end

			-- Show/hide the label
			local label = self:IsInAlert() and self:GetLabel()
			if label ~= self.shownLabel then
				self.shownLabel = label
				local widget = self:GetWidget('label')
				if label then
					if not widget then
						self:Attach('label', addon:AcquireWidget('label', label))
					else
						widget:SetLabel(label)
					end
				elseif widget then
					widget:Release()
				end
			end

			-- Do the layout
			return DoLayoutWidget(self, x, y, pixelsPerYard, distance, zoomRange, onEdge)
		end
	end

	-- Hide all
	if self.shown then
		self.shown, self.onEdge, self.shownLabel = nil, nil, nil
		self:Detach('label', true)
		self:Detach('edge_arrow', true)
		for name, widget in pairs(self.widgets) do
			widget:Hide()
		end
	end

end

--------------------------------------------------------------------------------
-- Static position
--------------------------------------------------------------------------------

local staticPositionProto = setmetatable({ heap = {} }, positionMeta)
local staticPositionMeta = { __index = staticPositionProto }

function staticPositionProto:OnAcquire(x, y, map, floor, label)
	assert(type(x) == "number")
	assert(type(y) == "number")
	if not map then
		self.map, self.floor = addon.currentMap, addon.currentFloor
	else
		self.map, self.floor = map, floor
	end
	self.x, self.y = x, y
	self:SetLabel(label)
	positionProto.OnAcquire(self)
end

function staticPositionProto:Detach(toDetach, release)
	local widget, name = positionProto.Detach(self, toDetach, release)
	if widget then
		if not next(self.widgets) then
			self:Release()
		end
		return widget, name
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

function staticPositionProto:SetLabel(label)
	if label and strtrim(label) ~= "" then
		self.label = label
	else
		self.label = nil
	end
end

function staticPositionProto:GetLabel()
	return self.label
end

function addon:GetStaticPosition(x, y, map, floor, label)
	return AcquirePosition(staticPositionMeta, x, y, map, floor, label)
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

local ParseColor = addon.ParseColor
function unitPositionProto:GetLabel()
	if self.unit then
		local name, _, class = UnitName(self.unit), UnitClass(self.unit)
		local r, g, b = ParseColor(class)
		return format("|cfff%02x%02x%02x%s|r", 255*r, 255*g, 255*b, name)
	end
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
	self.isValid, self.distance, self.relX, self.relY, self.zoomRange = true, 0, 0, 0, 0
end

function playerPositionProto:GetMapCoords()
	local x, y = GetPlayerMapPosition("player")
	if x ~= 0 and y ~= 0 then
		return x, y
	end
end

function playerPositionProto:UpdateRelativeCoords()
	return false -- NOOP
end

function playerPositionProto:ResetAlerts()
	self.alert = false
	for name, widget in pairs(self.widgets) do
		widget:SetAlert(false)
	end
end

function playerPositionProto:UpdateAlerts(distance)
	local alert = false
	for name, widget in pairs(self.widgets) do
		if widget:TestAlert(distance) then
			widget:SetAlert(true)
			self.alert = true
			alert = true
		end
	end
	return alert
end

function playerPositionProto:LayoutWidgets(zoomRange, pixelsPerYard)
	return DoLayoutWidget(self, 0, 0, pixelsPerYard, 0, zoomRange, false)
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
