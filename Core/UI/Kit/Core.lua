---@class LibAT
local LibAT = LibAT

local WHITE = 'Interface\\Buttons\\WHITE8X8'
local FONT_PATH = 'Interface\\AddOns\\LibsAddonTools\\Media\\Fonts\\RobotoCondensed-Bold.ttf'

---@class LibAT.UI.Kit
local Kit = {
	registry = {},
	fonts = {},
	plainFonts = {},
	instances = setmetatable({}, { __mode = 'k' }),
}
LibAT.UI.Kit = Kit

Kit.CHANGED = 'LIBAT_UI_KIT_CHANGED'
Kit.SPACING = { 4, 8, 12, 16, 24 }
Kit.TYPE = { 11, 12, 13, 14, 15, 16, 18, 22, 26 }

for _, size in ipairs(Kit.TYPE) do
	local name = 'LibATKitFont' .. size
	local font = _G[name] or CreateFont(name)
	font:SetFont(FONT_PATH, size, 'OUTLINE')
	font:SetShadowColor(0, 0, 0, 0.9)
	font:SetShadowOffset(1, -1)
	Kit.fonts[size] = font

	-- Text on filled shapes (buttons, chips) reads sharper without an outline or shadow
	local plainName = 'LibATKitPlainFont' .. size
	local plain = _G[plainName] or CreateFont(plainName)
	plain:SetFont(FONT_PATH, size, '')
	plain:SetShadowColor(0, 0, 0, 0)
	plain:SetShadowOffset(0, 0)
	Kit.plainFonts[size] = plain
end

local provider
local overrideId

-- Assets every kit can borrow from the neutral kit when it has none of its own
local SHAPE_FALLBACKS = {
	switchTrack = true,
	switchKnob = true,
	radioRing = true,
	check = true,
	triangle = true,
	chevron = true,
	activeMarker = true,
}

local function Log(level, message)
	if LibAT.InternalLog and LibAT.InternalLog[level] then
		LibAT.InternalLog[level](message)
	end
end

local function CopyColor(color, fallback)
	color = type(color) == 'table' and color or fallback
	return { color[1], color[2], color[3], color[4] }
end

local function Normalize(config)
	local fallback = Kit.registry.minimal
	if type(config) == 'string' then
		config = Kit.registry[config]
	end
	if type(config) ~= 'table' then
		return fallback
	end
	if config._normalized then
		return config
	end
	config.id = config.id or 'custom'
	config.name = config.name or config.id
	config.colors = config.colors or {}
	config.colors.surface = config.colors.surface or {}
	config.colors.surface[0] = CopyColor(config.colors.surface[0], { 0.035, 0.04, 0.05, 0.96 })
	config.colors.surface[1] = CopyColor(config.colors.surface[1], { 0.07, 0.08, 0.09, 0.96 })
	config.colors.surface[2] = CopyColor(config.colors.surface[2], { 0.11, 0.12, 0.14, 0.97 })
	config.colors.surface[3] = CopyColor(config.colors.surface[3], { 0.16, 0.17, 0.19, 0.98 })
	config.colors.text = CopyColor(config.colors.text, { 0.93, 0.94, 0.96 })
	config.colors.secondary = CopyColor(config.colors.secondary, { 0.72, 0.74, 0.78 })
	config.colors.muted = CopyColor(config.colors.muted, { 0.56, 0.58, 0.62 })
	config.colors.disabled = CopyColor(config.colors.disabled, { 0.4, 0.42, 0.45 })
	config.colors.trim = CopyColor(config.colors.trim, { 0.58, 0.61, 0.66 })
	config.colors.trimHi = CopyColor(config.colors.trimHi, config.colors.trim)
	config.colors.done = CopyColor(config.colors.done, { 0.32, 0.7, 0.42 })
	config.colors.warning = CopyColor(config.colors.warning, { 0.94, 0.68, 0.22 })
	config.colors.skipped = CopyColor(config.colors.skipped, { 0.56, 0.58, 0.62 })
	config.colors.ground = config.colors.surface[0]
	config.colors.panel = config.colors.surface[1]
	config.colors.card = config.colors.surface[2]
	config.colors.rim = config.colors.trim
	config.colors.dim = config.colors.muted
	config.assets = config.assets or {}
	-- Window proportions; painted kits move the bars inside their frame's beam
	local layout = config.layout or {}
	layout.barInset = layout.barInset or 0
	layout.titleHeight = layout.titleHeight or 28
	layout.footerHeight = layout.footerHeight or 38
	layout.sideInset = layout.sideInset or 12
	layout.barPadding = layout.barPadding or 18
	config.layout = layout
	-- Buttons a kit has no art for are drawn as a gradient with an edge; primary follows the accent unless the kit sets it
	local button = config.button or {}
	button.primary = button.primary or {}
	button.secondary = button.secondary or {}
	local secondary = button.secondary
	secondary.top = secondary.top or config.colors.surface[3]
	secondary.bottom = secondary.bottom or config.colors.surface[2]
	secondary.edge = secondary.edge or config.colors.trimHi
	secondary.text = secondary.text or config.colors.text
	config.button = button
	config.owned = true
	config.CreateWindow = function()
		return Kit:CreateWindow({ name = 'LibAT_SetupHub', title = 'Setup', width = 1024, height = 650 })
	end
	config.CreateScroll = function(_, parent)
		return Kit:CreateScrollArea(parent)
	end
	config.CreateButton = function(_, parent, text, primary)
		return Kit:CreateButton(parent, text, primary and 'primary' or 'secondary')
	end
	config.CreateTextButton = function(_, parent)
		return Kit:CreateTextButton(parent)
	end
	config.CreateProgress = function(_, parent)
		return Kit:CreateProgress(parent)
	end
	config.CreateCardGrid = function(_, parent, options)
		return Kit:CreateCardGrid(parent, options)
	end
	config.CreateBadge = function(_, parent)
		return Kit:CreateBadge(parent)
	end
	config.CreateSwitchRow = function(_, parent, title, description)
		return Kit:CreateSwitchRow(parent, title, description)
	end
	config.SetFont = function(_, fontString, size)
		Kit:SetFont(fontString, size)
	end
	config.Texture = function(owner, name)
		return Kit:Texture(owner, name)
	end
	config.GetBackdrop = function(owner)
		return Kit:Texture(owner, 'backdrop') or LibAT.UI.GetBackdrop()
	end
	config.ApplyAccent = function(_, window)
		if window and window.ApplyKit then
			window:ApplyKit()
		end
	end
	config._normalized = true
	return config
end

function Kit:Register(id, config)
	if type(id) ~= 'string' or id == '' or type(config) ~= 'table' then
		return
	end
	config.id = id
	config._normalized = nil
	self.registry[id] = Normalize(config)
end

function Kit:Get(id)
	return Normalize(self.registry[id] or self.registry.minimal)
end

function Kit:GetActive()
	if overrideId and overrideId ~= 'auto' and self.registry[overrideId] then
		return self:Get(overrideId)
	end
	if provider then
		local ok, value = pcall(provider)
		if ok then
			if type(value) == 'string' and self.registry[value] then
				return self:Get(value)
			elseif type(value) == 'table' then
				return Normalize(value)
			end
		else
			Log('warning', 'Kit provider failed: ' .. tostring(value))
		end
	end
	return self:Get('minimal')
end

function Kit:SetKitProvider(fn)
	if fn ~= nil and type(fn) ~= 'function' then
		Log('warning', 'SetKitProvider expects a function, got ' .. type(fn))
		return
	end
	provider = fn
	self:NotifyKitChanged()
end

function Kit:SetOverride(id)
	if id ~= nil and id ~= 'auto' and not self.registry[id] then
		return false
	end
	overrideId = id == 'auto' and nil or id
	self:NotifyKitChanged()
	return true
end

function Kit:GetOverride()
	return overrideId or 'auto'
end

function Kit:Track(frame, apply)
	if not frame or type(apply) ~= 'function' then
		return frame
	end
	local callbacks = self.instances[frame]
	if not callbacks then
		callbacks = {}
		self.instances[frame] = callbacks
	end
	callbacks[#callbacks + 1] = apply
	frame.ApplyKit = function(owner)
		-- Painting can resize a frame, which repaints it; one pass at a time is enough
		if owner.kitApplying then
			return
		end
		owner.kitApplying = true
		local active = Kit:GetActive()
		for _, callback in ipairs(Kit.instances[owner] or {}) do
			-- A painting bug must never stop a window from being built
			local ok, err = pcall(callback, owner, active)
			if not ok then
				Kit:ReportPaintError(err)
			end
		end
		owner.kitApplying = nil
	end
	frame:ApplyKit()
	return frame
end

local reportedErrors = {}

---Hand a painting error to the error handler once, instead of once per frame painted.
function Kit:ReportPaintError(err)
	local key = tostring(err)
	if reportedErrors[key] then
		return
	end
	reportedErrors[key] = true
	local handler = geterrorhandler and geterrorhandler()
	if handler then
		handler(err)
	end
end

function Kit:RefreshAll()
	for frame in pairs(self.instances) do
		frame:ApplyKit()
	end
end

function Kit:NotifyKitChanged()
	self:RefreshAll()
	if LibAT.SendMessage then
		LibAT:SendMessage(self.CHANGED, self:GetActive().id)
	end
end

LibAT.UI.SetKitProvider = function(fn)
	Kit:SetKitProvider(fn)
end

LibAT.UI.NotifyKitChanged = function()
	Kit:NotifyKitChanged()
end

---@param plain? boolean No outline or shadow, for text drawn on a filled shape
function Kit:SetFont(fontString, size, plain)
	local font = (plain and self.plainFonts or self.fonts)[size]
	if font then
		fontString:SetFontObject(font)
	end
end

---A kit asset's file, plus its texture coordinates when the asset is a region of a larger sheet.
---@return string|nil texture
---@return number[]|nil coords left, right, top, bottom
function Kit:Texture(config, name)
	local asset = config and config.assets and config.assets[name]
	-- Plain shapes a kit has no art for come from the neutral kit, never a bare square
	if asset == nil and SHAPE_FALLBACKS[name] and self.registry.minimal and config ~= self.registry.minimal then
		asset = self.registry.minimal.assets[name]
	end
	if type(asset) == 'table' then
		return asset.texture, asset.coords
	end
	return asset
end

---Points a texture region at a kit asset (or hides it when the kit has none).
---@return boolean found
function Kit:SetAsset(region, config, name, ...)
	local file, coords = self:Texture(config, name)
	if not file then
		region:Hide()
		return false
	end
	region:SetTexture(file, ...)
	if coords then
		region:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
	else
		region:SetTexCoord(0, 1, 0, 1)
	end
	region:Show()
	return true
end

---Fills a texture with a vertical gradient; clients without the color API get the average.
function Kit:SetGradient(region, top, bottom, alpha)
	region:SetTexture(WHITE)
	region:SetVertexColor(1, 1, 1, 1)
	alpha = alpha or 1
	if CreateColor and region.SetGradient then
		local ok = pcall(region.SetGradient, region, 'VERTICAL', CreateColor(bottom[1], bottom[2], bottom[3], alpha), CreateColor(top[1], top[2], top[3], alpha))
		if ok then
			return
		end
	end
	region:SetVertexColor((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2, alpha)
end

function Kit:HasAtlas(name)
	return name and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(name) ~= nil
end

function Kit:FirstAtlas(...)
	for i = 1, select('#', ...) do
		local name = select(i, ...)
		if self:HasAtlas(name) then
			return name
		end
	end
	return nil
end

function Kit:CropToFill(texture, imageAspect, width, height, anchorY)
	if not width or not height or width <= 0 or height <= 0 then
		return
	end
	local regionAspect = width / height
	if regionAspect >= imageAspect then
		local visible = imageAspect / regionAspect
		local top = (1 - visible) * (anchorY or 0.5)
		texture:SetTexCoord(0, 1, top, top + visible)
	else
		local visible = regionAspect / imageAspect
		local left = (1 - visible) * 0.5
		texture:SetTexCoord(left, left + visible, 0, 1)
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

local function ColorEdges(edges, color, alpha)
	for _, edge in ipairs(edges or {}) do
		edge:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
	end
end

local function HideEdges(edges)
	for _, edge in ipairs(edges or {}) do
		edge:Hide()
	end
end

local function ShowEdges(edges)
	for _, edge in ipairs(edges or {}) do
		edge:Show()
	end
end

local function ApplyNineSlice(owner, config, spec)
	owner.kitNineSlice = owner.kitNineSlice or {}
	local art = owner.kitNineSlice
	local pieces = spec and spec.pieces
	if type(pieces) ~= 'table' then
		for _, texture in pairs(art) do
			texture:Hide()
		end
		return false
	end
	local cornerSize = spec.cornerSize or 32
	local edgeSize = spec.edgeSize or 12
	local tileLength = spec.tileLength or 128
	local edgeCrop = spec.edgeCrop or 1
	local definitions = {
		topLeft = { 'TOPLEFT', cornerSize, cornerSize },
		topRight = { 'TOPRIGHT', cornerSize, cornerSize },
		bottomLeft = { 'BOTTOMLEFT', cornerSize, cornerSize },
		bottomRight = { 'BOTTOMRIGHT', cornerSize, cornerSize },
	}
	for key, definition in pairs(definitions) do
		local texture = art[key] or owner:CreateTexture(nil, 'OVERLAY')
		art[key] = texture
		texture:ClearAllPoints()
		texture:SetTexture(pieces[key])
		texture:SetSize(definition[2], definition[3])
		texture:SetPoint(definition[1])
		texture:Show()
	end
	local function Horizontal(key, point)
		local texture = art[key] or owner:CreateTexture(nil, 'OVERLAY')
		art[key] = texture
		texture:ClearAllPoints()
		texture:SetTexture(pieces[key], 'REPEAT', 'CLAMP')
		texture:SetPoint(point .. 'LEFT', owner, point .. 'LEFT', cornerSize - 2, 0)
		texture:SetPoint(point .. 'RIGHT', owner, point .. 'RIGHT', -(cornerSize - 2), 0)
		texture:SetHeight(edgeSize)
		texture:Show()
		return texture
	end
	local function Vertical(key, point)
		local texture = art[key] or owner:CreateTexture(nil, 'OVERLAY')
		art[key] = texture
		texture:ClearAllPoints()
		texture:SetTexture(pieces[key], 'CLAMP', 'REPEAT')
		texture:SetPoint('TOP' .. point, owner, 'TOP' .. point, 0, -(cornerSize - 2))
		texture:SetPoint('BOTTOM' .. point, owner, 'BOTTOM' .. point, 0, cornerSize - 2)
		texture:SetWidth(edgeSize)
		texture:Show()
		return texture
	end
	local top = Horizontal('top', 'TOP')
	local bottom = Horizontal('bottom', 'BOTTOM')
	local left = Vertical('left', 'LEFT')
	local right = Vertical('right', 'RIGHT')
	local across = math.max((owner:GetWidth() or 0) - (cornerSize - 2) * 2, 1) / tileLength
	local down = math.max((owner:GetHeight() or 0) - (cornerSize - 2) * 2, 1) / tileLength
	top:SetTexCoord(0, across, 0, edgeCrop)
	bottom:SetTexCoord(0, across, 0, edgeCrop)
	left:SetTexCoord(0, edgeCrop, 0, down)
	right:SetTexCoord(0, edgeCrop, 0, down)
	return true
end

Kit.ApplyNineSlice = ApplyNineSlice

---Dress an existing frame as a kit panel: surface, material, trim and an optional ornament.
---@param panel Frame
---@param options? {elevation?: number, materialAlpha?: number, trimAlpha?: number, shadow?: boolean, backdrop?: string|fun(config: table): string|nil, ornament?: string}
---@return Frame panel
function Kit:SkinPanel(panel, options)
	options = options or {}
	panel.kitOptions = options
	panel.layers = {}
	panel.layers.shadow = panel:CreateTexture(nil, 'BACKGROUND', nil, -8)
	panel.layers.shadow:SetPoint('TOPLEFT', panel, 'TOPLEFT', 3, -3)
	panel.layers.shadow:SetPoint('BOTTOMRIGHT', panel, 'BOTTOMRIGHT', 7, -7)
	panel.layers.backdrop = panel:CreateTexture(nil, 'BACKGROUND', nil, -7)
	panel.layers.backdrop:SetAllPoints()
	panel.layers.surface = panel:CreateTexture(nil, 'BACKGROUND', nil, -6)
	panel.layers.surface:SetAllPoints()
	panel.layers.material = panel:CreateTexture(nil, 'BACKGROUND', nil, -5)
	panel.layers.material:SetAllPoints()
	panel.layers.trim = AddEdges(panel, 'BORDER')
	panel.layers.ornament = panel:CreateTexture(nil, 'OVERLAY')
	panel.layers.ornament:SetPoint('TOPRIGHT')
	panel.layers.ornament:SetSize(32, 32)
	return self:Track(panel, function(owner, config)
		local level = math.min(math.max(options.elevation or 1, 0), 3)
		local surface = config.colors.surface[level]
		owner.layers.surface:SetTexture(WHITE)
		owner.layers.surface:SetVertexColor(surface[1], surface[2], surface[3], surface[4] or 1)
		local backdrop = options.backdrop
		if type(backdrop) == 'function' then
			backdrop = backdrop(config)
		end
		owner.layers.backdrop:SetTexture(backdrop or WHITE)
		owner.layers.backdrop:SetVertexColor(1, 1, 1, backdrop and 1 or 0)
		local material = Kit:Texture(config, 'materialTile')
		owner.layers.material:SetTexture(material or WHITE, 'REPEAT', 'REPEAT')
		owner.layers.material:SetHorizTile(true)
		owner.layers.material:SetVertTile(true)
		owner.layers.material:SetVertexColor(1, 1, 1, material and (options.materialAlpha or config.materialAlpha or 0.08) or 0)
		ColorEdges(owner.layers.trim, config.colors.trim, options.trimAlpha or 0.62)
		local ornament = options.ornament and Kit:Texture(config, options.ornament)
		owner.layers.ornament:SetTexture(ornament or WHITE)
		owner.layers.ornament:SetVertexColor(1, 1, 1, ornament and 1 or 0)
		local shadow = Kit:Texture(config, 'shadow')
		owner.layers.shadow:SetTexture(shadow or WHITE)
		owner.layers.shadow:SetVertexColor(0, 0, 0, options.shadow and (shadow and 0.75 or 0.32) or 0)
	end)
end

---@param parent Frame
---@param options? table See SkinPanel
---@return Frame panel
function Kit:CreatePanel(parent, options)
	return self:SkinPanel(CreateFrame('Frame', nil, parent), options)
end

function Kit:CreateSection(parent, title)
	local section = self:CreatePanel(parent, { elevation = 0, materialAlpha = 0, shadow = false })
	section.Header = section:CreateFontString(nil, 'OVERLAY')
	self:SetFont(section.Header, 16)
	section.Header:SetPoint('TOPLEFT', 0, 0)
	section.Header:SetText(title or '')
	section.Divider = section:CreateTexture(nil, 'ARTWORK')
	section.Divider:SetTexture(WHITE)
	section.Divider:SetPoint('TOPLEFT', section.Header, 'BOTTOMLEFT', 0, -4)
	section.Divider:SetPoint('TOPRIGHT', section, 'TOPRIGHT', 0, -4)
	section.Divider:SetHeight(1)
	return self:Track(section, function(owner, config)
		owner.Header:SetTextColor(config.colors.text[1], config.colors.text[2], config.colors.text[3])
		local divider = Kit:Texture(config, 'divider')
		owner.Divider:SetTexture(divider or WHITE)
		owner.Divider:SetVertexColor(config.colors.trim[1], config.colors.trim[2], config.colors.trim[3], 0.55)
	end)
end

local function LayoutChildren(container)
	local previous
	local total = 0
	local maxCross = 0
	for _, child in ipairs(container.children) do
		child:ClearAllPoints()
		if container.direction == 'vertical' then
			child:SetPoint('TOPLEFT', previous or container, previous and 'BOTTOMLEFT' or 'TOPLEFT', 0, previous and -container.gap or 0)
			total = total + (child:GetHeight() or 0) + (previous and container.gap or 0)
			maxCross = math.max(maxCross, child:GetWidth() or 0)
		else
			child:SetPoint('TOPLEFT', previous or container, previous and 'TOPRIGHT' or 'TOPLEFT', previous and container.gap or 0, 0)
			total = total + (child:GetWidth() or 0) + (previous and container.gap or 0)
			maxCross = math.max(maxCross, child:GetHeight() or 0)
		end
		previous = child
	end
	if container.direction == 'vertical' then
		container:SetSize(maxCross, math.max(total, 1))
	else
		container:SetSize(math.max(total, 1), maxCross)
	end
end

local function CreateLayout(parent, direction, gap)
	local layout = CreateFrame('Frame', nil, parent)
	layout.direction = direction
	layout.gap = gap or 8
	layout.children = {}
	function layout:Add(child)
		self.children[#self.children + 1] = child
		child:SetParent(self)
		LayoutChildren(self)
		return child
	end
	function layout:Layout()
		LayoutChildren(self)
	end
	return layout
end

function Kit:CreateStack(parent, gap)
	return CreateLayout(parent, 'vertical', gap)
end

function Kit:CreateRow(parent, gap)
	return CreateLayout(parent, 'horizontal', gap)
end

LibStub('AceEvent-3.0'):Embed(Kit)
Kit:RegisterMessage(LibAT.UI.ACCENT_CHANGED, function()
	Kit:RefreshAll()
end)
Kit:RegisterMessage(LibAT.UI.BACKDROP_CHANGED, function()
	Kit:RefreshAll()
end)

return Kit
