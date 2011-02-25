--[[
AdiProx - Proximity display.
Copyright 2011 Adirelle (adirelle@tagada-team.net)
All rights reserved.
--]]

local addonName, addon = ...

local TEXTURES = {}
addon.TEXTURES = TEXTURES

local DEFAULT_TEXTURE = {
	texCoord = { 0, 1, 0, 1 },
	blendMode = "BLEND",
	sizeModifier = 1
}

local function ParseTexture(texture, blendMode)
	if texture then
		local t = TEXTURES[texture] or DEFAULT_TEXTURE
		return t.path or texture, blendMode or t.blendMode, t.sizeModifier, t.texCoord		
	end
end
addon.ParseTexture = ParseTexture

local texParentProto = UIParent:CreateTexture()
local texProto = setmetatable({}, { __index = texParentProto })
local texMeta = { __index = texProto }

function addon:CreateTexture(parent, ...)
	local t = setmetatable(parent:CreateTexture(...), texMeta)
	t.angle, t.sizeModifier, t.texCoord = 0, DEFAULT_TEXTURE.sizeModifier, DEFAULT_TEXTURE.texCoord
	return t
end

function texProto:SetTexture(texture, ...)
	if type(texture) == "string" then
		local path, blendMode
		path, blendMode, self.sizeModifier, self.texCoord = ParseTexture(texture, ...)
		addon:Debug('SetTexture', texture, '=>', path, blendMode, self.sizeModifier, self.texCoord)
		self:SetBlendMode(blendMode)
		self:SetTexCoord(unpack(self.texCoord))
		return texParentProto.SetTexture(self, path)
	else
		self.angle, self.sizeModifier, self.texCoord = 0, DEFAULT_TEXTURE.sizeModifier, DEFAULT_TEXTURE.texCoord
		return texParentProto.SetTexture(self, texture, ...)
	end
end

local ParseColor = addon.ParseColor
function texProto:SetVertexColor(...)
	return texParentProto.SetVertexColor(self, ParseColor(...))
end

function texProto:DrawRouteLine(sx, sy, ex, ey, width, anchor, relPoint)
	return DrawRouteLine(self, anchor or self:GetParent(), sx, sy, ex, ey, width, relPoint)
end

-- Here commes the default textures
local function AddTexture(key, path, blendMode, sizeModifier, x0, x1, y0, y1)
	local t = {
		path = path,
		blendMode = blendMode or DEFAULT_TEXTURE.blendMode,
		sizeModifier = sizeModifier or DEFAULT_TEXTURE.sizeModifier,
	}
	if x0 and x1 and y0 and y1 then
		t.texCoord = { x0, x1, y0, y1 }
	else
		t.texCoord = DEFAULT_TEXTURE.texCoord
	end
	TEXTURES[key] = t
end

-- Textures borrowed from Antiarc's HudMap
AddTexture("targeting", [[Interface\Minimap\Ping\ping5]], "ADD")
AddTexture("highlight", [[Interface\AddOns\AdiProx\media\alert_circle]], "ADD")
AddTexture("radius", [[Interface\AddOns\AdiProx\media\radius]])
AddTexture("radius_lg", [[Interface\AddOns\AdiProx\media\radius_lg]])
AddTexture("timer", [[Interface\AddOns\AdiProx\media\timer]])
AddTexture("glow", [[Interface\GLUES\MODELS\UI_Tauren\gradientCircle]], "ADD")
AddTexture("party", [[Interface\MINIMAP\PartyRaidBlips]])
AddTexture("reticle", [[SPELLS\Reticle_128]], "ADD", 1, 0.05, 0.95, 0.05, 0.95)
AddTexture("ring", [[SPELLS\CIRCLE]], "ADD")
AddTexture("fuzzyring", [[SPELLS\WHITERINGTHIN128]], "ADD")
AddTexture("fatring", [[SPELLS\WhiteRingFat128]], "ADD")
AddTexture("rune1", [[SPELLS\AURARUNE256]], "ADD", 0.86)
AddTexture("rune2", [[SPELLS\AURARUNE9]], "ADD", 0.86)
AddTexture("rune3", [[SPELLS\AURARUNE_A]], "ADD", 0.77)
AddTexture("rune4", [[SPELLS\AURARUNE_B]], "ADD", 1, 0.032, 0.959, 0.035, 0.959)
