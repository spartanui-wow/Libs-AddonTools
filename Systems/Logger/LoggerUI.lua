---@class LibAT
local LibAT = LibAT

-- This file contains all UI-related code for the Logger system
-- Handles window creation, navigation tree, filtering, search, and export

-- Import shared state (will be set by Logger.lua)
local logger, LoggerState

---Initialize the UI module with shared state from Logger
---@param loggerModule table The logger module
---@param state table The shared logger state
function LibAT.Logger.InitUI(loggerModule, state)
	logger = loggerModule
	LoggerState = state
end

-- Forward declaration of CreateCategoryTree (defined later, used by CreateLogSourceCategories)
local CreateCategoryTree

-- Function to create hierarchical log source tree (like AuctionFrame categories)
local function CreateLogSourceCategories()
	if not LoggerState.LogWindow then
		return
	end

	-- Don't try to build categories if DB isn't initialized yet
	if not logger.DB or not logger.DB.modules then
		return
	end

	-- Clear existing data
	LoggerState.LogWindow.Categories = {}
	LoggerState.ScrollListing = {}

	-- Organize log sources into hierarchical categories
	for sourceName, _ in pairs(logger.DB.modules) do
		local category, subCategory, subSubCategory, sourceType = LoggerState.ParseLogSource(sourceName)

		-- Initialize category if it doesn't exist
		if not LoggerState.LogWindow.Categories[category] then
			LoggerState.LogWindow.Categories[category] = {
				name = category,
				subCategories = {},
				expanded = LoggerState.AddonCategories[category] and LoggerState.AddonCategories[category].expanded or false,
				button = nil,
				-- Mark as addon category if it's in AddonCategories OR RegisteredAddons
				isAddonCategory = (LoggerState.AddonCategories[category] ~= nil) or (LoggerState.RegisteredAddons[category] ~= nil),
			}
		end

		if sourceType == 'subCategory' then
			-- This is a direct subCategory under the main category
			if not LoggerState.LogWindow.Categories[category].subCategories[subCategory] then
				LoggerState.LogWindow.Categories[category].subCategories[subCategory] = {
					name = subCategory,
					sourceName = sourceName,
					subSubCategories = {},
					expanded = false,
					button = nil,
					type = 'subCategory',
				}
			end
		elseif sourceType == 'subSubCategory' then
			-- This has a subSubCategory level
			if not LoggerState.LogWindow.Categories[category].subCategories[subCategory] then
				LoggerState.LogWindow.Categories[category].subCategories[subCategory] = {
					name = subCategory,
					subSubCategories = {},
					expanded = false,
					button = nil,
					type = 'subCategory',
				}
			end

			LoggerState.LogWindow.Categories[category].subCategories[subCategory].subSubCategories[subSubCategory] = {
				name = subSubCategory,
				sourceName = sourceName,
				button = nil,
				type = 'subSubCategory',
			}
		end

		table.insert(LoggerState.ScrollListing, {
			text = sourceName,
			value = sourceName,
			category = category,
			subCategory = subCategory,
			subSubCategory = subSubCategory,
			sourceType = sourceType,
		})
	end

	-- Sort categories and their contents
	local sortedCategories = {}
	for categoryName, categoryData in pairs(LoggerState.LogWindow.Categories) do
		table.insert(sortedCategories, categoryName)

		-- Sort subCategories
		local sortedSubCategories = {}
		for subCategoryName, _ in pairs(categoryData.subCategories) do
			table.insert(sortedSubCategories, subCategoryName)
		end
		table.sort(sortedSubCategories)
		categoryData.sortedSubCategories = sortedSubCategories

		-- Sort subSubCategories within each subCategory
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

	-- Create the visual tree structure
	CreateCategoryTree(sortedCategories)
end

-- Make this available to Logger.lua for when new modules are registered
LibAT.Logger.CreateLogSourceCategories = CreateLogSourceCategories

-- Function to create the visual category tree (styled like AuctionFrame's category list)
function CreateCategoryTree(sortedCategories)
	if not LoggerState.LogWindow or not LoggerState.LogWindow.ModuleTree then
		return
	end

	-- Clear existing buttons
	for _, button in pairs(LoggerState.LogWindow.categoryButtons) do
		button:Hide()
		button:SetParent(nil)
	end
	for _, button in pairs(LoggerState.LogWindow.moduleButtons) do
		button:Hide()
		button:SetParent(nil)
	end
	LoggerState.LogWindow.categoryButtons = {}
	LoggerState.LogWindow.moduleButtons = {}

	local yOffset = 0
	local buttonHeight = 21 -- Standard AuctionHouse button height

	for _, categoryName in ipairs(sortedCategories) do
		local categoryData = LoggerState.LogWindow.Categories[categoryName]
		local subCategoryCount = 0

		-- Count total items in this category (subCategories + subSubCategories)
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

		-- Check if this category only has a single "Core" subcategory (make it directly selectable)
		local isCoreOnly = (subCategoryCount == 1 and categoryData.sortedSubCategories and #categoryData.sortedSubCategories == 1 and categoryData.sortedSubCategories[1] == 'Core')

		if isCoreOnly then
			-- Create a directly selectable button (top-level category style, but selectable)
			local coreSubCategory = categoryData.subCategories['Core']
			local categoryButton = LibAT.UI.CreateFilterButton(LoggerState.LogWindow.ModuleTree, nil)
			categoryButton:SetPoint('TOPLEFT', LoggerState.LogWindow.ModuleTree, 'TOPLEFT', 3, yOffset)

			local categoryInfo = {
				type = 'category',
				name = categoryName,
				categoryIndex = categoryName,
				isToken = categoryData.isAddonCategory,
				selected = (LoggerState.ActiveModule == coreSubCategory.sourceName),
			}
			LibAT.UI.SetupFilterButton(categoryButton, categoryInfo)

			-- No expand/collapse indicator for core-only categories

			-- Make it selectable
			categoryButton:SetScript('OnClick', function(self)
				-- Update button states (clear all selected states)
				for _, btn in pairs(LoggerState.LogWindow.moduleButtons) do
					btn.SelectedTexture:Hide()
					btn:SetNormalFontObject(GameFontHighlightSmall)
				end
				-- Set this button as selected
				self.SelectedTexture:Show()
				self:SetNormalFontObject(GameFontNormalSmall)

				LoggerState.ActiveModule = coreSubCategory.sourceName
				LibAT.Logger.UpdateLogDisplay()
			end)

			-- Standard hover effects
			categoryButton:SetScript('OnEnter', function(self)
				self.HighlightTexture:Show()
			end)
			categoryButton:SetScript('OnLeave', function(self)
				self.HighlightTexture:Hide()
			end)

			table.insert(LoggerState.LogWindow.moduleButtons, categoryButton)
			yOffset = yOffset - (buttonHeight + 1)
		else
			-- Create expandable category button (has multiple subcategories)
			local categoryButton = LibAT.UI.CreateFilterButton(LoggerState.LogWindow.ModuleTree, 'LibAT_CategoryButton_' .. categoryName)
			categoryButton:SetPoint('TOPLEFT', LoggerState.LogWindow.ModuleTree, 'TOPLEFT', 3, yOffset)

			-- Set up category button using Blizzard's helper function
			local categoryInfo = {
				type = 'category',
				name = categoryName .. ' (' .. subCategoryCount .. ')',
				categoryIndex = categoryName,
				isToken = categoryData.isAddonCategory, -- Use isToken for external addons (matches Blizzard's pattern)
				selected = false,
			}
			LibAT.UI.SetupFilterButton(categoryButton, categoryInfo)

			-- Add expand/collapse indicator
			categoryButton.indicator = categoryButton:CreateTexture(nil, 'OVERLAY')
			categoryButton.indicator:SetSize(15, 15)
			categoryButton.indicator:SetPoint('LEFT', categoryButton, 'LEFT', 2, 0)
			if categoryData.expanded then
				categoryButton.indicator:SetAtlas('uitools-icon-minimize')
			else
				categoryButton.indicator:SetAtlas('uitools-icon-plus')
			end

			-- Override text color for gold category headers
			categoryButton.Text:SetTextColor(1, 0.82, 0)

			-- Category button functionality
			categoryButton:SetScript('OnClick', function(self)
				categoryData.expanded = not categoryData.expanded

				-- Persist expansion state for registered addon categories
				if categoryData.isAddonCategory and LoggerState.AddonCategories[categoryName] then
					LoggerState.AddonCategories[categoryName].expanded = categoryData.expanded
				end

				if categoryData.expanded then
					self.indicator:SetAtlas('uitools-icon-minimize')
				else
					self.indicator:SetAtlas('uitools-icon-plus')
				end
				CreateCategoryTree(sortedCategories) -- Rebuild tree
			end)

			-- Standard hover effects
			categoryButton:SetScript('OnEnter', function(self)
				self.HighlightTexture:Show()
			end)
			categoryButton:SetScript('OnLeave', function(self)
				self.HighlightTexture:Hide()
			end)

			categoryData.button = categoryButton
			table.insert(LoggerState.LogWindow.categoryButtons, categoryButton)
			yOffset = yOffset - (buttonHeight + 1)
		end

		-- Create subCategory and subSubCategory buttons if category is expanded (skip for core-only categories)
		if categoryData.expanded and not isCoreOnly then
			for _, subCategoryName in ipairs(categoryData.sortedSubCategories) do
				local subCategoryData = categoryData.subCategories[subCategoryName]

				-- Create subCategory button using the proper template
				local subCategoryButton = LibAT.UI.CreateFilterButton(LoggerState.LogWindow.ModuleTree, nil)
				subCategoryButton:SetPoint('TOPLEFT', LoggerState.LogWindow.ModuleTree, 'TOPLEFT', 3, yOffset)

				-- Set up subCategory button using Blizzard's helper function
				local subCategoryInfo = {
					type = 'subCategory',
					name = subCategoryName,
					subCategoryIndex = subCategoryName,
					selected = (LoggerState.ActiveModule == (subCategoryData.sourceName or subCategoryName)),
				}
				LibAT.UI.SetupFilterButton(subCategoryButton, subCategoryInfo) -- If this subCategory has subSubCategories, add expand/collapse indicator
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

				-- Standard hover effects
				subCategoryButton:SetScript('OnEnter', function(self)
					self.HighlightTexture:Show()
				end)
				subCategoryButton:SetScript('OnLeave', function(self)
					self.HighlightTexture:Hide()
				end)

				-- SubCategory functionality
				subCategoryButton:SetScript('OnClick', function(self)
					-- If this has subSubCategories, toggle expansion
					if subCategoryData.subSubCategories and next(subCategoryData.subSubCategories) then
						subCategoryData.expanded = not subCategoryData.expanded
						if self.indicator then
							if subCategoryData.expanded then
								self.indicator:SetAtlas('uitools-icon-minimize')
							else
								self.indicator:SetAtlas('uitools-icon-plus')
							end
						end
						CreateCategoryTree(sortedCategories) -- Rebuild tree
					else
						-- This is a selectable log source
						-- Update button states (clear all selected states)
						for _, btn in pairs(LoggerState.LogWindow.moduleButtons) do
							btn.SelectedTexture:Hide()
							btn:SetNormalFontObject(GameFontHighlightSmall)
						end
						-- Set this button as selected
						self.SelectedTexture:Show()
						self:SetNormalFontObject(GameFontNormalSmall)

						LoggerState.ActiveModule = subCategoryData.sourceName or subCategoryName
						LibAT.Logger.UpdateLogDisplay()
					end
				end)

				table.insert(LoggerState.LogWindow.moduleButtons, subCategoryButton)
				yOffset = yOffset - (buttonHeight + 1)

				-- Create subSubCategory buttons if subCategory is expanded
				if subCategoryData.expanded and subCategoryData.sortedSubSubCategories then
					for _, subSubCategoryName in ipairs(subCategoryData.sortedSubSubCategories) do
						local subSubCategoryData = subCategoryData.subSubCategories[subSubCategoryName]

						-- Create subSubCategory button using the proper template
						local subSubCategoryButton = LibAT.UI.CreateFilterButton(LoggerState.LogWindow.ModuleTree, nil)
						subSubCategoryButton:SetPoint('TOPLEFT', LoggerState.LogWindow.ModuleTree, 'TOPLEFT', 3, yOffset)

						-- Set up subSubCategory button using Blizzard's helper function
						local subSubCategoryInfo = {
							type = 'subSubCategory',
							name = subSubCategoryName,
							subSubCategoryIndex = subSubCategoryName,
							selected = (LoggerState.ActiveModule == subSubCategoryData.sourceName),
						}
						LibAT.UI.SetupFilterButton(subSubCategoryButton, subSubCategoryInfo) -- Standard hover effects
						subSubCategoryButton:SetScript('OnEnter', function(self)
							self.HighlightTexture:Show()
						end)
						subSubCategoryButton:SetScript('OnLeave', function(self)
							self.HighlightTexture:Hide()
						end)

						-- SubSubCategory selection functionality
						subSubCategoryButton:SetScript('OnClick', function(self)
							-- Update button states (clear all selected states)
							for _, btn in pairs(LoggerState.LogWindow.moduleButtons) do
								btn.SelectedTexture:Hide()
								btn:SetNormalFontObject(GameFontHighlightSmall)
							end
							-- Set this button as selected
							self.SelectedTexture:Show()
							self:SetNormalFontObject(GameFontNormalSmall)

							LoggerState.ActiveModule = subSubCategoryData.sourceName
							LibAT.Logger.UpdateLogDisplay()
						end)

						table.insert(LoggerState.LogWindow.moduleButtons, subSubCategoryButton)
						yOffset = yOffset - (buttonHeight + 1)
					end
				end
			end
		end
	end

	-- Update tree height
	local totalHeight = math.abs(yOffset) + 20
	LoggerState.LogWindow.ModuleTree:SetHeight(math.max(totalHeight, LoggerState.LogWindow.ModuleScrollFrame:GetHeight()))
end

local function CreateLogWindow()
	if LoggerState.LogWindow then
		return
	end

	-- Create base window using LibAT.UI
	LoggerState.LogWindow = LibAT.UI.CreateWindow({
		name = 'LibAT_LogWindow',
		title = '|cffffffffSpartan|cffe21f1fUI|r Logging',
		width = 800,
		height = 538,
		portrait = 'Interface\\AddOns\\SpartanUI\\images\\LogoSpartanUI',
	})

	-- Create control frame (top bar for search/filters)
	LoggerState.LogWindow.ControlFrame = LibAT.UI.CreateControlFrame(LoggerState.LogWindow)

	-- Create header anchor (slightly offset for controls)
	LoggerState.LogWindow.HeaderAnchor = CreateFrame('Frame', nil, LoggerState.LogWindow)
	LoggerState.LogWindow.HeaderAnchor:SetPoint('TOPLEFT', LoggerState.LogWindow.ControlFrame, 'TOPLEFT', 53, 0)
	LoggerState.LogWindow.HeaderAnchor:SetPoint('TOPRIGHT', LoggerState.LogWindow.ControlFrame, 'TOPRIGHT', -16, 0)
	LoggerState.LogWindow.HeaderAnchor:SetHeight(28)

	-- Search all modules checkbox (leftmost)
	LoggerState.LogWindow.SearchAllModules = LibAT.UI.CreateCheckbox(LoggerState.LogWindow.HeaderAnchor, 'Search All Modules')
	LoggerState.LogWindow.SearchAllModules:SetPoint('LEFT', LoggerState.LogWindow.HeaderAnchor, 'LEFT', 0, 0)
	LoggerState.LogWindow.SearchAllModules:SetScript('OnClick', function(self)
		LoggerState.SearchAllModules = self:GetChecked()
		LibAT.Logger.UpdateLogDisplay()
	end)
	LoggerState.LogWindow.SearchAllModulesLabel = LoggerState.LogWindow.SearchAllModules.Label

	-- Search box positioned after checkbox
	LoggerState.LogWindow.SearchBox = LibAT.UI.CreateSearchBox(LoggerState.LogWindow.HeaderAnchor, 241)
	LoggerState.LogWindow.SearchBox:SetPoint('LEFT', LoggerState.LogWindow.SearchAllModulesLabel, 'RIGHT', 10, 0)
	LoggerState.LogWindow.SearchBox:SetScript('OnTextChanged', function(self)
		LoggerState.CurrentSearchTerm = self:GetText()
		LibAT.Logger.UpdateLogDisplay()
	end)
	LoggerState.LogWindow.SearchBox:SetScript('OnEscapePressed', function(self)
		self:SetText('')
		self:ClearFocus()
		LoggerState.CurrentSearchTerm = ''
		LibAT.Logger.UpdateLogDisplay()
	end)

	-- Settings button (workshop icon, positioned at right)
	LoggerState.LogWindow.OpenSettings =
		LibAT.UI.CreateIconButton(LoggerState.LogWindow.HeaderAnchor, 'Warfronts-BaseMapIcons-Empty-Workshop', 'Warfronts-BaseMapIcons-Alliance-Workshop', 'Warfronts-BaseMapIcons-Horde-Workshop')
	LoggerState.LogWindow.OpenSettings:SetPoint('RIGHT', LoggerState.LogWindow.HeaderAnchor, 'RIGHT', 0, 0)
	LoggerState.LogWindow.OpenSettings:SetScript('OnClick', function()
		LibAT.Options:ToggleOptions({ 'Help', 'Logging' })
	end)

	-- Logging Level dropdown positioned before settings button
	LoggerState.LogWindow.LoggingLevelButton = LibAT.UI.CreateDropdown(LoggerState.LogWindow.HeaderAnchor, 'Logging Level', 120, 22)
	LoggerState.LogWindow.LoggingLevelButton:SetPoint('RIGHT', LoggerState.LogWindow.OpenSettings, 'LEFT', -10, 0)

	-- Set initial dropdown text based on current global level
	local _, globalLevelData = LoggerState.GetLogLevelByPriority(LoggerState.GlobalLogLevel)
	if globalLevelData then
		LoggerState.LogWindow.LoggingLevelButton:SetText('Logging Level')
	end

	-- Create main content area
	LoggerState.LogWindow.MainContent = LibAT.UI.CreateContentFrame(LoggerState.LogWindow, LoggerState.LogWindow.ControlFrame)

	-- Create left panel for module navigation
	LoggerState.LogWindow.LeftPanel = LibAT.UI.CreateLeftPanel(LoggerState.LogWindow.MainContent)

	-- Create scroll frame for module tree (will be populated by CreateLogSourceCategories)
	LoggerState.LogWindow.ModuleScrollFrame = CreateFrame('ScrollFrame', 'LibAT_ModuleScrollFrame', LoggerState.LogWindow.LeftPanel)
	LoggerState.LogWindow.ModuleScrollFrame:SetPoint('TOPLEFT', LoggerState.LogWindow.LeftPanel, 'TOPLEFT', 2, -7)
	LoggerState.LogWindow.ModuleScrollFrame:SetPoint('BOTTOMRIGHT', LoggerState.LogWindow.LeftPanel, 'BOTTOMRIGHT', 0, 2)

	-- Create minimal scrollbar for left panel
	LoggerState.LogWindow.ModuleScrollFrame.ScrollBar = CreateFrame('EventFrame', nil, LoggerState.LogWindow.ModuleScrollFrame, 'MinimalScrollBar')
	LoggerState.LogWindow.ModuleScrollFrame.ScrollBar:SetPoint('TOPLEFT', LoggerState.LogWindow.ModuleScrollFrame, 'TOPRIGHT', 2, 0)
	LoggerState.LogWindow.ModuleScrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', LoggerState.LogWindow.ModuleScrollFrame, 'BOTTOMRIGHT', 2, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(LoggerState.LogWindow.ModuleScrollFrame, LoggerState.LogWindow.ModuleScrollFrame.ScrollBar)

	LoggerState.LogWindow.ModuleTree = CreateFrame('Frame', 'LibAT_ModuleTree', LoggerState.LogWindow.ModuleScrollFrame)
	LoggerState.LogWindow.ModuleScrollFrame:SetScrollChild(LoggerState.LogWindow.ModuleTree)
	LoggerState.LogWindow.ModuleTree:SetSize(160, 1)

	-- Create right panel for log display
	LoggerState.LogWindow.RightPanel = LibAT.UI.CreateRightPanel(LoggerState.LogWindow.MainContent, LoggerState.LogWindow.LeftPanel)

	-- Create scrollable text display for logs
	LoggerState.LogWindow.TextPanel, LoggerState.LogWindow.EditBox = LibAT.UI.CreateScrollableTextDisplay(LoggerState.LogWindow.RightPanel)
	LoggerState.LogWindow.TextPanel:SetPoint('TOPLEFT', LoggerState.LogWindow.RightPanel, 'TOPLEFT', 6, -6)
	LoggerState.LogWindow.TextPanel:SetPoint('BOTTOMRIGHT', LoggerState.LogWindow.RightPanel, 'BOTTOMRIGHT', 0, 2)
	LoggerState.LogWindow.EditBox:SetWidth(LoggerState.LogWindow.TextPanel:GetWidth() - 20)
	LoggerState.LogWindow.EditBox:SetText('No logs active - select a module from the left or enable "Search All Modules"')

	-- Create action buttons at bottom
	local actionButtons = LibAT.UI.CreateActionButtons(LoggerState.LogWindow, {
		{
			text = 'Clear',
			width = 70,
			onClick = function()
				LibAT.Logger.ClearCurrentLogs()
			end,
		},
		{
			text = 'Export',
			width = 70,
			onClick = function()
				LibAT.Logger.ExportCurrentLogs()
			end,
		},
	})
	LoggerState.LogWindow.ClearButton = actionButtons[1]
	LoggerState.LogWindow.ExportButton = actionButtons[2]

	-- Reload UI button positioned in bottom left
	LoggerState.LogWindow.ReloadButton = LibAT.UI.CreateButton(LoggerState.LogWindow, 80, 22, 'Reload UI')
	LoggerState.LogWindow.ReloadButton:SetPoint('BOTTOMLEFT', LoggerState.LogWindow, 'BOTTOMLEFT', 3, 4)
	LoggerState.LogWindow.ReloadButton:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)

	-- Pause button anchored left of action buttons
	LoggerState.LogWindow.PauseButton = LibAT.UI.CreateButton(LoggerState.LogWindow, 70, 22, LoggerState.Paused and 'Resume' or 'Pause')
	LoggerState.LogWindow.PauseButton:SetPoint('RIGHT', LoggerState.LogWindow.ClearButton, 'LEFT', -10, 0)
	LoggerState.LogWindow.PauseButton:SetScript('OnClick', function()
		LoggerState.Paused = not LoggerState.Paused
		LoggerState.LogWindow.PauseButton:SetText(LoggerState.Paused and 'Resume' or 'Pause')
		if not LoggerState.Paused then
			LibAT.Logger.UpdateLogDisplay(true)
		end
	end)

	-- Auto-scroll checkbox left of Pause button
	LoggerState.LogWindow.AutoScroll = LibAT.UI.CreateCheckbox(LoggerState.LogWindow, 'Auto-scroll')
	LoggerState.LogWindow.AutoScroll:SetPoint('RIGHT', LoggerState.LogWindow.PauseButton, 'LEFT', -10, 0)
	LoggerState.LogWindow.AutoScroll:SetChecked(LoggerState.AutoScrollEnabled)

	-- Initialize data structures
	LoggerState.LogWindow.Categories = {}
	LoggerState.LogWindow.categoryButtons = {}
	LoggerState.LogWindow.moduleButtons = {}

	-- Build log source categories
	CreateLogSourceCategories()

	-- Setup dropdown functionality
	LibAT.Logger.SetupLogLevelDropdowns()

	-- Store references for compatibility
	LoggerState.LogWindow.NamespaceListings = LoggerState.LogWindow.ModuleScrollFrame
	LoggerState.LogWindow.OutputSelect = LoggerState.LogWindow.LeftPanel
end

-- Make CreateLogWindow available to Logger.lua
LibAT.Logger.CreateLogWindow = CreateLogWindow

-- Function to highlight search terms in text
local function HighlightSearchTerm(text, searchTerm)
	if not searchTerm or searchTerm == '' then
		return text
	end

	-- Case-insensitive search and replace with highlighting
	local highlightColor = '|cffff00ff' -- Bright magenta for search highlights
	local resetColor = '|r'

	-- Escape special characters in search term for pattern matching
	local escapedTerm = searchTerm:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])', '%%%1')

	-- For case-insensitive highlighting, we need to find and replace manually
	-- since Lua patterns don't support case-insensitive flags
	local result = text
	local searchLower = escapedTerm:lower()
	local pos = 1

	while pos <= #result do
		-- Find the next occurrence (case-insensitive)
		local textLower = result:lower()
		local startPos, endPos = textLower:find(searchLower, pos, true)

		if not startPos then
			break
		end

		-- Extract the actual text with original case
		local actualMatch = result:sub(startPos, endPos)
		local highlightedMatch = highlightColor .. actualMatch .. resetColor

		-- Replace this occurrence
		result = result:sub(1, startPos - 1) .. highlightedMatch .. result:sub(endPos + 1)

		-- Move past this replacement
		pos = startPos + #highlightedMatch
	end

	return result
end

-- Function to check if a log entry matches the search criteria
local function MatchesSearchCriteria(logEntry, searchTerm, logLevel)
	-- Check log level first
	local entryLogLevel = LoggerState.LOG_LEVELS[logEntry.level]
	if not entryLogLevel or entryLogLevel.priority < logLevel then
		return false
	end

	-- Check search term
	if searchTerm and searchTerm ~= '' then
		return logEntry.message:lower():find(searchTerm:lower(), 1, true) ~= nil
	end

	return true
end

-- Function to update the log display based on current module and filter settings
---@param force? boolean Skip pause check (used by Resume button)
local function UpdateLogDisplay(force)
	if not LoggerState.LogWindow or not LoggerState.LogWindow.EditBox then
		return
	end

	if LoggerState.Paused and not force then
		return
	end

	local logText = ''
	local totalEntries = 0
	local filteredCount = 0
	local searchedCount = 0

	if LoggerState.SearchAllModules then
		-- Search across all modules
		logText = 'Search Results Across All Modules:\n\n'

		for moduleName, logs in pairs(LoggerState.LogMessages) do
			local moduleLogLevel = LoggerState.ModuleLogLevels[moduleName] or 0
			local effectiveLogLevel = moduleLogLevel > 0 and moduleLogLevel or LoggerState.GlobalLogLevel

			local moduleMatches = {}
			for _, logEntry in ipairs(logs) do
				totalEntries = totalEntries + 1
				if MatchesSearchCriteria(logEntry, LoggerState.CurrentSearchTerm, effectiveLogLevel) then
					table.insert(moduleMatches, logEntry)
					filteredCount = filteredCount + 1
				end
			end

			if #moduleMatches > 0 then
				logText = logText .. '=== ' .. moduleName .. ' (' .. #moduleMatches .. ' entries) ===\n'
				for _, logEntry in ipairs(moduleMatches) do
					local highlightedText = HighlightSearchTerm(logEntry.formattedMessage, LoggerState.CurrentSearchTerm)
					logText = logText .. highlightedText .. '\n'
					searchedCount = searchedCount + 1
				end
				logText = logText .. '\n'
			end
		end

		if searchedCount == 0 then
			logText = logText .. 'No logs match the current search and filter criteria.'
		else
			logText = 'Search Results: ' .. searchedCount .. ' matches across all modules\n' .. 'Total entries: ' .. totalEntries .. ' | Filtered: ' .. filteredCount .. '\n\n' .. logText
		end
	else
		-- Single module display
		if not LoggerState.ActiveModule then
			LoggerState.LogWindow.EditBox:SetText('No module selected - choose a module from the left or enable "Search All Modules"')
			return
		end

		local logs = LoggerState.LogMessages[LoggerState.ActiveModule] or {}
		totalEntries = #logs

		if totalEntries == 0 then
			LoggerState.LogWindow.EditBox:SetText('No logs for module: ' .. LoggerState.ActiveModule)
			return
		end

		-- Get current module log level for filtering
		local moduleLogLevel = LoggerState.ModuleLogLevels[LoggerState.ActiveModule] or 0
		local effectiveLogLevel = moduleLogLevel > 0 and moduleLogLevel or LoggerState.GlobalLogLevel

		local matchingEntries = {}
		for _, logEntry in ipairs(logs) do
			if MatchesSearchCriteria(logEntry, LoggerState.CurrentSearchTerm, effectiveLogLevel) then
				table.insert(matchingEntries, logEntry)
				filteredCount = filteredCount + 1
			end
		end

		-- Build the display text
		local searchInfo = ''
		if LoggerState.CurrentSearchTerm and LoggerState.CurrentSearchTerm ~= '' then
			searchInfo = ' | Search: "' .. LoggerState.CurrentSearchTerm .. '"'
		end

		logText = 'Logs for ' .. LoggerState.ActiveModule .. ' (' .. totalEntries .. ' total, ' .. filteredCount .. ' shown' .. searchInfo .. '):\n\n'

		if #matchingEntries > 0 then
			for _, logEntry in ipairs(matchingEntries) do
				local highlightedText = HighlightSearchTerm(logEntry.formattedMessage, LoggerState.CurrentSearchTerm)
				logText = logText .. highlightedText .. '\n'
			end
		else
			logText = logText .. 'No logs match current filter and search criteria.'
		end
	end

	LoggerState.LogWindow.EditBox:SetText(logText)

	-- Auto-scroll to bottom if enabled
	if LoggerState.LogWindow.AutoScroll and LoggerState.LogWindow.AutoScroll:GetChecked() and LoggerState.LogWindow.EditBox then
		LoggerState.LogWindow.EditBox:SetCursorPosition(string.len(logText))
	end

	-- Update logging level button text with color
	if LoggerState.LogWindow.LoggingLevelButton then
		local _, globalLevelData = LoggerState.GetLogLevelByPriority(LoggerState.GlobalLogLevel)
		if globalLevelData then
			local coloredButtonText = 'Log Level: ' .. globalLevelData.color .. globalLevelData.display .. '|r'
			LoggerState.LogWindow.LoggingLevelButton:SetText(coloredButtonText)
		end
	end
end

-- Make UpdateLogDisplay available to Logger.lua
LibAT.Logger.UpdateLogDisplay = UpdateLogDisplay

-- Function to clear logs for the current module or all modules
local function ClearCurrentLogs()
	if LoggerState.SearchAllModules then
		-- Clear all logs
		for moduleName in pairs(LoggerState.LogMessages) do
			LoggerState.LogMessages[moduleName] = {}
		end
		print('|cFF00FF00SpartanUI Logging:|r All logs cleared.')
	else
		-- Clear current module logs
		if LoggerState.ActiveModule and LoggerState.LogMessages[LoggerState.ActiveModule] then
			LoggerState.LogMessages[LoggerState.ActiveModule] = {}
			print('|cFF00FF00SpartanUI Logging:|r Logs cleared for module: ' .. LoggerState.ActiveModule)
		else
			print('|cFFFFFF00SpartanUI Logging:|r No active module selected.')
		end
	end

	UpdateLogDisplay()
end

LibAT.Logger.ClearCurrentLogs = ClearCurrentLogs

-- Function to export current logs to a copyable format
local function ExportCurrentLogs()
	if not LoggerState.LogWindow then
		return
	end

	-- Create export frame if it doesn't exist
	if not LoggerState.LogWindow.ExportFrame then
		LoggerState.LogWindow.ExportFrame = CreateFrame('Frame', 'LibAT_LogExportFrame', UIParent, 'ButtonFrameTemplate')
		LoggerState.LogWindow.ExportFrame:SetSize(500, 400)
		LoggerState.LogWindow.ExportFrame:SetPoint('CENTER', UIParent, 'CENTER', 0, 0)
		LoggerState.LogWindow.ExportFrame:SetFrameStrata('DIALOG')
		LoggerState.LogWindow.ExportFrame:Hide()

		-- Set the portrait (with safety checks)
		if LoggerState.LogWindow.ExportFrame.portrait then
			if LoggerState.LogWindow.ExportFrame.portrait.SetTexture then
				LoggerState.LogWindow.ExportFrame.portrait:SetTexture('Interface\\AddOns\\SpartanUI\\images\\LogoSpartanUI')
			end
		end

		-- Set title
		LoggerState.LogWindow.ExportFrame:SetTitle('Export Logs')

		-- Scroll frame for export text (properly styled)
		LoggerState.LogWindow.ExportFrame.ScrollFrame = CreateFrame('ScrollFrame', nil, LoggerState.LogWindow.ExportFrame, 'UIPanelScrollFrameTemplate')
		LoggerState.LogWindow.ExportFrame.ScrollFrame:SetPoint('TOPLEFT', LoggerState.LogWindow.ExportFrame.TitleBar, 'BOTTOMLEFT', 0, -10)
		LoggerState.LogWindow.ExportFrame.ScrollFrame:SetPoint('BOTTOMRIGHT', LoggerState.LogWindow.ExportFrame, 'BOTTOMRIGHT', -26, 40)

		LoggerState.LogWindow.ExportFrame.EditBox = CreateFrame('EditBox', nil, LoggerState.LogWindow.ExportFrame.ScrollFrame)
		LoggerState.LogWindow.ExportFrame.EditBox:SetMultiLine(true)
		LoggerState.LogWindow.ExportFrame.EditBox:SetFontObject('GameFontHighlightSmall')
		LoggerState.LogWindow.ExportFrame.EditBox:SetWidth(LoggerState.LogWindow.ExportFrame.ScrollFrame:GetWidth() - 20)
		LoggerState.LogWindow.ExportFrame.EditBox:SetAutoFocus(false)
		LoggerState.LogWindow.ExportFrame.EditBox:SetTextColor(1, 1, 1) -- White text
		LoggerState.LogWindow.ExportFrame.EditBox:SetScript('OnTextChanged', function(self)
			ScrollingEdit_OnTextChanged(self, self:GetParent())
		end)
		LoggerState.LogWindow.ExportFrame.EditBox:SetScript('OnCursorChanged', function(self, x, y, w, h)
			ScrollingEdit_OnCursorChanged(self, x, y - 10, w, h)
		end)
		LoggerState.LogWindow.ExportFrame.ScrollFrame:SetScrollChild(LoggerState.LogWindow.ExportFrame.EditBox)

		-- Instructions (styled like Blizzard help text)
		LoggerState.LogWindow.ExportFrame.Instructions = LoggerState.LogWindow.ExportFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		LoggerState.LogWindow.ExportFrame.Instructions:SetText('Select all text (Ctrl+A) and copy (Ctrl+C) to export logs')
		LoggerState.LogWindow.ExportFrame.Instructions:SetPoint('BOTTOM', LoggerState.LogWindow.ExportFrame, 'BOTTOM', 0, 15)
		LoggerState.LogWindow.ExportFrame.Instructions:SetTextColor(1, 0.82, 0) -- Gold color like other instructions
	end

	-- Generate export text
	local exportText = '=== SpartanUI Log Export ===\n'
	exportText = exportText .. 'Generated: ' .. date('%Y-%m-%d %H:%M:%S') .. '\n'
	exportText = exportText .. 'Global Log Level: ' .. (LoggerState.GetLogLevelByPriority(LoggerState.GlobalLogLevel) or 'Unknown') .. '\n\n'

	if LoggerState.SearchAllModules then
		exportText = exportText .. '=== ALL MODULES ===\n\n'
		for moduleName, logs in pairs(LoggerState.LogMessages) do
			if #logs > 0 then
				exportText = exportText .. '--- Module: ' .. moduleName .. ' (' .. #logs .. ' entries) ---\n'

				local moduleLogLevel = LoggerState.ModuleLogLevels[moduleName] or 0
				local effectiveLogLevel = moduleLogLevel > 0 and moduleLogLevel or LoggerState.GlobalLogLevel

				for _, logEntry in ipairs(logs) do
					local entryLogLevel = LoggerState.LOG_LEVELS[logEntry.level]
					if entryLogLevel and entryLogLevel.priority >= effectiveLogLevel then
						-- Remove color codes for export
						local cleanMessage = logEntry.formattedMessage:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
						exportText = exportText .. cleanMessage .. '\n'
					end
				end
				exportText = exportText .. '\n'
			end
		end
	else
		if LoggerState.ActiveModule and LoggerState.LogMessages[LoggerState.ActiveModule] then
			exportText = exportText .. '=== Module: ' .. LoggerState.ActiveModule .. ' ===\n\n'

			local logs = LoggerState.LogMessages[LoggerState.ActiveModule]
			local moduleLogLevel = LoggerState.ModuleLogLevels[LoggerState.ActiveModule] or 0
			local effectiveLogLevel = moduleLogLevel > 0 and moduleLogLevel or LoggerState.GlobalLogLevel

			for _, logEntry in ipairs(logs) do
				local entryLogLevel = LoggerState.LOG_LEVELS[logEntry.level]
				if entryLogLevel and entryLogLevel.priority >= effectiveLogLevel then
					-- Apply search filtering if active
					if not LoggerState.CurrentSearchTerm or LoggerState.CurrentSearchTerm == '' or logEntry.message:lower():find(LoggerState.CurrentSearchTerm:lower(), 1, true) then
						-- Remove color codes for export
						local cleanMessage = logEntry.formattedMessage:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
						exportText = exportText .. cleanMessage .. '\n'
					end
				end
			end
		else
			exportText = exportText .. 'No active module selected.\n'
		end
	end

	exportText = exportText .. '\n=== End of Export ==='

	-- Set text and show frame
	LoggerState.LogWindow.ExportFrame.EditBox:SetText(exportText)
	LoggerState.LogWindow.ExportFrame:Show()

	-- Select all text for easy copying
	LoggerState.LogWindow.ExportFrame.EditBox:SetFocus()
	LoggerState.LogWindow.ExportFrame.EditBox:HighlightText()

	print('|cFF00FF00SpartanUI Logging:|r Logs exported. Use Ctrl+A and Ctrl+C to copy.')
end

LibAT.Logger.ExportCurrentLogs = ExportCurrentLogs

-- Setup the log level dropdown functionality
local function SetupLogLevelDropdowns()
	-- Create ordered list of log levels by priority
	local orderedLevels = {}
	for logLevel, data in pairs(LoggerState.LOG_LEVELS) do
		table.insert(orderedLevels, { level = logLevel, data = data })
	end
	table.sort(orderedLevels, function(a, b)
		return a.data.priority < b.data.priority
	end)

	-- Setup logging level filter button (AH style)
	LoggerState.LogWindow.LoggingLevelButton:SetupMenu(function(dropdown, rootDescription)
		-- Add log levels in priority order with colored text
		for _, levelData in ipairs(orderedLevels) do
			-- Create colored display text
			local coloredText = levelData.data.color .. levelData.data.display .. '|r'
			local button = rootDescription:CreateButton(coloredText, function()
				LoggerState.GlobalLogLevel = levelData.data.priority
				logger.DB.globalLogLevel = LoggerState.GlobalLogLevel
				-- Update button text with colored level name
				local coloredButtonText = 'Level: ' .. levelData.data.color .. levelData.data.display .. '|r'
				LoggerState.LogWindow.LoggingLevelButton:SetText(coloredButtonText)
				UpdateLogDisplay() -- Refresh current view
			end)
			-- Add tooltip
			button:SetTooltip(function(tooltip, elementDescription)
				GameTooltip_SetTitle(tooltip, levelData.data.display .. ' Level')
				GameTooltip_AddNormalLine(tooltip, 'Shows ' .. levelData.data.display:lower() .. ' messages and higher priority')
			end)
			-- Check current selection
			if LoggerState.GlobalLogLevel == levelData.data.priority then
				button:SetRadio(true)
			end
		end
	end)
end

LibAT.Logger.SetupLogLevelDropdowns = SetupLogLevelDropdowns
