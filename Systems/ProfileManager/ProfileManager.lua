---@class LibAT
local LibAT = LibAT
---@class LibAT.ProfileManager
local ProfileManager = LibAT.ProfileManager

----------------------------------------------------------------------------------------------------
-- Type Definitions
----------------------------------------------------------------------------------------------------

---@class RegisteredAddon
---@field id string Unique identifier for this addon
---@field displayName string Display name shown in UI
---@field db table AceDB database object
---@field namespaces table|nil Optional array of namespace names
---@field icon string|nil Optional icon path
---@field metadata table|nil Additional addon metadata

----------------------------------------------------------------------------------------------------
-- Shared State Setup
----------------------------------------------------------------------------------------------------

local ProfileManagerState = {
	-- UI Components
	window = nil, ---@type table|Frame

	-- Core functionality
	logger = nil, -- Will be initialized in Initialize()
	namespaceblacklist = { 'LibDualSpec-1.0' },

	-- Registered addons storage
	registeredAddons = {},
	nextAddonId = 1,
}

----------------------------------------------------------------------------------------------------
-- External API - LibAT.ProfileManager (for third-party addons)
----------------------------------------------------------------------------------------------------

---Register an addon with the Profile Manager to enable profile import/export
---@param config table Configuration table with: name (string), db (table), namespaces (table|nil), icon (string|nil), id (string|nil)
---@return string addonId The unique ID assigned to this addon (use for ShowExport/ShowImport)
function ProfileManager:RegisterAddon(config)
	-- Validate required fields
	if not config or type(config) ~= 'table' then
		error('ProfileManager:RegisterAddon - config must be a table')
	end
	if not config.name or type(config.name) ~= 'string' then
		error('ProfileManager:RegisterAddon - config.name is required and must be a string')
	end
	if not config.db or type(config.db) ~= 'table' then
		error('ProfileManager:RegisterAddon - config.db is required and must be a table (AceDB object)')
	end

	-- Generate or use provided ID
	local addonId = config.id
	if not addonId then
		addonId = 'addon_' .. ProfileManagerState.nextAddonId
		ProfileManagerState.nextAddonId = ProfileManagerState.nextAddonId + 1
	end

	-- Check if already registered
	if ProfileManagerState.registeredAddons[addonId] then
		LibAT:Print('|cffff9900Warning:|r Addon "' .. config.name .. '" is already registered with ID: ' .. addonId)
		return addonId
	end

	-- Create registration entry
	ProfileManagerState.registeredAddons[addonId] = {
		id = addonId,
		displayName = config.name,
		db = config.db,
		namespaces = config.namespaces,
		icon = config.icon,
		metadata = config.metadata or {},
	}

	-- Rebuild navigation tree if window exists
	if ProfileManagerState.window and ProfileManagerState.window.NavTree then
		LibAT.ProfileManager.BuildNavigationTree()
	end

	if LibAT.Log then
		LibAT.Log('Registered addon "' .. config.name .. '" (ID: ' .. addonId .. ')', 'ProfileManager', 'debug')
	end
	return addonId
end

---Unregister an addon from the Profile Manager
---@param addonId string The unique ID of the addon to unregister
function ProfileManager:UnregisterAddon(addonId)
	if not ProfileManagerState.registeredAddons[addonId] then
		LibAT:Print('|cffff0000Error:|r Addon with ID "' .. addonId .. '" is not registered')
		return
	end

	local addonName = ProfileManagerState.registeredAddons[addonId].displayName
	ProfileManagerState.registeredAddons[addonId] = nil

	-- Rebuild navigation tree if window exists
	if ProfileManagerState.window and ProfileManagerState.window.NavTree then
		LibAT.ProfileManager.BuildNavigationTree()
	end

	LibAT:Debug('Unregistered addon "' .. addonName .. '" from ProfileManager')
end

---Get all registered addons
---@return table<string, RegisteredAddon> Table of registered addons keyed by ID
function ProfileManager:GetRegisteredAddons()
	return ProfileManagerState.registeredAddons
end

---Navigate to a specific addon in export mode
---@param addonId string The unique ID of the addon
---@param namespace string|nil Optional specific namespace to export
function ProfileManager:ShowExport(addonId, namespace)
	if not ProfileManagerState.registeredAddons[addonId] then
		LibAT:Print('|cffff0000Error:|r Addon with ID "' .. addonId .. '" is not registered')
		return
	end

	if not ProfileManagerState.window then
		local success, err = pcall(LibAT.ProfileManager.CreateWindow)
		if not success then
			if ProfileManagerState.logger then
				ProfileManagerState.logger.error('CreateWindow threw error: ' .. tostring(err))
			end
			return
		end
		if not ProfileManagerState.window then
			if ProfileManagerState.logger then
				ProfileManagerState.logger.error('Failed to create ProfileManager window')
			end
			return
		end
	end

	-- Set mode and active addon
	ProfileManagerState.window.mode = 'export'
	ProfileManagerState.window.activeAddonId = addonId
	ProfileManagerState.window.activeNamespace = namespace

	-- Build navigation key
	local navKey = 'Addons.' .. addonId .. '.' .. (namespace or 'ALL')

	-- Update navigation tree and auto-expand the addon's category
	if ProfileManagerState.window.NavTree then
		ProfileManagerState.window.NavTree.config.activeKey = navKey
		LibAT.ProfileManager.BuildNavigationTree()

		-- Auto-expand the category so the selected item is visible
		local categories = ProfileManagerState.window.NavTree.config.categories
		if categories[addonId] then
			categories[addonId].expanded = true
			LibAT.UI.BuildNavigationTree(ProfileManagerState.window.NavTree)
		end
	end

	LibAT.ProfileManager.UpdateWindowForMode()
end

---Navigate to a specific addon in import mode
---@param addonId string The unique ID of the addon
---@param namespace string|nil Optional specific namespace to import
function ProfileManager:ShowImport(addonId, namespace)
	if not ProfileManagerState.registeredAddons[addonId] then
		LibAT:Print('|cffff0000Error:|r Addon with ID "' .. addonId .. '" is not registered')
		return
	end

	if not ProfileManagerState.window then
		LibAT.ProfileManager.CreateWindow()
		if not ProfileManagerState.window then
			if ProfileManagerState.logger then
				ProfileManagerState.logger.error('Failed to create ProfileManager window')
			end
			return
		end
	end

	-- Set mode and active addon
	ProfileManagerState.window.mode = 'import'
	ProfileManagerState.window.activeAddonId = addonId
	ProfileManagerState.window.activeNamespace = namespace

	-- Build navigation key
	local navKey = 'Addons.' .. addonId .. '.' .. (namespace or 'ALL')

	-- Update navigation tree and auto-expand the addon's category
	if ProfileManagerState.window.NavTree then
		ProfileManagerState.window.NavTree.config.activeKey = navKey
		LibAT.ProfileManager.BuildNavigationTree()

		-- Auto-expand the category so the selected item is visible
		local categories = ProfileManagerState.window.NavTree.config.categories
		if categories[addonId] then
			categories[addonId].expanded = true
			LibAT.UI.BuildNavigationTree(ProfileManagerState.window.NavTree)
		end
	end

	LibAT.ProfileManager.UpdateWindowForMode()
end

----------------------------------------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------------------------------------

---Build navigation tree categories from registered addons
---Namespaces are listed directly under each addon (no Import/Export sub-nodes)
---Mode (import/export) is controlled by the "Switch Mode" button
---@return table categories Navigation tree category structure
local function BuildAddonCategories()
	local categories = {}

	-- Sort addon IDs for consistent display order
	local sortedIds = {}
	for id in pairs(ProfileManagerState.registeredAddons) do
		table.insert(sortedIds, id)
	end
	table.sort(sortedIds, function(a, b)
		return ProfileManagerState.registeredAddons[a].displayName < ProfileManagerState.registeredAddons[b].displayName
	end)

	-- Build category for each registered addon
	for _, addonId in ipairs(sortedIds) do
		local addon = ProfileManagerState.registeredAddons[addonId]
		local categoryKey = 'Addons.' .. addonId

		-- Check if addon has namespaces
		local hasNamespaces = addon.namespaces and #addon.namespaces > 0

		local subCategories = {}
		local sortedKeys = {}

		-- "All" entry - full DB export/import
		subCategories['ALL'] = {
			name = 'All (Full DB)',
			key = categoryKey .. '.ALL',
			onSelect = function()
				ProfileManagerState.window.activeAddonId = addonId
				ProfileManagerState.window.activeNamespace = nil
				LibAT.ProfileManager.UpdateWindowForMode()
			end,
		}
		table.insert(sortedKeys, 'ALL')

		-- "Core DB" entry - base profile data only
		subCategories['__COREDB__'] = {
			name = 'Core DB',
			key = categoryKey .. '.__COREDB__',
			onSelect = function()
				ProfileManagerState.window.activeAddonId = addonId
				ProfileManagerState.window.activeNamespace = '__COREDB__'
				LibAT.ProfileManager.UpdateWindowForMode()
			end,
		}
		table.insert(sortedKeys, '__COREDB__')

		-- Individual namespaces (sorted alphabetically)
		if hasNamespaces then
			local sortedNamespaces = {}
			for _, ns in ipairs(addon.namespaces) do
				table.insert(sortedNamespaces, ns)
			end
			table.sort(sortedNamespaces)

			for _, ns in ipairs(sortedNamespaces) do
				subCategories[ns] = {
					name = ns,
					key = categoryKey .. '.' .. ns,
					onSelect = function()
						ProfileManagerState.window.activeAddonId = addonId
						ProfileManagerState.window.activeNamespace = ns
						LibAT.ProfileManager.UpdateWindowForMode()
					end,
				}
				table.insert(sortedKeys, ns)
			end
		end

		-- Create main category
		categories[addonId] = {
			name = addon.displayName,
			key = categoryKey,
			expanded = false,
			icon = addon.icon,
			isToken = addon.autoDiscovered or false,
			subCategories = subCategories,
			sortedKeys = sortedKeys,
		}
	end

	return categories
end

-- Store helper function for UI module access
ProfileManagerState.BuildAddonCategories = BuildAddonCategories

----------------------------------------------------------------------------------------------------
-- Import/Export Functions
----------------------------------------------------------------------------------------------------

-- Export function - Works with registered addons
function ProfileManager:DoExport()
	if not ProfileManagerState.window then
		return
	end

	-- Check if an addon is selected
	if not ProfileManagerState.window.activeAddonId or not ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId] then
		LibAT:Print('|cffff0000Error:|r No addon selected for export')
		return
	end

	local addon = ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId]
	local db = addon.db

	-- Validate AceDB structure
	if not db or not db.sv then
		LibAT:Print('|cffff0000Error:|r Invalid AceDB object for ' .. addon.displayName)
		return
	end

	-- Build export data
	local exportData = {
		version = '3.0.0',
		timestamp = date('%Y-%m-%d %H:%M:%S'),
		addon = addon.displayName,
		addonId = addon.id,
		data = {},
	}

	-- Export based on namespace selection
	local activeNS = ProfileManagerState.window.activeNamespace
	if activeNS == '__COREDB__' then
		-- Export only the current active profile (core DB)
		exportData.namespace = '__COREDB__'
		if db.sv.profiles then
			-- Find the current profile key
			local currentProfileKey = db.keys and db.keys.profile or 'Default'
			if db.sv.profiles[currentProfileKey] then
				exportData.data = db.sv.profiles[currentProfileKey]
			else
				LibAT:Print('|cffff0000Error:|r Current profile "' .. currentProfileKey .. '" not found in database')
				return
			end
		else
			LibAT:Print('|cffff0000Error:|r No profile data found in database')
			return
		end
	elseif activeNS then
		-- Export single namespace
		if db.sv.namespaces and db.sv.namespaces[activeNS] then
			exportData.data[activeNS] = db.sv.namespaces[activeNS]
			exportData.namespace = activeNS
		else
			LibAT:Print('|cffff0000Error:|r Namespace "' .. activeNS .. '" not found')
			return
		end
	else
		-- Export all namespaces (excluding blacklist)
		if db.sv.namespaces then
			for namespace, nsData in pairs(db.sv.namespaces) do
				if not tContains(ProfileManagerState.namespaceblacklist, namespace) then
					exportData.data[namespace] = nsData
				end
			end
		end

		-- Also export profile data if available
		if db.sv.profiles then
			exportData.profiles = db.sv.profiles
		end

		-- Record which profile was active at export time (for targeted import)
		exportData.activeProfile = db.keys and db.keys.profile or 'Default'
	end

	-- Encode using base64 pipeline
	local encoded, encodeErr = ProfileManager.EncodeData(exportData)
	if not encoded then
		LibAT:Print('|cffff0000Export failed:|r ' .. tostring(encodeErr))
		return
	end

	-- Build comment header
	local header = '-- ' .. addon.displayName .. ' Profile Export\n'
	header = header .. '-- Generated: ' .. exportData.timestamp .. '\n'
	header = header .. '-- Version: ' .. exportData.version .. ' (Base64 Encoded)\n'
	if activeNS == '__COREDB__' then
		header = header .. '-- Section: Core DB\n'
	elseif activeNS then
		header = header .. '-- Namespace: ' .. activeNS .. '\n'
	else
		header = header .. '-- Section: All Namespaces\n'
	end
	header = header .. '\n'

	local exportString = header .. encoded

	-- Show the export action button area if it exists, hide it
	if ProfileManagerState.window.ExportActionButton then
		ProfileManagerState.window.ExportActionButton:Hide()
	end

	-- Show TextPanel and fill EditBox
	if ProfileManagerState.window.TextPanel then
		ProfileManagerState.window.TextPanel:Show()
	end

	ProfileManagerState.window.EditBox:SetText(exportString)
	ProfileManagerState.window.EditBox:SetCursorPosition(0)
	ProfileManagerState.window.EditBox:HighlightText(0)

	LibAT:Print('|cff00ff00Profile exported successfully!|r Select all (Ctrl+A) and copy (Ctrl+C).')
end

-- Import function - Works with registered addons
-- Supports both base64 encoded format (v3.0.0+) and legacy Lua table format
function ProfileManager:DoImport()
	if not ProfileManagerState.window then
		return
	end

	-- Check if an addon is selected
	if not ProfileManagerState.window.activeAddonId or not ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId] then
		LibAT:Print('|cffff0000Error:|r No addon selected for import')
		return
	end

	local importText = ProfileManagerState.window.EditBox:GetText()
	if not importText or importText == '' then
		LibAT:Print('|cffff0000Please paste profile data into the text box first.|r')
		return
	end

	-- Strip comment header lines
	local dataText = importText:gsub('%-%-[^\n]*\n', '')
	dataText = dataText:match('^%s*(.-)%s*$') -- trim whitespace

	if not dataText or dataText == '' then
		LibAT:Print('|cffff0000Invalid profile data. No content after stripping headers.|r')
		return
	end

	-- Detect format and decode
	local importData, decodeErr

	if dataText:match('^return%s*{') then
		-- Legacy format: Lua table string
		local func = loadstring(dataText)
		if func then
			local success, result = pcall(func)
			if success and type(result) == 'table' then
				importData = result
			else
				decodeErr = 'Failed to evaluate Lua table: ' .. tostring(result)
			end
		else
			decodeErr = 'Invalid Lua table format'
		end
	else
		-- New format: Base64 encoded
		importData, decodeErr = ProfileManager.DecodeData(dataText)
	end

	if not importData then
		LibAT:Print('|cffff0000Invalid profile data:|r ' .. tostring(decodeErr))
		return
	end

	local addon = ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId]
	local db = addon.db

	-- Validate AceDB structure
	if not db or not db.sv then
		LibAT:Print('|cffff0000Error:|r Invalid AceDB object for ' .. addon.displayName)
		return
	end

	-- Validate addon ID matches (optional safety check)
	if importData.addonId and importData.addonId ~= addon.id then
		LibAT:Print('|cffff9900Warning:|r Import data is for addon "' .. (importData.addon or 'Unknown') .. '" but you selected "' .. addon.displayName .. '"')
		LibAT:Print('Continuing with import anyway...')
	end

	-- Determine import destination profile key
	local importDest = ProfileManagerState.window.importDestination
	local targetProfileKey
	if importDest == '__NEW__' then
		-- Create new profile from user input
		local newName = ProfileManagerState.window.NewProfileInput and ProfileManagerState.window.NewProfileInput:GetText() or ''
		newName = newName:match('^%s*(.-)%s*$') -- trim
		if not newName or newName == '' then
			LibAT:Print('|cffff0000Error:|r Please enter a name for the new profile.')
			return
		end
		targetProfileKey = newName
		if not db.sv.profiles then
			db.sv.profiles = {}
		end
	elseif importDest and importDest ~= '' then
		-- Import to a specific existing profile
		targetProfileKey = importDest
	else
		-- Default: import to current active profile
		targetProfileKey = db.keys and db.keys.profile or 'Default'
	end

	-- Apply import data
	local importCount = 0
	local activeNS = ProfileManagerState.window.activeNamespace

	if activeNS == '__COREDB__' then
		-- Import Core DB to the target profile
		if importData.namespace == '__COREDB__' and importData.data then
			if not db.sv.profiles then
				db.sv.profiles = {}
			end
			db.sv.profiles[targetProfileKey] = importData.data
			importCount = 1
		else
			LibAT:Print('|cffff0000Error:|r Import data is not a Core DB export')
			return
		end
	elseif activeNS then
		-- Import single namespace
		local nsData
		if importData.data and importData.data[activeNS] then
			nsData = importData.data[activeNS]
		elseif importData.namespace == activeNS and importData.data then
			-- Data might be directly in importData.data if it was a single namespace export
			nsData = importData.data[activeNS] or importData.data
		end

		if nsData then
			if not db.sv.namespaces then
				db.sv.namespaces = {}
			end
			db.sv.namespaces[activeNS] = nsData
			importCount = 1
		else
			LibAT:Print('|cffff0000Error:|r Import data does not contain namespace "' .. activeNS .. '"')
			return
		end
	else
		-- Import all namespaces — merge source profile into target profile
		local sourceProfileKey = importData.activeProfile

		if importData.data then
			if not db.sv.namespaces then
				db.sv.namespaces = {}
			end
			for namespace, nsData in pairs(importData.data) do
				if not tContains(ProfileManagerState.namespaceblacklist, namespace) then
					if not db.sv.namespaces[namespace] then
						db.sv.namespaces[namespace] = {}
					end
					-- Copy non-profile keys (globals, etc.) directly
					for key, value in pairs(nsData) do
						if key ~= 'profiles' then
							db.sv.namespaces[namespace][key] = value
						end
					end
					-- Merge profiles: map source's active profile into target profile
					if nsData.profiles then
						if not db.sv.namespaces[namespace].profiles then
							db.sv.namespaces[namespace].profiles = {}
						end
						-- Find source profile data: prefer activeProfile key, fall back to first available
						local sourceData = sourceProfileKey and nsData.profiles[sourceProfileKey]
						if not sourceData then
							local firstKey = next(nsData.profiles)
							if firstKey then
								sourceData = nsData.profiles[firstKey]
							end
						end
						if sourceData then
							db.sv.namespaces[namespace].profiles[targetProfileKey] = sourceData
						end
					end
					importCount = importCount + 1
				end
			end
		end

		-- Import profiles: merge source's active profile into target profile
		if importData.profiles then
			if not db.sv.profiles then
				db.sv.profiles = {}
			end
			-- Find source profile data: prefer activeProfile key, fall back to first available
			local sourceProfileData = sourceProfileKey and importData.profiles[sourceProfileKey]
			if not sourceProfileData then
				local firstKey = next(importData.profiles)
				if firstKey then
					sourceProfileData = importData.profiles[firstKey]
				end
			end
			if sourceProfileData then
				db.sv.profiles[targetProfileKey] = sourceProfileData
				-- Prevent setup wizard from showing after import
				if type(sourceProfileData.SetupWizard) == 'table' then
					sourceProfileData.SetupWizard.FirstLaunch = false
				end
			end
		end
	end

	if importCount > 0 then
		local destMsg = ' to profile "' .. targetProfileKey .. '"'
		LibAT:Print('|cff00ff00Profile imported successfully!|r Imported ' .. importCount .. ' section(s) for ' .. addon.displayName .. destMsg)
		LibAT:Print('|cffff9900Please /reload to apply changes.|r')
	else
		LibAT:Print('|cffff0000No data was imported.|r')
	end
end

----------------------------------------------------------------------------------------------------
-- Lifecycle Hooks
----------------------------------------------------------------------------------------------------

-- Initialize ProfileManager system
function ProfileManager:Initialize()
	-- Initialize logger (now that Logger has finished loading)
	if LibAT.Logger and LibAT.Logger.RegisterAddon then
		ProfileManagerState.logger = LibAT.Logger.RegisterAddon('ProfileManager')
	end

	-- Register with LibAT
	LibAT:RegisterSystem('ProfileManager', self)

	-- Initialize UI module
	LibAT.ProfileManager.InitUI(ProfileManagerState)

	-- Auto-register LibAT itself if database is available
	if LibAT.Database then
		ProfileManager:RegisterAddon({
			id = 'libat',
			name = 'LibAT Core',
			db = LibAT.Database,
			icon = 'Interface\\AddOns\\Libs-AddonTools\\Logo-Icon',
		})
	end

	-- Create slash commands
	SLASH_LIBATPROFILES1 = '/libatprofiles'
	SLASH_LIBATPROFILES2 = '/profiles'
	SlashCmdList['LIBATPROFILES'] = function(msg)
		msg = msg:lower():trim()
		if msg == 'export' then
			ProfileManager:ExportUI()
		elseif msg == 'import' then
			ProfileManager:ImportUI()
		elseif msg == 'discover' or msg == 'refresh' then
			local count = ProfileManager.DiscoverAddons()
			LibAT:Print('Auto-discovery found ' .. count .. ' new addon(s)')
		else
			ProfileManager:ToggleWindow()
		end
	end

	-- Run auto-discovery after PLAYER_LOGIN when SavedVariables are available
	local discoveryFrame = CreateFrame('Frame')
	discoveryFrame:RegisterEvent('PLAYER_LOGIN')
	discoveryFrame:SetScript('OnEvent', function(frame)
		frame:UnregisterEvent('PLAYER_LOGIN')
		-- Delay slightly to allow other addons to finish loading
		C_Timer.After(2, function()
			if ProfileManager.DiscoverAddons then
				local count = ProfileManager.DiscoverAddons()
				if count > 0 and ProfileManagerState.logger then
					ProfileManagerState.logger.info('Auto-discovered ' .. count .. ' addon(s)')
				end
			end
		end)
	end)

	LibAT:Debug('Profile Manager initialized - Use /profiles to open')
	LibAT:Debug('Addons can register with: LibAT.ProfileManager:RegisterAddon({name = "MyAddon", db = MyAddonDB})')
end

----------------------------------------------------------------------------------------------------
-- UI Interface Functions (implemented in ProfileManagerUI.lua)
----------------------------------------------------------------------------------------------------

function ProfileManager:ImportUI()
	if not ProfileManagerState.window then
		LibAT.ProfileManager.CreateWindow()
	end
	ProfileManagerState.window.mode = 'import'
	LibAT.ProfileManager.UpdateWindowForMode()
end

function ProfileManager:ExportUI()
	if not ProfileManagerState.window then
		LibAT.ProfileManager.CreateWindow()
	end
	ProfileManagerState.window.mode = 'export'
	LibAT.ProfileManager.UpdateWindowForMode()
end

function ProfileManager:ToggleWindow()
	if not ProfileManagerState.window then
		LibAT.ProfileManager.CreateWindow()
	end
	if ProfileManagerState.window:IsVisible() then
		ProfileManagerState.window:Hide()
	else
		LibAT.ProfileManager.UpdateWindowForMode()
	end
end

-- Auto-initialize when loaded
ProfileManager:Initialize()

--[[
	REGISTRATION EXAMPLE FOR EXTERNAL ADDONS:

	-- Basic registration (no namespaces)
	local myAddonId = LibAT.ProfileManager:RegisterAddon({
		name = "My Addon",
		db = MyAddonDB  -- Your AceDB database object
	})

	-- Advanced registration (with namespaces and custom ID)
	local spartanId = LibAT.ProfileManager:RegisterAddon({
		id = "spartanui",  -- Optional: provide custom ID (defaults to auto-generated)
		name = "SpartanUI",
		db = SpartanUIDB,
		namespaces = {"PlayerFrame", "TargetFrame", "PartyFrame"},  -- Optional
		icon = "Interface\\AddOns\\SpartanUI\\Images\\Logo"  -- Optional
	})

	-- Later, navigate directly to export/import
	LibAT.ProfileManager:ShowExport("spartanui")  -- Opens export for SpartanUI
	LibAT.ProfileManager:ShowExport("spartanui", "PlayerFrame")  -- Export specific namespace
	LibAT.ProfileManager:ShowImport("spartanui")  -- Opens import for SpartanUI

	-- Unregister when addon unloads (optional)
	LibAT.ProfileManager:UnregisterAddon("spartanui")
]]
