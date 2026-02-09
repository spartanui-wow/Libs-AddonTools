---@class LibAT
local LibAT = LibAT

-- DevUI Errors Tab: Consolidated error viewer with session-based error list
-- Uses the existing ErrorDisplay.ErrorHandler API to read BugGrabber data

LibAT.DevUI = LibAT.DevUI or {}

local DevUI, DevUIState

-- Forward declarations (must be before InitErrors so closures capture the locals)
local GetErrorHandler
local RebuildErrorList
local DisplayError
local BuildContent

-- Tab-local UI state
local TabState = {
	ContentFrame = nil,
	LeftPanel = nil,
	RightPanel = nil,
	ErrorScrollFrame = nil,
	ErrorTree = nil,
	TextPanel = nil,
	EditBox = nil,
	ShowLocals = nil,
	ErrorButtons = {},
	CurrentError = nil, -- Currently displayed error object
	CurrentErrorList = {}, -- Filtered error list for navigation
	CurrentErrorIndex = 0,
}

---Initialize the Errors tab with shared state
---@param devUIModule table The DevUI module
---@param state table The DevUI shared state
function LibAT.DevUI.InitErrors(devUIModule, state)
	DevUI = devUIModule
	DevUIState = state

	-- Register this tab with DevUI
	DevUIState.TabModules[3] = {
		BuildContent = BuildContent,
		OnActivate = function()
			RebuildErrorList()
			-- Update error count label
			if TabState.ErrorCountLabel then
				local handler = GetErrorHandler()
				if handler then
					local total, ignored = handler:GetErrorCounts()
					TabState.ErrorCountLabel:SetText('Total: ' .. total .. ' | Ignored: ' .. ignored)
				end
			end
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- Error Handler Access
----------------------------------------------------------------------------------------------------

---Get the ErrorHandler from the ErrorDisplay system
---@return table|nil ErrorHandler
GetErrorHandler = function()
	if _G.LibATErrorDisplay and _G.LibATErrorDisplay.ErrorHandler then
		return _G.LibATErrorDisplay.ErrorHandler
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- Error List Building
----------------------------------------------------------------------------------------------------

---Rebuild the session-based error list in the left panel
RebuildErrorList = function()
	-- Clear existing buttons
	for _, button in pairs(TabState.ErrorButtons) do
		button:Hide()
		button:SetParent(nil)
	end
	TabState.ErrorButtons = {}
	TabState.CurrentErrorList = {}

	if not TabState.ErrorTree then
		return
	end

	local handler = GetErrorHandler()
	if not handler then
		return
	end

	local currentSession = handler:GetCurrentSession()
	local sessions = handler:GetSessionsWithInfo()

	-- Sort: current session first, then reverse chronological
	table.sort(sessions, function(a, b)
		if a.isCurrent then
			return true
		end
		if b.isCurrent then
			return false
		end
		return a.id > b.id
	end)

	local yOffset = 0
	local buttonHeight = 21

	for _, sessionData in ipairs(sessions) do
		local errors = handler:GetErrors(sessionData.id)
		if #errors > 0 or sessionData.isCurrent then
			-- Session header
			local headerButton = LibAT.UI.CreateFilterButton(TabState.ErrorTree, nil)
			headerButton:SetPoint('TOPLEFT', TabState.ErrorTree, 'TOPLEFT', 3, yOffset)

			local headerText
			if sessionData.isCurrent then
				headerText = 'Current Session (' .. #errors .. ')'
			else
				headerText = 'Session ' .. sessionData.id .. ' (' .. #errors .. ')'
			end

			LibAT.UI.SetupFilterButton(headerButton, {
				type = 'category',
				name = headerText,
				categoryIndex = sessionData.id,
				selected = false,
			})
			headerButton.Text:SetTextColor(1, 0.82, 0) -- Gold header

			-- View All button for this session
			headerButton:SetScript('OnClick', function()
				-- Show all errors from this session in the display
				local sessionErrors = handler:GetErrors(sessionData.id)
				if #sessionErrors > 0 then
					local allText = ''
					local showLocals = TabState.ShowLocals and TabState.ShowLocals:GetChecked()
					for i, err in ipairs(sessionErrors) do
						if i > 1 then
							allText = allText .. '\n|cff444444' .. string.rep('-', 60) .. '|r\n\n'
						end
						allText = allText .. handler:FormatError(err, showLocals) .. '\n'
					end
					if TabState.EditBox then
						TabState.EditBox:SetText(allText)
					end
				end
			end)

			headerButton:SetScript('OnEnter', function(self)
				self.HighlightTexture:Show()
			end)
			headerButton:SetScript('OnLeave', function(self)
				self.HighlightTexture:Hide()
			end)

			table.insert(TabState.ErrorButtons, headerButton)
			yOffset = yOffset - (buttonHeight + 1)

			-- Error entries under this session
			for _, err in ipairs(errors) do
				-- Add to navigable list
				table.insert(TabState.CurrentErrorList, err)
				local errorIndex = #TabState.CurrentErrorList

				local errorButton = LibAT.UI.CreateFilterButton(TabState.ErrorTree, nil)
				errorButton:SetPoint('TOPLEFT', TabState.ErrorTree, 'TOPLEFT', 3, yOffset)

				-- Truncate error message for button display
				local shortMessage = tostring(err.message or 'Unknown error')
				-- Remove path prefixes to save space
				shortMessage = shortMessage:gsub('^.-%]:%d+: ', '')
				if #shortMessage > 35 then
					shortMessage = shortMessage:sub(1, 32) .. '...'
				end

				-- Count indicator
				if err.counter and err.counter > 1 then
					shortMessage = err.counter .. 'x ' .. shortMessage
				end

				LibAT.UI.SetupFilterButton(errorButton, {
					type = 'subCategory',
					name = shortMessage,
					subCategoryIndex = errorIndex,
					selected = (TabState.CurrentError == err),
				})

				-- Color based on session: white for current, gray for previous
				if sessionData.isCurrent then
					errorButton.Text:SetTextColor(1, 1, 1)
				else
					errorButton.Text:SetTextColor(0.5, 0.5, 0.5)
				end

				errorButton:SetScript('OnEnter', function(self)
					self.HighlightTexture:Show()
					-- Tooltip with full error message
					GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
					GameTooltip:SetText('Error', 1, 0.2, 0.2)
					GameTooltip:AddLine(tostring(err.message or ''), 1, 1, 1, true)
					GameTooltip:Show()
				end)
				errorButton:SetScript('OnLeave', function(self)
					self.HighlightTexture:Hide()
					GameTooltip:Hide()
				end)

				errorButton:SetScript('OnClick', function(self)
					-- Clear all selections
					for _, btn in pairs(TabState.ErrorButtons) do
						btn.SelectedTexture:Hide()
					end
					self.SelectedTexture:Show()

					TabState.CurrentError = err
					TabState.CurrentErrorIndex = errorIndex
					DisplayError(err)
				end)

				table.insert(TabState.ErrorButtons, errorButton)
				yOffset = yOffset - (buttonHeight + 1)
			end
		end
	end

	-- Update tree height
	local totalHeight = math.abs(yOffset) + 20
	TabState.ErrorTree:SetHeight(math.max(totalHeight, TabState.ErrorScrollFrame:GetHeight()))

	-- Show empty state if no errors
	if #TabState.CurrentErrorList == 0 and TabState.EditBox then
		TabState.EditBox:SetText('No errors recorded in any session.')
	end
end

----------------------------------------------------------------------------------------------------
-- Error Display
----------------------------------------------------------------------------------------------------

---Display a single error in the right panel
---@param err table The BugGrabber error object
DisplayError = function(err)
	if not TabState.EditBox then
		return
	end

	local handler = GetErrorHandler()
	if not handler then
		TabState.EditBox:SetText('Error Display system not available.')
		return
	end

	local showLocals = TabState.ShowLocals and TabState.ShowLocals:GetChecked() or false
	local formattedText = handler:FormatError(err, showLocals)
	TabState.EditBox:SetText(formattedText)
end

---Navigate to the previous error
local function PreviousError()
	if TabState.CurrentErrorIndex > 1 then
		TabState.CurrentErrorIndex = TabState.CurrentErrorIndex - 1
		TabState.CurrentError = TabState.CurrentErrorList[TabState.CurrentErrorIndex]
		DisplayError(TabState.CurrentError)
	end
end

---Navigate to the next error
local function NextError()
	if TabState.CurrentErrorIndex < #TabState.CurrentErrorList then
		TabState.CurrentErrorIndex = TabState.CurrentErrorIndex + 1
		TabState.CurrentError = TabState.CurrentErrorList[TabState.CurrentErrorIndex]
		DisplayError(TabState.CurrentError)
	end
end

----------------------------------------------------------------------------------------------------
-- Content Builder
----------------------------------------------------------------------------------------------------

---Build the Errors tab content
---@param contentFrame Frame The parent content frame from DevUI
BuildContent = function(contentFrame)
	TabState.ContentFrame = contentFrame

	-- Control frame with Show Locals checkbox — contentFrame already starts below title bar
	local controlFrame = LibAT.UI.CreateControlFrame(contentFrame, -2)

	TabState.ShowLocals = LibAT.UI.CreateCheckbox(controlFrame, 'Show Locals')
	TabState.ShowLocals:SetPoint('LEFT', controlFrame, 'LEFT', 60, 0)
	TabState.ShowLocals:SetChecked(DevUI.DB and DevUI.DB.errors.showLocals or true)
	TabState.ShowLocals:SetScript('OnClick', function(self)
		if DevUI.DB then
			DevUI.DB.errors.showLocals = self:GetChecked()
		end
		-- Refresh current error display
		if TabState.CurrentError then
			DisplayError(TabState.CurrentError)
		end
	end)

	-- Error count label
	local errorCountLabel = controlFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	errorCountLabel:SetPoint('RIGHT', controlFrame, 'RIGHT', -16, 0)
	errorCountLabel:SetTextColor(1, 1, 1)
	TabState.ErrorCountLabel = errorCountLabel

	-- Main content area
	local mainContent = LibAT.UI.CreateContentFrame(contentFrame, controlFrame)

	-- Left panel: Session-based error list
	TabState.LeftPanel = LibAT.UI.CreateLeftPanel(mainContent)

	-- Error scroll frame
	TabState.ErrorScrollFrame = CreateFrame('ScrollFrame', nil, TabState.LeftPanel)
	TabState.ErrorScrollFrame:SetPoint('TOPLEFT', TabState.LeftPanel, 'TOPLEFT', 2, -7)
	TabState.ErrorScrollFrame:SetPoint('BOTTOMRIGHT', TabState.LeftPanel, 'BOTTOMRIGHT', 0, 2)

	TabState.ErrorScrollFrame.ScrollBar = CreateFrame('EventFrame', nil, TabState.ErrorScrollFrame, 'MinimalScrollBar')
	TabState.ErrorScrollFrame.ScrollBar:SetPoint('TOPLEFT', TabState.ErrorScrollFrame, 'TOPRIGHT', 6, 0)
	TabState.ErrorScrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', TabState.ErrorScrollFrame, 'BOTTOMRIGHT', 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(TabState.ErrorScrollFrame, TabState.ErrorScrollFrame.ScrollBar)

	TabState.ErrorTree = CreateFrame('Frame', nil, TabState.ErrorScrollFrame)
	TabState.ErrorScrollFrame:SetScrollChild(TabState.ErrorTree)
	TabState.ErrorTree:SetSize(160, 1)

	-- Right panel: Error display
	TabState.RightPanel = LibAT.UI.CreateRightPanel(mainContent, TabState.LeftPanel)

	-- Scrollable text display for error details
	TabState.TextPanel, TabState.EditBox = LibAT.UI.CreateScrollableTextDisplay(TabState.RightPanel)
	TabState.TextPanel:SetPoint('TOPLEFT', TabState.RightPanel, 'TOPLEFT', 6, -6)
	TabState.TextPanel:SetPoint('BOTTOMRIGHT', TabState.RightPanel, 'BOTTOMRIGHT', 0, 2)
	TabState.EditBox:SetWidth(TabState.TextPanel:GetWidth() - 20)
	TabState.EditBox:SetText('Select an error from the left panel to view details.')

	-- Navigation buttons at bottom
	local actionButtons = LibAT.UI.CreateActionButtons(contentFrame, {
		{
			text = '< Previous',
			width = 80,
			onClick = function()
				PreviousError()
			end,
		},
		{
			text = 'Next >',
			width = 80,
			onClick = function()
				NextError()
			end,
		},
		{
			text = 'Show All',
			width = 80,
			onClick = function()
				local handler = GetErrorHandler()
				if not handler then
					return
				end

				local allErrors = handler:GetAllErrorsFromAllSessions() or {}
				if #allErrors == 0 then
					if TabState.EditBox then
						TabState.EditBox:SetText('No errors to display.')
					end
					return
				end

				local showLocals = TabState.ShowLocals and TabState.ShowLocals:GetChecked() or false
				local text = handler:GenerateDebugHeader()
				text = text .. '=================================\n\n'

				for i, err in ipairs(allErrors) do
					text = text .. string.format('---------------------------------\n                  Error #%d\n---------------------------------\n\n```lua\n%s\n```\n\n', i, handler:FormatError(err, showLocals))
				end

				if TabState.EditBox then
					TabState.EditBox:SetText(text)
				end
			end,
		},
		{
			text = 'Ignore',
			width = 80,
			onClick = function()
				local handler = GetErrorHandler()
				if not handler or not TabState.CurrentError then
					return
				end

				if handler:IgnoreError(TabState.CurrentError) then
					TabState.CurrentError = nil
					TabState.CurrentErrorIndex = 0
					RebuildErrorList()

					if TabState.EditBox then
						TabState.EditBox:SetText('Error ignored. Select another error from the left panel.')
					end
				end
			end,
		},
		{
			text = 'Clear All',
			width = 80,
			onClick = function()
				if not _G.LibATErrorDisplay then
					return
				end

				_G.LibATErrorDisplay.Reset()
				TabState.CurrentError = nil
				TabState.CurrentErrorIndex = 0
				RebuildErrorList()

				if TabState.EditBox then
					TabState.EditBox:SetText('All errors have been cleared.')
				end

				-- Update error count label
				if TabState.ErrorCountLabel then
					TabState.ErrorCountLabel:SetText('Total: 0 | Ignored: 0')
				end
			end,
		},
	})

	-- Reload UI button
	local reloadButton = LibAT.UI.CreateButton(contentFrame, 80, 20, 'Reload UI', true)
	reloadButton:SetPoint('BOTTOMLEFT', contentFrame, 'BOTTOMLEFT', 4, 1)
	reloadButton:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)

	-- Check if ErrorDisplay is available
	if not GetErrorHandler() then
		TabState.EditBox:SetText('Error Display system not available.\nBugGrabber may not be loaded.')
	end
end
