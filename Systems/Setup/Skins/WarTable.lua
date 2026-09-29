---@class LibAT
local LibAT = LibAT

local Skins = LibAT.Setup.Skins

Skins:Register(
	'wartable',
	Skins.CreateOwnedSkin({
		name = 'The War Table',
		assetFolder = 'wartable',
		titleTexture = 'oak-tile',
		panelTexture = 'map-slate-tile',
		route = true,
		colors = {
			ground = { 0.09, 0.065, 0.045, 0.25 },
			panel = { 0.12, 0.15, 0.16, 0.9 },
			card = { 0.105, 0.12, 0.12, 0.96 },
			rim = { 0.68, 0.53, 0.31 },
			text = { 0.93, 0.91, 0.85 },
			secondary = { 0.72, 0.68, 0.59 },
			dim = { 0.65, 0.62, 0.56 },
			done = { 0.35, 0.67, 0.39 },
		},
	})
)
