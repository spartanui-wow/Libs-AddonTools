---@class LibAT
local LibAT = LibAT

local Kit = LibAT.UI.Kit
local WHITE = 'Interface\\Buttons\\WHITE8X8'

local function Measure(fontString, fallback)
	return LibAT.UI.MeasureText(fontString, fallback or 6)
end

local function ColorEdges(edges, color, alpha)
	for _, edge in ipairs(edges or {}) do
		edge:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
	end
end

local function AddEdges(frame, layer)
	local edges = {}
	local anchors = {
		{ 'TOPLEFT', 'TOPRIGHT', nil, 1 },
		{ 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, 1 },
		{ 'TOPLEFT', 'BOTTOMLEFT', 1, nil },
		{ 'TOPRIGHT', 'BOTTOMRIGHT', 1, nil },
	}
	for i, anchor in ipairs(anchors) do
		local edge = frame:CreateTexture(nil, layer or 'BORDER')
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

local function Luminance(r, g, b)
	local function Linear(channel)
		if channel <= 0.04045 then
			return channel / 12.92
		end
		return ((channel + 0.055) / 1.055) ^ 2.4
	end
	return 0.2126 * Linear(r) + 0.7152 * Linear(g) + 0.0722 * Linear(b)
end

local function Contrast(a, b)
	return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05)
end

function Kit:CreateBadge(parent)
	local badge = CreateFrame('Frame', nil, parent)
	badge:SetHeight(18)
	badge.edges = AddEdges(badge, 'BORDER')
	badge.bg = badge:CreateTexture(nil, 'BACKGROUND')
	badge.bg:SetTexture(WHITE)
	badge.bg:SetAllPoints()
	badge.text = badge:CreateFontString(nil, 'OVERLAY')
	self:SetFont(badge.text, 11, true)
	badge.text:SetPoint('CENTER')
	function badge:SetLabel(value, style)
		self.value = value or ''
		self.style = style
		self.text:SetText(self.value)
		self:SetWidth(Measure(self.text, 5.7) + 14)
		self:ApplyKit()
		self:Show()
	end
	badge:Hide()
	return self:Track(badge, function(owner, config)
		local color = config.colors.trim
		local alpha = 0.12
		if owner.style == 'accent' or owner.style == 'selected' then
			local r, g, b = LibAT.UI.GetAccentColor()
			color = { r, g, b }
			alpha = 0.28
		elseif owner.style == 'done' then
			color = config.colors.done
			alpha = 0.25
		elseif owner.style == 'warning' then
			color = config.colors.warning
			alpha = 0.25
		elseif owner.style == 'skipped' then
			color = config.colors.skipped
			alpha = 0.18
		elseif owner.style == 'new' then
			-- Text and border only
			color = { 1, 0.82, 0 }
			alpha = 0
		elseif owner.style == 'popular' then
			color = config.colors.secondary
			alpha = 0
		end
		owner.bg:SetVertexColor(color[1], color[2], color[3], alpha)
		ColorEdges(owner.edges, color, owner.style == 'recommended' and 0.65 or 0.85)
		local text = (owner.style == 'recommended' or owner.style == 'popular') and config.colors.secondary or (owner.style == 'new' and color) or config.colors.text
		owner.text:SetTextColor(text[1], text[2], text[3])
	end)
end

local function AtlasSlices(family, state)
	local suffix = state == 'DISABLED' and '-Disabled' or (state == 'PUSHED' and '-Pressed' or '')
	local center = Kit:FirstAtlas('_' .. family .. '-Center' .. suffix, family .. '-Center' .. suffix, '_' .. family .. '-Center', family .. '-Center')
	local left = Kit:FirstAtlas(family .. '-Left' .. suffix, family .. '-Left')
	local right = Kit:FirstAtlas(family .. '-Right' .. suffix, family .. '-Right')
	return left, center, right
end

---@param parent Frame
---@param text? string
---@param style? 'primary'|'secondary'|'ghost'
---@param width? number Fixed width; sized to the text when omitted
---@return Button
function Kit:CreateButton(parent, text, style, width)
	style = style or 'secondary'
	local button = CreateFrame('Button', nil, parent)
	local NativeSetEnabled = button.SetEnabled
	button:SetHeight(24)
	button.style = style
	button.enabled = true
	button.state = 'NORMAL'
	button.left = button:CreateTexture(nil, 'BACKGROUND')
	button.left:SetPoint('TOPLEFT')
	button.left:SetPoint('BOTTOMLEFT')
	button.right = button:CreateTexture(nil, 'BACKGROUND')
	button.right:SetPoint('TOPRIGHT')
	button.right:SetPoint('BOTTOMRIGHT')
	button.center = button:CreateTexture(nil, 'BACKGROUND')
	button.center:SetPoint('TOPLEFT', button.left, 'TOPRIGHT')
	button.center:SetPoint('BOTTOMRIGHT', button.right, 'BOTTOMLEFT')
	button.edges = AddEdges(button, 'BORDER')
	button.label = button:CreateFontString(nil, 'OVERLAY')
	self:SetFont(button.label, 13, true)
	button.label:SetPoint('CENTER', button, 'CENTER', 0, 1)
	-- Callers written for Blizzard's button templates reach the text through these
	button.Text = button.label
	button.fixedWidth = width

	function button:SetText(value)
		self.label:SetText(value or '')
		self:SetWidth(self.fixedWidth or math.max(60, Measure(self.label, 6.5) + 30))
	end

	function button:GetText()
		return self.label:GetText()
	end

	function button:GetFontString()
		return self.label
	end

	function button:SetEnabled(enabled)
		self.enabled = enabled and true or false
		NativeSetEnabled(self, self.enabled)
		self.state = self.enabled and 'NORMAL' or 'DISABLED'
		self:ApplyKit()
	end

	function button:ApplyAccent()
		self:ApplyKit()
	end

	-- Native Enable/Disable (used by template-era callers) repaint too
	button:HookScript('OnEnable', function(owner)
		owner.enabled = true
		owner.state = 'NORMAL'
		owner:ApplyKit()
	end)
	button:HookScript('OnDisable', function(owner)
		owner.enabled = false
		owner.state = 'DISABLED'
		owner:ApplyKit()
	end)
	button:SetScript('OnMouseDown', function(owner)
		if owner.enabled then
			owner.state = 'PUSHED'
			owner:ApplyKit()
		end
	end)
	button:SetScript('OnMouseUp', function(owner)
		owner.state = owner.enabled and 'NORMAL' or 'DISABLED'
		owner:ApplyKit()
	end)
	button:SetScript('OnEnter', function(owner)
		if owner.enabled then
			owner.state = 'HOVER'
			owner:ApplyKit()
		end
	end)
	button:SetScript('OnLeave', function(owner)
		owner.state = owner.enabled and 'NORMAL' or 'DISABLED'
		owner:ApplyKit()
	end)
	button:SetText(text or '')
	return self:Track(button, function(owner, config)
		local primary = owner.style == 'primary'
		local ghost = owner.style == 'ghost'
		local family = primary and '128-GoldRedButton' or '128-RedButton'
		local normalLeft, normalCenter, normalRight = AtlasSlices(family, 'NORMAL')
		local atlasReady = config.blizzardButtons and normalLeft and normalCenter and normalRight
		owner.family = atlasReady and family or nil
		local state = owner.state == 'HOVER' and 'NORMAL' or owner.state
		if atlasReady then
			local left, center, right = AtlasSlices(family, state)
			left, center, right = left or normalLeft, center or normalCenter, right or normalRight
			owner.left:SetAtlas(left)
			owner.center:SetAtlas(center)
			owner.right:SetAtlas(right)
			local leftInfo = C_Texture.GetAtlasInfo(left)
			local rightInfo = C_Texture.GetAtlasInfo(right)
			owner.left:SetWidth(leftInfo.width * owner:GetHeight() / leftInfo.height)
			owner.right:SetWidth(rightInfo.width * owner:GetHeight() / rightInfo.height)
			for _, slice in ipairs({ owner.left, owner.center, owner.right }) do
				slice:SetDesaturated(not primary)
				slice:SetVertexColor(not primary and 0.5 or 1, not primary and 0.47 or 1, not primary and 0.42 or 1, owner.state == 'HOVER' and 0.85 or 1)
				slice:Show()
			end
			ColorEdges(owner.edges, config.colors.trim, 0)
			owner.label:SetTextColor(owner.enabled and 1 or 0.6, owner.enabled and 0.94 or 0.58, owner.enabled and 0.82 or 0.55)
		else
			local spec = config.assets[primary and 'buttonPrimary' or (ghost and 'buttonGhost' or 'buttonSecondary')]
			local r, g, b = LibAT.UI.GetAccentColor()
			local alpha = ghost and 0 or (owner.state == 'HOVER' and 0.85 or 1)
			local label
			if type(spec) == 'table' then
				owner.left:SetTexture(spec.left or WHITE)
				owner.center:SetTexture(spec.center or WHITE, 'REPEAT', 'CLAMP')
				owner.right:SetTexture(spec.right or WHITE)
				owner.left:SetWidth(spec.capWidth or 16)
				owner.right:SetWidth(spec.capWidth or 16)
				local color = primary and { r, g, b } or config.colors.surface[3]
				for _, slice in ipairs({ owner.left, owner.center, owner.right }) do
					slice:SetDesaturated(false)
					slice:SetVertexColor(color[1], color[2], color[3], alpha)
					slice:Show()
				end
				ColorEdges(owner.edges, primary and { r, g, b } or config.colors.trim, ghost and 0.4 or 0.72)
			else
				-- No art: a gradient fill with the kit's edge, like the window kit mockups
				owner.left:Hide()
				owner.right:Hide()
				owner.left:SetWidth(0.01)
				owner.right:SetWidth(0.01)
				local colors = primary and config.button.primary or config.button.secondary
				local top = colors.top or { r, g, b }
				local bottom = colors.bottom or { r * 0.5, g * 0.5, b * 0.5 }
				Kit:SetGradient(owner.center, top, bottom, alpha)
				owner.center:Show()
				ColorEdges(owner.edges, colors.edge or { r, g, b }, ghost and 0 or (owner.state == 'HOVER' and 1 or 0.85))
				label = colors.text
			end
			if not label then
				label = config.colors.text
				if primary then
					local white = Contrast(Luminance(r, g, b), Luminance(1, 1, 1))
					label = white >= 4.5 and { 1, 1, 1 } or { 0.04, 0.04, 0.05 }
				end
			end
			if ghost then
				label = owner.state == 'HOVER' and config.colors.text or config.colors.secondary
			end
			owner.label:SetTextColor(label[1], label[2], label[3])
		end
		owner.label:ClearAllPoints()
		owner.label:SetPoint('CENTER', owner, 'CENTER', 0, owner.state == 'PUSHED' and -1 or 1)
		owner:SetAlpha(owner.enabled and 1 or 0.62)
	end)
end

function Kit:CreateTextButton(parent)
	local button = CreateFrame('Button', nil, parent)
	button:SetHeight(18)
	button.text = button:CreateFontString(nil, 'OVERLAY')
	self:SetFont(button.text, 11)
	button.text:SetPoint('LEFT')
	button.text:SetJustifyH('LEFT')
	button.hovered = false
	function button:SetLabel(value)
		self.text:SetText(value or '')
		self:SetWidth(Measure(self.text, 6) + 6)
	end
	function button:ApplyColor()
		self:ApplyKit()
	end
	button:SetScript('OnEnter', function(owner)
		owner.hovered = true
		owner:ApplyKit()
	end)
	button:SetScript('OnLeave', function(owner)
		owner.hovered = false
		owner:ApplyKit()
	end)
	return self:Track(button, function(owner, config)
		local color = owner.hovered and config.colors.text or config.colors.secondary
		owner.text:SetTextColor(color[1], color[2], color[3])
	end)
end

function Kit:CreateSwitchRow(parent, title, description)
	local row = CreateFrame('Button', nil, parent)
	local NativeSetEnabled = row.SetEnabled
	row:SetHeight(description and description ~= '' and 38 or 28)
	row.enabled = true
	row.checked = false
	row.hovered = false
	row.bg = row:CreateTexture(nil, 'BACKGROUND')
	row.bg:SetTexture(WHITE)
	row.bg:SetAllPoints()
	row.bottom = row:CreateTexture(nil, 'BORDER')
	row.bottom:SetTexture(WHITE)
	row.bottom:SetPoint('BOTTOMLEFT')
	row.bottom:SetPoint('BOTTOMRIGHT')
	row.bottom:SetHeight(1)
	row.track = row:CreateTexture(nil, 'ARTWORK')
	row.track:SetSize(36, 18)
	row.track:SetPoint('LEFT', row, 'LEFT', 4, 0)
	row.knob = row:CreateTexture(nil, 'OVERLAY')
	row.knob:SetSize(16, 16)
	row.label = row:CreateFontString(nil, 'OVERLAY')
	self:SetFont(row.label, 12)
	row.label:SetPoint('TOPLEFT', row, 'TOPLEFT', 50, description and description ~= '' and -4 or -7)
	row.label:SetPoint('RIGHT', row, 'RIGHT', -8, 0)
	row.label:SetJustifyH('LEFT')
	row.label:SetText(title or '')
	row.description = row:CreateFontString(nil, 'OVERLAY')
	self:SetFont(row.description, 11)
	row.description:SetPoint('TOPLEFT', row.label, 'BOTTOMLEFT', 0, -1)
	row.description:SetPoint('RIGHT', row, 'RIGHT', -8, 0)
	row.description:SetJustifyH('LEFT')
	row.description:SetText(description or '')
	row.badge = self:CreateBadge(row)
	row.badge:SetPoint('RIGHT', row, 'RIGHT', -6, 0)
	function row:SetText(value)
		self.label:SetText(value or '')
	end
	function row:SetDescription(value)
		self.description:SetText(value or '')
		self:Fit()
	end

	---Grow to fit a wrapped description. Text can measure 0 before it is drawn, so estimate too.
	function row:Fit()
		local labelHeight = math.max(self.label:GetStringHeight() or 0, 14)
		local text = self.description:GetText() or ''
		local height = 8 + labelHeight + 6
		if text ~= '' then
			local width = math.max((self:GetWidth() or 0) - 58 - (self.badge:IsShown() and (self.badge:GetWidth() + 8) or 0), 40)
			local lines = math.max(1, math.ceil(Measure(self.description, 5.6) / width))
			height = height + math.max(self.description:GetStringHeight() or 0, lines * 13) + 1
		end
		self:SetHeight(math.max(28, math.ceil(height)))
		return self:GetHeight()
	end
	function row:SetChecked(checked)
		self.checked = checked and true or false
		self.knob:ClearAllPoints()
		self.knob:SetPoint(self.checked and 'RIGHT' or 'LEFT', self.track, self.checked and 'RIGHT' or 'LEFT', self.checked and -1 or 1, 0)
		self:ApplyKit()
	end
	function row:GetChecked()
		return self.checked
	end
	function row:SetEnabled(enabled)
		self.enabled = enabled and true or false
		NativeSetEnabled(self, self.enabled)
		self:ApplyKit()
	end
	function row:SetBadge(value, badgeStyle)
		if value and value ~= '' then
			self.badge:SetLabel(value, badgeStyle)
			self.label:SetPoint('RIGHT', self.badge, 'LEFT', -8, 0)
			self.description:SetPoint('RIGHT', self.badge, 'LEFT', -8, 0)
		else
			self.badge:Hide()
			self.label:SetPoint('RIGHT', self, 'RIGHT', -8, 0)
			self.description:SetPoint('RIGHT', self, 'RIGHT', -8, 0)
		end
		self:Fit()
	end
	function row:ApplyAccent()
		self:ApplyKit()
	end
	row:SetScript('OnEnter', function(owner)
		owner.hovered = true
		owner:ApplyKit()
	end)
	row:SetScript('OnLeave', function(owner)
		owner.hovered = false
		owner:ApplyKit()
	end)
	row:SetScript('OnClick', function(owner)
		if not owner.enabled then
			return
		end
		owner:SetChecked(not owner:GetChecked())
		if owner.onToggle then
			owner.onToggle(owner:GetChecked())
		end
	end)
	return self:Track(row, function(owner, config)
		local r, g, b = LibAT.UI.GetAccentColor()
		owner.bg:SetVertexColor(1, 1, 1, owner.hovered and 0.055 or 0.025)
		owner.bottom:SetVertexColor(config.colors.trim[1], config.colors.trim[2], config.colors.trim[3], 0.2)
		owner.track:SetTexture(Kit:Texture(config, 'switchTrack') or WHITE)
		owner.knob:SetTexture(Kit:Texture(config, 'switchKnob') or WHITE)
		-- The track is drawn light: the accent when on, a muted warm grey when off
		if owner.checked then
			owner.track:SetVertexColor(r, g, b, 1)
		else
			owner.track:SetVertexColor(0.3, 0.28, 0.26, 1)
		end
		owner.label:SetTextColor(config.colors.text[1], config.colors.text[2], config.colors.text[3])
		owner.description:SetTextColor(config.colors.secondary[1], config.colors.secondary[2], config.colors.secondary[3])
		owner:SetAlpha(owner.enabled and 1 or 0.6)
	end)
end

function Kit:CreateProgress(parent)
	local progress = CreateFrame('Frame', nil, parent)
	progress:SetHeight(22)
	progress.minValue, progress.maxValue, progress.value = 0, 1, 0
	progress.track = progress:CreateTexture(nil, 'BACKGROUND')
	progress.track:SetTexture(WHITE)
	progress.track:SetPoint('BOTTOMLEFT', progress, 'BOTTOMLEFT', 0, 2)
	progress.track:SetPoint('BOTTOMRIGHT', progress, 'BOTTOMRIGHT', 0, 2)
	progress.track:SetHeight(2)
	progress.fill = progress:CreateTexture(nil, 'ARTWORK')
	progress.fill:SetTexture(WHITE)
	progress.fill:SetPoint('LEFT', progress.track, 'LEFT', 0, 0)
	progress.fill:SetHeight(2)
	progress.text = progress:CreateFontString(nil, 'OVERLAY')
	self:SetFont(progress.text, 11)
	progress.text:SetPoint('TOP')
	function progress:SetMinMaxValues(minimum, maximum)
		self.minValue, self.maxValue = minimum, maximum
	end
	function progress:SetValue(value)
		self.value = value
		local span = math.max(self.maxValue - self.minValue, 1)
		self.fill:SetWidth(math.max((self:GetWidth() or 200) * math.min(math.max((value - self.minValue) / span, 0), 1), 1))
	end
	function progress:SetText(value)
		self.text:SetText(value or '')
	end
	function progress:SetStatusBarColor(r, g, b)
		self.fill:SetVertexColor(r, g, b, 1)
	end
	progress:HookScript('OnSizeChanged', function(owner)
		owner:SetValue(owner.value)
	end)
	return self:Track(progress, function(owner, config)
		local r, g, b = LibAT.UI.GetAccentColor()
		owner.track:SetVertexColor(config.colors.trim[1], config.colors.trim[2], config.colors.trim[3], 0.28)
		owner.fill:SetVertexColor(r, g, b, 1)
		owner.text:SetTextColor(config.colors.secondary[1], config.colors.secondary[2], config.colors.secondary[3])
	end)
end

function Kit:CreateScrollArea(parent)
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
	bar.thumb = bar:CreateTexture(nil, 'ARTWORK')
	bar.thumb:SetTexture(WHITE)
	bar.thumb:SetPoint('TOPLEFT')
	bar.thumb:SetPoint('TOPRIGHT')
	bar.thumb:SetHeight(28)
	scroll.ScrollBar = bar
	local function UpdateThumb()
		local view = scroll:GetHeight() or 1
		local content = child:GetHeight() or 1
		local range = math.max(content - view, 0)
		local barHeight = bar:GetHeight() or view
		local thumbHeight = math.max(math.min(barHeight, barHeight * view / math.max(content, 1)), 24)
		local offset = range > 0 and (barHeight - thumbHeight) * scroll:GetVerticalScroll() / range or 0
		bar.offset, bar.thumbHeight, bar.range = offset, thumbHeight, range
		bar.thumb:ClearAllPoints()
		bar.thumb:SetPoint('TOPLEFT', bar, 'TOPLEFT', 0, -offset)
		bar.thumb:SetPoint('TOPRIGHT', bar, 'TOPRIGHT', 0, -offset)
		bar.thumb:SetHeight(thumbHeight)
		bar:SetShown(range > 0)
	end
	-- Grab the thumb and drag it, or click the track to jump there. The hit area is wider than the
	-- thin bar so it is easy to catch.
	local grip = CreateFrame('Button', nil, bar)
	grip:SetPoint('TOPLEFT', bar, 'TOPLEFT', -5, 0)
	grip:SetPoint('BOTTOMRIGHT', bar, 'BOTTOMRIGHT', 5, 0)
	grip:RegisterForClicks('LeftButtonUp')
	local function CursorFromTop()
		local _, y = GetCursorPosition()
		return (bar:GetTop() or 0) - y / bar:GetEffectiveScale()
	end
	local function DragTo(position)
		local barHeight = bar:GetHeight() or 1
		local travel = math.max(barHeight - (bar.thumbHeight or 24), 1)
		local offset = math.min(math.max(position - (grip.grab or 0), 0), travel)
		scroll:SetVerticalScroll((bar.range or 0) * offset / travel)
		UpdateThumb()
	end
	grip:SetScript('OnMouseDown', function(owner, button)
		if button ~= 'LeftButton' then
			return
		end
		local position = CursorFromTop()
		local top = bar.offset or 0
		local height = bar.thumbHeight or 24
		-- On the thumb: keep the point that was grabbed under the cursor; on the track: centre it there
		owner.grab = (position >= top and position <= top + height) and (position - top) or height / 2
		owner.dragging = true
		DragTo(position)
	end)
	grip:SetScript('OnMouseUp', function(owner)
		owner.dragging = false
	end)
	grip:SetScript('OnHide', function(owner)
		owner.dragging = false
	end)
	grip:SetScript('OnUpdate', function(owner)
		if owner.dragging then
			if not IsMouseButtonDown('LeftButton') then
				owner.dragging = false
				return
			end
			DragTo(CursorFromTop())
		end
	end)
	scroll:SetScript('OnMouseWheel', function(owner, delta)
		local range = math.max((child:GetHeight() or 0) - (owner:GetHeight() or 0), 0)
		owner:SetVerticalScroll(math.min(math.max(owner:GetVerticalScroll() - delta * 42, 0), range))
		UpdateThumb()
	end)
	scroll:HookScript('OnVerticalScroll', UpdateThumb)
	scroll:HookScript('OnSizeChanged', UpdateThumb)
	child:HookScript('OnSizeChanged', UpdateThumb)
	scroll.UpdateOwnedScrollBar = UpdateThumb
	self:Track(scroll, function(_, config)
		bar.track:SetVertexColor(config.colors.trim[1], config.colors.trim[2], config.colors.trim[3], 0.18)
		bar.thumb:SetVertexColor(config.colors.trim[1], config.colors.trim[2], config.colors.trim[3], 0.72)
	end)
	return scroll, child
end

Kit.CreateScroll = Kit.CreateScrollArea

function Kit:CreatePopover(parent, width, height)
	local popup = self:CreatePanel(parent, { elevation = 3, materialAlpha = 0.04, shadow = true })
	popup:SetSize(width or 280, height or 80)
	popup:SetFrameLevel((parent:GetFrameLevel() or 0) + 50)
	return popup
end

Kit.CreateMenu = Kit.CreatePopover

function Kit:CreateTabs(parent, labels)
	local tabs = self:CreateRow(parent, 4)
	tabs.buttons = {}
	function tabs:SetSelected(index)
		self.selected = index
		for i, button in ipairs(self.buttons) do
			button.style = i == index and 'primary' or (self.idleStyle or 'ghost')
			button:ApplyKit()
		end
	end
	for i, label in ipairs(labels or {}) do
		local button = self:CreateButton(tabs, label, 'ghost')
		button:SetScript('OnClick', function()
			tabs:SetSelected(i)
			if tabs.onSelect then
				tabs.onSelect(i)
			end
		end)
		tabs.buttons[i] = button
		tabs:Add(button)
	end
	tabs:SetSelected(1)
	return tabs
end

function Kit:CreateNavRail(parent, options)
	options = options or { elevation = 1, materialAlpha = 0.05, shadow = false }
	local rail = self:CreatePanel(parent, options)
	rail.component = 'NavRail'
	return rail
end

return Kit
