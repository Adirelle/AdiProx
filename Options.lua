--[[
AdiProx - Proximity minimap.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...
local L = addon.L

local handlerProto = {}
local handlerMeta = { __index = handlerProto }

function handlerProto:GetDatabase(info)
	return self.target.db.profile, info.args or info[#info]
end

function handlerProto:Get(info, subKey)
	local db, key = self:GetDatabase(info)
	if info.type == 'multiselect' then
		return db[key][subKey]
	else
		return db[key]
	end
end

function handlerProto:Set(info, ...)
	local db, key = self:GetDatabase(info)
	if info.type == 'multiselect' then
		local subKey, value = ...
		db[key][subKey] = value
	else
		db[key] = ...
	end
	addon:SendMessage('AdiProx_ConfigChanged_'..self.target.name, key, ...)
end

local function DecorateOptions(target, options)
	if not options.name then
		options.name =  L[target.moduleName or target.name or tostring(target)]
	end
	options.type = 'group'
	if not options.args then
		options.args = {}
	end
	if target.db then
		options.set = 'Set'
		options.get = 'Get'
		options.handler = setmetatable({ target = target }, handlerMeta)
	end
	if options.args.enabled == nil then
		options.args.enabled = {
			name = L['Enabled'],
			type = 'toggle',
			get = function(info) return addon.db.profile.modules[target.name] end,
			set = function(info, value)
				addon.db.profile.modules[target.name] = value
				target:UpdateEnabledState()
			end,
			disabled = false,
			order = 1,
		}
	end
	return options
end
addon.DecorateOptions = DecorateOptions

local options
function addon.GetOptions()
	if options then return options end
	
	local self = addon

	local profileOpts = LibStub('AceDBOptions-3.0'):GetOptionsTable(self.db)
	LibStub('LibDualSpec-1.0'):EnhanceOptions(profileOpts, self.db)
	profileOpts.order = -1

	options = DecorateOptions(self, {
		name = format("%s v%s", addonName, GetAddOnMetadata(addonName, "Version")),
		args = {
			enabled = false, -- bogus entry to prevent the decorator to add one
			general = {
				name = L['General'],
				type = 'group',
				order = 1,
				args = {
					enabled = {
						name = L['Enabled'],
						type = 'toggle',
						order = 10,
						set = function(info, value)
							info.handler:Set(info, value)
							addon:UpdateEnabledState()
						end,
					},
					opacity = {
						name = L['Opacity'],
						type = 'range',
						isPercent = true,
						min = 0.10,
						max = 1,
						step = 0.01,
						order = 30,
					},
					backgroundOpacity = {
						name = L['Background opacity'],
						type = 'range',
						isPercent = true,
						min = 0,
						max = 1,
						step = 0.01,
						order = 40,
					},
					scale = {
						name = L['Scale'],
						type = 'range',
						min = 0.5,
						max = 2.0,
						step = 0.05,
						order = 50,
					},
					autoHide = {
						name = L['Hide automatically'],
						type = 'toggle',
						order = 60,
					},
					zoom = {
						name = L['Zoom'],
						type = 'group',
						inline = true,
						args = {
							autoZoom = {
								name = L['Automatic'],
								type = 'toggle',
								order = 10,
							},
							minZoomRange = {
								name = L['Minimal range'],
								type = 'range',
								min = 10,
								max = 100,
								step = 5,
								order = 20,
								hidden = function() return not addon.db.profile.autoZoom end,
							},
							maxZoomRange = {
								name = L['Maximal range'],
								type = 'range',
								min = 40,
								max = 200,
								step = 5,
								order = 30,
								hidden = function() return not addon.db.profile.autoZoom end,
							},
							zoomRange = {
								name = L['Fixed range'],
								type = 'range',
								min = 10,
								max = 200,
								step = 5,
								order = 40,
								hidden = function() return addon.db.profile.autoZoom end,
							},
						}
					}
				}
			},
			profiles = profileOpts,
		}
	})
	
	options.args.enabled = nil
	
	for name, module in self:IterateModules() do
		if module.GetOptions then
			local modOptions = DecorateOptions(module, module:GetOptions())
			options.args[name] = modOptions
			module.GetOptions = nil
		end
	end
	
	return options
end

