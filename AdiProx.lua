--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0')
--@debug@
_G[addonName] = addon
--@end-debug@

--------------------------------------------------------------------------------
-- Debug stuff
--------------------------------------------------------------------------------

--@alpha@
if AdiDebug then
	AdiDebug:Embed(addon, addonName)
else
--@end-alpha@
	function addon.Debug() end
--@alpha@
end
--@end-alpha@

--------------------------------------------------------------------------------
-- Default settings
--------------------------------------------------------------------------------

local DEFAULT_SETTINGS = {}

--------------------------------------------------------------------------------
-- Upvalues and constants
--------------------------------------------------------------------------------

local prefs
local classColors

local UPDATE_PERIOD = 1/30

local ZOOM_GRANULARITY = 25
local MAX_ZOOM = ZOOM_GRANULARITY * 4

local LibMapData = LibStub('LibMapData-1.0')

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

function addon:OnInitialize()
	self.db = LibStub('AceDB-3.0'):New(addonName.."DB", DEFAULT_SETTINGS, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "Reconfigure")
	self.db.RegisterCallback(self, "OnProfileCopied", "Reconfigure")
	self.db.RegisterCallback(self, "OnProfileReset", "Reconfigure")

	LibStub('LibDualSpec-1.0'):EnhanceDatabase(self.db, addonName)

	prefs = self.db.profile

	LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, self.GetOptions)
	self.blizPanel = LibStub('AceConfigDialog-3.0'):AddToBlizOptions(addonName, addonName)

	--self:RegisterChatCommand("acm", "ChatCommand", true)
	--self:RegisterChatCommand(addonName, "ChatCommand", true)

	if CUSTOM_CLASS_COLORS then
		classColors = CUSTOM_CLASS_COLORS
		classColors:RegisterCallback(function() if self:IsEnabled() then self:SendMessage("AdiProx_ClassColorsChanged") end end)
	else
		classColors = RAID_CLASS_COLORS
	end		
end

function addon:OnEnable()
	prefs = self.db.profile
	self:Debug('OnEnable')

	if not self.frame then
		self:CreateTheFrame()
	end
	self.frame:Show()

	if not self.updateFrame then
		self.updateFrame = CreateFrame("Frame")
		self.updateFrame:SetScript('OnUpdate', function(_, elapsed) return self:OnUpdate(elapsed) end)
	end
	self.updateFrame:Show()

	self.zoomRange = ZOOM_GRANULARITY

	LibMapData.RegisterCallback(self, "MapChanged")
	self:MapChanged("OnEnable", GetMapInfo(), GetCurrentMapDungeonLevel())

	self:RegisterEvent('PARTY_MEMBERS_CHANGED')
	self:PARTY_MEMBERS_CHANGED("OnEnable")

	local player = self:GetUnitPosition("player")
	if not player:GetWidget('arrow') then
		local playerArrow = self:AcquireWidget("icon", [[Interface\Minimap\MinimapArrow]], 32)
		player:Attach("arrow", playerArrow)
	end

end

function aptest()
	local px, py = GetPlayerMapPosition("player")
	if px ~= 0 and py ~= 0 then
		local pos = addon:GetStaticPosition(px, py)
		pos:SetAlertCondition(5)
		local mark = addon:AcquireWidget("range", [[Interface\Cooldown\ping4]], 5, 1, 1, 1, 1, "ADD")
		pos:Attach("mark", mark)
	end
end

function addon:OnDisable()
	self.frame:Hide()
	self.updateFrame:Hide()
	LibMapData.UnregisterCallback(self, "MapChanged")
end

function addon:Reconfigure()
	self:Disable()
	self:Enable()
end

function addon:MapChanged(event, map, floor)
	self.currentMap, self.currentFloor = map, floor
	self.forceUpdate = true
end

--------------------------------------------------------------------------------
-- Create the proximity frame
--------------------------------------------------------------------------------

function addon:CreateTheFrame()
	local frame = CreateFrame("Frame", "AdiProxFrame", UIParent)
	frame:SetClampedToScreen(true)
	frame:SetSize(201, 201)
	frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -300, 300)
	frame:SetBackdrop{
	  bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = false, tileSize = 0,
  	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	}
	frame:SetBackdropColor(0, 0, 0, 0.8)
	frame:SetBackdropBorderColor(1, 1, 1, 0.8)
	self.frame = frame

	local scrollParent = CreateFrame("ScrollFrame", nil, frame)
	scrollParent:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
	scrollParent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)

	local scrollChild = CreateFrame("Frame", nil, frame)
	scrollParent:SetScrollChild(scrollChild)
	self.container = scrollChild
	scrollChild:SetSize(scrollParent:GetSize())

	local ticks = {}
	for i, v in ipairs{{1,0}, {0,1}, {-1, 0}, {0, -1}} do
		local dx, dy = unpack(v)
		for j = 1, 3 do
			local dist = j * 20
			local tick = self.container:CreateTexture(nil, "BACKGROUND")
			tick:SetTexture(0.7, 0.7, 0.7, 0.5)
			if dx ~= 0 then
				tick:SetSize(1, 5)
			else
				tick:SetSize(5, 1)
			end
			tick.x, tick.y = dist * dx, dist * dy
			ticks[tick] = true
		end
	end
	self.zoomTicks = ticks
end

--------------------------------------------------------------------------------
-- Updating
--------------------------------------------------------------------------------

local function TestCondition(distance, threshold, invert)
	if distance and threshold then
		if invert then
			return distance > threshold
		else
			return distance <= threshold
		end
	end
end

local log, pow = math.log, math.pow
local log2 = log(2)
local delay = 0
function addon:OnUpdate(elapsed)
	delay = delay + elapsed
	
	if delay > UPDATE_PERIOD or self.forceUpdate then
		elapsed, delay = delay, 0
	else
		return
	end
	
	local facing, px, py = GetPlayerFacing(), GetPlayerMapPosition("player")
	if px == 0 and py == 0 then
		self.frame:Hide()
		return
	end

	local pixelsPerYard = (self.container:GetWidth() - 16) / (self.zoomRange * 2)
	local rotangle = 2 * math.pi - facing
	local showMe = false
	local playerAlert, playerPos = false, self:GetUnitPosition("player")
	local playerDist, playerInvert = playerPos:GetAlertCondition()
	local zoomRange = self.zoomRange

	local now = GetTime()
	local maxDist = ZOOM_GRANULARITY
	for position in self:IterateActivePositions() do
		if position ~= playerPos then
			local state, distance, range = position:UpdateRelativeCoords(px, py, rotangle, zoomRange)
			if state ~= "invalid" then
				if TestCondition(distance, playerDist, playerInvert) then
					position:SetAlert(true)
					playerAlert = true
				else
					position:SetAlert(TestCondition(distance, position:GetAlertCondition()))
				end
			end
			if position:UpdateWidgets(pixelsPerYard, now) then
				showMe = true
				maxDist = max(maxDist, range * 1.25)
			end
		end
	end
	playerPos:SetAlert(playerAlert)
	if playerPos:UpdateWidgets(pixelsPerYard, now) then
		showMe = true
	end
	
	if showMe or IsShiftKeyDown() then
		self.frame:Show()
		if self.zoomRange ~= self.tickRange then
			for tick in pairs(self.zoomTicks) do
				tick:SetPoint("CENTER", tick.x * pixelsPerYard, tick.y * pixelsPerYard)
			end
			self.tickRange = self.zoomRange
		end
	else
		self.frame:Hide()
	end
	
	--local newZoom = ZOOM_GRANULARITY * ceil(maxDist / ZOOM_GRANULARITY)
	local newZoom = ZOOM_GRANULARITY * pow(2, ceil(log(min(maxDist, MAX_ZOOM) / ZOOM_GRANULARITY) / log2))
	if newZoom ~= self.targetZoom then
		self.zoomSpeed = max(newZoom, self.targetZoom or 0) / 0.5
		self.targetZoom = newZoom
	end
	if newZoom > self.zoomRange then
		self.zoomRange = min(self.zoomRange + elapsed * self.zoomSpeed, newZoom)
	elseif newZoom < self.zoomRange then
		self.zoomRange = max(self.zoomRange - elapsed * self.zoomSpeed, newZoom)
	end

	self.forceUpdate = nil
end

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

function addon:GetUnitColor(unit)
	if unit then
		local _, class = UnitClass(unit)
		return class and classColors[class]
	end
end

function addon:GetClassColor(class)
	return class and classColors[class]
end

--------------------------------------------------------------------------------
-- Module prototype
--------------------------------------------------------------------------------

local moduleProto = { Debug = addon.Debug }
addon:SetDefaultModulePrototype(moduleProto)
addon.moduleProto = moduleProto

function moduleProto:OnDisable()
	self:ReleaseAllWidgets()
	if self.PostDisable then
		self:PostDisable()
	end
end
