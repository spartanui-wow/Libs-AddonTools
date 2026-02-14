---@class LibAT
local LibAT = LibAT
local logger = LibAT:NewModule('Handler.Logger') ---@class LibAT.LoggerInternal : AceAddon, AceEvent-3.0, AceConsole-3.0
logger.description = 'SpartanUI Logging System'

----------------------------------------------------------------------------------------------------
-- Type Definitions for Logger System
----------------------------------------------------------------------------------------------------

---@alias LogLevel
---| "debug"    # Detailed debugging information
---| "info"     # General informational messages
---| "warning"  # Warning conditions
---| "error"    # Error conditions
---| "critical" # Critical system failures

---Logger object returned by RegisterAddon
---@class LoggerObject
---@field log fun(message: string, level?: LogLevel): nil
---@field debug fun(message: string): nil
---@field info fun(message: string): nil
---@field warning fun(message: string): nil
---@field error fun(message: string): nil
---@field critical fun(message: string): nil
---@field RegisterCategory fun(self: LoggerObject, categoryName: string): LoggerObject
---@field Categories table<string, LoggerObject>

---Internal Logger Handler (LibAT.Handlers.Logger)
---@class LibAT.LoggerInternal : LibAT.Module
---@field description string

---External Logger API (LibAT.Logger) - for third-party addons
---@class LibAT.Logger
---@field RegisterAddon fun(addonName: string, categories?: string[]): LoggerObject

----------------------------------------------------------------------------------------------------
-- Shared State Setup
----------------------------------------------------------------------------------------------------

local LoggerState = {
	-- UI Components
	LogWindow = nil, ---@type table|Frame
	LogMessages = {},
	ScrollListing = {},
	ActiveModule = nil,

	-- Log Levels Configuration
	LOG_LEVELS = {
		['debug'] = { color = '|cff888888', priority = 1, display = 'Debug' },
		['info'] = { color = '|cff00ff00', priority = 2, display = 'Info' },
		['warning'] = { color = '|cffffff00', priority = 3, display = 'Warning' },
		['error'] = { color = '|cffff0000', priority = 4, display = 'Error' },
		['critical'] = { color = '|cffff00ff', priority = 5, display = 'Critical' },
	},

	-- Global and per-module log level settings
	GlobalLogLevel = 2, -- Default to 'info' and above
	ModuleLogLevels = {}, -- Per-module overrides

	-- Search and UI state
	CurrentSearchTerm = '',
	SearchAllModules = false,
	AutoScrollEnabled = true,
	Paused = false,

	-- Registration system for external addons
	RegisteredAddons = {}, -- Simple addons registered under "External Addons"
	AddonCategories = {}, -- Complex addons with custom categories
	AddonLoggers = {}, -- Cache of logger functions by addon name
}

----------------------------------------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------------------------------------

-- Helper function to get log level by priority
local function GetLogLevelByPriority(priority)
	for level, data in pairs(LoggerState.LOG_LEVELS) do
		if data.priority == priority then
			return level, data
		end
	end
	return 'info', LoggerState.LOG_LEVELS['info'] -- Default fallback
end

-- Store helper function in LoggerState for module access
LoggerState.GetLogLevelByPriority = GetLogLevelByPriority

-- Function to parse and categorize log sources using hierarchical system
-- Returns: category, subCategory, subSubCategory, sourceType
local function ParseLogSource(sourceName)
	-- Check if this is a registered simple addon (gets its own top-level category with Core subcategory)
	if LoggerState.RegisteredAddons[sourceName] then
		return sourceName, 'Core', nil, 'subCategory'
	end

	-- Check if this is part of a registered addon category hierarchy
	for addonName, categoryData in pairs(LoggerState.AddonCategories) do
		-- Escape magic characters in addon name for pattern matching
		local escapedName = addonName:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%1')

		-- Check for three-level pattern: "AddonName.subCategory.subSubCategory"
		local subCategory, subSubCategory = sourceName:match('^' .. escapedName .. '%.([^%.]+)%.(.+)')
		if subCategory and subSubCategory then
			return addonName, subCategory, subSubCategory, 'subSubCategory'
		end

		-- Check for two-level pattern: "AddonName.subCategory"
		local subCategoryOnly = sourceName:match('^' .. escapedName .. '%.(.+)')
		if subCategoryOnly then
			return addonName, subCategoryOnly, nil, 'subCategory'
		end
	end

	-- Fall back to LibAT internal categorization with hierarchy support
	local internalCategories = {
		['Core'] = { 'Core', 'Framework', 'Events', 'Options', 'Database', 'Profiles' },
		['UI Components'] = { 'UnitFrames', 'Minimap', 'Artwork', 'ActionBars', 'ChatBox', 'Tooltips' },
		['Handlers'] = { 'Handler', 'Logger', 'ChatCommands', 'Compatibility' },
		['Development'] = { 'Debug', 'Test', 'Dev', 'Plugin' },
	}

	-- Check for internal three-level hierarchy: "System.Component.SubComponent"
	local parts = {}
	for part in sourceName:gmatch('[^%.]+') do
		table.insert(parts, part)
	end

	if #parts >= 3 then
		-- Check if first part matches any internal category keywords
		for category, keywords in pairs(internalCategories) do
			for _, keyword in ipairs(keywords) do
				if parts[1]:lower():find(keyword:lower()) or parts[2]:lower():find(keyword:lower()) then
					return category, parts[1] .. '.' .. parts[2], table.concat(parts, '.', 3), 'subSubCategory'
				end
			end
		end
	elseif #parts == 2 then
		-- Check for two-level internal hierarchy
		for category, keywords in pairs(internalCategories) do
			for _, keyword in ipairs(keywords) do
				if parts[1]:lower():find(keyword:lower()) then
					return category, parts[1], parts[2], 'subSubCategory'
				end
			end
		end
	end

	-- Single-level categorization fallback
	for category, keywords in pairs(internalCategories) do
		for _, keyword in ipairs(keywords) do
			if sourceName:lower():find(keyword:lower()) then
				return category, sourceName, nil, 'subCategory'
			end
		end
	end

	-- Default category for unmatched sources
	return 'Other Sources', sourceName, nil, 'subCategory'
end

-- Store helper function in LoggerState for module access
LoggerState.ParseLogSource = ParseLogSource

----------------------------------------------------------------------------------------------------
-- External API - LibAT.Logger (for third-party addons)
----------------------------------------------------------------------------------------------------

-- Initialize the external Logger API
LibAT.Logger = {} ---@class LibAT.Logger

-- Expose LoggerState for DevUI Logs tab (shared data, no duplication)
LibAT.Logger.GetState = function()
	return LoggerState
end

---Helper function to create a logger object for a module
---@param addonName string The addon name
---@param moduleName string The full module name (addonName or addonName.category)
---@return LoggerObject
local function CreateLoggerObject(addonName, moduleName)
	---@type LoggerObject
	local loggerObj = {
		Categories = {},
	}

	-- Generic log function
	loggerObj.log = function(message, level)
		LibAT.Log(message, moduleName, level)
	end

	-- Shorthand methods for each log level
	loggerObj.debug = function(message)
		LibAT.Log(message, moduleName, 'debug')
	end

	loggerObj.info = function(message)
		LibAT.Log(message, moduleName, 'info')
	end

	loggerObj.warning = function(message)
		LibAT.Log(message, moduleName, 'warning')
	end

	loggerObj.error = function(message)
		LibAT.Log(message, moduleName, 'error')
	end

	loggerObj.critical = function(message)
		LibAT.Log(message, moduleName, 'critical')
	end

	-- RegisterCategory method for dynamic category creation
	-- Accepts a string name or an AceAddon module table (extracts name automatically)
	loggerObj.RegisterCategory = function(self, categoryName)
		-- Support AceAddon module tables: extract name automatically
		if type(categoryName) == 'table' then
			if categoryName.GetName and type(categoryName.GetName) == 'function' then
				categoryName = categoryName:GetName()
			elseif categoryName.name and type(categoryName.name) == 'string' then
				categoryName = categoryName.name
			else
				error('RegisterCategory: table passed but could not extract a name (no :GetName() or .name field)')
			end
		end

		if not categoryName or categoryName == '' or type(categoryName) ~= 'string' then
			error('RegisterCategory: categoryName must be a non-empty string or a module table with :GetName()')
		end

		-- Check for invalid characters
		if categoryName:find('%.') then
			error('RegisterCategory: categoryName "' .. categoryName .. '" cannot contain dots (.)')
		end

		-- If category already exists, return it
		if self.Categories[categoryName] then
			return self.Categories[categoryName]
		end

		-- Create the full module name
		local fullModuleName = addonName .. '.' .. categoryName

		-- Create new logger object for this category
		local categoryLogger = CreateLoggerObject(addonName, fullModuleName)

		-- Store in Categories table
		self.Categories[categoryName] = categoryLogger

		-- Initialize in database if logger is ready
		if logger.DB then
			logger.DB.modules[fullModuleName] = true
		end

		-- Update category registration
		if not LoggerState.AddonCategories[addonName] then
			LoggerState.AddonCategories[addonName] = {
				subcategories = {},
				expanded = false,
			}
		end
		table.insert(LoggerState.AddonCategories[addonName].subcategories, categoryName)

		-- Rebuild UI if window exists
		if LoggerState.LogWindow and LoggerState.LogWindow.Categories then
			LibAT.Logger.CreateLogSourceCategories()
		end

		return categoryLogger
	end

	return loggerObj
end

---Register an addon for logging with optional pre-defined categories
---@param addonName string Name of the addon to register
---@param categories? string[] Optional array of pre-defined category names
---@return LoggerObject logger Logger object with methods and category support
function LibAT.Logger.RegisterAddon(addonName, categories)
	-- Protect against incorrect colon syntax: LibAT.Logger:RegisterAddon()
	if type(addonName) == 'table' and addonName == LibAT.Logger then
		error('RegisterAddon: Called with colon syntax (:) - use dot syntax (.) instead: LibAT.Logger.RegisterAddon(addonName)')
	end

	if not addonName or addonName == '' or type(addonName) ~= 'string' then
		error('RegisterAddon: addonName must be a non-empty string')
	end

	-- Validate addonName doesn't contain problematic characters
	if addonName:find('%.') then
		error('RegisterAddon: addonName "' .. addonName .. '" cannot contain dots (.)')
	end

	-- Create the main logger object
	local loggerObj = CreateLoggerObject(addonName, addonName)

	-- If categories are provided, pre-register them
	if categories and type(categories) == 'table' then
		if #categories == 0 then
			error('RegisterAddon: categories array must not be empty if provided')
		end

		-- Validate and create all categories
		for i, categoryName in ipairs(categories) do
			if type(categoryName) ~= 'string' or categoryName == '' then
				error('RegisterAddon: category at index ' .. i .. ' must be a non-empty string')
			end
			if categoryName:find('%.') then
				error('RegisterAddon: category "' .. categoryName .. '" cannot contain dots (.)')
			end
		end

		-- Store category registration
		LoggerState.AddonCategories[addonName] = {
			subcategories = categories,
			expanded = false,
		}

		-- Create logger objects for each pre-defined category
		for _, categoryName in ipairs(categories) do
			local fullModuleName = addonName .. '.' .. categoryName
			loggerObj.Categories[categoryName] = CreateLoggerObject(addonName, fullModuleName)

			-- Initialize in database if logger is ready
			if logger.DB then
				logger.DB.modules[fullModuleName] = true
			end
		end
	else
		-- Simple registration - store as a registered addon
		LoggerState.RegisteredAddons[addonName] = true
	end

	-- Cache the logger object
	LoggerState.AddonLoggers[addonName] = loggerObj

	-- Initialize main addon in database if logger is ready
	if logger.DB then
		logger.DB.modules[addonName] = true
	end

	-- Rebuild UI if window exists
	if LoggerState.LogWindow and LoggerState.LogWindow.Categories then
		LibAT.Logger.CreateLogSourceCategories()
	end

	return loggerObj
end

----------------------------------------------------------------------------------------------------
-- Core Logging Functions
----------------------------------------------------------------------------------------------------

---Enhanced logging function with log levels
---@param debugText string The message to log
---@param module string The module name
---@param level? LogLevel Log level - defaults to 'info'
function LibAT.Log(debugText, module, level)
	level = level or 'info'

	-- Validate module name to prevent invalid entries
	if type(module) ~= 'string' or module == '' then
		-- Log to a fallback module name and issue a warning
		module = 'InvalidModule'
		debugText = 'Invalid module name provided to LibAT.Log: ' .. tostring(debugText)
		level = 'warning'
	end

	-- Initialize module if it doesn't exist
	if not LoggerState.LogMessages[module] then
		LoggerState.LogMessages[module] = {}

		-- Add new module to category system if log window exists
		if LoggerState.LogWindow and LoggerState.LogWindow.Categories then
			-- Rebuild the category tree to include new module
			LibAT.Logger.CreateLogSourceCategories()
		end

		-- Only update DB if it's initialized (might be called before OnInitialize)
		if logger.DB and logger.DB.modules then
			logger.DB.modules[module] = true -- Default to enabled for logging approach
		end
		if logger.options then
			logger.options.args[module] = {
				name = module,
				desc = 'Set the minimum log level for the ' .. module .. ' module. Use "Global" to inherit the global log level setting.',
				type = 'select',
				values = function()
					local values = { [0] = 'Global (inherit)' }
					-- Create ordered list to ensure proper display order
					local orderedLevels = {}
					for logLevelKey, data in pairs(LoggerState.LOG_LEVELS) do
						table.insert(orderedLevels, { level = logLevelKey, data = data })
					end
					table.sort(orderedLevels, function(a, b)
						return a.data.priority < b.data.priority
					end)

					for _, levelData in ipairs(orderedLevels) do
						values[levelData.data.priority] = levelData.data.display
					end
					return values
				end,
				sorting = function()
					-- Return sorted order for dropdown
					local sorted = { 0 } -- Global first
					local orderedLevels = {}
					for logLevelKey, data in pairs(LoggerState.LOG_LEVELS) do
						table.insert(orderedLevels, { level = logLevelKey, data = data })
					end
					table.sort(orderedLevels, function(a, b)
						return a.data.priority < b.data.priority
					end)

					for _, levelData in ipairs(orderedLevels) do
						table.insert(sorted, levelData.data.priority)
					end
					return sorted
				end,
				get = function(info)
					return logger.DB.moduleLogLevels[info[#info]] or 0
				end,
				set = function(info, val)
					logger.DB.moduleLogLevels[info[#info]] = val
					LoggerState.ModuleLogLevels[info[#info]] = val
					if LoggerState.LogWindow then
						LibAT.Logger.UpdateLogDisplay()
					end
				end,
				order = (#logger.options.args + 1),
			}
		end
	end

	-- Validate log level
	local logLevel = LoggerState.LOG_LEVELS[level]
	if not logLevel then
		level = 'info'
		logLevel = LoggerState.LOG_LEVELS[level]
	end

	-- PERFORMANCE OPTIMIZATION: In release builds, skip logs below current threshold
	-- Dev builds capture everything for dynamic filtering, release builds filter early for performance
	if LibAT.releaseType ~= 'DEV Build' then
		-- Get effective log level for this module
		local moduleLogLevel = LoggerState.ModuleLogLevels[module] or 0
		local effectiveLogLevel = moduleLogLevel > 0 and moduleLogLevel or LoggerState.GlobalLogLevel

		-- Skip capturing if log level is below threshold (unless it's warning/error/critical)
		if logLevel.priority < effectiveLogLevel and logLevel.priority < 3 then
			return -- Early exit, don't capture low-priority logs in release builds
		end
	end

	-- LOGGING APPROACH:
	-- DEV builds: Always capture all messages, filter during display (allows dynamic level changes)
	-- RELEASE builds: Filter at capture time for performance, still capture warnings/errors

	-- Create log entry with timestamp and level
	local timestamp = date('%H:%M:%S')
	local coloredLevel = logLevel.color .. '[' .. logLevel.display:upper() .. ']|r'
	local formattedMessage = timestamp .. ' ' .. coloredLevel .. ' ' .. tostring(debugText)

	-- Store the log entry
	local logEntry = {
		timestamp = GetTime(),
		level = level,
		message = tostring(debugText),
		formattedMessage = formattedMessage,
	}

	table.insert(LoggerState.LogMessages[module], logEntry)

	-- Maintain maximum log history
	local maxHistory = logger.DB.maxLogHistory or 1000
	if #LoggerState.LogMessages[module] > maxHistory then
		table.remove(LoggerState.LogMessages[module], 1)
	end

	-- Initialize log window if needed
	if not LoggerState.LogWindow then
		LibAT.Logger.CreateLogWindow()
	end

	-- Update display if this module is currently active
	if LoggerState.ActiveModule and LoggerState.ActiveModule == module then
		LibAT.Logger.UpdateLogDisplay()
	end
end

---@param debugText string The message to log
---@param module string The module name
function LibAT.Debug(debugText, module)
	-- Redirect to the new logging function
	LibAT.Log(debugText, module, 'debug')
end

----------------------------------------------------------------------------------------------------
-- Lifecycle Hooks
----------------------------------------------------------------------------------------------------

function logger:OnInitialize()
	local defaults = {
		globalLogLevel = 2, -- Default to 'info' and above
		captureWarningsErrors = true, -- Always capture warnings and errors
		maxLogHistory = 1000, -- Maximum log entries per module
		window = {
			width = 800,
			height = 538,
			point = 'CENTER',
			relativeTo = 'UIParent',
			relativePoint = 'CENTER',
			x = 0,
			y = 0,
		},
		modules = {
			['*'] = true, -- Default to enabled for logging approach
		},
		moduleLogLevels = {
			['*'] = 0, -- Use global level by default
		},
	}
	logger.Database = LibAT.Database:RegisterNamespace('Logger', { profile = defaults })
	logger.DB = logger.Database.profile

	-- Initialize UI and Options modules
	LibAT.Logger.InitUI(logger, LoggerState)
	LibAT.Logger.InitOptions(logger, LoggerState)

	-- Validate and purge any invalid entries from the database (done in Options module)
	-- ValidateAndPurgeModulesDB() is called by AddOptions

	-- Initialize log structures
	for k, _ in pairs(logger.DB.modules) do
		if type(k) == 'string' then -- Extra safety check after validation
			LoggerState.LogMessages[k] = {}
		end
	end

	-- Load settings
	LoggerState.GlobalLogLevel = logger.DB.globalLogLevel or 2
	LoggerState.ModuleLogLevels = logger.DB.moduleLogLevels or {}

	-- Register options during OnInitialize so they're in the master table before LibAT:OnEnable registers with Blizzard
	LibAT.Logger.AddOptions()

	LibAT.InternalLog = LibAT.Logger.RegisterAddon('Libs - Addon Tools')
end

function logger:OnEnable()
	LibAT.Logger.CreateLogWindow()

	local function ToggleLogWindow(comp)
		if not LoggerState.LogWindow then
			LibAT.Logger.CreateLogWindow()
		end
		if LoggerState.LogWindow:IsVisible() then
			LoggerState.LogWindow:Hide()
		else
			LoggerState.LogWindow:Show()
		end
	end

	-- Expose as public method for LibAT to use
	LibAT.Logger.ToggleWindow = ToggleLogWindow

	-- Register direct WoW slash commands
	SLASH_LibATLOGS1 = '/logs'
	SlashCmdList['LibATLOGS'] = ToggleLogWindow
end
