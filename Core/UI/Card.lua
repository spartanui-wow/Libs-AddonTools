---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Cards - a picture, a title and a short caption the player can click
----------------------------------------------------------------------------------------------------

---@class LibAT.CardArt
---@field texture? string|number Texture path or file ID
---@field atlas? string Atlas name (used only when the client has it)
---@field texCoord? number[] left, right, top, bottom
---@field color? number[] r, g, b[, a] solid color when there is no picture
---@field desaturate? boolean

---@class LibAT.CardVariant
---@field value any
---@field text string

---@class LibAT.CardData
---@field value any Value handed to the click handler
---@field title string
---@field caption? string One or two short lines
---@field tag? string Small label in the top-right corner (e.g. 'Core')
---@field art? LibAT.CardArt
---@field accent? number[] r, g, b for this card's band; the LibAT accent when nil
---@field recommended? boolean Shows the Recommended badge
---@field variants? LibAT.CardVariant[] Adds a small style picker
---@field variant? any The selected variant
---@field checkable? boolean Clicking the card toggles a check box instead of picking it
---@field checked? boolean
---@field link? {text: string, onClick: fun(card: LibAT.Card)} Small text button in the bottom-right corner
---@field tooltip? string Extra text shown on hover

---@class LibAT.CardOptions
---@field width? number
---@field height? number
---@field artHeight? number Height of the picture area (0 hides it)

---@class LibAT.Card : Button
---@field data LibAT.CardData|nil
---@field selected boolean
---@field enabled boolean

local BORDER = { 0.22, 0.22, 0.24 }
local BORDER_HOVER = { 0.45, 0.45, 0.48 }
local BACKGROUND = { 0.06, 0.06, 0.07, 0.92 }
local BACKGROUND_SELECTED = { 0.11, 0.11, 0.12, 0.95 }
local BAND_HEIGHT = 3
local PAD = 8

---Does this client know the atlas?
---@param atlas string
---@return boolean
function LibAT.UI.HasAtlas(atlas)
	if type(atlas) ~= 'string' or atlas == '' then
		return false
	end
	if C_Texture and C_Texture.GetAtlasInfo then
		return C_Texture.GetAtlasInfo(atlas) ~= nil
	end
	return false
end

---Inline atlas markup, or '' when the client does not have the atlas
---@param atlas string
---@param size? number
---@return string
function LibAT.UI.AtlasMarkup(atlas, size)
	if not LibAT.UI.HasAtlas(atlas) then
		return ''
	end
	size = size or 0
	return '|A:' .. atlas .. ':' .. size .. ':' .. size .. '|a'
end

---Width of a font string's text. The client can report 0 before a font has been drawn once, so fall
---back to an estimate from the number of letters.
---@param fontString FontString
---@param perLetter? number
---@return number
function LibAT.UI.MeasureText(fontString, perLetter)
	local text = fontString:GetText() or ''
	local width = 0
	if fontString.GetUnboundedStringWidth then
		width = fontString:GetUnboundedStringWidth() or 0
	elseif fontString.GetStringWidth then
		width = fontString:GetStringWidth() or 0
	end
	if width <= 0 then
		local plain = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', ''):gsub('|A.-|a', '')
		width = #plain * (perLetter or 6)
	end
	return width
end

---Small rounded-looking label with a colored backing
---@param parent Frame
---@return Frame badge
local function CreateBadge(parent)
	local badge = CreateFrame('Frame', nil, parent)
	badge:SetHeight(14)
	badge.bg = badge:CreateTexture(nil, 'BACKGROUND')
	badge.bg:SetAllPoints()
	badge.text = badge:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	badge.text:SetPoint('CENTER', badge, 'CENTER', 0, 0)
	function badge:SetLabel(text, r, g, b)
		self.text:SetText(text)
		self.bg:SetColorTexture(r, g, b, 0.85)
		self:SetWidth(LibAT.UI.MeasureText(self.text, 5.5) + 10)
		self:Show()
	end
	badge:Hide()
	return badge
end

---Paint the one-pixel border
---@param card LibAT.Card
---@param r number
---@param g number
---@param b number
local function SetBorderColor(card, r, g, b)
	for _, edge in ipairs(card.edges) do
		edge:SetColorTexture(r, g, b, 1)
	end
end

---Repaint the border and background for the current hover/selected state
---@param card LibAT.Card
local function PaintFrame(card)
	if card.selected then
		local r, g, b = card:GetAccent()
		SetBorderColor(card, r, g, b)
		card.bg:SetColorTexture(BACKGROUND_SELECTED[1], BACKGROUND_SELECTED[2], BACKGROUND_SELECTED[3], BACKGROUND_SELECTED[4])
	else
		local c = card.hovered and card.enabled and BORDER_HOVER or BORDER
		SetBorderColor(card, c[1], c[2], c[3])
		card.bg:SetColorTexture(BACKGROUND[1], BACKGROUND[2], BACKGROUND[3], BACKGROUND[4])
	end
end

---Apply picture settings to the art texture
---@param card LibAT.Card
---@param art LibAT.CardArt|nil
local function ApplyArt(card, art)
	local tex = card.art
	if card.artHeight <= 0 or not art then
		tex:Hide()
		return
	end
	tex:SetTexCoord(0, 1, 0, 1)
	tex:SetVertexColor(1, 1, 1, 1)
	local shown = false
	if art.atlas and LibAT.UI.HasAtlas(art.atlas) then
		tex:SetAtlas(art.atlas)
		shown = true
	elseif art.texture then
		tex:SetTexture(art.texture)
		shown = true
	elseif art.color then
		tex:SetColorTexture(art.color[1] or 0, art.color[2] or 0, art.color[3] or 0, art.color[4] or 1)
		shown = true
	end
	if shown and art.texCoord and art.texCoord[4] then
		tex:SetTexCoord(art.texCoord[1], art.texCoord[2], art.texCoord[3], art.texCoord[4])
	end
	tex:SetDesaturated(art.desaturate and true or false)
	tex:SetShown(shown)
end

---Find the text for a variant value
---@param variants LibAT.CardVariant[]
---@param value any
---@return string
local function VariantText(variants, value)
	for _, v in ipairs(variants) do
		if v.value == value then
			return v.text
		end
	end
	return variants[1] and variants[1].text or ''
end

---Create a card. Cards are usually made through CreateCardGrid, which reuses them.
---@param parent Frame
---@param opts? LibAT.CardOptions
---@return LibAT.Card card
function LibAT.UI.CreateCard(parent, opts)
	opts = opts or {}
	---@type LibAT.Card
	local card = CreateFrame('Button', nil, parent)
	card:SetSize(opts.width or 180, opts.height or 150)
	card:RegisterForClicks('LeftButtonUp')
	card.artHeight = opts.artHeight or 0
	card.selected = false
	card.enabled = true
	card.hovered = false

	card.bg = card:CreateTexture(nil, 'BACKGROUND')
	card.bg:SetAllPoints()

	card.edges = {}
	local top = card:CreateTexture(nil, 'BORDER')
	top:SetPoint('TOPLEFT')
	top:SetPoint('TOPRIGHT')
	top:SetHeight(1)
	local bottom = card:CreateTexture(nil, 'BORDER')
	bottom:SetPoint('BOTTOMLEFT')
	bottom:SetPoint('BOTTOMRIGHT')
	bottom:SetHeight(1)
	local left = card:CreateTexture(nil, 'BORDER')
	left:SetPoint('TOPLEFT')
	left:SetPoint('BOTTOMLEFT')
	left:SetWidth(1)
	local right = card:CreateTexture(nil, 'BORDER')
	right:SetPoint('TOPRIGHT')
	right:SetPoint('BOTTOMRIGHT')
	right:SetWidth(1)
	card.edges = { top, bottom, left, right }

	card.band = card:CreateTexture(nil, 'ARTWORK')
	card.band:SetPoint('TOPLEFT', card, 'TOPLEFT', 1, -1)
	card.band:SetPoint('TOPRIGHT', card, 'TOPRIGHT', -1, -1)
	card.band:SetHeight(BAND_HEIGHT)

	card.art = card:CreateTexture(nil, 'ARTWORK')
	card.art:SetPoint('TOPLEFT', card.band, 'BOTTOMLEFT', 0, 0)
	card.art:SetPoint('TOPRIGHT', card.band, 'BOTTOMRIGHT', 0, 0)
	card.art:SetHeight(math.max(card.artHeight, 1))

	card.check = card:CreateTexture(nil, 'OVERLAY')
	card.check:SetSize(20, 20)
	card.check:SetTexture(130755) -- Interface\\Buttons\\UI-CheckBox-Up
	card.checkMark = card:CreateTexture(nil, 'OVERLAY', nil, 1)
	card.checkMark:SetAllPoints(card.check)
	card.checkMark:SetTexture(130751) -- Interface\\Buttons\\UI-CheckBox-Check

	card.title = card:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	card.title:SetJustifyH('LEFT')
	card.title:SetWordWrap(false)
	card.title:SetTextColor(1, 1, 1)

	card.tag = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	card.tag:SetJustifyH('RIGHT')
	card.tag:SetTextColor(0.8, 0.8, 0.8)

	card.caption = card:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	card.caption:SetJustifyH('LEFT')
	card.caption:SetJustifyV('TOP')
	card.caption:SetWordWrap(true)
	card.caption:SetTextColor(0.78, 0.78, 0.78)
	if card.caption.SetMaxLines then
		card.caption:SetMaxLines(3)
	end

	card.stateBadge = CreateBadge(card)
	card.recBadge = CreateBadge(card)

	card.link = CreateFrame('Button', nil, card)
	card.link:SetHeight(14)
	card.link.text = card.link:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	card.link.text:SetPoint('RIGHT', card.link, 'RIGHT', 0, 0)
	card.link.text:SetTextColor(0.7, 0.7, 0.7)
	card.link:SetScript('OnEnter', function(self)
		self.text:SetTextColor(1, 1, 1)
	end)
	card.link:SetScript('OnLeave', function(self)
		self.text:SetTextColor(0.7, 0.7, 0.7)
	end)
	card.link:SetScript('OnClick', function()
		local data = card.data
		if data and data.link and data.link.onClick then
			data.link.onClick(card)
		end
	end)
	card.link:Hide()

	card.variant = CreateFrame('Button', nil, card)
	card.variant:SetHeight(18)
	card.variant.bg = card.variant:CreateTexture(nil, 'BACKGROUND')
	card.variant.bg:SetAllPoints()
	card.variant.bg:SetColorTexture(0, 0, 0, 0.6)
	card.variant.text = card.variant:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall')
	card.variant.text:SetPoint('CENTER')
	card.variant:SetScript('OnClick', function(self)
		card:OpenVariantMenu(self)
	end)
	card.variant:Hide()

	---The color of this card's band
	---@return number r
	---@return number g
	---@return number b
	function card:GetAccent()
		local accent = self.data and self.data.accent
		if accent and accent[3] then
			return accent[1], accent[2], accent[3]
		end
		return LibAT.UI.GetAccentColor()
	end

	---Repaint the band and selected border after the accent changed
	function card:ApplyAccent()
		local r, g, b = self:GetAccent()
		self.band:SetColorTexture(r, g, b, 1)
		PaintFrame(self)
	end

	---Lay out the text parts for the card's current size
	function card:LayoutParts()
		local data = self.data or {}
		local topY = -(BAND_HEIGHT + 1) - (self.art:IsShown() and self.artHeight or 0)

		self.check:ClearAllPoints()
		self.title:ClearAllPoints()
		if data.checkable then
			self.check:SetPoint('TOPLEFT', self, 'TOPLEFT', PAD - 3, topY - PAD + 3)
			self.title:SetPoint('TOPLEFT', self, 'TOPLEFT', PAD + 20, topY - PAD)
		else
			self.title:SetPoint('TOPLEFT', self, 'TOPLEFT', PAD, topY - PAD)
		end
		self.title:SetPoint('RIGHT', self, 'RIGHT', -PAD, 0)

		self.tag:ClearAllPoints()
		if self.art:IsShown() then
			self.tag:SetPoint('TOPRIGHT', self.art, 'TOPRIGHT', -4, -4)
		else
			self.tag:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -PAD, topY - PAD)
			if data.tag and data.tag ~= '' then
				self.title:SetPoint('RIGHT', self.tag, 'LEFT', -6, 0)
			end
		end

		self.caption:ClearAllPoints()
		self.caption:SetPoint('TOPLEFT', self.title, 'BOTTOMLEFT', 0, -4)
		self.caption:SetPoint('RIGHT', self, 'RIGHT', -PAD, 0)
		self.caption:SetPoint('BOTTOM', self, 'BOTTOM', 0, PAD + 18)

		self.recBadge:ClearAllPoints()
		self.stateBadge:ClearAllPoints()
		self.stateBadge:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', PAD, PAD)
		if self.stateBadge:IsShown() then
			self.recBadge:SetPoint('LEFT', self.stateBadge, 'RIGHT', 4, 0)
		else
			self.recBadge:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', PAD, PAD)
		end

		self.variant:ClearAllPoints()
		self.variant:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -PAD, PAD - 2)
		self.link:ClearAllPoints()
		self.link:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -PAD, PAD)
	end

	---Fill the card
	---@param data LibAT.CardData
	function card:SetData(data)
		self.data = data
		ApplyArt(self, data.art)
		self.title:SetText(data.title or '')
		self.caption:SetText(data.caption or '')
		self.tag:SetText(data.tag or '')

		self.check:SetShown(data.checkable and true or false)
		self.checkMark:SetShown(data.checkable and data.checked and true or false)

		if data.recommended then
			self.recBadge:SetLabel('Recommended', 0.55, 0.42, 0.05)
		else
			self.recBadge:Hide()
		end

		if data.link and data.link.text then
			self.link.text:SetText(data.link.text)
			self.link:SetWidth(LibAT.UI.MeasureText(self.link.text, 5.5) + 4)
			self.link:Show()
		else
			self.link:Hide()
		end

		if data.variants and #data.variants > 1 then
			self.variant.text:SetText('Style: ' .. VariantText(data.variants, data.variant))
			self.variant:SetWidth(LibAT.UI.MeasureText(self.variant.text, 5.5) + 16)
			self.variant:Show()
		else
			self.variant:Hide()
		end

		self:LayoutParts()
		self:ApplyAccent()
	end

	---Show whether this card is picked, whether it can be clicked, and an optional status badge
	---@param selected boolean
	---@param enabled? boolean Defaults to true
	---@param label? string Status badge text such as 'In use'; nil hides it
	function card:SetState(selected, enabled, label)
		self.selected = selected and true or false
		self.enabled = enabled ~= false
		self:SetAlpha(self.enabled and 1 or 0.45)
		self.art:SetDesaturated((not self.enabled) or (self.data and self.data.art and self.data.art.desaturate) and true or false)
		if label and label ~= '' then
			local r, g, b = 0.12, 0.45, 0.16
			if self.selected then
				r, g, b = self:GetAccent()
				r, g, b = r * 0.7, g * 0.7, b * 0.7
			end
			self.stateBadge:SetLabel(label, r, g, b)
		else
			self.stateBadge:Hide()
		end
		self:LayoutParts()
		PaintFrame(self)
	end

	---Set the check box of a checkable card
	---@param checked boolean
	function card:SetChecked(checked)
		if self.data then
			self.data.checked = checked and true or false
		end
		self.checkMark:SetShown(checked and true or false)
	end

	---@return boolean
	function card:GetChecked()
		return self.data and self.data.checked and true or false
	end

	---Pick the next style, or open a menu of styles when the client has one
	---@param owner Frame
	function card:OpenVariantMenu(owner)
		local data = self.data
		if not data or not data.variants or not self.enabled then
			return
		end
		local function Pick(value)
			data.variant = value
			self.variant.text:SetText('Style: ' .. VariantText(data.variants, value))
			if self.onVariant then
				self.onVariant(self, data.value, value)
			end
		end
		if MenuUtil and MenuUtil.CreateContextMenu then
			MenuUtil.CreateContextMenu(owner, function(_, root)
				for _, v in ipairs(data.variants) do
					root:CreateRadio(v.text, function()
						return data.variant == v.value
					end, function()
						Pick(v.value)
					end)
				end
			end)
			return
		end
		local index = 1
		for i, v in ipairs(data.variants) do
			if v.value == data.variant then
				index = i
			end
		end
		local nextVariant = data.variants[(index % #data.variants) + 1]
		Pick(nextVariant.value)
	end

	card:SetScript('OnEnter', function(self)
		self.hovered = true
		PaintFrame(self)
		local data = self.data
		if data and GameTooltip and (data.tooltip or (data.caption and data.caption ~= '')) then
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetText(data.title or '', 1, 1, 1)
			GameTooltip:AddLine(data.tooltip or data.caption, nil, nil, nil, true)
			GameTooltip:Show()
		end
	end)
	card:SetScript('OnLeave', function(self)
		self.hovered = false
		PaintFrame(self)
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	card:SetScript('OnClick', function(self, button)
		if not self.enabled or not self.data then
			return
		end
		PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
		if self.data.checkable then
			self:SetChecked(not self:GetChecked())
			if self.onCheck then
				self.onCheck(self, self.data.value, self:GetChecked())
			end
			return
		end
		if self.onClick then
			self.onClick(self, self.data.value, button)
		end
	end)

	---Clear the card so it can be reused
	function card:Reset()
		self:Hide()
		self:ClearAllPoints()
		self.data = nil
		self.onClick = nil
		self.onVariant = nil
		self.onCheck = nil
		self.selected = false
		self.enabled = true
		self.hovered = false
		self:SetAlpha(1)
		self.stateBadge:Hide()
		self.recBadge:Hide()
	end

	card:ApplyAccent()
	return card
end

----------------------------------------------------------------------------------------------------
-- Card grid - lays cards out in columns and reuses them
----------------------------------------------------------------------------------------------------

---@class LibAT.CardGridOptions
---@field minWidth? number Narrowest a card may get before the grid drops a column (default 170)
---@field maxColumns? number Default 4
---@field cardHeight? number Default: fits the art, title, three caption lines and badges
---@field artHeight? number Picture height on each card (default 0)
---@field spacing? number Gap between cards (default 10)
---@field onClick? fun(card: LibAT.Card, value: any, button: string)
---@field onVariant? fun(card: LibAT.Card, value: any, variant: any)
---@field onCheck? fun(card: LibAT.Card, value: any, checked: boolean)

---@class LibAT.CardGrid : Frame
---@field cards LibAT.Card[] Cards in use, in order
---@field pool LibAT.Card[] Cards waiting to be reused

---Create a grid of cards. Cards are reused between SetCards calls, so a page that shows cards on
---every visit does not create new frames each time.
---@param parent Frame
---@param opts? LibAT.CardGridOptions
---@return LibAT.CardGrid grid
function LibAT.UI.CreateCardGrid(parent, opts)
	opts = opts or {}
	---@type LibAT.CardGrid
	local grid = CreateFrame('Frame', nil, parent)
	grid:SetHeight(1)
	grid.opts = opts
	grid.cards = {}
	grid.pool = {}

	local function DefaultHeight()
		local art = opts.artHeight or 0
		return BAND_HEIGHT + 1 + art + PAD + 16 + 4 + 36 + 18 + PAD
	end

	---Replace the cards shown
	---@param list LibAT.CardData[]
	function grid:SetCards(list)
		for i = #self.cards, 1, -1 do
			local card = self.cards[i]
			card:Reset()
			self.pool[#self.pool + 1] = card
			self.cards[i] = nil
		end
		for i, data in ipairs(list or {}) do
			local card = table.remove(self.pool)
			if not card then
				card = LibAT.UI.CreateCard(self, { artHeight = opts.artHeight or 0 })
			end
			card.artHeight = opts.artHeight or 0
			card.art:SetHeight(math.max(card.artHeight, 1))
			card:SetHeight(opts.cardHeight or DefaultHeight())
			card.onClick = opts.onClick
			card.onVariant = opts.onVariant
			card.onCheck = opts.onCheck
			card:SetData(data)
			card:SetState(false, not data.disabled, nil)
			card:Show()
			self.cards[i] = card
		end
	end

	---Position the cards for a width. Returns the grid's height.
	---@param width number
	---@return number height
	function grid:Layout(width)
		width = math.max(width or self:GetWidth() or 0, 1)
		local spacing = opts.spacing or 10
		local minWidth = opts.minWidth or 170
		local columns = math.floor((width + spacing) / (minWidth + spacing))
		columns = math.max(1, math.min(columns, opts.maxColumns or 4, math.max(#self.cards, 1)))
		local cardWidth = math.floor((width - spacing * (columns - 1)) / columns)
		local cardHeight = opts.cardHeight or DefaultHeight()
		for i, card in ipairs(self.cards) do
			local col = (i - 1) % columns
			local row = math.floor((i - 1) / columns)
			card:ClearAllPoints()
			card:SetWidth(cardWidth)
			card:SetPoint('TOPLEFT', self, 'TOPLEFT', col * (cardWidth + spacing), -row * (cardHeight + spacing))
			card:LayoutParts()
		end
		local rows = math.ceil(#self.cards / columns)
		local height = math.max(rows * cardHeight + math.max(rows - 1, 0) * spacing, 1)
		self:SetWidth(width)
		self:SetHeight(height)
		return height
	end

	---Find the card showing a value
	---@param value any
	---@return LibAT.Card|nil
	function grid:GetCard(value)
		for _, card in ipairs(self.cards) do
			if card.data and card.data.value == value then
				return card
			end
		end
		return nil
	end

	---Repaint every card after the accent changed
	function grid:ApplyAccent()
		for _, card in ipairs(self.cards) do
			card:ApplyAccent()
		end
	end

	---Hide every card and keep them for later
	function grid:Release()
		self:SetCards({})
	end

	return grid
end

return LibAT.UI
