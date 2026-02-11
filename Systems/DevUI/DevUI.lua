---@class LibAT
local LibAT = LibAT

-- DevUI: Tabbed Developer Tools window
-- Provides a consolidated interface with tabs for Logs, CLI, Errors, and Macros

local DevUI = LibAT:NewModule('Handler.DevUI')

-- Shared state passed to all tab files
local DevUIState = {
	Window = nil, ---@type Frame|nil
	TabButtons = {}, ---@type Frame[]
	ContentFrames = {}, ---@type Frame[]
	ActiveTab = 1, ---@type number
	TabModules = {}, ---@type table[]
	MonoFont = nil, ---@type Font|nil
}

-- Tab definitions
local TAB_CONFIG = {
	{ key = 'Logs', tooltipText = 'Logs', icon = 'Interface\\AddOns\\Libs-AddonTools\\Images\\logs.png' },
	{ key = 'CLI', tooltipText = 'CLI', icon = 'Interface\\AddOns\\Libs-AddonTools\\Images\\cli.png' },
	{ key = 'Errors', tooltipText = 'Errors', icon = 'Interface\\AddOns\\Libs-AddonTools\\Images\\errors.png' },
	{ key = 'Macros', tooltipText = 'Macros', icon = 'Interface\\AddOns\\Libs-AddonTools\\Images\\macros.png' },
}

----------------------------------------------------------------------------------------------------
-- Side Tab Creation (Blizzard LargeSideTabButtonTemplate pattern)
----------------------------------------------------------------------------------------------------

---Create a vertical side tab button matching Blizzard's quest log side tab style
---@param parent Frame The window frame to attach to
---@param index number Tab index (1-based)
---@param config table Tab configuration with key, tooltipText, activeAtlas, inactiveAtlas
---@return Frame tab The created tab button frame
local function CreateSideTab(parent, index, config)
	local tab = CreateFrame('Frame', 'LibAT_DevUI_Tab' .. index, parent)
	tab:SetSize(43, 55)
	tab:EnableMouse(true)

	-- Store config — supports both atlas-based and file path-based icons
	tab.activeAtlas = config.activeAtlas
	tab.inactiveAtlas = config.inactiveAtlas
	tab.iconPath = config.icon -- File path (e.g. Interface\\AddOns\\...)
	tab.tooltipText = config.tooltipText
	tab.tabIndex = index

	-- BACKGROUND: Tab shape
	tab.Background = tab:CreateTexture(nil, 'BACKGROUND')
	tab.Background:SetAtlas('questlog-tab-side', true)
	tab.Background:SetPoint('CENTER')

	-- ARTWORK: Icon (scaled down from native atlas size)
	tab.Icon = tab:CreateTexture(nil, 'ARTWORK')
	if config.icon then
		tab.Icon:SetTexture(config.icon)
	else
		tab.Icon:SetAtlas(config.inactiveAtlas, false)
	end
	tab.Icon:SetSize(20, 20)
	tab.Icon:SetPoint('CENTER', -2, 0)

	-- OVERLAY: Selected glow
	tab.SelectedTexture = tab:CreateTexture(nil, 'OVERLAY')
	tab.SelectedTexture:SetAtlas('QuestLog-Tab-side-Glow-select', true)
	tab.SelectedTexture:SetPoint('CENTER')
	tab.SelectedTexture:Hide()

	-- HIGHLIGHT: Hover glow
	tab.HighlightTexture = tab:CreateTexture(nil, 'HIGHLIGHT')
	tab.HighlightTexture:SetAtlas('QuestLog-Tab-side-Glow-hover', true)
	tab.HighlightTexture:SetPoint('CENTER')

	-- Anchoring: first tab at TOPRIGHT of window, subsequent tabs stack vertically
	-- Tabs sit at a lower frame level so they appear to come out from under the window edge
	tab:SetFrameLevel(parent:GetFrameLevel() - 1)
	if index == 1 then
		tab:SetPoint('TOPLEFT', parent, 'TOPRIGHT', 0, -28)
	else
		tab:SetPoint('TOP', DevUIState.TabButtons[index - 1], 'BOTTOM', 0, -3)
	end

	-- SetChecked method: swap icon and toggle selected glow
	---@param checked boolean
	function tab:SetChecked(checked)
		if self.iconPath then
			-- File path icon — just resize, no atlas swap needed
			self.Icon:SetSize(checked and 22 or 20, checked and 22 or 20)
		else
			-- Atlas-based icon — swap between active/inactive atlas
			if checked then
				self.Icon:SetAtlas(self.activeAtlas, false)
				self.Icon:SetSize(22, 22)
			else
				self.Icon:SetAtlas(self.inactiveAtlas, false)
				self.Icon:SetSize(20, 20)
			end
		end
		self.Icon:SetDesaturated(not checked)
		self.Icon:SetAlpha(checked and 1 or 0.6)
		self.SelectedTexture:SetShown(checked)
	end

	-- Mouse interaction (SidePanelTabButtonMixin pattern)
	tab:SetScript('OnMouseDown', function(self, button)
		if button == 'LeftButton' then
			self.Icon:SetPoint('CENTER', -1, -1)
		end
	end)

	tab:SetScript('OnMouseUp', function(self, button)
		self.Icon:SetPoint('CENTER', -2, 0)
		if button == 'LeftButton' then
			PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
			DevUI.SetActiveTab(self.tabIndex)
		end
	end)

	tab:SetScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT', -4, -4)
		GameTooltip:SetText(self.tooltipText)
		GameTooltip:Show()
	end)

	tab:SetScript('OnLeave', function()
		GameTooltip:Hide()
	end)

	return tab
end

----------------------------------------------------------------------------------------------------
-- Window and Tab Management
----------------------------------------------------------------------------------------------------

---Set the active tab, showing its content and updating tab button states
---@param tabIndex number The tab index to activate (1-4)
function DevUI.SetActiveTab(tabIndex)
	if tabIndex < 1 or tabIndex > #TAB_CONFIG then
		return
	end

	DevUIState.ActiveTab = tabIndex

	-- Show/hide content frames
	for i, content in ipairs(DevUIState.ContentFrames) do
		content:SetShown(i == tabIndex)
	end

	-- Update tab button states
	for i, tab in ipairs(DevUIState.TabButtons) do
		tab:SetChecked(i == tabIndex)
	end

	-- Update window title
	if DevUIState.Window then
		DevUIState.Window:SetTitle("Lib's Developer UI - " .. TAB_CONFIG[tabIndex].key)
	end

	-- Notify the tab module to refresh
	if DevUIState.TabModules[tabIndex] and DevUIState.TabModules[tabIndex].OnActivate then
		DevUIState.TabModules[tabIndex].OnActivate()
	end
end

---Create the main DevUI window with tabs and content frames
local function CreateDevUIWindow()
	if DevUIState.Window then
		return
	end

	-- Create base window
	DevUIState.Window = LibAT.UI.CreateWindow({
		name = 'LibAT_DevUIWindow',
		title = "Lib's Developer UI",
		width = 800,
		height = 538,
	})

	-- Hide the ButtonFrameTemplate's built-in Inset NineSlice — tabs provide their own panel styling
	if DevUIState.Window.Inset then
		DevUIState.Window.Inset:Hide()
	end

	-- Create content frames for each tab
	for i = 1, #TAB_CONFIG do
		local content = CreateFrame('Frame', 'LibAT_DevUI_Content' .. i, DevUIState.Window)
		content:SetPoint('TOPLEFT', DevUIState.Window, 'TOPLEFT', 2, -33)
		content:SetPoint('BOTTOMRIGHT', DevUIState.Window, 'BOTTOMRIGHT', -2, 2)
		content:Hide()
		DevUIState.ContentFrames[i] = content
	end

	-- Create side tab buttons
	for i, config in ipairs(TAB_CONFIG) do
		DevUIState.TabButtons[i] = CreateSideTab(DevUIState.Window, i, config)
	end

	-- Build content for each tab module
	for i, tabModule in ipairs(DevUIState.TabModules) do
		if tabModule.BuildContent then
			tabModule.BuildContent(DevUIState.ContentFrames[i])
		end
	end

	-- Set initial active tab
	DevUI.SetActiveTab(DevUIState.ActiveTab)
end

---Show the DevUI window on a specific tab
---@param tabIndex number The tab to show (1-4)
function DevUI.ShowTab(tabIndex)
	CreateDevUIWindow()

	if DevUIState.Window:IsShown() and DevUIState.ActiveTab == tabIndex then
		-- Toggle off if already showing this tab
		DevUIState.Window:Hide()
	else
		DevUI.SetActiveTab(tabIndex)
		DevUIState.Window:Show()
	end
end

----------------------------------------------------------------------------------------------------
-- Module Lifecycle
----------------------------------------------------------------------------------------------------

function DevUI:OnInitialize()
	-- Register DB namespace
	local defaults = {
		profile = {
			cli = {
				savedScripts = {},
				lastScript = nil,
			},
			errors = {
				showLocals = true,
			},
			macros = {},
			window = {},
		},
	}
	DevUI.Database = LibAT.Database:RegisterNamespace('DevUI', defaults)
	DevUI.DB = DevUI.Database.profile

	-- Create monospace font object
	local monoFont = CreateFont('LibAT_MonoFont')
	monoFont:SetFont('Interface\\AddOns\\Libs-AddonTools\\Fonts\\VeraMono.ttf', 12, '')
	monoFont:SetTextColor(1, 1, 1)
	DevUIState.MonoFont = monoFont

	-- Initialize tab modules with shared state
	LibAT.DevUI = LibAT.DevUI or {}
	LibAT.DevUI.InitLogs(DevUI, DevUIState)
	LibAT.DevUI.InitCLI(DevUI, DevUIState)
	LibAT.DevUI.InitErrors(DevUI, DevUIState)
	LibAT.DevUI.InitMacros(DevUI, DevUIState)
end

function DevUI:OnEnable()
	-- Register slash commands
	SLASH_LIBATDEVLOG1 = '/log'
	SlashCmdList['LIBATDEVLOG'] = function()
		DevUI.ShowTab(1)
	end

	SLASH_LIBATDEVLUA1 = '/lua'
	SLASH_LIBATDEVLUA2 = '/cli'
	SlashCmdList['LIBATDEVLUA'] = function()
		DevUI.ShowTab(2)
	end

	SLASH_LIBATDEVERROR1 = '/error'
	SlashCmdList['LIBATDEVERROR'] = function()
		DevUI.ShowTab(3)
	end

	SLASH_LIBATDEVMACROS1 = '/macros'
	SlashCmdList['LIBATDEVMACROS'] = function()
		DevUI.ShowTab(4)
	end
end
