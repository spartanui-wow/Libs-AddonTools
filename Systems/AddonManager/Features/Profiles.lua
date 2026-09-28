---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Profiles: named snapshots of which addons are on. Applying a profile only touches addons the
-- profile knows about, never turns off protected addons, and is saved immediately. Profile IDs are
-- ints; ID 1 is the shared Default profile. New profiles belong to the character that made them.

---@class LibAT.AddonManager.Profiles
local Profiles = {}
AddonManager.Profiles = Profiles

local DEFAULT_ID = 1

---@param characterName? string
---@return table
local function CharData(characterName)
	characterName = characterName or UnitName('player')
	local perCharacter = AddonManager.DB.perCharacter
	perCharacter[characterName] = perCharacter[characterName] or {}
	return perCharacter[characterName]
end

---@param profileId number
---@return boolean
function Profiles.IsProtectedProfile(profileId)
	return profileId == DEFAULT_ID
end

---@param profileId number
---@return LibAT.AddonManager.ProfileData|nil
function Profiles.GetProfile(profileId)
	if not AddonManager.DB or not profileId then
		return nil
	end
	local charData = AddonManager.DB.perCharacter[UnitName('player')]
	if charData and charData.profiles and charData.profiles[profileId] then
		return charData.profiles[profileId]
	end
	return AddonManager.DB.profiles[profileId]
end

---@param profileId number
---@return string
function Profiles.GetDisplayName(profileId)
	local profile = Profiles.GetProfile(profileId)
	if profile then
		return profile.displayName or ('Profile ' .. profileId)
	end
	return 'Default'
end

---All profiles visible to this character, Default first then by name
---@return {id: number, displayName: string, scope: string}[]
function Profiles.GetProfiles()
	local result, seenIds = {}, {}
	if not AddonManager.DB then
		return result
	end

	local charData = AddonManager.DB.perCharacter[UnitName('player')]
	if charData and charData.profiles then
		for id, data in pairs(charData.profiles) do
			if type(id) == 'number' and type(data) == 'table' then
				table.insert(result, { id = id, displayName = data.displayName or ('Profile ' .. id), scope = 'character' })
				seenIds[id] = true
			end
		end
	end
	for id, data in pairs(AddonManager.DB.profiles) do
		if type(id) == 'number' and type(data) == 'table' and not seenIds[id] then
			table.insert(result, { id = id, displayName = data.displayName or ('Profile ' .. id), scope = 'global' })
		end
	end
	if not AddonManager.DB.profiles[DEFAULT_ID] then
		AddonManager.DB.profiles[DEFAULT_ID] = { displayName = 'Default', enabled = {} }
		table.insert(result, { id = DEFAULT_ID, displayName = 'Default', scope = 'global' })
	end

	table.sort(result, function(a, b)
		local aDefault, bDefault = a.id == DEFAULT_ID, b.id == DEFAULT_ID
		if aDefault ~= bDefault then
			return aDefault
		end
		return a.displayName:lower() < b.displayName:lower()
	end)
	return result
end

---@return number
function Profiles.GetActiveProfile()
	if not AddonManager.DB then
		return DEFAULT_ID
	end
	local charData = AddonManager.DB.perCharacter[UnitName('player')]
	local active = charData and charData.activeProfile or AddonManager.DB.activeProfile or DEFAULT_ID
	if not Profiles.GetProfile(active) then
		return DEFAULT_ID
	end
	return active
end

---@param profileId number
function Profiles.SetActiveProfile(profileId)
	if AddonManager.DB then
		CharData().activeProfile = profileId
	end
end

---Record the current state (for the selected character context) into a profile table
---@param profile LibAT.AddonManager.ProfileData
local function Capture(profile)
	local Core = AddonManager.Core
	Core.EnsureScanned()
	profile.enabled = profile.enabled or {}
	wipe(profile.enabled)
	for _, addon in ipairs(Core.addons) do
		profile.enabled[addon.name] = Core.IsEnabled(addon)
	end
	profile.modified = time()
end

---Create a profile from the current addon state
---@param displayName string
---@return number profileId
function Profiles.CreateProfile(displayName)
	local charData = CharData()
	charData.profiles = charData.profiles or {}
	if not charData.nextProfileId then
		local maxId = 1
		for id in pairs(charData.profiles) do
			if type(id) == 'number' and id > maxId then
				maxId = id
			end
		end
		for id in pairs(AddonManager.DB.profiles) do
			if type(id) == 'number' and id > maxId then
				maxId = id
			end
		end
		charData.nextProfileId = maxId + 1
	end
	local newId = charData.nextProfileId
	-- Never reuse an ID that a global profile already owns
	while AddonManager.DB.profiles[newId] or charData.profiles[newId] do
		newId = newId + 1
	end
	charData.nextProfileId = newId + 1

	local profile = { displayName = displayName, enabled = {}, created = time() }
	Capture(profile)
	charData.profiles[newId] = profile
	Profiles.SetActiveProfile(newId)

	if AddonManager.logger then
		AddonManager.logger.info(string.format('Created profile %s (ID %d)', displayName, newId))
	end
	AddonManager.Core.Notify('profiles')
	return newId
end

---Overwrite a profile with the current addon state
---@param profileId number
function Profiles.SaveProfile(profileId)
	local profile = Profiles.GetProfile(profileId)
	if not profile then
		return
	end
	Capture(profile)
	Profiles.SetActiveProfile(profileId)
	AddonManager.Core.Notify('profiles')
end

---@param profileId number
---@param newName string
function Profiles.RenameProfile(profileId, newName)
	if Profiles.IsProtectedProfile(profileId) then
		return
	end
	local profile = Profiles.GetProfile(profileId)
	if profile then
		profile.displayName = newName
		AddonManager.Core.Notify('profiles')
	end
end

---@param profileId number
function Profiles.DeleteProfile(profileId)
	if Profiles.IsProtectedProfile(profileId) then
		return
	end
	local charData = AddonManager.DB.perCharacter[UnitName('player')]
	if charData and charData.profiles and charData.profiles[profileId] then
		charData.profiles[profileId] = nil
	elseif AddonManager.DB.profiles[profileId] then
		AddonManager.DB.profiles[profileId] = nil
	end
	if charData and charData.activeProfile == profileId then
		charData.activeProfile = DEFAULT_ID
	end
	AddonManager.Core.Notify('profiles')
end

---@param profileId number
---@return boolean
function Profiles.IsEmpty(profileId)
	local profile = Profiles.GetProfile(profileId)
	return not profile or not profile.enabled or next(profile.enabled) == nil
end

---Addons whose current state differs from the profile
---@param profileId number
---@return LibAT.AddonManager.Addon[] turnOn
---@return LibAT.AddonManager.Addon[] turnOff
function Profiles.GetDifferences(profileId)
	local Core = AddonManager.Core
	local turnOn, turnOff = {}, {}
	local profile = Profiles.GetProfile(profileId)
	if not profile or not profile.enabled then
		return turnOn, turnOff
	end
	Core.EnsureScanned()
	for _, addon in ipairs(Core.addons) do
		local wanted = profile.enabled[addon.name]
		if wanted ~= nil and wanted ~= Core.IsEnabled(addon) then
			if wanted then
				table.insert(turnOn, addon)
			elseif not Core.IsProtected(addon) then
				table.insert(turnOff, addon)
			end
		end
	end
	return turnOn, turnOff
end

---Apply a profile to the selected character context
---@param profileId number
---@return number changed
function Profiles.ApplyProfile(profileId)
	local Core = AddonManager.Core
	local turnOn, turnOff = Profiles.GetDifferences(profileId)
	local changed = Core.SetEnabledMany(turnOn, true) + Core.SetEnabledMany(turnOff, false)
	Profiles.SetActiveProfile(profileId)
	if AddonManager.Favorites then
		AddonManager.Favorites.EnforceLock()
	end
	if AddonManager.logger then
		AddonManager.logger.info(string.format('Applied profile %s: %d change(s)', Profiles.GetDisplayName(profileId), changed))
	end
	Core.Notify('profiles')
	return changed
end
