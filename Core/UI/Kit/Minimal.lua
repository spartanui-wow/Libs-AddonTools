---@class LibAT
local LibAT = LibAT

local Kit = LibAT.UI.Kit
local ROOT = 'Interface\\AddOns\\LibsAddonTools\\Media\\UI\\Kits\\minimal\\'

Kit:Register('minimal', {
	name = 'Minimal',
	backdropAspect = 2,
	backdropDim = 0.48,
	materialAlpha = 0.035,
	windowMaterialAlpha = 0.025,
	footerInset = 24,
	colors = {
		surface = {
			[0] = { 0.035, 0.045, 0.055, 0.94 },
			[1] = { 0.06, 0.075, 0.09, 0.94 },
			[2] = { 0.09, 0.11, 0.13, 0.97 },
			[3] = { 0.13, 0.15, 0.18, 0.98 },
		},
		text = { 0.93, 0.95, 0.97 },
		secondary = { 0.72, 0.76, 0.8 },
		muted = { 0.58, 0.62, 0.66 },
		disabled = { 0.42, 0.45, 0.49 },
		trim = { 0.52, 0.59, 0.65 },
		done = { 0.32, 0.7, 0.42 },
		warning = { 0.94, 0.68, 0.22 },
		skipped = { 0.56, 0.58, 0.62 },
	},
	assets = {
		windowBorder = {
			canvas = { 64, 64 },
			cornerSize = 16,
			edgeSize = 1,
			edgeCrop = 1 / 16,
			tileLength = 32,
			pieces = {
				topLeft = ROOT .. 'frame-top-left.png',
				topRight = ROOT .. 'frame-top-right.png',
				bottomLeft = ROOT .. 'frame-bottom-left.png',
				bottomRight = ROOT .. 'frame-bottom-right.png',
				top = ROOT .. 'frame-top.png',
				bottom = ROOT .. 'frame-bottom.png',
				left = ROOT .. 'frame-left.png',
				right = ROOT .. 'frame-right.png',
			},
		},
		headerPlate = ROOT .. 'header-plate.png',
		divider = ROOT .. 'divider.png',
		buttonPrimary = {
			left = ROOT .. 'button-primary-left.png',
			center = ROOT .. 'button-primary-center.png',
			right = ROOT .. 'button-primary-right.png',
			capWidth = 16,
		},
		buttonSecondary = {
			left = ROOT .. 'button-secondary-left.png',
			center = ROOT .. 'button-secondary-center.png',
			right = ROOT .. 'button-secondary-right.png',
			capWidth = 16,
		},
		activeMarker = ROOT .. 'active-marker.png',
		['chapter-marker'] = ROOT .. 'active-marker.png',
		check = ROOT .. 'check.png',
		['chapter-check'] = ROOT .. 'check.png',
		insetWell = ROOT .. 'inset-well.png',
		materialTile = ROOT .. 'material-tile.png',
		cornerOrnament = ROOT .. 'corner-ornament.png',
		shadow = ROOT .. 'shadow.png',
		switchTrack = ROOT .. 'switch-track.png',
		switchKnob = ROOT .. 'switch-knob.png',
		radioRing = ROOT .. 'radio-ring.png',
		checkMark = ROOT .. 'check-mark.png',
		triangle = ROOT .. 'triangle.png',
		chevron = ROOT .. 'triangle.png',
	},
})

return Kit
