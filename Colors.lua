--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local COLORS = {}
addon.COLORS = COLORS

local function SetColor(key, color)
	if not COLORS[key] then
		COLORS[key] = {}
	end
	local c = COLORS[key]
	c[1], c[2], c[3] = color.r, color.g, color.b
end

local function MergeColors(t)
	for key, color in pairs(t) do
		SetColor(key, color)
	end
end

MergeColors(DebuffTypeColor)
MergeColors(RAID_CLASS_COLORS)

for _, key in pairs{"NORMAL", "HIGHLIGHT", "RED", "DIM_RED", "GREEN", "GRAY", "YELLOW", "LIGHTYELLOW", "ORANGE", "PASSIVE_SPELL"} do
	SetColor(key, _G[key.."_FONT_COLOR"])
end

function addon.ParseColor(r, g, b, alpha)
	if type(r) == "string" then
		alpha = g
		if COLORS[r] then
			r, g, b = unpack(COLORS[r])
		else
			r, g, b = 1, 1, 1
		end
	end
	return r or 1, g or 1, b or 1, alpha or 1
end

if CUSTOM_CLASS_COLORS then
	MergeColors(CUSTOM_CLASS_COLORS)
	if CUSTOM_CLASS_COLORS.RegisterCallback then
		CUSTOM_CLASS_COLORS:RegisterCallback(function()
			MergeColors(CUSTOM_CLASS_COLORS)
			addon:SendMessage("AdiProx_ClassColorsChanged")
		end)
	end
end
