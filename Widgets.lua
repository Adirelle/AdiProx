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
end

function widgetProto:OnRelease()
	self:SetPosition(nil)
	self:SetAlert(false)
end

function widgetProto:Show()
	if not self.frame:IsShown() then
		self:Debug('Show')
		self.frame:Show()
	end
	return self
end

function widgetProto:Hide()
	if self.frame:IsShown() then
		self:Debug('Hide')
		self.frame:Hide()
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

function widgetProto:SetPosition(position)
	if position ~= self.position then
		local oldPosition = self.position
		self.position = position
		if oldPosition then
			oldPosition:Detach(self)
		end
		if not position then
			self:Hide()
		end
		self.x, self.y = nil, nil
	end
	return self
end

function widgetProto:OnUpdate(x, y)
	if x ~= self.x or y ~= self.y then
		self.x, self.y = x, y
		self.frame:SetPoint("CENTER", x, y)
	end
	return true, self.important
end

--------------------------------------------------------------------------------
-- Icon widgets
--------------------------------------------------------------------------------

local iconWidgetProto = NewWidgetType('icon', 'abstract')

function iconWidgetProto:CreateFrame(parent)
	return parent:CreateTexture(nil, "ARTWORK")	
end

function iconWidgetProto:OnAcquire()
	widgetProto.OnAcquire(self)
	self.colorR, self.colorG, self.colorB, self.alpha = 1, 1, 1, 1
end

function iconWidgetProto:SetTexture(texture)
	if texture ~= self.texture then
		self.texture = texture
		self.frame:SetTexture(texture)
	end
	return self
end

function iconWidgetProto:SetColor(r, g, b, a)
	self.colorR, self.colorG, self.colorB, self.alpha = r, g, b, a or 1
	self:OnAlertChanged()
	return self
end

function iconWidgetProto:OnAlertChanged()
	local r, g, b, a = self.colorR, self.colorG, self.colorB, self.alpha
	if self.alert then
		r, g, b = 1, 0, 0
	end
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
	iconWidgetProto.OnAcquire(self, 0)
end

function rangeWidgetProto:SetRadius(radius)
	if radius ~= self.radius then
		self.radius = radius
	end
	return self
end

function rangeWidgetProto:OnUpdate(uiRelX, uiRelY, distance, elapsed, pixelsPerYard)
	self:SetSize(self.radius * pixelsPerYard)
	return iconWidgetProto.OnUpdate(self, uiRelX, uiRelY, distance, elapsed, pixelsPerYard)
end

