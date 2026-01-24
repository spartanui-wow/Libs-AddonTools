---@class LibAT
local LibAT = LibAT

-- This file contains AceConfig options generation for the Logger system

-- Import shared state (will be set by Logger.lua)
local logger, LoggerState

---Initialize the Options module with shared state from Logger
---@param loggerModule table The logger module
---@param state table The shared logger state
function LibAT.Logger.InitOptions(loggerModule, state)
	logger = loggerModule
	LoggerState = state
end

-- Validate and purge invalid entries from the modules database
local function ValidateAndPurgeModulesDB()
	local invalidEntries = {}

	-- Check for invalid entries in modules DB
	for k, v in pairs(logger.DB.modules) do
		if type(k) ~= 'string' then
			-- Key is not a string, mark for removal
			table.insert(invalidEntries, k)
		elseif type(v) ~= 'boolean' then
			-- Value is not a boolean, mark for removal
			table.insert(invalidEntries, k)
		end
	end

	-- Remove invalid entries
	if #invalidEntries > 0 then
		LibAT.Log('Purging ' .. #invalidEntries .. ' invalid entries from logger modules database', 'Logger', 'warning')
		for _, key in ipairs(invalidEntries) do
			logger.DB.modules[key] = nil
			if LoggerState.LogMessages[key] then
				LoggerState.LogMessages[key] = nil
			end
			if LoggerState.ModuleLogLevels[key] then
				LoggerState.ModuleLogLevels[key] = nil
			end
			if logger.DB.moduleLogLevels[key] then
				logger.DB.moduleLogLevels[key] = nil
			end
		end
	end

	-- Also validate moduleLogLevels
	invalidEntries = {}
	for k, v in pairs(logger.DB.moduleLogLevels) do
		if type(k) ~= 'string' or type(v) ~= 'number' then
			table.insert(invalidEntries, k)
		end
	end

	if #invalidEntries > 0 then
		LibAT.Log('Purging ' .. #invalidEntries .. ' invalid entries from logger moduleLogLevels database', 'Logger', 'warning')
		for _, key in ipairs(invalidEntries) do
			logger.DB.moduleLogLevels[key] = nil
			if LoggerState.ModuleLogLevels[key] then
				LoggerState.ModuleLogLevels[key] = nil
			end
		end
	end
end

local function AddOptions()
	-- Validate and purge invalid DB entries before building options
	ValidateAndPurgeModulesDB()

	---@type AceConfig.OptionsTable
	local options = {
		name = 'Logging',
		type = 'group',
		args = {
			Description = {
				name = 'SpartanUI uses a comprehensive logging system that captures all messages and filters by log level.\nAll modules are always enabled - use log level settings to control what messages are displayed.',
				type = 'description',
				order = 0,
			},
			GlobalLogLevel = {
				name = 'Global Log Level',
				desc = 'Minimum log level to display globally. Individual modules can override this.',
				type = 'select',
				values = function()
					local values = {}
					-- Create ordered list to ensure proper display order
					local orderedLevels = {}
					for level, data in pairs(LoggerState.LOG_LEVELS) do
						table.insert(orderedLevels, { level = level, data = data })
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
					local sorted = {}
					local orderedLevels = {}
					for level, data in pairs(LoggerState.LOG_LEVELS) do
						table.insert(orderedLevels, { level = level, data = data })
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
					return logger.DB.globalLogLevel
				end,
				set = function(info, val)
					logger.DB.globalLogLevel = val
					LoggerState.GlobalLogLevel = val
					if LoggerState.LogWindow then
						LibAT.Logger.UpdateLogDisplay()
					end
				end,
				order = 1,
			},
			CaptureWarningsErrors = {
				name = 'Always Capture Warnings/Errors',
				desc = 'Always capture warning, error, and critical messages regardless of log level settings.',
				type = 'toggle',
				get = function(info)
					return logger.DB.captureWarningsErrors
				end,
				set = function(info, val)
					logger.DB.captureWarningsErrors = val
				end,
				order = 2,
			},
			MaxLogHistory = {
				name = 'Maximum Log History',
				desc = 'Maximum number of log entries to keep per module.',
				type = 'range',
				min = 100,
				max = 5000,
				step = 100,
				get = function(info)
					return logger.DB.maxLogHistory
				end,
				set = function(info, val)
					logger.DB.maxLogHistory = val
				end,
				order = 3,
			},
			ModuleHeader = {
				name = 'Module Logging Control',
				type = 'header',
				order = 10,
			},
			ResetAllToGlobal = {
				name = 'Reset All Modules to Global',
				desc = 'Reset all modules to use the global log level setting (remove individual overrides).',
				type = 'execute',
				order = 11,
				func = function()
					for k, _ in pairs(logger.DB.modules) do
						logger.DB.moduleLogLevels[k] = 0
						LoggerState.ModuleLogLevels[k] = 0
					end
					if LoggerState.LogWindow then
						LibAT.Logger.UpdateLogDisplay()
					end
					LibAT:Print('All module log levels reset to global setting.')
				end,
			},
		},
	}

	for k, _ in pairs(logger.DB.modules) do
		if type(k) == 'string' then
			options.args[k] = {
				name = k,
				desc = 'Set the minimum log level for the ' .. k .. ' module. Use "Global" to inherit the global log level setting.',
				type = 'select',
				values = function()
					local values = { [0] = 'Global (inherit)' }
					-- Create ordered list to ensure proper display order
					local orderedLevels = {}
					for level, data in pairs(LoggerState.LOG_LEVELS) do
						table.insert(orderedLevels, { level = level, data = data })
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
					for level, data in pairs(LoggerState.LOG_LEVELS) do
						table.insert(orderedLevels, { level = level, data = data })
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
				order = (#options.args + 1),
			}
		end
	end
	logger.options = options
	LibAT.Options:AddOptions(options, 'Logging', 'Help')
end

-- Make AddOptions available to Logger.lua
LibAT.Logger.AddOptions = AddOptions
