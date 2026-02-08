---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Setup Wizard Core - Registration API & Completion Tracking
----------------------------------------------------------------------------------------------------

---@class SetupWizardPage
---@field id string Unique page identifier
---@field name string Display name for nav tree
---@field builder function(contentFrame: Frame) Populates the right panel content
---@field isComplete? function(): boolean Dynamic completion check (returns true if page setup is done)

---@class SetupWizardAddonConfig
---@field name string Display name for the addon
---@field icon? string Optional icon texture path
---@field pages SetupWizardPage[] Array of wizard pages
---@field onComplete? function Optional callback when all pages are completed

---@class SetupWizardAddonEntry
---@field id string Addon identifier
---@field config SetupWizardAddonConfig Registration config
---@field order number Registration order for sorting

---@class LibAT.SetupWizard
LibAT.SetupWizard = {}
local SetupWizard = LibAT.SetupWizard

-- Internal storage
SetupWizard.registeredAddons = {} ---@type table<string, SetupWizardAddonEntry>
SetupWizard.registrationOrder = 0

----------------------------------------------------------------------------------------------------
-- Registration API
----------------------------------------------------------------------------------------------------

---Register an addon with the Setup Wizard
---@param addonId string Unique identifier for the addon (e.g., 'libs-timeplayed')
---@param config SetupWizardAddonConfig Addon configuration with pages
function SetupWizard:RegisterAddon(addonId, config)
	if not addonId or not config then
		LibAT:Print('SetupWizard: RegisterAddon requires addonId and config')
		return
	end

	if not config.name then
		LibAT:Print('SetupWizard: config.name is required for addon ' .. tostring(addonId))
		return
	end

	if not config.pages or #config.pages == 0 then
		LibAT:Print('SetupWizard: config.pages is required and must not be empty for addon ' .. tostring(addonId))
		return
	end

	-- Validate each page
	for i, page in ipairs(config.pages) do
		if not page.id then
			LibAT:Print('SetupWizard: page ' .. i .. ' missing id for addon ' .. tostring(addonId))
			return
		end
		if not page.name then
			LibAT:Print('SetupWizard: page ' .. i .. ' missing name for addon ' .. tostring(addonId))
			return
		end
		if not page.builder then
			LibAT:Print('SetupWizard: page ' .. i .. ' missing builder for addon ' .. tostring(addonId))
			return
		end
	end

	self.registrationOrder = self.registrationOrder + 1

	self.registeredAddons[addonId] = {
		id = addonId,
		config = config,
		order = self.registrationOrder,
	}

	LibAT:Debug('SetupWizard: Registered addon ' .. config.name .. ' with ' .. #config.pages .. ' pages')

	-- If the wizard window is already open, refresh the nav tree
	if self.RefreshNavTree then
		self:RefreshNavTree()
	end
end

---Unregister an addon from the Setup Wizard
---@param addonId string Addon identifier to remove
function SetupWizard:UnregisterAddon(addonId)
	if self.registeredAddons[addonId] then
		self.registeredAddons[addonId] = nil
		LibAT:Debug('SetupWizard: Unregistered addon ' .. tostring(addonId))

		-- Refresh nav tree if window is open
		if self.RefreshNavTree then
			self:RefreshNavTree()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Completion Tracking
----------------------------------------------------------------------------------------------------

---Check if a specific page is complete
---@param addonId string Addon identifier
---@param pageId string Page identifier
---@return boolean isComplete
function SetupWizard:IsPageComplete(addonId, pageId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return false
	end

	for _, page in ipairs(entry.config.pages) do
		if page.id == pageId then
			if page.isComplete then
				return page.isComplete()
			end
			-- No isComplete function means always incomplete (user must visit)
			return false
		end
	end

	return false
end

---Check if all pages for an addon are complete
---@param addonId string Addon identifier
---@return boolean allComplete
function SetupWizard:IsAddonComplete(addonId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return false
	end

	for _, page in ipairs(entry.config.pages) do
		if page.isComplete and not page.isComplete() then
			return false
		end
	end

	return true
end

---Check if there are any addons with uncompleted setup pages
---@return boolean hasUncompleted
function SetupWizard:HasUncompletedAddons()
	for addonId, _ in pairs(self.registeredAddons) do
		if not self:IsAddonComplete(addonId) then
			return true
		end
	end
	return false
end

---Get a sorted list of registered addon IDs (by registration order)
---@return string[] addonIds
function SetupWizard:GetSortedAddonIds()
	local ids = {}
	for addonId, _ in pairs(self.registeredAddons) do
		table.insert(ids, addonId)
	end

	table.sort(ids, function(a, b)
		return self.registeredAddons[a].order < self.registeredAddons[b].order
	end)

	return ids
end

---Get the count of registered addons
---@return number count
function SetupWizard:GetAddonCount()
	local count = 0
	for _ in pairs(self.registeredAddons) do
		count = count + 1
	end
	return count
end

---Get a specific page from an addon
---@param addonId string Addon identifier
---@param pageId string Page identifier
---@return SetupWizardPage|nil page
function SetupWizard:GetPage(addonId, pageId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return nil
	end

	for _, page in ipairs(entry.config.pages) do
		if page.id == pageId then
			return page
		end
	end

	return nil
end

---Get the next page after the current one (across addons if needed)
---@param addonId string Current addon identifier
---@param pageId string Current page identifier
---@return string|nil nextAddonId Next addon ID (nil if at end)
---@return string|nil nextPageId Next page ID (nil if at end)
function SetupWizard:GetNextPage(addonId, pageId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return nil, nil
	end

	-- Find current page index
	local currentIndex = nil
	for i, page in ipairs(entry.config.pages) do
		if page.id == pageId then
			currentIndex = i
			break
		end
	end

	if not currentIndex then
		return nil, nil
	end

	-- Try next page in same addon
	if currentIndex < #entry.config.pages then
		return addonId, entry.config.pages[currentIndex + 1].id
	end

	-- Try first page of next addon
	local sortedIds = self:GetSortedAddonIds()
	local foundCurrent = false
	for _, id in ipairs(sortedIds) do
		if foundCurrent then
			local nextEntry = self.registeredAddons[id]
			if nextEntry and #nextEntry.config.pages > 0 then
				return id, nextEntry.config.pages[1].id
			end
		end
		if id == addonId then
			foundCurrent = true
		end
	end

	return nil, nil
end

---Get the previous page before the current one (across addons if needed)
---@param addonId string Current addon identifier
---@param pageId string Current page identifier
---@return string|nil prevAddonId Previous addon ID (nil if at start)
---@return string|nil prevPageId Previous page ID (nil if at start)
function SetupWizard:GetPreviousPage(addonId, pageId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return nil, nil
	end

	-- Find current page index
	local currentIndex = nil
	for i, page in ipairs(entry.config.pages) do
		if page.id == pageId then
			currentIndex = i
			break
		end
	end

	if not currentIndex then
		return nil, nil
	end

	-- Try previous page in same addon
	if currentIndex > 1 then
		return addonId, entry.config.pages[currentIndex - 1].id
	end

	-- Try last page of previous addon
	local sortedIds = self:GetSortedAddonIds()
	local previousAddonId = nil
	for _, id in ipairs(sortedIds) do
		if id == addonId then
			break
		end
		previousAddonId = id
	end

	if previousAddonId then
		local prevEntry = self.registeredAddons[previousAddonId]
		if prevEntry and #prevEntry.config.pages > 0 then
			return previousAddonId, prevEntry.config.pages[#prevEntry.config.pages].id
		end
	end

	return nil, nil
end
