---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Favorites: star addons you always want. With the lock on, favorites stay enabled no matter
-- which profile is applied or which bulk action runs.

---@class LibAT.AddonManager.Favorites
local Favorites = {}
AddonManager.Favorites = Favorites

---@param addonName string
---@return boolean
function Favorites.IsFavorite(addonName)
	return AddonManager.DB ~= nil and AddonManager.DB.favorites[addonName] == true
end

---@return boolean
function Favorites.IsLocked()
	return AddonManager.DB ~= nil and AddonManager.DB.lockFavorites == true
end

---@param addonName string
---@return boolean
function Favorites.IsLockedFavorite(addonName)
	return Favorites.IsLocked() and Favorites.IsFavorite(addonName)
end

---@return number
function Favorites.Count()
	local count = 0
	if AddonManager.DB then
		for name in pairs(AddonManager.DB.favorites) do
			if AddonManager.Core.byName[name] then
				count = count + 1
			end
		end
	end
	return count
end

---@param addonName string
---@param isFavorite boolean
function Favorites.Set(addonName, isFavorite)
	if not AddonManager.DB then
		return
	end
	AddonManager.DB.favorites[addonName] = isFavorite and true or nil
	if isFavorite then
		Favorites.EnforceLock()
	end
	AddonManager.Core.Notify('favorites')
end

---@param addonName string
function Favorites.Toggle(addonName)
	Favorites.Set(addonName, not Favorites.IsFavorite(addonName))
end

---@param locked boolean
function Favorites.SetLocked(locked)
	if not AddonManager.DB then
		return
	end
	AddonManager.DB.lockFavorites = locked and true or false
	Favorites.EnforceLock()
	AddonManager.Core.Notify('favorites')
end

---Turn locked favorites back on for every character. Returns how many were re-enabled.
---@return number
function Favorites.EnforceLock()
	if not Favorites.IsLocked() then
		return 0
	end
	local Core = AddonManager.Core
	Core.EnsureScanned()
	local enforced = 0
	for name in pairs(AddonManager.DB.favorites) do
		local addon = Core.byName[name]
		if addon and C_AddOns.GetAddOnEnableState(addon.index, nil) < Core.Enum_All then
			C_AddOns.EnableAddOn(addon.index, nil)
			enforced = enforced + 1
		end
	end
	if enforced > 0 then
		C_AddOns.SaveAddOns()
		if AddonManager.logger then
			AddonManager.logger.info(string.format('Kept %d locked favorite(s) enabled', enforced))
		end
		Core.Notify('state')
	end
	return enforced
end
