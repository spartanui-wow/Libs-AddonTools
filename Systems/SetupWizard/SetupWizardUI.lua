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

				-- Add checkmark to completed pages
				local displayName = page.name
				if pageComplete then
					displayName = '|cff00ff00' .. displayName .. '|r |A:common-icon-checkmark:0:0|a'
				end

				subCategories[page.id] = {
					name = displayName,
					key = pageKey,
					onSelect = function()
						SetupWizard:ShowPage(addonId, page.id)
					end,
				}
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

---Clear the right panel content
local function ClearContentPanel()
	if not SetupWizard.window or not SetupWizard.window.ContentScroll then
		return
	end

	local scrollChild = SetupWizard.window.ContentScrollChild
	if scrollChild then
		-- Hide and release all child frames
		for _, child in ipairs({ scrollChild:GetChildren() }) do
			child:Hide()
			child:SetParent(nil)
		end
		-- Clear any font strings
		for _, region in ipairs({ scrollChild:GetRegions() }) do
			region:Hide()
		end
	end
end

---Show a specific page in the right panel
---@param addonId string Addon identifier
---@param pageId string Page identifier
function SetupWizard:ShowPage(addonId, pageId)
	local page = self:GetPage(addonId, pageId)
	if not page then
		LibAT:Print('SetupWizard: Page not found: ' .. tostring(addonId) .. '.' .. tostring(pageId))
		return
	end

	-- Update current state
	self.currentAddonId = addonId
	self.currentPageId = pageId

	-- Clear existing content
	ClearContentPanel()

	-- Call the page builder to populate content
	local scrollChild = self.window.ContentScrollChild
	if scrollChild and page.builder then
		page.builder(scrollChild)
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
	self.window.ContentScroll:SetPoint('TOPLEFT', self.window.RightPanel, 'TOPLEFT', 8, -8)
	self.window.ContentScroll:SetPoint('BOTTOMRIGHT', self.window.RightPanel, 'BOTTOMRIGHT', -8, 8)

	-- Create minimal scrollbar
	self.window.ContentScroll.ScrollBar = CreateFrame('EventFrame', nil, self.window.ContentScroll, 'MinimalScrollBar')
	self.window.ContentScroll.ScrollBar:SetPoint('TOPLEFT', self.window.ContentScroll, 'TOPRIGHT', 2, 0)
	self.window.ContentScroll.ScrollBar:SetPoint('BOTTOMLEFT', self.window.ContentScroll, 'BOTTOMRIGHT', 2, 0)
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
	self.window.PrevButton:SetPoint('LEFT', bottomBar, 'LEFT', 180, 0)
	self.window.PrevButton:Disable()
	self.window.PrevButton:SetScript('OnClick', function()
		local prevAddon, prevPage = SetupWizard:GetPreviousPage(SetupWizard.currentAddonId, SetupWizard.currentPageId)
		if prevAddon and prevPage then
			SetupWizard:ShowPage(prevAddon, prevPage)
		end
	end)

	-- Next button
	self.window.NextButton = LibAT.UI.CreateButton(bottomBar, 100, 22, 'Next')
	self.window.NextButton:SetPoint('RIGHT', bottomBar, 'RIGHT', -10, 0)
	self.window.NextButton:SetScript('OnClick', function()
		local nextAddon, nextPage = SetupWizard:GetNextPage(SetupWizard.currentAddonId, SetupWizard.currentPageId)
		if nextAddon and nextPage then
			SetupWizard:ShowPage(nextAddon, nextPage)
		else
			-- Last page — close the wizard
			SetupWizard:CloseWindow()
		end
	end)

	-- Close button in bottom bar
	self.window.BottomCloseButton = LibAT.UI.CreateButton(bottomBar, 70, 22, 'Close')
	self.window.BottomCloseButton:SetPoint('RIGHT', self.window.NextButton, 'LEFT', -5, 0)
	self.window.BottomCloseButton:SetScript('OnClick', function()
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
			local entry = self.registeredAddons[addonId]
			if entry then
				for _, page in ipairs(entry.config.pages) do
					if not page.isComplete or not page.isComplete() then
						self:ShowPage(addonId, page.id)
						return
					end
				end
			end
		end

		-- All complete or no pages — just show first available
		if sortedIds[1] then
			local entry = self.registeredAddons[sortedIds[1]]
			if entry and #entry.config.pages > 0 then
				self:ShowPage(sortedIds[1], entry.config.pages[1].id)
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

	-- Show static popup prompt
	StaticPopupDialogs['LIBAT_SETUP_WIZARD_PROMPT'] = {
		text = 'Libs-AddonTools has detected addons that need setup.\n\nWould you like to open the Setup Wizard?',
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
	StaticPopup_Show('LIBAT_SETUP_WIZARD_PROMPT')
end
