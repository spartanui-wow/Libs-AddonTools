---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Setup Wizard (old API) - kept so existing addons keep working. Everything now runs through
-- LibAT.Setup: each old page becomes a 'custom' step whose builder(frame) is called as before, and
-- the window scrolls using the frame's height or frame.totalHeight. New code should use LibAT.Setup.
----------------------------------------------------------------------------------------------------

local Setup = LibAT.Setup
local Log = Setup.Log

---@class SetupWizardPage
---@field id string Unique page identifier
---@field name string Display name for the step list
---@field order? number Sort order (lower = earlier)
---@field builder function(contentFrame: Frame) Populates the page
---@field isComplete? function(): boolean Used once to tell an existing user from a new one
---@field onLeave? function() Called when navigating away from this page
---@field cache? boolean Build the page once and reuse it on later visits
---@field onShow? function(contentFrame: Frame) Called when a cached page is shown again
---@field children? SetupWizardPage[] Child pages, shown right after this one

---@class SetupWizardAddonConfig
---@field name string Display name for the addon
---@field icon? string Optional icon texture path
---@field pages SetupWizardPage[] Array of wizard pages
---@field onComplete? function Runs once, the first time the player finishes this addon's setup
---@field summary? string One line for the Start page
---@field priority? number Lower opens first
---@field isExistingUser? fun(): boolean

---@class LibAT.SetupWizard
LibAT.SetupWizard = {}
local SetupWizard = LibAT.SetupWizard

SetupWizard.registeredAddons = {} ---@type table<string, {id: string, config: SetupWizardAddonConfig, order: number}>
SetupWizard.registrationOrder = 0
SetupWizard.viewedPages = {} ---@type table<string, boolean>
SetupWizard.window = nil ---@type Frame|nil Set when the setup window is created

---@param page SetupWizardPage
---@param index number
---@param addonId string
---@return boolean valid
local function ValidatePage(page, index, addonId)
	if type(page) ~= 'table' or not page.id then
		Log('warning', 'SetupWizard: page ' .. index .. ' missing id for addon ' .. tostring(addonId))
		return false
	end
	if not page.name then
		Log('warning', 'SetupWizard: page ' .. index .. ' missing name for addon ' .. tostring(addonId))
		return false
	end
	if type(page.builder) ~= 'function' then
		Log('warning', 'SetupWizard: page ' .. index .. ' missing builder for addon ' .. tostring(addonId))
		return false
	end
	for ci, child in ipairs(page.children or {}) do
		if not ValidatePage(child, ci, addonId) then
			return false
		end
	end
	return true
end

---Turn an old page into a custom step
---@param reg LibAT.SetupRegistration
---@param page SetupWizardPage
---@param parentId? string
local function AddLegacyPage(reg, page, parentId)
	if reg:GetStep(page.id) then
		Log('warning', 'SetupWizard: page "' .. tostring(page.id) .. '" already exists in ' .. reg.id)
		return
	end
	local step = {
		id = page.id,
		kind = 'custom',
		title = page.name,
		name = page.name,
		order = page.order,
		cache = page.cache and true or false,
		_legacyPage = page,
		_parentId = parentId,
		build = function(frame)
			page.builder(frame)
		end,
	}
	if page.onShow then
		step.onShow = function(frame)
			page.onShow(frame)
		end
	end
	if page.onLeave then
		step.onLeave = function()
			page.onLeave()
		end
	end
	reg:AddStep(step)
	for _, child in ipairs(page.children or {}) do
		AddLegacyPage(reg, child, page.id)
	end
end

---Register an addon (old API). Its pages become custom steps in the setup window.
---@param addonId string
---@param config SetupWizardAddonConfig
function SetupWizard:RegisterAddon(addonId, config)
	if not addonId or type(config) ~= 'table' then
		Log('warning', 'SetupWizard: RegisterAddon requires addonId and config')
		return
	end
	if not config.name then
		Log('warning', 'SetupWizard: config.name is required for addon ' .. tostring(addonId))
		return
	end
	config.pages = config.pages or {}
	for i, page in ipairs(config.pages) do
		if not ValidatePage(page, i, addonId) then
			return
		end
	end

	local reg = Setup:Register(addonId, {
		name = config.name,
		icon = config.icon,
		summary = config.summary,
		priority = config.priority,
		isExistingUser = config.isExistingUser,
		onComplete = config.onComplete,
		_legacy = config.isExistingUser == nil,
	})
	if not reg then
		return
	end

	self.registrationOrder = self.registrationOrder + 1
	self.registeredAddons[addonId] = { id = addonId, config = config, order = self.registrationOrder }
	for _, page in ipairs(config.pages) do
		AddLegacyPage(reg, page, nil)
	end
end

---Add a page to an already-registered addon (old API)
---@param addonId string
---@param page SetupWizardPage
---@param parentPageId? string Adds the page right after this one
function SetupWizard:AddPage(addonId, page, parentPageId)
	local reg = Setup:GetRegistration(addonId)
	if not reg then
		Log('warning', 'SetupWizard: AddPage - addon "' .. tostring(addonId) .. '" not registered')
		return
	end
	if not ValidatePage(page, #reg.steps + 1, addonId) then
		return
	end
	if parentPageId then
		local parent = self:GetPage(addonId, parentPageId)
		if not parent then
			Log('warning', 'SetupWizard: AddPage - parent page "' .. tostring(parentPageId) .. '" not found in addon "' .. tostring(addonId) .. '"')
			return
		end
		parent.children = parent.children or {}
		table.insert(parent.children, page)
	end
	AddLegacyPage(reg, page, parentPageId)
end

---Sort an addon's pages by their order field
---@param addonId string
function SetupWizard:SortPages(addonId)
	local reg = Setup:GetRegistration(addonId)
	if reg then
		reg:SortSteps()
	end
end

---Remove an addon from Setup
---@param addonId string
function SetupWizard:UnregisterAddon(addonId)
	self.registeredAddons[addonId] = nil
	Setup:Unregister(addonId)
end

---Get a page (old page table, or the step for addons using LibAT.Setup)
---@param addonId string
---@param pageId string
---@return SetupWizardPage|LibAT.SetupStep|nil
function SetupWizard:GetPage(addonId, pageId)
	local reg = Setup:GetRegistration(addonId)
	local step = reg and reg:GetStep(pageId)
	if not step then
		return nil
	end
	return step._legacyPage or step
end

---@param addonId string
---@param pageId string
function SetupWizard:MarkPageViewed(addonId, pageId)
	self.viewedPages[addonId .. '.' .. pageId] = true
end

---@param addonId string
---@param pageId string
---@return boolean
function SetupWizard:IsPageViewed(addonId, pageId)
	return self.viewedPages[addonId .. '.' .. pageId] == true
end

---@param addonId string
---@param pageId string
---@return boolean
function SetupWizard:IsPageComplete(addonId, pageId)
	if self:IsAddonComplete(addonId) or self:IsPageViewed(addonId, pageId) then
		return true
	end
	local page = self:GetPage(addonId, pageId)
	if page and type(page.isComplete) == 'function' then
		local ok, done = pcall(page.isComplete)
		return ok and done and true or false
	end
	return false
end

---True once the player finished or skipped this addon's setup
---@param addonId string
---@return boolean
function SetupWizard:IsAddonComplete(addonId)
	local status = Setup:GetStatus(addonId)
	return status == 'done' or status == 'skipped'
end

---Kept for old callers; Setup runs onComplete itself
function SetupWizard:CheckAddonComplete() end

---@return boolean
function SetupWizard:HasUncompletedAddons()
	return #Setup:GetDueAddons() > 0
end

---@return string[]
function SetupWizard:GetUncompletedAddonNames()
	local names = {}
	for _, reg in ipairs(Setup:GetDueAddons()) do
		names[#names + 1] = reg.name
	end
	return names
end

---@return string[]
function SetupWizard:GetSortedAddonIds()
	local ids = {}
	for _, reg in ipairs(Setup:GetSortedRegistrations()) do
		ids[#ids + 1] = reg.id
	end
	return ids
end

---@return number
function SetupWizard:GetAddonCount()
	return #Setup.order
end

---@param addonId string
---@return {id: string}[]
function SetupWizard:GetFlatPageList(addonId)
	local reg = Setup:GetRegistration(addonId)
	local flat = {}
	for _, step in ipairs(reg and reg.steps or {}) do
		flat[#flat + 1] = { id = step.id }
	end
	return flat
end

---Step after the given one, across addons
---@param addonId string
---@param pageId string
---@return string|nil nextAddonId
---@return string|nil nextPageId
function SetupWizard:GetNextPage(addonId, pageId)
	local found = false
	for _, id in ipairs(self:GetSortedAddonIds()) do
		for _, item in ipairs(self:GetFlatPageList(id)) do
			if found then
				return id, item.id
			end
			if id == addonId and item.id == pageId then
				found = true
			end
		end
	end
	return nil, nil
end

---Step before the given one, across addons
---@param addonId string
---@param pageId string
---@return string|nil prevAddonId
---@return string|nil prevPageId
function SetupWizard:GetPreviousPage(addonId, pageId)
	local prevAddon, prevPage
	for _, id in ipairs(self:GetSortedAddonIds()) do
		for _, item in ipairs(self:GetFlatPageList(id)) do
			if id == addonId and item.id == pageId then
				return prevAddon, prevPage
			end
			prevAddon, prevPage = id, item.id
		end
	end
	return nil, nil
end

function SetupWizard:RefreshNavTree()
	if Setup.Hub and Setup.Hub:IsShown() then
		Setup.Hub:RefreshList()
	end
end

---Open the setup window at a page
---@param addonId string
---@param pageId string
function SetupWizard:ShowPage(addonId, pageId)
	Setup:Open(addonId, pageId)
end

function SetupWizard:OpenWindow()
	Setup:Open()
end

function SetupWizard:CloseWindow()
	Setup:Close()
end

function SetupWizard:ToggleWindow()
	Setup:HandleSlash('')
end

---Kept for old callers; the setup window now opens by itself after login
function SetupWizard:CheckFirstRun() end
