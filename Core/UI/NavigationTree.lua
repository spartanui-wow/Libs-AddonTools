---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Navigation Tree Data Structures
----------------------------------------------------------------------------------------------------

---@class NavCategory
---@field name string Category display name
---@field key string Unique category key
---@field expanded boolean Whether category is expanded
---@field isToken? boolean Use token/blue styling (for external addons)
---@field isLeaf? boolean Leaf category with no subcategories — acts as direct selection
---@field subCategories table<string, NavSubCategory> Sub-categories
---@field sortedKeys string[] Sorted subcategory keys
---@field button? Frame Category button reference
---@field onSelect? function Optional callback when category is selected

---@class NavSubCategory
---@field name string Subcategory display name
---@field key string Unique subcategory key (can be hierarchical with dots)
---@field expanded boolean Whether subcategory is expanded (if has children)
---@field subSubCategories? table<string, NavSubSubCategory> Optional sub-subcategories
---@field sortedKeys? string[] Sorted sub-subcategory keys
---@field button? Frame Subcategory button reference
---@field onSelect? function Optional callback when subcategory is selected

---@class NavSubSubCategory
---@field name string Sub-subcategory display name
---@field key string Unique sub-subcategory key
---@field button? Frame Sub-subcategory button reference
---@field onSelect? function Optional callback when sub-subcategory is selected

---@class NavigationTreeConfig
---@field parent Frame Parent frame (usually a left panel)
---@field categories table<string, NavCategory> Categories data structure
---@field onCategoryClick? function Optional global category click handler
---@field onSubCategoryClick? function Optional global subcategory click handler
---@field onSubSubCategoryClick? function Optional global sub-subcategory click handler
---@field activeKey? string Currently selected item key

----------------------------------------------------------------------------------------------------
-- Navigation Tree Creation
----------------------------------------------------------------------------------------------------

---Create a hierarchical navigation tree
---@param config NavigationTreeConfig Navigation tree configuration
---@return Frame scrollFrame The scroll frame containing the tree
---@return Frame treeContainer The tree container frame
---@return table buttons Table storing all created buttons
function LibAT.UI.CreateNavigationTree(config)
	-- Validate configuration
	if not config.parent then
		error('CreateNavigationTree: config.parent is required')
	end
	if not config.categories then
		error('CreateNavigationTree: config.categories is required')
	end

	-- Create scroll frame for navigation tree
	local scrollFrame = CreateFrame('ScrollFrame', nil, config.parent)
	scrollFrame:SetPoint('TOPLEFT', config.parent, 'TOPLEFT', 2, -7)
	scrollFrame:SetPoint('BOTTOMRIGHT', config.parent, 'BOTTOMRIGHT', 0, 2)

	-- Create minimal scrollbar
	scrollFrame.ScrollBar = CreateFrame('EventFrame', nil, scrollFrame, 'MinimalScrollBar')
	scrollFrame.ScrollBar:SetPoint('TOPLEFT', scrollFrame, 'TOPRIGHT', 5, 0)
	scrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', scrollFrame, 'BOTTOMRIGHT', 5, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollFrame.ScrollBar)

	-- Create tree container
	local treeContainer = CreateFrame('Frame', nil, scrollFrame)
	scrollFrame:SetScrollChild(treeContainer)
	treeContainer:SetSize(160, 1)

	-- Store configuration
	scrollFrame.config = config
	scrollFrame.treeContainer = treeContainer
	scrollFrame.categoryButtons = {}
	scrollFrame.subCategoryButtons = {}
	scrollFrame.subSubCategoryButtons = {}

	return scrollFrame, treeContainer, {
		categoryButtons = {},
		subCategoryButtons = {},
		subSubCategoryButtons = {},
	}
end

----------------------------------------------------------------------------------------------------
-- Tree Building Functions
----------------------------------------------------------------------------------------------------

---Take a tree button from the scroll frame's pool; buttons are reused across rebuilds
---@param scrollFrame Frame
---@param treeContainer Frame
---@return Button
local function AcquireNavButton(scrollFrame, treeContainer)
	scrollFrame.buttonPool = scrollFrame.buttonPool or {}
	scrollFrame.poolUsed = (scrollFrame.poolUsed or 0) + 1
	local button = scrollFrame.buttonPool[scrollFrame.poolUsed]
	if not button then
		button = LibAT.UI.CreateFilterButton(treeContainer)
		button.indicator = button:CreateTexture(nil, 'OVERLAY')
		scrollFrame.buttonPool[scrollFrame.poolUsed] = button
	end
	button:ClearAllPoints()
	button.indicator:Hide()
	button.SelectedTexture:Hide()
	button.HighlightTexture:Hide()
	button.Text:SetFontObject(GameFontNormalSmall)
	button:Show()
	return button
end

---Build and display the navigation tree
---@param scrollFrame Frame The scroll frame containing the tree
---@param sortedCategoryKeys? string[] Optional sorted category keys
function LibAT.UI.BuildNavigationTree(scrollFrame, sortedCategoryKeys)
	local config = scrollFrame.config
	if not config then
		error('BuildNavigationTree: scrollFrame missing config')
	end

	local treeContainer = scrollFrame.treeContainer
	local categories = config.categories

	-- Start taking buttons from the front of the pool again
	scrollFrame.buttonPool = scrollFrame.buttonPool or {}
	scrollFrame.poolUsed = 0
	scrollFrame.categoryButtons = {}
	scrollFrame.subCategoryButtons = {}
	scrollFrame.subSubCategoryButtons = {}

	-- Sort categories if not provided
	if not sortedCategoryKeys then
		sortedCategoryKeys = {}
		for categoryKey, _ in pairs(categories) do
			table.insert(sortedCategoryKeys, categoryKey)
		end
		table.sort(sortedCategoryKeys)
	end

	local yOffset = 0
	local buttonHeight = 21

	-- Build tree structure
	for _, categoryKey in ipairs(sortedCategoryKeys) do
		local categoryData = categories[categoryKey]
		local isLeaf = categoryData.isLeaf

		-- Create category button
		local categoryButton = AcquireNavButton(scrollFrame, treeContainer)
		categoryButton:SetPoint('TOPLEFT', treeContainer, 'TOPLEFT', 3, yOffset)

		if isLeaf then
			-- Leaf category: no subcategories, acts as a direct selection button
			local categoryInfo = {
				type = 'category',
				name = categoryData.name,
				categoryIndex = categoryKey,
				isToken = categoryData.isToken or false,
				selected = (config.activeKey == categoryData.key),
			}
			LibAT.UI.SetupFilterButton(categoryButton, categoryInfo)

			-- Override text color for gold category headers
			categoryButton.Text:SetTextColor(1, 0.82, 0)

			-- Leaf category click handler — direct selection
			categoryButton:SetScript('OnClick', function(self)
				config.activeKey = categoryData.key

				-- Call custom handler if provided
				if categoryData.onSelect then
					categoryData.onSelect(categoryKey, categoryData)
				end
				if config.onCategoryClick then
					config.onCategoryClick(categoryKey, categoryData)
				end

				-- Rebuild tree to update selection highlighting
				LibAT.UI.BuildNavigationTree(scrollFrame, sortedCategoryKeys)
			end)
		else
			-- Expandable category with subcategories
			-- Count total items in category
			local subCategoryCount = 0
			if categoryData.subCategories then
				for _, subCategoryData in pairs(categoryData.subCategories) do
					subCategoryCount = subCategoryCount + 1
					if subCategoryData.subSubCategories then
						for _, _ in pairs(subCategoryData.subSubCategories) do
							subCategoryCount = subCategoryCount + 1
						end
					end
				end
			end

			local categoryInfo = {
				type = 'category',
				name = categoryData.name .. ' (' .. subCategoryCount .. ')',
				categoryIndex = categoryKey,
				isToken = categoryData.isToken or false,
				selected = (config.activeKey == categoryKey),
			}
			LibAT.UI.SetupFilterButton(categoryButton, categoryInfo)

			-- Add expand/collapse indicator
			categoryButton.indicator:Show()
			categoryButton.indicator:SetSize(15, 15)
			categoryButton.indicator:SetPoint('LEFT', categoryButton, 'LEFT', 2, 0)
			if categoryData.expanded then
				categoryButton.indicator:SetAtlas('uitools-icon-minimize')
			else
				categoryButton.indicator:SetAtlas('uitools-icon-plus')
			end

			-- Override text color for gold category headers
			categoryButton.Text:SetTextColor(1, 0.82, 0)

			-- Expandable category click handler
			categoryButton:SetScript('OnClick', function(self)
				categoryData.expanded = not categoryData.expanded

				if categoryData.expanded then
					self.indicator:SetAtlas('uitools-icon-minimize')
				else
					self.indicator:SetAtlas('uitools-icon-plus')
				end

				-- Call custom handler if provided
				if categoryData.onSelect then
					categoryData.onSelect(categoryKey, categoryData)
				end
				if config.onCategoryClick then
					config.onCategoryClick(categoryKey, categoryData)
				end

				-- Rebuild tree
				LibAT.UI.BuildNavigationTree(scrollFrame, sortedCategoryKeys)
			end)
		end

		-- Standard hover effects
		categoryButton:SetScript('OnEnter', function(self)
			self.HighlightTexture:Show()
		end)
		categoryButton:SetScript('OnLeave', function(self)
			self.HighlightTexture:Hide()
		end)

		categoryData.button = categoryButton
		table.insert(scrollFrame.categoryButtons, categoryButton)
		yOffset = yOffset - (buttonHeight + 1)

		-- Create subcategories if category is expanded (never for leaf categories)
		if not isLeaf and categoryData.expanded and categoryData.sortedKeys then
			yOffset = LibAT.UI.BuildSubCategories(scrollFrame, treeContainer, categoryData, yOffset, buttonHeight, config, sortedCategoryKeys)
		end
	end

	for i = scrollFrame.poolUsed + 1, #scrollFrame.buttonPool do
		scrollFrame.buttonPool[i]:Hide()
	end

	-- Update tree height
	local totalHeight = math.abs(yOffset) + 20
	treeContainer:SetHeight(math.max(totalHeight, scrollFrame:GetHeight()))
end

---Build subcategories for an expanded category
---@param scrollFrame Frame The scroll frame
---@param treeContainer Frame The tree container
---@param categoryData NavCategory The category data
---@param yOffset number Current Y offset
---@param buttonHeight number Button height
---@param config NavigationTreeConfig The config
---@param sortedCategoryKeys string[] Sorted category keys for rebuilding
---@return number yOffset Updated Y offset
function LibAT.UI.BuildSubCategories(scrollFrame, treeContainer, categoryData, yOffset, buttonHeight, config, sortedCategoryKeys)
	for _, subCategoryKey in ipairs(categoryData.sortedKeys) do
		local subCategoryData = categoryData.subCategories[subCategoryKey]

		-- Create subcategory button
		local subCategoryButton = AcquireNavButton(scrollFrame, treeContainer)
		subCategoryButton:SetPoint('TOPLEFT', treeContainer, 'TOPLEFT', 3, yOffset)

		-- Setup subcategory button styling
		local subCategoryInfo = {
			type = 'subCategory',
			name = subCategoryData.name,
			subCategoryIndex = subCategoryKey,
			selected = (config.activeKey == subCategoryData.key),
		}
		LibAT.UI.SetupFilterButton(subCategoryButton, subCategoryInfo)

		-- Add expand/collapse indicator if has children
		if subCategoryData.subSubCategories and next(subCategoryData.subSubCategories) then
			subCategoryButton.indicator:Show()
			subCategoryButton.indicator:SetSize(12, 12)
			subCategoryButton.indicator:SetPoint('LEFT', subCategoryButton, 'LEFT', 2, 0)
			if subCategoryData.expanded then
				subCategoryButton.indicator:SetAtlas('uitools-icon-minimize')
			else
				subCategoryButton.indicator:SetAtlas('uitools-icon-plus')
			end
		end

		-- Subcategory button click handler
		subCategoryButton:SetScript('OnClick', function(self)
			-- Handle expansion if has children
			if subCategoryData.subSubCategories and next(subCategoryData.subSubCategories) then
				subCategoryData.expanded = not subCategoryData.expanded
				if self.indicator:IsShown() then
					if subCategoryData.expanded then
						self.indicator:SetAtlas('uitools-icon-minimize')
					else
						self.indicator:SetAtlas('uitools-icon-plus')
					end
				end
			else
				-- Select this subcategory
				config.activeKey = subCategoryData.key
			end

			-- Call custom handler if provided
			if subCategoryData.onSelect then
				subCategoryData.onSelect(subCategoryKey, subCategoryData)
			end
			if config.onSubCategoryClick then
				config.onSubCategoryClick(subCategoryKey, subCategoryData)
			end

			-- Rebuild tree
			LibAT.UI.BuildNavigationTree(scrollFrame, sortedCategoryKeys)
		end)

		-- Standard hover effects
		subCategoryButton:SetScript('OnEnter', function(self)
			self.HighlightTexture:Show()
		end)
		subCategoryButton:SetScript('OnLeave', function(self)
			self.HighlightTexture:Hide()
		end)

		table.insert(scrollFrame.subCategoryButtons, subCategoryButton)
		yOffset = yOffset - (buttonHeight + 1)

		-- Create sub-subcategories if expanded
		if subCategoryData.expanded and subCategoryData.sortedKeys then
			yOffset = LibAT.UI.BuildSubSubCategories(scrollFrame, treeContainer, subCategoryData, yOffset, buttonHeight, config, sortedCategoryKeys)
		end
	end

	return yOffset
end

---Build sub-subcategories for an expanded subcategory
---@param scrollFrame Frame The scroll frame
---@param treeContainer Frame The tree container
---@param subCategoryData NavSubCategory The subcategory data
---@param yOffset number Current Y offset
---@param buttonHeight number Button height
---@param config NavigationTreeConfig The config
---@param sortedCategoryKeys string[] Sorted category keys for rebuilding
---@return number yOffset Updated Y offset
function LibAT.UI.BuildSubSubCategories(scrollFrame, treeContainer, subCategoryData, yOffset, buttonHeight, config, sortedCategoryKeys)
	for _, subSubCategoryKey in ipairs(subCategoryData.sortedKeys) do
		local subSubCategoryData = subCategoryData.subSubCategories[subSubCategoryKey]

		-- Create sub-subcategory button
		local subSubCategoryButton = AcquireNavButton(scrollFrame, treeContainer)
		subSubCategoryButton:SetPoint('TOPLEFT', treeContainer, 'TOPLEFT', 3, yOffset)

		-- Setup sub-subcategory button styling
		local subSubCategoryInfo = {
			type = 'subSubCategory',
			name = subSubCategoryData.name,
			subSubCategoryIndex = subSubCategoryKey,
			selected = (config.activeKey == subSubCategoryData.key),
		}
		LibAT.UI.SetupFilterButton(subSubCategoryButton, subSubCategoryInfo)

		-- Sub-subcategory button click handler
		subSubCategoryButton:SetScript('OnClick', function(self)
			config.activeKey = subSubCategoryData.key

			-- Call custom handler if provided
			if subSubCategoryData.onSelect then
				subSubCategoryData.onSelect(subSubCategoryKey, subSubCategoryData)
			end
			if config.onSubSubCategoryClick then
				config.onSubSubCategoryClick(subSubCategoryKey, subSubCategoryData)
			end

			-- Rebuild tree
			LibAT.UI.BuildNavigationTree(scrollFrame, sortedCategoryKeys)
		end)

		-- Standard hover effects
		subSubCategoryButton:SetScript('OnEnter', function(self)
			self.HighlightTexture:Show()
		end)
		subSubCategoryButton:SetScript('OnLeave', function(self)
			self.HighlightTexture:Hide()
		end)

		table.insert(scrollFrame.subSubCategoryButtons, subSubCategoryButton)
		yOffset = yOffset - (buttonHeight + 1)
	end

	return yOffset
end

return LibAT.UI
