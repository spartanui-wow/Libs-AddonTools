---@class LibAT
local LibAT = LibAT

-- Initialize ProfileManager namespace if it doesn't exist
LibAT.ProfileManager = LibAT.ProfileManager or {}

-- This file contains all UI-related code for the ProfileManager system
-- Handles window creation, navigation tree, and mode switching

-- Import shared state (will be set by ProfileManager.lua)
local ProfileManagerState

---Initialize the UI module with shared state from ProfileManager
---@param state table The shared ProfileManager state
function LibAT.ProfileManager.InitUI(state)
	ProfileManagerState = state
end

----------------------------------------------------------------------------------------------------
-- Navigation Tree Functions
----------------------------------------------------------------------------------------------------

---Rebuild the entire navigation tree with current registered addons
local function BuildNavigationTree()
	if not ProfileManagerState.window or not ProfileManagerState.window.NavTree then
		return
	end

	-- Build addon categories
	local addonCategories = ProfileManagerState.BuildAddonCategories()

	-- Combine with settings category
	local allCategories = addonCategories

	-- Add settings at the end
	allCategories['Settings'] = {
		name = 'Settings',
		key = 'Settings',
		expanded = false,
		subCategories = {
			['Options'] = {
				name = 'Options',
				key = 'Settings.Options',
				onSelect = function()
					LibAT:Print('Profile options coming in Phase 2')
				end,
			},
			['Namespaces'] = {
				name = 'Namespace Filter',
				key = 'Settings.Namespaces',
				onSelect = function()
					LibAT:Print('Namespace filtering coming in Phase 2')
				end,
			},
		},
		sortedKeys = { 'Options', 'Namespaces' },
	}

	-- Update navigation tree
	ProfileManagerState.window.NavTree.config.categories = allCategories
	LibAT.UI.BuildNavigationTree(ProfileManagerState.window.NavTree)
end

-- Make this available to ProfileManager.lua for when addons are registered
LibAT.ProfileManager.BuildNavigationTree = BuildNavigationTree

----------------------------------------------------------------------------------------------------
-- Window Management Functions
----------------------------------------------------------------------------------------------------

local function UpdateWindowForMode()
	if not ProfileManagerState.window then
		return
	end

	-- Clear text box
	ProfileManagerState.window.EditBox:SetText('')

	-- Get active addon info for display
	local addonInfo = ''
	if ProfileManagerState.window.activeAddonId and ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId] then
		local addon = ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId]
		addonInfo = ' - ' .. addon.displayName
		if ProfileManagerState.window.activeNamespace then
			addonInfo = addonInfo .. ' (' .. ProfileManagerState.window.activeNamespace .. ')'
		elseif addon.namespaces and #addon.namespaces > 0 then
			addonInfo = addonInfo .. ' (All Namespaces)'
		end
	end

	-- Update mode display
	if ProfileManagerState.window.mode == 'export' then
		ProfileManagerState.window.ModeLabel:SetText('|cff00ff00Export Mode|r' .. addonInfo)
		ProfileManagerState.window.Description:SetText('Click Export to generate profile data, then copy the text below.')
		ProfileManagerState.window.ExportButton:Show()
		ProfileManagerState.window.ImportButton:Hide()
	else
		ProfileManagerState.window.ModeLabel:SetText('|cff00aaffImport Mode|r' .. addonInfo)
		ProfileManagerState.window.Description:SetText('Paste profile data below, then click Import to apply changes.')
		ProfileManagerState.window.ExportButton:Hide()
		ProfileManagerState.window.ImportButton:Show()
	end

	-- Update navigation tree to highlight current selection
	if ProfileManagerState.window.NavTree and ProfileManagerState.window.activeAddonId then
		local navKey = 'Addons.' .. ProfileManagerState.window.activeAddonId .. '.' .. (ProfileManagerState.window.mode == 'export' and 'Export' or 'Import')
		if ProfileManagerState.window.activeNamespace then
			navKey = navKey .. '.' .. ProfileManagerState.window.activeNamespace
		elseif ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId] and ProfileManagerState.registeredAddons[ProfileManagerState.window.activeAddonId].namespaces then
			navKey = navKey .. '.ALL'
		end
		ProfileManagerState.window.NavTree.config.activeKey = navKey
		LibAT.UI.BuildNavigationTree(ProfileManagerState.window.NavTree)
	end

	ProfileManagerState.window:Show()
end

-- Make UpdateWindowForMode available to ProfileManager.lua
LibAT.ProfileManager.UpdateWindowForMode = UpdateWindowForMode

local function CreateWindow()
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
		UpdateWindowForMode()
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
	BuildNavigationTree()

	-- Create right panel for content
	ProfileManagerState.window.RightPanel = LibAT.UI.CreateRightPanel(ProfileManagerState.window.MainContent, ProfileManagerState.window.LeftPanel)

	-- Add description header
	ProfileManagerState.window.Description = LibAT.UI.CreateLabel(ProfileManagerState.window.RightPanel, '', ProfileManagerState.window.RightPanel:GetWidth() - 40)
	ProfileManagerState.window.Description:SetPoint('TOP', ProfileManagerState.window.RightPanel, 'TOP', 0, -10)
	ProfileManagerState.window.Description:SetJustifyH('CENTER')
	ProfileManagerState.window.Description:SetWordWrap(true)

	-- Create scrollable text display for profile data
	ProfileManagerState.window.TextPanel, ProfileManagerState.window.EditBox = LibAT.UI.CreateScrollableTextDisplay(ProfileManagerState.window.RightPanel)
	ProfileManagerState.window.TextPanel:SetPoint('TOPLEFT', ProfileManagerState.window.Description, 'BOTTOMLEFT', 6, -10)
	ProfileManagerState.window.TextPanel:SetPoint('BOTTOMRIGHT', ProfileManagerState.window.RightPanel, 'BOTTOMRIGHT', -6, 50)
	ProfileManagerState.window.EditBox:SetWidth(ProfileManagerState.window.TextPanel:GetWidth() - 20)

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
		LibAT.ProfileManager:DoImport()
	end)

	-- Export button (shown in export mode)
	ProfileManagerState.window.ExportButton = LibAT.UI.CreateButton(ProfileManagerState.window, 100, 22, 'Export')
	ProfileManagerState.window.ExportButton:SetPoint('RIGHT', actionButtons[1], 'LEFT', -5, 0)
	ProfileManagerState.window.ExportButton:SetScript('OnClick', function()
		LibAT.ProfileManager:DoExport()
	end)

	-- Hide window initially
	ProfileManagerState.window:Hide()
end

-- Make CreateWindow available to ProfileManager.lua
LibAT.ProfileManager.CreateWindow = CreateWindow
