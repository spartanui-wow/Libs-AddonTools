---@class LibAT : AceAddon-3.0, AceEvent-3.0, AceConsole-3.0
local LibAT = LibStub('AceAddon-3.0'):NewAddon('Libs-AddonTools', 'AceEvent-3.0', 'AceConsole-3.0')

-- Global namespace
_G.LibAT = LibAT

-- Version information
LibAT.Version = '1.0.0-dev'
LibAT.BuildType = 'Development'

-- Core systems storage
LibAT.Systems = {}
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
				minimapIcon = {hide = false, minimapPos = 97.66349921766368}
			},
			profileManager = {
				lastExportFormat = 'text',
				defaultProfileName = 'LibAT Import'
			},
			logger = {
				globalLogLevel = 2, -- Info and above
				captureWarningsErrors = true,
				maxLogHistory = 1000,
				window = {
					width = 800,
					height = 538,
					point = 'CENTER',
					relativeTo = 'UIParent',
					relativePoint = 'CENTER',
					x = 0,
					y = 0
				},
				modules = {
					['*'] = true,
					Core = true
				},
				moduleLogLevels = {
					['*'] = 0 -- Use global level by default
				}
			}
		}
	}

	self.Database = LibStub('AceDB-3.0'):New('LibsAddonToolsDB', defaults, true)
	self.DB = self.Database.profile

	self:Print('LibAT ' .. self.Version .. ' initialized')
end

---Enable the LibAT framework
function LibAT:OnEnable()
	-- Initialize systems that require database access after DB is ready
	if self.Systems.Logger and self.Systems.Logger.Initialize then
		self.Systems.Logger:Initialize()
	end

	-- Register the self-sufficient Error Display system if it's available
	if _G.LibATErrorDisplay and not self.Systems.ErrorDisplay then
		self.Systems.ErrorDisplay = _G.LibATErrorDisplay
		self:Print('Registered self-sufficient Error Display system')
	end

	self:Print('LibAT enabled - Error Display, Profile Manager, and Logger systems available')

	-- Register slash commands
	self:RegisterChatCommand('libat', 'SlashCommand')
	self:RegisterChatCommand('lat', 'SlashCommand')
end

---Handle slash commands
SLASH_LIBAT1 = '/libat'
SlashCmdList['LIBAT'] = function(msg)
	local args = {strsplit(' ', msg)}
	local command = args[1] and args[1]:lower() or ''

	if command == 'errors' or command == 'error' then
		if LibAT.Systems.ErrorDisplay then
			LibAT.Systems.ErrorDisplay.BugWindow:OpenErrorWindow()
		elseif _G.LibATErrorDisplay then
			_G.LibATErrorDisplay.BugWindow:OpenErrorWindow()
		else
			LibAT:Print('Error Display system not available')
		end
	-- elseif command == 'profiles' or command == 'profile' then
	-- 	if LibAT.Systems.ProfileManager then
	-- 		LibAT.Systems.ProfileManager:ImportUI()
	-- 	else
	-- 		LibAT:Print('Profile Manager system not available')
	-- 	end
	-- elseif command == 'logs' or command == 'log' then
	-- 	if LibAT.Systems.Logger then
	-- 		LibAT.Systems.Logger.ToggleWindow()
	-- 	else
	-- 		LibAT:Print('Logger system not available')
	-- 	end
	else
		LibAT:Print('LibAT Commands:')
		LibAT:Print('  /libat errors - Open error display window')
		LibAT:Print('  /libat profiles - Open profile manager')
		LibAT:Print('  /libat logs - Open logger window')
		LibAT:Print('  /libatlogs - Toggle logger (direct command)')
		LibAT:Print('  /libatprofiles - Open profile manager (direct command)')
	end
end

---Register a system with LibAT
---@param name string System name
---@param system table System object
function LibAT:RegisterSystem(name, system)
	self.Systems[name] = system
	self:Print('Registered system: ' .. name)
end

---Get a registered system
---@param name string System name
---@return table|nil system System object or nil if not found
function LibAT:GetSystem(name)
	return self.Systems[name]
end

return LibAT
