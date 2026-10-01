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
	card.recBadge = self:CreateBadge(card)
	card.stateBadge = self:CreateBadge(card)
	card.link = self:CreateTextButton(card)
	card.variant = self:CreateTextButton(card)

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
		local top = self.art:IsShown() and ((options.artHeight or 0) + 11) or 8
		self.title:ClearAllPoints()
		self.title:SetPoint('TOPLEFT', self, 'TOPLEFT', data.checkable and 36 or 11, -top)
		self.title:SetPoint('RIGHT', self, 'RIGHT', -11, 0)
		self.caption:ClearAllPoints()
		self.caption:SetPoint('TOPLEFT', self.title, 'BOTTOMLEFT', 0, -2)
		self.caption:SetPoint('RIGHT', self, 'RIGHT', -11, 0)
		if data.checkable then
			self.caption:SetWordWrap(false)
		else
			self.caption:SetWordWrap(true)
			self.caption:SetPoint('BOTTOM', self, 'BOTTOM', 0, 8)
		end
		self.tag:ClearAllPoints()
		self.tag:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -10, -top)
		if data.tag and data.tag ~= '' then
			self.title:SetPoint('RIGHT', self.tag, 'LEFT', -8, 0)
		end
		self.recBadge:ClearAllPoints()
		self.recBadge:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -9, -9)
		self.stateBadge:ClearAllPoints()
		self.link:ClearAllPoints()
		if data.checkable then
			self.stateBadge:SetPoint('BOTTOMRIGHT', self, 'BOTTOMRIGHT', -10, 8)
			self.link:SetPoint('RIGHT', self.stateBadge, 'LEFT', -10, 0)
		else
			self.stateBadge:SetPoint('BOTTOMLEFT', self, 'BOTTOMLEFT', 9, 8)
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
