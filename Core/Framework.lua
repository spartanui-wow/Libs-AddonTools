---@class LibAT : AceAddon, AceEvent-3.0, AceConsole-3.0
local LibAT = LibStub('AceAddon-3.0'):NewAddon('Libs-AddonTools', 'AceEvent-3.0', 'AceConsole-3.0')
-- Global namespace
_G.LibAT = LibAT

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
LibAT.Components = {}

-- Database reference (will be initialized in OnInitialize)
LibAT.DB = nil

---Initialize the LibAT framework
function LibAT:OnInitialize()
	-- Initialize database
	local defaults = {
		profile = {
			errorDisplay = {
				autoPopup = false,
				chatframe = true,
				fontSize = 12,
				minimapIcon = {hide = false, minimapPos = 97.66349921766368},
				ignoredErrors = {} -- Store signatures of errors to ignore
			},
			profileManager = {
				lastExportFormat = 'text',
				defaultProfileName = 'LibAT Import'
			}
		}
	}

	self.Database = LibStub('AceDB-3.0'):New('LibsAddonToolsDB', defaults, 'Default')
	self.DB = self.Database.profile
end

---Enable the LibAT framework
function LibAT:OnEnable()
end

---Handle slash commands
SLASH_LIBAT1 = '/libat'
SlashCmdList['LIBAT'] = function(msg)
	local args = {strsplit(' ', msg)}
	local command = args[1] and args[1]:lower() or ''

	if command == 'errors' or command == 'error' then
		if LibAT.ErrorDisplay then
			LibAT.ErrorDisplay.BugWindow:OpenErrorWindow()
		elseif _G.LibATErrorDisplay then
			_G.LibATErrorDisplay.BugWindow:OpenErrorWindow()
		else
			LibAT:Print('Error Display system not available')
		end
	elseif command == 'profiles' or command == 'profile' then
		if LibAT.ProfileManager then
			LibAT.ProfileManager:ImportUI()
		else
			LibAT:Print('Profile Manager system not available')
		end
	elseif command == 'logs' or command == 'log' then
		if LibAT.Logger then
			LibAT.Logger.ToggleWindow()
		else
			LibAT:Print('Logger system not available')
		end
	else
		LibAT:Print('LibAT Commands:')
		LibAT:Print('  /libat errors - Open error display window')
		LibAT:Print('  /libat profiles - Open profile manager')
		LibAT:Print('  /libat logs - Open logger window')
		LibAT:Print('  /libatlogs - Toggle logger (direct command)')
		LibAT:Print('  /libatprofiles - Open profile manager (direct command)')
	end
end

SLASH_RL1 = '/rl'
SlashCmdList['RL'] = function()
	ReloadUI()
end

return LibAT
