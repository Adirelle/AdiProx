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

addon.moduleProto = {Debug = addon.Debug}
addon:SetDefaultModulePrototype(addon.moduleProto)

--------------------------------------------------------------------------------
-- Default settings
--------------------------------------------------------------------------------

local DEFAULT_SETTINGS = {}

--------------------------------------------------------------------------------
-- Upvalues and constants
--------------------------------------------------------------------------------

local prefs

local UPDATE_PERIOD = 1/25

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

	self.zoomRange = 40

	LibMapData.RegisterCallback(self, "MapChanged")
	self:MapChanged("OnEnable", GetMapInfo(), GetCurrentMapDungeonLevel())
	
	self:RegisterEvent('PARTY_MEMBERS_CHANGED')
	self:PARTY_MEMBERS_CHANGED("OnEnable")
	
	local player = self:GetUnitPosition("player")
	if not player:GetWidget('arrow') then
		local playerArrow = self:AcquireWidget("icon"):SetSize(32):SetTexture([[Interface\Minimap\MinimapArrow]])
		player:Attach("arrow", playerArrow)
	end
	
end

function aptest()
	local px, py = GetPlayerMapPosition("player")
	if px ~= 0 and py ~= 0 then
		local pos = addon:GetStaticPosition(px + math.random(-0.02, 0.02), py + math.random(-0.02, 0.02))
		pos:SetAlertCondition(5)
		local mark = addon:AcquireWidget("icon"):SetSize(16):SetTexture([[Interface\Minimap\UI-Minimap-Ping-Center]])
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
	frame:SetSize(200, 200)
	frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -300, 300)
	frame:SetBackdrop{
	  bgFile = [[Interface\Tooltips\UI-Tooltip-Background]], tile = false, tileSize = 0,
  	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
		insets = { left = 3, right = 3, top = 3, bottom = 3 }
	}
	frame:SetBackdropColor(0, 0, 0, 0.8)
	frame:SetBackdropBorderColor(1, 1, 1, 0.8)
	self.frame = frame

	local scrollChild = CreateFrame("Frame", nil, frame)
	scrollChild:SetSize(200, 200)
	self.container = scrollChild
	
	local scrollParent = CreateFrame("ScrollFrame", nil, frame)
	scrollParent:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
	scrollParent:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 2)
	scrollParent:SetScrollChild(scrollChild)
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

local delay = 0
function addon:OnUpdate(elapsed)
	delay = delay + elapsed
	if delay < UPDATE_PERIOD and not self.forceUpdate then
		return
	end
	elapsed, delay = delay, 0
	self.forceUpdate = nil
	
	local px, py = GetPlayerMapPosition("player")
	if px == 0 and py == 0 then
		self.frame:Hide()
		return
	end
	
	local pixelsPerYard = self.frame:GetWidth() / (self.zoomRange * 2)
	local rotangle = 2 * math.pi - GetPlayerFacing()
	local showMe = false
	local playerAlert, playerPos = false, self:GetUnitPosition("player")
	local playerDist, playerInvert = playerPos:GetAlertCondition()
	
	for position in self:IterateActivePositions() do
		if position ~= playerPos then
			local visible, distance = position:UpdateRelativeCoords(px, py, rotangle)
			if visible then
				if TestCondition(distance, playerDist, playerInvert) then
					position:SetAlert(true)
					playerAlert = true
				else
					position:SetAlert(TestCondition(distance, position:GetAlertCondition()))
				end
			end
			if position:UpdateWidgets(elapsed, pixelsPerYard) then
				showMe = true
			end
		end
	end
	
	playerPos:SetAlert(playerAlert)	
	if playerPos:UpdateWidgets(elapsed, pixelsPerYard) then
		showMe = true
	end
	
	if showMe or true then
		self.frame:Show()
	else
		self.frame:Hide()
	end
end

