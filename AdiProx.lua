--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0', 'AceConsole-3.0')
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

local DEFAULT_SETTINGS = {
	profile = {
		enabled = true,
		modules = { ['*'] = true },
		opacity = 1.0,
		backgroundOpacity = 0.8,
		scale = 1.0,
		autoHide = true,
		autoZoom = true,
		minZoomRange = 25,
		maxZoomRange = 100,
		zoomRange = 50,
	}
}

--------------------------------------------------------------------------------
-- Upvalues and constants
--------------------------------------------------------------------------------

local prefs

local UPDATE_PERIOD = 1/30

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

	self:RegisterChatCommand("adp", "ChatCommand", true)
	self:RegisterChatCommand(addonName, "ChatCommand", true)
	
	self:SetEnabledState(self:ShouldEnable())
end

function addon:OnEnable()
	prefs = self.db.profile

	if not self.frame then
		self:CreateTheFrame()
	end
	self.forceUpdate = true

	if not self.updateFrame then
		self.updateFrame = CreateFrame("Frame")
		self.updateFrame:SetScript('OnUpdate', function(_, elapsed) return self:OnUpdate(elapsed) end)
	end
	self.updateFrame:Show()

	self:RegisterMessage('AdiProx_ConfigChanged_AdiProx', 'OnConfigChanged')
	self:OnConfigChanged()

	LibMapData.RegisterCallback(self, "MapChanged")
	self:MapChanged("OnEnable", GetMapInfo(), GetCurrentMapDungeonLevel())

	self:RegisterEvent('PARTY_MEMBERS_CHANGED')
	self:PARTY_MEMBERS_CHANGED("OnEnable")
end

function aptest()
	local px, py = GetPlayerMapPosition("player")
	if px ~= 0 and py ~= 0 then
		local mark = addon:AcquireWidget("encounter_proximity", 5)
		mark:SetImportant(true)
		--mark:SetTracked(true)
		mark:SetAlertRadius(5)
		local pos = addon:GetStaticPosition(px, py)
		pos:SetLabel("BLA !")
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
	if self.currentMap ~= map or self.currentFloor ~= floor then
		self.currentMap, self.currentFloor = map, floor
		self.forceUpdate = true
		self:SendMessage('AdiProx_MapChanged', map, floor)
	end
end

function addon:ShouldEnable()
	return prefs.enabled
end

function addon:UpdateEnabledState(...)
	local enable = self:ShouldEnable()
	if enable and not self:IsEnabled() then
		self:Enable()
	elseif not enable and self:IsEnabled() then 
		self:Disable()
	end
	return enable
end

function addon:OnConfigChanged()
	local frame = self.frame
	frame:SetAlpha(prefs.opacity)
	frame:SetBackdropColor(0, 0, 0, prefs.backgroundOpacity)
	frame:SetBackdropBorderColor(1, 1, 1, prefs.backgroundOpacity)	
	frame:SetScale(prefs.scale)
	self.forceUpdate = true
end

function addon:ChatCommand()
	InterfaceOptionsFrame_OpenToCategory(self.blizPanel)
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
	
	local layers = {}
	for i = 1, 4 do
		local layer = CreateFrame("Frame", nil, scrollChild)
		layer:SetAllPoints(scrollChild)
		layer:SetFrameLevel(scrollChild:GetFrameLevel() + i)
		layers[i] = layer
	end
	scrollChild.layers = layers
end

--------------------------------------------------------------------------------
-- Updating
--------------------------------------------------------------------------------

local log, pow = math.log, math.pow
local log2 = log(2)
local delay = 0
local actualZoom, nextZoom, targetZoom, zoomDelay, zoomSpeed = 25, 25, 25, 0, 0

function addon:OnUpdate(elapsed)
	delay = delay + elapsed
	
	if delay > UPDATE_PERIOD or self.forceUpdate then
		elapsed, delay = delay, 0
	else
		return
	end
	
	local playerPos = self:GetUnitPosition("player")
	local px, py = playerPos:GetMapCoords()
	if not px or not py then
		self.frame:Hide()
		return
	end

	-- Update all widgets	
	local now = GetTime()
	for widget in self:IterateActiveWidgets() do
		widget:OnUpdate(now)		
	end

	local showMe = not prefs.autoHide or IsShiftKeyDown()
	local rotangle = 2 * math.pi - GetPlayerFacing()
	local highestDistance = prefs.minZoomRange
	local maxZoom = prefs.autoZoom and prefs.maxZoomRange or (2 * prefs.zoomRange)

	playerPos:ResetAlerts()
	
	for position in self:IterateActivePositions() do
		local valid, distance, zoomRange = position:UpdateRelativeCoords(px, py, rotangle)
		if valid then
			local playerAlert = not position:GetIgnoreAlert() and playerPos:UpdateAlerts(distance)
			position:UpdateAlerts(distance, playerAlert)
			local important, tracked = position:UpdateFlags()
			if important then
				showMe = true
			end
			if tracked and zoomRange < maxZoom then
				highestDistance = max(highestDistance, zoomRange * 1.1)
			end
		end
	end

	-- Finally update player position	
	if playerPos:UpdateFlags() then
		showMe = true
	end
	
	if not showMe then
		self.forceUpdate = nil
		return self.frame:Hide()
	end
	
	if prefs.autoZoom then
		local idealZoom = min(prefs.minZoomRange * pow(2, ceil(log(highestDistance / prefs.minZoomRange) / log2)), prefs.maxZoomRange)
		if not self.frame:IsShown() then
			-- Directly use the ideal zoom on show
			actualZoom, nextZoom, targetZoom = idealZoom, idealZoom, idealZoom
		else
			-- Wait a small period (0.5s) before actually change the zoom
			if nextZoom ~= idealZoom then
				nextZoom, zoomDelay = idealZoom, 0.2
			elseif targetZoom ~= nextZoom then
				zoomDelay = zoomDelay - elapsed
				if zoomDelay <= 0 then
					targetZoom, zoomSpeed = nextZoom, max(nextZoom, targetZoom) / 0.5
				end
			end
		
			-- Have actualZoom reach targetZoom
			if actualZoom < targetZoom then
				actualZoom = min(actualZoom + elapsed * zoomSpeed, targetZoom)
			elseif actualZoom > targetZoom then
				actualZoom = max(actualZoom - elapsed * zoomSpeed, targetZoom)
			end
		end
	else
		actualZoom = prefs.zoomRange
	end
	
	local pixelsPerYard = (self.container:GetWidth() - 16) / (actualZoom * 2)
	
	-- Layout widgets
	showMe = not prefs.autoHide or IsShiftKeyDown()
	for position in self:IterateActivePositions() do
		if position:LayoutWidgets(actualZoom, pixelsPerYard) then
			showMe = true
		end
	end
	
	if showMe then
		-- Really show the frame
		self.frame:Show()
	else
		-- Finally, we don't display anything useful
		self.frame:Hide()
	end
	self.forceUpdate = nil
end

--------------------------------------------------------------------------------
-- Utility
--------------------------------------------------------------------------------

function addon:GetUnitColor(unit)
	if unit then
		local _, class = UnitClass(unit)
		return class and self.COLORS[class]
	end
end

function addon:GetClassColor(class)
	return class and self.COLORS[class]
end

--------------------------------------------------------------------------------
-- Module prototype
--------------------------------------------------------------------------------

local moduleProto = { Debug = addon.Debug, core = addon }
addon:SetDefaultModulePrototype(moduleProto)
addon.moduleProto = moduleProto

function moduleProto:OnInitialize()
	if self.GetOptions then
		self.db = addon.db:RegisterNamespace(self.name, self.default_db)
	end
	local enable = self:ShouldEnable()
	self:SetEnabledState(enable)
	if self.PostInitialize then
		self:PostInitialize()
	end
end

function moduleProto:ShouldEnable()
	return self.core:ShouldEnable() and prefs.modules[self.name]
end 

moduleProto.UpdateEnabledState = addon.UpdateEnabledState

function moduleProto:OnEnable()
	if self.OnConfigChanged then
		self:RegisterMessage('AdiProx_ConfigChanged_'..self.name, 'OnConfigChanged')
	end
	if self.PostEnable then
		self:PostEnable()
	end
	self:Debug('Enabled')
end

function moduleProto:OnDisable()
	self:ReleaseAllWidgets()
	if self.PostDisable then
		self:PostDisable()
	end
	self:Debug('Disabled')
end
