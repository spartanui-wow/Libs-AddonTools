---@class LibAT
local LibAT = LibAT

-- DevUI Macros Tab: Full-size macro editor with account and character macro lists
-- Uses WoW Macro API: GetNumMacros, GetMacroInfo, EditMacro

LibAT.DevUI = LibAT.DevUI or {}

local DevUI, DevUIState

-- Forward declarations (must be before InitMacros so closures capture the locals)
local RebuildMacroList
local BuildContent

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
	DevUIState.TabModules[4] = {
		BuildContent = BuildContent,
		OnActivate = function()
			RebuildMacroList()
		end,
	}
end

-- Additional forward declarations
local LoadMacro
local UpdateCharCount

----------------------------------------------------------------------------------------------------
-- Macro List Building
----------------------------------------------------------------------------------------------------

---Rebuild the macro list in the left panel
RebuildMacroList = function()
	-- Clear existing buttons
	for _, button in pairs(TabState.MacroButtons) do
		button:Hide()
		button:SetParent(nil)
	end
	TabState.MacroButtons = {}

	if not TabState.MacroTree then
		return
	end

	local numGlobal, numPerChar = GetNumMacros()
	local yOffset = 0
	local buttonHeight = 21

	-- Account Macros header
	local accountHeader = LibAT.UI.CreateFilterButton(TabState.MacroTree, nil)
	accountHeader:SetPoint('TOPLEFT', TabState.MacroTree, 'TOPLEFT', 3, yOffset)
	LibAT.UI.SetupFilterButton(accountHeader, {
		type = 'category',
		name = 'Account (' .. numGlobal .. ')',
		categoryIndex = 'account',
		selected = false,
	})
	accountHeader.Text:SetTextColor(1, 0.82, 0)
	accountHeader:SetScript('OnEnter', function(self)
		self.HighlightTexture:Show()
	end)
	accountHeader:SetScript('OnLeave', function(self)
		self.HighlightTexture:Hide()
	end)
	table.insert(TabState.MacroButtons, accountHeader)
	yOffset = yOffset - (buttonHeight + 1)

	-- Account macro entries
	for i = 1, numGlobal do
		local name, icon, body = GetMacroInfo(i)
		if name then
			local macroButton = LibAT.UI.CreateFilterButton(TabState.MacroTree, nil)
			macroButton:SetPoint('TOPLEFT', TabState.MacroTree, 'TOPLEFT', 3, yOffset)

			LibAT.UI.SetupFilterButton(macroButton, {
				type = 'subCategory',
				name = '  ' .. name,
				subCategoryIndex = i,
				selected = (TabState.CurrentMacroIndex == i),
			})

			-- Add icon texture to the button
			local iconTexture = macroButton:CreateTexture(nil, 'ARTWORK')
			iconTexture:SetSize(16, 16)
			iconTexture:SetPoint('LEFT', macroButton, 'LEFT', 12, 0)
			iconTexture:SetTexture(icon)
			-- Shift text right for icon
			macroButton.Text:ClearAllPoints()
			macroButton.Text:SetPoint('LEFT', macroButton, 'LEFT', 32, 0)
			macroButton.Text:SetPoint('RIGHT', macroButton, 'RIGHT', -4, 0)
			macroButton.Text:SetJustifyH('LEFT')
			macroButton.Text:SetText(name)

			local macroIndex = i
			macroButton:SetScript('OnClick', function(self)
				for _, btn in pairs(TabState.MacroButtons) do
					btn.SelectedTexture:Hide()
				end
				self.SelectedTexture:Show()
				LoadMacro(macroIndex)
			end)

			macroButton:SetScript('OnEnter', function(self)
				self.HighlightTexture:Show()
			end)
			macroButton:SetScript('OnLeave', function(self)
				self.HighlightTexture:Hide()
			end)

			table.insert(TabState.MacroButtons, macroButton)
			yOffset = yOffset - (buttonHeight + 1)
		end
	end

	-- Character Macros header
	local charHeader = LibAT.UI.CreateFilterButton(TabState.MacroTree, nil)
	charHeader:SetPoint('TOPLEFT', TabState.MacroTree, 'TOPLEFT', 3, yOffset)
	LibAT.UI.SetupFilterButton(charHeader, {
		type = 'category',
		name = 'Character (' .. numPerChar .. ')',
		categoryIndex = 'character',
		selected = false,
	})
	charHeader.Text:SetTextColor(1, 0.82, 0)
	charHeader:SetScript('OnEnter', function(self)
		self.HighlightTexture:Show()
	end)
	charHeader:SetScript('OnLeave', function(self)
		self.HighlightTexture:Hide()
	end)
	table.insert(TabState.MacroButtons, charHeader)
	yOffset = yOffset - (buttonHeight + 1)

	-- Character macro entries
	for i = CHARACTER_MACRO_OFFSET + 1, CHARACTER_MACRO_OFFSET + numPerChar do
		local name, icon, body = GetMacroInfo(i)
		if name then
			local macroButton = LibAT.UI.CreateFilterButton(TabState.MacroTree, nil)
			macroButton:SetPoint('TOPLEFT', TabState.MacroTree, 'TOPLEFT', 3, yOffset)

			LibAT.UI.SetupFilterButton(macroButton, {
				type = 'subCategory',
				name = '  ' .. name,
				subCategoryIndex = i,
				selected = (TabState.CurrentMacroIndex == i),
			})

			-- Add icon texture
			local iconTexture = macroButton:CreateTexture(nil, 'ARTWORK')
			iconTexture:SetSize(16, 16)
			iconTexture:SetPoint('LEFT', macroButton, 'LEFT', 12, 0)
			iconTexture:SetTexture(icon)
			macroButton.Text:ClearAllPoints()
			macroButton.Text:SetPoint('LEFT', macroButton, 'LEFT', 32, 0)
			macroButton.Text:SetPoint('RIGHT', macroButton, 'RIGHT', -4, 0)
			macroButton.Text:SetJustifyH('LEFT')
			macroButton.Text:SetText(name)

			local macroIndex = i
			macroButton:SetScript('OnClick', function(self)
				for _, btn in pairs(TabState.MacroButtons) do
					btn.SelectedTexture:Hide()
				end
				self.SelectedTexture:Show()
				LoadMacro(macroIndex)
			end)

			macroButton:SetScript('OnEnter', function(self)
				self.HighlightTexture:Show()
			end)
			macroButton:SetScript('OnLeave', function(self)
				self.HighlightTexture:Hide()
			end)

			table.insert(TabState.MacroButtons, macroButton)
			yOffset = yOffset - (buttonHeight + 1)
		end
	end

	-- Update tree height
	local totalHeight = math.abs(yOffset) + 20
	TabState.MacroTree:SetHeight(math.max(totalHeight, TabState.MacroScrollFrame:GetHeight()))
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
	TabState.CurrentMacroIcon = icon

	if TabState.NameBox then
		TabState.NameBox:SetText(name)
	end
	if TabState.IconTexture then
		TabState.IconTexture:SetTexture(icon)
	end
	if TabState.BodyBox then
		TabState.BodyBox:SetValue(body or '')
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

	local name = TabState.NameBox and TabState.NameBox:GetText() or nil
	local body = TabState.BodyBox and TabState.BodyBox:GetValue() or nil

	local success, err = pcall(function()
		EditMacro(TabState.CurrentMacroIndex, name, TabState.CurrentMacroIcon, body)
	end)

	if success then
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
	mainContent:SetPoint('BOTTOMRIGHT', contentFrame, 'BOTTOMRIGHT', 0, 0)

	-- Left panel: Macro list
	TabState.LeftPanel = LibAT.UI.CreateLeftPanel(mainContent)

	-- Macro scroll frame
	TabState.MacroScrollFrame = CreateFrame('ScrollFrame', nil, TabState.LeftPanel)
	TabState.MacroScrollFrame:SetPoint('TOPLEFT', TabState.LeftPanel, 'TOPLEFT', 2, -7)
	TabState.MacroScrollFrame:SetPoint('BOTTOMRIGHT', TabState.LeftPanel, 'BOTTOMRIGHT', 0, 2)

	TabState.MacroScrollFrame.ScrollBar = CreateFrame('EventFrame', nil, TabState.MacroScrollFrame, 'MinimalScrollBar')
	TabState.MacroScrollFrame.ScrollBar:SetPoint('TOPLEFT', TabState.MacroScrollFrame, 'TOPRIGHT', 2, 0)
	TabState.MacroScrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', TabState.MacroScrollFrame, 'BOTTOMRIGHT', 2, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(TabState.MacroScrollFrame, TabState.MacroScrollFrame.ScrollBar)

	TabState.MacroTree = CreateFrame('Frame', nil, TabState.MacroScrollFrame)
	TabState.MacroScrollFrame:SetScrollChild(TabState.MacroTree)
	TabState.MacroTree:SetSize(160, 1)

	-- Right panel: Macro editor
	TabState.RightPanel = LibAT.UI.CreateRightPanel(mainContent, TabState.LeftPanel)

	-- Name row: icon + name editbox
	TabState.IconTexture = TabState.RightPanel:CreateTexture(nil, 'ARTWORK')
	TabState.IconTexture:SetSize(32, 32)
	TabState.IconTexture:SetPoint('TOPLEFT', TabState.RightPanel, 'TOPLEFT', 8, -8)
	TabState.IconTexture:SetTexture('Interface\\Icons\\INV_Misc_QuestionMark')

	local nameLabel = TabState.RightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	nameLabel:SetPoint('LEFT', TabState.IconTexture, 'RIGHT', 8, 0)
	nameLabel:SetText('Name:')
	nameLabel:SetTextColor(1, 0.82, 0)

	TabState.NameBox = CreateFrame('EditBox', nil, TabState.RightPanel, 'InputBoxTemplate')
	TabState.NameBox:SetHeight(22)
	TabState.NameBox:SetPoint('LEFT', nameLabel, 'RIGHT', 6, 0)
	TabState.NameBox:SetPoint('RIGHT', TabState.RightPanel, 'RIGHT', -8, 0)
	TabState.NameBox:SetAutoFocus(false)
	TabState.NameBox:SetFontObject('GameFontHighlight')

	-- Macro body editor (fills most of the space)
	local bodyLabel = TabState.RightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	bodyLabel:SetPoint('TOPLEFT', TabState.IconTexture, 'BOTTOMLEFT', 0, -8)
	bodyLabel:SetText('Macro Body:')
	bodyLabel:SetTextColor(1, 0.82, 0)

	TabState.BodyBox = LibAT.UI.CreateMultiLineBox(TabState.RightPanel, 100, 100) -- Size via anchors
	TabState.BodyBox:SetPoint('TOPLEFT', bodyLabel, 'BOTTOMLEFT', 0, -4)
	TabState.BodyBox:SetPoint('RIGHT', TabState.RightPanel, 'RIGHT', -8, 0)
	TabState.BodyBox:SetPoint('BOTTOM', TabState.RightPanel, 'BOTTOM', 0, 40)

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

	-- Bottom bar: char count + save button
	TabState.CharCountLabel = TabState.RightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	TabState.CharCountLabel:SetPoint('BOTTOMLEFT', TabState.RightPanel, 'BOTTOMLEFT', 8, 12)
	TabState.CharCountLabel:SetText('0/255')
	TabState.CharCountLabel:SetTextColor(1, 1, 1)

	local saveButton = LibAT.UI.CreateButton(TabState.RightPanel, 70, 22, 'Save')
	saveButton:SetPoint('BOTTOMRIGHT', TabState.RightPanel, 'BOTTOMRIGHT', -8, 8)
	saveButton:SetScript('OnClick', function()
		SaveCurrentMacro()
	end)

	-- Reload UI button
	local reloadButton = LibAT.UI.CreateButton(contentFrame, 80, 22, 'Reload UI')
	reloadButton:SetPoint('BOTTOMLEFT', contentFrame, 'BOTTOMLEFT', 3, 4)
	reloadButton:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)

	-- Show placeholder text
	if TabState.BodyBox then
		TabState.BodyBox:SetValue('')
	end
end
