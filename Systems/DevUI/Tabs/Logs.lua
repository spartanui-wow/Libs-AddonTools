---@class LibAT
local LibAT = LibAT

-- DevUI Logs Tab: Mirrors the standalone Logger window, sharing the same LoggerState data
-- This tab provides an identical log viewing experience within the DevUI tabbed interface

LibAT.DevUI = LibAT.DevUI or {}

local DevUI, DevUIState
local LoggerState -- Retrieved from Logger module via GetState accessor

-- Forward declarations (must be before InitLogs so closures capture the locals)
local BuildCategoryTree
local BuildLogSourceCategories
local UpdateLogsDisplay
local SetupLogLevelDropdown
local BuildContent

-- Tab-local UI state (separate from standalone Logger window)
local TabState = {
	ContentFrame = nil,
	ControlFrame = nil,
	MainContent = nil,
	LeftPanel = nil,
	RightPanel = nil,
	ModuleScrollFrame = nil,
	ModuleTree = nil,
	TextPanel = nil,
	EditBox = nil,
	SearchBox = nil,
	SearchAllModules = nil,
	LoggingLevelButton = nil,
	AutoScroll = nil,
	categoryButtons = {},
	moduleButtons = {},
	Categories = {},
	ActiveModule = nil,
	CurrentSearchTerm = '',
	SearchAllEnabled = false,
	AutoScrollEnabled = true,
}

---Initialize the Logs tab with shared state
---@param devUIModule table The DevUI module
---@param state table The DevUI shared state
function LibAT.DevUI.InitLogs(devUIModule, state)
	DevUI = devUIModule
	DevUIState = state

	-- Register this tab with DevUI
	DevUIState.TabModules[1] = {
		BuildContent = BuildContent,
		OnActivate = function()
			-- Refresh LoggerState reference
			LoggerState = LibAT.Logger.GetState()
			if LoggerState then
				BuildLogSourceCategories()
				UpdateLogsDisplay()
			end
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- Search and Display Helpers
----------------------------------------------------------------------------------------------------

---Highlight search terms in text with magenta color
---@param text string The text to highlight in
---@param searchTerm string The term to highlight
---@return string highlighted The text with highlighted matches
local function HighlightSearchTerm(text, searchTerm)
	if not searchTerm or searchTerm == '' then
		return text
	end

	local highlightColor = '|cffff00ff'
	local resetColor = '|r'
	local escapedTerm = searchTerm:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')
	local result = text
	local searchLower = escapedTerm:lower()
	local pos = 1

	while pos <= #result do
		local textLower = result:lower()
		local startPos, endPos = textLower:find(searchLower, pos, true)
		if not startPos then
			break
		end
		local actualMatch = result:sub(startPos, endPos)
		local highlightedMatch = highlightColor .. actualMatch .. resetColor
		result = result:sub(1, startPos - 1) .. highlightedMatch .. result:sub(endPos + 1)
		pos = startPos + #highlightedMatch
	end

	return result
end

---Check if a log entry matches the search criteria
---@param logEntry table The log entry to check
---@param searchTerm string The current search term
---@param logLevel number The minimum log level priority
---@return boolean matches Whether the entry matches
local function MatchesSearchCriteria(logEntry, searchTerm, logLevel)
	local entryLogLevel = LoggerState.LOG_LEVELS[logEntry.level]
	if not entryLogLevel or entryLogLevel.priority < logLevel then
		return false
	end
	if searchTerm and searchTerm ~= '' then
		return logEntry.message:lower():find(searchTerm:lower(), 1, true) ~= nil
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- Category Tree
----------------------------------------------------------------------------------------------------

---Build hierarchical log source categories from LoggerState data
---Assigns to the forward-declared local above
BuildLogSourceCategories = function()
	if not TabState.ModuleTree then
		return
	end

	local loggerModule = LibAT:GetModule('Handler.Logger', true)
	if not loggerModule or not loggerModule.DB or not loggerModule.DB.modules then
		return
	end

	TabState.Categories = {}
	local scrollListing = {}

	for sourceName, _ in pairs(loggerModule.DB.modules) do
		local category, subCategory, subSubCategory, sourceType = LoggerState.ParseLogSource(sourceName)

		if not TabState.Categories[category] then
			TabState.Categories[category] = {
				name = category,
				subCategories = {},
				expanded = LoggerState.AddonCategories[category] and LoggerState.AddonCategories[category].expanded or false,
				button = nil,
				isAddonCategory = (LoggerState.AddonCategories[category] ~= nil) or (LoggerState.RegisteredAddons[category] ~= nil),
			}
		end

		if sourceType == 'subCategory' then
			if not TabState.Categories[category].subCategories[subCategory] then
				TabState.Categories[category].subCategories[subCategory] = {
					name = subCategory,
					sourceName = sourceName,
					subSubCategories = {},
					expanded = false,
					button = nil,
					type = 'subCategory',
				}
			end
		elseif sourceType == 'subSubCategory' then
			if not TabState.Categories[category].subCategories[subCategory] then
				TabState.Categories[category].subCategories[subCategory] = {
					name = subCategory,
					subSubCategories = {},
					expanded = false,
					button = nil,
					type = 'subCategory',
				}
			end
			TabState.Categories[category].subCategories[subCategory].subSubCategories[subSubCategory] = {
				name = subSubCategory,
				sourceName = sourceName,
				button = nil,
				type = 'subSubCategory',
			}
		end

		table.insert(scrollListing, {
			text = sourceName,
			value = sourceName,
			category = category,
			subCategory = subCategory,
			subSubCategory = subSubCategory,
			sourceType = sourceType,
		})
	end

	-- Sort categories
	local sortedCategories = {}
	for categoryName, categoryData in pairs(TabState.Categories) do
		table.insert(sortedCategories, categoryName)

		local sortedSubCategories = {}
		for subCategoryName, _ in pairs(categoryData.subCategories) do
			table.insert(sortedSubCategories, subCategoryName)
		end
		table.sort(sortedSubCategories)
		categoryData.sortedSubCategories = sortedSubCategories

		for _, subCategoryData in pairs(categoryData.subCategories) do
			local sortedSubSubCategories = {}
			for subSubCategoryName, _ in pairs(subCategoryData.subSubCategories) do
				table.insert(sortedSubSubCategories, subSubCategoryName)
			end
			table.sort(sortedSubSubCategories)
			subCategoryData.sortedSubSubCategories = sortedSubSubCategories
		end
	end
	table.sort(sortedCategories)

	BuildCategoryTree(sortedCategories)
end

---Create the visual category tree buttons
---@param sortedCategories table Sorted array of category names
---Assigns to the forward-declared local above
BuildCategoryTree = function(sortedCategories)
	if not TabState.ModuleTree then
		return
	end

	-- Clear existing buttons
	for _, button in pairs(TabState.categoryButtons) do
		button:Hide()
		button:SetParent(nil)
	end
	for _, button in pairs(TabState.moduleButtons) do
		button:Hide()
		button:SetParent(nil)
	end
	TabState.categoryButtons = {}
	TabState.moduleButtons = {}

	local yOffset = 0
	local buttonHeight = 21

	for _, categoryName in ipairs(sortedCategories) do
		local categoryData = TabState.Categories[categoryName]
		local subCategoryCount = 0

		if categoryData.subCategories then
			for _, subCategoryData in pairs(categoryData.subCategories) do
				subCategoryCount = subCategoryCount + 1
				if subCategoryData.subSubCategories then
					for _, _ in pairs(subCategoryData.subSubCategories) do
						subCategoryCount = subCategoryCount + 1
					end
				end
			end
		end

		local isCoreOnly = (subCategoryCount == 1 and categoryData.sortedSubCategories and #categoryData.sortedSubCategories == 1 and categoryData.sortedSubCategories[1] == 'Core')

		if isCoreOnly then
			local coreSubCategory = categoryData.subCategories['Core']
			local categoryButton = LibAT.UI.CreateFilterButton(TabState.ModuleTree, nil)
			categoryButton:SetPoint('TOPLEFT', TabState.ModuleTree, 'TOPLEFT', 3, yOffset)

			LibAT.UI.SetupFilterButton(categoryButton, {
				type = 'category',
				name = categoryName,
				categoryIndex = categoryName,
				isToken = categoryData.isAddonCategory,
				selected = (TabState.ActiveModule == coreSubCategory.sourceName),
			})

			categoryButton:SetScript('OnClick', function(self)
				for _, btn in pairs(TabState.moduleButtons) do
					btn.SelectedTexture:Hide()
					btn:SetNormalFontObject(GameFontHighlightSmall)
				end
				self.SelectedTexture:Show()
				self:SetNormalFontObject(GameFontNormalSmall)
				TabState.ActiveModule = coreSubCategory.sourceName
				UpdateLogsDisplay()
			end)

			categoryButton:SetScript('OnEnter', function(self)
				self.HighlightTexture:Show()
			end)
			categoryButton:SetScript('OnLeave', function(self)
				self.HighlightTexture:Hide()
			end)

			table.insert(TabState.moduleButtons, categoryButton)
			yOffset = yOffset - (buttonHeight + 1)
		else
			local categoryButton = LibAT.UI.CreateFilterButton(TabState.ModuleTree, nil)
			categoryButton:SetPoint('TOPLEFT', TabState.ModuleTree, 'TOPLEFT', 3, yOffset)

			LibAT.UI.SetupFilterButton(categoryButton, {
				type = 'category',
				name = categoryName .. ' (' .. subCategoryCount .. ')',
				categoryIndex = categoryName,
				isToken = categoryData.isAddonCategory,
				selected = false,
			})

			categoryButton.indicator = categoryButton:CreateTexture(nil, 'OVERLAY')
			categoryButton.indicator:SetSize(15, 15)
			categoryButton.indicator:SetPoint('LEFT', categoryButton, 'LEFT', 2, 0)
			if categoryData.expanded then
				categoryButton.indicator:SetAtlas('uitools-icon-minimize')
			else
				categoryButton.indicator:SetAtlas('uitools-icon-plus')
			end

			categoryButton.Text:SetTextColor(1, 0.82, 0)

			categoryButton:SetScript('OnClick', function(self)
				categoryData.expanded = not categoryData.expanded
				if categoryData.isAddonCategory and LoggerState.AddonCategories[categoryName] then
					LoggerState.AddonCategories[categoryName].expanded = categoryData.expanded
				end
				if categoryData.expanded then
					self.indicator:SetAtlas('uitools-icon-minimize')
				else
					self.indicator:SetAtlas('uitools-icon-plus')
				end
				BuildCategoryTree(sortedCategories)
			end)

			categoryButton:SetScript('OnEnter', function(self)
				self.HighlightTexture:Show()
			end)
			categoryButton:SetScript('OnLeave', function(self)
				self.HighlightTexture:Hide()
			end)

			categoryData.button = categoryButton
			table.insert(TabState.categoryButtons, categoryButton)
			yOffset = yOffset - (buttonHeight + 1)
		end

		-- SubCategories and SubSubCategories when expanded
		if categoryData.expanded and not isCoreOnly then
			for _, subCategoryName in ipairs(categoryData.sortedSubCategories) do
				local subCategoryData = categoryData.subCategories[subCategoryName]

				local subCategoryButton = LibAT.UI.CreateFilterButton(TabState.ModuleTree, nil)
				subCategoryButton:SetPoint('TOPLEFT', TabState.ModuleTree, 'TOPLEFT', 3, yOffset)

				LibAT.UI.SetupFilterButton(subCategoryButton, {
					type = 'subCategory',
					name = subCategoryName,
					subCategoryIndex = subCategoryName,
					selected = (TabState.ActiveModule == (subCategoryData.sourceName or subCategoryName)),
				})

				if subCategoryData.subSubCategories and next(subCategoryData.subSubCategories) then
					subCategoryButton.indicator = subCategoryButton:CreateTexture(nil, 'OVERLAY')
					subCategoryButton.indicator:SetSize(12, 12)
					subCategoryButton.indicator:SetPoint('LEFT', subCategoryButton, 'LEFT', 2, 0)
					if subCategoryData.expanded then
						subCategoryButton.indicator:SetAtlas('uitools-icon-minimize')
					else
						subCategoryButton.indicator:SetAtlas('uitools-icon-plus')
					end
				end

				subCategoryButton:SetScript('OnEnter', function(self)
					self.HighlightTexture:Show()
				end)
				subCategoryButton:SetScript('OnLeave', function(self)
					self.HighlightTexture:Hide()
				end)

				subCategoryButton:SetScript('OnClick', function(self)
					if subCategoryData.subSubCategories and next(subCategoryData.subSubCategories) then
						subCategoryData.expanded = not subCategoryData.expanded
						if self.indicator then
							if subCategoryData.expanded then
								self.indicator:SetAtlas('uitools-icon-minimize')
							else
								self.indicator:SetAtlas('uitools-icon-plus')
							end
						end
						BuildCategoryTree(sortedCategories)
					else
						for _, btn in pairs(TabState.moduleButtons) do
							btn.SelectedTexture:Hide()
							btn:SetNormalFontObject(GameFontHighlightSmall)
						end
						self.SelectedTexture:Show()
						self:SetNormalFontObject(GameFontNormalSmall)
						TabState.ActiveModule = subCategoryData.sourceName or subCategoryName
						UpdateLogsDisplay()
					end
				end)

				table.insert(TabState.moduleButtons, subCategoryButton)
				yOffset = yOffset - (buttonHeight + 1)

				-- SubSubCategories
				if subCategoryData.expanded and subCategoryData.sortedSubSubCategories then
					for _, subSubCategoryName in ipairs(subCategoryData.sortedSubSubCategories) do
						local subSubCategoryData = subCategoryData.subSubCategories[subSubCategoryName]

						local subSubCategoryButton = LibAT.UI.CreateFilterButton(TabState.ModuleTree, nil)
						subSubCategoryButton:SetPoint('TOPLEFT', TabState.ModuleTree, 'TOPLEFT', 3, yOffset)

						LibAT.UI.SetupFilterButton(subSubCategoryButton, {
							type = 'subSubCategory',
							name = subSubCategoryName,
							subSubCategoryIndex = subSubCategoryName,
							selected = (TabState.ActiveModule == subSubCategoryData.sourceName),
						})

						subSubCategoryButton:SetScript('OnEnter', function(self)
							self.HighlightTexture:Show()
						end)
						subSubCategoryButton:SetScript('OnLeave', function(self)
							self.HighlightTexture:Hide()
						end)

						subSubCategoryButton:SetScript('OnClick', function(self)
							for _, btn in pairs(TabState.moduleButtons) do
								btn.SelectedTexture:Hide()
								btn:SetNormalFontObject(GameFontHighlightSmall)
							end
							self.SelectedTexture:Show()
							self:SetNormalFontObject(GameFontNormalSmall)
							TabState.ActiveModule = subSubCategoryData.sourceName
							UpdateLogsDisplay()
						end)

						table.insert(TabState.moduleButtons, subSubCategoryButton)
						yOffset = yOffset - (buttonHeight + 1)
					end
				end
			end
		end
	end

	-- Update tree height
	local totalHeight = math.abs(yOffset) + 20
	TabState.ModuleTree:SetHeight(math.max(totalHeight, TabState.ModuleScrollFrame:GetHeight()))
end

----------------------------------------------------------------------------------------------------
-- Display Update
----------------------------------------------------------------------------------------------------

---Update the log display based on current module selection and filters
UpdateLogsDisplay = function()
	if not TabState.EditBox then
		return
	end

	-- Ensure LoggerState is available
	if not LoggerState then
		LoggerState = LibAT.Logger.GetState()
		if not LoggerState then
			TabState.EditBox:SetText('Logger system not available.')
			return
		end
	end

	local logText = ''
	local totalEntries = 0
	local filteredCount = 0
	local searchedCount = 0

	if TabState.SearchAllEnabled then
		logText = 'Search Results Across All Modules:\n\n'

		for moduleName, logs in pairs(LoggerState.LogMessages) do
			local moduleLogLevel = LoggerState.ModuleLogLevels[moduleName] or 0
			local effectiveLogLevel = moduleLogLevel > 0 and moduleLogLevel or LoggerState.GlobalLogLevel

			local moduleMatches = {}
			for _, logEntry in ipairs(logs) do
				totalEntries = totalEntries + 1
				if MatchesSearchCriteria(logEntry, TabState.CurrentSearchTerm, effectiveLogLevel) then
					table.insert(moduleMatches, logEntry)
					filteredCount = filteredCount + 1
				end
			end

			if #moduleMatches > 0 then
				logText = logText .. '=== ' .. moduleName .. ' (' .. #moduleMatches .. ' entries) ===\n'
				for _, logEntry in ipairs(moduleMatches) do
					local highlightedText = HighlightSearchTerm(logEntry.formattedMessage, TabState.CurrentSearchTerm)
					logText = logText .. highlightedText .. '\n'
					searchedCount = searchedCount + 1
				end
				logText = logText .. '\n'
			end
		end

		if searchedCount == 0 then
			logText = logText .. 'No logs match the current search and filter criteria.'
		else
			logText = 'Search Results: ' .. searchedCount .. ' matches across all modules\nTotal entries: ' .. totalEntries .. ' | Filtered: ' .. filteredCount .. '\n\n' .. logText
		end
	else
		if not TabState.ActiveModule then
			TabState.EditBox:SetText('No module selected - choose a module from the left or enable "Search All Modules"')
			return
		end

		local logs = LoggerState.LogMessages[TabState.ActiveModule] or {}
		totalEntries = #logs

		if totalEntries == 0 then
			TabState.EditBox:SetText('No logs for module: ' .. TabState.ActiveModule)
			return
		end

		local moduleLogLevel = LoggerState.ModuleLogLevels[TabState.ActiveModule] or 0
		local effectiveLogLevel = moduleLogLevel > 0 and moduleLogLevel or LoggerState.GlobalLogLevel

		local matchingEntries = {}
		for _, logEntry in ipairs(logs) do
			if MatchesSearchCriteria(logEntry, TabState.CurrentSearchTerm, effectiveLogLevel) then
				table.insert(matchingEntries, logEntry)
				filteredCount = filteredCount + 1
			end
		end

		local searchInfo = ''
		if TabState.CurrentSearchTerm and TabState.CurrentSearchTerm ~= '' then
			searchInfo = ' | Search: "' .. TabState.CurrentSearchTerm .. '"'
		end

		logText = 'Logs for ' .. TabState.ActiveModule .. ' (' .. totalEntries .. ' total, ' .. filteredCount .. ' shown' .. searchInfo .. '):\n\n'

		if #matchingEntries > 0 then
			for _, logEntry in ipairs(matchingEntries) do
				local highlightedText = HighlightSearchTerm(logEntry.formattedMessage, TabState.CurrentSearchTerm)
				logText = logText .. highlightedText .. '\n'
			end
		else
			logText = logText .. 'No logs match current filter and search criteria.'
		end
	end

	TabState.EditBox:SetText(logText)

	-- Auto-scroll to bottom
	if TabState.AutoScroll and TabState.AutoScroll:GetChecked() and TabState.EditBox then
		TabState.EditBox:SetCursorPosition(string.len(logText))
	end

	-- Update logging level button text
	if TabState.LoggingLevelButton and LoggerState.GetLogLevelByPriority then
		local _, globalLevelData = LoggerState.GetLogLevelByPriority(LoggerState.GlobalLogLevel)
		if globalLevelData then
			TabState.LoggingLevelButton:SetText('Log Level: ' .. globalLevelData.color .. globalLevelData.display .. '|r')
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Content Builder
----------------------------------------------------------------------------------------------------

---Build the Logs tab content within the provided content frame
---@param contentFrame Frame The parent content frame from DevUI
BuildContent = function(contentFrame)
	TabState.ContentFrame = contentFrame

	-- Get LoggerState
	LoggerState = LibAT.Logger.GetState()
	if not LoggerState then
		local label = contentFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		label:SetPoint('CENTER')
		label:SetText('Logger system not available.')
		return
	end

	-- Control frame (top bar) — contentFrame already starts below title bar, so use minimal offset
	TabState.ControlFrame = LibAT.UI.CreateControlFrame(contentFrame, -2)

	-- Header anchor for controls
	local headerAnchor = CreateFrame('Frame', nil, contentFrame)
	headerAnchor:SetPoint('TOPLEFT', TabState.ControlFrame, 'TOPLEFT', 53, 0)
	headerAnchor:SetPoint('TOPRIGHT', TabState.ControlFrame, 'TOPRIGHT', -16, 0)
	headerAnchor:SetHeight(22)

	-- Search All Modules checkbox
	TabState.SearchAllModules = LibAT.UI.CreateCheckbox(headerAnchor, 'Search All Modules')
	TabState.SearchAllModules:SetPoint('LEFT', headerAnchor, 'LEFT', 0, 0)
	TabState.SearchAllModules:SetScript('OnClick', function(self)
		TabState.SearchAllEnabled = self:GetChecked()
		UpdateLogsDisplay()
	end)

	-- Search box
	TabState.SearchBox = LibAT.UI.CreateSearchBox(headerAnchor, 241)
	TabState.SearchBox:SetPoint('LEFT', TabState.SearchAllModules.Label, 'RIGHT', 10, 0)
	TabState.SearchBox:SetScript('OnTextChanged', function(self)
		TabState.CurrentSearchTerm = self:GetText()
		UpdateLogsDisplay()
	end)
	TabState.SearchBox:SetScript('OnEscapePressed', function(self)
		self:SetText('')
		self:ClearFocus()
		TabState.CurrentSearchTerm = ''
		UpdateLogsDisplay()
	end)

	-- Settings button
	local settingsButton = LibAT.UI.CreateIconButton(headerAnchor, 'Warfronts-BaseMapIcons-Empty-Workshop', 'Warfronts-BaseMapIcons-Alliance-Workshop', 'Warfronts-BaseMapIcons-Horde-Workshop')
	settingsButton:SetPoint('RIGHT', headerAnchor, 'RIGHT', 0, 0)
	settingsButton:SetScript('OnClick', function()
		LibAT.Options:ToggleOptions({ 'Help', 'Logging' })
	end)

	-- Logging Level dropdown
	TabState.LoggingLevelButton = LibAT.UI.CreateDropdown(headerAnchor, 'Logging Level', 120, 22)
	TabState.LoggingLevelButton:SetPoint('RIGHT', settingsButton, 'LEFT', -10, 0)

	-- Main content area
	TabState.MainContent = LibAT.UI.CreateContentFrame(contentFrame, TabState.ControlFrame)

	-- Left panel: module navigation
	TabState.LeftPanel = LibAT.UI.CreateLeftPanel(TabState.MainContent, nil)

	-- Module scroll frame
	TabState.ModuleScrollFrame = CreateFrame('ScrollFrame', nil, TabState.LeftPanel)
	TabState.ModuleScrollFrame:SetPoint('TOPLEFT', TabState.LeftPanel, 'TOPLEFT', 2, -7)
	TabState.ModuleScrollFrame:SetPoint('BOTTOMRIGHT', TabState.LeftPanel, 'BOTTOMRIGHT', 0, 2)

	TabState.ModuleScrollFrame.ScrollBar = CreateFrame('EventFrame', nil, TabState.ModuleScrollFrame, 'MinimalScrollBar')
	TabState.ModuleScrollFrame.ScrollBar:SetPoint('TOPLEFT', TabState.ModuleScrollFrame, 'TOPRIGHT', 6, 0)
	TabState.ModuleScrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', TabState.ModuleScrollFrame, 'BOTTOMRIGHT', 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(TabState.ModuleScrollFrame, TabState.ModuleScrollFrame.ScrollBar)

	TabState.ModuleTree = CreateFrame('Frame', nil, TabState.ModuleScrollFrame)
	TabState.ModuleScrollFrame:SetScrollChild(TabState.ModuleTree)
	TabState.ModuleTree:SetSize(160, 1)

	-- Right panel: log display
	TabState.RightPanel = LibAT.UI.CreateRightPanel(TabState.MainContent, TabState.LeftPanel)

	-- Scrollable text display
	TabState.TextPanel, TabState.EditBox = LibAT.UI.CreateScrollableTextDisplay(TabState.RightPanel)
	TabState.TextPanel:SetPoint('TOPLEFT', TabState.RightPanel, 'TOPLEFT', 6, -6)
	TabState.TextPanel:SetPoint('BOTTOMRIGHT', TabState.RightPanel, 'BOTTOMRIGHT', 0, 0)
	TabState.EditBox:SetWidth(TabState.TextPanel:GetWidth() - 20)
	TabState.EditBox:SetText('No logs active - select a module from the left or enable "Search All Modules"')

	-- Action buttons
	local actionButtons = LibAT.UI.CreateActionButtons(contentFrame, {
		{
			text = 'Clear',
			width = 70,
			onClick = function()
				if TabState.SearchAllEnabled then
					for moduleName in pairs(LoggerState.LogMessages) do
						LoggerState.LogMessages[moduleName] = {}
					end
				else
					if TabState.ActiveModule and LoggerState.LogMessages[TabState.ActiveModule] then
						LoggerState.LogMessages[TabState.ActiveModule] = {}
					end
				end
				UpdateLogsDisplay()
				-- Also update standalone Logger window if it exists
				if LibAT.Logger.UpdateLogDisplay then
					LibAT.Logger.UpdateLogDisplay()
				end
			end,
		},
		{
			text = 'Export',
			width = 70,
			onClick = function()
				-- Delegate to Logger's export function
				if LibAT.Logger.ExportCurrentLogs then
					LibAT.Logger.ExportCurrentLogs()
				end
			end,
		},
	}, 5, 3, 0)

	-- Reload UI button
	local reloadButton = LibAT.UI.CreateButton(contentFrame, 80, 20, 'Reload UI', true)
	reloadButton:SetPoint('BOTTOMLEFT', contentFrame, 'BOTTOMLEFT', 4, 1)
	reloadButton:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)

	-- Auto-scroll checkbox
	TabState.AutoScroll = LibAT.UI.CreateCheckbox(contentFrame, 'Auto-scroll')
	TabState.AutoScroll:SetPoint('CENTER', TabState.RightPanel, 'BOTTOM', 0, -20)
	TabState.AutoScroll:SetChecked(TabState.AutoScrollEnabled)

	-- Setup logging level dropdown
	SetupLogLevelDropdown()

	-- Set initial logging level text
	if LoggerState and LoggerState.GetLogLevelByPriority then
		local _, globalLevelData = LoggerState.GetLogLevelByPriority(LoggerState.GlobalLogLevel)
		if globalLevelData then
			TabState.LoggingLevelButton:SetText('Level: ' .. globalLevelData.color .. globalLevelData.display .. '|r')
		end
	end

	-- Build initial categories
	BuildLogSourceCategories()
end

----------------------------------------------------------------------------------------------------
-- Log Level Dropdown
----------------------------------------------------------------------------------------------------

---Setup the log level dropdown with level options
SetupLogLevelDropdown = function()
	if not TabState.LoggingLevelButton or not LoggerState then
		return
	end

	local orderedLevels = {}
	for logLevel, data in pairs(LoggerState.LOG_LEVELS) do
		table.insert(orderedLevels, { level = logLevel, data = data })
	end
	table.sort(orderedLevels, function(a, b)
		return a.data.priority < b.data.priority
	end)

	local loggerModule = LibAT:GetModule('Handler.Logger', true)

	TabState.LoggingLevelButton:SetupMenu(function(dropdown, rootDescription)
		for _, levelData in ipairs(orderedLevels) do
			local coloredText = levelData.data.color .. levelData.data.display .. '|r'
			local button = rootDescription:CreateButton(coloredText, function()
				LoggerState.GlobalLogLevel = levelData.data.priority
				if loggerModule and loggerModule.DB then
					loggerModule.DB.globalLogLevel = LoggerState.GlobalLogLevel
				end
				TabState.LoggingLevelButton:SetText('Level: ' .. levelData.data.color .. levelData.data.display .. '|r')
				UpdateLogsDisplay()
				-- Also update standalone Logger window
				if LibAT.Logger.UpdateLogDisplay then
					LibAT.Logger.UpdateLogDisplay()
				end
			end)
			button:SetTooltip(function(tooltip, elementDescription)
				GameTooltip_SetTitle(tooltip, levelData.data.display .. ' Level')
				GameTooltip_AddNormalLine(tooltip, 'Shows ' .. levelData.data.display:lower() .. ' messages and higher priority')
			end)
			if LoggerState.GlobalLogLevel == levelData.data.priority then
				button:SetRadio(true)
			end
		end
	end)
end
