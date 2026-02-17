---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Profiles: Profile system for saving/loading addon sets
-- Supports named profiles, per-character profiles, and profile inheritance

local Profiles = {}
AddonManager.Profiles = Profiles

----------------------------------------------------------------------------------------------------
-- Profile Management
----------------------------------------------------------------------------------------------------

---Get list of all profile names
---@param characterName? string Character name (defaults to current character)
---@return string[] profiles List of profile names
function Profiles.GetProfileNames(characterName)
	if not AddonManager.DB then
		return {}
	end

	characterName = characterName or UnitName('player')

	local seen = {}
	local names = {}

	-- Collect per-character profiles first
	if AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName] and AddonManager.DB.perCharacter[characterName].profiles then
		for name in pairs(AddonManager.DB.perCharacter[characterName].profiles) do
			if not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end

	-- Also collect global profiles (ensures Default is always included)
	if AddonManager.DB.profiles then
		for name in pairs(AddonManager.DB.profiles) do
			if not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end

	-- Safety net: always include Default
	if not seen['Default'] then
		table.insert(names, 'Default')
	end

	table.sort(names)
	return names
end

---Get current active profile name
---@param characterName? string Character name (defaults to current character)
---@return string profileName Active profile name
function Profiles.GetActiveProfile(characterName)
	if not AddonManager.DB then
		return 'Default'
	end

	characterName = characterName or UnitName('player')

	-- Check per-character setting
	if AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName] and AddonManager.DB.perCharacter[characterName].activeProfile then
		return AddonManager.DB.perCharacter[characterName].activeProfile
	end

	-- Fall back to global active profile
	return AddonManager.DB.activeProfile or 'Default'
end

---Set active profile
---@param profileName string Profile name
---@param characterName? string Character name (defaults to current character)
function Profiles.SetActiveProfile(profileName, characterName)
	if not AddonManager.DB then
		return
	end

	characterName = characterName or UnitName('player')

	-- Ensure per-character data exists
	if not AddonManager.DB.perCharacter then
		AddonManager.DB.perCharacter = {}
	end
	if not AddonManager.DB.perCharacter[characterName] then
		AddonManager.DB.perCharacter[characterName] = {}
	end

	-- Set active profile
	AddonManager.DB.perCharacter[characterName].activeProfile = profileName

	if AddonManager.logger then
		AddonManager.logger.info(string.format('Set active profile to: %s', profileName))
	end
end

---Create a new profile
---@param profileName string Profile name
---@param characterName? string Character name (defaults to current character)
function Profiles.CreateProfile(profileName, characterName)
	if not AddonManager.DB then
		return
	end

	characterName = characterName or UnitName('player')

	-- Ensure per-character data exists
	if not AddonManager.DB.perCharacter then
		AddonManager.DB.perCharacter = {}
	end
	if not AddonManager.DB.perCharacter[characterName] then
		AddonManager.DB.perCharacter[characterName] = {}
	end
	if not AddonManager.DB.perCharacter[characterName].profiles then
		AddonManager.DB.perCharacter[characterName].profiles = {}
	end

	-- Create profile with current addon states
	local profile = {
		enabled = {},
		created = time(),
		modified = time(),
	}

	-- Capture current addon states
	if AddonManager.Core then
		for i, addon in pairs(AddonManager.Core.AddonCache) do
			profile.enabled[addon.name] = addon.enabled or false
		end
	end

	AddonManager.DB.perCharacter[characterName].profiles[profileName] = profile

	if AddonManager.logger then
		AddonManager.logger.info(string.format('Created profile: %s', profileName))
	end
end

---Delete a profile
---@param profileName string Profile name
---@param characterName? string Character name (defaults to current character)
function Profiles.DeleteProfile(profileName, characterName)
	if not AddonManager.DB then
		return
	end

	-- Don't allow deleting "Default" profile
	if profileName == 'Default' then
		if AddonManager.logger then
			AddonManager.logger.warning('Cannot delete Default profile')
		end
		return
	end

	characterName = characterName or UnitName('player')

	if AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName] and AddonManager.DB.perCharacter[characterName].profiles then
		AddonManager.DB.perCharacter[characterName].profiles[profileName] = nil

		if AddonManager.logger then
			AddonManager.logger.info(string.format('Deleted profile: %s', profileName))
		end

		-- If this was the active profile, switch to Default
		if Profiles.GetActiveProfile(characterName) == profileName then
			Profiles.SetActiveProfile('Default', characterName)
		end
	end
end

---Load a profile (apply addon states)
---@param profileName string Profile name
---@param characterName? string Character name (defaults to current character)
function Profiles.LoadProfile(profileName, characterName)
	if not AddonManager.DB or not AddonManager.Core then
		return
	end

	characterName = characterName or UnitName('player')

	-- Get profile data
	local profile = Profiles.GetProfile(profileName, characterName)
	if not profile then
		if AddonManager.logger then
			AddonManager.logger.error(string.format('Profile not found: %s', profileName))
		end
		return
	end

	-- Apply addon states
	local changesCount = 0
	for addonName, enabled in pairs(profile.enabled) do
		local addon = AddonManager.Core.GetAddonByName(addonName)
		if addon then
			if enabled and not addon.enabled then
				AddonManager.Core.EnableAddon(addon.index)
				changesCount = changesCount + 1
			elseif not enabled and addon.enabled then
				AddonManager.Core.DisableAddon(addon.index)
				changesCount = changesCount + 1
			end
		end
	end

	-- Save changes
	if AddonManager.Core.SaveAddOns then
		AddonManager.Core.SaveAddOns()
	end

	-- Set as active profile
	Profiles.SetActiveProfile(profileName, characterName)

	if AddonManager.logger then
		AddonManager.logger.info(string.format('Loaded profile: %s (%d changes)', profileName, changesCount))
	end
end

---Save current addon states to a profile
---@param profileName string Profile name
---@param characterName? string Character name (defaults to current character)
function Profiles.SaveProfile(profileName, characterName)
	if not AddonManager.DB or not AddonManager.Core then
		return
	end

	characterName = characterName or UnitName('player')

	-- Get or create profile
	local profile = Profiles.GetProfile(profileName, characterName)
	if not profile then
		Profiles.CreateProfile(profileName, characterName)
		profile = Profiles.GetProfile(profileName, characterName)
	end

	if not profile then
		return
	end

	-- Update addon states
	wipe(profile.enabled)
	for i, addon in pairs(AddonManager.Core.AddonCache) do
		profile.enabled[addon.name] = addon.enabled or false
	end

	profile.modified = time()

	if AddonManager.logger then
		AddonManager.logger.info(string.format('Saved profile: %s', profileName))
	end
end

---Get profile data
---@param profileName string Profile name
---@param characterName? string Character name (defaults to current character)
---@return LibAT.AddonManager.ProfileData|nil profile Profile data or nil if not found
function Profiles.GetProfile(profileName, characterName)
	if not AddonManager.DB then
		return nil
	end

	characterName = characterName or UnitName('player')

	-- Check per-character profiles first
	if
		AddonManager.DB.perCharacter
		and AddonManager.DB.perCharacter[characterName]
		and AddonManager.DB.perCharacter[characterName].profiles
		and AddonManager.DB.perCharacter[characterName].profiles[profileName]
	then
		return AddonManager.DB.perCharacter[characterName].profiles[profileName]
	end

	-- Fall back to global profiles
	return AddonManager.DB.profiles[profileName]
end

----------------------------------------------------------------------------------------------------
-- Bulk Operations
----------------------------------------------------------------------------------------------------

---Enable all addons in a list
---@param addonList LibAT.AddonManager.AddonMetadata[] List of addons
---@return number count Number of addons enabled
function Profiles.EnableAddons(addonList)
	if not AddonManager.Core then
		return 0
	end

	local count = 0
	for _, addon in ipairs(addonList) do
		if not addon.enabled then
			AddonManager.Core.EnableAddon(addon.index)
			count = count + 1
		end
	end

	if count > 0 and AddonManager.Core.SaveAddOns then
		AddonManager.Core.SaveAddOns()
	end

	return count
end

---Disable all addons in a list
---@param addonList LibAT.AddonManager.AddonMetadata[] List of addons
---@param respectProtected? boolean Skip protected addons (default: true)
---@return number count Number of addons disabled
function Profiles.DisableAddons(addonList, respectProtected)
	if not AddonManager.Core then
		return 0
	end

	if respectProtected == nil then
		respectProtected = true
	end

	local count = 0
	for _, addon in ipairs(addonList) do
		-- Skip protected addons if requested
		if respectProtected and AddonManager.SpecialCases and AddonManager.SpecialCases.IsProtectedAddon(addon.name) then
			-- Skip
		else
			if addon.enabled then
				AddonManager.Core.DisableAddon(addon.index)
				count = count + 1
			end
		end
	end

	if count > 0 and AddonManager.Core.SaveAddOns then
		AddonManager.Core.SaveAddOns()
	end

	return count
end

---Toggle all addons in a list
---@param addonList LibAT.AddonManager.AddonMetadata[] List of addons
---@return number enabledCount Number enabled
---@return number disabledCount Number disabled
function Profiles.ToggleAddons(addonList)
	if not AddonManager.Core then
		return 0, 0
	end

	local enabledCount = 0
	local disabledCount = 0

	for _, addon in ipairs(addonList) do
		if addon.enabled then
			AddonManager.Core.DisableAddon(addon.index)
			disabledCount = disabledCount + 1
		else
			AddonManager.Core.EnableAddon(addon.index)
			enabledCount = enabledCount + 1
		end
	end

	if (enabledCount + disabledCount) > 0 and AddonManager.Core.SaveAddOns then
		AddonManager.Core.SaveAddOns()
	end

	return enabledCount, disabledCount
end

----------------------------------------------------------------------------------------------------
-- Profile Inheritance (Future Enhancement)
----------------------------------------------------------------------------------------------------

-- Note: Profile inheritance system can be added here in Phase 8 if needed
-- This would allow profiles to inherit settings from parent profiles
