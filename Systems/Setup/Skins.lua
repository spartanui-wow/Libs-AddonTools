---@class LibAT
local LibAT = LibAT

local Setup = LibAT.Setup

---@class LibAT.SetupSkins
local Skins = {
	registry = {},
	fonts = {},
}
Setup.Skins = Skins

local WHITE = 'Interface\\Buttons\\WHITE8X8'
local ROOT = 'Interface\\AddOns\\LibsAddonTools\\Media\\Setup\\'
local FONT_PATH = 'Interface\\AddOns\\LibsAddonTools\\Media\\Fonts\\RobotoCondensed-Bold.ttf'

local function TexturePath(skin, name)
	return ROOT .. skin.assetFolder .. '\\' .. name .. '.png'
end

local function SetFont(fontString, size)
	local font = Skins.fonts[size]
	if font then
		fontString:SetFontObject(font)
	end
end

local function CreateFonts()
	for _, size in ipairs({ 11, 12, 14, 18, 26 }) do
		local name = 'LibATSetupFont' .. size
		local font = _G[name] or CreateFont(name)
		font:SetFont(FONT_PATH, size, 'OUTLINE')
		font:SetShadowColor(0, 0, 0, 0.9)
		font:SetShadowOffset(1, -1)
		Skins.fonts[size] = font
	end
end

CreateFonts()

local function AddEdges(frame, layer, inset)
	inset = inset or 0
	local edges = {}
	local top = frame:CreateTexture(nil, layer or 'BORDER')
	top:SetTexture(WHITE)
	top:SetPoint('TOPLEFT', frame, 'TOPLEFT', inset, -inset)
	top:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -inset, -inset)
	top:SetHeight(1)
	local bottom = frame:CreateTexture(nil, layer or 'BORDER')
	bottom:SetTexture(WHITE)
	bottom:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', inset, inset)
	bottom:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -inset, inset)
	bottom:SetHeight(1)
	local left = frame:CreateTexture(nil, layer or 'BORDER')
	left:SetTexture(WHITE)
	left:SetPoint('TOPLEFT', frame, 'TOPLEFT', inset, -inset)
	left:SetPoint('BOTTOMLEFT', frame, 'BOTTOMLEFT', inset, inset)
	left:SetWidth(1)
	local right = frame:CreateTexture(nil, layer or 'BORDER')
	right:SetTexture(WHITE)
	right:SetPoint('TOPRIGHT', frame, 'TOPRIGHT', -inset, -inset)
	right:SetPoint('BOTTOMRIGHT', frame, 'BOTTOMRIGHT', -inset, inset)
	right:SetWidth(1)
	edges[1], edges[2], edges[3], edges[4] = top, bottom, left, right
	return edges
end

local function ColorEdges(edges, r, g, b, a)
	for _, edge in ipairs(edges) do
		edge:SetVertexColor(r, g, b, a or 1)
	end
end

local function Measure(fontString, fallback)
	return LibAT.UI.MeasureText(fontString, fallback or 6)
end

local function RelativeLuminance(r, g, b)
	local function Linear(channel)
		if channel <= 0.04045 then
			return channel / 12.92
		end
		return ((channel + 0.055) / 1.055) ^ 2.4
	end

	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

local function ContrastRatio(a, b)
	local lighter = math.max(a, b)
	local darker = math.min(a, b)
	return (lighter + 0.05) / (darker + 0.05)
end

function Skins:Register(id, skin)
	if type(id) ~= 'string' or id == '' or type(skin) ~= 'table' then
		return
	end
	skin.id = id
	self.registry[id] = skin
end

function Skins:Get(id)
	return self.registry[id] or self.registry.stage or self.registry.classic
end

function Skins:GetActive()
	return self:Get(Setup:GetSkin())
end

local classic = { id = 'classic', name = 'Classic', owned = false }
Skins:Register('classic', classic)

local function CreateOwnedScroll(skin, parent)
	local scroll = CreateFrame('ScrollFrame', nil, parent)
	local child = CreateFrame('Frame', nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	scroll:EnableMouseWheel(true)

	local bar = CreateFrame('Frame', nil, scroll)
	bar:SetPoint('TOPLEFT', scroll, 'TOPRIGHT', 7, 0)
	bar:SetPoint('BOTTOMLEFT', scroll, 'BOTTOMRIGHT', 7, 0)
	bar:SetWidth(5)
	bar.track = bar:CreateTexture(nil, 'BACKGROUND')
	bar.track:SetTexture(WHITE)
	bar.track:SetAllPoints()
	bar.track:SetVertexColor(skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.18)
	bar.thumb = bar:CreateTexture(nil, 'ARTWORK')
	bar.thumb:SetTexture(WHITE)
	bar.thumb:SetPoint('TOPLEFT', bar, 'TOPLEFT', 0, 0)
	bar.thumb:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', 0, 0)
	bar.thumb:SetHeight(28)
	bar.thumb:SetVertexColor(skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.72)
	scroll.ScrollBar = bar

	local function UpdateThumb()
		local view = scroll:GetHeight() or 1
		local content = child:GetHeight() or 1
		local range = math.max(content - view, 0)
		local barHeight = bar:GetHeight() or view
		local thumbHeight = math.max(math.min(barHeight, barHeight * view / math.max(content, 1)), 24)
		local offset = 0
		if range > 0 then
			offset = (barHeight - thumbHeight) * scroll:GetVerticalScroll() / range
		end
		bar.thumb:ClearAllPoints()
		bar.thumb:SetPoint('TOPLEFT', bar, 'TOPLEFT', 0, -offset)
		bar.thumb:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', 0, -offset)
		bar.thumb:SetHeight(thumbHeight)
		bar:SetShown(range > 0)
	end

	scroll:SetScript('OnMouseWheel', function(self, delta)
		local range = math.max((child:GetHeight() or 0) - (self:GetHeight() or 0), 0)
		self:SetVerticalScroll(math.min(math.max(self:GetVerticalScroll() - delta * 42, 0), range))
		UpdateThumb()
	end)
	scroll:HookScript('OnVerticalScroll', UpdateThumb)
	scroll:HookScript('OnSizeChanged', UpdateThumb)
	child:HookScript('OnSizeChanged', UpdateThumb)
	scroll.UpdateOwnedScrollBar = UpdateThumb
	return scroll, child
end

local function CreateOwnedButton(skin, parent, text, primary)
	local button = CreateFrame('Button', nil, parent)
	local SetButtonEnabled = button.SetEnabled
	button:SetHeight(28)
	button.primary = primary and true or false
	button.enabled = true
	button.bg = button:CreateTexture(nil, 'BACKGROUND')
	button.bg:SetAllPoints()
	button.bg:SetTexture(TexturePath(skin, primary and 'button-filled' or 'button'))
	button.label = button:CreateFontString(nil, 'OVERLAY')
	SetFont(button.label, 14)
	button.label:SetPoint('CENTER', button, 'CENTER', 0, 0)
	button.label:SetTextColor(0.94, 0.95, 0.97)

	function button:SetText(value)
		self.label:SetText(value or '')
		self:SetWidth(math.max(54, Measure(self.label, 7) + 30))
	end

	function button:GetText()
		return self.label:GetText()
	end

	function button:SetEnabled(enabled)
		self.enabled = enabled and true or false
		SetButtonEnabled(self, self.enabled)
		self:SetAlpha(self.enabled and 1 or 0.62)
	end

	function button:ApplyAccent()
		if self.primary then
			local r, g, b = LibAT.UI.GetAccentColor()
			self.bg:SetVertexColor(r, g, b, self.enabled and 1 or 0.45)
			local accentLuminance = RelativeLuminance(r, g, b)
			local darkLuminance = RelativeLuminance(0.01, 0.01, 0.01)
			local lightLuminance = RelativeLuminance(1, 1, 1)
			if ContrastRatio(accentLuminance, darkLuminance) >= ContrastRatio(accentLuminance, lightLuminance) then
				self.label:SetTextColor(0.01, 0.01, 0.01)
			else
				self.label:SetTextColor(1, 1, 1)
			end
		else
			self.bg:SetVertexColor(1, 1, 1, self.enabled and 0.9 or 0.5)
			self.label:SetTextColor(0.94, 0.95, 0.97)
		end
	end

	button:SetScript('OnEnter', function(self)
		if self.enabled then
			self.bg:SetAlpha(0.82)
		end
	end)
	button:SetScript('OnLeave', function(self)
		self.bg:SetAlpha(1)
	end)
	button:SetText(text or '')
	button:ApplyAccent()
	return button
end

local function CreateTextButton(skin, parent)
	local button = CreateFrame('Button', nil, parent)
	button:SetHeight(18)
	button.text = button:CreateFontString(nil, 'OVERLAY')
	SetFont(button.text, 11)
	button.text:SetPoint('LEFT')
	button.text:SetJustifyH('LEFT')

	function button:SetLabel(value)
		self.text:SetText(value or '')
		self:SetWidth(Measure(self.text, 6) + 6)
	end

	function button:ApplyColor()
		self.text:SetTextColor(skin.colors.secondary[1], skin.colors.secondary[2], skin.colors.secondary[3])
	end

	button:SetScript('OnEnter', function(self)
		self.text:SetTextColor(1, 1, 1)
	end)
	button:SetScript('OnLeave', function(self)
		self:ApplyColor()
	end)
	button:ApplyColor()
	return button
end

local function CreateProgress(skin, parent)
	local progress = CreateFrame('Frame', nil, parent)
	progress:SetHeight(14)
	progress.minValue = 0
	progress.maxValue = 1
	progress.value = 0
	progress.track = progress:CreateTexture(nil, 'BACKGROUND')
	progress.track:SetTexture(WHITE)
	progress.track:SetPoint('LEFT', progress, 'LEFT', 0, 0)
	progress.track:SetPoint('RIGHT', progress, 'RIGHT', 0, 0)
	progress.track:SetHeight(2)
	progress.track:SetVertexColor(skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.28)
	progress.fill = progress:CreateTexture(nil, 'ARTWORK')
	progress.fill:SetTexture(WHITE)
	progress.fill:SetPoint('LEFT', progress.track, 'LEFT', 0, 0)
	progress.fill:SetHeight(2)
	progress.text = progress:CreateFontString(nil, 'OVERLAY')
	SetFont(progress.text, 11)
	progress.text:SetPoint('CENTER')
	progress.text:SetTextColor(skin.colors.secondary[1], skin.colors.secondary[2], skin.colors.secondary[3])

	function progress:SetMinMaxValues(minValue, maxValue)
		self.minValue = minValue
		self.maxValue = maxValue
	end

	function progress:SetValue(value)
		self.value = value
		local span = math.max(self.maxValue - self.minValue, 1)
		local fraction = math.min(math.max((value - self.minValue) / span, 0), 1)
		self.fill:SetWidth(math.max((self:GetWidth() or 200) * fraction, 1))
	end

	function progress:SetText(value)
		self.text:SetText(value or '')
	end

	function progress:SetStatusBarColor(r, g, b)
		self.fill:SetVertexColor(r, g, b, 1)
	end

	function progress:Update(value, valueText)
		self:SetValue(value)
		self:SetText(valueText)
	end

	progress:HookScript('OnSizeChanged', function(self)
		self:SetValue(self.value)
	end)
	return progress
end

local function CreateBadge(skin, parent)
	local badge = CreateFrame('Frame', nil, parent)
	badge:SetHeight(18)
	badge.edges = AddEdges(badge, 'BORDER')
	badge.bg = badge:CreateTexture(nil, 'BACKGROUND')
	badge.bg:SetTexture(WHITE)
	badge.bg:SetAllPoints()
	badge.text = badge:CreateFontString(nil, 'OVERLAY')
	SetFont(badge.text, 11)
	badge.text:SetPoint('CENTER')

	function badge:SetLabel(value, style)
		self.text:SetText(value or '')
		self:SetWidth(Measure(self.text, 5.7) + 14)
		local r, g, b = skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3]
		local alpha = 0.12
		if style == 'accent' then
			r, g, b = LibAT.UI.GetAccentColor()
			alpha = 0.28
		elseif style == 'done' then
			r, g, b = skin.colors.done[1], skin.colors.done[2], skin.colors.done[3]
			alpha = 0.25
		elseif style == 'skipped' then
			r, g, b = skin.colors.dim[1], skin.colors.dim[2], skin.colors.dim[3]
			alpha = 0.18
		end
		self.bg:SetVertexColor(r, g, b, alpha)
		ColorEdges(self.edges, r, g, b, style == 'recommended' and 0.65 or 0.8)
		self.text:SetTextColor(
			style == 'recommended' and skin.colors.secondary[1] or 0.95,
			style == 'recommended' and skin.colors.secondary[2] or 0.95,
			style == 'recommended' and skin.colors.secondary[3] or 0.95
		)
		self:Show()
	end

	badge:Hide()
	return badge
end

local function CreateSwitchRow(skin, parent, title, description)
	local row = CreateFrame('Button', nil, parent)
	local SetRowEnabled = row.SetEnabled
	row:SetHeight(description and description ~= '' and 38 or 28)
	row.enabled = true
	row.checked = false
	row.bg = row:CreateTexture(nil, 'BACKGROUND')
	row.bg:SetTexture(WHITE)
	row.bg:SetAllPoints()
	row.bg:SetVertexColor(1, 1, 1, 0.025)
	row.bottom = row:CreateTexture(nil, 'BORDER')
	row.bottom:SetTexture(WHITE)
	row.bottom:SetPoint('BOTTOMLEFT')
	row.bottom:SetPoint('BOTTOMRIGHT')
	row.bottom:SetHeight(1)
	row.bottom:SetVertexColor(skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.2)

	row.track = row:CreateTexture(nil, 'ARTWORK')
	row.track:SetTexture(TexturePath(skin, 'switch-track'))
	row.track:SetSize(36, 18)
	row.track:SetPoint('LEFT', row, 'LEFT', 4, 0)
	row.knob = row:CreateTexture(nil, 'OVERLAY')
	row.knob:SetTexture(TexturePath(skin, 'switch-knob'))
	row.knob:SetSize(16, 16)

	row.label = row:CreateFontString(nil, 'OVERLAY')
	SetFont(row.label, 12)
	row.label:SetPoint('TOPLEFT', row, 'TOPLEFT', 50, description and description ~= '' and -4 or -7)
	row.label:SetPoint('RIGHT', row, 'RIGHT', -8, 0)
	row.label:SetJustifyH('LEFT')
	row.label:SetTextColor(skin.colors.text[1], skin.colors.text[2], skin.colors.text[3])
	row.label:SetText(title or '')
	row.description = row:CreateFontString(nil, 'OVERLAY')
	SetFont(row.description, 11)
	row.description:SetPoint('TOPLEFT', row.label, 'BOTTOMLEFT', 0, -1)
	row.description:SetPoint('RIGHT', row, 'RIGHT', -8, 0)
	row.description:SetJustifyH('LEFT')
	row.description:SetTextColor(skin.colors.secondary[1], skin.colors.secondary[2], skin.colors.secondary[3])
	row.description:SetText(description or '')
	row.badge = CreateBadge(skin, row)
	row.badge:SetPoint('RIGHT', row, 'RIGHT', -6, 0)

	function row:SetText(value)
		self.label:SetText(value or '')
	end

	function row:SetDescription(value)
		self.description:SetText(value or '')
		self:SetHeight(value and value ~= '' and 38 or 28)
	end

	function row:SetChecked(checked)
		self.checked = checked and true or false
		self.knob:ClearAllPoints()
		if self.checked then
			self.knob:SetPoint('RIGHT', self.track, 'RIGHT', -1, 0)
		else
			self.knob:SetPoint('LEFT', self.track, 'LEFT', 1, 0)
		end
		self:ApplyAccent()
	end

	function row:GetChecked()
		return self.checked
	end

	function row:SetEnabled(enabled)
		self.enabled = enabled and true or false
		SetRowEnabled(self, self.enabled)
		self:SetAlpha(self.enabled and 1 or 0.6)
	end

	function row:SetBadge(value, style)
		if value and value ~= '' then
			self.badge:SetLabel(value, style)
			self.label:SetPoint('RIGHT', self.badge, 'LEFT', -8, 0)
			self.description:SetPoint('RIGHT', self.badge, 'LEFT', -8, 0)
		else
			self.badge:Hide()
			self.label:SetPoint('RIGHT', self, 'RIGHT', -8, 0)
			self.description:SetPoint('RIGHT', self, 'RIGHT', -8, 0)
		end
	end

	function row:ApplyAccent()
		if self.checked then
			local r, g, b = LibAT.UI.GetAccentColor()
			self.track:SetVertexColor(r, g, b, 1)
		else
			self.track:SetVertexColor(1, 1, 1, 1)
		end
	end

	row:SetScript('OnClick', function(self)
		if not self.enabled then
			return
		end
		self:SetChecked(not self:GetChecked())
		if self.onToggle then
			self.onToggle(self:GetChecked())
		end
	end)
	row:SetChecked(false)
	return row
end

local function CreateOwnedCard(skin, parent, opts)
	local card = CreateFrame('Button', nil, parent)
	card:SetSize(180, opts.cardHeight or 58)
	card:RegisterForClicks('LeftButtonUp')
	card.enabled = true
	card.selected = false
	card.bg = card:CreateTexture(nil, 'BACKGROUND')
	card.bg:SetTexture(WHITE)
	card.bg:SetAllPoints()
	card.bg:SetVertexColor(skin.colors.card[1], skin.colors.card[2], skin.colors.card[3], skin.colors.card[4])
	card.glow = card:CreateTexture(nil, 'BACKGROUND', nil, -1)
	card.glow:SetTexture(TexturePath(skin, 'soft-shadow'))
	card.glow:SetPoint('TOPLEFT', card, 'TOPLEFT', -9, 9)
	card.glow:SetPoint('BOTTOMRIGHT', card, 'BOTTOMRIGHT', 9, -9)
	card.glow:Hide()
	card.edges = AddEdges(card, 'BORDER')
	ColorEdges(card.edges, skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.48)

	card.art = card:CreateTexture(nil, 'ARTWORK')
	card.art:SetPoint('TOPLEFT', card, 'TOPLEFT', 5, -5)
	card.art:SetPoint('TOPRIGHT', card, 'TOPRIGHT', -5, -5)
	card.art:SetHeight(opts.artHeight or 0)
	card.art:SetShown((opts.artHeight or 0) > 0)

	card.check = card:CreateTexture(nil, 'OVERLAY')
	card.check:SetSize(18, 18)
	card.check:SetTexture(TexturePath(skin, 'chapter-marker'))
	card.check:SetPoint('LEFT', card, 'LEFT', 10, 0)
	card.checkMark = card:CreateTexture(nil, 'OVERLAY', nil, 1)
	card.checkMark:SetAllPoints(card.check)
	card.checkMark:SetTexture(TexturePath(skin, 'chapter-check'))
	card.check:Hide()
	card.checkMark:Hide()

	card.title = card:CreateFontString(nil, 'OVERLAY')
	SetFont(card.title, 14)
	card.title:SetJustifyH('LEFT')
	card.title:SetTextColor(skin.colors.text[1], skin.colors.text[2], skin.colors.text[3])
	card.caption = card:CreateFontString(nil, 'OVERLAY')
	SetFont(card.caption, 11)
	card.caption:SetJustifyH('LEFT')
	card.caption:SetJustifyV('TOP')
	card.caption:SetWordWrap(true)
	card.caption:SetTextColor(skin.colors.secondary[1], skin.colors.secondary[2], skin.colors.secondary[3])
	card.tag = card:CreateFontString(nil, 'OVERLAY')
	SetFont(card.tag, 11)
	card.tag:SetJustifyH('RIGHT')
	card.tag:SetTextColor(skin.colors.dim[1], skin.colors.dim[2], skin.colors.dim[3])
	card.recBadge = CreateBadge(skin, card)
	card.stateBadge = CreateBadge(skin, card)
	card.link = CreateTextButton(skin, card)
	card.variant = CreateTextButton(skin, card)

	local function ApplyArt(art)
		if not art or (opts.artHeight or 0) <= 0 then
			card.art:Hide()
			return
		end
		card.art:SetTexCoord(0, 1, 0, 1)
		card.art:SetVertexColor(1, 1, 1, 1)
		if art.texture then
			card.art:SetTexture(art.texture)
		elseif art.color then
			card.art:SetColorTexture(art.color[1] or 0, art.color[2] or 0, art.color[3] or 0, art.color[4] or 1)
		else
			card.art:SetTexture(WHITE)
			card.art:SetVertexColor(0.12, 0.12, 0.13, 1)
		end
		if art.texCoord and art.texCoord[4] then
			card.art:SetTexCoord(art.texCoord[1], art.texCoord[2], art.texCoord[3], art.texCoord[4])
		end
		card.art:SetDesaturated(art.desaturate and true or false)
		card.art:Show()
	end

	function card:LayoutParts()
		local data = self.data or {}
		local top = self.art:IsShown() and ((opts.artHeight or 0) + 11) or 8
		self.title:ClearAllPoints()
		self.title:SetPoint('TOPLEFT', self, 'TOPLEFT', data.checkable and 36 or 11, -top)
		self.title:SetPoint('RIGHT', self, 'RIGHT', -11, 0)
		self.caption:ClearAllPoints()
		self.caption:SetPoint('TOPLEFT', self.title, 'BOTTOMLEFT', 0, -2)
		self.caption:SetPoint('RIGHT', self, 'RIGHT', -11, 0)
		self.caption:SetPoint('BOTTOM', self, 'BOTTOM', 0, 8)
		self.tag:ClearAllPoints()
		self.tag:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -10, -top)
		if data.tag and data.tag ~= '' then
			self.title:SetPoint('RIGHT', self.tag, 'LEFT', -8, 0)
		end
		self.recBadge:ClearAllPoints()
		self.recBadge:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -9, -9)
		self.stateBadge:ClearAllPoints()
		self.stateBadge:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 9, 8)
		self.link:ClearAllPoints()
		self.link:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -10, 8)
		self.variant:ClearAllPoints()
		self.variant:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -10, 8)
	end

	function card:SetData(data)
		self.data = data
		ApplyArt(data.art)
		self.title:SetText(data.title or '')
		self.caption:SetText(data.caption or '')
		self.tag:SetText(data.tag or '')
		self.check:SetShown(data.checkable and true or false)
		self.checkMark:SetShown(data.checkable and data.checked and true or false)
		if data.recommended then
			self.recBadge:SetLabel('Recommended', 'recommended')
		else
			self.recBadge:Hide()
		end
		if data.link and data.link.text then
			self.link:SetLabel(data.link.text)
			self.link:SetScript('OnClick', function()
				if card.data and card.data.link and card.data.link.onClick then
					card.data.link.onClick(card)
				end
			end)
			self.link:Show()
		else
			self.link:Hide()
		end
		if data.variants and #data.variants > 1 then
			local label = data.variants[1].text
			for _, variant in ipairs(data.variants) do
				if variant.value == data.variant then
					label = variant.text
				end
			end
			self.variant:SetLabel('Style: ' .. label)
			self.variant:Show()
		else
			self.variant:Hide()
		end
		self:LayoutParts()
		self:ApplyAccent()
	end

	function card:SetState(selected, enabled, label)
		self.selected = selected and true or false
		self.enabled = enabled ~= false
		self:SetAlpha(self.enabled and 1 or 0.48)
		if label and label ~= '' then
			local style = label == 'Done' and 'done' or (label == 'Skipped' and 'skipped' or 'accent')
			self.stateBadge:SetLabel(label, style)
		else
			self.stateBadge:Hide()
		end
		self:ApplyAccent()
	end

	function card:SetChecked(checked)
		if self.data then
			self.data.checked = checked and true or false
		end
		self.checkMark:SetShown(checked and true or false)
	end

	function card:GetChecked()
		return self.data and self.data.checked and true or false
	end

	function card:ApplyAccent()
		local r, g, b = LibAT.UI.GetAccentColor()
		if self.selected then
			ColorEdges(self.edges, r, g, b, 1)
			self.glow:SetVertexColor(r, g, b, 0.58)
			self.glow:Show()
		else
			ColorEdges(self.edges, skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.48)
			self.glow:Hide()
		end
		if self.recBadge:IsShown() then
			self.recBadge:SetLabel('Recommended', 'recommended')
		end
		if self.stateBadge:IsShown() and self.stateBadge.text:GetText() then
			local label = self.stateBadge.text:GetText()
			self.stateBadge:SetLabel(label, label == 'Done' and 'done' or (label == 'Skipped' and 'skipped' or 'accent'))
		end
	end

	function card:Reset()
		self:Hide()
		self:ClearAllPoints()
		self.data = nil
		self.onClick = nil
		self.onVariant = nil
		self.onCheck = nil
		self.stateBadge:Hide()
		self.recBadge:Hide()
		self.link:Hide()
		self.variant:Hide()
	end

	card.variant:SetScript('OnClick', function()
		local data = card.data
		if not data or not data.variants or #data.variants == 0 then
			return
		end
		local index = 1
		for i, variant in ipairs(data.variants) do
			if variant.value == data.variant then
				index = i
			end
		end
		local nextVariant = data.variants[(index % #data.variants) + 1]
		data.variant = nextVariant.value
		card.variant:SetLabel('Style: ' .. nextVariant.text)
		if card.onVariant then
			card.onVariant(card, data.value, nextVariant.value)
		end
	end)
	card:SetScript('OnClick', function(self, button)
		if not self.enabled or not self.data then
			return
		end
		if self.data.checkable then
			self:SetChecked(not self:GetChecked())
			if self.onCheck then
				self.onCheck(self, self.data.value, self:GetChecked())
			end
		elseif self.onClick then
			self.onClick(self, self.data.value, button)
		end
	end)
	card:SetScript('OnEnter', function(self)
		if not self.selected then
			ColorEdges(self.edges, skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.86)
		end
	end)
	card:SetScript('OnLeave', function(self)
		self:ApplyAccent()
	end)
	return card
end

local function CreateCardGrid(skin, parent, opts)
	local grid = CreateFrame('Frame', nil, parent)
	grid:SetHeight(1)
	grid.opts = opts
	grid.cards = {}
	grid.pool = {}

	function grid:SetCards(list)
		for _, card in ipairs(self.cards) do
			card:Reset()
			self.pool[#self.pool + 1] = card
		end
		self.cards = {}
		for _, data in ipairs(list) do
			local card = table.remove(self.pool) or CreateOwnedCard(skin, self, self.opts)
			card:SetParent(self)
			card.onClick = self.opts.onClick
			card.onVariant = self.opts.onVariant
			card.onCheck = self.opts.onCheck
			card:SetData(data)
			card:Show()
			self.cards[#self.cards + 1] = card
		end
	end

	function grid:Layout(width)
		local spacing = self.opts.spacing or 10
		local columns = math.max(1, math.min(self.opts.maxColumns or 2, math.floor((width + spacing) / ((self.opts.minWidth or 210) + spacing))))
		local cardWidth = math.floor((width - (columns - 1) * spacing) / columns)
		local rowHeight = self.opts.cardHeight or 58
		for i, card in ipairs(self.cards) do
			local column = (i - 1) % columns
			local row = math.floor((i - 1) / columns)
			card:ClearAllPoints()
			card:SetPoint('TOPLEFT', self, 'TOPLEFT', column * (cardWidth + spacing), -row * (rowHeight + spacing))
			card:SetSize(cardWidth, rowHeight)
			card:LayoutParts()
		end
		local rows = math.ceil(#self.cards / columns)
		local height = math.max(rows * rowHeight + math.max(rows - 1, 0) * spacing, 1)
		self:SetSize(width, height)
		return height
	end

	function grid:GetCard(value)
		for _, card in ipairs(self.cards) do
			if card.data and card.data.value == value then
				return card
			end
		end
	end

	function grid:ApplyAccent()
		for _, card in ipairs(self.cards) do
			card:ApplyAccent()
		end
	end
	return grid
end

local function CreateOwnedWindow(skin)
	local name = 'LibAT_SetupHub_' .. skin.id
	local window = CreateFrame('Frame', name, UIParent)
	window:SetSize(1024, 650)
	window:SetPoint('CENTER')
	window:SetFrameStrata('HIGH')
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag('LeftButton')
	window:SetScript('OnDragStart', window.StartMoving)
	window:SetScript('OnDragStop', function(self)
		self:StopMovingOrSizing()
	end)
	window:Hide()
	if window.SetDontSavePosition then
		window:SetDontSavePosition(true)
	end
	if UISpecialFrames then
		tinsert(UISpecialFrames, name)
	end

	local visual = CreateFrame('Frame', nil, window)
	visual:SetAllPoints()
	window.VisualRoot = visual
	window.Backdrop = visual:CreateTexture(nil, 'BACKGROUND', nil, -7)
	window.Backdrop:SetAllPoints()
	window.Backdrop:SetTexture(skin:GetBackdrop())
	-- Shipped backdrops are 2:1. Crop their sides to fill the 1024x650 window without stretching.
	window.Backdrop:SetTexCoord(0.106, 0.894, 0, 1)
	window.Dim = visual:CreateTexture(nil, 'BACKGROUND', nil, -6)
	window.Dim:SetAllPoints()
	window.Dim:SetTexture(WHITE)
	window.Dim:SetVertexColor(skin.colors.ground[1], skin.colors.ground[2], skin.colors.ground[3], skin.colors.ground[4])

	window.Shadow = visual:CreateTexture(nil, 'BACKGROUND', nil, -8)
	window.Shadow:SetTexture(TexturePath(skin, 'soft-shadow'))
	window.Shadow:SetPoint('TOPLEFT', window, 'TOPLEFT', -18, 18)
	window.Shadow:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', 18, -18)
	window.Rim = visual:CreateTexture(nil, 'BORDER')
	window.Rim:SetTexture(TexturePath(skin, 'glass-rim'))
	window.Rim:SetAllPoints()

	local titleBar = CreateFrame('Frame', nil, visual)
	titleBar:SetPoint('TOPLEFT', window, 'TOPLEFT', 1, -1)
	titleBar:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -1, -1)
	titleBar:SetHeight(36)
	titleBar.bg = titleBar:CreateTexture(nil, 'BACKGROUND')
	titleBar.bg:SetAllPoints()
	if skin.titleTexture then
		titleBar.bg:SetTexture(TexturePath(skin, skin.titleTexture))
	else
		titleBar.bg:SetTexture(WHITE)
		titleBar.bg:SetVertexColor(skin.colors.panel[1], skin.colors.panel[2], skin.colors.panel[3], 0.94)
	end
	titleBar.edges = AddEdges(titleBar, 'BORDER')
	ColorEdges(titleBar.edges, skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.5)
	window.TitleText = titleBar:CreateFontString(nil, 'OVERLAY')
	SetFont(window.TitleText, 18)
	window.TitleText:SetPoint('LEFT', titleBar, 'LEFT', 16, 0)
	window.TitleText:SetText('Setup')
	window.TitleText:SetTextColor(skin.colors.text[1], skin.colors.text[2], skin.colors.text[3])

	local close = CreateFrame('Button', nil, window)
	close:SetSize(28, 28)
	close:SetPoint('TOPRIGHT', window, 'TOPRIGHT', -6, -5)
	close.bg = close:CreateTexture(nil, 'BACKGROUND')
	close.bg:SetTexture(WHITE)
	close.bg:SetAllPoints()
	close.bg:SetVertexColor(0.05, 0.05, 0.06, 0.55)
	close.edges = AddEdges(close, 'BORDER')
	ColorEdges(close.edges, skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.6)
	close.a = close:CreateTexture(nil, 'ARTWORK')
	close.a:SetTexture(WHITE)
	close.a:SetSize(15, 2)
	close.a:SetPoint('CENTER')
	close.a:SetRotation(math.rad(45))
	close.b = close:CreateTexture(nil, 'ARTWORK')
	close.b:SetTexture(WHITE)
	close.b:SetSize(15, 2)
	close.b:SetPoint('CENTER')
	close.b:SetRotation(math.rad(-45))
	close:SetScript('OnClick', function()
		window:Hide()
	end)
	window.CloseButton = close
	window.closeBtn = close

	window.MainContent = CreateFrame('Frame', nil, visual)
	window.MainContent:SetPoint('TOPLEFT', window, 'TOPLEFT', 10, -46)
	window.MainContent:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -10, 62)
	window.LeftPanel = CreateFrame('Frame', nil, window.MainContent)
	window.LeftPanel:SetPoint('TOPLEFT')
	window.LeftPanel:SetPoint('BOTTOMLEFT')
	window.LeftPanel:SetWidth(218)
	window.RightPanel = CreateFrame('Frame', nil, window.MainContent)
	window.RightPanel:SetPoint('TOPLEFT', window.LeftPanel, 'TOPRIGHT', 12, 0)
	window.RightPanel:SetPoint('BOTTOMRIGHT')
	for _, panel in ipairs({ window.LeftPanel, window.RightPanel }) do
		panel.bg = panel:CreateTexture(nil, 'BACKGROUND')
		panel.bg:SetAllPoints()
		if skin.panelTexture then
			panel.bg:SetTexture(TexturePath(skin, skin.panelTexture))
			panel.bg:SetVertexColor(1, 1, 1, panel == window.LeftPanel and 0.74 or 0.82)
		else
			panel.bg:SetTexture(WHITE)
			panel.bg:SetVertexColor(skin.colors.panel[1], skin.colors.panel[2], skin.colors.panel[3], panel == window.LeftPanel and 0.79 or 0.88)
		end
		panel.edges = AddEdges(panel, 'BORDER')
		ColorEdges(panel.edges, skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], panel == window.LeftPanel and 0.36 or 0.58)
	end

	window.Footer = CreateFrame('Frame', nil, visual)
	window.Footer:SetPoint('BOTTOMLEFT', window, 'BOTTOMLEFT', 1, 1)
	window.Footer:SetPoint('BOTTOMRIGHT', window, 'BOTTOMRIGHT', -1, 1)
	window.Footer:SetHeight(52)
	window.Footer.bg = window.Footer:CreateTexture(nil, 'BACKGROUND')
	window.Footer.bg:SetAllPoints()
	if skin.titleTexture then
		window.Footer.bg:SetTexture(TexturePath(skin, skin.titleTexture))
	else
		window.Footer.bg:SetTexture(WHITE)
		window.Footer.bg:SetVertexColor(skin.colors.panel[1], skin.colors.panel[2], skin.colors.panel[3], 0.94)
	end
	window.Footer.edges = AddEdges(window.Footer, 'BORDER')
	ColorEdges(window.Footer.edges, skin.colors.rim[1], skin.colors.rim[2], skin.colors.rim[3], 0.5)

	function window:SetTitle(value)
		self.TitleText:SetText(value or 'Setup')
	end

	function window:RefreshBackdrop()
		self.Backdrop:SetTexture(skin:GetBackdrop())
		self.Backdrop:SetTexCoord(0.106, 0.894, 0, 1)
	end

	return window
end

function Skins.CreateOwnedSkin(config)
	local skin = config
	skin.owned = true

	function skin:GetBackdrop()
		if self.id == 'stage' then
			return LibAT.UI.GetBackdrop() or TexturePath(self, 'backdrop')
		end
		return TexturePath(self, 'backdrop')
	end

	function skin:CreateWindow()
		return CreateOwnedWindow(self)
	end

	function skin:CreateScroll(parent)
		return CreateOwnedScroll(self, parent)
	end

	function skin:CreateButton(parent, text, primary)
		return CreateOwnedButton(self, parent, text, primary)
	end

	function skin:CreateTextButton(parent)
		return CreateTextButton(self, parent)
	end

	function skin:CreateProgress(parent)
		return CreateProgress(self, parent)
	end

	function skin:CreateCardGrid(parent, opts)
		return CreateCardGrid(self, parent, opts)
	end

	function skin:CreateBadge(parent)
		return CreateBadge(self, parent)
	end

	function skin:CreateSwitchRow(parent, title, description)
		return CreateSwitchRow(self, parent, title, description)
	end

	function skin:SetFont(fontString, size)
		SetFont(fontString, size)
	end

	function skin:Texture(name)
		return TexturePath(self, name)
	end

	function skin:ApplyAccent(window)
		if window and window.RefreshBackdrop then
			window:RefreshBackdrop()
		end
		for _, button in ipairs(window and window.ownedButtons or {}) do
			button:ApplyAccent()
		end
	end

	return skin
end

return Skins
