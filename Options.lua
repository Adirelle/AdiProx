--[[
AdiProx - Proximity minimap.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local options

function addon:GetOptionHandler(target)
	local target = target
	local handler = {
		GetDatabase = function(self, info)
			return target.db.profile, info.args or info[#info]
		end,
		Get = function(self, info, subKey)
			local db, key = self:GetDatabase(info)
			if info.type == 'multiselect' then
				return db[key][subKey]
			else
				return db[key]
			end
		end,
		Set = function(self, info, ...)
			local db, key = self:GetDatabase(info)
			if info.type == 'multiselect' then
				local subKey, value = ...
				db[key][subKey] = value
			else
				db[key] = ...
			end
			if target.OnConfigChanged then
				target:OnConfigChanged(key, ...)
			end
		end,
	}
	if target ~= addon then
		handler.IsDisabled = function(self) return not addon.db.profile.modules[target.moduleName] end
	else
		handler.IsDisabled = function(self) return false end
	end
	return handler
end

function addon.GetOptions()
	if options then return options end
	local self = addon

	local moduleList = {}

	local profileOpts = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)
	LibStub('LibDualSpec-1.0'):EnhanceOptions(profileOpts, self.db)
	profileOpts.order = -1

	options = {
		name = format("%s v%s", addonName, GetAddOnMetadata(addonName, "Version")),
		type = 'group',
		childGroups = 'tab',
		handler = self:GetOptionHandler(self),
		set = 'Set',
		get = 'Get',
		args = {
			profiles = profileOpts,
		},
	}
	return options
end

