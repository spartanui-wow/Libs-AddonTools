---@class LibAT.ProfileManager
local LibAT = _G.LibAT
if not LibAT then
	return
end

local ProfileManager = {}

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
	LibAT:Print('[ProfileManager] ShowExport called for addonId: ' .. tostring(addonId))
	if ProfileManagerState.logger then
		ProfileManagerState.logger.debug('ShowExport called for addonId: ' .. tostring(addonId))
	else
		LibAT:Print('[ProfileManager] WARNING: logger is nil!')
	end

	if not ProfileManagerState.registeredAddons[addonId] then
		LibAT:Print('|cffff0000Error:|r Addon with ID "' .. addonId .. '" is not registered')
		return
	end

	if not ProfileManagerState.window then
		LibAT:Print('[ProfileManager] Window does not exist, creating...')
		local success, err = pcall(LibAT.ProfileManager.CreateWindow)
		if not success then
			LibAT:Print('[ProfileManager] ERROR: CreateWindow threw error: ' .. tostring(err))
			return
		end
		if not ProfileManagerState.window then
			LibAT:Print('[ProfileManager] ERROR: Failed to create window!')
			if ProfileManagerState.logger then
				ProfileManagerState.logger.error('Failed to create ProfileManager window')
			end
			return
		end
		LibAT:Print('[ProfileManager] Window created successfully')
	end

	-- Set mode and active addon
	ProfileManagerState.window.mode = 'export'
	ProfileManagerState.window.activeAddonId = addonId
	ProfileManagerState.window.activeNamespace = namespace

	if ProfileManagerState.logger then
		ProfileManagerState.logger.debug('Calling UpdateWindowForMode()')
	end

	-- Build navigation key
	local navKey = 'Addons.' .. addonId .. '.Export'
	if namespace then
		navKey = navKey .. '.' .. namespace
	end

	-- Update navigation tree
	if ProfileManagerState.window.NavTree then
		ProfileManagerState.window.NavTree.config.activeKey = navKey
		LibAT.ProfileManager.BuildNavigationTree()
	end

	LibAT.ProfileManager.UpdateWindowForMode()

	LibAT:Print('[ProfileManager] ShowExport completed, window visibility: ' .. tostring(ProfileManagerState.window:IsVisible()))
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
	local navKey = 'Addons.' .. addonId .. '.Import'
	if namespace then
		navKey = navKey .. '.' .. namespace
	end

	-- Update navigation tree
	if ProfileManagerState.window.NavTree then
		ProfileManagerState.window.NavTree.config.activeKey = navKey
		LibAT.ProfileManager.BuildNavigationTree()
	end

	LibAT.ProfileManager.UpdateWindowForMode()
end

----------------------------------------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------------------------------------

---Build navigation tree categories from registered addons
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

		-- Create subcategories for Import and Export
		local subCategories = {}
		local sortedKeys = {}

		-- Import subcategory
		if hasNamespaces then
			-- Add Import with namespace options
			subCategories['Import'] = {
				name = 'Import',
				key = categoryKey .. '.Import',
				expanded = false,
				subCategories = {},
				sortedKeys = {},
			}

			-- Add "ALL" option
			subCategories['Import'].subCategories['ALL'] = {
				name = 'All Namespaces',
				key = categoryKey .. '.Import.ALL',
				onSelect = function()
					ProfileManagerState.window.mode = 'import'
					ProfileManagerState.window.activeAddonId = addonId
					ProfileManagerState.window.activeNamespace = nil
					LibAT.ProfileManager.UpdateWindowForMode()
				end,
			}
			table.insert(subCategories['Import'].sortedKeys, 'ALL')

			-- Add individual namespaces
			for _, ns in ipairs(addon.namespaces) do
				subCategories['Import'].subCategories[ns] = {
					name = ns,
					key = categoryKey .. '.Import.' .. ns,
					onSelect = function()
						ProfileManagerState.window.mode = 'import'
						ProfileManagerState.window.activeAddonId = addonId
						ProfileManagerState.window.activeNamespace = ns
						LibAT.ProfileManager.UpdateWindowForMode()
					end,
				}
				table.insert(subCategories['Import'].sortedKeys, ns)
			end
		else
			-- Simple import without namespaces
			subCategories['Import'] = {
				name = 'Import',
				key = categoryKey .. '.Import',
				onSelect = function()
					ProfileManagerState.window.mode = 'import'
					ProfileManagerState.window.activeAddonId = addonId
					ProfileManagerState.window.activeNamespace = nil
					LibAT.ProfileManager.UpdateWindowForMode()
				end,
			}
		end
		table.insert(sortedKeys, 'Import')

		-- Export subcategory (same structure as Import)
		if hasNamespaces then
			subCategories['Export'] = {
				name = 'Export',
				key = categoryKey .. '.Export',
				expanded = false,
				subCategories = {},
				sortedKeys = {},
			}

			-- Add "ALL" option
			subCategories['Export'].subCategories['ALL'] = {
				name = 'All Namespaces',
				key = categoryKey .. '.Export.ALL',
				onSelect = function()
					ProfileManagerState.window.mode = 'export'
					ProfileManagerState.window.activeAddonId = addonId
					ProfileManagerState.window.activeNamespace = nil
					LibAT.ProfileManager.UpdateWindowForMode()
				end,
			}
			table.insert(subCategories['Export'].sortedKeys, 'ALL')

			-- Add individual namespaces
			for _, ns in ipairs(addon.namespaces) do
				subCategories['Export'].subCategories[ns] = {
					name = ns,
					key = categoryKey .. '.Export.' .. ns,
					onSelect = function()
						ProfileManagerState.window.mode = 'export'
						ProfileManagerState.window.activeAddonId = addonId
						ProfileManagerState.window.activeNamespace = ns
						LibAT.ProfileManager.UpdateWindowForMode()
					end,
				}
				table.insert(subCategories['Export'].sortedKeys, ns)
			end
		else
			-- Simple export without namespaces
			subCategories['Export'] = {
				name = 'Export',
				key = categoryKey .. '.Export',
				onSelect = function()
					ProfileManagerState.window.mode = 'export'
					ProfileManagerState.window.activeAddonId = addonId
					ProfileManagerState.window.activeNamespace = nil
					LibAT.ProfileManager.UpdateWindowForMode()
				end,
			}
		end
		table.insert(sortedKeys, 'Export')

		-- Create main category
		categories[addonId] = {
			name = addon.displayName,
			key = categoryKey,
			expanded = false,
			icon = addon.icon,
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
		version = '2.0.0',
		timestamp = date('%Y-%m-%d %H:%M:%S'),
		addon = addon.displayName,
		addonId = addon.id,
		data = {},
	}

	-- Export based on namespace selection
	if ProfileManagerState.window.activeNamespace then
		-- Export single namespace
		if db.sv.namespaces and db.sv.namespaces[ProfileManagerState.window.activeNamespace] then
			exportData.data[ProfileManagerState.window.activeNamespace] = db.sv.namespaces[ProfileManagerState.window.activeNamespace]
			exportData.namespace = ProfileManagerState.window.activeNamespace
		else
			LibAT:Print('|cffff0000Error:|r Namespace "' .. ProfileManagerState.window.activeNamespace .. '" not found')
			return
		end
	else
		-- Export all namespaces (excluding blacklist)
		if db.sv.namespaces then
			for namespace, data in pairs(db.sv.namespaces) do
				if not tContains(ProfileManagerState.namespaceblacklist, namespace) then
					exportData.data[namespace] = data
				end
			end
		end

		-- Also export profile data if available
		if db.sv.profiles then
			exportData.profiles = db.sv.profiles
		end
	end

	-- Serialize to string
	local exportString = '-- ' .. addon.displayName .. ' Profile Export\n'
	exportString = exportString .. '-- Generated: ' .. exportData.timestamp .. '\n'
	exportString = exportString .. '-- Version: ' .. exportData.version .. '\n'
	if ProfileManagerState.window.activeNamespace then
		exportString = exportString .. '-- Namespace: ' .. ProfileManagerState.window.activeNamespace .. '\n'
	end
	exportString = exportString .. '\n'

	local function serializeTable(tbl, indent)
		indent = indent or ''
		local result = '{\n'
		for k, v in pairs(tbl) do
			result = result .. indent .. '  [' .. string.format('%q', tostring(k)) .. '] = '
			if type(v) == 'table' then
				result = result .. serializeTable(v, indent .. '  ')
			else
				result = result .. string.format('%q', tostring(v))
			end
			result = result .. ',\n'
		end
		result = result .. indent .. '}'
		return result
	end

	exportString = exportString .. 'return ' .. serializeTable(exportData)

	ProfileManagerState.window.EditBox:SetText(exportString)
	ProfileManagerState.window.EditBox:SetCursorPosition(0)
	ProfileManagerState.window.EditBox:HighlightText(0)

	LibAT:Print('|cff00ff00Profile exported successfully!|r Select all (Ctrl+A) and copy (Ctrl+C).')
end

-- Import function - Works with registered addons
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

	-- Try to parse the import data
	local success, importData = pcall(loadstring(importText))
	if not success or type(importData) ~= 'table' then
		LibAT:Print('|cffff0000Invalid profile data. Please check the format.|r')
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

	-- Apply import data
	local importCount = 0

	if ProfileManagerState.window.activeNamespace then
		-- Import single namespace
		if importData.namespace and importData.namespace == ProfileManagerState.window.activeNamespace then
			if importData.data[ProfileManagerState.window.activeNamespace] then
				if not db.sv.namespaces then
					db.sv.namespaces = {}
				end
				db.sv.namespaces[ProfileManagerState.window.activeNamespace] = importData.data[ProfileManagerState.window.activeNamespace]
				importCount = 1
			else
				LibAT:Print('|cffff0000Error:|r Import data does not contain namespace "' .. ProfileManagerState.window.activeNamespace .. '"')
				return
			end
		else
			LibAT:Print('|cffff0000Error:|r Import data namespace mismatch')
			return
		end
	else
		-- Import all namespaces
		if importData.data then
			if not db.sv.namespaces then
				db.sv.namespaces = {}
			end
			for namespace, data in pairs(importData.data) do
				if not tContains(ProfileManagerState.namespaceblacklist, namespace) then
					db.sv.namespaces[namespace] = data
					importCount = importCount + 1
				end
			end
		end

		-- Import profiles if available
		if importData.profiles then
			db.sv.profiles = importData.profiles
		end
	end

	if importCount > 0 then
		LibAT:Print('|cff00ff00Profile imported successfully!|r Imported ' .. importCount .. ' namespace(s) for ' .. addon.displayName)
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
		else
			ProfileManager:ToggleWindow()
		end
	end

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

-- Export ProfileManager to LibAT namespace (at end of file after all methods are defined)
LibAT.ProfileManager = ProfileManager

return ProfileManager
