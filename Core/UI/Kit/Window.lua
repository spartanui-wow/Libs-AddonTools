---@class LibAT
local LibAT = LibAT

local Kit = LibAT.UI.Kit
local WHITE = 'Interface\\Buttons\\WHITE8X8'
-- Space between the bars and the body
local BODY_GAP = 9

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

---A title or footer strip: the kit's material under a shade, with one rule on the body side.
local function CreateBar(parent, ruleOnTop)
	local bar = CreateFrame('Frame', nil, parent)
	bar.material = bar:CreateTexture(nil, 'BACKGROUND', nil, 1)
	bar.material:SetAllPoints()
	bar.shade = bar:CreateTexture(nil, 'BACKGROUND', nil, 2)
	bar.shade:SetAllPoints()
	bar.rule = bar:CreateTexture(nil, 'BORDER')
	bar.rule:SetTexture(WHITE)
	bar.rule:SetHeight(1)
	bar.rule:SetPoint(ruleOnTop and 'TOPLEFT' or 'BOTTOMLEFT')
	bar.rule:SetPoint(ruleOnTop and 'TOPRIGHT' or 'BOTTOMRIGHT')
	return bar
end

local function PaintBar(bar, config)
	local hasMaterial = Kit:SetAsset(bar.material, config, 'materialTile', 'REPEAT', 'REPEAT')
	if hasMaterial then
		bar.material:SetHorizTile(true)
		bar.material:SetVertTile(true)
		bar.material:SetVertexColor(1, 1, 1, 1)
	end
	local shade = config.colors.bar or config.colors.surface[1]
	bar.shade:SetTexture(WHITE)
	bar.shade:SetVertexColor(shade[1], shade[2], shade[3], hasMaterial and (shade[4] or 0.75) or 1)
	bar.rule:SetVertexColor(config.colors.trim[1], config.colors.trim[2], config.colors.trim[3], 0.6)
end

local function CreateCloseButton(shell)
	local close = CreateFrame('Button', nil, shell)
	close:SetFrameLevel(shell:GetFrameLevel() + 60)
	close:SetSize(20, 20)
	close.bg = close:CreateTexture(nil, 'BACKGROUND')
	close.bg:SetAllPoints()
	close.edges = AddEdges(close)
	close.a = close:CreateTexture(nil, 'OVERLAY')
	close.a:SetTexture(WHITE)
	close.a:SetSize(10, 2)
	close.a:SetPoint('CENTER')
	close.a:SetRotation(math.rad(45))
	close.b = close:CreateTexture(nil, 'OVERLAY')
	close.b:SetTexture(WHITE)
	close.b:SetSize(10, 2)
	close.b:SetPoint('CENTER')
	close.b:SetRotation(math.rad(-45))
	close.hover = close:CreateTexture(nil, 'ARTWORK')
	close.hover:SetTexture(WHITE)
	close.hover:SetAllPoints()
	close.hover:SetVertexColor(1, 1, 1, 0.14)
	close.hover:Hide()
	close:SetScript('OnEnter', function(self)
		if not self.usingAtlas then
			self.hover:Show()
			local text = self.hoverColor or { 1, 1, 1 }
			self.a:SetVertexColor(text[1], text[2], text[3], 1)
			self.b:SetVertexColor(text[1], text[2], text[3], 1)
		end
	end)
	close:SetScript('OnLeave', function(self)
		self.hover:Hide()
		if not self.usingAtlas and self.restColor then
			self.a:SetVertexColor(self.restColor[1], self.restColor[2], self.restColor[3], 1)
			self.b:SetVertexColor(self.restColor[1], self.restColor[2], self.restColor[3], 1)
		end
	end)
	close:SetScript('OnClick', function()
		shell:Hide()
	end)
	return close
end

local function PaintCloseButton(close, config)
	local atlas = config.blizzardButtons and Kit:FirstAtlas('RedButton-Exit', '128-RedButton-Exit')
	if atlas then
		close:SetSize(22, 22)
		close:SetNormalAtlas(atlas)
		close:SetPushedAtlas(Kit:FirstAtlas('RedButton-exit-pressed', '128-RedButton-Exit-Pressed') or atlas)
		local highlight = Kit:FirstAtlas('RedButton-Highlight', '128-redbutton-exit-highlight')
		if highlight then
			close:SetHighlightAtlas(highlight, 'ADD')
		end
		close.bg:Hide()
		ColorEdges(close.edges, config.colors.trim, 0)
		close.a:Hide()
		close.b:Hide()
		close.usingAtlas = true
		return
	end
	close:SetSize(20, 20)
	-- Only a kit switch away from the atlas button leaves textures to clear. Retail refuses nil here.
	if close.usingAtlas and close.ClearNormalTexture then
		close:ClearNormalTexture()
		close:ClearPushedTexture()
		close:ClearHighlightTexture()
	end
	close.usingAtlas = nil
	local secondary = config.button.secondary
	Kit:SetGradient(close.bg, secondary.top, secondary.bottom, 1)
	close.bg:Show()
	ColorEdges(close.edges, secondary.edge, 1)
	local text = config.colors.secondary
	close.restColor = text
	close.hoverColor = config.colors.text
	close.a:SetVertexColor(text[1], text[2], text[3], 1)
	close.b:SetVertexColor(text[1], text[2], text[3], 1)
	close.a:Show()
	close.b:Show()
end

local function CreateResizeHandle(shell)
	local handle = CreateFrame('Button', nil, shell)
	handle:SetSize(14, 14)
	handle:SetFrameLevel(shell:GetFrameLevel() + 61)
	handle.dots = {}
	-- A small triangle of dots, drawn in the kit's trim color
	for row = 0, 2 do
		for col = 0, row do
			local dot = handle:CreateTexture(nil, 'OVERLAY')
			dot:SetTexture(WHITE)
			dot:SetSize(2, 2)
			dot:SetPoint('BOTTOMRIGHT', -(col * 4) - 2, (row - col) * 4 + 2)
			handle.dots[#handle.dots + 1] = dot
		end
	end
	handle:SetScript('OnMouseDown', function()
		shell:StartSizing('BOTTOMRIGHT')
	end)
	handle:SetScript('OnMouseUp', function()
		shell:StopMovingOrSizing()
		-- Windows that remember their size set this
		if shell.OnResized then
			shell:OnResized()
		end
	end)
	handle:Hide()
	return handle
end

---@class LibAT.UI.KitShellOptions
---@field name string Global frame name (also lets Escape close it)
---@field title? string
---@field width? number
---@field height? number
---@field strata? FrameStrata
---@field footer? boolean Show the footer bar from the start (CreateActionButtons also turns it on)
---@field resizable? boolean
---@field minWidth? number
---@field minHeight? number
---@field kit? string Keep this window on one kit: a kit id, 'default' (LibAT's own look) or 'auto' (follow the host addon, the default)

---A window dressed by the active kit: title bar, painted frame, optional footer and a Body for content.
---@param options LibAT.UI.KitShellOptions
---@return Frame shell
function Kit:CreateShell(options)
	options = options or {}
	local name = options.name or 'LibAT_KitWindow'
	local shell = CreateFrame('Frame', name, UIParent)
	shell:SetSize(options.width or 800, options.height or 538)
	shell:SetPoint('CENTER')
	shell:SetFrameStrata(options.strata or 'HIGH')
	shell:SetToplevel(true)
	shell:SetClampedToScreen(true)
	shell:SetMovable(true)
	shell:EnableMouse(true)
	shell:RegisterForDrag('LeftButton')
	shell:SetScript('OnDragStart', shell.StartMoving)
	shell:SetScript('OnDragStop', function(owner)
		owner:StopMovingOrSizing()
	end)
	shell:Hide()
	if shell.SetDontSavePosition then
		shell:SetDontSavePosition(true)
	end
	if UISpecialFrames then
		tinsert(UISpecialFrames, name)
	end
	return self:DressShell(shell, options)
end

---Dress a window someone else created (an AceGUI container, for example) in the kit's chrome.
---The caller keeps control of its size, position, strata and dragging.
---@param shell Frame
---@param options? LibAT.UI.KitShellOptions
---@return Frame shell
function Kit:DressShell(shell, options)
	options = options or {}
	shell.kitShell = true
	-- An addon can keep its window on one kit whatever the host addon picks
	if options.kit and options.kit ~= 'auto' then
		shell.kitPinned = options.kit == 'default' and Kit.DEFAULT or (self.registry[options.kit] and options.kit or Kit.DEFAULT)
	end

	shell.VisualRoot = CreateFrame('Frame', nil, shell)
	shell.VisualRoot:SetAllPoints()
	shell.Backdrop = shell.VisualRoot:CreateTexture(nil, 'BACKGROUND', nil, -7)
	shell.Dim = shell.VisualRoot:CreateTexture(nil, 'BACKGROUND', nil, -6)
	shell.Dim:SetTexture(WHITE)
	shell.Surface = shell.VisualRoot:CreateTexture(nil, 'BACKGROUND', nil, -5)
	shell.Material = shell.VisualRoot:CreateTexture(nil, 'BACKGROUND', nil, -4)
	shell.Rim = AddEdges(shell.VisualRoot)
	shell.FrameArt = CreateFrame('Frame', nil, shell.VisualRoot)
	shell.FrameArt:SetAllPoints()
	shell.FrameArt:SetFrameLevel(shell:GetFrameLevel() + 40)
	-- A crest mounted on the frame's top edge, rising above the window
	shell.Crest = shell.FrameArt:CreateTexture(nil, 'OVERLAY', nil, 7)
	shell.Crest:Hide()

	shell.TitleBar = CreateBar(shell.VisualRoot, false)
	shell.TitleText = shell.TitleBar:CreateFontString(nil, 'OVERLAY')
	self:SetFont(shell.TitleText, 15)
	shell.TitleText:SetText(options.title or '')
	shell.TitlePlate = shell.TitleBar:CreateTexture(nil, 'ARTWORK')
	shell.TitlePlate:SetPoint('TOP', shell.TitleBar, 'TOP', 0, 0)
	shell.TitlePlate:Hide()
	shell.CloseButton = CreateCloseButton(shell)
	shell.closeBtn = shell.CloseButton

	shell.Footer = CreateBar(shell.VisualRoot, true)
	shell.Footer:SetShown(options.footer and true or false)
	shell.Body = CreateFrame('Frame', nil, shell)
	shell.ResizeHandle = CreateResizeHandle(shell)
	shell.config = options

	function shell:SetTitle(value)
		self.TitleText:SetText(value or '')
	end

	---Turn the footer bar on or off; the body grows into its space when it is off.
	function shell:SetFooterShown(shown)
		self.Footer:SetShown(shown and true or false)
		self:ApplyKit()
	end

	---@param enable boolean
	---@param minW? number
	---@param minH? number
	function shell:EnableResize(enable, minW, minH)
		self:SetResizable(enable and true or false)
		if enable then
			local width, height = minW or options.minWidth or 200, minH or options.minHeight or 150
			if self.SetResizeBounds then
				self:SetResizeBounds(width, height)
			elseif self.SetMinResize then
				self:SetMinResize(width, height)
			end
		end
		self.ResizeHandle:SetShown(enable and true or false)
	end

	shell:HookScript('OnSizeChanged', function(owner)
		owner:ApplyKit()
	end)

	if options.resizable then
		shell:EnableResize(true)
	end

	return self:Track(shell, function(owner, config)
		owner._kitId = config.id
		local layout = config.layout
		local hasPaintedFrame = Kit.ApplyNineSlice(owner.FrameArt, config, config.assets.windowBorder)
		local inset = layout.barInset

		owner.TitleBar:ClearAllPoints()
		owner.TitleBar:SetPoint('TOPLEFT', owner, 'TOPLEFT', inset, -inset)
		owner.TitleBar:SetPoint('TOPRIGHT', owner, 'TOPRIGHT', -inset, -inset)
		owner.TitleBar:SetHeight(layout.titleHeight)
		owner.Footer:ClearAllPoints()
		owner.Footer:SetPoint('BOTTOMLEFT', owner, 'BOTTOMLEFT', inset, inset)
		owner.Footer:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -inset, inset)
		owner.Footer:SetHeight(layout.footerHeight)
		owner.Body:ClearAllPoints()
		owner.Body:SetPoint('TOPLEFT', owner.TitleBar, 'BOTTOMLEFT', layout.sideInset - inset, -BODY_GAP)
		if owner.Footer:IsShown() then
			owner.Body:SetPoint('BOTTOMRIGHT', owner.Footer, 'TOPRIGHT', -(layout.sideInset - inset), BODY_GAP)
		else
			owner.Body:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -layout.sideInset, inset + BODY_GAP)
		end
		-- Painted frames have shaped corners; keep the square background tucked under the beam
		local fill = hasPaintedFrame and math.floor(((config.assets.windowBorder.edgeSize or 9) / 2) + 0.5) or 0
		for _, layer in ipairs({ owner.Backdrop, owner.Dim, owner.Surface, owner.Material }) do
			layer:ClearAllPoints()
			layer:SetPoint('TOPLEFT', owner, 'TOPLEFT', fill, -fill)
			layer:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -fill, fill)
		end
		owner.ResizeHandle:ClearAllPoints()
		owner.ResizeHandle:SetPoint('BOTTOMRIGHT', owner, 'BOTTOMRIGHT', -inset, inset)
		for _, dot in ipairs(owner.ResizeHandle.dots) do
			dot:SetVertexColor(config.colors.trimHi[1], config.colors.trimHi[2], config.colors.trimHi[3], 0.8)
		end

		local backdrop = Kit:Texture(config, 'backdrop') or LibAT.UI.GetBackdrop()
		owner.Backdrop:SetTexture(backdrop or WHITE)
		owner.Backdrop:SetVertexColor(1, 1, 1, backdrop and (config.backdropAlpha or 1) or 0)
		if backdrop then
			Kit:CropToFill(owner.Backdrop, config.backdropAspect or 2, owner:GetWidth(), owner:GetHeight(), config.backdropAnchorY)
		end
		local ground = config.colors.surface[0]
		owner.Dim:SetVertexColor(ground[1], ground[2], ground[3], config.backdropDim or 0.35)
		owner.Surface:SetTexture(WHITE)
		owner.Surface:SetVertexColor(ground[1], ground[2], ground[3], backdrop and (config.windowSurfaceAlpha or 0.18) or (ground[4] or 0.95))
		if Kit:SetAsset(owner.Material, config, 'materialTile', 'REPEAT', 'REPEAT') then
			owner.Material:SetHorizTile(true)
			owner.Material:SetVertTile(true)
			owner.Material:SetVertexColor(1, 1, 1, config.windowMaterialAlpha or 0.06)
		end
		ColorEdges(owner.Rim, config.colors.trimHi, hasPaintedFrame and 0 or 0.7)

		PaintBar(owner.TitleBar, config)
		PaintBar(owner.Footer, config)
		owner.TitleText:ClearAllPoints()
		owner.TitleText:SetPoint('LEFT', owner.TitleBar, 'LEFT', layout.barPadding, 0)
		owner.TitleText:SetTextColor(config.colors.text[1], config.colors.text[2], config.colors.text[3])
		local crest = config.assets.crest
		if Kit:SetAsset(owner.Crest, config, 'crest') then
			owner.Crest:ClearAllPoints()
			-- overlap: how far the crest's base reaches down over the frame and title bar
			owner.Crest:SetPoint('BOTTOM', owner, 'TOP', 0, -(crest.overlap or 20))
			owner.Crest:SetSize(crest.width or 128, crest.height or 64)
		end
		local plate = config.assets.titlePlate
		if Kit:SetAsset(owner.TitlePlate, config, 'titlePlate') then
			owner.TitlePlate:SetSize(type(plate) == 'table' and plate.width or 150, type(plate) == 'table' and plate.height or layout.titleHeight)
		end
		owner.CloseButton:ClearAllPoints()
		owner.CloseButton:SetPoint('RIGHT', owner.TitleBar, 'RIGHT', -6, 0)
		PaintCloseButton(owner.CloseButton, config)
	end)
end

---The setup window: a shell whose body holds the step rail and the page.
function Kit:CreateWindow(options)
	options = options or {}
	local window = self:CreateShell({
		name = options.name or 'LibAT_KitWindow',
		title = options.title or 'Setup',
		width = options.width or 1024,
		height = options.height or 650,
		footer = true,
	})
	window.MainContent = window.Body
	window.LeftPanel = self:CreateNavRail(window.Body, {
		elevation = 1,
		shadow = false,
		backdrop = function(config)
			return Kit:Texture(config, 'railBackdrop')
		end,
	})
	window.LeftPanel:SetPoint('TOPLEFT')
	window.LeftPanel:SetPoint('BOTTOMLEFT')
	window.LeftPanel:SetWidth(218)
	window.RightPanel = self:CreatePanel(window.Body, {
		elevation = 1,
		shadow = false,
		backdrop = function(config)
			return Kit:Texture(config, 'panelBackdrop')
		end,
	})
	window.RightPanel:SetPoint('TOPLEFT', window.LeftPanel, 'TOPRIGHT', 12, 0)
	window.RightPanel:SetPoint('BOTTOMRIGHT')

	function window:RefreshBackdrop()
		self:ApplyKit()
	end

	return window
end

return Kit
