--[[
AdiProx - Proximity minimap.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local heap = {}

local parentProto = CreateFrame("Frame")
local proto = setmetatable({ Debug = addon.Debug }, { __index = parentProto })
local meta = { __index = proto }

function addon:AcquireAnimation(parent, ...)
	local frame = next(heap)
	if frame then
		heap[frame] = nil
	else
		frame = setmetatable(CreateFrame("Frame"), meta)
		frame:OnCreate()
	end
	frame:SetParent(parent)
	frame:SetPoint("CENTER", parent, "CENTER", 0, 0)
	frame:OnAcquire(...)
	return frame
end

function proto:OnCreate()
	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)	
	self.Texture = self:CreateTexture(nil, "ARTWORK")
	self.Texture:SetAllPoints(self)	
	
	local pulseGroup = self:CreateAnimationGroup()
	local pulseAnim = pulseGroup:CreateAnimation("Scale") 
	pulseGroup:SetLooping("BOUNCE")
	pulseAnim:SetOrder(1)
	self.PulseGroup, self.PulseAnim = pulseGroup, pulseAnim
	
	local rotationGroup = self:CreateAnimationGroup()
	local rotationAnim = rotationGroup:CreateAnimation("Rotation") 
	rotationGroup:SetLooping("REPEAT")
	rotationAnim:SetOrder(1)
	self.RotationGroup, self.RotationAnim = rotationGroup, rotationAnim
end

function proto:Release()
	if not heap[self] then
		heap[self] = true
		self:Hide()
		self:Pulse(nil, nil)
		self:Rotate(nil, nil)
		self:ClearAllPoints()
		self:SetParent(nil)
	end
end

function proto:OnAcquire(texture, size, r, g, b, a, blendMode)
	if texture then
		self:SetTexture(texture)
	end
	if size then
		self:SetSize(size)
	end
	if r and g and b and a then
		self:SetColor(r, g, b, a)
	else
		self:SetColor(1, 1, 1, 1)
	end
	self:SetBlendMode(blendMode or "BLEND")
	self:Show()
end

function proto:Pulse(scale, duration)
	local anim = self.PulseAnim
	if scale ~= anim.scale or duration ~= anim.duration then
		anim.scale, anim.duration = scale, duration
		if self.PulseGroup:IsPlaying() then
			self.PulseGroup:Stop()
		end
		if scale and duration then
			anim:SetScale(scale, scale)
			anim:SetDuration(duration)
			self.PulseGroup:Play()
		end
	end
	return self
end

function proto:Rotate(degrees, duration)
	local anim = self.RotationAnim
	if degrees ~= anim.degrees or duration ~= anim.duration then
		anim.degrees, anim.duration = degrees, duration
		if self.RotationGroup:IsPlaying() then
			self.RotationGroup:Stop()
		end
		if degrees and duration then
			anim:SetDegrees(degrees)
			anim:SetDuration(duration)
			self.RotationGroup:Play()
		end
	end
	return self
end

function proto:SetSize(size)
	parentProto.SetSize(self, size, size)
	return self
end

function proto:SetTexture(...)
	self.Texture:SetTexture(...)
	return self
end

function proto:SetColor(...)
	self.Texture:SetVertexColor(...)
	return self
end

function proto:SetTexCoord(...)
	self.Texture:SetTexCoord(...)
	return self
end

function proto:SetBlendMode(...)
	self.Texture:SetBlendMode(...)
	return self
end