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
	DevUIState.TabModules[DevUIState.GetTabIndex('CLI')] = {
		BuildContent = BuildContent,
		OnActivate = function()
			RebuildScriptList()
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- Script Execution
----------------------------------------------------------------------------------------------------

local MAX_DEPTH = 4
local MAX_LINES = 3000

---Format a value for dump output (similar to WoW's /dump). Depth and total output are capped so
---dumping something huge like _G stays responsive.
---@param val any The value to format
---@param indent string Current indentation
---@param visited table Tables on the current path (cycle detection)
---@param budget {lines: number} Shared output budget
---@param depth number Current nesting depth
---@return string formatted The formatted string
local function FormatValue(val, indent, visited, budget, depth)
	local valType = type(val)

	if valType == 'string' then
		return '|cff88ff88"' .. val .. '"|r'
	elseif valType == 'number' then
		return '|cffffcc00' .. tostring(val) .. '|r'
	elseif valType == 'boolean' then
		return '|cff44ddff' .. tostring(val) .. '|r'
	elseif valType == 'nil' then
		return '|cff888888nil|r'
	elseif valType == 'function' then
		return '|cffcc88ff<function>|r'
	elseif valType == 'userdata' then
		return '|cffcc88ff<userdata>|r'
	elseif valType == 'table' then
		if visited[val] then
			return '|cffff8800<circular reference>|r'
		end
		if depth >= MAX_DEPTH then
			return '|cff888888{...}|r'
		end
		visited[val] = true

		local parts = {}
		local nextIndent = indent .. '  '
		local count = 0
		local maxEntries = 200
		local truncated = false

		local function Add(keyStr, v)
			if count >= maxEntries or budget.lines >= MAX_LINES then
				truncated = true
				return false
			end
			budget.lines = budget.lines + 1
			table.insert(parts, nextIndent .. '|cffffcc00' .. keyStr .. '|r=' .. FormatValue(v, nextIndent, visited, budget, depth + 1))
			count = count + 1
			return true
		end

		local length = #val
		for i = 1, length do
			if not Add('[' .. i .. ']', val[i]) then
				break
			end
		end
		if not truncated then
			for k, v in pairs(val) do
				if type(k) ~= 'number' or k < 1 or k > length or k ~= math.floor(k) then
					if not Add(type(k) == 'string' and k or ('[' .. tostring(k) .. ']'), v) then
						break
					end
				end
			end
		end
		if truncated then
			table.insert(parts, nextIndent .. '|cff888888... (truncated)|r')
		end

		visited[val] = nil

		if #parts == 0 then
			return '{}'
		end
		return '{\n' .. table.concat(parts, ',\n') .. '\n' .. indent .. '}'
	end

	return tostring(val)
end

---Dump values in a structured format (like WoW's /dump)
---@param count number Number of values, including trailing nils
---@param values table Values packed from index 1
---@return string output Formatted dump output
local function DumpValues(count, values)
	if count == 0 then
		return '|cff888888nil|r'
	end
	local budget = { lines = 0 }
	if count == 1 then
		return FormatValue(values[1], '', {}, budget, 0)
	end
	local lines = {}
	for i = 1, count do
		table.insert(lines, '|cffffcc00[' .. i .. ']|r=' .. FormatValue(values[i], '', {}, budget, 0))
	end
	return table.concat(lines, ',\n')
end

---@return number count
---@return table values
local function Pack(...)
	return select('#', ...), { ... }
end

---Execute Lua code and capture output. The code runs in its own environment whose print writes
---to the output pane; globals still read from and write to _G, and the real print is never touched.
---@param code string The Lua code to execute
---@return string output The captured output text
local function ExecuteCode(code)
	if not code or code == '' then
		return '|cffff0000No code to execute.|r'
	end

	local output = {}
	local env = setmetatable({
		print = function(...)
			local parts = {}
			for i = 1, select('#', ...) do
				parts[i] = tostring(select(i, ...))
			end
			table.insert(output, table.concat(parts, '\t'))
		end,
	}, { __index = _G, __newindex = _G })

	-- Strip common WoW slash command prefixes so copy-pasted commands just work
	-- /run, /script execute Lua; /dump inspects values
	local strippedCode = code:match('^%s*/?run%s+(.+)') or code:match('^%s*/?script%s+(.+)')
	if strippedCode then
		code = strippedCode
	end

	-- Support "dump expression" and "/dump expression" shorthand
	local dumpExpr = code:match('^%s*/?dump%s+(.+)')
	if dumpExpr then
		local func, err = loadstring('return ' .. dumpExpr)
		if func then
			setfenv(func, env)
			local count, results = Pack(pcall(func))
			if results[1] then
				local ok, text = pcall(DumpValues, count - 1, { select(2, unpack(results, 1, count)) })
				table.insert(output, ok and text or ('|cffff0000Could not display the result: ' .. tostring(text) .. '|r'))
			else
				table.insert(output, '|cffff0000Runtime Error: ' .. tostring(results[2]) .. '|r')
			end
		else
			table.insert(output, '|cffff0000Syntax Error: ' .. tostring(err) .. '|r')
		end
		return table.concat(output, '\n')
	end

	-- Support "= expression" shorthand (auto-print)
	local evalCode = code:gsub('^%s*=%s*(.+)', 'print(%1)')

	local func, err = loadstring(evalCode)
	if func then
		setfenv(func, env)
		local success, execErr = pcall(func)
		if not success then
			table.insert(output, '|cffff0000Runtime Error: ' .. tostring(execErr) .. '|r')
		end
	else
		table.insert(output, '|cffff0000Syntax Error: ' .. tostring(err) .. '|r')
	end

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
	if not TabState.ScriptTree or not DevUI.DB then
		return
	end

	local yOffset = 0
	local buttonHeight = 21

	local scriptNames = {}
	for name, _ in pairs(DevUI.DB.cli.savedScripts) do
		table.insert(scriptNames, name)
	end
	table.sort(scriptNames)

	for index, scriptName in ipairs(scriptNames) do
		local button = TabState.ScriptButtons[index]
		if not button then
			button = LibAT.UI.CreateFilterButton(TabState.ScriptTree, nil)
			button:SetScript('OnEnter', function(self)
				self.HighlightTexture:Show()
			end)
			button:SetScript('OnLeave', function(self)
				self.HighlightTexture:Hide()
			end)
			button:SetScript('OnClick', function(self)
				for _, btn in ipairs(TabState.ScriptButtons) do
					btn.SelectedTexture:Hide()
					btn:SetNormalFontObject(GameFontHighlightSmall)
				end
				self.SelectedTexture:Show()
				self:SetNormalFontObject(GameFontNormalSmall)

				TabState.ActiveScript = self.scriptName
				local body = DevUI.DB.cli.savedScripts[self.scriptName]
				if TabState.TitleBox then
					TabState.TitleBox:SetText(self.scriptName)
				end
				if TabState.EditorBox then
					TabState.EditorBox:SetValue(body or '')
				end
			end)
			TabState.ScriptButtons[index] = button
		end

		button.scriptName = scriptName
		button:ClearAllPoints()
		button:SetPoint('TOPLEFT', TabState.ScriptTree, 'TOPLEFT', 3, yOffset)
		LibAT.UI.SetupFilterButton(button, {
			type = 'subCategory',
			name = scriptName,
			subCategoryIndex = scriptName,
			selected = (TabState.ActiveScript == scriptName),
		})
		button:Show()
		yOffset = yOffset - (buttonHeight + 1)
	end

	for i = #scriptNames + 1, #TabState.ScriptButtons do
		TabState.ScriptButtons[i]:Hide()
	end

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

	-- Control frame (top bar) — contentFrame already starts below title bar, so use minimal offset
	TabState.ControlFrame = LibAT.UI.CreateControlFrame(contentFrame, -2)

	-- Main content area
	TabState.MainContent = LibAT.UI.CreateContentFrame(contentFrame, TabState.ControlFrame)

	-- Left panel: Saved scripts
	TabState.LeftPanel = LibAT.UI.CreateLeftPanel(TabState.MainContent)

	-- "Saved Scripts" header
	local header = TabState.LeftPanel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	header:SetPoint('TOP', TabState.LeftPanel, 'TOP', 0, -4)
	header:SetText('Saved Scripts')
	header:SetTextColor(1, 0.82, 0)

	-- Script scroll frame
	TabState.ScriptScrollFrame = CreateFrame('ScrollFrame', nil, TabState.LeftPanel)
	TabState.ScriptScrollFrame:SetPoint('TOPLEFT', TabState.LeftPanel, 'TOPLEFT', 2, -7)
	TabState.ScriptScrollFrame:SetPoint('BOTTOMRIGHT', TabState.LeftPanel, 'BOTTOMRIGHT', 0, 2)

	TabState.ScriptScrollFrame.ScrollBar = CreateFrame('EventFrame', nil, TabState.ScriptScrollFrame, 'MinimalScrollBar')
	TabState.ScriptScrollFrame.ScrollBar:SetPoint('TOPLEFT', TabState.ScriptScrollFrame, 'TOPRIGHT', 6, 0)
	TabState.ScriptScrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', TabState.ScriptScrollFrame, 'BOTTOMRIGHT', 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(TabState.ScriptScrollFrame, TabState.ScriptScrollFrame.ScrollBar)

	TabState.ScriptTree = CreateFrame('Frame', nil, TabState.ScriptScrollFrame)
	TabState.ScriptScrollFrame:SetScrollChild(TabState.ScriptTree)
	TabState.ScriptTree:SetSize(160, 1)

	-- Right panel
	TabState.RightPanel = LibAT.UI.CreateRightPanel(TabState.MainContent, TabState.LeftPanel)
	local rightPanel = TabState.RightPanel

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
		tile = true,
		tileSize = 16,
		edgeSize = 12,
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
		tile = true,
		tileSize = 16,
		edgeSize = 12,
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
	local reloadButton = LibAT.UI.CreateButton(contentFrame, 80, 20, 'Reload UI', true)
	reloadButton:SetPoint('BOTTOMLEFT', contentFrame, 'BOTTOMLEFT', 4, 1)
	reloadButton:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)
end
