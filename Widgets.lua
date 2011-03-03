--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local AceEvent = LibStub('AceEvent-3.0')

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
	widget.owner = owner
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
widgetProto.layerLevel = 1

function widgetProto:OnCreate()
	self.frame = self:CreateFrame(addon.container.layers[self.layerLevel])
	self.frame:Hide()
	self.animations = {}
end

function widgetProto:CreateFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetSize(0.1, 0.1)
	return frame
end

function widgetProto:OnAcquire()
	AceEvent.RegisterMessage(self, 'AdiProx_ConfigChanged_'..self.owner.name, 'OnConfigChanged')
	self:OnConfigChanged()
end

function widgetProto:OnConfigChanged()
end

function widgetProto:Release()
	if activeWidgets[self] then
		activeWidgets[self] = nil
		for _, animation in pairs(self.animations) do
			animation:Release()
		end
		self:OnRelease()
		AceEvent.UnregisterAllEvents(self)
		AceEvent.UnregisterAllMessages(self)
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

function widgetProto:SetTracked(tracked)
	tracked = not not tracked
	if self.tracked ~= tracked then
		self.tracked = tracked
		addon.forceUpdate = true
	end
	return self
end

function widgetProto:SetShowOnEdge(showOnEdge)
	showOnEdge = not not showOnEdge
	if self.showOnEdge ~= showOnEdge then
		self.showOnEdge = showOnEdge
		addon.forceUpdate = true
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

function widgetProto:IsTracked()
	return self.tracked or self.alert
end

function widgetProto:IsShownOnEdge()
	return self.showOnEdge or self:IsTracked()
end

function widgetProto:IsActive()
	return not not activeWidgets[self]
end

function widgetProto:ShouldBeShown(onEdge)
	return self:IsActive() and (not onEdge or self:IsShownOnEdge())
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

function widgetProto:IsInAlert()
	return self.alert
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
	--animation:SetFrameLevel(self:GetParent():GetFrameLevel()+1)
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
-- Edge arrow
--------------------------------------------------------------------------------

local edgeArrowProto = NewWidgetType('edge_arrow', 'abstract')
edgeArrowProto.layerLevel = 4

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

--------------------------------------------------------------------------------
-- Label
--------------------------------------------------------------------------------

local labelProto = NewWidgetType('label', 'abstract')
edgeArrowProto.layerLevel = 4

function labelProto:CreateFrame(parent)
	return parent:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Small", 1)
end

function labelProto:OnAcquire(label)
	self.x, self.y = nil, nil
	self:SetLabel(label)
	return widgetProto.OnAcquire(self)
end

function labelProto:SetLabel(label)
	if label and strtrim(label) ==  "" then label = nil end
	if label ~= self.label then
		self.label = label
		self.frame:SetText(label or "")
	end
	return self
end

function labelProto:GetLabel()
	return label
end

function labelProto:ShouldBeShown(onEdge)
	return self:IsActive() and self.label
end

function labelProto:SetPoint(x, y, pixelsPerYard, distance, zoomRange, onEdge)
	if onEdge then
		local f = zoomRange / self.position.zoomRange
		x, y = x * f, y * f
	end
	if self.x ~= x or self.y ~= y then
		self.x, self.y = x, y
		self.frame:SetPoint("BOTTOM", self.frame:GetParent(), "CENTER", x, y + 8)
	end
end
