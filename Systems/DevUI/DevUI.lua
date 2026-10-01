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
	TabConfig = nil, ---@type table Reference to TAB_CONFIG for index lookups
}

---Look up a tab's index by its key name
---@param key string The tab key (e.g. 'Logs', 'Errors', 'Macros')
---@return number|nil index The tab index, or nil if not found
local function GetTabIndex(key)
	if not DevUIState.TabConfig then
		return nil
	end
	for i, config in ipairs(DevUIState.TabConfig) do
		if config.key == key then
			return i
		end
	end
	return nil
end

-- Tab definitions
local TAB_CONFIG = {
	{ key = 'Logs', tooltipText = 'Logs', icon = 'Interface\\AddOns\\libsaddontools\\Images\\logs.png' },
	{ key = 'CLI', tooltipText = 'CLI', icon = 'Interface\\AddOns\\libsaddontools\\Images\\cli.png' },
	{ key = 'Macros', tooltipText = 'Macros', icon = 'Interface\\AddOns\\libsaddontools\\Images\\Macros.png' },
	{ key = 'Addons', tooltipText = 'Addon Manager', icon = 'Interface\\AddOns\\libsaddontools\\Images\\Addons.png' },
	{ key = 'Performance', tooltipText = 'Performance', icon = 'Interface\\AddOns\\libsaddontools\\Images\\performance.png' },
}

-- Insert Errors tab only when ErrorDisplay is active (not disabled by BugSack etc.)
if _G.LibATErrorDisplay then
	table.insert(TAB_CONFIG, 3, { key = 'Errors', tooltipText = 'Errors', icon = 'Interface\\AddOns\\libsaddontools\\Images\\errors.png' })
end

DevUIState.TabConfig = TAB_CONFIG
DevUIState.GetTabIndex = GetTabIndex

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
	tab:SetSize(44, 46)
	tab:EnableMouse(true)

	-- Store config — supports both atlas-based and file path-based icons
	tab.activeAtlas = config.activeAtlas
	tab.inactiveAtlas = config.inactiveAtlas
	tab.iconPath = config.icon -- File path (e.g. Interface\\AddOns\\...)
	tab.tooltipText = config.tooltipText
	tab.tabIndex = index

	-- Drawn by the window's kit: a small panel, the accent when selected, a soft glow on hover
	LibAT.UI.Kit:SkinPanel(tab, { elevation = 2, shadow = false })

	tab.Icon = tab:CreateTexture(nil, 'ARTWORK')
	if config.icon then
		tab.Icon:SetTexture(config.icon)
	else
		tab.Icon:SetAtlas(config.inactiveAtlas, false)
	end
	tab.Icon:SetSize(20, 20)
	tab.Icon:SetPoint('CENTER', -2, 0)

	tab.SelectedTexture = tab:CreateTexture(nil, 'BORDER')
	tab.SelectedTexture:SetTexture('Interface\\Buttons\\WHITE8X8')
	tab.SelectedTexture:SetAllPoints()
	tab.SelectedTexture:Hide()

	tab.HighlightTexture = tab:CreateTexture(nil, 'HIGHLIGHT')
	tab.HighlightTexture:SetTexture('Interface\\Buttons\\WHITE8X8')
	tab.HighlightTexture:SetAllPoints()
	tab.HighlightTexture:SetVertexColor(1, 1, 1, 0.06)

	LibAT.UI.Kit:Track(tab, function(owner)
		local r, g, b = LibAT.UI.GetAccentColor()
		owner.SelectedTexture:SetVertexColor(r, g, b, 0.3)
	end)

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

---Tell a tab it is no longer visible so it can stop timers and tracking
---@param tabIndex number|nil
local function DeactivateTab(tabIndex)
	local tabModule = tabIndex and DevUIState.TabModules[tabIndex]
	if tabModule and tabModule.OnDeactivate then
		tabModule.OnDeactivate()
	end
end

---Set the active tab, showing its content and updating tab button states
---@param tabIndex number The tab index to activate
function DevUI.SetActiveTab(tabIndex)
	if tabIndex < 1 or tabIndex > #TAB_CONFIG then
		return
	end

	if DevUIState.ActivatedTab and DevUIState.ActivatedTab ~= tabIndex then
		DeactivateTab(DevUIState.ActivatedTab)
	end
	DevUIState.ActivatedTab = tabIndex
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
		resizable = true,
		minWidth = 600,
		minHeight = 400,
	})

	-- Closing the window (button, Escape or toggle) deactivates the visible tab
	DevUIState.Window:HookScript('OnHide', function()
		DeactivateTab(DevUIState.ActivatedTab)
		DevUIState.ActivatedTab = nil
	end)

	-- Create content frames for each tab
	for i = 1, #TAB_CONFIG do
		local content = CreateFrame('Frame', 'LibAT_DevUI_Content' .. i, DevUIState.Window)
		content:SetAllPoints(DevUIState.Window.Body)
		content:Hide()
		DevUIState.ContentFrames[i] = content
	end

	-- Create side tab buttons
	for i, config in ipairs(TAB_CONFIG) do
		DevUIState.TabButtons[i] = CreateSideTab(DevUIState.Window, i, config)
	end

	-- Build content for each tab module
	for i = 1, #TAB_CONFIG do
		local tabModule = DevUIState.TabModules[i]
		if tabModule and tabModule.BuildContent then
			tabModule.BuildContent(DevUIState.ContentFrames[i])
		end
	end

	-- Set initial active tab
	DevUI.SetActiveTab(DevUIState.ActiveTab)
end

---Show the DevUI window on a specific tab
---@param tabIndex number The tab to show (1-4)
DevUI.GetTabIndex = GetTabIndex

---@param tabIndex number
---@param keepOpen? boolean Do not close the window when this tab is already showing
function DevUI.ShowTab(tabIndex, keepOpen)
	CreateDevUIWindow()

	if not keepOpen and DevUIState.Window:IsShown() and DevUIState.ActiveTab == tabIndex then
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
	monoFont:SetFont('Interface\\AddOns\\libsaddontools\\Fonts\\VeraMono.ttf', 12, '')
	monoFont:SetTextColor(1, 1, 1)
	DevUIState.MonoFont = monoFont

	-- Initialize tab modules with shared state
	LibAT.DevUI = LibAT.DevUI or {}
	LibAT.DevUI.InitLogs(DevUI, DevUIState)
	LibAT.DevUI.InitCLI(DevUI, DevUIState)
	if _G.LibATErrorDisplay then
		LibAT.DevUI.InitErrors(DevUI, DevUIState)
	end
	LibAT.DevUI.InitMacros(DevUI, DevUIState)
	LibAT.DevUI.InitAddonManager(DevUI, DevUIState)
	LibAT.DevUI.InitPerformance(DevUI, DevUIState)
end

function DevUI:OnEnable()
	-- Register slash commands
	SLASH_LIBATDEVLOG1 = '/log'
	SlashCmdList['LIBATDEVLOG'] = function()
		DevUI.ShowTab(GetTabIndex('Logs'))
	end

	SLASH_LIBATDEVLUA1 = '/lua'
	SLASH_LIBATDEVLUA2 = '/cli'
	SlashCmdList['LIBATDEVLUA'] = function()
		DevUI.ShowTab(GetTabIndex('CLI'))
	end

	if GetTabIndex('Errors') then
		SLASH_LIBATDEVERROR1 = '/error'
		SlashCmdList['LIBATDEVERROR'] = function()
			DevUI.ShowTab(GetTabIndex('Errors'))
		end
	end

	SLASH_LIBATDEVMACROS1 = '/macros'
	SlashCmdList['LIBATDEVMACROS'] = function()
		DevUI.ShowTab(GetTabIndex('Macros'))
	end

	SLASH_LIBATDEVADDONS1 = '/addons'
	SlashCmdList['LIBATDEVADDONS'] = function()
		DevUI.ShowTab(GetTabIndex('Addons'))
	end

	SLASH_LIBATDEVPERF1 = '/perf'
	SLASH_LIBATDEVPERF2 = '/performance'
	SlashCmdList['LIBATDEVPERF'] = function()
		DevUI.ShowTab(GetTabIndex('Performance'))
	end
end
