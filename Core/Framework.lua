---@class LibAT : AceAddon, AceEvent-3.0, AceConsole-3.0
local LibAT = LibStub('AceAddon-3.0'):NewAddon('Libs-AddonTools', 'AceEvent-3.0', 'AceConsole-3.0')
-- Global namespace
_G.LibAT = LibAT

-- Debug flag - set to true to enable debug messages during development/testing
LibAT.DebugMode = false

-- Version information
LibAT.Version = C_AddOns.GetAddOnMetadata('Libs-AddonTools', 'Version') or 0
LibAT.BuildNum = C_AddOns.GetAddOnMetadata('Libs-AddonTools', 'X-Build') or 0
LibAT.BuildType = 'Release'
--@alpha@
LibAT.BuildType = 'ALPHA ' .. LibAT.BuildNum
--@end-alpha@
--@beta@
LibAT.BuildType = 'BETA ' .. LibAT.BuildNum
--@end-beta@
--@do-not-package@
LibAT.BuildType = 'DEV Build'
LibAT.Version = ''
--@end-do-not-package@

-- Core systems storage
LibAT.UI = {}
LibAT.Components = {}
LibAT.Systems = {}

-- UI ready flag - set to true after UI components are loaded
-- Systems can check this flag to ensure UI is available before using it
LibAT.UI.Ready = false

---Debug print function - only prints if DebugMode is enabled
---@param ... any Messages to print
function LibAT:Debug(...)
	if self.DebugMode then
		self:Print('[DEBUG]', ...)
	end
end

---Safely reload the UI with instance+combat check
---@param showMessage? boolean Whether to show error message (default: true)
---@return boolean success Whether reload was initiated or would be allowed
function LibAT:SafeReloadUI(showMessage)
	if showMessage == nil then
		showMessage = true
	end

	local inInstance = IsInInstance()
	local inCombat = InCombatLockdown()

	if inInstance and inCombat then
		if showMessage then
			self:Print('|cffff0000Cannot reload UI while in combat in an instance|r')
		end
		return false
	end

	ReloadUI()
	return true
end

---Options Manager - Simple interface for managing AceConfig options
LibAT.Options = {
	optionsTable = {},
	categoryInfo = {},
	registry = nil,
	dialog = nil,
}

---Initialize the Options system with AceConfig
function LibAT.Options:Init()
	if not self.registry then
		self.registry = LibStub('AceConfigRegistry-3.0', true)
		self.dialog = LibStub('AceConfigDialog-3.0', true)
	end
end

---Add options to the config system
---@param options table The options table
---@param name string The name for this options group
---@param parent? string Optional parent category
function LibAT.Options:AddOptions(options, name, parent)
	self:Init()

	if not self.registry then
		LibAT:Print('Warning: AceConfig not available, options cannot be registered')
		return
	end

	-- Store the options
	self.optionsTable[name] = options

	-- Store the category info for later retrieval
	if not self.categoryInfo then
		self.categoryInfo = {}
	end
	self.categoryInfo[name] = { name = name, parent = parent }

	if LibAT.Logger and LibAT.Logger.logger then
		LibAT.Logger.logger.debug('AddOptions called for: ' .. tostring(name) .. ' with parent: ' .. tostring(parent or 'none'))
	end

	-- Register with AceConfig if available
	if self.registry and self.dialog then
		self.registry:RegisterOptionsTable(name, options)

		-- Try to add to Blizzard options
		-- If parent is specified but doesn't exist, add without parent
		local success, err = pcall(function()
			if parent then
				-- First ensure parent exists by trying to create it
				if not self.optionsTable[parent] then
					-- Create a parent category with description
					local parentOptions = {
						type = 'group',
						name = parent,
						args = {
							Description = {
								name = 'Shared tools and utilities used by SpartanUI and related addons.\n\nSelect a subcategory to configure specific systems.',
								type = 'description',
								order = 0,
								fontSize = 'medium',
							},
						},
					}
					self.registry:RegisterOptionsTable(parent, parentOptions)
					local frame, categoryID = self.dialog:AddToBlizOptions(parent, parent)
					self.optionsTable[parent] = parentOptions
					-- Store the parent's category ID
					if not self.categoryInfo[parent] then
						self.categoryInfo[parent] = {}
					end
					self.categoryInfo[parent].categoryID = categoryID
				end
				local frame, categoryID = self.dialog:AddToBlizOptions(name, name, parent)
				-- Store the category ID returned by AddToBlizOptions
				self.categoryInfo[name].categoryID = categoryID
			else
				local frame, categoryID = self.dialog:AddToBlizOptions(name, name)
				self.categoryInfo[name].categoryID = categoryID
			end
		end)

		if not success then
			-- Fallback: add without parent if there was an error
			LibAT:Print('Warning: Could not add options with parent "' .. tostring(parent) .. '", adding as standalone. Error: ' .. tostring(err))
			pcall(function()
				local frame, categoryID = self.dialog:AddToBlizOptions(name, name)
				self.categoryInfo[name].categoryID = categoryID
			end)
		end
	end
end

---Toggle options dialog
---@param path? table Optional path to specific options
function LibAT.Options:ToggleOptions(path)
	self:Init()

	if not self.dialog or not self.registry then
		if LibAT.Logger and LibAT.Logger.logger then
			LibAT.Logger.logger.error('AceConfig not available')
		end
		return
	end

	local targetName
	if path and #path > 0 then
		targetName = path[#path]
	else
		targetName = 'Libs-AddonTools'
	end

	if LibAT.Logger and LibAT.Logger.logger then
		LibAT.Logger.logger.debug('Opening options panel: ' .. tostring(targetName))
		-- Check if the options table exists
		local registered = self.registry:GetOptionsTable(targetName)
		if registered then
			LibAT.Logger.logger.debug('Options table found for: ' .. targetName)
		else
			LibAT.Logger.logger.error('No options table registered for: ' .. targetName)
		end
	end

	-- Try to open in Blizzard Settings panel first (modern API)
	-- Settings.OpenToCategory calls the protected OpenSettingsPanel() internally,
	-- so it cannot be used during combat lockdown — fall through to standalone dialog instead
	if Settings and Settings.OpenToCategory and not InCombatLockdown() then
		-- Get the stored category ID for this option
		local categoryID = self.categoryInfo and self.categoryInfo[targetName] and self.categoryInfo[targetName].categoryID

		if categoryID then
			if LibAT.Logger and LibAT.Logger.logger then
				LibAT.Logger.logger.debug('Opening Blizzard Settings with category ID: ' .. tostring(categoryID))
			end

			-- Settings.OpenToCategory doesn't return a meaningful value, so we just call it and return
			-- The category ID from AddToBlizOptions is required for this to work
			Settings.OpenToCategory(categoryID)
			return
		else
			if LibAT.Logger and LibAT.Logger.logger then
				LibAT.Logger.logger.warning('No category ID found for: ' .. tostring(targetName) .. ', falling back to standalone dialog')
			end
		end
	end

	-- Fallback: Open the AceConfig standalone frame if Blizzard Settings API unavailable or no category ID
	if LibAT.Logger and LibAT.Logger.logger then
		LibAT.Logger.logger.debug('Opening standalone AceConfig window for: ' .. tostring(targetName))
	end
	self.dialog:Open(targetName)
end

---Register a system with LibAT
---@param name string The name of the system
---@param system table The system object
function LibAT:RegisterSystem(name, system)
	if not name or not system then
		self:Print('RegisterSystem: Invalid parameters')
		return
	end
	self.Systems[name] = system
	self:Debug(string.format('Registered system: %s', name))
end

---Initialize the LibAT framework
function LibAT:OnInitialize()
	-- Initialize database
	local defaults = {
		profile = {
			errorDisplay = {
				autoPopup = false,
				chatframe = true,
				fontSize = 12,
				minimapIcon = { hide = false, minimapPos = 97.66349921766368 },
				ignoredErrors = {}, -- Store signatures of errors to ignore
			},
			profileManager = {
				lastExportFormat = 'text',
				defaultProfileName = 'LibAT Import',
			},
		},
	}

	self.Database = LibStub('AceDB-3.0'):New('LibsAddonToolsDB', defaults, 'Default')
	self.DB = self.Database.profile
end

---Enable the LibAT framework
function LibAT:OnEnable()
	-- Mark UI as ready - all UI components have been loaded
	self.UI.Ready = true
end

---Handle slash commands
SLASH_LIBAT1 = '/libat'
SlashCmdList['LIBAT'] = function(msg)
	local args = { strsplit(' ', msg) }
	local command = args[1] and args[1]:lower() or ''
	local subcommand = args[2] and args[2]:lower() or ''

	if command == 'debug' then
		LibAT.DebugMode = not LibAT.DebugMode
		LibAT:Print('Debug mode:', LibAT.DebugMode and '|cff00ff00Enabled|r' or '|cffff0000Disabled|r')
	elseif command == 'errors' or command == 'error' then
		-- Default action: show errors (or handle subcommands if added later)
		if subcommand == 'show' or subcommand == '' then
			if LibAT.ErrorDisplay then
				LibAT.ErrorDisplay.BugWindow:OpenErrorWindow()
			elseif _G.LibATErrorDisplay then
				_G.LibATErrorDisplay.BugWindow:OpenErrorWindow()
			else
				LibAT:Print('Error Display system not available')
			end
		else
			LibAT:Print('Unknown errors subcommand: ' .. subcommand)
			LibAT:Print('Available: show')
		end
	elseif command == 'profiles' or command == 'profile' then
		-- Default action: open profile manager (or handle subcommands if added later)
		if subcommand == 'show' or subcommand == '' then
			if LibAT.ProfileManager then
				LibAT.ProfileManager:ToggleWindow()
			else
				LibAT:Print('Profile Manager system not available')
			end
		else
			LibAT:Print('Unknown profiles subcommand: ' .. subcommand)
			LibAT:Print('Available: show')
		end
	elseif command == 'logs' or command == 'log' then
		-- Default action: toggle logs (or handle subcommands if added later)
		if subcommand == 'show' or subcommand == 'toggle' or subcommand == '' then
			if LibAT.Logger then
				LibAT.Logger.ToggleWindow()
			else
				LibAT:Print('Logger system not available')
			end
		else
			LibAT:Print('Unknown logs subcommand: ' .. subcommand)
			LibAT:Print('Available: show, toggle')
		end
	else
		LibAT:Print('LibAT Commands:')
		LibAT:Print('  /libat debug - Toggle debug mode (shows initialization messages)')
		LibAT:Print('  /libat errors [show] - Open error display window')
		LibAT:Print('  /libat profiles [show] - Open profile manager')
		LibAT:Print('  /libat logs [show|toggle] - Toggle logger window')
		LibAT:Print(' ')
		LibAT:Print('Shortcuts:')
		LibAT:Print('  /errors - Open error display')
		LibAT:Print('  /logs - Toggle logger')
		LibAT:Print('  /profiles - Open profile manager')
		LibAT:Print(' ')
		LibAT:Print('Developer Tools:')
		LibAT:Print('  /frame <name> [true] - Inspect frame and set _G.FRAME')
		LibAT:Print('  /getpoint <name> - Show frame anchor points')
		LibAT:Print('  /texlist <name> - List frame textures')
		LibAT:Print('  /framelist [options] - Enhanced frame stack at mouse')
		LibAT:Print('  /devcon - Open developer console')
	end
end

-- Shortcut aliases
SLASH_ERRORS1 = '/errors'
SlashCmdList['ERRORS'] = function(msg)
	SlashCmdList['LIBAT']('errors ' .. (msg or ''))
end

SLASH_LOGS1 = '/logs'
SlashCmdList['LOGS'] = function(msg)
	SlashCmdList['LIBAT']('logs ' .. (msg or ''))
end

SLASH_PROFILES1 = '/profiles'
SlashCmdList['PROFILES'] = function(msg)
	SlashCmdList['LIBAT']('profiles ' .. (msg or ''))
end

SLASH_RL1 = '/rl'
SlashCmdList['RL'] = function()
	LibAT:SafeReloadUI()
end
