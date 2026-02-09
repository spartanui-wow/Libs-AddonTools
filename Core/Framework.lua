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

---Options Manager - Single master options table with one Blizzard Settings entry
---Modules add their options as child groups within the master table's args.
LibAT.Options = {
	registry = nil,
	dialog = nil,
	categoryID = nil,
	registered = false,
	---@type AceConfig.OptionsTable
	masterOptions = {
		type = 'group',
		name = 'Libs-AddonTools',
		childGroups = 'tab',
		args = {
			Description = {
				name = 'Shared tools and utilities used by SpartanUI and related addons.\n\nSelect a tab to configure specific systems.',
				type = 'description',
				order = 0,
				fontSize = 'medium',
			},
		},
	},
}

---Initialize the Options system with AceConfig
function LibAT.Options:Init()
	if not self.registry then
		self.registry = LibStub('AceConfigRegistry-3.0', true)
		self.dialog = LibStub('AceConfigDialog-3.0', true)
	end
end

---Register the master options table with Blizzard Settings (called once)
function LibAT.Options:Register()
	if self.registered then
		return
	end

	self:Init()
	if not self.registry or not self.dialog then
		return
	end

	self.registry:RegisterOptionsTable('Libs-AddonTools', self.masterOptions)

	local success, err = pcall(function()
		local frame, categoryID = self.dialog:AddToBlizOptions('Libs-AddonTools', 'Libs-AddonTools')
		self.categoryID = categoryID
	end)

	if not success then
		LibAT:Print('Warning: Could not register options with Blizzard Settings: ' .. tostring(err))
	end

	self.registered = true
end

---Add options to the config system as a child group
---Modules should call this during OnInitialize. Blizzard registration happens in LibAT:OnEnable().
---@param options table The options table (type='group')
---@param name string The name for this options group
---@param parent? string Ignored (kept for API compatibility) — all options go under the master table
function LibAT.Options:AddOptions(options, name, parent)
	self:Init()

	if LibAT.Logger and LibAT.Logger.logger then
		LibAT.Logger.logger.debug('AddOptions called for: ' .. tostring(name))
	end

	-- Add the options as a child group in the master table
	self.masterOptions.args[name] = options
	-- Ensure it renders as a group/tab
	if not options.type then
		options.type = 'group'
	end

	-- If already registered with Blizzard (late addition after OnEnable), notify change
	if self.registered and self.registry then
		self.registry:NotifyChange('Libs-AddonTools')
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

	if LibAT.Logger and LibAT.Logger.logger then
		LibAT.Logger.logger.debug('Opening options panel')
	end

	-- Try to open in Blizzard Settings panel first (modern API)
	-- Settings.OpenToCategory calls the protected OpenSettingsPanel() internally,
	-- so it cannot be used during combat lockdown — fall through to standalone dialog instead
	if Settings and Settings.OpenToCategory and not InCombatLockdown() then
		if self.categoryID then
			if LibAT.Logger and LibAT.Logger.logger then
				LibAT.Logger.logger.debug('Opening Blizzard Settings with category ID: ' .. tostring(self.categoryID))
			end
			Settings.OpenToCategory(self.categoryID)
			return
		end
	end

	-- Fallback: Open the AceConfig standalone frame
	if LibAT.Logger and LibAT.Logger.logger then
		LibAT.Logger.logger.debug('Opening standalone AceConfig window')
	end
	self.dialog:Open('Libs-AddonTools')
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
		global = {
			setupWizardDismissed = false,
		},
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

	-- Register options with Blizzard now that all modules have added theirs via OnInitialize
	LibAT.Options:Register()

	-- Check for first-run setup wizard prompt after a short delay
	-- Delay allows other addons to register their setup pages first
	C_Timer.After(3, function()
		if LibAT.SetupWizard and LibAT.SetupWizard.CheckFirstRun then
			LibAT.SetupWizard:CheckFirstRun()
		end
	end)
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
	elseif command == 'setup' or command == 'wizard' then
		-- Open the Setup Wizard
		if LibAT.SetupWizard then
			LibAT.SetupWizard:ToggleWindow()
		else
			LibAT:Print('Setup Wizard system not available')
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
		LibAT:Print('  /libat setup - Open setup wizard')
		LibAT:Print(' ')
		LibAT:Print('Shortcuts:')
		LibAT:Print('  /errors - Open error display')
		LibAT:Print('  /logs - Toggle logger')
		LibAT:Print('  /profiles - Open profile manager')
		LibAT:Print('  /setup - Open setup wizard')
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

SLASH_SETUP1 = '/setup'
SlashCmdList['SETUP'] = function(msg)
	SlashCmdList['LIBAT']('setup ' .. (msg or ''))
end

SLASH_RL1 = '/rl'
SlashCmdList['RL'] = function()
	LibAT:SafeReloadUI()
end
