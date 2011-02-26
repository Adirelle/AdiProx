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
	assert(type(typeName) == "string" and registry[typeName], "AcquireWidget: invalid typeName: "..tostring(typeName))
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

function addon:IterateActiveWidgets()
	return pairs(activeWidgets)
end

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
widgetProto.frameLevel = 5

function widgetProto:OnCreate()
	self.frame = self:CreateFrame(addon.container)
	self.frame:Hide()
	if self.frameLevel and self.frame.SetFrameLevel then
		self.frame:SetFrameLevel(self.frameLevel)
	end
	self.animations = {}
end

function widgetProto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(0.1, 0.1)
	return frame
end

function widgetProto:Release()
	if activeWidgets[self] then
		activeWidgets[self] = nil
		for _, animation in pairs(self.animations) do
			animation:Release()
		end
		self:OnRelease()
		self.heap[self] = true
	end
end

function widgetProto:OnRelease()
	self:SetPosition(nil)	
	self.important = false
	self.alert = false
	self.expires = nil
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
	end
	return self
end

function widgetProto:SetImportant(important)
	important = not not important
	if self.important ~= important then
		self.important = important
		addon.forceUpdate = true
	end
	return self
end

function widgetProto:IsImportant()
	return self.important or self.alert
end

function widgetProto:IsActive()
	return not not activeWidgets[self]
end

function widgetProto:ShouldBeShown(onEdge)
	return self:IsActive()
end

function widgetProto:SetExpires(expires)
	expires = expires and tonumber(expires) or nil
	if expires and expires < GetTime() then
		self:Release()
	else
		self.expires = expires
	end
	return self
end

function widgetProto:SetDuration(duration)
	return self:SetExpires(duration and GetTime() + duration or nil)
end

function widgetProto:SetAlertRadius(radius, reverse)
	reverse = not not reverse
	if self.alertRadius ~= radius or self.alertReverse ~= reverse then
		self.alertRadius, self.alertReverse = radius, reverse
		addon.forceUpdate = true
	end
	return self
end

function widgetProto:TestAlert(distance)
	if distance and self.alertRadius then
		if self.alertReverse then
			return distance > self.alertRadius
		else
			return distance <= self.alertRadius
		end
	end
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

function widgetProto:OnPositionChanged()	
end

function widgetProto:OnUpdate(now)
	if self.expires and self.expires < now then
		self:Release()
	end
end

function widgetProto:SetPoint(x, y, pixelsPerYard, distance, zoomRange, onEdge)
	if x ~= self.x or y ~= self.y then
		self.x, self.y = x, y
		self.frame:SetPoint("CENTER", x, y)
	end
end

function widgetProto:AcquireAnimation(name, ...)
	if self.animations[name] then
		self.animations[name]:Release()
	end
	local animation = addon:AcquireAnimation(self.frame, ...)
	self.animations[name] = animation
	animation:SetFrameLevel(self.frameLevel)
	animation:Attach(self)
	return animation
end

function widgetProto:ReleaseAnimation(key)
	local animation
	if type(key) == "string" then
		animation = self.animations[key]
		self.animations[key] = nil
	else
		for name, anim in pairs(self.animations) do
			if anim == key then
				animation = anim
				self.animations[name] = nil
				break
			end
		end
	end
	if animation then
		animation:Release()
	end
	return animation
end

function widgetProto:GetAnimation(name)
	return self.animations[name]
end

--------------------------------------------------------------------------------
-- Icon widgets
--------------------------------------------------------------------------------

local iconWidgetProto = NewWidgetType('icon', 'abstract')

function iconWidgetProto:CreateFrame(parent, name)
	return parent:CreateTexture(name, "ARTWORK")	
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

function iconWidgetProto:OnAcquire(texture, size, r, g, b, a, blendMode)
	widgetProto.OnAcquire(self)
	if texture then
		self:SetTexture(texture, blendMode or "BLEND")
	end
	if size then
		self:SetSize(size)
	end
	if r and g and b and a then
		SetColor(self.color, r, g, b, a)
	else
		SetColor(self.color, 1, 1, 1, 1)
	end
	SetColor(self.alertColor, 1, 0, 0)
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

function rangeWidgetProto:OnAcquire(texture, radius, radiusModifier, r, g, b, a, blendMode)
	iconWidgetProto.OnAcquire(self, texture, nil, r, g, b, a, blendMode)
	self.radius, self.radiusModifier = radius or 16, radiusModifier or 1
	self.pixelsPerYard = nil
end

function rangeWidgetProto:SetRadius(radius)
	if self.radius ~= radius then
		self.radius = radius
		addon.forceUpdate = true
	end
	return self
end

function rangeWidgetProto:SetRadiusModifier(radiusModifier)
	if self.radiusModifier ~= radiusModifier then
		self.radiusModifier = radiusModifier
		addon.forceUpdate = true
	end
	return self
end

function rangeWidgetProto:SetPoint(x, y, pixelsPerYard, ...)
	iconWidgetProto.SetPoint(self, x, y, pixelsPerYard, ...)
	if pixelsPerYard ~= self.pixelsPerYard then
		self.pixelsPerYard = pixelsPerYard
		self:SetSize(2 * self.radius * pixelsPerYard * self.radiusModifier)
	end
end

--------------------------------------------------------------------------------
-- Edge arrow
--------------------------------------------------------------------------------

local edgeArrowProto = NewWidgetType('edge_arrow', 'abstract')

function edgeArrowProto:CreateFrame(parent, name)
	local f = addon:CreateTexture(parent, name, "OVERLAY")
	f:SetSize(48, 48)
	f:SetTexture([[Interface\Minimap\ROTATING-MINIMAPARROW]])
	return f
end

function edgeArrowProto:ShouldBeShown(onEdge)
	return onEdge and widgetProto.ShouldBeShown(self, onEdge)
end

local atan2 = math.atan2
function edgeArrowProto:SetPoint(x, y, pixelsPerYard, distance, zoomRange, onEdge)
	if self.x ~= x or self.y ~= y then
		self.x, self.y = x, y
		local f = zoomRange / self.position.zoomRange
		self.frame:SetRotation(atan2(-x, y))
		self.frame:SetPoint("CENTER", x * f, y * f)
		--self.frame:DrawRouteLine(0, 0, x*f, y*f, 10, addon.container, "CENTER")
	end
end
