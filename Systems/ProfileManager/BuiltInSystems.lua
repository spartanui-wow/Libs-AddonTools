---@class LibAT
local LibAT = LibAT
---@class LibAT.ProfileManager
local ProfileManager = LibAT.ProfileManager

-- Access shared state
local ProfileManagerState = LibAT.ProfileManager.ProfileManagerState
if not ProfileManagerState then
	error('ProfileManager state not initialized. Ensure ProfileManager.lua loads before BuiltInSystems.lua')
end

----------------------------------------------------------------------------------------------------
-- Built-In Systems Registry
----------------------------------------------------------------------------------------------------
-- This module defines built-in knowledge for common WoW addon systems that can be included
-- in composite exports. Each system can be referenced by a simple string ID (e.g., 'bartender4')
-- instead of requiring addons to provide full component definitions.

---@class BuiltInSystemDefinition
---@field displayName string User-friendly name shown in UI
---@field addonId? string Optional ProfileManager addon ID (for auto-discovered addons)
---@field isAvailable fun(): boolean Function to check if this system is available
---@field export? fun(): table|nil Optional custom export function (for non-addon systems)
---@field import? fun(data: table): boolean, string|nil Optional custom import function (returns success, error)

---Built-in system definitions for common WoW addons and systems
---@type table<string, BuiltInSystemDefinition>
local BuiltInSystems = {
	-- Action Bar Addons
	bartender4 = {
		displayName = 'Bartender4 Action Bars',
		addonId = 'discovered_bartender4',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_bartender4'] ~= nil
		end,
	},

	dominos = {
		displayName = 'Dominos Action Bars',
		addonId = 'discovered_dominos',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_dominos'] ~= nil
		end,
	},

	-- Blizzard Edit Mode (Retail only)
	editmode = {
		displayName = 'Edit Mode Layout',
		isAvailable = function()
			-- Check if Retail and C_EditMode exists
			local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
			return isRetail and C_EditMode ~= nil
		end,
		export = function()
			if not C_EditMode then
				return nil
			end

			local layouts = C_EditMode.GetLayouts()
			if not layouts or not layouts.layouts or not layouts.activeLayout then
				return nil
			end

			local activeLayout = layouts.layouts[layouts.activeLayout]
			if not activeLayout then
				return nil
			end

			-- Export the active layout
			return {
				version = '1.0.0',
				format = 'EditMode_Layout',
				layoutInfo = C_EditMode.ConvertLayoutInfoToString(activeLayout),
				accountSettings = C_EditMode.GetAccountSettings(),
				layoutName = activeLayout.layoutName,
				layoutType = activeLayout.layoutType,
			}
		end,
		import = function(data)
			if not C_EditMode then
				return false, 'Edit Mode not available (Retail only)'
			end

			if InCombatLockdown() then
				return false, 'Cannot import Edit Mode during combat'
			end

			-- Validate data structure
			if not data or not data.layoutInfo then
				return false, 'Invalid Edit Mode data'
			end

			-- Convert string to layout info
			local layoutInfo = C_EditMode.ConvertStringToLayoutInfo(data.layoutInfo)
			if not layoutInfo then
				return false, 'Failed to decode Edit Mode layout'
			end

			-- Get current layouts
			local currentLayouts = C_EditMode.GetLayouts()
			if not currentLayouts then
				return false, 'Failed to get current layouts'
			end

			-- Find existing layout by name or create new
			local existingLayoutIndex = nil
			for i, layout in ipairs(currentLayouts.layouts) do
				if layout.layoutName == data.layoutName then
					existingLayoutIndex = i
					break
				end
			end

			-- Save the layout
			if existingLayoutIndex then
				-- Update existing layout
				C_EditMode.SaveLayoutFromString(existingLayoutIndex, data.layoutInfo)
			else
				-- Create new layout
				local newLayoutIndex = #currentLayouts.layouts + 1
				C_EditMode.SaveLayoutFromString(newLayoutIndex, data.layoutInfo)
			end

			-- Apply account settings if present
			if data.accountSettings then
				for key, value in pairs(data.accountSettings) do
					C_EditMode.SetAccountSetting(key, value)
				end
			end

			-- Activate the layout
			local updatedLayouts = C_EditMode.GetLayouts()
			for i, layout in ipairs(updatedLayouts.layouts) do
				if layout.layoutName == data.layoutName then
					C_EditMode.SetActiveLayout(i)
					break
				end
			end

			return true
		end,
	},

	-- WeakAuras
	weakauras = {
		displayName = 'WeakAuras',
		addonId = 'discovered_weakauras',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_weakauras'] ~= nil
		end,
	},

	-- Nameplate Addons
	plater = {
		displayName = 'Plater Nameplates',
		addonId = 'discovered_plater',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_plater'] ~= nil
		end,
	},

	kui_nameplates = {
		displayName = 'Kui Nameplates',
		addonId = 'discovered_kuinameplates',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_kuinameplates'] ~= nil
		end,
	},

	-- Damage Meter Addons
	details = {
		displayName = 'Details! Damage Meter',
		addonId = 'discovered_details',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_details'] ~= nil
		end,
	},

	skada = {
		displayName = 'Skada Damage Meter',
		addonId = 'discovered_skada',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_skada'] ~= nil
		end,
	},

	-- Unit Frame Addons
	elvui = {
		displayName = 'ElvUI',
		addonId = 'discovered_elvui',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_elvui'] ~= nil
		end,
	},

	shadowanddlight = {
		displayName = 'Shadow & Light (ElvUI plugin)',
		addonId = 'discovered_elvui_shadowandlight',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_elvui_shadowandlight'] ~= nil
		end,
	},

	-- Bag Addons
	bagnon = {
		displayName = 'Bagnon',
		addonId = 'discovered_bagnon',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_bagnon'] ~= nil
		end,
	},

	adibags = {
		displayName = 'AdiBags',
		addonId = 'discovered_adibags',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_adibags'] ~= nil
		end,
	},

	betterbags = {
		displayName = 'BetterBags',
		addonId = 'discovered_betterbags',
		isAvailable = function()
			return ProfileManagerState.registeredAddons['discovered_betterbags'] ~= nil
		end,
	},
}

----------------------------------------------------------------------------------------------------
-- Built-In Systems API
----------------------------------------------------------------------------------------------------

---Get a built-in system definition by ID
---@param systemId string The system ID (e.g., 'bartender4', 'editmode')
---@return BuiltInSystemDefinition|nil systemDef The system definition or nil if not found
function ProfileManager:GetBuiltInSystem(systemId)
	return BuiltInSystems[systemId]
end

---Check if a system ID is a built-in system
---@param systemId string The system ID to check
---@return boolean isBuiltIn True if this is a built-in system
function ProfileManager:IsBuiltInSystem(systemId)
	return BuiltInSystems[systemId] ~= nil
end

---Normalize a component reference to a full component definition
---Handles both string IDs (built-in systems) and custom component tables
---@param component string|table Either a built-in system ID or a custom component definition
---@return table|nil componentDef The normalized component definition or nil if invalid
function ProfileManager:NormalizeComponent(component)
	-- If it's a string, look up built-in system
	if type(component) == 'string' then
		local builtIn = BuiltInSystems[component]
		if not builtIn then
			if LibAT.Log then
				LibAT.Log('Unknown built-in system: ' .. component, 'Libs - Addon Tools.ProfileManager.BuiltInSystems', 'warning')
			end
			return nil
		end

		-- Convert built-in definition to component format
		return {
			id = component,
			displayName = builtIn.displayName,
			addonId = builtIn.addonId,
			required = false,
			isAvailable = builtIn.isAvailable,
			export = builtIn.export,
			import = builtIn.import,
		}
	end

	-- If it's already a table, validate it has required fields
	if type(component) == 'table' then
		if not component.id or not component.displayName then
			if LibAT.Log then
				LibAT.Log('Invalid component definition: missing id or displayName', 'Libs - Addon Tools.ProfileManager.BuiltInSystems', 'error')
			end
			return nil
		end

		-- Ensure isAvailable function exists
		if not component.isAvailable then
			component.isAvailable = function()
				return true
			end
		end

		-- Set default required flag
		if component.required == nil then
			component.required = false
		end

		return component
	end

	-- Invalid component type
	if LibAT.Log then
		LibAT.Log('Invalid component type: ' .. type(component), 'Libs - Addon Tools.ProfileManager.BuiltInSystems', 'error')
	end
	return nil
end

---Get all built-in system IDs
---@return string[] systemIds Array of built-in system IDs
function ProfileManager:GetAllBuiltInSystemIds()
	local ids = {}
	for id in pairs(BuiltInSystems) do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

---Get all available built-in systems (currently installed/enabled)
---@return table<string, BuiltInSystemDefinition> availableSystems Map of available system ID to definition
function ProfileManager:GetAvailableBuiltInSystems()
	local available = {}
	for id, system in pairs(BuiltInSystems) do
		if system.isAvailable() then
			available[id] = system
		end
	end
	return available
end
