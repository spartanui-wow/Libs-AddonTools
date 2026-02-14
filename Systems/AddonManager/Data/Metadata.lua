---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Metadata: TOC tag parsing and caching utilities

local Metadata = {}
AddonManager.Metadata = Metadata

----------------------------------------------------------------------------------------------------
-- TOC Tag Constants
----------------------------------------------------------------------------------------------------

-- Standard WoW TOC tags
Metadata.STANDARD_TAGS = {
	'Interface',
	'Title',
	'Notes',
	'Author',
	'Version',
	'Dependencies',
	'OptionalDeps',
	'LoadOnDemand',
	'SavedVariables',
	'SavedVariablesPerCharacter',
	'DefaultState',
	'Secure',
	'LoadWith',
	'LoadManagers',
	'RequiredDeps',
}

-- Custom TOC tags (from ACP and SAM patterns)
Metadata.CUSTOM_TAGS = {
	PART_OF = 'X-Part-Of', -- Multi-part addon grouping (ACP)
	CHILD_OF = 'X-Child-Of', -- Alternative grouping tag (ACP)
	CATEGORY = 'X-Category', -- Category assignment (SAM)
	MIN_INTERFACE = 'X-Min-Interface', -- Minimum interface version (ACP)
	MAX_INTERFACE = 'X-Max-Interface', -- Maximum interface version (ACP)
}

----------------------------------------------------------------------------------------------------
-- Metadata Extraction
----------------------------------------------------------------------------------------------------

---Extract all metadata for an addon
---@param addonIndex number Addon index
---@return table metadata Table of metadata key-value pairs
function Metadata.ExtractAll(addonIndex)
	local metadata = {}
	local Core = AddonManager.Core

	if not Core then
		return metadata
	end

	-- Extract standard tags
	for _, tag in ipairs(Metadata.STANDARD_TAGS) do
		local value = Core.GetAddOnMetadata(addonIndex, tag)
		if value then
			metadata[tag] = value
		end
	end

	-- Extract custom tags
	for key, tag in pairs(Metadata.CUSTOM_TAGS) do
		local value = Core.GetAddOnMetadata(addonIndex, tag)
		if value then
			metadata[key] = value
		end
	end

	return metadata
end

----------------------------------------------------------------------------------------------------
-- Dependency Parsing
----------------------------------------------------------------------------------------------------

---Parse dependency string into table
---@param depsString string Comma-separated dependency list
---@return table dependencies List of dependency names
function Metadata.ParseDependencies(depsString)
	if not depsString or depsString == '' then
		return {}
	end

	local deps = {}
	for dep in string.gmatch(depsString, '[^,]+') do
		-- Trim whitespace
		dep = dep:match('^%s*(.-)%s*$')
		if dep and dep ~= '' then
			table.insert(deps, dep)
		end
	end

	return deps
end

----------------------------------------------------------------------------------------------------
-- Interface Version Utilities
----------------------------------------------------------------------------------------------------

---Parse interface version string to number
---@param versionString string|number Interface version (e.g., "120002" or 120002)
---@return number|nil version Numeric version or nil if invalid
function Metadata.ParseInterfaceVersion(versionString)
	if type(versionString) == 'number' then
		return versionString
	end

	if type(versionString) == 'string' then
		local num = tonumber(versionString)
		return num
	end

	return nil
end

---Get current game interface version
---@return number version Current interface version
function Metadata.GetCurrentInterfaceVersion()
	return (select(4, GetBuildInfo()))
end

---Check if interface version is compatible
---@param minVersion number|string|nil Minimum version
---@param maxVersion number|string|nil Maximum version
---@return boolean compatible Whether current version is compatible
---@return string|nil warning Warning message if incompatible
function Metadata.CheckInterfaceCompatibility(minVersion, maxVersion)
	local currentVersion = Metadata.GetCurrentInterfaceVersion()

	if minVersion then
		local min = Metadata.ParseInterfaceVersion(minVersion)
		if min and currentVersion < min then
			return false, string.format('Requires interface %d or higher (current: %d)', min, currentVersion)
		end
	end

	if maxVersion then
		local max = Metadata.ParseInterfaceVersion(maxVersion)
		if max and currentVersion > max then
			return false, string.format('Only supports interface %d or lower (current: %d)', max, currentVersion)
		end
	end

	return true, nil
end

----------------------------------------------------------------------------------------------------
-- Category Utilities
----------------------------------------------------------------------------------------------------

---Get default category for an addon if no X-Category is set
---@param addonMetadata table Addon metadata
---@return string|nil category Default category or nil
function Metadata.GetDefaultCategory(addonMetadata)
	if not addonMetadata then
		return nil
	end

	-- Check if addon is LOD (Load on Demand)
	if addonMetadata.loadOnDemand then
		return 'Load on Demand'
	end

	-- Check if addon is part of a family
	local family = AddonManager.SpecialCases and AddonManager.SpecialCases.GetAddonFamily(addonMetadata.name)
	if family then
		return family
	end

	-- No default category
	return nil
end

---Normalize category name (trim, capitalize first letter)
---@param category string Category name
---@return string normalized Normalized category name
function Metadata.NormalizeCategory(category)
	if not category or category == '' then
		return 'Uncategorized'
	end

	-- Trim whitespace
	category = category:match('^%s*(.-)%s*$')

	-- Capitalize first letter
	if category:len() > 0 then
		category = category:sub(1, 1):upper() .. category:sub(2)
	end

	return category
end
