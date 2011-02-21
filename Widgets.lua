--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

--------------------------------------------------------------------------------
-- Map widgets
--------------------------------------------------------------------------------

local activeWidgets = {}
local registry = {}

function addon.AcquireWidget(owner, typeName, ...)
	local meta = registry[typeName]
	local heap = meta.__index.heap
	local widget = next(heap)
	if widget then
		heap[widget] = nil
	else
		widget = setmetatable({}, meta)
		widget:OnCreate()
	end
	activeWidgets[widget] = owner
	widget:OnAcquire(...)
	return widget
end
addon.moduleProto.AcquireWidget = addon.AcquireWidget

function addon.ReleaseAllWidgets(owner)
	for widget, widgetOwner in pairs(activeWidgets) do
		if widgetOwner == owner then
			widget:Release()
		end
	end
end
addon.moduleProto.ReleaseAllWidgets = addon.ReleaseAllWidgets

local function NewWidgetType(typeName, parentName)
	local proto = { heap = {} }
	local meta = { __index = proto }
	registry[typeName] = meta
	if parentName then
		local parent = registry[parentName]
		assert(parent)
		setmetatable(proto, parent)
		return proto, parent.__index
	else
		return proto
	end
end
addon.NewWidgetType = NewWidgetType

--------------------------------------------------------------------------------
-- Abstract widget
--------------------------------------------------------------------------------

local widgetProto = NewWidgetType('abstract')

widgetProto.Debug = addon.Debug

function widgetProto:OnCreate()
	self.frame = self:CreateFrame(addon.container)
end

function widgetProto:Release()
	if activeWidgets[self] then
		activeWidgets[self] = nil
		self:OnRelease()
		self.heap[self] = true
	end
end

function widgetProto:OnAcquire()
	self.important = false
	self.alert = false
end

function widgetProto:OnRelease()
	self:SetPosition(nil)	
end

function widgetProto:Show()
	if not self.frame:IsShown() then
		self.frame:Show()
		addon.forceUpdate = true
	end
	return self
end

function widgetProto:Hide()
	if self.frame:IsShown() then
		self.frame:Hide()
		addon.forceUpdate = true
	end
	return self
end

function widgetProto:SetImportant(imporant)
	self.important = important
	return self
end

function widgetProto:SetAlert(alert)
	alert = not not alert
	if alert ~= self.alert then
		self.alert = alert
		self:OnAlertChanged()
	end
	return self
end

function widgetProto:OnAlertChanged()
end

function widgetProto:OnPositionChanged()	
end

function widgetProto:SetPosition(position)
	if position ~= self.position then
		local oldPosition = self.position
		self.position = position
		if oldPosition then
			oldPosition:Detach(self)
		end
		self.x, self.y = nil, nil
		self:OnPositionChanged()
		if position then
			self:Show()
		else
			self:Hide()
		end
	end
	return self
end

function widgetProto:OnUpdate(x, y)
	if x ~= self.x or y ~= self.y then
		self.x, self.y = x, y
		self.frame:SetPoint("CENTER", x, y)
	end
	return true, self.alert or self.important
end

--------------------------------------------------------------------------------
-- Icon widgets
--------------------------------------------------------------------------------

local iconWidgetProto = NewWidgetType('icon', 'abstract')

function iconWidgetProto:CreateFrame(parent)
	return parent:CreateTexture(nil, "ARTWORK")	
end

local function SetColor(c, r, g, b, a)
	if c[1] ~= r or c[2] ~= g or c[3] ~= b or c[4] ~= a then
		c[1], c[2], c[3], c[4] = r, g, b, a
		return true
	end
end

function iconWidgetProto:OnCreate()
	widgetProto.OnCreate(self)
	self.color = { 1, 1, 1, 1 }
	self.alertColor = { 1, 1, 1 }
end

function iconWidgetProto:OnAcquire()
	widgetProto.OnAcquire(self)
	SetColor(self.color, 1, 1, 1, 1)
	SetColor(self.alertColor, 1, 0, 0)
	self.frame:SetBlendMode("BLEND")
end

function iconWidgetProto:SetTexture(texture, blendMode)
	if texture ~= self.texture then
		self.texture = texture
		self.frame:SetTexture(texture)
	end
	if blendMode then
		self.frame:SetBlendMode(blendMode)
	end
	return self
end

function iconWidgetProto:SetColor(r, g, b, a)
	if SetColor(self.color, r, g, b, a or 1) then
		self:OnAlertChanged()
	end
	return self
end

function iconWidgetProto:SetAlertColor(r, g, b)
	if SetColor(self.alertColor, r, g, b) then
		self:OnAlertChanged()
	end
	return self
end

function iconWidgetProto:OnAlertChanged()
	local a = self.color[4]
	local r, g, b = unpack(self.alert and self.alertColor or self.color, 1, 3)
	self.frame:SetVertexColor(r, g, b, a)
end

function iconWidgetProto:SetTexCoords(...)
	self.frame:SetTexCoords(...)
	return self
end

function iconWidgetProto:SetSize(size)
	if size ~= self.size then
		self.size = size
		self.frame:SetSize(size, size)
	end
	return self
end

--------------------------------------------------------------------------------
-- Range widgets
--------------------------------------------------------------------------------

local rangeWidgetProto = NewWidgetType('range', 'icon')

function rangeWidgetProto:OnAcquire()
	iconWidgetProto.OnAcquire(self)
	self.radius, self.radiusModifier = 16, 1
end

function rangeWidgetProto:SetRadius(radius)
	self.radius = radius
	return self
end

function rangeWidgetProto:SetRadiusModifier(radiusModifier)
	self.radiusModifier = radiusModifier
	return self
end

function rangeWidgetProto:OnUpdate(uiRelX, uiRelY, distance, elapsed, pixelsPerYard)
	self:SetSize(2 * self.radius * pixelsPerYard * self.radiusModifier)
	return iconWidgetProto.OnUpdate(self, uiRelX, uiRelY, distance, elapsed, pixelsPerYard)
end

