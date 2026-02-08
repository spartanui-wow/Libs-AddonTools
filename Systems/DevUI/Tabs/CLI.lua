---@class LibAT
local LibAT = LibAT

-- DevUI CLI Tab: Lua console with script editor, execution, and saved scripts

LibAT.DevUI = LibAT.DevUI or {}

local DevUI, DevUIState

-- Forward declarations (must be before InitCLI so closures capture the locals)
local RebuildScriptList
local BuildContent

-- Tab-local UI state
local TabState = {
	ContentFrame = nil,
	LeftPanel = nil,
	TitleBox = nil,
	EditorBox = nil, -- The multiline code editor ScrollFrame
	ResultsBox = nil, -- The read-only results ScrollFrame
	ScriptButtons = {},
	ActiveScript = nil, -- Currently loaded script title
}

---Initialize the CLI tab with shared state
---@param devUIModule table The DevUI module
---@param state table The DevUI shared state
function LibAT.DevUI.InitCLI(devUIModule, state)
	DevUI = devUIModule
	DevUIState = state

	-- Register this tab with DevUI
	DevUIState.TabModules[2] = {
		BuildContent = BuildContent,
		OnActivate = function()
			RebuildScriptList()
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- Script Execution
----------------------------------------------------------------------------------------------------

---Execute Lua code and capture output
---@param code string The Lua code to execute
---@return string output The captured output text
local function ExecuteCode(code)
	if not code or code == '' then
		return '|cffff0000No code to execute.|r'
	end

	local output = {}
	local oldPrint = print

	-- Redirect print to capture output
	print = function(...)
		local parts = {}
		for i = 1, select('#', ...) do
			parts[i] = tostring(select(i, ...))
		end
		table.insert(output, table.concat(parts, '\t'))
	end

	-- Support "= expression" shorthand (auto-print)
	local evalCode = code:gsub('^%s*=%s*(.+)', 'print(%1)')

	-- Compile
	local func, err = loadstring(evalCode)
	if func then
		local success, execErr = pcall(func)
		if not success then
			table.insert(output, '|cffff0000Runtime Error: ' .. tostring(execErr) .. '|r')
		end
	else
		table.insert(output, '|cffff0000Syntax Error: ' .. tostring(err) .. '|r')
	end

	-- Restore print
	print = oldPrint

	if #output == 0 then
		return '|cff888888(no output)|r'
	end

	return table.concat(output, '\n')
end

----------------------------------------------------------------------------------------------------
-- Saved Scripts Management
----------------------------------------------------------------------------------------------------

---Rebuild the saved scripts list in the left panel
RebuildScriptList = function()
	-- Clear existing buttons
	for _, button in pairs(TabState.ScriptButtons) do
		button:Hide()
		button:SetParent(nil)
	end
	TabState.ScriptButtons = {}

	if not TabState.ScriptTree or not DevUI.DB then
		return
	end

	local yOffset = 0
	local buttonHeight = 21

	-- Sort script names alphabetically
	local scriptNames = {}
	for name, _ in pairs(DevUI.DB.cli.savedScripts) do
		table.insert(scriptNames, name)
	end
	table.sort(scriptNames)

	for _, scriptName in ipairs(scriptNames) do
		local button = LibAT.UI.CreateFilterButton(TabState.ScriptTree, nil)
		button:SetPoint('TOPLEFT', TabState.ScriptTree, 'TOPLEFT', 3, yOffset)

		LibAT.UI.SetupFilterButton(button, {
			type = 'subCategory',
			name = scriptName,
			subCategoryIndex = scriptName,
			selected = (TabState.ActiveScript == scriptName),
		})

		button:SetScript('OnEnter', function(self)
			self.HighlightTexture:Show()
		end)
		button:SetScript('OnLeave', function(self)
			self.HighlightTexture:Hide()
		end)

		button:SetScript('OnClick', function(self)
			-- Clear all selections
			for _, btn in pairs(TabState.ScriptButtons) do
				btn.SelectedTexture:Hide()
				btn:SetNormalFontObject(GameFontHighlightSmall)
			end
			-- Select this one
			self.SelectedTexture:Show()
			self:SetNormalFontObject(GameFontNormalSmall)

			-- Load script into editor
			TabState.ActiveScript = scriptName
			local body = DevUI.DB.cli.savedScripts[scriptName]
			if TabState.TitleBox then
				TabState.TitleBox:SetText(scriptName)
			end
			if TabState.EditorBox then
				TabState.EditorBox:SetValue(body or '')
			end
		end)

		table.insert(TabState.ScriptButtons, button)
		yOffset = yOffset - (buttonHeight + 1)
	end

	-- Update tree height
	local totalHeight = math.abs(yOffset) + 20
	TabState.ScriptTree:SetHeight(math.max(totalHeight, TabState.ScriptScrollFrame:GetHeight()))
end

---Save the current script to the database
local function SaveCurrentScript()
	if not DevUI.DB or not TabState.TitleBox or not TabState.EditorBox then
		return
	end

	local title = TabState.TitleBox:GetText()
	if not title or title == '' then
		title = 'Untitled ' .. date('%H:%M:%S')
		TabState.TitleBox:SetText(title)
	end

	local body = TabState.EditorBox:GetValue()
	DevUI.DB.cli.savedScripts[title] = body
	DevUI.DB.cli.lastScript = title
	TabState.ActiveScript = title

	RebuildScriptList()
end

---Delete the currently loaded script
local function DeleteCurrentScript()
	if not DevUI.DB or not TabState.ActiveScript then
		return
	end

	DevUI.DB.cli.savedScripts[TabState.ActiveScript] = nil
	if DevUI.DB.cli.lastScript == TabState.ActiveScript then
		DevUI.DB.cli.lastScript = nil
	end
	TabState.ActiveScript = nil

	if TabState.TitleBox then
		TabState.TitleBox:SetText('')
	end
	if TabState.EditorBox then
		TabState.EditorBox:SetValue('')
	end

	RebuildScriptList()
end

----------------------------------------------------------------------------------------------------
-- Content Builder
----------------------------------------------------------------------------------------------------

---Build the CLI tab content
---@param contentFrame Frame The parent content frame from DevUI
BuildContent = function(contentFrame)
	TabState.ContentFrame = contentFrame

	-- Main content area (skip control frame — CLI doesn't need search/filters)
	local mainContent = CreateFrame('Frame', nil, contentFrame)
	mainContent:SetPoint('TOPLEFT', contentFrame, 'TOPLEFT', 0, -4)
	mainContent:SetPoint('BOTTOMRIGHT', contentFrame, 'BOTTOMRIGHT', 0, 0)

	-- Left panel: Saved scripts
	TabState.LeftPanel = LibAT.UI.CreateLeftPanel(mainContent)

	-- "Saved Scripts" header
	local header = TabState.LeftPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	header:SetPoint('TOP', TabState.LeftPanel, 'TOP', 0, -4)
	header:SetText('Saved Scripts')
	header:SetTextColor(1, 0.82, 0)

	-- Script scroll frame
	TabState.ScriptScrollFrame = CreateFrame('ScrollFrame', nil, TabState.LeftPanel)
	TabState.ScriptScrollFrame:SetPoint('TOPLEFT', TabState.LeftPanel, 'TOPLEFT', 2, -22)
	TabState.ScriptScrollFrame:SetPoint('BOTTOMRIGHT', TabState.LeftPanel, 'BOTTOMRIGHT', 0, 2)

	TabState.ScriptScrollFrame.ScrollBar = CreateFrame('EventFrame', nil, TabState.ScriptScrollFrame, 'MinimalScrollBar')
	TabState.ScriptScrollFrame.ScrollBar:SetPoint('TOPLEFT', TabState.ScriptScrollFrame, 'TOPRIGHT', 2, 0)
	TabState.ScriptScrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', TabState.ScriptScrollFrame, 'BOTTOMRIGHT', 2, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(TabState.ScriptScrollFrame, TabState.ScriptScrollFrame.ScrollBar)

	TabState.ScriptTree = CreateFrame('Frame', nil, TabState.ScriptScrollFrame)
	TabState.ScriptScrollFrame:SetScrollChild(TabState.ScriptTree)
	TabState.ScriptTree:SetSize(160, 1)

	-- Right panel
	local rightPanel = LibAT.UI.CreateRightPanel(mainContent, TabState.LeftPanel)

	-- Title bar at top of right panel
	local titleLabel = rightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	titleLabel:SetPoint('TOPLEFT', rightPanel, 'TOPLEFT', 8, -8)
	titleLabel:SetText('Script Name:')
	titleLabel:SetTextColor(1, 0.82, 0)

	TabState.TitleBox = CreateFrame('EditBox', nil, rightPanel, 'InputBoxTemplate')
	TabState.TitleBox:SetSize(rightPanel:GetWidth() - 110 > 0 and rightPanel:GetWidth() - 110 or 400, 22)
	TabState.TitleBox:SetPoint('LEFT', titleLabel, 'RIGHT', 6, 0)
	TabState.TitleBox:SetPoint('RIGHT', rightPanel, 'RIGHT', -8, 0)
	TabState.TitleBox:SetAutoFocus(false)
	TabState.TitleBox:SetFontObject('GameFontHighlight')

	-- Code editor area (top ~55% of remaining space)
	local editorLabel = rightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	editorLabel:SetPoint('TOPLEFT', titleLabel, 'BOTTOMLEFT', 0, -8)
	editorLabel:SetText('Code:')
	editorLabel:SetTextColor(1, 0.82, 0)

	-- Create editor with monospace font
	TabState.EditorBox = LibAT.UI.CreateMultiLineBox(rightPanel, 100, 100) -- Size set by anchors
	TabState.EditorBox:SetPoint('TOPLEFT', editorLabel, 'BOTTOMLEFT', 0, -4)
	TabState.EditorBox:SetPoint('RIGHT', rightPanel, 'RIGHT', -8, 0)

	-- Add background to editor
	Mixin(TabState.EditorBox, BackdropTemplateMixin)
	TabState.EditorBox:SetBackdrop({
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	TabState.EditorBox:SetBackdropColor(0, 0, 0, 0.5)
	TabState.EditorBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

	-- Set monospace font on the editor's EditBox
	if DevUIState.MonoFont and TabState.EditorBox.editBox then
		TabState.EditorBox.editBox:SetFontObject(DevUIState.MonoFont)
	end

	-- Button bar
	local buttonBar = CreateFrame('Frame', nil, rightPanel)
	buttonBar:SetHeight(28)

	local runButton = LibAT.UI.CreateButton(buttonBar, 70, 22, 'Run', true)
	runButton:SetPoint('LEFT', buttonBar, 'LEFT', 0, 0)
	runButton:SetScript('OnClick', function()
		if TabState.EditorBox and TabState.ResultsBox then
			local code = TabState.EditorBox:GetValue()
			local result = ExecuteCode(code)
			TabState.ResultsBox:SetValue(result)
		end
	end)

	local saveButton = LibAT.UI.CreateButton(buttonBar, 70, 22, 'Save', true)
	saveButton:SetPoint('LEFT', runButton, 'RIGHT', 5, 0)
	saveButton:SetScript('OnClick', function()
		SaveCurrentScript()
	end)

	local deleteButton = LibAT.UI.CreateButton(buttonBar, 70, 22, 'Delete', true)
	deleteButton:SetPoint('LEFT', saveButton, 'RIGHT', 5, 0)
	deleteButton:SetScript('OnClick', function()
		DeleteCurrentScript()
	end)

	local clearOutputButton = LibAT.UI.CreateButton(buttonBar, 90, 22, 'Clear Output', true)
	clearOutputButton:SetPoint('LEFT', deleteButton, 'RIGHT', 5, 0)
	clearOutputButton:SetScript('OnClick', function()
		if TabState.ResultsBox then
			TabState.ResultsBox:SetValue('')
		end
	end)

	-- Results area (bottom ~35% of remaining space)
	local resultsLabel = rightPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	resultsLabel:SetText('Output:')
	resultsLabel:SetTextColor(1, 0.82, 0)

	TabState.ResultsBox = LibAT.UI.CreateMultiLineBox(rightPanel, 100, 100) -- Size set by anchors
	TabState.ResultsBox:SetPoint('BOTTOMLEFT', rightPanel, 'BOTTOMLEFT', 8, 8)
	TabState.ResultsBox:SetPoint('RIGHT', rightPanel, 'RIGHT', -8, 0)
	TabState.ResultsBox:SetReadOnly(true)

	-- Add background to results
	Mixin(TabState.ResultsBox, BackdropTemplateMixin)
	TabState.ResultsBox:SetBackdrop({
		bgFile = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true, tileSize = 16, edgeSize = 12,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	TabState.ResultsBox:SetBackdropColor(0, 0, 0, 0.5)
	TabState.ResultsBox:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

	-- Set monospace font on the results box
	if DevUIState.MonoFont and TabState.ResultsBox.editBox then
		TabState.ResultsBox.editBox:SetFontObject(DevUIState.MonoFont)
	end

	-- Now position elements relative to each other using proportional layout
	-- Editor takes top 55%, button bar in middle, results take bottom 35%
	-- We do this by anchoring from bottom up
	TabState.ResultsBox:SetHeight(120) -- Fixed height for results

	resultsLabel:SetPoint('BOTTOMLEFT', TabState.ResultsBox, 'TOPLEFT', 0, 2)

	buttonBar:SetPoint('BOTTOMLEFT', resultsLabel, 'TOPLEFT', 0, 4)
	buttonBar:SetPoint('RIGHT', rightPanel, 'RIGHT', -8, 0)

	-- Editor fills remaining space between title and button bar
	TabState.EditorBox:SetPoint('BOTTOMLEFT', buttonBar, 'TOPLEFT', 0, 4)

	-- Reload UI button
	local reloadButton = LibAT.UI.CreateButton(contentFrame, 80, 22, 'Reload UI', true)
	reloadButton:SetPoint('BOTTOMLEFT', contentFrame, 'BOTTOMLEFT', 3, 1)
	reloadButton:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)
end
