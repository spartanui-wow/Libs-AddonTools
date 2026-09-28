---@class LibAT
local LibAT = LibAT

-- DevUI Macros Tab: Full-size macro editor with account and character macro lists
-- Uses WoW Macro API: GetNumMacros, GetMacroInfo, EditMacro

LibAT.DevUI = LibAT.DevUI or {}

local DevUI, DevUIState

-- Forward declarations (must be before InitMacros so closures capture the locals)
local RebuildMacroList
local BuildContent
local FindMacroByName

-- Tab-local UI state
local TabState = {
	ContentFrame = nil,
	LeftPanel = nil,
	RightPanel = nil,
	MacroScrollFrame = nil,
	MacroTree = nil,
	NameBox = nil,
	IconTexture = nil,
	BodyBox = nil, -- Multiline editor ScrollFrame
	CharCountLabel = nil,
	DragButton = nil, -- Drag-to-actionbar button
	MacroButtons = {},
	CurrentMacroIndex = nil, -- Currently selected macro index
	CurrentMacroIcon = nil, -- Current macro icon fileID
}

-- WoW macro constants (defined in Blizzard_UIParent)
local ACCOUNT_MACRO_MAX = 120 -- MAX_ACCOUNT_MACROS
local CHARACTER_MACRO_OFFSET = ACCOUNT_MACRO_MAX -- Character macros start at index 121

---Initialize the Macros tab with shared state
---@param devUIModule table The DevUI module
---@param state table The DevUI shared state
function LibAT.DevUI.InitMacros(devUIModule, state)
	DevUI = devUIModule
	DevUIState = state

	-- Register this tab with DevUI
	DevUIState.TabModules[DevUIState.GetTabIndex('Macros')] = {
		BuildContent = BuildContent,
		OnActivate = function()
			RebuildMacroList()
		end,
	}

	-- Macros changed elsewhere (Blizzard's macro UI, other addons): follow the selection by name
	local watcher = CreateFrame('Frame')
	watcher:RegisterEvent('UPDATE_MACROS')
	watcher:SetScript('OnEvent', function()
		if not TabState.ContentFrame or not TabState.ContentFrame:IsVisible() then
			return
		end
		if TabState.CurrentMacroIndex then
			local index = FindMacroByName(TabState.CurrentMacroName)
			if index then
				TabState.CurrentMacroIndex = index
			else
				TabState.CurrentMacroIndex = nil
				TabState.CurrentMacroName = nil
			end
		end
		RebuildMacroList()
	end)
end

-- Additional forward declarations
local LoadMacro
local UpdateCharCount

----------------------------------------------------------------------------------------------------
-- Macro List Building
----------------------------------------------------------------------------------------------------

---Take a list button from the pool, creating it the first time
---@param index number
---@return Button
local function AcquireListButton(index)
	local button = TabState.MacroButtons[index]
	if not button then
		button = LibAT.UI.CreateFilterButton(TabState.MacroTree, nil)
		button.MacroIcon = button:CreateTexture(nil, 'ARTWORK')
		button.MacroIcon:SetSize(16, 16)
		button.MacroIcon:SetPoint('LEFT', button, 'LEFT', 12, 0)
		button:SetScript('OnEnter', function(self)
			self.HighlightTexture:Show()
		end)
		button:SetScript('OnLeave', function(self)
			self.HighlightTexture:Hide()
		end)
		button:SetScript('OnClick', function(self)
			if not self.macroIndex then
				return
			end
			for _, btn in ipairs(TabState.MacroButtons) do
				btn.SelectedTexture:Hide()
			end
			self.SelectedTexture:Show()
			LoadMacro(self.macroIndex)
		end)
		TabState.MacroButtons[index] = button
	end
	button:Show()
	return button
end

---Rebuild the macro list in the left panel
RebuildMacroList = function()
	if not TabState.MacroTree then
		return
	end

	local numGlobal, numPerChar = GetNumMacros()
	local yOffset = 0
	local buttonHeight = 21
	local used = 0

	local function AddHeader(label, key)
		used = used + 1
		local header = AcquireListButton(used)
		header:ClearAllPoints()
		header:SetPoint('TOPLEFT', TabState.MacroTree, 'TOPLEFT', 3, yOffset)
		LibAT.UI.SetupFilterButton(header, { type = 'category', name = label, categoryIndex = key, selected = false })
		header.Text:SetText(label)
		header.Text:SetTextColor(1, 0.82, 0)
		header.MacroIcon:Hide()
		header.macroIndex = nil
		yOffset = yOffset - (buttonHeight + 1)
	end

	local function AddMacro(macroIndex)
		local name, icon = GetMacroInfo(macroIndex)
		if not name then
			return
		end
		used = used + 1
		local button = AcquireListButton(used)
		button:ClearAllPoints()
		button:SetPoint('TOPLEFT', TabState.MacroTree, 'TOPLEFT', 3, yOffset)
		LibAT.UI.SetupFilterButton(button, {
			type = 'subCategory',
			name = '',
			subCategoryIndex = macroIndex,
			selected = (TabState.CurrentMacroIndex == macroIndex),
		})
		button.MacroIcon:SetTexture(icon)
		button.MacroIcon:Show()
		button.Text:ClearAllPoints()
		button.Text:SetPoint('LEFT', button, 'LEFT', 32, 0)
		button.Text:SetPoint('RIGHT', button, 'RIGHT', -4, 0)
		button.Text:SetJustifyH('LEFT')
		button.Text:SetText(name)
		button.Text:SetTextColor(1, 1, 1)
		button.macroIndex = macroIndex
		yOffset = yOffset - (buttonHeight + 1)
	end

	AddHeader('Account (' .. numGlobal .. ')', 'account')
	for i = 1, numGlobal do
		AddMacro(i)
	end

	AddHeader('Character (' .. numPerChar .. ')', 'character')
	for i = CHARACTER_MACRO_OFFSET + 1, CHARACTER_MACRO_OFFSET + numPerChar do
		AddMacro(i)
	end

	for i = used + 1, #TabState.MacroButtons do
		TabState.MacroButtons[i]:Hide()
	end

	local totalHeight = math.abs(yOffset) + 20
	TabState.MacroTree:SetHeight(math.max(totalHeight, TabState.MacroScrollFrame:GetHeight()))
end

---Find a macro index by name (indexes shift when macros are renamed, created or deleted)
---@param name string
---@return number|nil
FindMacroByName = function(name)
	if not name then
		return nil
	end
	local index = GetMacroIndexByName(name)
	if index and index > 0 then
		return index
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- Macro Load/Save
----------------------------------------------------------------------------------------------------

---Load a macro into the editor
---@param macroIndex number The macro index to load
LoadMacro = function(macroIndex)
	local name, icon, body = GetMacroInfo(macroIndex)
	if not name then
		return
	end

	TabState.CurrentMacroIndex = macroIndex
	TabState.CurrentMacroName = name
	TabState.CurrentMacroIcon = icon
	TabState.IconChanged = false

	if TabState.NameBox then
		TabState.NameBox:SetText(name)
	end
	if TabState.IconTexture then
		TabState.IconTexture:SetTexture(icon)
	end
	if TabState.BodyBox then
		TabState.BodyBox:SetValue(body or '')
	end
	if TabState.DragButton then
		TabState.DragButton:SetNormalTexture(icon)
		TabState.DragButton:Show()
	end

	UpdateCharCount()
end

---Update the character count display
UpdateCharCount = function()
	if not TabState.CharCountLabel or not TabState.BodyBox then
		return
	end

	local body = TabState.BodyBox:GetValue()
	local charCount = #body
	local maxChars = 255

	if charCount > maxChars then
		TabState.CharCountLabel:SetText('|cffff0000' .. charCount .. '/' .. maxChars .. '|r')
	elseif charCount > maxChars * 0.9 then
		TabState.CharCountLabel:SetText('|cffffff00' .. charCount .. '/' .. maxChars .. '|r')
	else
		TabState.CharCountLabel:SetText(charCount .. '/' .. maxChars)
	end
end

---Save the current macro
local function SaveCurrentMacro()
	if not TabState.CurrentMacroIndex then
		return
	end

	if InCombatLockdown() then
		if TabState.CharCountLabel then
			TabState.CharCountLabel:SetText('|cffff0000Cannot save in combat!|r')
		end
		return
	end

	-- Macro names cannot contain quotes; an empty name keeps the current one
	local name = TabState.NameBox and TabState.NameBox:GetText() or ''
	name = strtrim((name:gsub('"', '')))
	if name == '' then
		name = nil
	end
	local body = TabState.BodyBox and TabState.BodyBox:GetValue() or nil
	-- Passing the displayed icon back would freeze dynamic (#showtooltip) icons; only send a picked one
	local icon = TabState.IconChanged and TabState.CurrentMacroIcon or nil

	local success, result = pcall(EditMacro, TabState.CurrentMacroIndex, name, icon, body)
	local err = result

	if success then
		-- Renaming re-sorts the list, so the macro may now live at a different index
		if type(result) == 'number' and result > 0 then
			TabState.CurrentMacroIndex = result
		end
		TabState.CurrentMacroName = name or TabState.CurrentMacroName
		TabState.IconChanged = false
		if TabState.CharCountLabel then
			TabState.CharCountLabel:SetText('|cff00ff00Saved!|r')
			C_Timer.After(2, UpdateCharCount) -- Restore char count after 2s
		end
		RebuildMacroList()
	else
		if TabState.CharCountLabel then
			TabState.CharCountLabel:SetText('|cffff0000Save failed: ' .. tostring(err) .. '|r')
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Content Builder
----------------------------------------------------------------------------------------------------

---Build the Macros tab content
---@param contentFrame Frame The parent content frame from DevUI
BuildContent = function(contentFrame)
	TabState.ContentFrame = contentFrame

	-- Main content area (no control frame needed)
	local mainContent = CreateFrame('Frame', nil, contentFrame)
	mainContent:SetPoint('TOPLEFT', contentFrame, 'TOPLEFT', 0, -4)
	mainContent:SetPoint('BOTTOMRIGHT', contentFrame, 'BOTTOMRIGHT', 0, 15)

	-- Left panel: Macro list (shortened to leave room for drag button below)
	TabState.LeftPanel = LibAT.UI.CreateLeftPanel(mainContent, nil, nil, nil, 63)

	-- Macro scroll frame
	TabState.MacroScrollFrame = CreateFrame('ScrollFrame', nil, TabState.LeftPanel)
	TabState.MacroScrollFrame:SetPoint('TOPLEFT', TabState.LeftPanel, 'TOPLEFT', 2, -7)
	TabState.MacroScrollFrame:SetPoint('BOTTOMRIGHT', TabState.LeftPanel, 'BOTTOMRIGHT', 0, 2)

	TabState.MacroScrollFrame.ScrollBar = CreateFrame('EventFrame', nil, TabState.MacroScrollFrame, 'MinimalScrollBar')
	TabState.MacroScrollFrame.ScrollBar:SetPoint('TOPLEFT', TabState.MacroScrollFrame, 'TOPRIGHT', 6, 0)
	TabState.MacroScrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', TabState.MacroScrollFrame, 'BOTTOMRIGHT', 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(TabState.MacroScrollFrame, TabState.MacroScrollFrame.ScrollBar)

	TabState.MacroTree = CreateFrame('Frame', nil, TabState.MacroScrollFrame)
	TabState.MacroScrollFrame:SetScrollChild(TabState.MacroTree)
	TabState.MacroTree:SetSize(160, 1)

	-- Right panel: Macro editor
	TabState.RightPanel = LibAT.UI.CreateRightPanel(mainContent, TabState.LeftPanel)

	-- Name row: clickable icon + name editbox
	local iconButton = CreateFrame('Button', nil, TabState.RightPanel)
	iconButton:SetSize(32, 32)
	iconButton:SetPoint('TOPLEFT', TabState.RightPanel, 'TOPLEFT', 8, -8)
	TabState.IconTexture = iconButton:CreateTexture(nil, 'ARTWORK')
	TabState.IconTexture:SetAllPoints()
	TabState.IconTexture:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark')
	iconButton:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')
	iconButton:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetText('Change Icon')
		GameTooltip:AddLine('Click to browse icons', 1, 1, 1, true)
		GameTooltip:Show()
	end)
	iconButton:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)
	iconButton:SetScript('OnClick', function()
		if not LibAT_MacroIconSelector then
			return
		end

		-- Pass current icon so the browser can pre-select it
		LibAT_MacroIconSelector.currentIcon = TabState.CurrentMacroIcon

		-- Set callback to apply the selected icon back to the editor
		LibAT_MacroIconSelector.onIconSelected = function(iconTexture)
			TabState.CurrentMacroIcon = iconTexture
			TabState.IconChanged = true
			TabState.IconTexture:SetTexture(iconTexture)
		end

		-- Position beside the DevUI window and show
		LibAT_MacroIconSelector:ClearAllPoints()
		if DevUIState.Window then
			LibAT_MacroIconSelector:SetPoint('TOPLEFT', DevUIState.Window, 'TOPRIGHT', 5, 0)
		else
			LibAT_MacroIconSelector:SetPoint('CENTER')
		end
		LibAT_MacroIconSelector:Show()
	end)

	local nameLabel = TabState.RightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	nameLabel:SetPoint('LEFT', iconButton, 'RIGHT', 8, 0)
	nameLabel:SetText('Name:')
	nameLabel:SetTextColor(1, 0.82, 0)

	local saveButton = LibAT.UI.CreateButton(TabState.RightPanel, 70, 22, 'Save')
	saveButton:SetPoint('RIGHT', TabState.RightPanel, 'RIGHT', -8, 0)
	saveButton:SetPoint('TOP', iconButton, 'TOP', 0, 0)
	saveButton:SetScript('OnClick', function()
		SaveCurrentMacro()
	end)

	TabState.NameBox = CreateFrame('EditBox', nil, TabState.RightPanel, 'InputBoxTemplate')
	TabState.NameBox:SetHeight(22)
	TabState.NameBox:SetPoint('LEFT', nameLabel, 'RIGHT', 6, 0)
	TabState.NameBox:SetPoint('RIGHT', saveButton, 'LEFT', -6, 0)
	TabState.NameBox:SetAutoFocus(false)
	TabState.NameBox:SetFontObject('GameFontHighlight')
	TabState.NameBox:SetMaxLetters(16)
	TabState.NameBox:SetScript('OnEnterPressed', function(self)
		self:ClearFocus()
		SaveCurrentMacro()
		if TabState.BodyBox and TabState.BodyBox.editBox then
			TabState.BodyBox.editBox:SetFocus()
		end
	end)

	-- Macro body editor (fills most of the space)
	local bodyLabel = TabState.RightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	bodyLabel:SetPoint('TOPLEFT', iconButton, 'BOTTOMLEFT', 0, -8)
	bodyLabel:SetText('Macro Body:')
	bodyLabel:SetTextColor(1, 0.82, 0)

	TabState.BodyBox = LibAT.UI.CreateMultiLineBox(TabState.RightPanel, 100, 100) -- Size via anchors
	TabState.BodyBox:SetPoint('TOPLEFT', bodyLabel, 'BOTTOMLEFT', 0, -4)
	TabState.BodyBox:SetPoint('RIGHT', TabState.RightPanel, 'RIGHT', -28, 0)
	TabState.BodyBox:SetPoint('BOTTOM', TabState.RightPanel, 'BOTTOM', 0, 20)

	-- Add background to macro body editor
	Mixin(TabState.BodyBox, BackdropTemplateMixin)
	TabState.BodyBox:SetBackdrop({
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	TabState.BodyBox:SetBackdropColor(0, 0, 0, 0.5)
	TabState.BodyBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

	-- Set monospace font
	if DevUIState.MonoFont and TabState.BodyBox.editBox then
		TabState.BodyBox.editBox:SetFontObject(DevUIState.MonoFont)
	end

	-- Track text changes for character count
	if TabState.BodyBox.editBox then
		TabState.BodyBox.editBox:HookScript('OnTextChanged', function()
			UpdateCharCount()
		end)
	end

	-- Character count (centered below the body editor)
	TabState.CharCountLabel = TabState.RightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	TabState.CharCountLabel:SetPoint('TOP', TabState.BodyBox, 'BOTTOM', 0, -2)
	TabState.CharCountLabel:SetText('0/255')
	TabState.CharCountLabel:SetTextColor(1, 1, 1)
	TabState.CharCountLabel:SetJustifyH('CENTER')

	-- Drag-to-actionbar area (below the left panel, above reload button)
	TabState.DragButton = CreateFrame('Button', 'LibAT_MacroDragButton', mainContent)
	TabState.DragButton:SetSize(32, 32)
	TabState.DragButton:SetPoint('TOPLEFT', TabState.LeftPanel, 'BOTTOMLEFT', 8, -6)
	TabState.DragButton:RegisterForDrag('LeftButton')
	TabState.DragButton:Hide() -- Hidden until a macro is selected

	-- Icon (use NormalTexture so it always renders visibly)
	TabState.DragButton:SetNormalTexture('Interface\\Icons\\INV_Misc_QuestionMark')

	-- Highlight on hover
	TabState.DragButton:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square')

	-- Label to the right of the icon
	local dragLabel = mainContent:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	dragLabel:SetPoint('LEFT', TabState.DragButton, 'RIGHT', 6, 0)
	dragLabel:SetText('Drag to\naction bars')
	dragLabel:SetJustifyH('LEFT')
	dragLabel:SetTextColor(0.6, 0.6, 0.6)

	-- Drag starts PickupMacro (hardware-initiated, so protected API is allowed)
	TabState.DragButton:SetScript('OnDragStart', function()
		if TabState.CurrentMacroIndex and not InCombatLockdown() then
			PickupMacro(TabState.CurrentMacroIndex)
		end
	end)

	-- Tooltip
	TabState.DragButton:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetText('Drag to Action Bar')
		GameTooltip:AddLine('Drag this icon to place the macro on your action bars.', 1, 1, 1, true)
		GameTooltip:Show()
	end)
	TabState.DragButton:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	-- Reload UI button
	local reloadButton = LibAT.UI.CreateButton(contentFrame, 80, 20, 'Reload UI', true)
	reloadButton:SetPoint('BOTTOMLEFT', contentFrame, 'BOTTOMLEFT', 4, 1)
	reloadButton:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)

	-- Show placeholder text
	if TabState.BodyBox then
		TabState.BodyBox:SetValue('')
	end
end
