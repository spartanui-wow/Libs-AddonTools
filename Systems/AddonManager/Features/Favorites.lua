---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Favorites: Mark addons as favorites and optionally lock them to stay enabled

local Favorites = {}
AddonManager.Favorites = Favorites

-- Tracks items removed this session so the sidecar can show them dimmed until hide
Favorites.PendingRemovals = {}

----------------------------------------------------------------------------------------------------
-- Favorites CRUD
----------------------------------------------------------------------------------------------------

---Check if an addon is favorited
---@param addonName string
---@return boolean
function Favorites.IsFavorite(addonName)
	if not AddonManager.GDB then return false end
	return AddonManager.GDB.favorites[addonName] == true
end

---Add an addon to favorites. If the lock is on, also enables the addon immediately.
---@param addonName string
function Favorites.AddFavorite(addonName)
	if not AddonManager.GDB then return end
	AddonManager.GDB.favorites[addonName] = true
	Favorites.PendingRemovals[addonName] = nil

	-- If lock is on, enable the addon immediately so it's checked in the list
	if Favorites.IsLocked() and AddonManager.Core then
		local addon = AddonManager.Core.GetAddonByName(addonName)
		if addon then
			C_AddOns.EnableAddOn(addon.index)
			addon.enabled = true
			C_AddOns.SaveAddOns()
		end
	end

	if AddonManager.logger then
		AddonManager.logger.info('Added to favorites: ' .. addonName)
	end
end

---Remove an addon from favorites (marks as pending removal for UI undo)
---@param addonName string
function Favorites.RemoveFavorite(addonName)
	if not AddonManager.GDB then return end
	AddonManager.GDB.favorites[addonName] = nil
	Favorites.PendingRemovals[addonName] = true

	if AddonManager.logger then
		AddonManager.logger.info('Removed from favorites: ' .. addonName)
	end
end

---Commit all pending removals (called on panel hide or reload)
function Favorites.CommitRemovals()
	wipe(Favorites.PendingRemovals)
end

---Get all favorited addon names sorted alphabetically
---@return string[]
function Favorites.GetFavorites()
	if not AddonManager.GDB then return {} end

	local names = {}
	for name in pairs(AddonManager.GDB.favorites) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

---Get non-favorited addon names for the "add" dropdown
---@return string[]
function Favorites.GetNonFavorites()
	if not AddonManager.Core then return {} end

	-- Ensure cache is populated (AddonList can open before PLAYER_LOGIN)
	if not next(AddonManager.Core.AddonCache) then
		AddonManager.Core.ScanAddons()
	end

	local names = {}
	for _, addon in pairs(AddonManager.Core.AddonCache) do
		if not Favorites.IsFavorite(addon.name) then
			table.insert(names, addon.name)
		end
	end
	table.sort(names)
	return names
end

----------------------------------------------------------------------------------------------------
-- Lock System
----------------------------------------------------------------------------------------------------

---Get lock state
---@return boolean
function Favorites.IsLocked()
	if not AddonManager.GDB then return false end
	return AddonManager.GDB.lockFavorites == true
end

---Set lock state
---@param locked boolean
function Favorites.SetLocked(locked)
	if not AddonManager.GDB then return end
	AddonManager.GDB.lockFavorites = locked

	if AddonManager.logger then
		AddonManager.logger.info('Favorites lock: ' .. tostring(locked))
	end
end

---Enforce favorites: re-enable all favorited addons regardless of cached state.
---Called after DisableAll or profile apply when lock is ON. Does NOT rely on
---the addon cache because it may be stale after bulk operations like DisableAllAddOns.
function Favorites.EnforceLock()
	if not Favorites.IsLocked() or not AddonManager.Core then return end

	local enforced = 0
	for name in pairs(AddonManager.GDB.favorites) do
		local addon = AddonManager.Core.GetAddonByName(name)
		if addon then
			C_AddOns.EnableAddOn(addon.index)
			addon.enabled = true
			enforced = enforced + 1
		else
			if AddonManager.logger then
				AddonManager.logger.warning('EnforceLock: favorite not found in cache: ' .. tostring(name))
			end
		end
	end

	if AddonManager.logger then
		AddonManager.logger.info(string.format('EnforceLock: re-enabled %d favorite(s)', enforced))
	end

	if enforced > 0 and AddonManager.Core.SaveAddOns then
		AddonManager.Core.SaveAddOns()
	end
end
