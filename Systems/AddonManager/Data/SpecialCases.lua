---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- SpecialCases: Hardcoded handling for known addon families
-- Based on ACP's SpecialCaseName() function for multi-part addon grouping

local SpecialCases = {}
AddonManager.SpecialCases = SpecialCases

----------------------------------------------------------------------------------------------------
-- Known Addon Families (Special Case Name Transformations)
----------------------------------------------------------------------------------------------------

---Transform addon name for grouping purposes (ACP pattern)
---Handles multi-part addons that should be grouped together
---@param addonName string Original addon name
---@return string transformedName Name to use for grouping/sorting
function SpecialCases.TransformName(addonName)
	if not addonName then
		return addonName
	end

	-- DBM (Deadly Boss Mods) family
	if addonName == 'DBM-Core' then
		return 'DBM'
	elseif addonName:match('^DBM%-') then
		return addonName:gsub('DBM%-', 'DBM_')
	end

	-- CT_ family (CTMod)
	if addonName:match('^CT_') then
		return addonName:gsub('CT_', 'CT-')
	end

	-- WeakAuras family
	if addonName:match('^WeakAuras') then
		return addonName:gsub('WeakAuras(%w+)', 'WeakAuras_%1')
	end

	-- ShadowedUnitFrames special case
	if addonName == 'ShadowedUF_Options' then
		return 'ShadowedUnitFrames_Options'
	end

	-- FishingBuddy special case
	if addonName == 'FB_TrackingFrame' then
		return 'FishingBuddy_TrackingFrame'
	end

	-- Remove leading special characters (+, !, _)
	if addonName:sub(1, 1):match('[%+!_]') then
		return addonName:sub(2)
	end

	return addonName
end

----------------------------------------------------------------------------------------------------
-- Addon Family Detection
----------------------------------------------------------------------------------------------------

---Get the family name for an addon (e.g., "DBM" for "DBM-Core")
---@param addonName string Addon name
---@return string|nil familyName Family name or nil if standalone
function SpecialCases.GetAddonFamily(addonName)
	if not addonName then
		return nil
	end

	-- DBM family
	if addonName:match('^DBM') then
		return 'DBM'
	end

	-- CT family
	if addonName:match('^CT[_-]') then
		return 'CTMod'
	end

	-- WeakAuras family
	if addonName:match('^WeakAuras') then
		return 'WeakAuras'
	end

	-- ShadowedUF family
	if addonName:match('^ShadowedUF') or addonName:match('^ShadowedUnitFrames') then
		return 'ShadowedUnitFrames'
	end

	-- FishingBuddy family
	if addonName:match('^FB[_-]') or addonName:match('^FishingBuddy') then
		return 'FishingBuddy'
	end

	-- Auctioneer family
	if addonName:match('^Auc%-') or addonName == 'Auctioneer' then
		return 'Auctioneer'
	end

	-- Bartender family
	if addonName:match('^Bartender') then
		return 'Bartender'
	end

	-- BigWigs family
	if addonName:match('^BigWigs') then
		return 'BigWigs'
	end

	-- ElvUI family
	if addonName:match('^ElvUI') then
		return 'ElvUI'
	end

	-- Skada family
	if addonName:match('^Skada') then
		return 'Skada'
	end

	-- Recount family
	if addonName:match('^Recount') then
		return 'Recount'
	end

	-- Grid family
	if addonName:match('^Grid') then
		return 'Grid'
	end

	-- Masque family
	if addonName:match('^Masque') then
		return 'Masque'
	end

	-- Titan Panel family
	if addonName:match('^Titan') then
		return 'TitanPanel'
	end

	-- No known family
	return nil
end

----------------------------------------------------------------------------------------------------
-- Protected Addon Detection
----------------------------------------------------------------------------------------------------

---Check if an addon is protected (Blizzard addon that shouldn't be disabled)
---@param addonName string Addon name
---@return boolean isProtected Whether addon is protected
function SpecialCases.IsProtectedAddon(addonName)
	if not addonName then
		return false
	end

	-- Blizzard_ prefix indicates official Blizzard addon
	if addonName:match('^Blizzard_') then
		return true
	end

	return false
end

----------------------------------------------------------------------------------------------------
-- Core Addon Detection (family parent)
----------------------------------------------------------------------------------------------------

---Check if an addon is the core/parent addon of a family
---@param addonName string Addon name
---@return boolean isCore Whether addon is a family core addon
function SpecialCases.IsCoreAddon(addonName)
	if not addonName then
		return false
	end

	local coreAddons = {
		'DBM-Core',
		'WeakAuras',
		'BigWigs',
		'ElvUI',
		'Skada',
		'Recount',
		'Grid',
		'Bartender4',
		'Auctioneer',
		'Masque',
		'TitanPanel',
		'FishingBuddy',
		'ShadowedUnitFrames',
		'CTMod',
	}

	for _, coreName in ipairs(coreAddons) do
		if addonName == coreName then
			return true
		end
	end

	return false
end
