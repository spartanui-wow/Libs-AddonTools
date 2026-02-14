---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Compatibility: Version checking and compatibility warnings
-- Checks X-Min/Max-Interface tags, detects outdated addons

local Compatibility = {}
AddonManager.Compatibility = Compatibility

----------------------------------------------------------------------------------------------------
-- Interface Version Checking
----------------------------------------------------------------------------------------------------

---Check if addon is compatible with current game version
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@return boolean compatible Whether addon is compatible
---@return string|nil warning Warning message if incompatible
---@return string|nil level Warning level ('info', 'warning', 'error')
function Compatibility.CheckAddonCompatibility(addon)
	if not addon then
		return true, nil, nil
	end

	-- Use Core's compatibility check if available
	if AddonManager.Core then
		local compatible, warning = AddonManager.Core.CheckCompatibility(addon.index)
		if not compatible then
			return false, warning, 'error'
		end
	end

	-- Check if addon has compatibility metadata
	if AddonManager.Metadata then
		local compatible, warning = AddonManager.Metadata.CheckInterfaceCompatibility(addon.minInterface, addon.maxInterface)
		if not compatible then
			return false, warning, 'error'
		end
	end

	-- Check if addon has new version available (info, not error)
	if addon.newVersion then
		return true, 'A new version of this addon is available', 'info'
	end

	return true, nil, nil
end

---Get all incompatible addons
---@return LibAT.AddonManager.AddonMetadata[] incompatible List of incompatible addons
function Compatibility.GetIncompatibleAddons()
	if not AddonManager.Core then
		return {}
	end

	local incompatible = {}

	for i, addon in pairs(AddonManager.Core.AddonCache) do
		local compatible = Compatibility.CheckAddonCompatibility(addon)
		if not compatible then
			table.insert(incompatible, addon)
		end
	end

	return incompatible
end

----------------------------------------------------------------------------------------------------
-- Addon Age Detection
----------------------------------------------------------------------------------------------------

---Check if addon is outdated (interface version too old)
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@param threshold? number Major versions behind before considered outdated (default: 2)
---@return boolean outdated Whether addon is outdated
---@return string|nil message Informational message
function Compatibility.IsAddonOutdated(addon, threshold)
	if not addon then
		return false, nil
	end

	threshold = threshold or 2

	local currentInterface = (select(4, GetBuildInfo()))

	-- Get addon's interface version (from TOC)
	local addonInterfaceStr = AddonManager.Core.GetAddOnMetadata(addon.index, 'Interface')
	local addonInterface = tonumber(addonInterfaceStr)
	if not addonInterface then
		return false, nil
	end

	-- Calculate major version difference
	-- Interface format: XXYYZZ (XX = expansion, YY = major patch, ZZ = minor patch)
	local currentMajor = math.floor(currentInterface / 10000)
	local addonMajor = math.floor(addonInterface / 10000)

	local versionsBehind = currentMajor - addonMajor

	if versionsBehind >= threshold then
		return true, string.format('Addon is %d major version(s) behind current game version', versionsBehind)
	end

	return false, nil
end

----------------------------------------------------------------------------------------------------
-- Security Warnings
----------------------------------------------------------------------------------------------------

---Check if addon has security concerns
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@return boolean hasIssue Whether addon has security issues
---@return string|nil warning Warning message
function Compatibility.CheckAddonSecurity(addon)
	if not addon then
		return false, nil
	end

	-- Check security field from GetAddOnInfo
	-- "SECURE" = addon is secure
	-- "INSECURE" = addon is not secure
	-- "BANNED" = addon is banned
	if addon.security == 'BANNED' then
		return true, 'This addon is banned and cannot be loaded'
	end

	if addon.security == 'INSECURE' then
		return true, 'This addon is marked as insecure'
	end

	return false, nil
end

----------------------------------------------------------------------------------------------------
-- Load State Checking
----------------------------------------------------------------------------------------------------

---Check if addon failed to load and why
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@return boolean failed Whether addon failed to load
---@return string|nil reason Reason for failure
function Compatibility.CheckLoadFailure(addon)
	if not addon then
		return false, nil
	end

	if addon.loaded then
		return false, nil
	end

	if not addon.loadable then
		-- Translate reason code to message
		local reasons = {
			['DISABLED'] = 'Addon is disabled',
			['INCOMPATIBLE'] = 'Addon is incompatible with current game version',
			['MISSING'] = 'Addon files are missing',
			['CORRUPT'] = 'Addon files are corrupted',
			['INTERFACE_VERSION'] = 'Interface version mismatch',
			['DEPENDENCIES'] = 'Missing dependencies',
			['BANNED'] = 'Addon is banned',
		}

		local reason = reasons[addon.reason] or addon.reason or 'Unknown error'
		return true, reason
	end

	-- Addon is loadable but not loaded - might be LOD
	if addon.loadOnDemand then
		return false, 'Load on demand - not loaded yet'
	end

	return false, nil
end

----------------------------------------------------------------------------------------------------
-- Compatibility Report
----------------------------------------------------------------------------------------------------

---Generate compatibility report for an addon
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@return table report Compatibility report with sections
function Compatibility.GenerateCompatibilityReport(addon)
	if not addon then
		return {}
	end

	local report = {
		compatible = true,
		warnings = {},
		errors = {},
		info = {},
	}

	-- Check version compatibility
	local compatible, warning, level = Compatibility.CheckAddonCompatibility(addon)
	if not compatible then
		report.compatible = false
		table.insert(report.errors, warning)
	elseif warning then
		if level == 'warning' then
			table.insert(report.warnings, warning)
		elseif level == 'info' then
			table.insert(report.info, warning)
		end
	end

	-- Check if outdated
	local outdated, msg = Compatibility.IsAddonOutdated(addon)
	if outdated then
		table.insert(report.warnings, msg)
	end

	-- Check security
	local hasSecurityIssue, secWarning = Compatibility.CheckAddonSecurity(addon)
	if hasSecurityIssue then
		report.compatible = false
		table.insert(report.errors, secWarning)
	end

	-- Check load failure
	local failed, failReason = Compatibility.CheckLoadFailure(addon)
	if failed then
		table.insert(report.warnings, failReason)
	end

	return report
end

---Format compatibility report as text
---@param report table Compatibility report
---@return string formatted Formatted report text
function Compatibility.FormatCompatibilityReport(report)
	local lines = {}

	if #report.errors > 0 then
		table.insert(lines, '|cffff0000Errors:|r')
		for _, err in ipairs(report.errors) do
			table.insert(lines, '  ' .. err)
		end
	end

	if #report.warnings > 0 then
		table.insert(lines, '|cffffff00Warnings:|r')
		for _, warn in ipairs(report.warnings) do
			table.insert(lines, '  ' .. warn)
		end
	end

	if #report.info > 0 then
		table.insert(lines, '|cff00ff00Info:|r')
		for _, info in ipairs(report.info) do
			table.insert(lines, '  ' .. info)
		end
	end

	if #lines == 0 then
		return '|cff00ff00No compatibility issues found|r'
	end

	return table.concat(lines, '\n')
end
