---@class LibAT
local LibAT = LibAT

-- DevUI AddonManager Tab: Full-featured addon management with 3-pane layout
-- LEFT: Category filter | CENTER: Addon list with search | RIGHT: Details panel

LibAT.DevUI = LibAT.DevUI or {}

local DevUI, DevUIState
local AddonManager -- Reference to AddonManager module

-- Forward declarations
local BuildContent
local RefreshAddonList
local RefreshCategoryList
local RefreshDetailsPanel
local ApplyChanges

-- Tab-local state (separate from AddonManager module state)
local TabState = {
	ContentFrame = nil,
	LeftPanel = nil, -- Category panel
	CenterPanel = nil, -- Addon list panel
	RightPanel = nil, -- Details panel

	-- Category panel
	CategoryScrollFrame = nil,
	CategoryButtons = {},
	ActiveCategory = 'All', -- Currently selected category

	-- Addon list panel
	SearchBox = nil,
	SortDropdown = nil,
	FilterButtons = {}, -- [All] [Enabled] [Disabled] buttons
	AddonScrollFrame = nil,
	AddonListButtons = {},
	CurrentSearchTerm = '',
	CurrentSortMode = 'name', -- name, title, author, category
	CurrentFilterMode = 'all', -- all, enabled, disabled, loaded, lod

	-- Details panel
	DetailsContent = nil,
	SelectedAddon = nil, -- AddonMetadata object

	-- Pending changes (not yet applied)
	PendingChanges = {}, -- { [addonName] = { enabled = true/false } }
	ChangesLabel = nil,
	ReloadButton = nil,
	ApplyButton = nil,
	CancelButton = nil,

	-- Profile dropdown
	ProfileDropdown = nil,
	SelectedProfile = nil, -- Profile selected in dropdown (not yet applied)

	-- Collapse/expand state
	CollapsedAddons = {}, -- { [addonName] = true } for collapsed parent addons
}

---Initialize the AddonManager tab
---@param devUIModule table The DevUI module
---@param state table The DevUI shared state
function LibAT.DevUI.InitAddonManager(devUIModule, state)
	DevUI = devUIModule
	DevUIState = state

	-- Get AddonManager module reference
	AddonManager = LibAT:GetModule('Handler.AddonManager')

	-- Register this tab with DevUI (tab index 5)
	DevUIState.TabModules[5] = {
		BuildContent = BuildContent,
		OnActivate = function()
			-- Refresh all panels when tab becomes visible
			if AddonManager.logger then
				AddonManager.logger.info('AddonManager tab OnActivate fired')
			end
			RefreshCategoryList()
			RefreshAddonList()
			if TabState.SelectedAddon then
				RefreshDetailsPanel(TabState.SelectedAddon)
			end
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- Build Content (3-Pane Layout)
----------------------------------------------------------------------------------------------------

function BuildContent(contentFrame)
	TabState.ContentFrame = contentFrame

	-- Create main 3-pane layout container
	local container = CreateFrame('Frame', nil, contentFrame)
	container:SetAllPoints()

	-- LEFT PANEL: Categories (20% width)
	TabState.LeftPanel = CreateFrame('Frame', nil, container, 'InsetFrameTemplate3')
	TabState.LeftPanel:SetPoint('TOPLEFT', container, 'TOPLEFT', 5, 0)
	TabState.LeftPanel:SetPoint('BOTTOMLEFT', container, 'BOTTOMLEFT', 5, 30)
	TabState.LeftPanel:SetWidth(150)

	-- CENTER PANEL: Addon List (50% width)
	TabState.CenterPanel = CreateFrame('Frame', nil, container, 'InsetFrameTemplate3')
	TabState.CenterPanel:SetPoint('TOPLEFT', TabState.LeftPanel, 'TOPRIGHT', 18, 0)
	TabState.CenterPanel:SetPoint('BOTTOMLEFT', TabState.LeftPanel, 'BOTTOMRIGHT', 18, 0)
	TabState.CenterPanel:SetWidth(350)

	-- RIGHT PANEL: Details (30% width)
	TabState.RightPanel = CreateFrame('Frame', nil, container, 'InsetFrameTemplate3')
	TabState.RightPanel:SetPoint('TOPLEFT', TabState.CenterPanel, 'TOPRIGHT', 18, 0)
	TabState.RightPanel:SetPoint('BOTTOMRIGHT', container, 'BOTTOMRIGHT', -18, 30)

	-- Build each panel
	BuildCategoryPanel(TabState.LeftPanel)
	BuildAddonListPanel(TabState.CenterPanel)
	BuildDetailsPanel(TabState.RightPanel)
	BuildFooterPanel(container)
end

----------------------------------------------------------------------------------------------------
-- Category Panel (Left)
----------------------------------------------------------------------------------------------------

function BuildCategoryPanel(parent)
	-- Title
	local title = parent:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	title:SetPoint('TOP', parent, 'TOP', 0, -8)
	title:SetText('Categories')

	-- Scroll frame for category list
	local scrollFrame = CreateFrame('ScrollFrame', nil, parent)
	scrollFrame:SetPoint('TOPLEFT', parent, 'TOPLEFT', 2, -30)
	scrollFrame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', 0, 2)

	scrollFrame.ScrollBar = CreateFrame('EventFrame', nil, scrollFrame, 'MinimalScrollBar')
	scrollFrame.ScrollBar:SetPoint('TOPLEFT', scrollFrame, 'TOPRIGHT', 4, 0)
	scrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', scrollFrame, 'BOTTOMRIGHT', 4, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollFrame.ScrollBar)

	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollFrame:SetScrollChild(scrollChild)
	scrollChild:SetSize(160, 1)

	TabState.CategoryScrollFrame = scrollFrame
	TabState.CategoryScrollChild = scrollChild
end

function RefreshCategoryList()
	if not AddonManager or not AddonManager.Categories then
		return
	end

	local scrollChild = TabState.CategoryScrollChild
	if not scrollChild then
		return
	end

	-- Clear existing buttons
	for _, btn in ipairs(TabState.CategoryButtons) do
		btn:Hide()
		btn:SetParent(nil)
	end
	wipe(TabState.CategoryButtons)

	-- Get all categories (includes built-in, custom, and special categories)
	local categories = AddonManager.Categories.GetAllCategories()

	-- Create category buttons
	local yOffset = -4
	for i, category in ipairs(categories) do
		-- Get category count
		local count = AddonManager.Categories and AddonManager.Categories.GetCategoryCount(category) or 0

		-- Hide empty categories (except "All" which always shows)
		if count == 0 and category ~= 'All' then
			-- Skip empty category
		else

		local btn = CreateFrame('Button', nil, scrollChild)
		btn:SetSize(140, 20)
		btn:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, yOffset)

		-- Background (highlight when selected)
		btn.bg = btn:CreateTexture(nil, 'BACKGROUND')
		btn.bg:SetAllPoints()
		btn.bg:SetColorTexture(0.2, 0.2, 0.2, 0.5)
		btn.bg:Hide()

		-- Text (with count) - smaller font for compact display
		btn.text = btn:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		btn.text:SetPoint('LEFT', btn, 'LEFT', 6, 0)

		btn.text:SetText(string.format('%s (%d)', category, count))
		btn.text:SetJustifyH('LEFT')

		-- Click handler
		btn:SetScript('OnClick', function()
			TabState.ActiveCategory = category
			RefreshCategoryList() -- Update selection highlight
			RefreshAddonList() -- Filter addons by category
		end)

		-- Hover
		btn:SetScript('OnEnter', function(self)
			if TabState.ActiveCategory ~= category then
				self.bg:SetAlpha(0.3)
				self.bg:Show()
			end
		end)
		btn:SetScript('OnLeave', function(self)
			if TabState.ActiveCategory ~= category then
				self.bg:Hide()
			end
		end)

		-- Highlight if active
		if TabState.ActiveCategory == category then
			btn.bg:SetAlpha(0.7)
			btn.bg:Show()
			btn.text:SetTextColor(1, 1, 0) -- Yellow
		else
			btn.text:SetTextColor(1, 1, 1) -- White
		end

		table.insert(TabState.CategoryButtons, btn)
		yOffset = yOffset - 22

		end -- end else (non-empty category)
	end

	-- Update scroll child height
	scrollChild:SetHeight(math.abs(yOffset) + 4)
end

----------------------------------------------------------------------------------------------------
-- Addon List Panel (Center)
----------------------------------------------------------------------------------------------------

function BuildAddonListPanel(parent)
	local L = LibAT.L or {}

	-- Header with controls (left: search/buttons, right: label)
	local header = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	header:SetPoint('TOPLEFT', parent, 'TOPLEFT', 4, -4)
	header:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -4, -4)
	header:SetHeight(28)
	header:SetBackdrop({
		bgFile = 'Interface\\Buttons\\WHITE8x8',
	})
	header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

	-- Search box (left-aligned in header, larger)
	local searchBox = CreateFrame('EditBox', nil, header, 'SearchBoxTemplate')
	searchBox:SetPoint('LEFT', header, 'LEFT', 8, 0)
	searchBox:SetSize(160, 24)
	searchBox:SetAutoFocus(false)
	searchBox:SetScript('OnTextChanged', function(self)
		TabState.CurrentSearchTerm = self:GetText()
		RefreshAddonList()
	end)
	TabState.SearchBox = searchBox

	-- Bulk action buttons (larger, left of header label)
	local selectAllBtn = LibAT.UI.CreateButton(header, 80, 24, L['Select All'] or 'Select All')
	selectAllBtn:SetPoint('LEFT', searchBox, 'RIGHT', 8, 0)
	selectAllBtn:SetScript('OnClick', function()
		BulkSelectAll(true)
	end)

	local deselectAllBtn = LibAT.UI.CreateButton(header, 80, 24, L['Deselect All'] or 'Deselect')
	deselectAllBtn:SetPoint('LEFT', selectAllBtn, 'RIGHT', 4, 0)
	deselectAllBtn:SetScript('OnClick', function()
		BulkSelectAll(false)
	end)

	-- Scroll frame for addon list
	local scrollFrame = CreateFrame('ScrollFrame', nil, parent)
	scrollFrame:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 2, -4)
	scrollFrame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', 0, 2)

	scrollFrame.ScrollBar = CreateFrame('EventFrame', nil, scrollFrame, 'MinimalScrollBar')
	scrollFrame.ScrollBar:SetPoint('TOPLEFT', scrollFrame, 'TOPRIGHT', 5, 0)
	scrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', scrollFrame, 'BOTTOMRIGHT', 5, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollFrame.ScrollBar)

	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollFrame:SetScrollChild(scrollChild)
	scrollChild:SetSize(scrollFrame:GetWidth(), 1)

	TabState.AddonScrollFrame = scrollFrame
	TabState.AddonScrollChild = scrollChild
end

function RefreshAddonList()
	if not AddonManager or not AddonManager.Core then
		if AddonManager and AddonManager.logger then
			AddonManager.logger.warning('RefreshAddonList called but AddonManager.Core not available')
		end
		return
	end

	-- Ensure addon cache is populated
	if not AddonManager.Core.AddonCache or #AddonManager.Core.AddonCache == 0 then
		if AddonManager.logger then
			AddonManager.logger.info('AddonCache empty, calling ScanAddons')
		end
		AddonManager.Core.ScanAddons()
	end

	if AddonManager.logger then
		AddonManager.logger.info(string.format('RefreshAddonList: AddonCache has %d entries', AddonManager.Core.AddonCache and #AddonManager.Core.AddonCache or 0))
	end

	local scrollChild = TabState.AddonScrollChild
	if not scrollChild then
		if AddonManager.logger then
			AddonManager.logger.warning('RefreshAddonList: scrollChild is nil')
		end
		return
	end

	-- Clear existing buttons
	for _, btn in ipairs(TabState.AddonListButtons) do
		btn:Hide()
		btn:SetParent(nil)
	end
	wipe(TabState.AddonListButtons)

	-- Get filtered addon list
	local addons = GetFilteredAddonList()

	if AddonManager.logger then
		AddonManager.logger.info(string.format('RefreshAddonList: GetFilteredAddonList returned %d addons', #addons))
	end

	-- Create addon list buttons
	local yOffset = -4
	for i, addon in ipairs(addons) do
		-- Check if this addon is a dependency of another (for indentation)
		local isChild, parentName = AddonManager.Core.IsChildAddon(addon)

		-- Check if parent is collapsed (skip rendering children)
		local shouldSkip = isChild and parentName and TabState.CollapsedAddons[parentName]

		if not shouldSkip then
			-- Check if this addon has dependents (to show collapse/expand button)
			local dependents = AddonManager.Core.GetDependents(addon.name)
			local hasChildren = (#dependents > 0)

			-- Log addons with parent/child relationships for debugging
			if AddonManager.logger and (hasChildren or isChild) then
				AddonManager.logger.info(
					string.format(
						'Hierarchy %s: isChild=%s, parent=%s, hasChildren=%s, dependents=%s',
						addon.name,
						tostring(isChild),
						tostring(parentName or 'nil'),
						tostring(hasChildren),
						table.concat(dependents, ', ')
					)
				)
			end

			-- Container frame for full-width row
			local row = CreateFrame('Frame', nil, scrollChild)
			row:SetSize(scrollChild:GetWidth() - 8, 24)
			row:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 4, yOffset)

			-- Collapse/expand button (for parent addons with children)
			local collapseButton
			if hasChildren then
				collapseButton = CreateFrame('Button', nil, row)
				collapseButton:SetSize(16, 16)
				collapseButton:SetPoint('LEFT', row, 'LEFT', 0, 0)

				local collapseIcon = collapseButton:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
				collapseIcon:SetPoint('CENTER', collapseButton, 'CENTER', 0, 0)

				-- Set icon based on collapsed state
				if TabState.CollapsedAddons[addon.name] then
					collapseIcon:SetText('+') -- Collapsed (click to expand)
				else
					collapseIcon:SetText('-') -- Expanded (click to collapse)
				end

				collapseButton:SetScript('OnClick', function()
					-- Toggle collapsed state
					TabState.CollapsedAddons[addon.name] = not TabState.CollapsedAddons[addon.name]

					if AddonManager.logger then
						AddonManager.logger.info(string.format('Collapse button clicked for %s, collapsed=%s', addon.name, tostring(TabState.CollapsedAddons[addon.name])))
					end

					-- Refresh list to show/hide children
					RefreshAddonList()
				end)
			end

			-- Checkbox (fixed size, not stretched, with indentation for children)
			local btn = CreateFrame('CheckButton', nil, row, 'UICheckButtonTemplate')
			btn:SetSize(24, 24)
			local xOffset = 20 -- All addons start at 20 (aligned with collapse button space)
			if hasChildren then
				-- Parent with children: checkbox right after collapse button
				xOffset = 20
			elseif isChild then
				-- Child addon: indent further
				xOffset = 40
			end
			btn:SetPoint('LEFT', row, 'LEFT', xOffset, 0)
			btn.addon = addon
			btn.hasChildren = hasChildren
			btn.dependents = dependents

			-- Get enable state for tri-state checkbox
			-- Check global enable state (all characters)
			local enableStateGlobal = AddonManager.Core and AddonManager.Core.GetAddOnEnableState(addon.index) or 0

			-- Check enable state for current character specifically
			local currentChar = UnitName('player')
			local enableStateChar = AddonManager.Core and AddonManager.Core.GetAddOnEnableState(addon.index, currentChar) or 0

			local isEnabled = (enableStateChar > 0)
			local showGrayCheck = false

			-- Check for pending changes
			if TabState.PendingChanges[addon.name] ~= nil then
				isEnabled = TabState.PendingChanges[addon.name].enabled
				enableStateChar = isEnabled and 2 or 0
				enableStateGlobal = isEnabled and 2 or 0
			end

			-- Tri-state logic:
			-- - Normal yellow check: enabled for current character
			-- - Gray check: disabled for current character but enabled for other characters
			-- - Unchecked: disabled for all characters
			if enableStateChar == 0 and enableStateGlobal > 0 then
				-- Disabled for current character, but enabled for others
				btn:SetChecked(true)
				btn:SetCheckedTexture('Interface\\Buttons\\UI-CheckBox-Check-Disabled')
				btn.tooltip = 'Disabled for this character, but enabled for other characters'
				showGrayCheck = true
			else
				-- Normal state: enabled or fully disabled
				btn:SetChecked(isEnabled)
				btn:SetCheckedTexture('Interface\\Buttons\\UI-CheckBox-Check')
				btn.tooltip = nil
			end

			-- Text (addon title) - positioned to the right of checkbox on row, clickable
			local text = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			text:SetPoint('LEFT', btn, 'RIGHT', 4, 0)
			text:SetPoint('RIGHT', row, 'RIGHT', -80, 0)
			text:SetText(addon.title)
			text:SetJustifyH('LEFT')
			text:SetWordWrap(false)

			-- Make label clickable to toggle checkbox
			local labelButton = CreateFrame('Button', nil, row)
			labelButton:SetPoint('LEFT', btn, 'RIGHT', 0, 0)
			labelButton:SetPoint('RIGHT', row, 'RIGHT', -80, 0)
			labelButton:SetHeight(24)
			labelButton:SetScript('OnClick', function(self, button)
				if button == 'LeftButton' then
					btn:Click()
				elseif button == 'RightButton' then
					ShowAddonContextMenu(self, addon, dependents)
				end
			end)
			labelButton:SetScript('OnEnter', function()
				TabState.SelectedAddon = addon
				RefreshDetailsPanel(addon)
			end)
			labelButton:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

			-- Status icons (protected, LOD, etc.)
			local iconText = ''
			if AddonManager.SpecialCases and AddonManager.SpecialCases.IsProtectedAddon(addon.name) then
				iconText = iconText .. ' [Protected]'
			end
			if addon.loadOnDemand then
				iconText = iconText .. ' [LOD]'
			end
			if iconText ~= '' then
				local icons = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
				icons:SetPoint('RIGHT', row, 'RIGHT', -4, 0)
				icons:SetText(iconText)
				icons:SetTextColor(0.7, 0.7, 0.7)
			end

			-- Click handler (toggle enable/disable)
			btn:SetScript('OnClick', function(self, button)
				if button == 'RightButton' then
					ShowAddonContextMenu(self, self.addon, self.dependents)
					return
				end

				local newState = self:GetChecked()

				-- If unchecking a parent addon with children, uncheck all dependents
				if not newState and self.hasChildren then
					for _, depName in ipairs(self.dependents) do
						-- Mark dependent as disabled
						TabState.PendingChanges[depName] = { enabled = false }
					end
				end

				-- Check if this reverts to original state
				local originalState = self.addon.enabled
				if newState == originalState then
					-- Remove from pending changes (reverted to original)
					TabState.PendingChanges[self.addon.name] = nil
				else
					-- Store change
					TabState.PendingChanges[self.addon.name] = { enabled = newState }
				end

				UpdateChangeIndicator()

				-- Refresh list to update dependent checkboxes
				RefreshAddonList()
			end)
			btn:RegisterForClicks('LeftButtonUp', 'RightButtonUp')

			-- Tooltip for tri-state checkbox
			if btn.tooltip then
				btn:SetScript('OnEnter', function(self)
					GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
					GameTooltip:SetText(self.tooltip)
					GameTooltip:Show()
				end)
				btn:SetScript('OnLeave', function()
					GameTooltip:Hide()
				end)
			end

			-- Hover handler for row (show details in right panel)
			row:SetScript('OnEnter', function()
				TabState.SelectedAddon = addon
				RefreshDetailsPanel(addon)
			end)
			row:EnableMouse(true)

			table.insert(TabState.AddonListButtons, row)
			yOffset = yOffset - 26
		end -- end if not shouldSkip
	end

	-- Update scroll child height
	scrollChild:SetHeight(math.abs(yOffset) + 4)
end

---Get filtered addon list based on current category, search, and filter settings
---@return LibAT.AddonManager.AddonMetadata[] addons Filtered addon list
function GetFilteredAddonList()
	if not AddonManager then
		return {}
	end

	local allAddons = {}

	-- Filter by category first
	if AddonManager.Categories then
		allAddons = AddonManager.Categories.GetAddonsInCategory(TabState.ActiveCategory)
	else
		-- Fallback if Categories not available yet
		if not AddonManager.Core then
			return {}
		end
		for i, addon in pairs(AddonManager.Core.AddonCache) do
			table.insert(allAddons, addon)
		end
	end

	-- Filter by search term (use Search module if available)
	if TabState.CurrentSearchTerm and TabState.CurrentSearchTerm ~= '' then
		if AddonManager.Search then
			allAddons = AddonManager.Search.SearchAddonsMultiTerm(allAddons, TabState.CurrentSearchTerm)
		else
			-- Fallback basic search
			local filtered = {}
			local searchLower = TabState.CurrentSearchTerm:lower()
			for _, addon in ipairs(allAddons) do
				if
					(addon.name and addon.name:lower():find(searchLower, 1, true))
					or (addon.title and addon.title:lower():find(searchLower, 1, true))
					or (addon.author and addon.author:lower():find(searchLower, 1, true))
					or (addon.notes and addon.notes:lower():find(searchLower, 1, true))
				then
					table.insert(filtered, addon)
				end
			end
			allAddons = filtered
		end
	end

	-- Sort by current sort mode (strip color codes for proper alphabetical sorting)
	local function StripColorCodes(text)
		if not text then
			return ''
		end
		-- Strip |cXXXXXXXX color codes and |r reset codes
		local stripped = text:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|r', '')
		return stripped
	end

	-- Hierarchical sort: parents first, then their children grouped under them
	table.sort(allAddons, function(a, b)
		local aIsChild, aParent = AddonManager.Core.IsChildAddon(a)
		local bIsChild, bParent = AddonManager.Core.IsChildAddon(b)

		-- If A is a child of B, A comes after B
		if aIsChild and aParent == b.name then
			return false
		end

		-- If B is a child of A, B comes after A
		if bIsChild and bParent == a.name then
			return true
		end

		-- If both are children of the same parent, sort them normally
		if aIsChild and bIsChild and aParent == bParent then
			if TabState.CurrentSortMode == 'name' then
				return StripColorCodes(a.name) < StripColorCodes(b.name)
			elseif TabState.CurrentSortMode == 'title' then
				return StripColorCodes(a.title) < StripColorCodes(b.title)
			elseif TabState.CurrentSortMode == 'author' then
				return StripColorCodes(a.author) < StripColorCodes(b.author)
			elseif TabState.CurrentSortMode == 'category' then
				return StripColorCodes(a.category) < StripColorCodes(b.category)
			end
		end

		-- If A is a child but B is not, compare A's parent with B
		if aIsChild and not bIsChild then
			local aParentAddon = AddonManager.Core.GetAddonByName(aParent)
			if aParentAddon then
				if TabState.CurrentSortMode == 'name' then
					return StripColorCodes(aParentAddon.name) < StripColorCodes(b.name)
				elseif TabState.CurrentSortMode == 'title' then
					return StripColorCodes(aParentAddon.title) < StripColorCodes(b.title)
				elseif TabState.CurrentSortMode == 'author' then
					return StripColorCodes(aParentAddon.author) < StripColorCodes(b.author)
				elseif TabState.CurrentSortMode == 'category' then
					return StripColorCodes(aParentAddon.category) < StripColorCodes(b.category)
				end
			end
		end

		-- If B is a child but A is not, compare A with B's parent
		if bIsChild and not aIsChild then
			local bParentAddon = AddonManager.Core.GetAddonByName(bParent)
			if bParentAddon then
				if TabState.CurrentSortMode == 'name' then
					return StripColorCodes(a.name) < StripColorCodes(bParentAddon.name)
				elseif TabState.CurrentSortMode == 'title' then
					return StripColorCodes(a.title) < StripColorCodes(bParentAddon.title)
				elseif TabState.CurrentSortMode == 'author' then
					return StripColorCodes(a.author) < StripColorCodes(bParentAddon.author)
				elseif TabState.CurrentSortMode == 'category' then
					return StripColorCodes(a.category) < StripColorCodes(bParentAddon.category)
				end
			end
		end

		-- Both are top-level parents (or no parent relationship), sort normally
		if TabState.CurrentSortMode == 'name' then
			return StripColorCodes(a.name) < StripColorCodes(b.name)
		elseif TabState.CurrentSortMode == 'title' then
			return StripColorCodes(a.title) < StripColorCodes(b.title)
		elseif TabState.CurrentSortMode == 'author' then
			return StripColorCodes(a.author) < StripColorCodes(b.author)
		elseif TabState.CurrentSortMode == 'category' then
			return StripColorCodes(a.category) < StripColorCodes(b.category)
		end
		return false
	end)

	return allAddons
end

----------------------------------------------------------------------------------------------------
-- Context Menu (Right-Click on Parent Addons)
----------------------------------------------------------------------------------------------------

---Show context menu for any addon (favorites + children controls)
---@param anchorFrame table Frame to anchor menu to
---@param addon table Addon metadata
---@param dependents? table List of dependent addon names
function ShowAddonContextMenu(anchorFrame, addon, dependents)
	if not addon then
		return
	end
	dependents = dependents or {}

	-- Create dropdown menu
	local menu = CreateFrame('Frame', 'LibAT_AddonManager_ContextMenu', UIParent, 'UIDropDownMenuTemplate')

	UIDropDownMenu_Initialize(menu, function(self, level)
		local info

		-- Favorites section
		if AddonManager.Favorites then
			local isFav = AddonManager.Favorites.IsFavorite(addon.name)
			info = UIDropDownMenu_CreateInfo()
			info.notCheckable = true
			if isFav then
				info.text = 'Remove from Favorites'
				info.func = function()
					AddonManager.Favorites.RemoveFavorite(addon.name)
					if TabState.SelectedAddon and TabState.SelectedAddon.name == addon.name then
						RefreshDetailsPanel(addon)
					end
					CloseDropDownMenus()
				end
			else
				info.text = 'Add to Favorites'
				info.func = function()
					AddonManager.Favorites.AddFavorite(addon.name)
					if TabState.SelectedAddon and TabState.SelectedAddon.name == addon.name then
						RefreshDetailsPanel(addon)
					end
					CloseDropDownMenus()
				end
			end
			UIDropDownMenu_AddButton(info, level)

			-- Separator before children section
			if #dependents > 0 then
				info = UIDropDownMenu_CreateInfo()
				info.text = ''
				info.isTitle = true
				info.notCheckable = true
				UIDropDownMenu_AddButton(info, level)
			end
		end

		-- Children section (only if this addon has dependents)
		if #dependents > 0 then
			-- Enable all children
			info = UIDropDownMenu_CreateInfo()
			info.text = string.format('Enable All Children (%d)', #dependents)
			info.notCheckable = true
			info.func = function()
				TabState.PendingChanges[addon.name] = { enabled = true }
				for _, depName in ipairs(dependents) do
					TabState.PendingChanges[depName] = { enabled = true }
				end
				UpdateChangeIndicator()
				RefreshAddonList()
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Disable all children
			info = UIDropDownMenu_CreateInfo()
			info.text = string.format('Disable All Children (%d)', #dependents)
			info.notCheckable = true
			info.func = function()
				for _, depName in ipairs(dependents) do
					TabState.PendingChanges[depName] = { enabled = false }
				end
				UpdateChangeIndicator()
				RefreshAddonList()
				CloseDropDownMenus()
			end
			UIDropDownMenu_AddButton(info, level)

			-- Separator
			info = UIDropDownMenu_CreateInfo()
			info.text = ''
			info.isTitle = true
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, level)

			-- List children (informational)
			info = UIDropDownMenu_CreateInfo()
			info.text = 'Children:'
			info.isTitle = true
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, level)

			for _, depName in ipairs(dependents) do
				local depAddon = AddonManager.Core.GetAddonByName(depName)
				if depAddon then
					info = UIDropDownMenu_CreateInfo()
					info.text = '  ' .. (depAddon.title or depName)
					info.notCheckable = true
					info.disabled = true
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end, 'MENU')

	-- Position and show menu
	ToggleDropDownMenu(1, nil, menu, anchorFrame, 0, 0)
end

----------------------------------------------------------------------------------------------------
-- Details Panel (Right)
----------------------------------------------------------------------------------------------------

function BuildDetailsPanel(parent)
	-- Header
	local header = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	header:SetPoint('TOPLEFT', parent, 'TOPLEFT', 4, -4)
	header:SetPoint('TOPRIGHT', parent, 'TOPRIGHT', -4, -4)
	header:SetHeight(28)
	header:SetBackdrop({
		bgFile = 'Interface\\Buttons\\WHITE8x8',
	})
	header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

	-- Header label
	local headerLabel = header:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	headerLabel:SetPoint('CENTER', header, 'CENTER', 0, 0)
	headerLabel:SetText('Addon Details')

	-- Scroll frame for details content
	local scrollFrame = CreateFrame('ScrollFrame', nil, parent)
	scrollFrame:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 2, -4)
	scrollFrame:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', 0, 2)

	scrollFrame.ScrollBar = CreateFrame('EventFrame', nil, scrollFrame, 'MinimalScrollBar')
	scrollFrame.ScrollBar:SetPoint('TOPLEFT', scrollFrame, 'TOPRIGHT', 5, 0)
	scrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', scrollFrame, 'BOTTOMRIGHT', 5, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollFrame.ScrollBar)

	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollFrame:SetScrollChild(scrollChild)
	scrollChild:SetSize(scrollFrame:GetWidth(), 1)

	TabState.DetailsContent = scrollChild
end

function RefreshDetailsPanel(addon)
	local content = TabState.DetailsContent
	if not content then
		return
	end

	-- Clear existing content (FontStrings and child frames)
	for _, region in ipairs({ content:GetRegions() }) do
		if region:GetObjectType() == 'FontString' then
			region:SetText('')
			region:Hide()
		end
	end
	for _, child in ipairs({ content:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end

	if not addon then
		local noSelection = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
		noSelection:SetPoint('TOP', content, 'TOP', 0, -20)
		noSelection:SetText('No addon selected')
		noSelection:SetTextColor(0.5, 0.5, 0.5)
		return
	end

	-- Addon name (with wrapping for long names)
	local name = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	name:SetPoint('TOP', content, 'TOP', 0, -8)
	name:SetPoint('LEFT', content, 'LEFT', 8, 0)
	name:SetPoint('RIGHT', content, 'RIGHT', -60, 0)
	name:SetText(addon.title)
	name:SetJustifyH('CENTER')
	name:SetWordWrap(true)

	-- Favorite star icon (top-right)
	if AddonManager.Favorites then
		local starBtn = LibAT.UI.CreateFavoriteButton(content, 18, function(self, isFavorite)
			if isFavorite then
				AddonManager.Favorites.AddFavorite(addon.name)
			else
				AddonManager.Favorites.RemoveFavorite(addon.name)
			end
		end)
		starBtn:SetPoint('TOPRIGHT', content, 'TOPRIGHT', -8, -8)
		starBtn:SetFavorite(AddonManager.Favorites.IsFavorite(addon.name))

		starBtn:SetScript('OnEnter', function(self)
			GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
			GameTooltip:SetText(self:IsFavorite() and 'Remove from Favorites' or 'Add to Favorites', 1, 1, 1)
			GameTooltip:Show()
		end)
		starBtn:SetScript('OnLeave', function() GameTooltip:Hide() end)
	end

	-- Version
	local version = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	version:SetPoint('TOP', name, 'BOTTOM', 0, -4)
	version:SetText('Version: ' .. (addon.version or 'Unknown'))
	version:SetTextColor(0.7, 0.7, 0.7)

	-- Author
	local author = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	author:SetPoint('TOP', version, 'BOTTOM', 0, -4)
	author:SetText('Author: ' .. (addon.author or 'Unknown'))

	-- Description
	local desc = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	desc:SetPoint('TOP', author, 'BOTTOM', 0, -12)
	desc:SetPoint('LEFT', content, 'LEFT', 8, 0)
	desc:SetPoint('RIGHT', content, 'RIGHT', -8, 0)
	desc:SetText(addon.notes or 'No description available')
	desc:SetJustifyH('LEFT')
	desc:SetSpacing(2)

	-- Status
	local status = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	status:SetPoint('TOP', desc, 'BOTTOM', 0, -12)
	if addon.loaded then
		status:SetText('Status: |cff00ff00Loaded|r')
	elseif addon.enabled then
		status:SetText('Status: |cffffff00Enabled (not loaded)|r')
	else
		status:SetText('Status: |cffff0000Disabled|r')
	end

	-- Dependency tree (Phase 5)
	if AddonManager.Dependencies then
		local depsTree = AddonManager.Dependencies.GenerateDependencyTree(addon, true, true)
		if depsTree then
			local depsText = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			depsText:SetPoint('TOP', status, 'BOTTOM', 0, -12)
			depsText:SetPoint('LEFT', content, 'LEFT', 8, 0)
			depsText:SetPoint('RIGHT', content, 'RIGHT', -8, 0)
			depsText:SetJustifyH('LEFT')
			depsText:SetSpacing(2)
			depsText:SetText(depsTree)
		end
	elseif addon.dependencies and #addon.dependencies > 0 then
		-- Fallback if Dependencies module not loaded
		local depsLabel = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
		depsLabel:SetPoint('TOP', status, 'BOTTOM', 0, -12)
		depsLabel:SetText('Dependencies:')
		depsLabel:SetTextColor(1, 1, 0)

		local depsList = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		depsList:SetPoint('TOP', depsLabel, 'BOTTOM', 0, -4)
		depsList:SetPoint('LEFT', content, 'LEFT', 16, 0)
		depsList:SetJustifyH('LEFT')
		depsList:SetText(table.concat(addon.dependencies, '\n'))
	end

	-- Compatibility check (Phase 5)
	if AddonManager.Compatibility then
		local report = AddonManager.Compatibility.GenerateCompatibilityReport(addon)
		if not report.compatible or #report.warnings > 0 or #report.info > 0 then
			local compatText = AddonManager.Compatibility.FormatCompatibilityReport(report)
			local compatLabel = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
			compatLabel:SetPoint('BOTTOM', content, 'BOTTOM', 0, 8)
			compatLabel:SetPoint('LEFT', content, 'LEFT', 8, 0)
			compatLabel:SetPoint('RIGHT', content, 'RIGHT', -8, 0)
			compatLabel:SetJustifyH('LEFT')
			compatLabel:SetSpacing(2)
			compatLabel:SetText(compatText)
		end
	elseif AddonManager.Core then
		-- Fallback basic compatibility check
		local compatible, warning = AddonManager.Core.CheckCompatibility(addon.index)
		if not compatible then
			local compatWarning = content:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
			compatWarning:SetPoint('BOTTOM', content, 'BOTTOM', 0, 8)
			compatWarning:SetText('|cffff0000Warning: ' .. warning .. '|r')
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Footer Panel (Bottom)
----------------------------------------------------------------------------------------------------

function BuildFooterPanel(parent)
	local L = LibAT.L or {}

	-- Footer panel (no background)
	local footer = CreateFrame('Frame', nil, parent)
	footer:SetPoint('BOTTOMLEFT', parent, 'BOTTOMLEFT', 4, 4)
	footer:SetPoint('BOTTOMRIGHT', parent, 'BOTTOMRIGHT', -4, 4)
	footer:SetHeight(32)

	-- Reload UI button (bottom left, BLACK button like other tabs)
	local reloadBtn = LibAT.UI.CreateButton(footer, 80, 20, 'Reload UI', true)
	reloadBtn:SetPoint('LEFT', footer, 'LEFT', 0, 0)
	reloadBtn:SetScript('OnClick', function()
		ApplyChanges()
		LibAT:SafeReloadUI()
	end)
	TabState.ReloadButton = reloadBtn

	-- Profile label (center)
	local profileLabel = footer:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	profileLabel:SetPoint('CENTER', footer, 'CENTER', -80, 0)
	profileLabel:SetText((L['Profile'] or 'Profile') .. ':')

	-- Profile dropdown (center, black dropdown like log level)
	local profileDropdown = LibAT.UI.CreateDropdown(footer, 'Profile', 140, 24)
	profileDropdown:SetPoint('LEFT', profileLabel, 'RIGHT', 4, 0)
	TabState.ProfileDropdown = profileDropdown

	-- Save Profile button (saves current addon states to selected profile)
	local saveProfileBtn = LibAT.UI.CreateButton(footer, 100, 24, 'Save Profile')
	saveProfileBtn:SetPoint('LEFT', profileDropdown, 'RIGHT', 8, 0)
	saveProfileBtn:SetScript('OnClick', function()
		local profileName = TabState.SelectedProfile or AddonManager.Profiles.GetActiveProfile() or 'Default'
		-- Apply pending changes first
		ApplyChanges()
		-- Then save current states to the profile
		AddonManager.Profiles.SaveProfile(profileName)
		UpdateChangeIndicator()
		RefreshAddonList()
		if AddonManager.logger then
			AddonManager.logger.info(string.format('Saved current addon states to profile: %s', profileName))
		end
	end)
	TabState.SaveProfileButton = saveProfileBtn

	-- Apply Profile button (applies the previewed pending changes and prompts reload)
	local applyProfileBtn = LibAT.UI.CreateButton(footer, 100, 24, 'Apply Profile')
	applyProfileBtn:SetPoint('LEFT', saveProfileBtn, 'RIGHT', 4, 0)
	applyProfileBtn:SetScript('OnClick', function()
		local profileName = TabState.SelectedProfile or AddonManager.Profiles.GetActiveProfile() or 'Default'

		-- Count pending changes for the confirm message
		local count = 0
		for _ in pairs(TabState.PendingChanges) do
			count = count + 1
		end

		if count == 0 then
			-- No changes to apply, just set active profile
			AddonManager.Profiles.SetActiveProfile(profileName)
			return
		end

		StaticPopupDialogs['LIBAT_ADDONMANAGER_APPLY_PROFILE'] = {
			text = string.format('Apply profile "%s"?\n%d addon(s) will change. This requires a UI reload.', profileName, count),
			button1 = 'Reload UI',
			button2 = 'Cancel',
			OnAccept = function()
				ApplyChanges()
				AddonManager.Profiles.SetActiveProfile(profileName)
				LibAT:SafeReloadUI()
			end,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
		}
		StaticPopup_Show('LIBAT_ADDONMANAGER_APPLY_PROFILE')
	end)
	TabState.ApplyButton = applyProfileBtn

	-- Changes indicator
	local changesLabel = footer:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	changesLabel:SetPoint('LEFT', applyProfileBtn, 'RIGHT', 12, 0)
	changesLabel:SetText('')
	TabState.ChangesLabel = changesLabel

	-- Contextual Reload UI button (only visible when changes are pending)
	local contextReloadBtn = LibAT.UI.CreateButton(footer, 80, 24, 'Reload UI')
	contextReloadBtn:SetPoint('LEFT', changesLabel, 'RIGHT', 8, 0)
	contextReloadBtn:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)
	contextReloadBtn:Hide()
	TabState.ContextReloadButton = contextReloadBtn

	-- Cancel button (far right) - clears preview and resets dropdown to active profile
	local cancelBtn = LibAT.UI.CreateButton(footer, 80, 24, 'Cancel')
	cancelBtn:SetPoint('RIGHT', footer, 'RIGHT', -8, 0)
	cancelBtn:SetScript('OnClick', function()
		wipe(TabState.PendingChanges)
		-- Reset dropdown to the actual active profile
		local activeProfile = AddonManager.Profiles.GetActiveProfile() or 'Default'
		TabState.SelectedProfile = activeProfile
		if TabState.ProfileDropdown then
			TabState.ProfileDropdown:SetText(activeProfile)
		end
		UpdateChangeIndicator()
		RefreshAddonList()
	end)
	TabState.CancelButton = cancelBtn

	-- Setup profile dropdown menu
	SetupProfileDropdown(profileDropdown)
end

function UpdateChangeIndicator()
	if not TabState.ChangesLabel then
		return
	end

	local count = 0
	for _ in pairs(TabState.PendingChanges) do
		count = count + 1
	end

	if count > 0 then
		TabState.ChangesLabel:SetText('|cffff0000' .. count .. ' pending|r')
		if TabState.ContextReloadButton then
			TabState.ContextReloadButton:Show()
		end
	else
		TabState.ChangesLabel:SetText('')
		if TabState.ContextReloadButton then
			TabState.ContextReloadButton:Hide()
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Profile Menu
----------------------------------------------------------------------------------------------------

function SetupProfileDropdown(dropdown)
	if not dropdown or not AddonManager.Profiles then
		return
	end

	-- Set initial text to active profile
	local activeProfile = AddonManager.Profiles.GetActiveProfile() or 'Default'
	dropdown:SetText(activeProfile)
	TabState.SelectedProfile = activeProfile

	-- Set click handler
	dropdown:SetScript('OnMouseDown', function(self)
		ShowProfileMenu(self)
	end)
end

---Preview a profile by computing the diff against current addon states
---and populating PendingChanges so the checkbox list updates
---@param profileName string Profile name to preview
function PreviewProfile(profileName)
	if not AddonManager.Profiles or not AddonManager.Core then
		return
	end

	-- Clear existing pending changes
	wipe(TabState.PendingChanges)

	local profile = AddonManager.Profiles.GetProfile(profileName)
	if not profile or not profile.enabled then
		-- No profile data - just refresh to show current state
		UpdateChangeIndicator()
		RefreshAddonList()
		return
	end

	-- Compare profile states against current actual addon states
	for _, addon in pairs(AddonManager.Core.AddonCache) do
		local profileEnabled = profile.enabled[addon.name]
		-- Only create a pending change if the profile says something different from current state
		if profileEnabled ~= nil and profileEnabled ~= addon.enabled then
			TabState.PendingChanges[addon.name] = { enabled = profileEnabled }
		end
	end

	UpdateChangeIndicator()
	RefreshAddonList()
end

function ShowProfileMenu(anchorFrame)
	if not AddonManager.Profiles then
		return
	end

	local L = LibAT.L or {}

	-- Create dropdown menu
	local menu = CreateFrame('Frame', 'LibAT_AddonManager_ProfileMenu', UIParent, 'UIDropDownMenuTemplate')
	UIDropDownMenu_Initialize(menu, function(self, level)
		local info = UIDropDownMenu_CreateInfo()

		-- Get profile list
		local profiles = AddonManager.Profiles.GetProfileNames()
		local activeProfile = AddonManager.Profiles.GetActiveProfile()

		-- Add profile entries (selecting previews the profile's addon states as pending changes)
		for _, profileName in ipairs(profiles) do
			info.text = profileName
			info.func = function()
				TabState.SelectedProfile = profileName
				if TabState.ProfileDropdown then
					TabState.ProfileDropdown:SetText(profileName)
				end
				PreviewProfile(profileName)
				CloseDropDownMenus()
			end
			info.checked = (profileName == activeProfile)
			UIDropDownMenu_AddButton(info, level)
		end

		-- Separator
		info = UIDropDownMenu_CreateInfo()
		info.isTitle = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, level)

		-- Create new profile
		info = UIDropDownMenu_CreateInfo()
		info.text = L['Create Profile'] or 'Create Profile'
		info.func = function()
			ShowCreateProfileDialog()
			CloseDropDownMenus()
		end
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, level)

		-- Delete profile
		if activeProfile ~= 'Default' then
			info = UIDropDownMenu_CreateInfo()
			info.text = L['Delete Profile'] or 'Delete Profile'
			info.func = function()
				DeleteProfileWithConfirm(activeProfile)
				CloseDropDownMenus()
			end
			info.notCheckable = true
			UIDropDownMenu_AddButton(info, level)
		end
	end, 'MENU')

	ToggleDropDownMenu(1, nil, menu, anchorFrame, 0, 0)
end

function LoadProfileWithConfirm(profileName)
	if not AddonManager.Profiles then
		return
	end

	local L = LibAT.L or {}

	StaticPopupDialogs['LIBAT_ADDONMANAGER_LOAD_PROFILE'] = {
		text = string.format('Load profile "%s"? This will change addon states and reload the UI.', profileName),
		button1 = L['Reload UI'] or 'Reload UI',
		button2 = L['Cancel'] or 'Cancel',
		OnAccept = function()
			AddonManager.Profiles.LoadProfile(profileName)
			LibAT:SafeReloadUI()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}

	StaticPopup_Show('LIBAT_ADDONMANAGER_LOAD_PROFILE')
end

function ShowCreateProfileDialog()
	if not AddonManager.Profiles then
		return
	end

	local L = LibAT.L or {}

	StaticPopupDialogs['LIBAT_ADDONMANAGER_CREATE_PROFILE'] = {
		text = 'Enter profile name:',
		button1 = L['Create Profile'] or 'Create',
		button2 = L['Cancel'] or 'Cancel',
		hasEditBox = true,
		OnAccept = function(self)
			local profileName = self:GetEditBox():GetText()
			if profileName and profileName ~= '' then
				AddonManager.Profiles.CreateProfile(profileName)
				UpdateProfileDropdown()
			end
		end,
		EditBoxOnEnterPressed = function(self)
			local profileName = self:GetText()
			if profileName and profileName ~= '' then
				AddonManager.Profiles.CreateProfile(profileName)
				UpdateProfileDropdown()
			end
			self:GetParent():Hide()
		end,
		EditBoxOnEscapePressed = function(self)
			self:GetParent():Hide()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}

	StaticPopup_Show('LIBAT_ADDONMANAGER_CREATE_PROFILE')
end

function DeleteProfileWithConfirm(profileName)
	if not AddonManager.Profiles then
		return
	end

	local L = LibAT.L or {}

	StaticPopupDialogs['LIBAT_ADDONMANAGER_DELETE_PROFILE'] = {
		text = string.format('Delete profile "%s"? This cannot be undone.', profileName),
		button1 = L['Delete Profile'] or 'Delete',
		button2 = L['Cancel'] or 'Cancel',
		OnAccept = function()
			AddonManager.Profiles.DeleteProfile(profileName)
			UpdateProfileDropdown()
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}

	StaticPopup_Show('LIBAT_ADDONMANAGER_DELETE_PROFILE')
end

function UpdateProfileDropdown()
	if not TabState.ProfileDropdown or not AddonManager.Profiles then
		return
	end

	local activeProfile = AddonManager.Profiles.GetActiveProfile()
	TabState.ProfileDropdown:SetText(activeProfile)
end

----------------------------------------------------------------------------------------------------
-- Bulk Actions
----------------------------------------------------------------------------------------------------

function BulkSelectAll(enabled)
	local addons = GetFilteredAddonList()

	for _, addon in ipairs(addons) do
		-- Skip protected addons when disabling
		local isProtected = AddonManager.SpecialCases and AddonManager.SpecialCases.IsProtectedAddon(addon.name)
		if enabled or not isProtected then
			TabState.PendingChanges[addon.name] = { enabled = enabled }
		end
	end

	UpdateChangeIndicator()
	RefreshAddonList()
end

----------------------------------------------------------------------------------------------------
-- Apply Changes
----------------------------------------------------------------------------------------------------

function ApplyChanges()
	if not AddonManager or not AddonManager.Core then
		return
	end

	for addonName, change in pairs(TabState.PendingChanges) do
		local addon = AddonManager.Core.GetAddonByName(addonName)
		if addon then
			if change.enabled then
				AddonManager.Core.EnableAddon(addon.index)
			else
				AddonManager.Core.DisableAddon(addon.index)
			end
		end
	end

	-- Save changes
	if AddonManager.Core.SaveAddOns then
		AddonManager.Core.SaveAddOns()
	end

	-- Enforce favorites lock after applying changes
	if AddonManager.Favorites then
		AddonManager.Favorites.EnforceLock()
	end

	-- Clear pending changes
	wipe(TabState.PendingChanges)
end
