---@class LibAT
local LibAT = LibAT
---@class LibAT.ProfileManager
local ProfileManager = LibAT.ProfileManager

----------------------------------------------------------------------------------------------------
-- Auto-Discovery System
-- Discovers and registers addons that haven't opted in via RegisterAddon()
-- Inspired by Import-Hub's adapter pattern
----------------------------------------------------------------------------------------------------

---@class DiscoveryAdapter
---@field display string Display name for the addon
---@field icon? string Optional icon path
---@field isReady fun(): boolean Check if addon is loaded and accessible
---@field getDatabase fun(): table|nil Return a table with .sv field pointing to SavedVariables
---@field getNamespaces? fun(): string[]|nil Optional: return list of namespace names

-- Storage for discovery adapters
local discoveryAdapters = {}

-- Track which adapters have been registered to avoid duplicates
local discoveredAddons = {}

---Register a discovery adapter for a known addon
---@param key string Unique key for this adapter
---@param adapter DiscoveryAdapter The adapter configuration
function ProfileManager.RegisterDiscoveryAdapter(key, adapter)
	if not key or type(key) ~= 'string' then
		error('RegisterDiscoveryAdapter: key must be a string')
	end
	if not adapter or type(adapter) ~= 'table' then
		error('RegisterDiscoveryAdapter: adapter must be a table')
	end
	if not adapter.display or type(adapter.display) ~= 'string' then
		error('RegisterDiscoveryAdapter: adapter.display is required')
	end
	if not adapter.isReady or type(adapter.isReady) ~= 'function' then
		error('RegisterDiscoveryAdapter: adapter.isReady must be a function')
	end
	if not adapter.getDatabase or type(adapter.getDatabase) ~= 'function' then
		error('RegisterDiscoveryAdapter: adapter.getDatabase must be a function')
	end

	discoveryAdapters[key] = adapter
end

---Detect duplicate addon display names across all registered addons
---@return table<string, boolean> duplicateNames Map of addon names that appear more than once
function ProfileManager.GetDuplicateAddons()
	local addonNames = {}
	local duplicateNames = {}
	local registeredAddons = ProfileManager:GetRegisteredAddons()

	-- Count how many times each display name appears
	for addonId, addon in pairs(registeredAddons) do
		local name = addon.displayName
		if addonNames[name] then
			duplicateNames[name] = true
		else
			addonNames[name] = true
		end
	end

	return duplicateNames
end

---Scan AceDB.db_registry for addons not covered by manual adapters
---@return number count Number of newly discovered addons via registry
function ProfileManager.DiscoverViaRegistry()
	local count = 0

	-- Get AceDB library
	local AceDB = LibStub and LibStub('AceDB-3.0', true)
	if not AceDB or not AceDB.db_registry then
		return 0
	end

	-- Track duplicate names for suffix appending
	local duplicateNames = ProfileManager.GetDuplicateAddons()

	-- Scan registry for unknown addons
	for db, _ in pairs(AceDB.db_registry) do
		-- Only process root databases (not child namespaces)
		if not db.parent then
			-- Use issecurevariable to extract addon name from SavedVariables
			local _, addonName = issecurevariable(db, 'sv')
			if addonName and type(addonName) == 'string' then
				-- Generate unique ID for this addon
				local addonId = 'registry_' .. addonName

				-- Check if this addon should be skipped (already registered)
				local shouldSkip = false

				-- Skip if already discovered by manual adapters
				if discoveredAddons[addonName] then
					shouldSkip = true
				end

				-- Skip if already registered via registry (previous scan)
				local registeredAddons = ProfileManager:GetRegisteredAddons()
				if not shouldSkip and registeredAddons[addonId] then
					shouldSkip = true
				end

				-- Check if any registered addon is using this same SavedVariables global
				-- (prevents duplicates when manual adapter and registry both find same addon)
				if not shouldSkip then
					local svName = ProfileManager.FindGlobal(db.sv)
					if svName then
						for _, registeredAddon in pairs(registeredAddons) do
							local registeredSvName = ProfileManager.FindGlobal(registeredAddon.db.sv)
							if registeredSvName == svName then
								-- Same SavedVariables global already registered, skip
								shouldSkip = true
								break
							end
						end
					end
				end

				-- Only register if passed all checks
				if not shouldSkip then
					-- Get addon title from TOC or use addon name
					local _, title = C_AddOns.GetAddOnInfo(addonName)
					local displayName = title or addonName

					-- Append SavedVariables suffix if duplicate name detected
					if duplicateNames[displayName] then
						-- Find the global SavedVariables name
						local svName = ProfileManager.FindGlobal(db.sv)
						if svName then
							displayName = displayName .. ' (' .. svName .. ')'
						end
					end

					-- Extract namespaces if available
					local namespaces
					if db.sv and db.sv.namespaces then
						namespaces = {}
						for name in pairs(db.sv.namespaces) do
							-- Skip blacklisted namespaces (e.g., LibDualSpec debug DBs)
							if name ~= 'LibDualSpec-1.0' then
								table.insert(namespaces, name)
							end
						end
						table.sort(namespaces)
						if #namespaces == 0 then
							namespaces = nil
						end
					end

					-- Register with ProfileManager
					ProfileManager:RegisterAddon({
						id = addonId,
						name = displayName,
						db = db,
						namespaces = namespaces,
						metadata = { autoDiscovered = true, discoverySource = 'registry', originalAddonName = addonName },
					})

					-- Mark as auto-discovered for UI styling
					registeredAddons = ProfileManager:GetRegisteredAddons()
					if registeredAddons[addonId] then
						registeredAddons[addonId].autoDiscovered = true
					end

					discoveredAddons[addonName] = addonId
					count = count + 1

					if LibAT.Log then
						LibAT.Log('Auto-discovered addon via registry: ' .. displayName, 'Libs - Addon Tools.ProfileManager', 'debug')
					end
				end
			end
		end
	end

	return count
end

---Scan all registered adapters and auto-register any that are ready
---@return number count Number of newly discovered addons
function ProfileManager.DiscoverAddons()
	local count = 0

	-- First pass: run manual adapters (they have richer metadata)
	for key, adapter in pairs(discoveryAdapters) do
		-- Skip if already discovered
		if not discoveredAddons[key] then
			-- Check if the addon is loaded and ready
			local readyOk, isReady = pcall(adapter.isReady)
			if readyOk and isReady then
				-- Get the database wrapper
				local dbOk, db = pcall(adapter.getDatabase)
				if dbOk and db then
					-- Get namespaces if available
					local namespaces
					if adapter.getNamespaces then
						local nsOk, ns = pcall(adapter.getNamespaces)
						if nsOk then
							namespaces = ns
						end
					end

					-- Register with ProfileManager
					local addonId = 'discovered_' .. key
					ProfileManager:RegisterAddon({
						id = addonId,
						name = adapter.display,
						db = db,
						namespaces = namespaces,
						icon = adapter.icon,
						metadata = { autoDiscovered = true, adapterKey = key },
					})

					-- Mark the registration entry as auto-discovered for UI styling
					local registeredAddons = ProfileManager:GetRegisteredAddons()
					if registeredAddons[addonId] then
						registeredAddons[addonId].autoDiscovered = true
					end

					discoveredAddons[key] = addonId
					count = count + 1

					if LibAT.Log then
						LibAT.Log('Auto-discovered addon: ' .. adapter.display, 'Libs - Addon Tools.ProfileManager', 'debug')
					end
				end
			end
		end
	end

	-- Second pass: scan AceDB registry for addons not covered by adapters
	local registryCount = ProfileManager.DiscoverViaRegistry()
	count = count + registryCount

	return count
end

---Get list of all registered discovery adapters
---@return table<string, DiscoveryAdapter>
function ProfileManager.GetDiscoveryAdapters()
	return discoveryAdapters
end

----------------------------------------------------------------------------------------------------
-- Helper: Find Global Variable Name
----------------------------------------------------------------------------------------------------

-- Cache for FindGlobal results to avoid repeated lookups
local globalNameCache = {}

---Find the global variable name for a given value
---@param value any The value to find in global namespace
---@return string|nil globalName The name of the global variable, or nil if not found
function ProfileManager.FindGlobal(value)
	if not value then
		return nil
	end

	-- Check cache first
	if globalNameCache[value] then
		return globalNameCache[value]
	end

	-- Scan global namespace
	for k, v in pairs(_G) do
		if value == v and type(k) == 'string' then
			globalNameCache[value] = k
			return k
		end
	end

	return nil
end

----------------------------------------------------------------------------------------------------
-- Helper: Wrap raw SavedVariables into AceDB-compatible structure
-- Many addons use raw SavedVariables tables without AceDB. This wraps them
-- so our export/import pipeline can work with them.
----------------------------------------------------------------------------------------------------

---Wrap a raw SavedVariables global into an AceDB-compatible object
---@param globalName string The name of the global SavedVariables table
---@return table|nil db An AceDB-compatible wrapper, or nil if global doesn't exist
function ProfileManager.WrapSavedVariables(globalName)
	local sv = _G[globalName]
	if type(sv) ~= 'table' then
		return nil
	end

	-- Create a minimal wrapper that our export/import can use
	-- The wrapper has .sv pointing to a structure where .profiles holds the data
	local wrapper = {
		sv = {
			profiles = { ['Default'] = sv },
		},
		keys = { profile = 'Default' },
	}

	return wrapper
end

---Wrap an AceDB SavedVariables table directly (already has namespaces/profiles structure)
---@param globalName string The name of the global SavedVariables table
---@return table|nil db An AceDB-compatible wrapper, or nil if global doesn't exist
function ProfileManager.WrapAceDBSavedVariables(globalName)
	local sv = _G[globalName]
	if type(sv) ~= 'table' then
		return nil
	end

	-- AceDB SavedVariables already have the right structure (profiles, namespaces, etc.)
	local wrapper = {
		sv = sv,
		keys = sv.profileKeys and { profile = 'Default' } or { profile = 'Default' },
	}

	return wrapper
end

----------------------------------------------------------------------------------------------------
-- Built-in Discovery Adapters
-- These detect popular AceDB-based addons
----------------------------------------------------------------------------------------------------

-- Bartender4 (action bar addon - required dependency for SpartanUI)
ProfileManager.RegisterDiscoveryAdapter('bartender4', {
	display = 'Bartender4',
	isReady = function()
		return type(_G.Bartender4DB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('Bartender4DB')
	end,
	getNamespaces = function()
		local sv = _G.Bartender4DB
		if sv and sv.namespaces then
			local ns = {}
			for name in pairs(sv.namespaces) do
				if name ~= 'LibDualSpec-1.0' then
					table.insert(ns, name)
				end
			end
			table.sort(ns)
			return ns
		end
	end,
})

-- BugSack (error display addon)
ProfileManager.RegisterDiscoveryAdapter('bugsack', {
	display = 'BugSack',
	isReady = function()
		return type(_G.BugSackDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('BugSackDB')
	end,
})

-- Masque (button skinning)
ProfileManager.RegisterDiscoveryAdapter('masque', {
	display = 'Masque',
	isReady = function()
		return type(_G.MasqueDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('MasqueDB')
	end,
})

----------------------------------------------------------------------------------------------------
-- Libs-* Addon Discovery Adapters
----------------------------------------------------------------------------------------------------

-- Lib's TimePlayed
ProfileManager.RegisterDiscoveryAdapter('libs-timeplayed', {
	display = "Lib's TimePlayed",
	isReady = function()
		return type(_G.LibsTimePlayedDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('LibsTimePlayedDB')
	end,
})

-- Lib's Social
ProfileManager.RegisterDiscoveryAdapter('libs-social', {
	display = "Lib's Social",
	isReady = function()
		return type(_G.LibsSocialDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('LibsSocialDB')
	end,
})

-- Lib's FarmAssistant
ProfileManager.RegisterDiscoveryAdapter('libs-farmassistant', {
	display = "Lib's FarmAssistant",
	isReady = function()
		return type(_G.LibsFarmAssistantDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('LibsFarmAssistantDB')
	end,
})

-- Lib's DataBar
ProfileManager.RegisterDiscoveryAdapter('libs-databar', {
	display = "Lib's DataBar",
	isReady = function()
		return type(_G.LibsDataBarDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('LibsDataBarDB')
	end,
})

----------------------------------------------------------------------------------------------------
-- Popular AceDB-Based Addon Discovery Adapters
----------------------------------------------------------------------------------------------------

-- Details! Damage Meter (custom profile system, not AceDB)
-- SavedVariables: _detalhes_global (profiles stored in __profiles subtable)
ProfileManager.RegisterDiscoveryAdapter('details', {
	display = 'Details! Damage Meter',
	isReady = function()
		return type(_G._detalhes_global) == 'table' and type(_G._detalhes_global.__profiles) == 'table'
	end,
	getDatabase = function()
		local sv = _G._detalhes_global
		if type(sv) ~= 'table' or type(sv.__profiles) ~= 'table' then
			return nil
		end

		-- Details stores profiles in _detalhes_global.__profiles[profileName]
		-- Wrap into AceDB-compatible structure
		local wrapper = {
			sv = {
				profiles = sv.__profiles,
			},
			keys = { profile = 'Default' },
		}

		return wrapper
	end,
})

-- TomTom (waypoint navigation - AceDB)
-- SavedVariables: TomTomDB
ProfileManager.RegisterDiscoveryAdapter('tomtom', {
	display = 'TomTom',
	isReady = function()
		return type(_G.TomTomDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('TomTomDB')
	end,
	getNamespaces = function()
		local sv = _G.TomTomDB
		if sv and sv.namespaces then
			local ns = {}
			for name in pairs(sv.namespaces) do
				if name ~= 'LibDualSpec-1.0' then
					table.insert(ns, name)
				end
			end
			table.sort(ns)
			return #ns > 0 and ns or nil
		end
	end,
})

-- Mapster (world map enhancements - AceDB)
-- SavedVariables: MapsterDB
ProfileManager.RegisterDiscoveryAdapter('mapster', {
	display = 'Mapster',
	isReady = function()
		return type(_G.MapsterDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('MapsterDB')
	end,
	getNamespaces = function()
		local sv = _G.MapsterDB
		if sv and sv.namespaces then
			local ns = {}
			for name in pairs(sv.namespaces) do
				if name ~= 'LibDualSpec-1.0' then
					table.insert(ns, name)
				end
			end
			table.sort(ns)
			return #ns > 0 and ns or nil
		end
	end,
})

-- Angrier World Quests (world quest list - AceDB)
-- SavedVariables: AngrierWorldQuestsDB
ProfileManager.RegisterDiscoveryAdapter('angrierworldquests', {
	display = 'Angrier World Quests',
	isReady = function()
		return type(_G.AngrierWorldQuestsDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('AngrierWorldQuestsDB')
	end,
})

----------------------------------------------------------------------------------------------------
-- Additional Popular AceDB-Based Addon Discovery Adapters
----------------------------------------------------------------------------------------------------

-- Plater Nameplates (nameplate addon)
-- SavedVariables: PlaterDB
ProfileManager.RegisterDiscoveryAdapter('plater', {
	display = 'Plater Nameplates',
	isReady = function()
		return type(_G.PlaterDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('PlaterDB')
	end,
	getNamespaces = function()
		local sv = _G.PlaterDB
		if sv and sv.namespaces then
			local ns = {}
			for name in pairs(sv.namespaces) do
				if name ~= 'LibDualSpec-1.0' then
					table.insert(ns, name)
				end
			end
			table.sort(ns)
			return #ns > 0 and ns or nil
		end
	end,
})

-- TidyPlates: Threat Plates (nameplate addon - AceDB)
-- SavedVariables: TidyPlatesThreat
ProfileManager.RegisterDiscoveryAdapter('tidyplates-threatplates', {
	display = 'Threat Plates',
	isReady = function()
		return type(_G.TidyPlatesThreat) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('TidyPlatesThreat')
	end,
	getNamespaces = function()
		local sv = _G.TidyPlatesThreat
		if sv and sv.namespaces then
			local ns = {}
			for name in pairs(sv.namespaces) do
				if name ~= 'LibDualSpec-1.0' then
					table.insert(ns, name)
				end
			end
			table.sort(ns)
			return #ns > 0 and ns or nil
		end
	end,
})

-- BigWigs (boss mod - AceDB)
-- SavedVariables: BigWigs3DB
ProfileManager.RegisterDiscoveryAdapter('bigwigs', {
	display = 'BigWigs',
	isReady = function()
		return type(_G.BigWigs3DB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('BigWigs3DB')
	end,
	getNamespaces = function()
		local sv = _G.BigWigs3DB
		if sv and sv.namespaces then
			local ns = {}
			for name in pairs(sv.namespaces) do
				if name ~= 'LibDualSpec-1.0' then
					table.insert(ns, name)
				end
			end
			table.sort(ns)
			return #ns > 0 and ns or nil
		end
	end,
})

-- Bazooka (data broker display - AceDB)
-- SavedVariables: BazookaDB
ProfileManager.RegisterDiscoveryAdapter('bazooka', {
	display = 'Bazooka',
	isReady = function()
		return type(_G.BazookaDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('BazookaDB')
	end,
	getNamespaces = function()
		local sv = _G.BazookaDB
		if sv and sv.namespaces then
			local ns = {}
			for name in pairs(sv.namespaces) do
				if name ~= 'LibDualSpec-1.0' then
					table.insert(ns, name)
				end
			end
			table.sort(ns)
			return #ns > 0 and ns or nil
		end
	end,
})

-- HandyNotes (map pins framework - AceDB)
-- SavedVariables: HandyNotesDB
ProfileManager.RegisterDiscoveryAdapter('handynotes', {
	display = 'HandyNotes',
	isReady = function()
		return type(_G.HandyNotesDB) == 'table'
	end,
	getDatabase = function()
		return ProfileManager.WrapAceDBSavedVariables('HandyNotesDB')
	end,
	getNamespaces = function()
		local sv = _G.HandyNotesDB
		if sv and sv.namespaces then
			local ns = {}
			for name in pairs(sv.namespaces) do
				if name ~= 'LibDualSpec-1.0' then
					table.insert(ns, name)
				end
			end
			table.sort(ns)
			return #ns > 0 and ns or nil
		end
	end,
})
