--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local mod = addon:NewModule('Group', 'AceEvent-3.0')

function mod:OnEnable()
	self:RegisterMessage('AdiProx_GroupChanged', "Update")
	mod:Update()
end

function mod:OnDisable()
	self:ReleaseAllWidgets()
end

function mod:Update()
end

