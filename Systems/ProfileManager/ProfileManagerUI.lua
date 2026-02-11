---@class LibAT
local LibAT = LibAT

-- Initialize ProfileManager namespace
---@class LibAT.ProfileManager
LibAT.ProfileManager = LibAT:NewModule('Handler.ProfileManager')
local ProfileManager = LibAT.ProfileManager

-- This file contains all UI-related code for the ProfileManager system
-- Handles window creation, navigation tree, and mode switching

-- Import shared state (will be set by ProfileManager.lua)
local ProfileManagerState

---Initialize the UI module with shared state from ProfileManager
---@param state table The shared ProfileManager state
function ProfileManager.InitUI(state)
	ProfileManagerState = state
end

----------------------------------------------------------------------------------------------------
-- Navigation Tree Functions
----------------------------------------------------------------------------------------------------

---Rebuild the entire navigation tree with current registered addons
function ProfileManager.BuildNavigationTree()
	if not ProfileManagerState.window or not ProfileManagerState.window.NavTree then
		return
	end

	-- Build addon categories
	local addonCategories = ProfileManagerState.BuildAddonCategories()

	-- Update navigation tree
	ProfileManagerState.window.NavTree.config.categories = addonCategories
	LibAT.UI.BuildNavigationTree(ProfileManagerState.window.NavTree)
end

----------------------------------------------------------------------------------------------------
-- Window Management Functions
----------------------------------------------------------------------------------------------------

---Update the import destination dropdown with profiles from the selected addon
local function UpdateImportDestDropdown()
	local win = ProfileManagerState.window
	if not win or not win.ImportDestDropdown then
		return
	end

	-- Reset destination to current profile
	win.importDestination = nil
	win.NewProfileInput:Hide()
	win.NewProfileInput:SetText('')

	-- Get the current profile key for display
	local currentProfileKey = 'Default'
	if win.activeAddonId and ProfileManagerState.registeredAddons[win.activeAddonId] then
		local addon = ProfileManagerState.registeredAddons[win.activeAddonId]
		if addon.db and addon.db.keys and addon.db.keys.profile then
			currentProfileKey = addon.db.keys.profile
		end
	end

	win.ImportDestDropdown:SetText('Current Profile (' .. currentProfileKey .. ')')

	-- Setup the menu with profile choices
	if win.ImportDestDropdown.SetupMenu then
		win.ImportDestDropdown:SetupMenu(function(owner, rootDescription)
			-- Current profile option
			rootDescription:CreateButton('Current Profile (' .. currentProfileKey .. ')', function()
				win.importDestination = nil
				win.ImportDestDropdown:SetText('Current Profile (' .. currentProfileKey .. ')')
				win.NewProfileInput:Hide()
			end)

			-- Existing profiles from the addon's DB
			if win.activeAddonId and ProfileManagerState.registeredAddons[win.activeAddonId] then
				local addon = ProfileManagerState.registeredAddons[win.activeAddonId]
				if addon.db and addon.db.sv and addon.db.sv.profiles then
					local sortedProfiles = {}
					for profileName in pairs(addon.db.sv.profiles) do
						if profileName ~= currentProfileKey then
							table.insert(sortedProfiles, profileName)
						end
					end
					table.sort(sortedProfiles)

					for _, profileName in ipairs(sortedProfiles) do
						rootDescription:CreateButton(profileName, function()
							win.importDestination = profileName
							win.ImportDestDropdown:SetText(profileName)
							win.NewProfileInput:Hide()
						end)
					end
				end
			end

			-- Create New option
			rootDescription:CreateButton('|cff00ff00Create New...|r', function()
				win.importDestination = '__NEW__'
				win.ImportDestDropdown:SetText('New Profile:')
				win.NewProfileInput:Show()
				win.NewProfileInput:SetFocus()
			end)
		end)
	end
end

function ProfileManager.UpdateWindowForMode()
	if not ProfileManagerState.window then
		return
	end

	-- Clear text box (EditBox may not exist if window hasn't been fully created)
	if ProfileManagerState.window.EditBox then
		ProfileManagerState.window.EditBox:SetText('')
	end

	-- Get active addon info for display
	local addonInfo = ''
	local sectionName = ''
	local isComposite = false
	if ProfileManagerState.window.activeAddonId and ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId] then
		local addon = ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId]
		local activeNS = ProfileManagerState.window.activeNamespace
		addonInfo = ' - ' .. addon.displayName
		if activeNS == '__COMPOSITE__' then
			isComposite = true
			addonInfo = addonInfo .. ' (Composite)'
			sectionName = addon.displayName .. ' Composite'
		elseif activeNS == '__COREDB__' then
			addonInfo = addonInfo .. ' (Core DB)'
			sectionName = addon.displayName .. ' Core DB'
		elseif activeNS then
			addonInfo = addonInfo .. ' (' .. activeNS .. ')'
			sectionName = addon.displayName .. ' ' .. activeNS
		else
			addonInfo = addonInfo .. ' (All)'
			sectionName = addon.displayName
		end
	end

	-- Update mode display
	if ProfileManagerState.window.mode == 'export' then
		ProfileManagerState.window.ModeLabel:SetText('|cff00ff00Export Mode|r' .. addonInfo)

		-- In export mode: show action button, hide text area initially
		if ProfileManagerState.window.activeAddonId then
			ProfileManagerState.window.Description:SetText('')
			ProfileManagerState.window.Description:Hide()

			if ProfileManagerState.window.ExportActionButton then
				if isComposite then
					ProfileManagerState.window.ExportActionButton:SetText('Export Composite Profile')
				else
					ProfileManagerState.window.ExportActionButton:SetText('Export ' .. sectionName)
				end
				ProfileManagerState.window.ExportActionButton:Show()
			end

			-- Hide the text panel until export is generated
			if ProfileManagerState.window.TextPanel then
				ProfileManagerState.window.TextPanel:Hide()
			end
		else
			ProfileManagerState.window.Description:SetText('Select a section from the left panel to export.')
			ProfileManagerState.window.Description:Show()
			if ProfileManagerState.window.ExportActionButton then
				ProfileManagerState.window.ExportActionButton:Hide()
			end
		end

		-- Hide import destination dropdown in export mode
		if ProfileManagerState.window.ImportDestFrame then
			ProfileManagerState.window.ImportDestFrame:Hide()
		end

		-- Hide bottom action bar import/export buttons (action is on the centered button now)
		ProfileManagerState.window.ExportButton:Hide()
		ProfileManagerState.window.ImportButton:Hide()
	else
		ProfileManagerState.window.ModeLabel:SetText('|cff00aaffImport Mode|r' .. addonInfo)
		ProfileManagerState.window.Description:SetText('Paste profile data below, then click Import to apply changes.')
		ProfileManagerState.window.Description:Show()

		-- In import mode: hide export action button, show text area
		if ProfileManagerState.window.ExportActionButton then
			ProfileManagerState.window.ExportActionButton:Hide()
		end
		if ProfileManagerState.window.TextPanel then
			ProfileManagerState.window.TextPanel:Show()
		end

		-- Show import destination dropdown only when an addon is selected and namespace is Core DB or nil (profile-level import)
		local activeNS = ProfileManagerState.window.activeNamespace
		if ProfileManagerState.window.ImportDestFrame and ProfileManagerState.window.activeAddonId and (activeNS == '__COREDB__' or activeNS == nil) then
			ProfileManagerState.window.ImportDestFrame:Show()
			UpdateImportDestDropdown()
		elseif ProfileManagerState.window.ImportDestFrame then
			ProfileManagerState.window.ImportDestFrame:Hide()
		end

		ProfileManagerState.window.ExportButton:Hide()
		ProfileManagerState.window.ImportButton:Show()
	end

	-- Update navigation tree to highlight current selection
	if ProfileManagerState.window.NavTree and ProfileManagerState.window.activeAddonId then
		local addonId = ProfileManagerState.window.activeAddonId
		local navKey
		-- Check if this addon is currently a leaf category in the tree
		local categories = ProfileManagerState.window.NavTree.config.categories
		if categories[addonId] and categories[addonId].isLeaf then
			navKey = 'Addons.' .. addonId
		else
			navKey = 'Addons.' .. addonId .. '.' .. (ProfileManagerState.window.activeNamespace or 'ALL')
		end
		ProfileManagerState.window.NavTree.config.activeKey = navKey
		LibAT.UI.BuildNavigationTree(ProfileManagerState.window.NavTree)
	end

	ProfileManagerState.window:Show()
end

----------------------------------------------------------------------------------------------------
-- Composite Export/Import UI
----------------------------------------------------------------------------------------------------

---Show composite export window with component selection checkboxes
---@param compositeId string The composite ID to export
function ProfileManager:ShowCompositeExport(compositeId)
	-- Get composite definition
	local composite = self:GetComposite(compositeId)
	if not composite then
		LibAT:Print('|cffff0000Error:|r Composite "' .. compositeId .. '" is not registered')
		return
	end

	-- Create window with component selection
	local selectionWindow = LibAT.UI.CreateWindow({
		name = 'LibAT_CompositeExportWindow',
		title = 'Export ' .. composite.displayName,
		width = 500,
		height = 400,
		layout = 'list',
	})

	-- Add description
	local desc = selectionWindow:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
	desc:SetPoint('TOPLEFT', 15, -15)
	desc:SetPoint('TOPRIGHT', -15, -15)
	desc:SetJustifyH('LEFT')
	desc:SetText('Select components to include in your profile export:')

	-- Create scrollable frame for checkboxes
	local scrollFrame = CreateFrame('ScrollFrame', nil, selectionWindow, 'UIPanelScrollFrameTemplate')
	scrollFrame:SetPoint('TOPLEFT', desc, 'BOTTOMLEFT', 0, -10)
	scrollFrame:SetPoint('BOTTOMRIGHT', -35, 50)

	local contentFrame = CreateFrame('Frame', nil, scrollFrame)
	contentFrame:SetSize(scrollFrame:GetWidth(), 1)
	scrollFrame:SetScrollChild(contentFrame)

	-- Track checkbox states
	local checkboxes = {}
	local yOffset = 0

	-- Primary addon (always checked, disabled)
	local primaryAddon = ProfileManagerState.registeredAddons[composite.primaryAddonId]
	local primaryCheckbox = LibAT.UI.CreateCheckbox(contentFrame, primaryAddon.displayName .. ' (always included)')
	primaryCheckbox:SetPoint('TOPLEFT', 5, yOffset)
	primaryCheckbox:SetChecked(true)
	primaryCheckbox:SetEnabled(false)
	yOffset = yOffset - 30

	-- Optional components
	for _, component in ipairs(composite.components) do
		local available = component.isAvailable()
		local label = component.displayName
		if not available then
			label = label .. ' |cff888888(not available)|r'
		end

		local checkbox = LibAT.UI.CreateCheckbox(contentFrame, label)
		checkbox:SetPoint('TOPLEFT', 5, yOffset)
		checkbox:SetChecked(available)
		checkbox:SetEnabled(available)
		checkboxes[component.id] = checkbox
		yOffset = yOffset - 30
	end

	contentFrame:SetHeight(math.abs(yOffset))

	-- Export button
	local exportButton = LibAT.UI.CreateButton(selectionWindow, 120, 30, 'Export Profile')
	exportButton:SetPoint('BOTTOM', 0, 15)
	exportButton:SetScript('OnClick', function()
		-- Collect selected components
		local selectedComponents = {}
		for componentId, checkbox in pairs(checkboxes) do
			if checkbox:GetChecked() then
				selectedComponents[componentId] = true
			end
		end

		-- Create composite export
		local exportData, err = self:CreateCompositeExport(compositeId, selectedComponents)
		if not exportData then
			LibAT:Print('|cffff0000Export failed:|r ' .. tostring(err))
			return
		end

		-- Encode to base64
		local encoded, encodeErr = ProfileManager.EncodeData(exportData)
		if not encoded then
			LibAT:Print('|cffff0000Export failed:|r ' .. tostring(encodeErr))
			return
		end

		-- Build header
		local header = '-- ' .. composite.displayName .. ' Export\n'
		header = header .. '-- Generated: ' .. exportData.timestamp .. '\n'
		header = header .. '-- Version: ' .. exportData.version .. ' (Composite Format)\n'
		header = header .. '-- Includes: '
		local includeList = {}
		for componentId in pairs(exportData.included) do
			if componentId == composite.primaryAddonId then
				table.insert(includeList, primaryAddon.displayName)
			else
				for _, comp in ipairs(composite.components) do
					if comp.id == componentId then
						table.insert(includeList, comp.displayName)
						break
					end
				end
			end
		end
		header = header .. table.concat(includeList, ', ') .. '\n\n'

		local exportString = header .. encoded

		-- Show result window
		local resultWindow = LibAT.UI.CreateWindow({
			name = 'LibAT_CompositeExportResult',
			title = 'Composite Export - ' .. composite.displayName,
			width = 600,
			height = 450,
		})

		local resultPanel, resultEditBox = LibAT.UI.CreateScrollableTextDisplay(resultWindow)
		resultPanel:SetPoint('TOPLEFT', resultWindow, 'TOPLEFT', 10, -10)
		resultPanel:SetPoint('BOTTOMRIGHT', resultWindow, 'BOTTOMRIGHT', -10, 50)

		resultEditBox:SetText(exportString)
		resultEditBox:SetCursorPosition(0)
		resultEditBox:HighlightText(0)

		local closeButton = LibAT.UI.CreateButton(resultWindow, 100, 30, 'Close')
		closeButton:SetPoint('BOTTOM', 0, 15)
		closeButton:SetScript('OnClick', function()
			resultWindow:Hide()
		end)

		resultWindow:Show()
		selectionWindow:Hide()

		LibAT:Print('|cff00ff00Composite profile exported!|r Select all (Ctrl+A) and copy (Ctrl+C).')
	end)

	selectionWindow:Show()
end

---Show composite import window with confirmation dialog
---@param encodedData string The base64-encoded composite data
function ProfileManager:ShowCompositeImport(encodedData)
	-- Decode data
	local compositeData, decodeErr = ProfileManager.DecodeData(encodedData)
	if not compositeData then
		LibAT:Print('|cffff0000Import failed:|r ' .. tostring(decodeErr))
		return
	end

	-- Analyze composite
	local analysis = self:AnalyzeComposite(compositeData)
	if not analysis or not analysis.valid then
		LibAT:Print('|cffff0000Import failed:|r ' .. (analysis and analysis.error or 'Invalid composite format'))
		return
	end

	-- Create confirmation window
	local confirmWindow = LibAT.UI.CreateWindow({
		name = 'LibAT_CompositeImportConfirm',
		title = 'Import ' .. analysis.compositeName,
		width = 500,
		height = 450,
	})

	-- Warning text
	local warning = confirmWindow:CreateFontString(nil, 'OVERLAY', 'GameFontNormalLarge')
	warning:SetPoint('TOP', 0, -15)
	warning:SetText('|cffff9900This will import the following:|r')

	-- Scrollable component list
	local scrollFrame = CreateFrame('ScrollFrame', nil, confirmWindow, 'UIPanelScrollFrameTemplate')
	scrollFrame:SetPoint('TOPLEFT', warning, 'BOTTOMLEFT', 0, -10)
	scrollFrame:SetPoint('BOTTOMRIGHT', -35, 80)

	local contentFrame = CreateFrame('Frame', nil, scrollFrame)
	contentFrame:SetSize(scrollFrame:GetWidth(), 1)
	scrollFrame:SetScrollChild(contentFrame)

	local yOffset = 0

	for _, component in ipairs(analysis.components) do
		local color = component.available and '|cff00ff00' or '|cff888888'
		local status = component.available and '' or ' (not installed, will be skipped)'

		local text = contentFrame:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
		text:SetPoint('TOPLEFT', 5, yOffset)
		text:SetJustifyH('LEFT')
		text:SetText(color .. component.name .. status .. '|r')

		yOffset = yOffset - 25
	end

	contentFrame:SetHeight(math.abs(yOffset))

	-- Overwrite warning
	local overwriteWarning = confirmWindow:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	overwriteWarning:SetPoint('BOTTOM', 0, 55)
	overwriteWarning:SetText('|cffff0000This will overwrite your current settings!|r')

	-- Buttons
	local buttonFrame = CreateFrame('Frame', nil, confirmWindow)
	buttonFrame:SetPoint('BOTTOM', 0, 15)
	buttonFrame:SetSize(250, 30)

	local importButton = LibAT.UI.CreateButton(buttonFrame, 110, 30, 'Import')
	importButton:SetPoint('LEFT', 0, 0)
	importButton:SetScript('OnClick', function()
		-- Perform import
		local success, results = self:ImportComposite(compositeData)

		if success then
			LibAT:Print('|cff00ff00Successfully imported ' .. results.successCount .. ' component(s).|r Please /reload to apply changes.')
		else
			LibAT:Print('|cffff0000Import completed with errors.|r')
			if results.successCount > 0 then
				LibAT:Print('|cff00ff00' .. results.successCount .. ' component(s) imported successfully.|r')
			end
			if results.errorCount > 0 then
				LibAT:Print('|cffff0000' .. results.errorCount .. ' component(s) failed to import.|r')
			end
		end

		confirmWindow:Hide()
	end)

	local cancelButton = LibAT.UI.CreateButton(buttonFrame, 110, 30, 'Cancel')
	cancelButton:SetPoint('RIGHT', 0, 0)
	cancelButton:SetScript('OnClick', function()
		confirmWindow:Hide()
	end)

	confirmWindow:Show()
end

function ProfileManager.CreateWindow()
	-- Create base window using LibAT.UI
	ProfileManagerState.window = LibAT.UI.CreateWindow({
		name = 'LibAT_ProfileWindow',
		title = '|cffffffffLib|cffe21f1fAT|r Profile Manager',
		width = 800,
		height = 538,
		portrait = 'Interface\\AddOns\\Libs-AddonTools\\Logo-Icon',
	})

	ProfileManagerState.window.mode = 'import'
	ProfileManagerState.window.activeAddonId = nil -- Currently selected addon ID
	ProfileManagerState.window.activeNamespace = nil -- Currently selected namespace (nil = all)

	-- Create control frame (top bar)
	ProfileManagerState.window.ControlFrame = LibAT.UI.CreateControlFrame(ProfileManagerState.window)

	-- Add mode label (shows current mode)
	ProfileManagerState.window.ModeLabel = LibAT.UI.CreateHeader(ProfileManagerState.window.ControlFrame, 'Import Mode')
	ProfileManagerState.window.ModeLabel:SetPoint('LEFT', ProfileManagerState.window.ControlFrame, 'LEFT', 10, 0)

	-- Add switch mode button (centered, 20% larger than original 100px)
	ProfileManagerState.window.SwitchModeButton = LibAT.UI.CreateButton(ProfileManagerState.window.ControlFrame, 120, 22, 'Switch Mode')
	ProfileManagerState.window.SwitchModeButton:SetPoint('CENTER', ProfileManagerState.window.ControlFrame, 'CENTER', 0, 0)
	ProfileManagerState.window.SwitchModeButton:SetScript('OnClick', function()
		ProfileManagerState.window.mode = ProfileManagerState.window.mode == 'import' and 'export' or 'import'
		ProfileManager.UpdateWindowForMode()
	end)

	-- Add Expert Mode checkbox (top-right, default off)
	ProfileManagerState.window.expertMode = false
	ProfileManagerState.window.ExpertModeCheckbox = LibAT.UI.CreateCheckbox(ProfileManagerState.window.ControlFrame, 'Expert Mode')
	ProfileManagerState.window.ExpertModeCheckbox:SetPoint('RIGHT', ProfileManagerState.window.ControlFrame, 'RIGHT', -10, 0)
	ProfileManagerState.window.ExpertModeCheckbox:SetChecked(false)
	ProfileManagerState.window.ExpertModeCheckbox.checkbox:SetScript('OnClick', function(self)
		ProfileManagerState.window.expertMode = self:GetChecked()
		-- Rebuild navigation tree to show/hide namespace subcategories
		ProfileManager.BuildNavigationTree()
	end)

	-- Create main content area
	ProfileManagerState.window.MainContent = LibAT.UI.CreateContentFrame(ProfileManagerState.window, ProfileManagerState.window.ControlFrame)

	-- Create left panel for navigation
	ProfileManagerState.window.LeftPanel = LibAT.UI.CreateLeftPanel(ProfileManagerState.window.MainContent)

	-- Initialize navigation tree with registered addons
	ProfileManagerState.window.NavTree = LibAT.UI.CreateNavigationTree({
		parent = ProfileManagerState.window.LeftPanel,
		categories = {},
		activeKey = nil,
	})

	-- Build initial navigation tree
	ProfileManager.BuildNavigationTree()

	-- Create right panel for content
	ProfileManagerState.window.RightPanel = LibAT.UI.CreateRightPanel(ProfileManagerState.window.MainContent, ProfileManagerState.window.LeftPanel)

	-- Allow clicking anywhere in the right panel to focus the editbox
	ProfileManagerState.window.RightPanel:EnableMouse(true)
	ProfileManagerState.window.RightPanel:SetScript('OnMouseDown', function()
		if ProfileManagerState.window.TextPanel and ProfileManagerState.window.TextPanel:IsShown() and ProfileManagerState.window.EditBox then
			ProfileManagerState.window.EditBox:SetFocus()
		end
	end)

	-- Add description header
	ProfileManagerState.window.Description = LibAT.UI.CreateLabel(ProfileManagerState.window.RightPanel, '')
	ProfileManagerState.window.Description:SetPoint('TOP', ProfileManagerState.window.RightPanel, 'TOP', 0, -10)
	ProfileManagerState.window.Description:SetPoint('LEFT', ProfileManagerState.window.RightPanel, 'LEFT', 20, 0)
	ProfileManagerState.window.Description:SetPoint('RIGHT', ProfileManagerState.window.RightPanel, 'RIGHT', -20, 0)
	ProfileManagerState.window.Description:SetJustifyH('CENTER')
	ProfileManagerState.window.Description:SetWordWrap(true)

	-- Create export action button (centered, shown in export mode)
	ProfileManagerState.window.ExportActionButton = LibAT.UI.CreateButton(ProfileManagerState.window.RightPanel, 250, 40, 'Export')
	ProfileManagerState.window.ExportActionButton:SetPoint('CENTER', ProfileManagerState.window.RightPanel, 'CENTER', 0, 0)
	ProfileManagerState.window.ExportActionButton:SetScript('OnClick', function()
		ProfileManager:DoExport()
	end)
	ProfileManagerState.window.ExportActionButton:Hide()

	-- Create import destination container (label + dropdown, shown in import mode only)
	local importDestFrame = CreateFrame('Frame', nil, ProfileManagerState.window.RightPanel)
	importDestFrame:SetSize(500, 40)
	importDestFrame:SetPoint('TOPLEFT', ProfileManagerState.window.Description, 'BOTTOMLEFT', 0, -4)
	ProfileManagerState.window.ImportDestFrame = importDestFrame

	local destLabel = importDestFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	destLabel:SetPoint('LEFT', importDestFrame, 'LEFT', 0, 0)
	destLabel:SetText('Import to:')
	destLabel:SetTextColor(1, 0.82, 0)

	ProfileManagerState.window.ImportDestDropdown = LibAT.UI.CreateDropdown(importDestFrame, 'Current Profile', 220, 22)
	ProfileManagerState.window.ImportDestDropdown:SetPoint('LEFT', destLabel, 'RIGHT', 8, 0)
	ProfileManagerState.window.importDestination = nil -- nil = current profile

	-- New profile name input (hidden by default, shown when "Create New..." is selected)
	ProfileManagerState.window.NewProfileInput = CreateFrame('EditBox', nil, importDestFrame, 'InputBoxTemplate')
	ProfileManagerState.window.NewProfileInput:SetSize(150, 22)
	ProfileManagerState.window.NewProfileInput:SetPoint('LEFT', ProfileManagerState.window.ImportDestDropdown, 'RIGHT', 8, 0)
	ProfileManagerState.window.NewProfileInput:SetAutoFocus(false)
	ProfileManagerState.window.NewProfileInput:SetFontObject('GameFontHighlightSmall')
	ProfileManagerState.window.NewProfileInput:SetScript('OnEscapePressed', ProfileManagerState.window.NewProfileInput.ClearFocus)
	ProfileManagerState.window.NewProfileInput:Hide()

	importDestFrame:Hide()

	-- Create scrollable text display for profile data
	-- Anchor to the RightPanel directly so the editbox fills the full width
	ProfileManagerState.window.TextPanel, ProfileManagerState.window.EditBox = LibAT.UI.CreateScrollableTextDisplay(ProfileManagerState.window.RightPanel)
	ProfileManagerState.window.TextPanel:SetPoint('TOPLEFT', ProfileManagerState.window.RightPanel, 'TOPLEFT', 6, -60)
	ProfileManagerState.window.TextPanel:SetPoint('BOTTOMRIGHT', ProfileManagerState.window.RightPanel, 'BOTTOMRIGHT', -6, 15)
	ProfileManagerState.window.EditBox:SetWidth(ProfileManagerState.window.TextPanel:GetWidth() - 20)

	-- Move the right pane scrollbar further right to avoid overlapping the panel edge
	ProfileManagerState.window.TextPanel.ScrollBar:ClearAllPoints()
	ProfileManagerState.window.TextPanel.ScrollBar:SetPoint('TOPLEFT', ProfileManagerState.window.TextPanel, 'TOPRIGHT', 12, 0)
	ProfileManagerState.window.TextPanel.ScrollBar:SetPoint('BOTTOMLEFT', ProfileManagerState.window.TextPanel, 'BOTTOMRIGHT', 12, 0)

	-- Create action buttons
	local actionButtons = LibAT.UI.CreateActionButtons(ProfileManagerState.window, {
		{
			text = 'Clear',
			width = 70,
			onClick = function()
				ProfileManagerState.window.EditBox:SetText('')
			end,
		},
		{
			text = 'Close',
			width = 70,
			onClick = function()
				ProfileManagerState.window:Hide()
			end,
		},
	})

	-- Import button (shown in import mode)
	ProfileManagerState.window.ImportButton = LibAT.UI.CreateButton(ProfileManagerState.window, 100, 22, 'Import')
	ProfileManagerState.window.ImportButton:SetPoint('RIGHT', actionButtons[1], 'LEFT', -5, 0)
	ProfileManagerState.window.ImportButton:SetScript('OnClick', function()
		ProfileManager:DoImport()
	end)

	-- Export button (shown in export mode)
	ProfileManagerState.window.ExportButton = LibAT.UI.CreateButton(ProfileManagerState.window, 100, 22, 'Export')
	ProfileManagerState.window.ExportButton:SetPoint('RIGHT', actionButtons[1], 'LEFT', -5, 0)
	ProfileManagerState.window.ExportButton:SetScript('OnClick', function()
		ProfileManager:DoExport()
	end)

	-- Hide window initially
	ProfileManagerState.window:Hide()
end
