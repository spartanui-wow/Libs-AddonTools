---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Profiles: Profile system for saving/loading addon sets
-- Uses int-keyed profiles with displayName for rename support

local Profiles = {}
AddonManager.Profiles = Profiles

----------------------------------------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------------------------------------

---Get the per-character data table, creating it if needed
---@param characterName? string
---@return table charData
local function EnsureCharData(characterName)
	characterName = characterName or UnitName('player')
	if not AddonManager.DB.perCharacter then
		AddonManager.DB.perCharacter = {}
	end
	if not AddonManager.DB.perCharacter[characterName] then
		AddonManager.DB.perCharacter[characterName] = {}
	end
	return AddonManager.DB.perCharacter[characterName]
end

----------------------------------------------------------------------------------------------------
-- Profile Management
----------------------------------------------------------------------------------------------------

---Get all profiles as a list of {id, displayName, scope} entries
---@param characterName? string Character name (defaults to current character)
---@return {id: number, displayName: string, scope: string}[] profiles
function Profiles.GetProfiles(characterName)
	if not AddonManager.DB then
		return {}
	end

	characterName = characterName or UnitName('player')

	local result = {}
	local seenNames = {}

	-- Per-character profiles first (scope = 'character')
	local charData = AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName]
	if charData and charData.profiles then
		for id, data in pairs(charData.profiles) do
			if type(id) == 'number' and data then
				local name = data.displayName or ('Profile ' .. id)
				table.insert(result, { id = id, displayName = name, scope = 'character' })
				seenNames[name] = true
			end
		end
	end

	-- Global profiles (scope = 'global')
	if AddonManager.DB.profiles then
		for id, data in pairs(AddonManager.DB.profiles) do
			if type(id) == 'number' and data then
				local name = data.displayName or ('Profile ' .. id)
				if not seenNames[name] then
					table.insert(result, { id = id, displayName = name, scope = 'global' })
				end
			end
		end
	end

	-- Safety net: always include Default (global ID 1)
	local hasDefault = false
	for _, entry in ipairs(result) do
		if entry.id == 1 and entry.scope == 'global' then
			hasDefault = true
			break
		end
	end
	if not hasDefault then
		table.insert(result, { id = 1, displayName = 'Default', scope = 'global' })
	end

	table.sort(result, function(a, b)
		-- Default always first
		if a.id == 1 and a.scope == 'global' then
			return true
		end
		if b.id == 1 and b.scope == 'global' then
			return false
		end
		return a.displayName < b.displayName
	end)

	return result
end

---Get display name for a profile ID
---@param profileId number
---@param characterName? string
---@return string displayName
function Profiles.GetDisplayName(profileId, characterName)
	if not AddonManager.DB then
		return 'Default'
	end

	characterName = characterName or UnitName('player')

	-- Check per-character first
	local charData = AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName]
	if charData and charData.profiles and charData.profiles[profileId] then
		return charData.profiles[profileId].displayName or ('Profile ' .. profileId)
	end

	-- Check global
	if AddonManager.DB.profiles and AddonManager.DB.profiles[profileId] then
		return AddonManager.DB.profiles[profileId].displayName or ('Profile ' .. profileId)
	end

	return 'Default'
end

---Check if a profile is protected (cannot be deleted or renamed)
---@param profileId number
---@return boolean isProtected
function Profiles.IsProtectedProfile(profileId)
	return profileId == 1
end

---Get the default profile ID
---@return number
function Profiles.GetDefaultProfileId()
	return 1
end

---Get current active profile ID
---@param characterName? string Character name (defaults to current character)
---@return number profileId Active profile ID
function Profiles.GetActiveProfile(characterName)
	if not AddonManager.DB then
		return 1
	end

	characterName = characterName or UnitName('player')

	-- Check per-character setting
	local charData = AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName]
	if charData and charData.activeProfile then
		return charData.activeProfile
	end

	-- Fall back to global active profile
	return AddonManager.DB.activeProfile or 1
end

---Set active profile
---@param profileId number Profile ID
---@param characterName? string Character name (defaults to current character)
function Profiles.SetActiveProfile(profileId, characterName)
	if not AddonManager.DB then
		return
	end

	local charData = EnsureCharData(characterName)
	charData.activeProfile = profileId

	if AddonManager.logger then
		local name = Profiles.GetDisplayName(profileId, characterName)
		AddonManager.logger.info(string.format('Set active profile to: %s (ID %d)', name, profileId))
	end
end

---Create a new profile
---@param displayName string Profile display name
---@param characterName? string Character name (defaults to current character)
---@return number profileId The new profile's ID
function Profiles.CreateProfile(displayName, characterName)
	if not AddonManager.DB then
		return 1
	end

	local charData = EnsureCharData(characterName)
	if not charData.profiles then
		charData.profiles = {}
	end
	if not charData.nextProfileId then
		-- Find the max existing ID to avoid collisions
		local maxId = 0
		for id in pairs(charData.profiles) do
			if type(id) == 'number' and id > maxId then
				maxId = id
			end
		end
		charData.nextProfileId = maxId + 1
	end

	local newId = charData.nextProfileId
	charData.nextProfileId = newId + 1

	local profile = {
		displayName = displayName,
		enabled = {},
		created = time(),
		modified = time(),
	}

	-- Capture current addon states
	if AddonManager.Core then
		for _, addon in pairs(AddonManager.Core.AddonCache) do
			profile.enabled[addon.name] = addon.enabled or false
		end
	end

	charData.profiles[newId] = profile

	if AddonManager.logger then
		AddonManager.logger.info(string.format('Created profile: %s (ID %d)', displayName, newId))
	end

	return newId
end

---Delete a profile
---@param profileId number Profile ID
---@param characterName? string Character name (defaults to current character)
function Profiles.DeleteProfile(profileId, characterName)
	if not AddonManager.DB then
		return
	end

	-- Don't allow deleting the Default profile (global ID 1)
	if Profiles.IsProtectedProfile(profileId) then
		if AddonManager.logger then
			AddonManager.logger.warning('Cannot delete Default profile')
		end
		return
	end

	characterName = characterName or UnitName('player')

	-- Try per-character first
	local charData = AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName]
	if charData and charData.profiles and charData.profiles[profileId] then
		local name = charData.profiles[profileId].displayName or profileId
		charData.profiles[profileId] = nil

		if AddonManager.logger then
			AddonManager.logger.info(string.format('Deleted profile: %s (ID %d)', name, profileId))
		end

		-- If this was the active profile, switch to Default
		if Profiles.GetActiveProfile(characterName) == profileId then
			Profiles.SetActiveProfile(1, characterName)
		end
		return
	end

	-- Try global
	if AddonManager.DB.profiles and AddonManager.DB.profiles[profileId] then
		local name = AddonManager.DB.profiles[profileId].displayName or profileId
		AddonManager.DB.profiles[profileId] = nil

		if AddonManager.logger then
			AddonManager.logger.info(string.format('Deleted global profile: %s (ID %d)', name, profileId))
		end

		if Profiles.GetActiveProfile(characterName) == profileId then
			Profiles.SetActiveProfile(1, characterName)
		end
	end
end

---Rename a profile
---@param profileId number Profile ID
---@param newDisplayName string New display name
---@param characterName? string Character name (defaults to current character)
function Profiles.RenameProfile(profileId, newDisplayName, characterName)
	if not AddonManager.DB then
		return
	end

	if Profiles.IsProtectedProfile(profileId) then
		if AddonManager.logger then
			AddonManager.logger.warning('Cannot rename Default profile')
		end
		return
	end

	characterName = characterName or UnitName('player')

	-- Try per-character first
	local charData = AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName]
	if charData and charData.profiles and charData.profiles[profileId] then
		local oldName = charData.profiles[profileId].displayName
		charData.profiles[profileId].displayName = newDisplayName
		if AddonManager.logger then
			AddonManager.logger.info(string.format('Renamed profile: %s -> %s (ID %d)', oldName or '?', newDisplayName, profileId))
		end
		return
	end

	-- Try global
	if AddonManager.DB.profiles and AddonManager.DB.profiles[profileId] then
		local oldName = AddonManager.DB.profiles[profileId].displayName
		AddonManager.DB.profiles[profileId].displayName = newDisplayName
		if AddonManager.logger then
			AddonManager.logger.info(string.format('Renamed global profile: %s -> %s (ID %d)', oldName or '?', newDisplayName, profileId))
		end
	end
end

---Load a profile (apply addon states)
---@param profileId number Profile ID
---@param characterName? string Character name (defaults to current character)
function Profiles.LoadProfile(profileId, characterName)
	if not AddonManager.DB or not AddonManager.Core then
		return
	end

	characterName = characterName or UnitName('player')

	local profile = Profiles.GetProfile(profileId, characterName)
	if not profile then
		if AddonManager.logger then
			AddonManager.logger.error(string.format('Profile not found: ID %d', profileId))
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

	if AddonManager.Core.SaveAddOns then
		AddonManager.Core.SaveAddOns()
	end

	Profiles.SetActiveProfile(profileId, characterName)

	-- Enforce favorites lock after profile application
	if AddonManager.Favorites then
		AddonManager.Favorites.EnforceLock()
	end

	if AddonManager.logger then
		local name = profile.displayName or profileId
		AddonManager.logger.info(string.format('Loaded profile: %s (%d changes)', name, changesCount))
	end
end

---Save current addon states to a profile
---@param profileId number Profile ID
---@param characterName? string Character name (defaults to current character)
function Profiles.SaveProfile(profileId, characterName)
	if not AddonManager.DB or not AddonManager.Core then
		return
	end

	characterName = characterName or UnitName('player')

	local profile = Profiles.GetProfile(profileId, characterName)
	if not profile then
		-- Create with a placeholder name, then get it
		local newId = Profiles.CreateProfile('Profile ' .. profileId, characterName)
		profile = Profiles.GetProfile(newId, characterName)
		profileId = newId
	end

	if not profile then
		return
	end

	wipe(profile.enabled)
	for _, addon in pairs(AddonManager.Core.AddonCache) do
		profile.enabled[addon.name] = addon.enabled or false
	end

	profile.modified = time()

	if AddonManager.logger then
		local name = profile.displayName or profileId
		AddonManager.logger.info(string.format('Saved profile: %s (ID %d)', name, profileId))
	end
end

---Get profile data
---@param profileId number Profile ID
---@param characterName? string Character name (defaults to current character)
---@return LibAT.AddonManager.ProfileData|nil profile Profile data or nil if not found
function Profiles.GetProfile(profileId, characterName)
	if not AddonManager.DB then
		return nil
	end

	characterName = characterName or UnitName('player')

	-- Check per-character profiles first
	local charData = AddonManager.DB.perCharacter and AddonManager.DB.perCharacter[characterName]
	if charData and charData.profiles and charData.profiles[profileId] then
		return charData.profiles[profileId]
	end

	-- Fall back to global profiles
	if AddonManager.DB.profiles then
		return AddonManager.DB.profiles[profileId]
	end

	return nil
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
