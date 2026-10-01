---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Button Components
----------------------------------------------------------------------------------------------------

---Create a button drawn by the active UI kit
---@param parent Frame Parent frame
---@param width number Button width
---@param height number Button height
---@param text string Button text
---@param black? boolean Older callers used this for the dark list-style button; it is a secondary button now
---@return Frame button
function LibAT.UI.CreateButton(parent, width, height, text, black)
	local button = LibAT.UI.Kit:CreateButton(parent, text, 'secondary', width)
	button:SetHeight(height or 24)
	if black then
		-- Older list buttons are marked selected through this texture
		button.SelectedTexture = button:CreateTexture(nil, 'ARTWORK')
		button.SelectedTexture:SetTexture('Interface\\Buttons\\WHITE8X8')
		button.SelectedTexture:SetAllPoints()
		button.SelectedTexture:Hide()
		LibAT.UI.Kit:Track(button.SelectedTexture, function(owner)
			local r, g, b = LibAT.UI.GetAccentColor()
			owner:SetVertexColor(r, g, b, 0.25)
		end)
	end
	return button
end

local WHITE = 'Interface\\Buttons\\WHITE8X8'
-- Text indent and highlight inset for each level of a navigation list
local NAV_LEVELS = {
	category = { text = 8, inset = 0, fill = 0.05 },
	subCategory = { text = 18, inset = 10, fill = 0 },
	subSubCategory = { text = 26, inset = 20, fill = 0 },
}

local function PaintNavButton(button, kit)
	local level = NAV_LEVELS[button.type] or NAV_LEVELS.category
	local r, g, b = LibAT.UI.GetAccentColor()
	button.NormalTexture:SetVertexColor(kit.colors.text[1], kit.colors.text[2], kit.colors.text[3], level.fill)
	button.SelectedTexture:SetVertexColor(r, g, b, 0.25)
	button.HighlightTexture:SetVertexColor(1, 1, 1, 0.06)
	button.Lines:SetVertexColor(kit.colors.trim[1], kit.colors.trim[2], kit.colors.trim[3], 0.6)
	local color = button.type == 'category' and kit.colors.text or kit.colors.secondary
	button.Text:SetTextColor(color[1], color[2], color[3])
end

---Create a navigation list button (categories and their children)
---@param parent Frame Parent frame
---@param name? string Optional unique name for the button
---@return Frame button
function LibAT.UI.CreateFilterButton(parent, name)
	local button = CreateFrame('Button', name, parent, 'TruncatedTooltipScriptTemplate')
	button:SetSize(150, 22)

	button.NormalTexture = button:CreateTexture(nil, 'BACKGROUND')
	button.NormalTexture:SetTexture(WHITE)
	button.NormalTexture:SetAllPoints()
	button.Lines = button:CreateTexture(nil, 'BACKGROUND')
	button.Lines:SetTexture(WHITE)
	button.Lines:SetSize(6, 1)
	button.Lines:SetPoint('LEFT', button, 'LEFT', 16, 0)
	button.Lines:Hide()
	button.HighlightTexture = button:CreateTexture(nil, 'BORDER')
	button.HighlightTexture:SetTexture(WHITE)
	button.HighlightTexture:SetAllPoints()
	button:SetHighlightTexture(button.HighlightTexture)
	button.SelectedTexture = button:CreateTexture(nil, 'ARTWORK')
	button.SelectedTexture:SetTexture(WHITE)
	button.SelectedTexture:SetAllPoints()
	button.SelectedTexture:Hide()

	button.Text = button:CreateFontString(nil, 'OVERLAY')
	LibAT.UI.Kit:SetFont(button.Text, 13)
	button.Text:SetPoint('LEFT', button, 'LEFT', 8, 0)
	button.Text:SetPoint('RIGHT', button, 'RIGHT', -4, 0)
	button.Text:SetJustifyH('LEFT')
	button.Text:SetWordWrap(false)
	button:SetFontString(button.Text)

	-- A row placed against its list's top left also reaches the list's right edge, so rows never
	-- run under the list's scroll bar
	local NativeSetPoint = button.SetPoint
	function button:SetPoint(point, relativeTo, relativePoint, x, y)
		NativeSetPoint(self, point, relativeTo, relativePoint, x, y)
		if point == 'TOPLEFT' and relativeTo == self:GetParent() and relativePoint == 'TOPLEFT' then
			NativeSetPoint(self, 'TOPRIGHT', relativeTo, 'TOPRIGHT', -2, y or 0)
		end
	end

	return LibAT.UI.Kit:Track(button, PaintNavButton)
end

---Set a navigation list button up for its level
---@param button Frame The button to set up
---@param info table { type = 'category'|'subCategory'|'subSubCategory', name, selected, categoryIndex, ... }
function LibAT.UI.SetupFilterButton(button, info)
	local level = NAV_LEVELS[info.type] or NAV_LEVELS.category
	button.type = info.type
	button:SetText(info.name or '')
	button.Text:ClearAllPoints()
	button.Text:SetPoint('LEFT', button, 'LEFT', level.text, 0)
	button.Text:SetPoint('RIGHT', button, 'RIGHT', -4, 0)
	for _, texture in ipairs({ button.SelectedTexture, button.HighlightTexture }) do
		texture:ClearAllPoints()
		texture:SetPoint('TOPLEFT', button, 'TOPLEFT', level.inset, 0)
		texture:SetPoint('BOTTOMRIGHT')
	end
	button.Lines:SetShown(info.type == 'subSubCategory')
	LibAT.UI.Kit:SetFont(button.Text, info.type == 'category' and 13 or 12)

	if info.type == 'category' then
		button.categoryIndex = info.categoryIndex
	elseif info.type == 'subCategory' then
		button.subCategoryIndex = info.subCategoryIndex
	elseif info.type == 'subSubCategory' then
		button.subSubCategoryIndex = info.subSubCategoryIndex
	end

	button.SelectedTexture:SetShown(info.selected)
	button:ApplyKit()
end

---Create an icon button (like the settings gear)
---@param parent Frame Parent frame
---@param normalAtlas string Atlas name for normal state
---@param highlightAtlas string Atlas name for highlight state
---@param pushedAtlas string Atlas name for pushed state
---@param size? number Optional size (default 24)
---@return Frame button Icon button
function LibAT.UI.CreateIconButton(parent, normalAtlas, highlightAtlas, pushedAtlas, size)
	size = size or 24
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(size, size)

	-- Create texture layers using atlas
	button.NormalTexture = button:CreateTexture(nil, 'ARTWORK')
	button.NormalTexture:SetAtlas(normalAtlas)
	button.NormalTexture:SetAllPoints()

	button.HighlightTexture = button:CreateTexture(nil, 'HIGHLIGHT')
	button.HighlightTexture:SetAtlas(highlightAtlas)
	button.HighlightTexture:SetAllPoints()
	button.HighlightTexture:SetAlpha(0)

	button.PushedTexture = button:CreateTexture(nil, 'ARTWORK')
	button.PushedTexture:SetAtlas(pushedAtlas)
	button.PushedTexture:SetAllPoints()
	button.PushedTexture:SetAlpha(0)

	-- Set up hover and click effects
	button:SetScript('OnEnter', function(self)
		self.HighlightTexture:SetAlpha(1)
	end)
	button:SetScript('OnLeave', function(self)
		self.HighlightTexture:SetAlpha(0)
	end)
	button:SetScript('OnMouseDown', function(self)
		self.PushedTexture:SetAlpha(1)
		self.NormalTexture:SetAlpha(0)
	end)
	button:SetScript('OnMouseUp', function(self)
		self.PushedTexture:SetAlpha(0)
		self.NormalTexture:SetAlpha(1)
	end)

	return button
end

----------------------------------------------------------------------------------------------------
-- Input Components
----------------------------------------------------------------------------------------------------

-- Inputs, checkboxes and dropdowns draw through the window kit, so they change with the theme
-- like the windows around them. Every builder keeps the fields and methods it always had.

local WHITE = 'Interface\\Buttons\\WHITE8X8'

---Keep a widget's own handlers for these scripts running whatever the caller sets. SetScript clears
---hooks added with HookScript, so a widget that paints from a hook would break the moment a caller
---sets its own handler. Here the caller's SetScript/GetScript only see the caller's handler, and the
---widget's handlers run first.
---@param frame Frame
---@param handlers table<string, function>
---@return Frame frame
function LibAT.UI.KeepScripts(frame, handlers)
	local own = frame.kitOwnScripts
	if not own then
		own = {}
		frame.kitOwnScripts = own
		frame.kitCallerScripts = {}
		local NativeSetScript, NativeGetScript = frame.SetScript, frame.GetScript
		frame.kitNativeSetScript, frame.kitNativeGetScript = NativeSetScript, NativeGetScript
		function frame:SetScript(event, handler)
			if own[event] then
				self.kitCallerScripts[event] = handler
				return
			end
			NativeSetScript(self, event, handler)
		end
		function frame:GetScript(event)
			if own[event] then
				return self.kitCallerScripts[event]
			end
			return NativeGetScript(self, event)
		end
	end
	for event, fn in pairs(handlers) do
		local list = own[event]
		if not list then
			list = {}
			own[event] = list
			frame.kitCallerScripts[event] = frame.kitNativeGetScript(frame, event)
			frame.kitNativeSetScript(frame, event, function(self, ...)
				for i = 1, #list do
					list[i](self, ...)
				end
				local caller = self.kitCallerScripts[event]
				if caller then
					return caller(self, ...)
				end
			end)
		end
		list[#list + 1] = fn
	end
	return frame
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
	for _, edge in ipairs(edges) do
		edge:SetVertexColor(color[1], color[2], color[3], alpha or color[4] or 1)
	end
end

local function Accent()
	local r, g, b = LibAT.UI.GetAccentColor()
	return { r, g, b }
end

---Dark or light glyphs, whichever reads better on the accent color
local function OnAccent()
	local r, g, b = LibAT.UI.GetAccentColor()
	if 0.299 * r + 0.587 * g + 0.114 * b > 0.6 then
		return { 0.05, 0.06, 0.07 }
	end
	return { 1, 1, 1 }
end

---Input fill and 1px edges that brighten on hover and take the accent color while focused.
---@param frame Frame
---@param state fun(frame: Frame): 'normal'|'hover'|'focus'|'disabled'
local function SkinInput(frame, state)
	frame.kitFill = frame:CreateTexture(nil, 'BACKGROUND')
	frame.kitFill:SetTexture(WHITE)
	frame.kitFill:SetAllPoints()
	frame.kitEdges = AddEdges(frame, 'BORDER')
	LibAT.UI.Kit:Track(frame, function(owner, config)
		local c = config.colors
		local mode = state(owner)
		local fill = c.surface[0]
		owner.kitFill:SetVertexColor(fill[1], fill[2], fill[3], mode == 'disabled' and 0.4 or 0.85)
		if mode == 'focus' then
			ColorEdges(owner.kitEdges, Accent(), 1)
		elseif mode == 'hover' then
			ColorEdges(owner.kitEdges, c.trimHi, 0.85)
		else
			ColorEdges(owner.kitEdges, c.trim, mode == 'disabled' and 0.35 or 0.75)
		end
		if owner.kitPaintText then
			owner:kitPaintText(c, mode, config)
		end
	end)
end

local function EditBoxState(editBox)
	if editBox.IsEnabled and not editBox:IsEnabled() then
		return 'disabled'
	elseif editBox:HasFocus() then
		return 'focus'
	elseif editBox.kitHovered then
		return 'hover'
	end
	return 'normal'
end

local function PaintEditText(editBox, c, mode)
	local color = mode == 'disabled' and c.muted or c.text
	editBox:SetTextColor(color[1], color[2], color[3])
end

local function HookInputStates(editBox)
	LibAT.UI.KeepScripts(editBox, {
		OnEditFocusGained = editBox.ApplyKit,
		OnEditFocusLost = editBox.ApplyKit,
		OnEnter = function(self)
			self.kitHovered = true
			self:ApplyKit()
		end,
		OnLeave = function(self)
			self.kitHovered = false
			self:ApplyKit()
		end,
	})
end

---Create a search box: an input with a magnifier, a "Search" hint and a clear button.
---Keeps the SearchBoxTemplate fields (Instructions, clearButton, searchIcon).
---@param parent Frame Parent frame
---@param width number Search box width
---@param height? number Optional height (default 22)
---@return EditBox searchBox Search box with clear button
function LibAT.UI.CreateSearchBox(parent, width, height)
	height = height or 22
	local searchBox = LibAT.UI.CreateEditBox(parent, width, height)
	searchBox:SetTextInsets(22, 20, 0, 0)

	searchBox.searchIcon = searchBox:CreateTexture(nil, 'OVERLAY')
	searchBox.searchIcon:SetSize(12, 12)
	searchBox.searchIcon:SetPoint('LEFT', 6, 0)
	local magnifier = LibAT.UI.Kit:FirstAtlas('common-search-magnifyingglass')
	if magnifier then
		searchBox.searchIcon:SetAtlas(magnifier)
	else
		searchBox.searchIcon:SetTexture('Interface\\Common\\UI-Searchbox-Icon')
	end

	searchBox.Instructions = searchBox:CreateFontString(nil, 'OVERLAY')
	LibAT.UI.Kit:SetFont(searchBox.Instructions, 12, true)
	searchBox.Instructions:SetPoint('LEFT', 22, 0)
	searchBox.Instructions:SetPoint('RIGHT', -20, 0)
	searchBox.Instructions:SetJustifyH('LEFT')
	searchBox.Instructions:SetWordWrap(false)
	searchBox.Instructions:SetText(SEARCH or 'Search')

	local clear = CreateFrame('Button', nil, searchBox)
	clear:SetSize(14, 14)
	clear:SetPoint('RIGHT', -4, 0)
	clear.texture = clear:CreateTexture(nil, 'ARTWORK')
	clear.texture:SetAllPoints()
	clear.texture:SetTexture('Interface\\FriendsFrame\\ClearBroadcastIcon')
	clear:Hide()
	searchBox.clearButton = clear

	local function Update(self)
		local empty = (self:GetText() or '') == ''
		self.Instructions:SetShown(empty and not self:HasFocus())
		self.clearButton:SetShown(not empty)
	end

	searchBox.kitPaintText = function(self, c, mode)
		PaintEditText(self, c, mode)
		self.Instructions:SetTextColor(c.muted[1], c.muted[2], c.muted[3])
		local icon = mode == 'focus' and c.secondary or c.muted
		self.searchIcon:SetVertexColor(icon[1], icon[2], icon[3])
		local x = self.clearButton.hovered and c.text or c.muted
		self.clearButton.texture:SetVertexColor(x[1], x[2], x[3])
	end

	clear:SetScript('OnEnter', function(self)
		self.hovered = true
		searchBox:ApplyKit()
	end)
	clear:SetScript('OnLeave', function(self)
		self.hovered = false
		searchBox:ApplyKit()
	end)
	clear:SetScript('OnClick', function()
		searchBox:SetText('')
		searchBox:ClearFocus()
	end)

	LibAT.UI.KeepScripts(searchBox, {
		OnTextChanged = Update,
		OnEditFocusGained = Update,
		OnEditFocusLost = Update,
	})
	searchBox:SetScript('OnEnterPressed', searchBox.ClearFocus)

	searchBox:ApplyKit()
	Update(searchBox)
	return searchBox
end

---Create a standard EditBox
---@param parent Frame Parent frame
---@param width number EditBox width
---@param height number EditBox height
---@param multiline? boolean Optional multiline support (default false)
---@return EditBox editBox Standard edit box
function LibAT.UI.CreateEditBox(parent, width, height, multiline)
	local editBox = CreateFrame('EditBox', nil, parent)
	editBox:SetSize(width, height)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject(LibAT.UI.Kit.plainFonts[12] or 'GameFontHighlight')
	editBox:SetTextInsets(6, 6, 2, 2)
	editBox:SetScript('OnEscapePressed', editBox.ClearFocus)
	editBox.kitPaintText = PaintEditText
	SkinInput(editBox, EditBoxState)
	HookInputStates(editBox)

	if multiline then
		editBox:SetMultiLine(true)
	end

	return editBox
end

---@class LibAT.CheckboxContainer : Frame
---@field checkbox CheckButton The actual checkbox button
---@field Label FontString The label font string (if label provided)
---@field Desc FontString|nil Optional description text below label
---@field disabled boolean Whether the checkbox is disabled
---@field tristate boolean|nil Whether tri-state mode is enabled
---@field SetChecked fun(self: LibAT.CheckboxContainer, checked: boolean|nil) Set checked state (nil = indeterminate in tri-state)
---@field GetChecked fun(self: LibAT.CheckboxContainer): boolean|nil Get checked state
---@field SetText fun(self: LibAT.CheckboxContainer, text: string) Set label text
---@field GetText fun(self: LibAT.CheckboxContainer): string|nil Get label text
---@field SetEnabled fun(self: LibAT.CheckboxContainer, enabled: boolean) Enable/disable the checkbox
---@field SetDescription fun(self: LibAT.CheckboxContainer, desc: string|nil) Set/clear description text below label
---@field SetTriState fun(self: LibAT.CheckboxContainer, enabled: boolean) Enable/disable tri-state mode
---@field HookScript fun(self: LibAT.CheckboxContainer, event: string, handler: function) Hook script on the checkbox
---@field SetScript fun(self: LibAT.CheckboxContainer, event: string, handler: function) Set script on the checkbox

local BOX_SIZE = 16

local function PaintCheckbox(container, config)
	local c = config.colors
	local state = container._checked
	local on = state and true or false
	local mixed = container.tristate and state == nil
	local accent = Accent()
	local alpha = container.disabled and 0.45 or 1
	if on then
		container.checkbg:SetVertexColor(accent[1], accent[2], accent[3], alpha)
		ColorEdges(container.boxEdges, accent, alpha)
	else
		local fill = c.surface[0]
		container.checkbg:SetVertexColor(fill[1], fill[2], fill[3], 0.85 * alpha)
		local edge = (mixed and accent) or (container.hovered and not container.disabled and c.trimHi) or c.trim
		ColorEdges(container.boxEdges, edge, (mixed and 1 or 0.85) * alpha)
	end
	LibAT.UI.Kit:SetAsset(container.check, config, 'checkMark')
	local glyph = OnAccent()
	container.check:SetVertexColor(glyph[1], glyph[2], glyph[3], alpha)
	container.check:SetShown(on)
	container.dash:SetVertexColor(accent[1], accent[2], accent[3], alpha)
	container.dash:SetShown(mixed)
	if container.Label then
		local color = container.disabled and c.muted or c.text
		container.Label:SetTextColor(color[1], color[2], color[3])
	end
	if container.Desc then
		local color = container.disabled and c.muted or c.secondary
		container.Desc:SetTextColor(color[1], color[2], color[3])
	end
end

---Create a checkbox with a container frame for proper positioning
---@param parent Frame Parent frame
---@param label? string Optional label text
---@param width? number Optional total width (default auto-calculated or 150)
---@param height? number Optional height (default 24)
---@return LibAT.CheckboxContainer container Container frame with checkbox and label
function LibAT.UI.CreateCheckbox(parent, label, width, height)
	height = height or 24
	local Kit = LibAT.UI.Kit
	local NativeSetScript, NativeHookScript

	---@type LibAT.CheckboxContainer
	local container = CreateFrame('Frame', nil, parent)
	container.disabled = false
	container.tristate = false
	NativeSetScript, NativeHookScript = container.SetScript, container.HookScript

	local checkbox = CreateFrame('CheckButton', nil, container)
	checkbox:SetSize(24, 24)
	checkbox:SetPoint('LEFT', container, 'LEFT', 0, 0)
	checkbox:EnableMouse(false) -- clicks go to the container
	container.checkbox = checkbox

	local box = CreateFrame('Frame', nil, checkbox)
	box:SetSize(BOX_SIZE, BOX_SIZE)
	box:SetPoint('CENTER')
	container.box = box

	local checkbg = box:CreateTexture(nil, 'BACKGROUND')
	checkbg:SetTexture(WHITE)
	checkbg:SetAllPoints()
	container.checkbg = checkbg
	container.boxEdges = AddEdges(box, 'BORDER')

	local check = box:CreateTexture(nil, 'OVERLAY')
	check:SetSize(BOX_SIZE - 2, BOX_SIZE - 2)
	check:SetPoint('CENTER')
	check:Hide()
	container.check = check

	local dash = box:CreateTexture(nil, 'OVERLAY')
	dash:SetTexture(WHITE)
	dash:SetSize(BOX_SIZE - 8, 2)
	dash:SetPoint('CENTER')
	dash:Hide()
	container.dash = dash

	if label then
		local labelText = container:CreateFontString(nil, 'OVERLAY')
		Kit:SetFont(labelText, 12)
		labelText:SetText(label)
		labelText:SetJustifyH('LEFT')
		labelText:SetWordWrap(false)
		labelText:SetHeight(18)
		labelText:SetPoint('LEFT', checkbox, 'RIGHT', 2, 0)
		container.Label = labelText

		if not width then
			width = 24 + LibAT.UI.MeasureText(labelText, 6.5) + 6
		end
		labelText:SetPoint('RIGHT', container, 'RIGHT', 0, 0)
	else
		width = width or 24
	end

	container:SetSize(width, height)
	container:EnableMouse(true)

	NativeHookScript(container, 'OnEnter', function()
		container.hovered = true
		container:ApplyKit()
	end)
	NativeHookScript(container, 'OnLeave', function()
		container.hovered = false
		container:ApplyKit()
	end)

	NativeSetScript(container, 'OnMouseUp', function(_, mouseButton)
		if container.disabled or (mouseButton and mouseButton ~= 'LeftButton') then
			return
		end
		if container.tristate then
			local current = container:GetChecked()
			if current then
				container:SetChecked(nil)
			elseif current == nil then
				container:SetChecked(false)
			else
				container:SetChecked(true)
			end
		else
			container:SetChecked(not container:GetChecked())
		end

		if container:GetChecked() then
			PlaySound(856) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON
		else
			PlaySound(857) -- SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
		end

		if container._onClickHandler then
			container._onClickHandler(container)
		end
	end)

	---Set checked state
	---@param checked boolean|nil Whether the checkbox is checked (nil = indeterminate in tri-state)
	function container:SetChecked(checked)
		container._checked = checked
		container:ApplyKit()
	end

	---Get checked state
	---@return boolean|nil checked Whether the checkbox is checked
	function container:GetChecked()
		return container._checked
	end

	---Set the label text
	---@param text string The text to display
	function container:SetText(text)
		if self.Label then
			self.Label:SetText(text)
		end
	end

	---Get the label text
	---@return string|nil text The label text or nil if no label
	function container:GetText()
		if self.Label then
			return self.Label:GetText()
		end
		return nil
	end

	---Enable or disable the checkbox
	---@param enabled boolean Whether to enable
	function container:SetEnabled(enabled)
		container.disabled = not enabled
		container:ApplyKit()
	end

	---Set optional description text below the label
	---@param desc string|nil Description text or nil to clear
	function container:SetDescription(desc)
		if desc then
			if not self.Desc then
				local f = container:CreateFontString(nil, 'OVERLAY')
				Kit:SetFont(f, 11)
				f:SetPoint('TOPLEFT', checkbox, 'TOPRIGHT', 2, -21)
				f:SetPoint('RIGHT', container, 'RIGHT', -4, 0)
				f:SetJustifyH('LEFT')
				f:SetJustifyV('TOP')
				self.Desc = f
			end
			self.Desc:Show()
			self.Desc:SetText(desc)
			container:SetHeight(28 + self.Desc:GetStringHeight())
		else
			if self.Desc then
				self.Desc:SetText('')
				self.Desc:Hide()
			end
			container:SetHeight(24)
		end
		container:ApplyKit()
	end

	---Enable or disable tri-state mode (cycles: true -> nil -> false)
	---@param enabled boolean Whether to enable tri-state
	function container:SetTriState(enabled)
		container.tristate = enabled
		container:SetChecked(container:GetChecked())
	end

	---Hook a script on the checkbox
	---@param event string Script event name
	---@param handler function Script handler
	function container:HookScript(event, handler)
		if event == 'OnClick' then
			local prev = container._onClickHandler
			container._onClickHandler = function(self)
				if prev then
					prev(self)
				end
				handler(self)
			end
		else
			NativeHookScript(self, event, function(_, ...)
				handler(container, ...)
			end)
		end
	end

	---Set a script on the checkbox
	---@param event string Script event name
	---@param handler function|nil Script handler
	function container:SetScript(event, handler)
		if event == 'OnClick' then
			container._onClickHandler = handler and function(self)
				handler(self)
			end or nil
		elseif event == 'OnEnter' or event == 'OnLeave' then
			-- Hover painting stays hooked, so the caller's handler is wrapped rather than replacing it
			local hovered = event == 'OnEnter'
			NativeSetScript(self, event, function(_, ...)
				container.hovered = hovered
				container:ApplyKit()
				if handler then
					handler(container, ...)
				end
			end)
		else
			NativeSetScript(self, event, handler)
		end
	end

	Kit:Track(container, PaintCheckbox)
	return container
end

---Menus opened from a LibAT dropdown: a kit surface with a trim edge. Blizzard's menu reads its
---look from the dropdown's own menuMixin, so no other menu in the game changes. Menus stay mostly
---solid even under a see-through kit, so their items stay readable.
local KitMenuMixin
if MenuStyleMixin and CreateFromMixins then
	KitMenuMixin = CreateFromMixins(MenuStyleMixin)

	function KitMenuMixin:Generate()
		local c = LibAT.UI.Kit:GetKitFor(self.kitOwner).colors
		local surface = c.surface[3]
		local fill = self:AttachTexture()
		fill:SetAllPoints()
		fill:SetColorTexture(surface[1], surface[2], surface[3], math.max(surface[4] or 1, 0.94))
		local edges = {
			{ 'TOPLEFT', 'TOPRIGHT', nil, 1 },
			{ 'BOTTOMLEFT', 'BOTTOMRIGHT', nil, 1 },
			{ 'TOPLEFT', 'BOTTOMLEFT', 1, nil },
			{ 'TOPRIGHT', 'BOTTOMRIGHT', 1, nil },
		}
		for _, anchor in ipairs(edges) do
			local edge = self:AttachTexture()
			edge:SetPoint(anchor[1])
			edge:SetPoint(anchor[2])
			if anchor[3] then
				edge:SetWidth(anchor[3])
			else
				edge:SetHeight(anchor[4])
			end
			edge:SetColorTexture(c.trim[1], c.trim[2], c.trim[3], 0.9)
		end
		local r, g, b = LibAT.UI.GetAccentColor()
		local accent = self:AttachTexture()
		accent:SetPoint('TOPLEFT', 1, -1)
		accent:SetPoint('TOPRIGHT', -1, -1)
		accent:SetHeight(1)
		accent:SetColorTexture(r, g, b, 0.85)
	end

	local inset = { left = 6, top = 6, right = 6, bottom = 6 }
	function KitMenuMixin:GetInset()
		return inset
	end

	local padding = { width = 20, height = 0 }
	function KitMenuMixin:GetChildExtentPadding()
		return padding
	end
end
LibAT.UI.KitMenuMixin = KitMenuMixin

local function DropdownState(dropdown)
	if not dropdown:IsEnabled() then
		return 'disabled'
	elseif (dropdown.IsMenuOpen and dropdown:IsMenuOpen()) or (dropdown.IsDown and dropdown:IsDown()) then
		return 'focus'
	elseif dropdown.IsOver and dropdown:IsOver() then
		return 'hover'
	end
	return 'normal'
end

---Restyle a Blizzard dropdown button with the kit; its menu behavior is left as it is.
---@param dropdown DropdownButton
function LibAT.UI.SkinDropdown(dropdown)
	local Kit = LibAT.UI.Kit
	if dropdown.Background then
		dropdown.Background:SetAlpha(0)
	end
	local font = Kit.plainFonts[12]
	if font then
		dropdown.baseFontObject = font
		dropdown.disableFontObject = font
		dropdown.Text:SetFontObject(font)
	end
	dropdown.resizeToText = false
	if KitMenuMixin then
		-- The menu is not inside the window, so it carries its dropdown to find the right kit
		dropdown.menuMixin = CreateFromMixins(KitMenuMixin, { kitOwner = dropdown })
	end
	dropdown.Text:ClearAllPoints()
	dropdown.Text:SetPoint('LEFT', 8, 0)
	dropdown.Text:SetPoint('RIGHT', -22, 0)
	dropdown.Text:SetJustifyH('LEFT')
	dropdown.kitArrow = dropdown:CreateTexture(nil, 'OVERLAY')
	dropdown.kitArrow:SetSize(10, 10)
	dropdown.kitArrow:SetPoint('RIGHT', -8, 0)
	dropdown.kitPaintText = function(self, c, mode, config)
		local color = mode == 'disabled' and c.muted or c.text
		self.Text:SetTextColor(color[1], color[2], color[3])
		Kit:SetAsset(self.kitArrow, config, 'chevron')
		if self.kitArrow.SetRotation then
			self.kitArrow:SetRotation(mode == 'focus' and math.pi / 2 or -math.pi / 2)
		end
		local arrow = (mode == 'hover' or mode == 'focus') and c.text or c.muted
		self.kitArrow:SetVertexColor(arrow[1], arrow[2], arrow[3], mode == 'disabled' and 0.5 or 1)
	end
	SkinInput(dropdown, DropdownState)
	-- The template repaints its own art on every state change; paint ours instead
	dropdown.OnButtonStateChanged = dropdown.ApplyKit
	dropdown:HookScript('OnEnable', dropdown.ApplyKit)
	dropdown:HookScript('OnDisable', dropdown.ApplyKit)
	if dropdown.RegisterCallback and DropdownButtonMixin and DropdownButtonMixin.Event then
		pcall(dropdown.RegisterCallback, dropdown, DropdownButtonMixin.Event.OnMenuClose, dropdown.ApplyKit, dropdown)
		pcall(dropdown.RegisterCallback, dropdown, DropdownButtonMixin.Event.OnMenuOpen, dropdown.ApplyKit, dropdown)
	end
	return dropdown
end

---Create a dropdown button (Blizzard's menu, drawn with the kit)
---@param parent Frame Parent frame
---@param text string Dropdown button text
---@param width? number Optional width (default 120)
---@param height? number Optional height (default 22)
---@return Frame dropdown Dropdown button
function LibAT.UI.CreateDropdown(parent, text, width, height)
	width = width or 120
	height = height or 22
	local dropdown = CreateFrame('DropdownButton', nil, parent, 'WowStyle1FilterDropdownTemplate')
	dropdown:SetSize(width, height)
	LibAT.UI.SkinDropdown(dropdown)
	dropdown:SetText(text)
	return dropdown
end

----------------------------------------------------------------------------------------------------
-- Favorite/Star Toggle Button
----------------------------------------------------------------------------------------------------

---@class LibAT.FavoriteButton : Button
---@field starTex Texture The star atlas texture
---@field SetFavorite fun(self: LibAT.FavoriteButton, isFavorite: boolean) Set the visual state
---@field IsFavorite fun(self: LibAT.FavoriteButton): boolean Get the current visual state

---Create a dual-state favorite star button using AuctionHouse atlas icons
---@param parent Frame Parent frame
---@param size? number Icon size (default 18)
---@param onToggle? fun(self: LibAT.FavoriteButton, isFavorite: boolean) Callback when toggled
---@return LibAT.FavoriteButton button Favorite toggle button
function LibAT.UI.CreateFavoriteButton(parent, size, onToggle)
	size = size or 18
	---@type LibAT.FavoriteButton
	local button = CreateFrame('Button', nil, parent)
	button:SetSize(size + 4, size + 4)

	button.starTex = button:CreateTexture(nil, 'ARTWORK')
	button.starTex:SetAtlas('auctionhouse-icon-favorite-off', false)
	button.starTex:SetSize(size, size)
	button.starTex:SetPoint('CENTER', button, 'CENTER', 0, 0)

	button._isFavorite = false

	function button:SetFavorite(isFavorite)
		button._isFavorite = isFavorite
		button.starTex:SetAtlas(isFavorite and 'auctionhouse-icon-favorite' or 'auctionhouse-icon-favorite-off', false)
	end

	function button:IsFavorite()
		return button._isFavorite
	end

	button:SetScript('OnClick', function(self)
		local newState = not self._isFavorite
		self:SetFavorite(newState)
		if onToggle then
			onToggle(self, newState)
		end
	end)

	return button
end

----------------------------------------------------------------------------------------------------
-- Panel Components
----------------------------------------------------------------------------------------------------

---Create a kit panel. The atlas argument is kept for older callers; the kit draws the panel.
---@param parent Frame Parent frame
---@param atlas? string Ignored
---@return Frame panel Styled panel frame
function LibAT.UI.CreateStyledPanel(parent, atlas)
	local panel = LibAT.UI.Kit:CreatePanel(parent, { elevation = 1 })
	panel.layoutType = 'InsetFrameTemplate'
	panel.Background = panel.layers.surface
	return panel
end

local function PaintScrollBar(bar, config)
	local c = config.colors
	local hot = bar.kitThumbHot
	bar.kitTrack:SetVertexColor(c.trim[1], c.trim[2], c.trim[3], 0.22)
	if hot then
		local r, g, b = LibAT.UI.GetAccentColor()
		bar.kitThumb:SetVertexColor(r, g, b, 0.95)
	else
		bar.kitThumb:SetVertexColor(c.trim[1], c.trim[2], c.trim[3], 0.8)
	end
end

---Restyle Blizzard's MinimalScrollBar with the kit: a thin track, a thumb that lights up under the
---mouse, and no step arrows. Scrolling behavior is Blizzard's.
---@param bar Frame MinimalScrollBar
function LibAT.UI.SkinScrollBar(bar)
	if not bar or bar.kitSkinned or not bar.Track or not bar.Track.Thumb then
		return bar
	end
	bar.kitSkinned = true
	local track, thumb = bar.Track, bar.Track.Thumb
	for _, region in ipairs({ track.Begin, track.Middle, track.End, thumb.Begin, thumb.Middle, thumb.End }) do
		if region then
			region:SetAlpha(0)
		end
	end
	for _, stepper in ipairs({ bar.Back, bar.Forward }) do
		if stepper then
			stepper:SetAlpha(0)
			stepper:EnableMouse(false)
		end
	end
	track:ClearAllPoints()
	track:SetPoint('TOP', bar, 'TOP', 0, -2)
	track:SetPoint('BOTTOM', bar, 'BOTTOM', 0, 2)

	bar.kitTrack = track:CreateTexture(nil, 'BACKGROUND')
	bar.kitTrack:SetTexture('Interface\\Buttons\\WHITE8X8')
	bar.kitTrack:SetPoint('TOP')
	bar.kitTrack:SetPoint('BOTTOM')
	bar.kitTrack:SetWidth(2)
	bar.kitThumb = thumb:CreateTexture(nil, 'OVERLAY')
	bar.kitThumb:SetTexture('Interface\\Buttons\\WHITE8X8')
	bar.kitThumb:SetPoint('TOP')
	bar.kitThumb:SetPoint('BOTTOM')
	bar.kitThumb:SetWidth(4)

	local function SetHot(hot)
		bar.kitThumbHot = hot
		bar:ApplyKit()
	end
	thumb:HookScript('OnEnter', function()
		SetHot(true)
	end)
	thumb:HookScript('OnLeave', function()
		if not thumb.kitDragging then
			SetHot(false)
		end
	end)
	thumb:HookScript('OnMouseDown', function()
		thumb.kitDragging = true
		SetHot(true)
	end)
	thumb:HookScript('OnMouseUp', function()
		thumb.kitDragging = false
		SetHot(thumb:IsMouseOver())
	end)
	return LibAT.UI.Kit:Track(bar, PaintScrollBar)
end

---Create a scroll frame with a kit-styled MinimalScrollBar
---@param parent Frame Parent frame
---@return ScrollFrame scrollFrame Scroll frame with attached scrollbar
function LibAT.UI.CreateScrollFrame(parent)
	local scrollFrame = CreateFrame('ScrollFrame', nil, parent)

	scrollFrame.ScrollBar = CreateFrame('EventFrame', nil, scrollFrame, 'MinimalScrollBar')
	scrollFrame.ScrollBar:SetPoint('TOPLEFT', scrollFrame, 'TOPRIGHT', 4, -4)
	scrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', scrollFrame, 'BOTTOMRIGHT', 4, 4)
	ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollFrame.ScrollBar)
	LibAT.UI.SkinScrollBar(scrollFrame.ScrollBar)

	return scrollFrame
end

---Create a scrollable text display (EditBox within ScrollFrame)
---@param parent Frame Parent frame
---@return Frame scrollFrame The scroll frame
---@return Frame editBox The edit box
function LibAT.UI.CreateScrollableTextDisplay(parent)
	local scrollFrame = LibAT.UI.CreateScrollFrame(parent)

	-- Create the text display area
	local editBox = CreateFrame('EditBox', nil, scrollFrame)
	editBox:SetMultiLine(true)
	editBox:SetFontObject(LibAT.UI.Kit.plainFonts[12] or 'GameFontHighlight')
	editBox:SetAutoFocus(false)
	editBox:EnableMouse(true)
	editBox:SetTextInsets(6, 6, 6, 6)

	-- The scroll bar sits inside the view, in the room callers leave beside the text, so the well
	-- and everything in it stay inside the frame the caller anchored
	scrollFrame.ScrollBar:ClearAllPoints()
	scrollFrame.ScrollBar:SetPoint('TOPRIGHT', scrollFrame, 'TOPRIGHT', -5, -5)
	scrollFrame.ScrollBar:SetPoint('BOTTOMRIGHT', scrollFrame, 'BOTTOMRIGHT', -5, 5)
	scrollFrame.kitFill = scrollFrame:CreateTexture(nil, 'BACKGROUND')
	scrollFrame.kitFill:SetTexture(WHITE)
	scrollFrame.kitFill:SetAllPoints()
	scrollFrame.kitEdges = AddEdges(scrollFrame, 'BORDER')

	-- Read-only views pick their own text color; follow the kit until they do
	local NativeSetTextColor = editBox.SetTextColor
	function editBox:SetTextColor(...)
		self.kitCustomColor = true
		NativeSetTextColor(self, ...)
	end
	LibAT.UI.Kit:Track(scrollFrame, function(owner, config)
		local c = config.colors
		local well0 = c.surface[0]
		owner.kitFill:SetVertexColor(well0[1], well0[2], well0[3], math.min((well0[4] or 1) * 0.75, 0.75))
		ColorEdges(owner.kitEdges, c.trim, 0.55)
		if not editBox.kitCustomColor then
			NativeSetTextColor(editBox, c.text[1], c.text[2], c.text[3])
		end
	end)
	editBox:SetWidth(1) -- Initial width; updated by OnSizeChanged below

	-- Initialize cursor tracking fields required by ScrollingEdit functions
	editBox.cursorOffset = 0
	editBox.cursorHeight = 0

	editBox:SetScript('OnTextChanged', function(self)
		ScrollingEdit_OnTextChanged(self, self:GetParent())
	end)
	editBox:SetScript('OnCursorChanged', function(self, x, y, w, h)
		ScrollingEdit_OnCursorChanged(self, x, y - 10, w, h)
	end)
	editBox:SetScript('OnEscapePressed', editBox.ClearFocus)

	scrollFrame:SetScrollChild(editBox)

	-- Keep editBox width in sync with scroll frame (scroll children can't use anchors)
	scrollFrame:SetScript('OnSizeChanged', function(self)
		editBox:SetWidth(math.max(self:GetWidth() - 20, 1))
	end)

	-- Click anywhere in scroll area to focus the edit box
	scrollFrame:EnableMouse(true)
	scrollFrame:SetScript('OnMouseDown', function()
		editBox:SetFocus()
	end)

	return scrollFrame, editBox
end

---Create a multiline text box with convenience methods (enhanced scrollable text)
---@param parent Frame Parent frame
---@param width number Box width
---@param height number Box height
---@param text? string Optional initial text
---@return Frame scrollFrame The scroll frame container with convenience methods
function LibAT.UI.CreateMultiLineBox(parent, width, height, text)
	local scrollFrame, editBox = LibAT.UI.CreateScrollableTextDisplay(parent)
	scrollFrame:SetSize(width, height)

	if text then
		editBox:SetText(text)
	end

	-- Add convenience methods to scrollFrame for easier usage
	---Set the text content
	---@param value string Text to set
	function scrollFrame:SetValue(value)
		scrollFrame._readOnlyText = value or ''
		editBox:SetText(scrollFrame._readOnlyText)
	end

	---Get the text content
	---@return string text Current text
	function scrollFrame:GetValue()
		return editBox:GetText()
	end

	---Set read-only mode (text remains selectable and copyable)
	---@param readonly boolean True to make read-only
	function scrollFrame:SetReadOnly(readonly)
		scrollFrame._isReadOnly = readonly
		local c = LibAT.UI.Kit:GetKitFor(scrollFrame).colors
		if readonly then
			editBox:SetTextColor(c.secondary[1], c.secondary[2], c.secondary[3])
			-- Block typing but keep the EditBox enabled so text is selectable/copyable
			editBox:SetScript('OnChar', function() end)
			-- Guard against paste or other modifications
			editBox:SetScript('OnTextChanged', function(self)
				if scrollFrame._readOnlyText and self:GetText() ~= scrollFrame._readOnlyText then
					self:SetText(scrollFrame._readOnlyText)
				end
				ScrollingEdit_OnTextChanged(self, self:GetParent())
			end)
		else
			editBox:SetTextColor(c.text[1], c.text[2], c.text[3])
			editBox:SetScript('OnChar', nil)
			editBox:SetScript('OnKeyDown', nil)
			editBox:SetScript('OnTextChanged', function(self)
				ScrollingEdit_OnTextChanged(self, self:GetParent())
			end)
		end
	end

	---Highlight all text
	function scrollFrame:HighlightText()
		editBox:HighlightText()
	end

	---Set focus to the editbox
	function scrollFrame:SetFocus()
		editBox:SetFocus()
	end

	-- Expose editBox for direct access if needed
	scrollFrame.editBox = editBox

	return scrollFrame
end

----------------------------------------------------------------------------------------------------
-- Text Components
----------------------------------------------------------------------------------------------------

---Kit text: follows the kit's colors until the caller picks a color of its own
---@param fontString FontString
---@param size number
---@param role string Kit color name
local function KitText(fontString, size, role)
	local Kit = LibAT.UI.Kit
	Kit:SetFont(fontString, size)
	local NativeSetTextColor = fontString.SetTextColor
	function fontString:SetTextColor(...)
		self.kitCustomColor = true
		NativeSetTextColor(self, ...)
	end
	Kit:Track(fontString, function(owner, config)
		if not owner.kitCustomColor then
			local color = config.colors[role]
			NativeSetTextColor(owner, color[1], color[2], color[3])
		end
	end)
	return fontString
end

---Create a font string label
---@param parent Frame Parent frame
---@param text string Label text
---@param fontObject? string Optional font object name (kit text when omitted)
---@return FontString label Font string
function LibAT.UI.CreateLabel(parent, text, fontObject)
	local label = parent:CreateFontString(nil, 'OVERLAY', fontObject)
	if not fontObject then
		KitText(label, 12, 'secondary')
	end
	label:SetText(text)
	return label
end

---Create a header label
---@param parent Frame Parent frame
---@param text string Header text
---@return FontString header Header font string
function LibAT.UI.CreateHeader(parent, text)
	local header = KitText(parent:CreateFontString(nil, 'OVERLAY'), 14, 'text')
	header:SetText(text)
	return header
end

----------------------------------------------------------------------------------------------------
-- Tooltip Style Constants
-- Shared color and formatting constants for consistent tooltip styling across Libs-* addons
----------------------------------------------------------------------------------------------------

---@class LibAT.UI.TooltipStyle
LibAT.UI.TooltipStyle = {
	-- Header colors (addon title, section headers)
	headerColor = { r = 1, g = 0.82, b = 0 }, -- Gold
	headerHex = 'ffd100',

	-- Subheader / section divider color
	subHeaderColor = { r = 0.8, g = 0.8, b = 0.8 }, -- Light gray
	subHeaderHex = 'cccccc',

	-- Normal text color
	textColor = { r = 1, g = 1, b = 1 }, -- White
	textHex = 'ffffff',

	-- Hint text color (click hints, instructions)
	hintColor = { r = 0.7, g = 0.7, b = 0.7 }, -- Gray
	hintHex = 'b3b3b3',

	-- Value/highlight color
	valueColor = { r = 0, g = 1, b = 0 }, -- Green
	valueHex = '00ff00',

	-- Warning/alert color
	warningColor = { r = 1, g = 0.5, b = 0 }, -- Orange
	warningHex = 'ff8000',

	-- Divider character for section separators
	dividerChar = '\226\148\128', -- Unicode box-drawing horizontal line (─)
}

---Format text as a tooltip hint (gray, smaller)
---@param text string The hint text
---@return string formatted Color-coded hint text
function LibAT.UI.TooltipStyle.FormatHint(text)
	return '|cff' .. LibAT.UI.TooltipStyle.hintHex .. text .. '|r'
end

---Format text as a tooltip header (gold)
---@param text string The header text
---@return string formatted Color-coded header text
function LibAT.UI.TooltipStyle.FormatHeader(text)
	return '|cff' .. LibAT.UI.TooltipStyle.headerHex .. text .. '|r'
end

---Format text as a tooltip value (green)
---@param text string The value text
---@return string formatted Color-coded value text
function LibAT.UI.TooltipStyle.FormatValue(text)
	return '|cff' .. LibAT.UI.TooltipStyle.valueHex .. text .. '|r'
end

---Build a section divider line (e.g., "── Section Name ──")
---@param title? string Optional section title
---@param width? number Optional total character width (default 40)
---@return string divider Formatted divider string
function LibAT.UI.TooltipStyle.BuildDivider(title, width)
	width = width or 40
	local divChar = LibAT.UI.TooltipStyle.dividerChar
	local hex = LibAT.UI.TooltipStyle.subHeaderHex

	if title then
		local sideLen = math.max(2, math.floor((width - #title - 2) / 2))
		local side = string.rep(divChar, sideLen)
		return '|cff' .. hex .. side .. ' ' .. title .. ' ' .. side .. '|r'
	else
		return '|cff' .. hex .. string.rep(divChar, width) .. '|r'
	end
end

return LibAT.UI
