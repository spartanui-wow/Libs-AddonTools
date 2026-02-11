---@class LibATErrorDisplay
local ErrorDisplay = _G.LibATErrorDisplay

ErrorDisplay.Config = {}

-- Minimal defaults - only store overrides, use fallbacks for defaults
-- Note: We no longer store errors ourselves - BugGrabber handles that
local defaults = {
	profile = {},
	global = {},
}

-- Initialize using Ace3 DB pattern
function ErrorDisplay.Config:Initialize()
	-- Use LibStub to get AceDB if available, fallback to manual setup
	local AceDB = LibStub and LibStub('AceDB-3.0', true)

	if AceDB then
		ErrorDisplay.database = AceDB:New('LibATErrorDisplayDB', defaults, true)
		ErrorDisplay.db = ErrorDisplay.database.profile
		ErrorDisplay.gdb = ErrorDisplay.database.global
	else
		-- Fallback to manual setup
		if not LibATErrorDisplayDB then
			LibATErrorDisplayDB = CopyTable(defaults)
		end
		ErrorDisplay.database = LibATErrorDisplayDB
		ErrorDisplay.db = LibATErrorDisplayDB.profile or {}
		ErrorDisplay.gdb = LibATErrorDisplayDB.global or {}

		-- Ensure global defaults exist
		for k, v in pairs(defaults.global) do
			if ErrorDisplay.gdb[k] == nil then
				ErrorDisplay.gdb[k] = v
			end
		end
	end

	-- Remove old reference
	self.db = nil
end

-- Register options via LibAT.Options (AceConfig) instead of manual Blizzard panel
function ErrorDisplay.Config:CreatePanel()
	local MinimapIconName = 'Libs-AddonToolsErrorDisplay'

	---@type AceConfig.OptionsTable
	local options = {
		type = 'group',
		name = 'Error Display',
		args = {
			Description = {
				name = 'Configure how LibAT handles and displays Lua errors.',
				type = 'description',
				order = 0,
				fontSize = 'medium',
			},
			autoPopup = {
				name = 'Auto popup on errors',
				desc = 'Automatically open the error window when new errors are captured.',
				type = 'toggle',
				order = 1,
				get = function()
					return ErrorDisplay.db.autoPopup or false
				end,
				set = function(_, val)
					ErrorDisplay.db.autoPopup = val or nil
				end,
			},
			chatframe = {
				name = 'Chat frame output',
				desc = 'Print error notifications to the chat frame.',
				type = 'toggle',
				order = 2,
				get = function()
					return ErrorDisplay.db.chatframe ~= false
				end,
				set = function(_, val)
					ErrorDisplay.db.chatframe = val and nil or false
				end,
			},
			fontSize = {
				name = 'Font Size',
				desc = 'Font size for the error display window.',
				type = 'range',
				min = 8,
				max = 24,
				step = 1,
				order = 3,
				get = function()
					return ErrorDisplay.db.fontSize or 12
				end,
				set = function(_, val)
					ErrorDisplay.db.fontSize = val ~= 12 and val or nil
					if ErrorDisplay.BugWindow.UpdateFontSize then
						ErrorDisplay.BugWindow:UpdateFontSize()
					end
				end,
			},
			minimapIcon = {
				name = 'Show Minimap Icon',
				desc = 'Show or hide the minimap icon for error display.',
				type = 'toggle',
				order = 4,
				get = function()
					if ErrorDisplay.icon and ErrorDisplay.db.minimapIcon then
						return not ErrorDisplay.db.minimapIcon.hide
					end
					return true
				end,
				set = function(_, val)
					-- Persist hide state to database
					if ErrorDisplay.db.minimapIcon then
						ErrorDisplay.db.minimapIcon.hide = not val
					end
					-- Update icon visibility
					if ErrorDisplay.icon then
						if val then
							ErrorDisplay.icon:Show(MinimapIconName)
						else
							ErrorDisplay.icon:Hide(MinimapIconName)
						end
					end
				end,
			},
			resetDefaults = {
				name = 'Reset to Defaults',
				desc = 'Reset all Error Display settings to their default values.',
				type = 'execute',
				order = 10,
				func = function()
					ErrorDisplay.Config:ResetToDefaults()
				end,
			},
		},
	}

	LibAT.Options:AddOptions(options, 'Error Display', 'Libs-AddonTools')
end

function ErrorDisplay.Config:ResetToDefaults()
	-- Clear profile settings (let defaults kick in)
	if ErrorDisplay.database and ErrorDisplay.database.ResetProfile then
		ErrorDisplay.database:ResetProfile()
	else
		-- Manual reset
		wipe(ErrorDisplay.db)
	end

	if ErrorDisplay.BugWindow.UpdateFontSize then
		ErrorDisplay.BugWindow:UpdateFontSize()
	end
end

return ErrorDisplay.Config
