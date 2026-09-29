---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Setup Wizard UI - Window, Navigation Tree, Page Rendering
----------------------------------------------------------------------------------------------------

local SetupWizard = LibAT.SetupWizard

-- UI state
SetupWizard.window = nil ---@type Frame|nil
SetupWizard.currentAddonId = nil ---@type string|nil
SetupWizard.currentPageId = nil ---@type string|nil

----------------------------------------------------------------------------------------------------
-- Navigation Tree Building
----------------------------------------------------------------------------------------------------

---Build the navigation categories from registered addons
---@return table<string, NavCategory> categories
local function BuildNavCategories()
	local categories = {}
	local sortedIds = SetupWizard:GetSortedAddonIds()

	for _, addonId in ipairs(sortedIds) do
		local entry = SetupWizard.registeredAddons[addonId]
		if entry then
			local addonComplete = SetupWizard:IsAddonComplete(addonId)

			-- Build subcategories from pages
			local subCategories = {}
			local sortedPageKeys = {}
			for _, page in ipairs(entry.config.pages) do
				local pageKey = addonId .. '.' .. page.id
				local pageComplete = SetupWizard:IsPageComplete(addonId, page.id)

				local displayName = page.name
				if pageComplete then
					displayName = '|cff00ff00' .. displayName .. '|r |A:common-icon-checkmark:0:0|a'
				end

				local subCat = {
					name = displayName,
					key = pageKey,
					onSelect = function()
						SetupWizard:ShowPage(addonId, page.id)
					end,
				}

				-- Build sub-subcategories from children
				if page.children and #page.children > 0 then
					subCat.expanded = (SetupWizard.currentAddonId == addonId)
					subCat.subSubCategories = {}
					subCat.sortedKeys = {}
					for _, child in ipairs(page.children) do
						local childKey = addonId .. '.' .. child.id
						local childComplete = SetupWizard:IsPageComplete(addonId, child.id)

						local childDisplayName = child.name
						if childComplete then
							childDisplayName = '|cff00ff00' .. childDisplayName .. '|r |A:common-icon-checkmark:0:0|a'
						end

						subCat.subSubCategories[child.id] = {
							name = childDisplayName,
							key = childKey,
							onSelect = function()
								SetupWizard:ShowPage(addonId, child.id)
							end,
						}
						table.insert(subCat.sortedKeys, child.id)
					end
				end

				subCategories[page.id] = subCat
				table.insert(sortedPageKeys, page.id)
			end

			-- Add checkmark to completed addons
			local addonDisplayName = entry.config.name
			if addonComplete then
				addonDisplayName = '|cff00ff00' .. addonDisplayName .. '|r |A:common-icon-checkmark:0:0|a'
			end

			categories[addonId] = {
				name = addonDisplayName,
				key = addonId,
				expanded = (SetupWizard.currentAddonId == addonId),
				subCategories = subCategories,
				sortedKeys = sortedPageKeys,
			}
		end
	end

	return categories
end

---Refresh the navigation tree (called when addons register or completion changes)
function SetupWizard:RefreshNavTree()
	if not self.window or not self.window.NavTree then
		return
	end

	local categories = BuildNavCategories()
	self.window.NavTree.config.categories = categories

	-- Update activeKey to current selection
	if self.currentAddonId and self.currentPageId then
		self.window.NavTree.config.activeKey = self.currentAddonId .. '.' .. self.currentPageId
	end

	LibAT.UI.BuildNavigationTree(self.window.NavTree)
end

----------------------------------------------------------------------------------------------------
-- Page Rendering
----------------------------------------------------------------------------------------------------

---Hide whatever the right panel is showing (welcome text and page containers)
local function ClearContentPanel()
	if not SetupWizard.window or not SetupWizard.window.ContentScrollChild then
		return
	end
	if SetupWizard.window.WelcomeText then
		SetupWizard.window.WelcomeText:Hide()
	end
	for _, container in pairs(SetupWizard.window.PageContainers or {}) do
		container:Hide()
	end
end

---Get the frame a page renders into. Pages are rebuilt on every visit because builders may show
---state other pages change; a page registered with cache = true is built once and reused.
---@param key string addonId.pageId
---@param page SetupWizardPage
---@return Frame container
---@return boolean needsBuild
local function GetPageContainer(key, page)
	local window = SetupWizard.window
	window.PageContainers = window.PageContainers or {}
	local existing = window.PageContainers[key]
	if existing and page.cache then
		return existing, false
	end

	local scrollChild = window.ContentScrollChild
	local container = CreateFrame('Frame', nil, scrollChild)
	container:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, 0)
	container:SetPoint('TOPRIGHT', scrollChild, 'TOPRIGHT', 0, 0)
	container:SetWidth(math.max(scrollChild:GetWidth(), 1))
	container:SetHeight(1)
	window.PageContainers[key] = container
	return container, true
end

---Show a specific page in the right panel
---@param addonId string Addon identifier
---@param pageId string Page identifier
function SetupWizard:ShowPage(addonId, pageId)
	local page = self:GetPage(addonId, pageId)
	if not page then
		if LibAT.InternalLog then
			LibAT.InternalLog.warning('SetupWizard: Page not found: ' .. tostring(addonId) .. '.' .. tostring(pageId))
		end
		return
	end

	-- Call onLeave on current page before switching
	local leavingAddonId = self.currentAddonId
	if self.currentAddonId and self.currentPageId then
		local currentPage = self:GetPage(self.currentAddonId, self.currentPageId)
		if currentPage and currentPage.onLeave then
			currentPage.onLeave()
		end
	end
	if leavingAddonId and leavingAddonId ~= addonId then
		self:CheckAddonComplete(leavingAddonId)
	end

	-- Update current state
	self.currentAddonId = addonId
	self.currentPageId = pageId

	-- Mark as viewed
	self:MarkPageViewed(addonId, pageId)

	-- Clear existing content
	ClearContentPanel()

	-- Render the page into its own container; the scroll area follows the container's height
	local scrollChild = self.window.ContentScrollChild
	if scrollChild then
		local container, needsBuild = GetPageContainer(addonId .. '.' .. pageId, page)
		container:Show()
		if needsBuild and page.builder then
			page.builder(container)
		elseif page.onShow then
			page.onShow(container)
		end
		-- Builders may either size the container or report their height in container.totalHeight
		local height = container:GetHeight() or 1
		if type(container.totalHeight) == 'number' and container.totalHeight > height then
			height = container.totalHeight
		end
		height = math.max(height, 1)
		container:SetHeight(height)
		scrollChild:SetHeight(height)
	end

	-- Update navigation tree highlights
	self:RefreshNavTree()

	-- Update button states
	self:UpdateNavigationButtons()

	-- Update page title
	local entry = self.registeredAddons[addonId]
	if entry and self.window.PageTitle then
		self.window.PageTitle:SetText(entry.config.name .. ' - ' .. page.name)
	end
end

---Update Previous/Next button enabled states
function SetupWizard:UpdateNavigationButtons()
	if not self.window then
		return
	end

	local prevAddon, prevPage = self:GetPreviousPage(self.currentAddonId, self.currentPageId)
	local nextAddon, nextPage = self:GetNextPage(self.currentAddonId, self.currentPageId)

	if self.window.PrevButton then
		if prevAddon and prevPage then
			self.window.PrevButton:Enable()
		else
			self.window.PrevButton:Disable()
		end
	end

	if self.window.NextButton then
		if nextAddon and nextPage then
			self.window.NextButton:SetText('Next')
			self.window.NextButton:Enable()
		else
			self.window.NextButton:SetText('Finish')
			self.window.NextButton:Enable()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Window Creation
----------------------------------------------------------------------------------------------------

---Create the Setup Wizard window
function SetupWizard:CreateWindow()
	if self.window then
		return
	end

	-- Create base window using LibAT.UI
	self.window = LibAT.UI.CreateWindow({
		name = 'LibAT_SetupWizard',
		title = '|cffffffffLib|cffe21f1fAT|r Setup Wizard',
		width = 800,
		height = 538,
		portrait = 'Interface\\AddOns\\libsaddontools\\Logo-Icon',
	})
	self.window:HookScript('OnHide', function()
		SetupWizard:OnWindowHidden()
	end)

	-- Create control frame (top bar)
	self.window.ControlFrame = LibAT.UI.CreateControlFrame(self.window)

	-- Add page title in control frame
	self.window.PageTitle = LibAT.UI.CreateHeader(self.window.ControlFrame, 'Select a page to begin')
	self.window.PageTitle:SetPoint('LEFT', self.window.ControlFrame, 'LEFT', 10, 0)
	self.window.PageTitle:SetPoint('RIGHT', self.window.ControlFrame, 'RIGHT', -10, 0)

	-- Create main content area
	self.window.MainContent = LibAT.UI.CreateContentFrame(self.window, self.window.ControlFrame, -4, 40)

	-- Create left panel for navigation
	self.window.LeftPanel = LibAT.UI.CreateLeftPanel(self.window.MainContent)

	-- Initialize navigation tree
	self.window.NavTree = LibAT.UI.CreateNavigationTree({
		parent = self.window.LeftPanel,
		categories = {},
		activeKey = nil,
		onSubCategoryClick = function(subCategoryKey, subCategoryData)
			-- Selection is handled by onSelect on each page subcategory
		end,
	})

	-- Create right panel for content
	self.window.RightPanel = LibAT.UI.CreateRightPanel(self.window.MainContent, self.window.LeftPanel)

	-- Create scrollable content area inside right panel
	self.window.ContentScroll = CreateFrame('ScrollFrame', nil, self.window.RightPanel)
	self.window.ContentScroll:SetPoint('TOPLEFT', self.window.RightPanel, 'TOPLEFT', 8, -28)
	self.window.ContentScroll:SetPoint('BOTTOMRIGHT', self.window.RightPanel, 'BOTTOMRIGHT', -8, 8)

	-- Create minimal scrollbar (offset 15px right so it clears the border)
	self.window.ContentScroll.ScrollBar = CreateFrame('EventFrame', nil, self.window.ContentScroll, 'MinimalScrollBar')
	self.window.ContentScroll.ScrollBar:SetPoint('TOPLEFT', self.window.ContentScroll, 'TOPRIGHT', 13, 0)
	self.window.ContentScroll.ScrollBar:SetPoint('BOTTOMLEFT', self.window.ContentScroll, 'BOTTOMRIGHT', 13, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(self.window.ContentScroll, self.window.ContentScroll.ScrollBar)

	-- Create scroll child (this is what page builders populate)
	self.window.ContentScrollChild = CreateFrame('Frame', nil, self.window.ContentScroll)
	self.window.ContentScrollChild:SetWidth(self.window.ContentScroll:GetWidth() or 500)
	self.window.ContentScrollChild:SetHeight(1) -- Will be sized by content
	self.window.ContentScroll:SetScrollChild(self.window.ContentScrollChild)

	-- Keep scroll child width in sync with scroll frame
	self.window.ContentScroll:SetScript('OnSizeChanged', function(scrollFrame)
		self.window.ContentScrollChild:SetWidth(math.max(scrollFrame:GetWidth() - 20, 1))
	end)

	-- Create welcome text (shown when no page is selected)
	self.window.WelcomeText = LibAT.UI.CreateLabel(self.window.ContentScrollChild, '', 'GameFontNormal')
	self.window.WelcomeText:SetPoint('TOP', self.window.ContentScrollChild, 'TOP', 0, -40)
	self.window.WelcomeText:SetPoint('LEFT', self.window.ContentScrollChild, 'LEFT', 20, 0)
	self.window.WelcomeText:SetPoint('RIGHT', self.window.ContentScrollChild, 'RIGHT', -20, 0)
	self.window.WelcomeText:SetJustifyH('CENTER')
	self.window.WelcomeText:SetWordWrap(true)
	self.window.WelcomeText:SetText(
		'Welcome to the Libs-AddonTools Setup Wizard.\n\nSelect an addon from the left panel to begin configuring it.\nCompleted pages will show a |A:common-icon-checkmark:0:0|a checkmark.'
	)

	-- Create bottom navigation bar
	local bottomBar = CreateFrame('Frame', nil, self.window)
	bottomBar:SetPoint('BOTTOMLEFT', self.window, 'BOTTOMLEFT', 0, 0)
	bottomBar:SetPoint('BOTTOMRIGHT', self.window, 'BOTTOMRIGHT', 0, 0)
	bottomBar:SetHeight(36)

	-- Previous button
	self.window.PrevButton = LibAT.UI.CreateButton(bottomBar, 100, 22, 'Previous')
	self.window.PrevButton:SetPoint('LEFT', bottomBar, 'LEFT', 180, -4)
	self.window.PrevButton:Disable()
	self.window.PrevButton:SetScript('OnClick', function()
		local prevAddon, prevPage = SetupWizard:GetPreviousPage(SetupWizard.currentAddonId, SetupWizard.currentPageId)
		if prevAddon and prevPage then
			SetupWizard:ShowPage(prevAddon, prevPage)
		end
	end)

	-- Next button
	self.window.NextButton = LibAT.UI.CreateButton(bottomBar, 100, 22, 'Next')
	self.window.NextButton:SetPoint('RIGHT', bottomBar, 'RIGHT', -10, -4)
	self.window.NextButton:SetScript('OnClick', function()
		local nextAddon, nextPage = SetupWizard:GetNextPage(SetupWizard.currentAddonId, SetupWizard.currentPageId)
		if nextAddon and nextPage then
			SetupWizard:ShowPage(nextAddon, nextPage)
		else
			-- Last page — call onLeave then close
			if SetupWizard.currentAddonId and SetupWizard.currentPageId then
				local currentPage = SetupWizard:GetPage(SetupWizard.currentAddonId, SetupWizard.currentPageId)
				if currentPage and currentPage.onLeave then
					currentPage.onLeave()
				end
			end
			SetupWizard:CloseWindow()
		end
	end)

	-- Close button in bottom bar
	self.window.BottomCloseButton = LibAT.UI.CreateButton(bottomBar, 70, 22, 'Close')
	self.window.BottomCloseButton:SetPoint('RIGHT', self.window.NextButton, 'LEFT', -5, 0)
	self.window.BottomCloseButton:SetScript('OnClick', function()
		-- Call onLeave on current page
		if SetupWizard.currentAddonId and SetupWizard.currentPageId then
			local currentPage = SetupWizard:GetPage(SetupWizard.currentAddonId, SetupWizard.currentPageId)
			if currentPage and currentPage.onLeave then
				currentPage.onLeave()
			end
		end
		SetupWizard:CloseWindow()
	end)

	-- Build initial navigation tree
	self:RefreshNavTree()
end

----------------------------------------------------------------------------------------------------
-- Window Management
----------------------------------------------------------------------------------------------------

---Open the Setup Wizard window
function SetupWizard:OpenWindow()
	if not self.window then
		self:CreateWindow()
	end

	-- Refresh nav tree to show current registration state
	self:RefreshNavTree()

	-- Show window
	self.window:Show()

	-- If no page selected yet, try to select the first uncompleted page
	if not self.currentPageId then
		local sortedIds = self:GetSortedAddonIds()
		for _, addonId in ipairs(sortedIds) do
			local flat = self:GetFlatPageList(addonId)
			for _, item in ipairs(flat) do
				if not self:IsPageComplete(addonId, item.id) then
					self:ShowPage(addonId, item.id)
					return
				end
			end
		end

		-- All complete or no pages — just show first available
		if sortedIds[1] then
			local flat = self:GetFlatPageList(sortedIds[1])
			if #flat > 0 then
				self:ShowPage(sortedIds[1], flat[1].id)
			end
		end
	end
end

---Close the Setup Wizard window
function SetupWizard:CloseWindow()
	if self.window then
		self.window:Hide()
	end
end

---The window was hidden (Finish, Close, Escape or the X): the addon being viewed may now be complete
function SetupWizard:OnWindowHidden()
	if self.currentAddonId then
		self:CheckAddonComplete(self.currentAddonId)
	end
end

---Toggle the Setup Wizard window
function SetupWizard:ToggleWindow()
	if self.window and self.window:IsShown() then
		self:CloseWindow()
	else
		self:OpenWindow()
	end
end

----------------------------------------------------------------------------------------------------
-- First-Run Detection
----------------------------------------------------------------------------------------------------

---Show first-run prompt if there are uncompleted addons
function SetupWizard:CheckFirstRun()
	-- Only prompt if there are registered addons with uncompleted pages
	if not self:HasUncompletedAddons() then
		return
	end

	-- Check if user has dismissed the wizard before
	if LibAT.Database and LibAT.Database.global and LibAT.Database.global.setupWizardDismissed then
		return
	end

	-- Build addon list for the prompt
	local addonNames = self:GetUncompletedAddonNames()
	local addonList = table.concat(addonNames, ', ')

	-- Show static popup prompt
	StaticPopupDialogs['LIBAT_SETUP_WIZARD_PROMPT'] = {
		-- The addon list goes in as an argument: popup text is formatted, so a '%' in a name would break it
		text = 'The following addons have setup pages to review:\n\n%s\n\nWould you like to open the Setup Wizard?',
		button1 = 'Open Wizard',
		button2 = 'Not Now',
		button3 = "Don't Ask Again",
		OnAccept = function()
			SetupWizard:OpenWindow()
		end,
		OnCancel = function()
			-- Just dismiss, will ask again next login
		end,
		OnAlt = function()
			-- Mark as permanently dismissed
			if LibAT.Database and LibAT.Database.global then
				LibAT.Database.global.setupWizardDismissed = true
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show('LIBAT_SETUP_WIZARD_PROMPT', addonList)
end
