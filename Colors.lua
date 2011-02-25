--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local COLORS = {
	-- Gathered from Blizzard_CombatLog.lua
	PHYSICAL = { r = 1.0, g = 1.0, b = 0.0 },
	HOLY     = { r = 1.0, g = 0.9, b = 0.5 },
	FIRE     = { r = 1.0, g = 0.5, b = 0.0 },
	NATURE   = { r = 0.3, g = 1.0, b = 0.3 },
	FROST    = { r = 0.5, g = 1.0, b = 1.0 },
	SHADOW   = { r = 0.5, g = 0.5, b = 1.0 },
	ARCANE   = { r = 1.0, g = 0.5, b = 1.0 },
}
addon.COLORS = COLORS

-- Add debuff type colors
for key, color in pairs(DebuffTypeColor) do
	COLORS[key] = color
end

-- Add class colors
for key, color in pairs(CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS) do
	COLORS[key] = color
end
if CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS.RegisterCallback then
	CUSTOM_CLASS_COLORS:RegisterCallback(function() addon:SendMessage("AdiProx_ClassColorsChanged") end)
end

-- Add some colors from font styles
for _, key in pairs{"NORMAL", "HIGHLIGHT", "RED", "DIM_RED", "GREEN", "GRAY", "YELLOW", "LIGHTYELLOW", "ORANGE", "PASSIVE_SPELL"} do
	COLORS[key] = _G[key.."_FONT_COLOR"]
end

-- Core of color: parse color definitiion, either:
-- * addon.ParseColor("colorname", alpha): try to solve the color name
-- * addon.ParseColor(r, g, b, alpha): sanitize the color values
-- Returns (r, g, b, alpha), alpha defaults to 1 and if anything is wrong, returns 1, 1, 1.
local function ParseColor(r, g, b, alpha)
	if type(r) == "string" then
		local c = COLORS[r]
		if c then
			return c.r, c.g, c.b, g or 1
		end
	elseif r and g and b then
		return r, g, b, alpha or 1
	end
	return 1, 1, 1, alpha or 1
end
addon.ParseColor = ParseColor
