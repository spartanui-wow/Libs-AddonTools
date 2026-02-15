---@class LibAT
local LibAT = LibAT
---@class LibAT.ProfileManager
local ProfileManager = LibAT.ProfileManager

----------------------------------------------------------------------------------------------------
-- Utility Functions
----------------------------------------------------------------------------------------------------

---Check if a path matches any blacklist pattern
---Uses shared blacklist from ProfileManagerState (registered via ProfileManager:RegisterExportBlacklist)
---@param path string The current path being checked (e.g., "Chatbox.chatLog.history")
---@return boolean matches True if the path should be excluded from export
local function IsPathBlacklisted(path)
	local blacklist = ProfileManagerState.exportBlacklist or {}
	for _, pattern in ipairs(blacklist) do
		-- Convert wildcard pattern to Lua pattern
		local luaPattern = '^' .. pattern:gsub('%*', '.-') .. '$'
		if path:match(luaPattern) then
			return true
		end
	end
	return false
end

---Strip default values from data by comparing against defaults table
---Only exports values that differ from defaults (Configuration Override Pattern)
---@param data table The data to check (user's merged data)
---@param defaults table|nil The default values to compare against
---@return table|nil strippedData The data with defaults removed, or nil if everything is default
local function StripDefaults(data, defaults)
	if type(data) ~= 'table' then
		-- If not a table, compare directly with default
		if defaults == nil then
			-- No default exists, export the value
			return data
		elseif data == defaults then
			-- Value matches default, don't export
			return nil
		else
			-- Value differs from default, export it
			return data
		end
	end

	-- Both are tables, compare recursively
	local result = {}
	local hasChanges = false

	for key, value in pairs(data) do
		local defaultValue = defaults and defaults[key]
		local stripped = StripDefaults(value, defaultValue)

		if stripped ~= nil then
			result[key] = stripped
			hasChanges = true
		end
	end

	-- Only return the table if it has changes from defaults
	return hasChanges and result or nil
end

---Remove empty tables and blacklisted paths from a data structure (deep copy with pruning)
---@param data table The table to prune
---@param currentPath? string Internal: current path for blacklist checking
---@return table|nil prunedData The pruned table, or nil if the entire table is empty
local function PruneEmptyTables(data, currentPath)
	if type(data) ~= 'table' then
		return data
	end

	currentPath = currentPath or ''
	local result = {}
	local hasContent = false

	for key, value in pairs(data) do
		local keyPath = currentPath ~= '' and (currentPath .. '.' .. key) or key

		-- Skip blacklisted paths
		if IsPathBlacklisted(keyPath) then
			-- Skip this key entirely (don't include in export)
			if LibAT.Log then
				LibAT.Log('Excluding blacklisted path from export: ' .. keyPath, 'Libs - Addon Tools.ProfileManager.Composite', 'debug')
			end
		elseif type(value) == 'table' then
			local pruned = PruneEmptyTables(value, keyPath)
			if pruned ~= nil then
				result[key] = pruned
				hasContent = true
			end
		else
			result[key] = value
			hasContent = true
		end
	end

	return hasContent and result or nil
end

----------------------------------------------------------------------------------------------------
-- Type Definitions
----------------------------------------------------------------------------------------------------

---@class CompositeDefinition
---@field id string Unique identifier for this composite (e.g., 'spartanui_full')
---@field displayName string User-friendly name (e.g., 'SpartanUI (Full Profile)')
---@field description string Description shown in UI
---@field primaryAddonId string The main addon ID (always included, registered with ProfileManager)
---@field components table[] Array of component definitions (built-in IDs or custom definitions)

---@class CompositeComponent
---@field id string Unique identifier for this component
---@field displayName string User-friendly name shown in UI
---@field addonId? string Optional ProfileManager addon ID (for registered addons)
---@field required boolean Whether this component must be included (default: false)
---@field isAvailable fun(): boolean Function to check if this component is available
---@field export? fun(): table|nil Optional custom export function (returns data or nil if unavailable)
---@field import? fun(data: table): boolean, string|nil Optional custom import function (returns success, error)

---@class CompositeExport
---@field version string Composite format version (e.g., '4.0.0')
---@field timestamp string Export timestamp (YYYY-MM-DD HH:MM:SS)
---@field format string Always 'ProfileManager_Composite'
---@field compositeId string ID of the composite definition used
---@field components table<string, table> Map of component ID to exported data
---@field included table<string, boolean> Map of component ID to whether it was included

----------------------------------------------------------------------------------------------------
-- Shared State Extension
----------------------------------------------------------------------------------------------------

-- Access shared state (initialized in ProfileManager.lua)
local ProfileManagerState = LibAT.ProfileManager.ProfileManagerState
if not ProfileManagerState then
	error('ProfileManager state not initialized. Ensure ProfileManager.lua loads before Composite.lua')
end

-- Add composites storage to shared state
ProfileManagerState.composites = ProfileManagerState.composites or {}

----------------------------------------------------------------------------------------------------
-- Registration API
----------------------------------------------------------------------------------------------------

---Register a composite definition with ProfileManager
---@param config CompositeDefinition Configuration table with id, displayName, primaryAddonId, components
---@return boolean success True if registration succeeded
---@return string|nil error Error message if registration failed
function ProfileManager:RegisterComposite(config)
	-- Validate required fields
	if not config or type(config) ~= 'table' then
		local err = 'RegisterComposite: config must be a table'
		if LibAT.Log then
			LibAT.Log(err, 'Libs - Addon Tools.ProfileManager.Composite', 'error')
		end
		return false, err
	end

	if not config.id or type(config.id) ~= 'string' then
		local err = 'RegisterComposite: config.id is required and must be a string'
		if LibAT.Log then
			LibAT.Log(err, 'Libs - Addon Tools.ProfileManager.Composite', 'error')
		end
		return false, err
	end

	if not config.displayName or type(config.displayName) ~= 'string' then
		local err = 'RegisterComposite: config.displayName is required and must be a string'
		if LibAT.Log then
			LibAT.Log(err, 'Libs - Addon Tools.ProfileManager.Composite', 'error')
		end
		return false, err
	end

	if not config.primaryAddonId or type(config.primaryAddonId) ~= 'string' then
		local err = 'RegisterComposite: config.primaryAddonId is required and must be a string'
		if LibAT.Log then
			LibAT.Log(err, 'Libs - Addon Tools.ProfileManager.Composite', 'error')
		end
		return false, err
	end

	-- Validate primary addon is registered
	if not ProfileManagerState.registeredAddons[config.primaryAddonId] then
		local err = 'RegisterComposite: primaryAddonId "' .. config.primaryAddonId .. '" is not registered with ProfileManager'
		if LibAT.Log then
			LibAT.Log(err, 'Libs - Addon Tools.ProfileManager.Composite', 'error')
		end
		return false, err
	end

	-- Normalize components list (convert string IDs to full definitions using BuiltInSystems)
	local normalizedComponents = {}
	if config.components and type(config.components) == 'table' then
		for _, component in ipairs(config.components) do
			local normalized = ProfileManager:NormalizeComponent(component)
			if normalized then
				table.insert(normalizedComponents, normalized)
			else
				if LibAT.Log then
					LibAT.Log('Skipping invalid component in composite "' .. config.id .. '"', 'Libs - Addon Tools.ProfileManager.Composite', 'warning')
				end
			end
		end
	end

	-- Store composite definition
	ProfileManagerState.composites[config.id] = {
		id = config.id,
		displayName = config.displayName,
		description = config.description or '',
		primaryAddonId = config.primaryAddonId,
		components = normalizedComponents,
	}

	if LibAT.Log then
		LibAT.Log(
			'Registered composite "' .. config.displayName .. '" (ID: ' .. config.id .. ') with ' .. #normalizedComponents .. ' components',
			'Libs - Addon Tools.ProfileManager.Composite',
			'debug'
		)
	end

	return true
end

---Add a component to an existing composite definition
---Useful for plugin ecosystems where plugins self-register with a core addon's composite
---@param compositeId string The composite ID to add to
---@param component string|table Built-in system ID or custom component definition
---@return boolean success True if component was added
---@return string|nil error Error message if addition failed
function ProfileManager:AddToComposite(compositeId, component)
	-- Validate composite exists
	if not ProfileManagerState.composites[compositeId] then
		local err = 'AddToComposite: Composite "' .. compositeId .. '" is not registered'
		if LibAT.Log then
			LibAT.Log(err, 'Libs - Addon Tools.ProfileManager.Composite', 'error')
		end
		return false, err
	end

	-- Normalize component
	local normalized = ProfileManager:NormalizeComponent(component)
	if not normalized then
		local err = 'AddToComposite: Invalid component'
		if LibAT.Log then
			LibAT.Log(err, 'Libs - Addon Tools.ProfileManager.Composite', 'error')
		end
		return false, err
	end

	-- Check if component already exists
	local composite = ProfileManagerState.composites[compositeId]
	for _, existing in ipairs(composite.components) do
		if existing.id == normalized.id then
			if LibAT.Log then
				LibAT.Log('Component "' .. normalized.id .. '" already exists in composite "' .. compositeId .. '"', 'Libs - Addon Tools.ProfileManager.Composite', 'warning')
			end
			return true -- Not an error, just a no-op
		end
	end

	-- Add component
	table.insert(composite.components, normalized)

	if LibAT.Log then
		LibAT.Log('Added component "' .. normalized.displayName .. '" to composite "' .. compositeId .. '"', 'Libs - Addon Tools.ProfileManager.Composite', 'debug')
	end

	return true
end

---Get a registered composite definition
---@param compositeId string The composite ID
---@return CompositeDefinition|nil composite The composite definition or nil if not found
function ProfileManager:GetComposite(compositeId)
	return ProfileManagerState.composites[compositeId]
end

---Check if an addon has a registered composite
---@param addonId string The addon ID
---@return string|nil compositeId The composite ID if one exists for this addon
function ProfileManager:GetCompositeForAddon(addonId)
	for id, composite in pairs(ProfileManagerState.composites) do
		if composite.primaryAddonId == addonId then
			return id
		end
	end
	return nil
end

----------------------------------------------------------------------------------------------------
-- Export/Import Logic
----------------------------------------------------------------------------------------------------

---Export a registered addon using the existing ProfileManager export logic
---@param addonId string The addon ID (must be registered with ProfileManager)
---@return table|nil exportData The exported data or nil if export failed
---@return string|nil error Error message if export failed
local function ExportRegisteredAddon(addonId)
	local addon = ProfileManagerState.registeredAddons[addonId]
	if not addon then
		return nil, 'Addon "' .. addonId .. '" is not registered'
	end

	local db = addon.db
	if not db or not db.sv then
		return nil, 'Invalid AceDB object for ' .. addon.displayName
	end

	-- Build export data (same structure as ProfileManager:DoExport)
	local exportData = {
		version = '3.0.0',
		timestamp = date('%Y-%m-%d %H:%M:%S'),
		addon = addon.displayName,
		addonId = addon.id,
		data = {},
	}

	-- Get defaults from AceDB for stripping (Configuration Override Pattern)
	local profileDefaults = db.defaults and db.defaults.profile

	-- Export all namespaces (excluding blacklist)
	if db.sv.namespaces then
		for namespace, nsData in pairs(db.sv.namespaces) do
			if not tContains(ProfileManagerState.namespaceblacklist, namespace) then
				-- Get namespace defaults from AceDB
				local nsDefaults = db.defaults and db.defaults.namespaces and db.defaults.namespaces[namespace]
				local strippedData = StripDefaults(nsData, nsDefaults)
				local pruned = PruneEmptyTables(strippedData)
				if pruned then
					exportData.data[namespace] = pruned
				end
			end
		end
	end

	-- Export only the ACTIVE profile (not all profiles)
	-- This prevents bloat from exporting unused character profiles
	if db.sv.profiles then
		local currentProfileKey = db.keys and db.keys.profile or 'Default'
		if db.sv.profiles[currentProfileKey] then
			-- Strip defaults first, then prune empty tables
			local strippedData = StripDefaults(db.sv.profiles[currentProfileKey], profileDefaults)
			local pruned = PruneEmptyTables(strippedData)
			if pruned then
				exportData.profiles = { [currentProfileKey] = pruned }
			end
		end
	end

	-- Record which profile was active at export time
	exportData.activeProfile = db.keys and db.keys.profile or 'Default'

	return exportData
end

---Import to a registered addon using the existing ProfileManager import logic
---@param addonId string The addon ID (must be registered with ProfileManager)
---@param data table The exported data to import
---@return boolean success True if import succeeded
---@return string|nil error Error message if import failed
local function ImportRegisteredAddon(addonId, data)
	local addon = ProfileManagerState.registeredAddons[addonId]
	if not addon then
		return false, 'Addon "' .. addonId .. '" is not registered'
	end

	local db = addon.db
	if not db or not db.sv then
		return false, 'Invalid AceDB object for ' .. addon.displayName
	end

	-- Validate data structure
	if not data.addonId or not data.data then
		return false, 'Invalid export data structure'
	end

	-- Import namespaces
	if data.data and type(data.data) == 'table' then
		if not db.sv.namespaces then
			db.sv.namespaces = {}
		end

		for namespace, nsData in pairs(data.data) do
			if not tContains(ProfileManagerState.namespaceblacklist, namespace) then
				db.sv.namespaces[namespace] = nsData
			end
		end
	end

	-- Import profiles if present
	if data.profiles and type(data.profiles) == 'table' then
		if not db.sv.profiles then
			db.sv.profiles = {}
		end

		for profileName, profileData in pairs(data.profiles) do
			db.sv.profiles[profileName] = profileData
		end
	end

	return true
end

---Export a single component (handles both registered addons and custom export functions)
---@param component CompositeComponent The component definition
---@return table|nil exportData The exported data or nil if unavailable/failed
---@return string|nil error Error message if export failed
local function ExportComponent(component)
	-- Check if component is available
	if not component.isAvailable() then
		return nil, 'Component "' .. component.displayName .. '" is not available'
	end

	-- If component has addonId, use ProfileManager export
	if component.addonId then
		return ExportRegisteredAddon(component.addonId)
	end

	-- If component has custom export function, use it
	if component.export then
		local success, result = pcall(component.export)
		if not success then
			return nil, 'Export function failed: ' .. tostring(result)
		end
		return result
	end

	return nil, 'Component has no export method'
end

---Import a single component (handles both registered addons and custom import functions)
---@param component CompositeComponent The component definition
---@param data table The exported data to import
---@return boolean success True if import succeeded
---@return string|nil error Error message if import failed
local function ImportComponent(component, data)
	-- Check if component is available
	if not component.isAvailable() then
		if LibAT.Log then
			LibAT.Log('Skipping unavailable component: ' .. component.displayName, 'Libs - Addon Tools.ProfileManager.Composite', 'info')
		end
		return true -- Not an error, just skip
	end

	-- If component has addonId, use ProfileManager import
	if component.addonId then
		return ImportRegisteredAddon(component.addonId, data)
	end

	-- If component has custom import function, use it
	if component.import then
		local success, result, err = pcall(component.import, data)
		if not success then
			return false, 'Import function failed: ' .. tostring(result)
		end
		return result, err
	end

	return false, 'Component has no import method'
end

---Create a composite export bundle
---@param compositeId string The composite ID
---@param selectedComponents? table<string, boolean> Optional map of component IDs to include (nil = all)
---@return table|nil exportData The composite export data or nil if failed
---@return string|nil error Error message if export failed
function ProfileManager:CreateCompositeExport(compositeId, selectedComponents)
	-- Get composite definition
	local composite = ProfileManagerState.composites[compositeId]
	if not composite then
		return nil, 'Composite "' .. compositeId .. '" is not registered'
	end

	-- Build composite export structure
	local compositeExport = {
		version = '4.0.0',
		timestamp = date('%Y-%m-%d %H:%M:%S'),
		format = 'ProfileManager_Composite',
		compositeId = compositeId,
		components = {},
		included = {},
	}

	-- Always export primary addon
	local primaryData, primaryErr = ExportRegisteredAddon(composite.primaryAddonId)
	if not primaryData then
		return nil, 'Failed to export primary addon: ' .. tostring(primaryErr)
	end
	compositeExport.components[composite.primaryAddonId] = primaryData
	compositeExport.included[composite.primaryAddonId] = true

	-- Export selected components
	for _, component in ipairs(composite.components) do
		-- Check if this component should be included
		local shouldInclude = true
		if selectedComponents then
			shouldInclude = selectedComponents[component.id] == true
		end

		if shouldInclude then
			local componentData, componentErr = ExportComponent(component)
			if componentData then
				compositeExport.components[component.id] = componentData
				compositeExport.included[component.id] = true
			else
				if LibAT.Log then
					LibAT.Log('Skipping component "' .. component.displayName .. '": ' .. tostring(componentErr), 'Libs - Addon Tools.ProfileManager.Composite', 'warning')
				end
			end
		end
	end

	return compositeExport
end

---Import a composite export bundle
---@param compositeData table The composite export data (decoded from base64)
---@param options? table Optional import options
---@return boolean success True if import succeeded
---@return table summary Import summary with component results
function ProfileManager:ImportComposite(compositeData, options)
	options = options or {}

	-- Validate composite format
	if not compositeData or compositeData.format ~= 'ProfileManager_Composite' then
		return false, { error = 'Invalid composite format' }
	end

	if not compositeData.version then
		return false, { error = 'Missing composite version' }
	end

	-- Version compatibility check (reject if major version > 4)
	local majorVersion = tonumber(compositeData.version:match('^(%d+)'))
	if not majorVersion or majorVersion > 4 then
		return false, { error = 'Unsupported composite version: ' .. compositeData.version }
	end

	-- Get composite definition
	local composite = ProfileManagerState.composites[compositeData.compositeId]
	if not composite then
		return false, { error = 'Composite "' .. compositeData.compositeId .. '" is not registered' }
	end

	-- Build component lookup map
	local componentMap = {}
	componentMap[composite.primaryAddonId] = {
		id = composite.primaryAddonId,
		displayName = ProfileManagerState.registeredAddons[composite.primaryAddonId].displayName,
		addonId = composite.primaryAddonId,
		isAvailable = function()
			return true
		end,
	}
	for _, component in ipairs(composite.components) do
		componentMap[component.id] = component
	end

	-- Import results
	local results = {
		success = true,
		componentResults = {},
		componentCount = 0,
		successCount = 0,
		skippedCount = 0,
		errorCount = 0,
	}

	-- Import each component
	for componentId, componentData in pairs(compositeData.components) do
		local component = componentMap[componentId]
		if component then
			results.componentCount = results.componentCount + 1

			local success, err = ImportComponent(component, componentData)
			if success then
				results.successCount = results.successCount + 1
				results.componentResults[componentId] = { success = true }
			else
				results.errorCount = results.errorCount + 1
				results.componentResults[componentId] = { success = false, error = err }
				if LibAT.Log then
					LibAT.Log('Failed to import component "' .. component.displayName .. '": ' .. tostring(err), 'Libs - Addon Tools.ProfileManager.Composite', 'error')
				end
			end
		else
			results.skippedCount = results.skippedCount + 1
			if LibAT.Log then
				LibAT.Log('Skipping unknown component: ' .. componentId, 'Libs - Addon Tools.ProfileManager.Composite', 'warning')
			end
		end
	end

	return results.errorCount == 0, results
end

---Analyze a composite export without importing
---@param compositeData table The composite export data (decoded from base64)
---@return table|nil analysis Analysis summary or nil if invalid
function ProfileManager:AnalyzeComposite(compositeData)
	-- Validate composite format
	if not compositeData or compositeData.format ~= 'ProfileManager_Composite' then
		return nil
	end

	-- Get composite definition
	local composite = ProfileManagerState.composites[compositeData.compositeId]
	if not composite then
		return {
			valid = false,
			error = 'Composite "' .. compositeData.compositeId .. '" is not registered',
		}
	end

	-- Build component lookup
	local componentMap = {}
	componentMap[composite.primaryAddonId] = {
		id = composite.primaryAddonId,
		displayName = ProfileManagerState.registeredAddons[composite.primaryAddonId].displayName,
		isAvailable = function()
			return true
		end,
	}
	for _, component in ipairs(composite.components) do
		componentMap[component.id] = component
	end

	-- Analyze components
	local analysis = {
		valid = true,
		compositeId = compositeData.compositeId,
		compositeName = composite.displayName,
		version = compositeData.version,
		timestamp = compositeData.timestamp,
		components = {},
		totalCount = 0,
		availableCount = 0,
		unavailableCount = 0,
	}

	for componentId, componentData in pairs(compositeData.components) do
		local component = componentMap[componentId]
		if component then
			analysis.totalCount = analysis.totalCount + 1
			local available = component.isAvailable()
			if available then
				analysis.availableCount = analysis.availableCount + 1
			else
				analysis.unavailableCount = analysis.unavailableCount + 1
			end

			table.insert(analysis.components, {
				id = componentId,
				name = component.displayName,
				available = available,
			})
		end
	end

	return analysis
end

if LibAT.Log then
	LibAT.Log('Composite module loaded', 'Libs - Addon Tools.ProfileManager.Composite', 'debug')
end
