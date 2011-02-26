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
	frame:Debug('Acquired')
	return frame
end

function proto:OnCreate()
	self:SetScript('OnShow', self.OnShow)
	self:SetScript('OnHide', self.OnHide)	

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
		self:Attach(nil)
		self:Hide()
		self:Pulse(nil, nil)
		self:Rotate(nil, nil)
		self:ClearAllPoints()
		self:SetParent(nil)
		self.Texture:Release()
	end
end

function proto:Attach(attach)
	local oldAttach = self.attach
	if oldAttach ~= attach then
		self.attach = attach
		if oldAttach and oldAttach.ReleaseAnimation then
			oldAttach:ReleaseAnimation(self)
		end
		if oldAttach then		
			self:Debug('Detached from', oldAttach)
		end
		if attach then
			self:Debug('Attached to', attach)
		end
	end
end

function proto:OnAcquire(texture, size, r, g, b, a, blendMode)
	self.Texture = addon:AcquireTexture(self, "ARTWORK")
	self.Texture:SetPoint("CENTER")	
	if texture then
		self:SetTexture(texture, blendMode)
	else
		self:SetTexture([[Tileset\Generic\Checkers]], "ADD")
	end
	self:SetSize(size or 16)
	self:SetColor(r, g, b, a)
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

function proto:UpdateTextureSize()
	local w, h = self:GetSize()
	if w and h then
		local sizeModifier = self.Texture.sizeModifier or 1
		self.Texture:SetSize(w * sizeModifier, h * sizeModifier)
	end
end

function proto:SetSize(size)
	parentProto.SetSize(self, size, size)
	self:UpdateTextureSize()
	return self
end

function proto:SetTexture(...)
	self.Texture:SetTexture(...)
	self:UpdateTextureSize()
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
