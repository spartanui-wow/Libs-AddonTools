---@class LibAT
local LibAT = LibAT

local Skins = LibAT.Setup.Skins

Skins:Register(
	'stage',
	Skins.CreateOwnedSkin({
		name = 'The Selection Stage',
		assetFolder = 'stage',
		colors = {
			ground = { 0.08, 0.08, 0.1, 0.42 },
			panel = { 0.17, 0.18, 0.2, 0.88 },
			card = { 0.12, 0.13, 0.15, 0.94 },
			rim = { 0.61, 0.63, 0.67 },
			text = { 0.91, 0.92, 0.94 },
			secondary = { 0.67, 0.69, 0.72 },
			dim = { 0.64, 0.66, 0.69 },
			done = { 0.32, 0.7, 0.42 },
		},
	})
)
