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
	if ProfileManagerState.window.activeAddonId and ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId] then
		local addon = ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId]
		local activeNS = ProfileManagerState.window.activeNamespace
		addonInfo = ' - ' .. addon.displayName
		if activeNS == '__COREDB__' then
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
				ProfileManagerState.window.ExportActionButton:SetText('Export ' .. sectionName)
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
		local navKey = 'Addons.' .. ProfileManagerState.window.activeAddonId .. '.' .. (ProfileManagerState.window.activeNamespace or 'ALL')
		ProfileManagerState.window.NavTree.config.activeKey = navKey
		LibAT.UI.BuildNavigationTree(ProfileManagerState.window.NavTree)
	end

	ProfileManagerState.window:Show()
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

	-- Add switch mode button
	ProfileManagerState.window.SwitchModeButton = LibAT.UI.CreateButton(ProfileManagerState.window.ControlFrame, 100, 22, 'Switch Mode')
	ProfileManagerState.window.SwitchModeButton:SetPoint('RIGHT', ProfileManagerState.window.ControlFrame, 'RIGHT', -10, 0)
	ProfileManagerState.window.SwitchModeButton:SetScript('OnClick', function()
		ProfileManagerState.window.mode = ProfileManagerState.window.mode == 'import' and 'export' or 'import'
		ProfileManager.UpdateWindowForMode()
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
