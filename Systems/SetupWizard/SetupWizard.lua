---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Setup Wizard Core - Registration API & Completion Tracking
----------------------------------------------------------------------------------------------------

---@class SetupWizardPage
---@field id string Unique page identifier
---@field name string Display name for nav tree
---@field order? number Sort order (lower = earlier). Pages without order sort by registration order.
---@field builder function(contentFrame: Frame) Populates the right panel content
---@field isComplete? function(): boolean Dynamic completion check (returns true if page setup is done)
---@field onLeave? function() Called when navigating away from this page
---@field children? SetupWizardPage[] Optional child pages (shown as sub-subcategories in nav tree)

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
SetupWizard.viewedPages = {} ---@type table<string, boolean> In-memory viewed tracking (resets on /rl)

----------------------------------------------------------------------------------------------------
-- Registration API
----------------------------------------------------------------------------------------------------

---Validate a page table has required fields
---@param page SetupWizardPage
---@param index number
---@param addonId string
---@return boolean valid
local function ValidatePage(page, index, addonId)
	if not page.id then
		LibAT:Print('SetupWizard: page ' .. index .. ' missing id for addon ' .. tostring(addonId))
		return false
	end
	if not page.name then
		LibAT:Print('SetupWizard: page ' .. index .. ' missing name for addon ' .. tostring(addonId))
		return false
	end
	if not page.builder then
		LibAT:Print('SetupWizard: page ' .. index .. ' missing builder for addon ' .. tostring(addonId))
		return false
	end
	-- Validate children recursively
	if page.children then
		for ci, child in ipairs(page.children) do
			if not ValidatePage(child, ci, addonId) then
				return false
			end
		end
	end
	return true
end

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

	if not config.pages then
		config.pages = {}
	end

	-- Validate each page
	for i, page in ipairs(config.pages) do
		if not ValidatePage(page, i, addonId) then
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

---Add a page to an already-registered addon
---@param addonId string Registered addon key (e.g., 'spartanui')
---@param page SetupWizardPage Page table to add
---@param parentPageId? string If provided, adds as child of that page
function SetupWizard:AddPage(addonId, page, parentPageId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		LibAT:Print('SetupWizard: AddPage - addon "' .. tostring(addonId) .. '" not registered')
		return
	end

	if not ValidatePage(page, #entry.config.pages + 1, addonId) then
		return
	end

	if parentPageId then
		-- Find parent page and add as child
		local parent = self:GetPage(addonId, parentPageId)
		if not parent then
			LibAT:Print('SetupWizard: AddPage - parent page "' .. tostring(parentPageId) .. '" not found in addon "' .. tostring(addonId) .. '"')
			return
		end
		if not parent.children then
			parent.children = {}
		end
		table.insert(parent.children, page)
	else
		table.insert(entry.config.pages, page)
	end

	-- Re-sort pages by order field
	self:SortPages(addonId)

	LibAT:Debug('SetupWizard: Added page "' .. page.name .. '" to addon "' .. addonId .. '"')

	if self.window and self.RefreshNavTree then
		self:RefreshNavTree()
	end
end

---Sort an addon's pages by their order field
---@param addonId string
function SetupWizard:SortPages(addonId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return
	end

	table.sort(entry.config.pages, function(a, b)
		local orderA = a.order or 999
		local orderB = b.order or 999
		if orderA == orderB then
			return false
		end
		return orderA < orderB
	end)

	-- Sort children within each page
	for _, page in ipairs(entry.config.pages) do
		if page.children and #page.children > 1 then
			table.sort(page.children, function(a, b)
				local orderA = a.order or 999
				local orderB = b.order or 999
				if orderA == orderB then
					return false
				end
				return orderA < orderB
			end)
		end
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
-- Viewed Tracking (in-memory, resets on /rl)
----------------------------------------------------------------------------------------------------

---Mark a page as viewed
---@param addonId string
---@param pageId string
function SetupWizard:MarkPageViewed(addonId, pageId)
	self.viewedPages[addonId .. '.' .. pageId] = true
end

---Check if a page has been viewed this session
---@param addonId string
---@param pageId string
---@return boolean
function SetupWizard:IsPageViewed(addonId, pageId)
	return self.viewedPages[addonId .. '.' .. pageId] == true
end

----------------------------------------------------------------------------------------------------
-- Completion Tracking
----------------------------------------------------------------------------------------------------

---Check if a specific page is complete (isComplete returns true OR page has been viewed)
---@param addonId string Addon identifier
---@param pageId string Page identifier
---@return boolean isComplete
function SetupWizard:IsPageComplete(addonId, pageId)
	-- Viewed pages count as complete
	if self:IsPageViewed(addonId, pageId) then
		return true
	end

	local entry = self.registeredAddons[addonId]
	if not entry then
		return false
	end

	-- Search top-level pages and children
	local page = self:GetPage(addonId, pageId)
	if page then
		if page.isComplete then
			return page.isComplete()
		end
		return false
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
		if not self:IsPageComplete(addonId, page.id) then
			return false
		end
		-- Check children too
		if page.children then
			for _, child in ipairs(page.children) do
				if not self:IsPageComplete(addonId, child.id) then
					return false
				end
			end
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

---Get a specific page from an addon (searches top-level and children)
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
		if page.children then
			for _, child in ipairs(page.children) do
				if child.id == pageId then
					return child
				end
			end
		end
	end

	return nil
end

---Build a flat list of all pages (including children) for navigation
---@param addonId string
---@return table[] flatPages Array of {id=pageId} in display order
function SetupWizard:GetFlatPageList(addonId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return {}
	end

	local flat = {}
	for _, page in ipairs(entry.config.pages) do
		table.insert(flat, { id = page.id })
		if page.children then
			for _, child in ipairs(page.children) do
				table.insert(flat, { id = child.id })
			end
		end
	end
	return flat
end

---Get the next page after the current one (across addons if needed), walking into children
---@param addonId string Current addon identifier
---@param pageId string Current page identifier
---@return string|nil nextAddonId Next addon ID (nil if at end)
---@return string|nil nextPageId Next page ID (nil if at end)
function SetupWizard:GetNextPage(addonId, pageId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return nil, nil
	end

	-- Build flat list and find current position
	local flat = self:GetFlatPageList(addonId)
	local currentIndex = nil
	for i, item in ipairs(flat) do
		if item.id == pageId then
			currentIndex = i
			break
		end
	end

	if not currentIndex then
		return nil, nil
	end

	-- Try next page in same addon (flat list includes children)
	if currentIndex < #flat then
		return addonId, flat[currentIndex + 1].id
	end

	-- Try first page of next addon
	local sortedIds = self:GetSortedAddonIds()
	local foundCurrent = false
	for _, id in ipairs(sortedIds) do
		if foundCurrent then
			local nextFlat = self:GetFlatPageList(id)
			if #nextFlat > 0 then
				return id, nextFlat[1].id
			end
		end
		if id == addonId then
			foundCurrent = true
		end
	end

	return nil, nil
end

---Get the previous page before the current one (across addons if needed), walking into children
---@param addonId string Current addon identifier
---@param pageId string Current page identifier
---@return string|nil prevAddonId Previous addon ID (nil if at start)
---@return string|nil prevPageId Previous page ID (nil if at start)
function SetupWizard:GetPreviousPage(addonId, pageId)
	local entry = self.registeredAddons[addonId]
	if not entry then
		return nil, nil
	end

	-- Build flat list and find current position
	local flat = self:GetFlatPageList(addonId)
	local currentIndex = nil
	for i, item in ipairs(flat) do
		if item.id == pageId then
			currentIndex = i
			break
		end
	end

	if not currentIndex then
		return nil, nil
	end

	-- Try previous page in same addon (flat list includes children)
	if currentIndex > 1 then
		return addonId, flat[currentIndex - 1].id
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
		local prevFlat = self:GetFlatPageList(previousAddonId)
		if #prevFlat > 0 then
			return previousAddonId, prevFlat[#prevFlat].id
		end
	end

	return nil, nil
end
