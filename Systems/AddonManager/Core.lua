---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Core: Addon metadata handling, API compatibility layer, and state management
-- Provides unified API for Retail (C_AddOns) vs Classic (legacy globals)

local Core = {}
AddonManager.Core = Core

----------------------------------------------------------------------------------------------------
-- API Layer (C_AddOns available on all game versions)
----------------------------------------------------------------------------------------------------

Core.GetNumAddOns = C_AddOns.GetNumAddOns
Core.GetAddOnInfo = C_AddOns.GetAddOnInfo
Core.GetAddOnMetadata = C_AddOns.GetAddOnMetadata
Core.GetAddOnDependencies = C_AddOns.GetAddOnDependencies
Core.GetAddOnOptionalDependencies = C_AddOns.GetAddOnOptionalDependencies
Core.IsAddOnLoaded = C_AddOns.IsAddOnLoaded
Core.IsAddOnLoadOnDemand = C_AddOns.IsAddOnLoadOnDemand
Core.LoadAddOn = C_AddOns.LoadAddOn
Core.GetAddOnEnableState = C_AddOns.GetAddOnEnableState
Core.EnableAddOn = C_AddOns.EnableAddOn
Core.DisableAddOn = C_AddOns.DisableAddOn
Core.EnableAllAddOns = C_AddOns.EnableAllAddOns
Core.DisableAllAddOns = C_AddOns.DisableAllAddOns
Core.SaveAddOns = C_AddOns.SaveAddOns
Core.ResetAddOns = C_AddOns.ResetAddOns

----------------------------------------------------------------------------------------------------
-- Addon Metadata Cache
----------------------------------------------------------------------------------------------------

-- Cache structure: { [index] = { name, title, notes, author, version, ... } }
Core.AddonCache = {}

-- Special addon families (from ACP patterns)
Core.SpecialFamilies = {
	-- These will be loaded from Data/SpecialCases.lua
}

----------------------------------------------------------------------------------------------------
-- Metadata Scanning
----------------------------------------------------------------------------------------------------

---Scan all installed addons and populate metadata cache
function Core.ScanAddons()
	local numAddons = Core.GetNumAddOns()

	for i = 1, numAddons do
		local name, title, notes, loadable, reason, security, newVersion = Core.GetAddOnInfo(i)

		if name then
			local metadata = {
				index = i,
				name = name,
				title = title or name,
				notes = notes or '',
				loadable = loadable,
				reason = reason,
				security = security,
				newVersion = newVersion,

				-- Additional metadata from TOC
				author = Core.GetAddOnMetadata(i, 'Author') or '',
				version = Core.GetAddOnMetadata(i, 'Version') or '',

				-- Custom TOC fields (ACP pattern)
				partOf = Core.GetAddOnMetadata(i, 'X-Part-Of'),
				minInterface = tonumber(Core.GetAddOnMetadata(i, 'X-Min-Interface')),
				maxInterface = tonumber(Core.GetAddOnMetadata(i, 'X-Max-Interface')),

				-- Category (SAM pattern)
				category = Core.GetAddOnMetadata(i, 'X-Category'),

				-- Dependency tracking
				dependencies = {},
				optionalDeps = {},

				-- State
				loaded = Core.IsAddOnLoaded(i),
				loadOnDemand = Core.IsAddOnLoadOnDemand(i),
				enabled = nil, -- Will be set based on enable state
			}

			-- Get dependencies
			local deps = { Core.GetAddOnDependencies(i) }
			if deps[1] then
				for j = 1, #deps do
					if deps[j] and deps[j] ~= '' then
						table.insert(metadata.dependencies, deps[j])
					end
				end
			end

			-- Get optional dependencies
			local optDeps = { Core.GetAddOnOptionalDependencies(i) }
			if optDeps[1] then
				for j = 1, #optDeps do
					if optDeps[j] and optDeps[j] ~= '' then
						table.insert(metadata.optionalDeps, optDeps[j])
					end
				end
			end

			-- Get enable state
			local enableState = Core.GetAddOnEnableState(i)
			metadata.enabled = (enableState > 0) -- 0=disabled, >0=enabled (1=some chars, 2=all chars)

			-- Debug: Log first 5 addon enable states
			if AddonManager.logger and i <= 5 then
				AddonManager.logger.info(string.format('ScanAddons: %s, enableState=%s, enabled=%s', name, tostring(enableState), tostring(metadata.enabled)))
			end

			-- Store in cache
			Core.AddonCache[i] = metadata
		end
	end

	if AddonManager.logger then
		AddonManager.logger.info(string.format('Scanned %d addons', numAddons))
	end
end

----------------------------------------------------------------------------------------------------
-- Compatibility Checking (ACP pattern)
----------------------------------------------------------------------------------------------------

---Check if an addon is compatible with the current interface version
---@param addonIndex number Addon index
---@return boolean isCompatible Whether addon is compatible
---@return string|nil warning Warning message if incompatible
function Core.CheckCompatibility(addonIndex)
	local addon = Core.AddonCache[addonIndex]
	if not addon then
		return true, nil
	end

	local currentInterface = select(4, GetBuildInfo())
	local minInterface = addon.minInterface
	local maxInterface = addon.maxInterface

	if minInterface and currentInterface < minInterface then
		return false, string.format('Requires interface %d or higher (current: %d)', minInterface, currentInterface)
	end

	if maxInterface and currentInterface > maxInterface then
		return false, string.format('Only supports interface %d or lower (current: %d)', maxInterface, currentInterface)
	end

	return true, nil
end

----------------------------------------------------------------------------------------------------
-- Addon Enable/Disable
----------------------------------------------------------------------------------------------------

---Enable an addon for the specified character
---@param addonIndex number Addon index
---@param character? string Character name (defaults to current character)
function Core.EnableAddon(addonIndex, character)
	Core.EnableAddOn(addonIndex, character)

	-- Update cache
	if Core.AddonCache[addonIndex] then
		Core.AddonCache[addonIndex].enabled = true
	end

	if AddonManager.logger then
		local name = Core.AddonCache[addonIndex] and Core.AddonCache[addonIndex].name or tostring(addonIndex)
		AddonManager.logger.debug(string.format('Enabled addon: %s', name))
	end
end

---Disable an addon for the specified character
---@param addonIndex number Addon index
---@param character? string Character name (defaults to current character)
function Core.DisableAddon(addonIndex, character)
	Core.DisableAddOn(addonIndex, character)

	-- Update cache
	if Core.AddonCache[addonIndex] then
		Core.AddonCache[addonIndex].enabled = false
	end

	if AddonManager.logger then
		local name = Core.AddonCache[addonIndex] and Core.AddonCache[addonIndex].name or tostring(addonIndex)
		AddonManager.logger.debug(string.format('Disabled addon: %s', name))
	end
end

----------------------------------------------------------------------------------------------------
-- Helper Functions
----------------------------------------------------------------------------------------------------

---Get addon by name
---@param addonName string Addon name
---@return table|nil metadata Addon metadata or nil if not found
function Core.GetAddonByName(addonName)
	for i, addon in pairs(Core.AddonCache) do
		if addon.name == addonName then
			return addon
		end
	end
	return nil
end

---Get all addons in a category
---@param category string Category name
---@return table addons List of addon metadata matching category
function Core.GetAddonsByCategory(category)
	local results = {}

	for i, addon in pairs(Core.AddonCache) do
		if addon.category == category then
			table.insert(results, addon)
		end
	end

	return results
end

---Get all unique categories from installed addons
---@return table categories List of category names
function Core.GetAllCategories()
	local categories = {}
	local seen = {}

	for i, addon in pairs(Core.AddonCache) do
		if addon.category and not seen[addon.category] then
			table.insert(categories, addon.category)
			seen[addon.category] = true
		end
	end

	table.sort(categories)
	return categories
end

----------------------------------------------------------------------------------------------------
-- Dependency Helpers
----------------------------------------------------------------------------------------------------

---Check if an addon is a child addon (has X-Part-Of, RequiredDeps, or is part of known family)
---@param addon table Addon metadata
---@return boolean isChild Whether addon is a child
---@return string|nil parentName Name of parent addon if child
function Core.IsChildAddon(addon)
	if not addon then
		return false, nil
	end

	-- Check X-Part-Of first (explicit parent declaration)
	if addon.partOf then
		return true, addon.partOf
	end

	-- Special case for known addon families (DBM, etc.) due to ordering issues
	if AddonManager.SpecialCases then
		local family = AddonManager.SpecialCases.GetAddonFamily(addon.name)
		if family then
			-- Check if this is a child addon (not the core addon itself)
			if not AddonManager.SpecialCases.IsCoreAddon(addon.name) then
				-- For DBM and other known families, find the core addon
				for _, otherAddon in pairs(Core.AddonCache) do
					if AddonManager.SpecialCases.IsCoreAddon(otherAddon.name) then
						local otherFamily = AddonManager.SpecialCases.GetAddonFamily(otherAddon.name)
						if otherFamily == family then
							return true, otherAddon.name
						end
					end
				end
			end
		end
	end

	-- Dynamic detection: Check if this addon has RequiredDeps (dependencies)
	-- If it does, the first dependency is considered the parent
	if addon.dependencies and #addon.dependencies > 0 then
		-- Return first dependency as parent
		return true, addon.dependencies[1]
	end

	return false, nil
end

---Get all addons that are part of this addon family (children via X-Part-Of or known families)
---@param addonName string Addon name
---@return table dependents List of addon names that are part of this addon family
function Core.GetDependents(addonName)
	local dependents = {}

	for _, addon in pairs(Core.AddonCache) do
		-- Check X-Part-Of first
		if addon.partOf == addonName then
			table.insert(dependents, addon.name)
		end

		-- Check if this addon is a child of addonName via known families
		local isChild, parentName = Core.IsChildAddon(addon)
		if isChild and parentName == addonName then
			-- Only add if not already added via partOf
			local alreadyAdded = false
			for _, depName in ipairs(dependents) do
				if depName == addon.name then
					alreadyAdded = true
					break
				end
			end
			if not alreadyAdded then
				table.insert(dependents, addon.name)
			end
		end
	end

	return dependents
end

---Get all addons that this addon depends on (recursively)
---@param addonName string Addon name
---@return table dependencies List of addon names this addon depends on (recursive)
function Core.GetAllDependencies(addonName)
	local allDeps = {}
	local seen = {}

	local function addDeps(name)
		if seen[name] then
			return
		end
		seen[name] = true

		local addon = Core.GetAddonByName(name)
		if not addon then
			return
		end

		for _, dep in ipairs(addon.dependencies) do
			table.insert(allDeps, dep)
			addDeps(dep) -- Recursive
		end
	end

	addDeps(addonName)
	return allDeps
end
