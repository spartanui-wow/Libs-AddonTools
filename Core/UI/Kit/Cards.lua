---@class LibAT
local LibAT = LibAT

local Kit = LibAT.UI.Kit
local WHITE = 'Interface\\Buttons\\WHITE8X8'

local function Measure(fontString, fallback)
	return LibAT.UI.MeasureText(fontString, fallback or 6)
end

local function AddEdges(frame)
	local edges = {}
	local anchors = {
		{ 'TOPLEFT', 'TOPRIGHT', nil, 1 },
		{ 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, 1 },
		{ 'TOPLEFT', 'BOTTOMLEFT', 1, nil },
		{ 'TOPRIGHT', 'BOTTOMRIGHT', 1, nil },
	}
	for i, anchor in ipairs(anchors) do
		local edge = frame:CreateTexture(nil, 'BORDER')
		edge:SetTexture(WHITE)
		edge:SetPoint(anchor[1])
		edge:SetPoint(anchor[2])
		if anchor[3] then
			edge:SetWidth(anchor[3])
		else
			edge:SetHeight(anchor[4])
		end
		edges[i] = edge
	end
	return edges
end

local function ColorEdges(edges, color, alpha)
	for _, edge in ipairs(edges) do
		edge:SetVertexColor(color[1], color[2], color[3], alpha or 1)
	end
end

local variantMenu

---The list of a card's variants, opened by hovering its variant chip
---@return Frame
local function VariantMenu()
	if variantMenu then
		return variantMenu
	end
	local menu = Kit:CreatePopover(UIParent, 200, 40)
	-- Above every window, including ones on the top dialog layer
	menu:SetFrameStrata('TOOLTIP')
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu.rows = {}
	menu:Hide()
	-- Close once the mouse has left both the chip and the list for a moment
	menu:SetScript('OnUpdate', function(self, elapsed)
		if self:IsMouseOver() or (self.owner and self.owner:IsMouseOver()) then
			self.away = 0
			return
		end
		self.away = (self.away or 0) + elapsed
		if self.away > 0.25 then
			self:Hide()
		end
	end)
	variantMenu = menu
	return menu
end

---@param chip Button the card's variant chip
local function OpenVariantMenu(chip)
	local card = chip.card
	local data = card and card.data
	if not data or not data.variants or #data.variants < 2 then
		return
	end
	local menu = VariantMenu()
	menu.owner = chip
	menu.away = 0
	local width = 160
	for i, variant in ipairs(data.variants) do
		local row = menu.rows[i]
		if not row then
			row = Kit:CreateButton(menu, '', 'secondary')
			row:SetHeight(22)
			menu.rows[i] = row
		end
		row.fixedWidth = nil
		row:SetText(variant.text)
		width = math.max(width, row:GetWidth())
		row.style = variant.value == data.variant and 'primary' or 'secondary'
		if row.ApplyKit then
			row:ApplyKit()
		end
		row:SetScript('OnClick', function()
			data.variant = variant.value
			chip:SetText(variant.text)
			menu:Hide()
			if card.onVariant then
				card.onVariant(card, data.value, variant.value)
			end
		end)
		row:Show()
	end
	for i = #data.variants + 1, #menu.rows do
		menu.rows[i]:Hide()
	end
	for i, variant in ipairs(data.variants) do
		local row = menu.rows[i]
		row.fixedWidth = width
		row:SetWidth(width)
		row:ClearAllPoints()
		row:SetPoint('TOPLEFT', menu, 'TOPLEFT', 6, -6 - (i - 1) * 25)
	end
	menu:SetSize(width + 12, #data.variants * 25 + 9)
	menu:ClearAllPoints()
	menu:SetPoint('TOPLEFT', chip, 'BOTTOMLEFT', 0, -2)
	menu:Show()
end

function Kit:CreateCard(parent, options)
	options = options or {}
	local card = CreateFrame('Button', nil, parent)
	card:SetSize(180, options.cardHeight or 58)
	card:RegisterForClicks('LeftButtonUp')
	card.enabled = true
	card.selected = false
	card.hovered = false
	card.focused = false
	card.bg = card:CreateTexture(nil, 'BACKGROUND')
	card.bg:SetTexture(WHITE)
	card.bg:SetAllPoints()
	card.material = card:CreateTexture(nil, 'BACKGROUND', nil, 1)
	card.material:SetAllPoints()
	card.edges = AddEdges(card)
	card.glow = CreateFrame('Frame', nil, card)
	card.glow:SetPoint('TOPLEFT', card, 'TOPLEFT', -2, 2)
	card.glow:SetPoint('BOTTOMRIGHT', card, 'BOTTOMRIGHT', 2, -2)
	card.glow.edges = AddEdges(card.glow)
	card.glow:Hide()
	card.art = card:CreateTexture(nil, 'ARTWORK')
	card.art:SetPoint('TOPLEFT', 5, -5)
	card.art:SetPoint('TOPRIGHT', -5, -5)
	card.art:SetHeight(options.artHeight or 0)
	card.art:SetShown((options.artHeight or 0) > 0)
	card.check = card:CreateTexture(nil, 'OVERLAY')
	card.check:SetSize(18, 18)
	card.check:SetPoint('LEFT', 10, 0)
	card.checkMark = card:CreateTexture(nil, 'OVERLAY', nil, 1)
	card.checkMark:SetAllPoints(card.check)
	card.check:Hide()
	card.checkMark:Hide()
	card.title = card:CreateFontString(nil, 'OVERLAY')
	self:SetFont(card.title, 14)
	card.title:SetJustifyH('LEFT')
	card.caption = card:CreateFontString(nil, 'OVERLAY')
	self:SetFont(card.caption, 11)
	card.caption:SetJustifyH('LEFT')
	card.caption:SetJustifyV('TOP')
	card.caption:SetWordWrap(true)
	card.tag = card:CreateFontString(nil, 'OVERLAY')
	self:SetFont(card.tag, 11)
	card.tag:SetJustifyH('RIGHT')
	-- A tag with a style (data.tagStyle, for example 'new') is drawn as a badge instead of plain text
	card.tagBadge = self:CreateBadge(card)
	card.recBadge = self:CreateBadge(card)
	card.stateBadge = self:CreateBadge(card)
	card.link = self:CreateTextButton(card)
	card.variant = self:CreateButton(card, '', 'secondary')
	card.variant:SetHeight(20)
	card.variant.card = card
	card.variant.arrow = card.variant:CreateTexture(nil, 'OVERLAY')
	card.variant.arrow:SetSize(9, 9)
	card.variant.arrow:SetPoint('RIGHT', card.variant, 'RIGHT', -7, 0)
	if Kit.SetAsset then
		Kit:SetAsset(card.variant.arrow, Kit:GetActive(), 'triangle')
	end
	-- The triangle points right; a drop-down points down
	card.variant.arrow:SetRotation(math.rad(-90))
	card.variant:HookScript('OnEnter', OpenVariantMenu)

	local function ApplyArt(owner, art)
		if not art or (options.artHeight or 0) <= 0 then
			owner.art:Hide()
			return
		end
		owner.art:SetTexCoord(0, 1, 0, 1)
		owner.art:SetVertexColor(1, 1, 1, 1)
		if art.texture then
			owner.art:SetTexture(art.texture)
		elseif art.atlas then
			if Kit:HasAtlas(art.atlas) then
				owner.art:SetAtlas(art.atlas)
			else
				owner.art:Hide()
				return
			end
		elseif art.color then
			owner.art:SetColorTexture(art.color[1] or 0, art.color[2] or 0, art.color[3] or 0, art.color[4] or 1)
		else
			owner.art:SetTexture(WHITE)
			owner.art:SetVertexColor(0.12, 0.12, 0.13, 1)
		end
		if art.texCoord and art.texCoord[4] then
			owner.art:SetTexCoord(art.texCoord[1], art.texCoord[2], art.texCoord[3], art.texCoord[4])
		end
		owner.art:SetDesaturated(art.desaturate and true or false)
		owner.art:Show()
	end

	function card:LayoutParts()
		local data = self.data or {}
		local hasArt = self.art:IsShown()
		local top = hasArt and ((options.artHeight or 0) + 11) or 10
		-- Cards without a picture carry their badges in the top right corner, beside the title, so a
		-- badge never lands on the caption. Picture cards put them in the picture's top corners.
		local topBadges = not hasArt and not data.checkable
		local stateShown = self.stateBadge:IsShown()
		self.recBadge:ClearAllPoints()
		self.stateBadge:ClearAllPoints()
		local titleRight = -11
		if topBadges then
			local anchor
			if self.recBadge:IsShown() then
				self.recBadge:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -9, -top + 1)
				anchor = self.recBadge
			end
			if stateShown then
				if anchor then
					self.stateBadge:SetPoint('RIGHT', anchor, 'LEFT', -6, 0)
				else
					self.stateBadge:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -9, -top + 1)
				end
				anchor = self.stateBadge
			end
			if anchor then
				titleRight = nil
				self.titleAnchor = anchor
			end
		else
			self.recBadge:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -9, -9)
			if data.checkable then
				self.stateBadge:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -10, 8)
			else
				self.stateBadge:SetPoint('TOPLEFT', self, 'TOPLEFT', 9, -9)
			end
		end
		self.title:ClearAllPoints()
		self.title:SetPoint('TOPLEFT', self, 'TOPLEFT', data.checkable and 36 or 11, -top)
		if titleRight then
			self.title:SetPoint('RIGHT', self, 'RIGHT', titleRight, 0)
		else
			self.title:SetPoint('RIGHT', self.titleAnchor, 'LEFT', -8, 0)
		end
		self.tag:ClearAllPoints()
		self.tag:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -10, -top)
		self.tagBadge:ClearAllPoints()
		self.tagBadge:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -9, -top + 1)
		if self.tagBadge:IsShown() and titleRight then
			self.title:SetPoint('RIGHT', self.tagBadge, 'LEFT', -8, 0)
		elseif data.tag and data.tag ~= '' and titleRight then
			self.title:SetPoint('RIGHT', self.tag, 'LEFT', -8, 0)
		end
		self.caption:ClearAllPoints()
		self.caption:SetPoint('TOPLEFT', self.title, 'BOTTOMLEFT', 0, -7)
		self.caption:SetPoint('RIGHT', self, 'RIGHT', -11, 0)
		if data.checkable then
			self.caption:SetWordWrap(false)
		else
			self.caption:SetWordWrap(true)
			-- Leave the bottom row free when something sits in it
			local bottomRow = self.link:IsShown() or self.variant:IsShown()
			self.caption:SetPoint('BOTTOM', self, 'BOTTOM', 0, bottomRow and 30 or 8)
		end
		self.link:ClearAllPoints()
		if data.checkable then
			self.link:SetPoint('RIGHT', self.stateBadge, 'LEFT', -10, 0)
		else
			self.link:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -10, 8)
		end
		self.variant:ClearAllPoints()
		self.variant:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -10, 8)
	end

	function card:SetData(data)
		self.data = data
		ApplyArt(self, data.art)
		self.title:SetText(data.title or '')
		self.caption:SetText(data.caption or '')
		if data.tagStyle and data.tag and data.tag ~= '' then
			self.tag:SetText('')
			self.tagBadge:SetLabel(data.tag, data.tagStyle)
		else
			self.tagBadge:Hide()
			self.tag:SetText(data.tag or '')
		end
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
			-- Room on the right for the arrow
			self.variant.fixedWidth = nil
			self.variant:SetText(label)
			self.variant.fixedWidth = self.variant:GetWidth() + 14
			self.variant:SetWidth(self.variant.fixedWidth)
			self.variant:Show()
		else
			self.variant:Hide()
		end
		self:LayoutParts()
		self:ApplyKit()
	end

	function card:SetState(selected, enabled, label)
		self.selected = selected and true or false
		self.enabled = enabled ~= false
		self.stateLabel = label
		if label and label ~= '' then
			local style = label == 'Done' and 'done' or (label == 'Skipped' and 'skipped' or 'accent')
			self.stateBadge:SetLabel(label, style)
		else
			self.stateBadge:Hide()
		end
		self:LayoutParts()
		self:ApplyKit()
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
		self:ApplyKit()
	end

	function card:Reset()
		self:Hide()
		self:ClearAllPoints()
		self.data = nil
		self.onClick, self.onVariant, self.onCheck = nil, nil, nil
		self.stateBadge:Hide()
		self.recBadge:Hide()
		self.tagBadge:Hide()
		self.link:Hide()
		self.variant:Hide()
	end

	-- Clicking the chip opens the list too, for players who click before the hover shows it
	card.variant:SetScript('OnClick', OpenVariantMenu)
	card:SetScript('OnClick', function(owner, button)
		if not owner.enabled or not owner.data then
			return
		end
		if owner.data.checkable then
			owner:SetChecked(not owner:GetChecked())
			if owner.onCheck then
				owner.onCheck(owner, owner.data.value, owner:GetChecked())
			end
		elseif owner.onClick then
			owner.onClick(owner, owner.data.value, button)
		end
	end)
	card:SetScript('OnEnter', function(owner)
		owner.hovered = true
		owner:ApplyKit()
	end)
	card:SetScript('OnLeave', function(owner)
		owner.hovered = false
		owner:ApplyKit()
	end)
	return self:Track(card, function(owner, config)
		local surface = config.colors.surface[2]
		owner.bg:SetVertexColor(surface[1], surface[2], surface[3], surface[4] or 1)
		local material = Kit:Texture(config, 'materialTile')
		owner.material:SetTexture(material or WHITE, 'REPEAT', 'REPEAT')
		owner.material:SetHorizTile(true)
		owner.material:SetVertTile(true)
		owner.material:SetVertexColor(1, 1, 1, material and 0.045 or 0)
		local r, g, b = LibAT.UI.GetAccentColor()
		local edge = config.colors.trim
		local alpha = owner.hovered and 0.9 or 0.48
		if owner.selected or owner.focused then
			edge = { r, g, b }
			alpha = 1
			ColorEdges(owner.glow.edges, edge, owner.selected and 0.58 or 0.35)
			owner.glow:Show()
		else
			owner.glow:Hide()
		end
		ColorEdges(owner.edges, edge, alpha)
		owner.title:SetTextColor(config.colors.text[1], config.colors.text[2], config.colors.text[3])
		owner.caption:SetTextColor(config.colors.secondary[1], config.colors.secondary[2], config.colors.secondary[3])
		owner.tag:SetTextColor(config.colors.muted[1], config.colors.muted[2], config.colors.muted[3])
		owner.check:SetTexture(Kit:Texture(config, 'activeMarker') or WHITE)
		owner.checkMark:SetTexture(Kit:Texture(config, 'check') or WHITE)
		owner:SetAlpha(owner.enabled and 1 or 0.48)
	end)
end

function Kit:CreateCardGrid(parent, options)
	local grid = CreateFrame('Frame', nil, parent)
	grid:SetHeight(1)
	grid.opts = options or {}
	grid.cards = {}
	grid.pool = {}
	function grid:SetCards(list)
		for _, card in ipairs(self.cards) do
			card:Reset()
			self.pool[#self.pool + 1] = card
		end
		self.cards = {}
		for _, data in ipairs(list) do
			local card = table.remove(self.pool) or Kit:CreateCard(self, self.opts)
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
			card:ApplyKit()
		end
	end
	return grid
end

return Kit
