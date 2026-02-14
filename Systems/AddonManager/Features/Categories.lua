---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

-- Categories: Category management system for organizing addons
-- Supports X-Category tag, custom categories, and smart defaults

local Categories = {}
AddonManager.Categories = Categories

----------------------------------------------------------------------------------------------------
-- Category Management
----------------------------------------------------------------------------------------------------

---Get all categories from installed addons and custom definitions
---@return string[] categories List of unique category names
function Categories.GetAllCategories()
	local categories = { 'All' } -- Always include "All"
	local seen = { ['All'] = true }

	-- Get categories from Core
	if AddonManager.Core then
		local addonCategories = AddonManager.Core.GetAllCategories()
		for _, cat in ipairs(addonCategories) do
			if not seen[cat] then
				table.insert(categories, cat)
				seen[cat] = true
			end
		end
	end

	-- Get custom categories from DB
	if AddonManager.DB and AddonManager.DB.categories and AddonManager.DB.categories.custom then
		for catName in pairs(AddonManager.DB.categories.custom) do
			if not seen[catName] then
				table.insert(categories, catName)
				seen[catName] = true
			end
		end
	end

	-- Add built-in special categories
	local specialCategories = {
		'Load on Demand',
		'Protected',
		'Enabled',
		'Disabled',
	}

	for _, cat in ipairs(specialCategories) do
		if not seen[cat] then
			table.insert(categories, cat)
			seen[cat] = true
		end
	end

	-- Sort alphabetically (except "All" which stays first)
	local sortable = {}
	for i = 2, #categories do
		table.insert(sortable, categories[i])
	end
	table.sort(sortable)

	-- Rebuild with "All" first
	local sorted = { 'All' }
	for _, cat in ipairs(sortable) do
		table.insert(sorted, cat)
	end

	return sorted
end

---Get addons in a specific category
---@param category string Category name
---@return LibAT.AddonManager.AddonMetadata[] addons Addons in category
function Categories.GetAddonsInCategory(category)
	if not AddonManager.Core then
		return {}
	end

	local allAddons = {}
	for i, addon in pairs(AddonManager.Core.AddonCache) do
		table.insert(allAddons, addon)
	end

	-- "All" category returns everything
	if category == 'All' then
		return allAddons
	end

	-- Special categories
	if category == 'Load on Demand' then
		return Categories.FilterByLoadOnDemand(allAddons)
	elseif category == 'Protected' then
		return Categories.FilterByProtected(allAddons)
	elseif category == 'Enabled' then
		return Categories.FilterByEnabled(allAddons, true)
	elseif category == 'Disabled' then
		return Categories.FilterByEnabled(allAddons, false)
	end

	-- X-Category tag or custom category
	local results = {}
	for _, addon in ipairs(allAddons) do
		if Categories.AddonBelongsToCategory(addon, category) then
			table.insert(results, addon)
		end
	end

	return results
end

---Check if addon belongs to a category
---@param addon LibAT.AddonManager.AddonMetadata Addon metadata
---@param category string Category name
---@return boolean belongs Whether addon belongs to category
function Categories.AddonBelongsToCategory(addon, category)
	-- Check X-Category tag
	if addon.category == category then
		return true
	end

	-- Check custom category assignments
	if AddonManager.DB and AddonManager.DB.categories and AddonManager.DB.categories.custom then
		local customCat = AddonManager.DB.categories.custom[category]
		if customCat and tContains(customCat, addon.name) then
			return true
		end
	end

	-- Check addon family (special cases)
	if AddonManager.SpecialCases then
		local family = AddonManager.SpecialCases.GetAddonFamily(addon.name)
		if family == category then
			return true
		end
	end

	return false
end

----------------------------------------------------------------------------------------------------
-- Custom Category Management
----------------------------------------------------------------------------------------------------

---Create a new custom category
---@param categoryName string Category name
function Categories.CreateCustomCategory(categoryName)
	if not AddonManager.DB then
		return
	end

	if not AddonManager.DB.categories then
		AddonManager.DB.categories = {}
	end

	if not AddonManager.DB.categories.custom then
		AddonManager.DB.categories.custom = {}
	end

	-- Normalize category name
	categoryName = AddonManager.Metadata.NormalizeCategory(categoryName)

	if not AddonManager.DB.categories.custom[categoryName] then
		AddonManager.DB.categories.custom[categoryName] = {}

		if AddonManager.logger then
			AddonManager.logger.info('Created custom category: ' .. categoryName)
		end
	end
end

---Add addon to custom category
---@param addonName string Addon name
---@param categoryName string Category name
function Categories.AddAddonToCategory(addonName, categoryName)
	if not AddonManager.DB then
		return
	end

	-- Ensure category exists
	Categories.CreateCustomCategory(categoryName)

	local customCat = AddonManager.DB.categories.custom[categoryName]
	if not tContains(customCat, addonName) then
		table.insert(customCat, addonName)

		if AddonManager.logger then
			AddonManager.logger.debug(string.format('Added %s to category %s', addonName, categoryName))
		end
	end
end

---Remove addon from custom category
---@param addonName string Addon name
---@param categoryName string Category name
function Categories.RemoveAddonFromCategory(addonName, categoryName)
	if not AddonManager.DB or not AddonManager.DB.categories or not AddonManager.DB.categories.custom then
		return
	end

	local customCat = AddonManager.DB.categories.custom[categoryName]
	if customCat then
		for i, name in ipairs(customCat) do
			if name == addonName then
				table.remove(customCat, i)

				if AddonManager.logger then
					AddonManager.logger.debug(string.format('Removed %s from category %s', addonName, categoryName))
				end
				break
			end
		end
	end
end

---Delete a custom category
---@param categoryName string Category name
function Categories.DeleteCustomCategory(categoryName)
	if not AddonManager.DB or not AddonManager.DB.categories or not AddonManager.DB.categories.custom then
		return
	end

	if AddonManager.DB.categories.custom[categoryName] then
		AddonManager.DB.categories.custom[categoryName] = nil

		if AddonManager.logger then
			AddonManager.logger.info('Deleted custom category: ' .. categoryName)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Category Filters (Special Categories)
----------------------------------------------------------------------------------------------------

---Filter addons by LOD status
---@param addons LibAT.AddonManager.AddonMetadata[] List of addons
---@return LibAT.AddonManager.AddonMetadata[] filtered LOD addons
function Categories.FilterByLoadOnDemand(addons)
	local results = {}
	for _, addon in ipairs(addons) do
		if addon.loadOnDemand then
			table.insert(results, addon)
		end
	end
	return results
end

---Filter addons by protected status
---@param addons LibAT.AddonManager.AddonMetadata[] List of addons
---@return LibAT.AddonManager.AddonMetadata[] filtered Protected addons
function Categories.FilterByProtected(addons)
	local results = {}
	for _, addon in ipairs(addons) do
		if AddonManager.SpecialCases and AddonManager.SpecialCases.IsProtectedAddon(addon.name) then
			table.insert(results, addon)
		end
	end
	return results
end

---Filter addons by enabled status
---@param addons LibAT.AddonManager.AddonMetadata[] List of addons
---@param enabled boolean True for enabled, false for disabled
---@return LibAT.AddonManager.AddonMetadata[] filtered Filtered addons
function Categories.FilterByEnabled(addons, enabled)
	local results = {}
	for _, addon in ipairs(addons) do
		if addon.enabled == enabled then
			table.insert(results, addon)
		end
	end
	return results
end

----------------------------------------------------------------------------------------------------
-- Smart Category Defaults
----------------------------------------------------------------------------------------------------

---Get smart default filter mode for a category
---Some categories should default to showing only certain addon states
---@param categoryName string Category name
---@return string filterMode Default filter mode (all, enabled, disabled)
function Categories.GetSmartDefaultFilter(categoryName)
	-- "Enabled" category always shows only enabled
	if categoryName == 'Enabled' then
		return 'enabled'
	end

	-- "Disabled" category always shows only disabled
	if categoryName == 'Disabled' then
		return 'disabled'
	end

	-- Most categories default to "all"
	return 'all'
end

---Get category count (number of addons in category)
---@param categoryName string Category name
---@return number count Number of addons in category
function Categories.GetCategoryCount(categoryName)
	local addons = Categories.GetAddonsInCategory(categoryName)
	return #addons
end
