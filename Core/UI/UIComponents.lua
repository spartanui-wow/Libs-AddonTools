---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Button Components
----------------------------------------------------------------------------------------------------

---Create a standard styled button using UIPanelButtonTemplate
---@param parent Frame Parent frame
---@param width number Button width
---@param height number Button height
---@param text string Button text
---@param black? boolean Optional flag to use black AH-style button (category style)
---@return Frame button Standard WoW UI button or black AH-style button
function LibAT.UI.CreateButton(parent, width, height, text, black)
	if black then
		-- Create black AH-style button (category style from SetupFilterButton)
		local button = CreateFrame('Button', nil, parent)
		button:SetSize(width, height)

		-- Create textures
		button.NormalTexture = button:CreateTexture(nil, 'BACKGROUND')
		button.NormalTexture:SetAtlas('auctionhouse-nav-button', false)
		button.NormalTexture:SetSize(width + 6, height + 11)
		button.NormalTexture:SetPoint('TOPLEFT', -2, 0)

		button.SelectedTexture = button:CreateTexture(nil, 'ARTWORK')
		button.SelectedTexture:SetAtlas('auctionhouse-nav-button-select', false)
		button.SelectedTexture:SetSize(width + 2, height)
		button.SelectedTexture:SetPoint('LEFT')
		button.SelectedTexture:Hide()

		button.HighlightTexture = button:CreateTexture(nil, 'BORDER')
		button.HighlightTexture:SetAtlas('auctionhouse-nav-button-highlight', false)
		button.HighlightTexture:SetSize(width + 2, height)
		button.HighlightTexture:SetPoint('LEFT')
		button.HighlightTexture:SetBlendMode('BLEND')

		-- Set highlight texture
		button:SetHighlightTexture(button.HighlightTexture)

		-- Button text
		button.Text = button:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		button.Text:SetSize(0, 8)
		button.Text:SetPoint('LEFT', button, 'LEFT', 8, 0)
		button.Text:SetPoint('RIGHT', button, 'RIGHT', -8, 0)
		button.Text:SetJustifyH('CENTER')
		button.Text:SetText(text)

		-- Font objects
		button:SetNormalFontObject(GameFontNormalSmall)
		button:SetHighlightFontObject(GameFontHighlightSmall)

		return button
	else
		-- Standard UIPanelButtonTemplate
		local button = CreateFrame('Button', nil, parent, 'UIPanelButtonTemplate')
		button:SetSize(width, height)
		button:SetText(text)
		return button
	end
end

---Create a filter button styled like the AuctionHouse navigation buttons
---@param parent Frame Parent frame
---@param name? string Optional unique name for the button
---@return Frame button Filter button with textures
function LibAT.UI.CreateFilterButton(parent, name)
	local button = CreateFrame('Button', name, parent, 'TruncatedTooltipScriptTemplate')
	button:SetSize(150, 21)

	-- Create all texture layers as defined in the XML template
	-- BACKGROUND layer
	button.Lines = button:CreateTexture(nil, 'BACKGROUND')
	button.Lines:SetAtlas('auctionhouse-nav-button-tertiary-filterline', true)
	button.Lines:SetPoint('LEFT', button, 'LEFT', 18, 3)

	button.NormalTexture = button:CreateTexture(nil, 'BACKGROUND')

	-- BORDER layer
	button.HighlightTexture = button:CreateTexture(nil, 'BORDER')
	button.HighlightTexture:Hide()

	-- ARTWORK layer
	button.SelectedTexture = button:CreateTexture(nil, 'ARTWORK')
	button.SelectedTexture:Hide()

	-- Button text with shadow
	button.Text = button:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	button.Text:SetSize(0, 8)
	button.Text:SetPoint('LEFT', button, 'LEFT', 4, 0)
	button.Text:SetPoint('RIGHT', button, 'RIGHT', -4, 0)
	button.Text:SetJustifyH('LEFT')
	-- Add text shadow
	button.Text:SetShadowOffset(1, -1)
	button.Text:SetShadowColor(0, 0, 0)

	-- Set font objects
	button:SetNormalFontObject(GameFontNormalSmall)
	button:SetHighlightFontObject(GameFontHighlightSmall)

	return button
end

---Setup a filter button with proper styling (matches Blizzard's FilterButton_SetUp)
---@param button Frame The button to setup
---@param info table Button configuration table with type, name, selected, etc.
function LibAT.UI.SetupFilterButton(button, info)
	local normalText = button.Text
	local normalTexture = button.NormalTexture
	local line = button.Lines
	local btnWidth = 144
	local btnHeight = 20

	if info.type == 'category' then
		button:SetNormalFontObject(GameFontNormalSmall)
		button.NormalTexture:SetAtlas('auctionhouse-nav-button', false)
		button.NormalTexture:SetSize(btnWidth + 6, btnHeight + 11)
		button.NormalTexture:ClearAllPoints()
		button.NormalTexture:SetPoint('TOPLEFT', -2, 0)
		button.SelectedTexture:SetAtlas('auctionhouse-nav-button-select', false)
		button.SelectedTexture:SetSize(btnWidth + 2, btnHeight)
		button.SelectedTexture:ClearAllPoints()
		button.SelectedTexture:SetPoint('LEFT')
		button.HighlightTexture:SetAtlas('auctionhouse-nav-button-highlight', false)
		button.HighlightTexture:SetSize(btnWidth + 2, btnHeight)
		button.HighlightTexture:ClearAllPoints()
		button.HighlightTexture:SetPoint('LEFT')
		button.HighlightTexture:SetBlendMode('BLEND')
		button:SetText(info.name)
		normalText:ClearAllPoints()
		normalText:SetPoint('LEFT', button, 'LEFT', 8, 0)
		normalTexture:SetAlpha(1.0)
		line:Hide()
	elseif info.type == 'subCategory' then
		button:SetNormalFontObject(GameFontHighlightSmall)
		button.NormalTexture:SetAtlas('auctionhouse-nav-button-secondary', false)
		button.NormalTexture:SetSize(btnWidth + 3, btnHeight + 11)
		button.NormalTexture:ClearAllPoints()
		button.NormalTexture:SetPoint('TOPLEFT', 1, 0)
		button.SelectedTexture:SetAtlas('auctionhouse-nav-button-secondary-select', false)
		button.SelectedTexture:SetSize(btnWidth - 10, btnHeight)
		button.SelectedTexture:ClearAllPoints()
		button.SelectedTexture:SetPoint('TOPLEFT', 10, 0)
		button.HighlightTexture:SetAtlas('auctionhouse-nav-button-secondary-highlight', false)
		button.HighlightTexture:SetSize(btnWidth - 10, btnHeight)
		button.HighlightTexture:ClearAllPoints()
		button.HighlightTexture:SetPoint('TOPLEFT', 10, 0)
		button.HighlightTexture:SetBlendMode('BLEND')
		button:SetText(info.name or '')
		normalText:ClearAllPoints()
		normalText:SetPoint('LEFT', button, 'LEFT', 18, 0)
		normalTexture:SetAlpha(1.0)
		line:Hide()
	elseif info.type == 'subSubCategory' then
		button:SetNormalFontObject(GameFontHighlightSmall)
		button.NormalTexture:ClearAllPoints()
		button.NormalTexture:SetPoint('TOPLEFT', 10, 0)
		button.SelectedTexture:SetAtlas('auctionhouse-ui-row-select', false)
		button.SelectedTexture:SetSize(btnWidth - 20, btnHeight - 3)
		button.SelectedTexture:ClearAllPoints()
		button.SelectedTexture:SetPoint('TOPRIGHT', 0, -2)
		button.HighlightTexture:SetAtlas('auctionhouse-ui-row-highlight', false)
		button.HighlightTexture:SetSize(btnWidth - 20, btnHeight - 3)
		button.HighlightTexture:ClearAllPoints()
		button.HighlightTexture:SetPoint('TOPRIGHT', 0, -2)
		button.HighlightTexture:SetBlendMode('ADD')
		button:SetText(info.name)
		normalText:SetPoint('LEFT', button, 'LEFT', 26, 0)
		normalTexture:SetAlpha(0.0)
		line:Show()
	end
	button.type = info.type

	if info.type == 'category' then
		button.categoryIndex = info.categoryIndex
	elseif info.type == 'subCategory' then
		button.subCategoryIndex = info.subCategoryIndex
	elseif info.type == 'subSubCategory' then
		button.subSubCategoryIndex = info.subSubCategoryIndex
	end

	button.SelectedTexture:SetShown(info.selected)
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

	-- Set up texture states
	button:SetNormalTexture('Interface\\AddOns\\SpartanUI\\images\\empty')
	button:SetHighlightTexture('Interface\\AddOns\\SpartanUI\\images\\empty')
	button:SetPushedTexture('Interface\\AddOns\\SpartanUI\\images\\empty')

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

---Create a search box using SearchBoxTemplate
---@param parent Frame Parent frame
---@param width number Search box width
---@param height? number Optional height (default 22)
---@return Frame searchBox Search box with clear button
function LibAT.UI.CreateSearchBox(parent, width, height)
	height = height or 22
	local searchBox = CreateFrame('EditBox', nil, parent, 'SearchBoxTemplate')
	searchBox:SetSize(width, height)
	searchBox:SetAutoFocus(false)
	return searchBox
end

---Create a standard EditBox
---@param parent Frame Parent frame
---@param width number EditBox width
---@param height number EditBox height
---@param multiline? boolean Optional multiline support (default false)
---@return EditBox editBox Standard edit box
function LibAT.UI.CreateEditBox(parent, width, height, multiline)
	local editBox = CreateFrame('EditBox', nil, parent, 'BackdropTemplate')
	editBox:SetSize(width, height)
	editBox:SetAutoFocus(false)
	editBox:SetFontObject('GameFontHighlight')
	editBox:SetTextInsets(4, 4, 2, 2)

	-- Add a subtle border so the field is visually identifiable
	editBox:SetBackdrop({
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	editBox:SetBackdropColor(0, 0, 0, 0.5)
	editBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

	if multiline then
		editBox:SetMultiLine(true)
	end

	return editBox
end

---@class LibAT.CheckboxContainer : Frame
---@field checkbox CheckButton The actual checkbox button
---@field Label FontString The label font string (if label provided)
---@field SetChecked fun(self: LibAT.CheckboxContainer, checked: boolean) Set checked state
---@field GetChecked fun(self: LibAT.CheckboxContainer): boolean Get checked state
---@field SetText fun(self: LibAT.CheckboxContainer, text: string) Set label text
---@field GetText fun(self: LibAT.CheckboxContainer): string Get label text
---@field SetEnabled fun(self: LibAT.CheckboxContainer, enabled: boolean) Enable/disable the checkbox
---@field HookScript fun(self: LibAT.CheckboxContainer, event: string, handler: function) Hook script on the checkbox
---@field SetScript fun(self: LibAT.CheckboxContainer, event: string, handler: function) Set script on the checkbox

---Create a checkbox with a container frame for proper positioning
---@param parent Frame Parent frame
---@param label? string Optional label text
---@param width? number Optional total width (default auto-calculated or 150)
---@param height? number Optional height (default 20)
---@return LibAT.CheckboxContainer container Container frame with checkbox and label
function LibAT.UI.CreateCheckbox(parent, label, width, height)
	height = height or 20

	-- Create container frame
	---@type LibAT.CheckboxContainer
	local container = CreateFrame('Frame', nil, parent)

	-- Create the actual checkbox inside container
	local checkbox = CreateFrame('CheckButton', nil, container, 'UICheckButtonTemplate')
	checkbox:SetSize(18, 18)
	checkbox:SetPoint('LEFT', container, 'LEFT', 0, 0)
	container.checkbox = checkbox

	-- Create label if provided
	if label then
		local labelText = container:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		labelText:SetText(label)
		labelText:SetPoint('LEFT', checkbox, 'RIGHT', 2, 0)
		labelText:SetTextColor(1, 1, 1)
		container.Label = labelText

		-- Calculate width if not provided
		if not width then
			local labelWidth = labelText:GetStringWidth()
			width = 18 + 2 + labelWidth + 4 -- checkbox + gap + label + padding
		end

		-- Set label to fill remaining space
		labelText:SetPoint('RIGHT', container, 'RIGHT', 0, 0)
	else
		width = width or 18
	end

	container:SetSize(width, height)

	-- Extend click detection to the entire container
	container:EnableMouse(true)
	container:SetScript('OnMouseDown', function()
		checkbox:Click()
	end)

	-- Passthrough methods to the container

	---Set checked state
	---@param checked boolean Whether the checkbox is checked
	function container:SetChecked(checked)
		self.checkbox:SetChecked(checked)
	end

	---Get checked state
	---@return boolean checked Whether the checkbox is checked
	function container:GetChecked()
		return self.checkbox:GetChecked()
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
		if enabled then
			self.checkbox:Enable()
			if self.Label then
				self.Label:SetTextColor(1, 1, 1)
			end
		else
			self.checkbox:Disable()
			if self.Label then
				self.Label:SetTextColor(0.5, 0.5, 0.5)
			end
		end
	end

	---Hook a script on the checkbox
	---@param event string Script event name
	---@param handler function Script handler
	function container:HookScript(event, handler)
		-- Wrap handler to pass container as self instead of the inner checkbox
		self.checkbox:HookScript(event, function(_, ...)
			handler(container, ...)
		end)
	end

	---Set a script on the checkbox
	---@param event string Script event name
	---@param handler function|nil Script handler
	function container:SetScript(event, handler)
		-- For OnClick and similar events, delegate to checkbox
		-- For frame events, keep on container
		if event == 'OnClick' or event == 'OnEnter' or event == 'OnLeave' then
			if handler then
				-- Wrap handler to pass container as self instead of the inner checkbox
				self.checkbox:SetScript(event, function(_, ...)
					handler(container, ...)
				end)
			else
				self.checkbox:SetScript(event, nil)
			end
		else
			-- Call the original Frame SetScript for container events
			getmetatable(self).__index.SetScript(self, event, handler)
		end
	end

	return container
end

---Create a dropdown button using WowStyle1FilterDropdownTemplate
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
	dropdown:SetText(text)
	return dropdown
end

----------------------------------------------------------------------------------------------------
-- Panel Components
----------------------------------------------------------------------------------------------------

---Create a panel with AuctionHouse styling and nine-slice border
---@param parent Frame Parent frame
---@param atlas string Atlas name for background (e.g., 'auctionhouse-background-summarylist')
---@return Frame panel Styled panel frame
function LibAT.UI.CreateStyledPanel(parent, atlas)
	local panel = CreateFrame('Frame', nil, parent)
	panel.layoutType = 'InsetFrameTemplate'

	-- Add AuctionHouse background
	panel.Background = panel:CreateTexture(nil, 'BACKGROUND')
	panel.Background:SetAtlas(atlas, true)
	panel.Background:SetAllPoints(panel)

	-- Add nine slice border
	panel.NineSlice = CreateFrame('Frame', nil, panel, 'NineSlicePanelTemplate')
	panel.NineSlice:SetAllPoints()

	return panel
end

---Create a scroll frame with MinimalScrollBar
---@param parent Frame Parent frame
---@return ScrollFrame scrollFrame Scroll frame with attached scrollbar
function LibAT.UI.CreateScrollFrame(parent)
	local scrollFrame = CreateFrame('ScrollFrame', nil, parent)

	-- Create minimal scrollbar
	scrollFrame.ScrollBar = CreateFrame('EventFrame', nil, scrollFrame, 'MinimalScrollBar')
	scrollFrame.ScrollBar:SetPoint('TOPLEFT', scrollFrame, 'TOPRIGHT', 2, 0)
	scrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', scrollFrame, 'BOTTOMRIGHT', 2, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollFrame.ScrollBar)

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
	editBox:SetFontObject('GameFontHighlight')
	editBox:SetAutoFocus(false)
	editBox:EnableMouse(true)
	editBox:SetTextColor(1, 1, 1)
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
		editBox:SetText(value or '')
	end

	---Get the text content
	---@return string text Current text
	function scrollFrame:GetValue()
		return editBox:GetText()
	end

	---Set read-only mode
	---@param readonly boolean True to make read-only
	function scrollFrame:SetReadOnly(readonly)
		editBox:SetEnabled(not readonly)
		if readonly then
			editBox:SetTextColor(0.7, 0.7, 0.7)
		else
			editBox:SetTextColor(1, 1, 1)
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

---Create a font string label
---@param parent Frame Parent frame
---@param text string Label text
---@param fontObject? string Optional font object name (default 'GameFontNormalSmall')
---@return FontString label Font string
function LibAT.UI.CreateLabel(parent, text, fontObject)
	fontObject = fontObject or 'GameFontNormalSmall'
	local label = parent:CreateFontString(nil, 'OVERLAY', fontObject)
	label:SetText(text)
	return label
end

---Create a header label (gold colored)
---@param parent Frame Parent frame
---@param text string Header text
---@return FontString header Header font string
function LibAT.UI.CreateHeader(parent, text)
	local header = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	header:SetText(text)
	header:SetTextColor(1, 0.82, 0) -- Gold color
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

return UI
