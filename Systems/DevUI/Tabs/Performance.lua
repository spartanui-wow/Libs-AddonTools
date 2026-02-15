---@class LibAT
local LibAT = LibAT

-- DevUI Performance Tab: CPU/memory/load time profiling
-- IMPORTANT: Only starts tracking when tab is active to avoid performance drag

LibAT.DevUI = LibAT.DevUI or {}

local DevUI, DevUIState
local Performance -- Reference to Performance module

-- Forward declarations
local BuildContent
local RefreshMetricsDisplay
local StartTracking
local StopTracking

-- Tab-local state
local TabState = {
	ContentFrame = nil,
	WarningLabel = nil,
	SortDropdown = nil,
	RefreshButton = nil,
	ResetButton = nil,
	ScrollFrame = nil,
	MetricsDisplay = nil,
	TotalLabel = nil,
	AutoRefresh = nil,
	ShowSystemAddons = nil,

	CurrentSortMode = 'cpu', -- cpu, memory, loadTime, name
	SortDescending = true,
	AutoRefreshEnabled = true,
	AutoRefreshTimer = nil,
	ColumnHeaders = {},
}

---Initialize the Performance tab
---@param devUIModule table The DevUI module
---@param state table The DevUI shared state
function LibAT.DevUI.InitPerformance(devUIModule, state)
	DevUI = devUIModule
	DevUIState = state

	-- Get Performance module reference
	Performance = LibAT:GetModule('Handler.Performance')

	-- Register this tab with DevUI (tab index 6)
	DevUIState.TabModules[6] = {
		BuildContent = BuildContent,
		OnActivate = function()
			-- START tracking when tab becomes visible
			StartTracking()
			RefreshMetricsDisplay()
		end,
		OnDeactivate = function()
			-- STOP tracking when tab is hidden (unless Keep Enabled is checked)
			if not TabState.KeepTrackingEnabled then
				StopTracking()
			end
		end,
	}
end

----------------------------------------------------------------------------------------------------
-- Build Content
----------------------------------------------------------------------------------------------------

function BuildContent(contentFrame)
	local L = LibAT.L or {}
	TabState.ContentFrame = contentFrame

	-- Tracking info bar
	local infoBar = CreateFrame('Frame', nil, contentFrame)
	infoBar:SetPoint('TOP', contentFrame, 'TOP', 0, -8)
	infoBar:SetSize(400, 24)

	-- Info label
	local infoLabel = infoBar:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	infoLabel:SetPoint('LEFT', infoBar, 'LEFT', 0, 0)
	infoLabel:SetText('Tracking only active while tab is open')
	infoLabel:SetTextColor(1, 0.82, 0) -- Gold color

	-- Keep Enabled checkbox
	local keepEnabledCheck = CreateFrame('CheckButton', nil, infoBar, 'UICheckButtonTemplate')
	keepEnabledCheck:SetPoint('LEFT', infoLabel, 'RIGHT', 8, 0)
	keepEnabledCheck:SetSize(20, 20)
	keepEnabledCheck:SetChecked(false)
	keepEnabledCheck:SetScript('OnClick', function(self)
		TabState.KeepTrackingEnabled = self:GetChecked()
		if TabState.KeepTrackingEnabled then
			infoLabel:SetText('Tracking will remain active')
			infoLabel:SetTextColor(0, 1, 0) -- Green
		else
			infoLabel:SetText('Tracking only active while tab is open')
			infoLabel:SetTextColor(1, 0.82, 0) -- Gold
		end
	end)

	local keepEnabledLabel = infoBar:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	keepEnabledLabel:SetPoint('LEFT', keepEnabledCheck, 'RIGHT', 4, 0)
	keepEnabledLabel:SetText('Keep Enabled')

	TabState.WarningLabel = infoLabel
	TabState.KeepTrackingEnabled = false

	-- Control bar
	local controlBar = CreateFrame('Frame', nil, contentFrame)
	controlBar:SetPoint('TOP', infoBar, 'BOTTOM', 0, -8)
	controlBar:SetPoint('LEFT', contentFrame, 'LEFT', 8, 0)
	controlBar:SetPoint('RIGHT', contentFrame, 'RIGHT', -8, 0)
	controlBar:SetHeight(30)

	-- Refresh button (left)
	local refreshBtn = LibAT.UI.CreateButton(controlBar, 80, 24, L['Refresh'] or 'Refresh')
	refreshBtn:SetPoint('LEFT', controlBar, 'LEFT', 0, 0)
	refreshBtn:SetScript('OnClick', function()
		RefreshMetricsDisplay()
	end)
	TabState.RefreshButton = refreshBtn

	-- Reset button
	local resetBtn = LibAT.UI.CreateButton(controlBar, 120, 24, 'Reset Counters')
	resetBtn:SetPoint('LEFT', refreshBtn, 'RIGHT', 4, 0)
	resetBtn:SetScript('OnClick', function()
		if Performance then
			Performance.ResetMetrics()
			RefreshMetricsDisplay()
		end
	end)
	TabState.ResetButton = resetBtn

	-- Background for metrics area
	local metricsBg = CreateFrame('Frame', nil, contentFrame, 'BackdropTemplate')
	metricsBg:SetPoint('TOPLEFT', controlBar, 'BOTTOMLEFT', 0, -8)
	metricsBg:SetPoint('BOTTOMRIGHT', contentFrame, 'BOTTOMRIGHT', -20, 40) -- Leave space for footer
	metricsBg:SetBackdrop({
		bgFile = 'Interface\\Buttons\\WHITE8x8',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border',
		tile = true,
		tileSize = 16,
		edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	metricsBg:SetBackdropColor(0, 0, 0, 0.4)
	metricsBg:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

	-- Scroll frame for metrics
	local scrollFrame = CreateFrame('ScrollFrame', nil, metricsBg)
	scrollFrame:SetPoint('TOPLEFT', metricsBg, 'TOPLEFT', 2, -4)
	scrollFrame:SetPoint('BOTTOMRIGHT', metricsBg, 'BOTTOMRIGHT', 0, 2)

	scrollFrame.ScrollBar = CreateFrame('EventFrame', nil, scrollFrame, 'MinimalScrollBar')
	scrollFrame.ScrollBar:SetPoint('TOPLEFT', scrollFrame, 'TOPRIGHT', 6, 0)
	scrollFrame.ScrollBar:SetPoint('BOTTOMLEFT', scrollFrame, 'BOTTOMRIGHT', 6, 0)
	ScrollUtil.InitScrollFrameWithScrollBar(scrollFrame, scrollFrame.ScrollBar)

	local scrollChild = CreateFrame('Frame', nil, scrollFrame)
	scrollFrame:SetScrollChild(scrollChild)
	scrollChild:SetSize(scrollFrame:GetWidth(), 1)

	TabState.ScrollFrame = scrollFrame
	TabState.MetricsDisplay = scrollChild

	-- Build metrics header
	BuildMetricsHeader(scrollChild)

	-- Footer panel (no background)
	local footer = CreateFrame('Frame', nil, contentFrame)
	footer:SetPoint('BOTTOMLEFT', contentFrame, 'BOTTOMLEFT', 4, 4)
	footer:SetPoint('BOTTOMRIGHT', contentFrame, 'BOTTOMRIGHT', -4, 4)
	footer:SetHeight(32)

	-- Reload UI button (bottom left, BLACK button like other tabs)
	local reloadBtn = LibAT.UI.CreateButton(footer, 80, 20, 'Reload UI', true)
	reloadBtn:SetPoint('LEFT', footer, 'LEFT', 0, 0)
	reloadBtn:SetScript('OnClick', function()
		LibAT:SafeReloadUI()
	end)

	-- Total label (left of center)
	local totalLabel = footer:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
	totalLabel:SetPoint('LEFT', reloadBtn, 'RIGHT', 16, 0)
	totalLabel:SetText('Total: 0 ms CPU | 0 MB Memory')
	TabState.TotalLabel = totalLabel

	-- Options (right side of footer)
	local autoRefreshCheck = CreateFrame('CheckButton', nil, footer, 'UICheckButtonTemplate')
	autoRefreshCheck:SetPoint('RIGHT', footer, 'RIGHT', -8, 0)
	autoRefreshCheck:SetSize(20, 20)
	autoRefreshCheck:SetChecked(TabState.AutoRefreshEnabled)
	autoRefreshCheck:SetScript('OnClick', function(self)
		TabState.AutoRefreshEnabled = self:GetChecked()
		if TabState.AutoRefreshEnabled then
			StartAutoRefresh()
		else
			StopAutoRefresh()
		end
	end)

	local autoRefreshLabel = footer:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	autoRefreshLabel:SetPoint('RIGHT', autoRefreshCheck, 'LEFT', -4, 0)
	autoRefreshLabel:SetText('Auto-refresh every 5s')

	-- Show system addons checkbox
	local showSystemCheck = CreateFrame('CheckButton', nil, footer, 'UICheckButtonTemplate')
	showSystemCheck:SetPoint('RIGHT', autoRefreshLabel, 'LEFT', -20, 0)
	showSystemCheck:SetSize(20, 20)
	showSystemCheck:SetChecked(Performance and Performance.DB.tracking.showSystemAddons or false)
	showSystemCheck:SetScript('OnClick', function(self)
		if Performance then
			Performance.DB.tracking.showSystemAddons = self:GetChecked()
			RefreshMetricsDisplay()
		end
	end)

	local showSystemLabel = footer:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	showSystemLabel:SetPoint('RIGHT', showSystemCheck, 'LEFT', -4, 0)
	showSystemLabel:SetText('Show system addons')
end

function BuildMetricsHeader(parent)
	local header = CreateFrame('Frame', nil, parent, 'BackdropTemplate')
	header:SetPoint('TOPLEFT', parent, 'TOPLEFT', 0, 0)
	header:SetSize(parent:GetWidth(), 24)
	header:SetBackdrop({
		bgFile = 'Interface\\Buttons\\WHITE8x8',
	})
	header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

	-- Helper function to create sortable column header buttons
	local function CreateColumnButton(xPos, width, label, sortMode)
		local btn = CreateFrame('Button', nil, header)
		btn:SetSize(width, 22)
		btn:SetPoint('LEFT', header, 'LEFT', xPos, 0)

		btn.text = btn:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		btn.text:SetPoint('LEFT', btn, 'LEFT', 4, 0)
		btn.text:SetText(label)
		btn.text:SetJustifyH('LEFT')

		btn.indicator = btn:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		btn.indicator:SetPoint('RIGHT', btn, 'RIGHT', -4, 0)
		btn.indicator:SetText('')

		btn:SetScript('OnClick', function()
			if TabState.CurrentSortMode == sortMode then
				-- Toggle direction (not implemented yet, just refresh)
				TabState.SortDescending = not TabState.SortDescending
			else
				TabState.CurrentSortMode = sortMode
				TabState.SortDescending = true
			end
			UpdateColumnHeaders()
			RefreshMetricsDisplay()
		end)

		btn:SetScript('OnEnter', function(self)
			self:SetAlpha(0.7)
		end)
		btn:SetScript('OnLeave', function(self)
			self:SetAlpha(1.0)
		end)

		return btn
	end

	-- Column header buttons
	TabState.ColumnHeaders = {
		name = CreateColumnButton(8, 250, 'Addon Name', 'name'),
		cpu = CreateColumnButton(260, 75, 'CPU (ms)', 'cpu'),
		memory = CreateColumnButton(340, 105, 'Memory (MB)', 'memory'),
		loadTime = CreateColumnButton(450, 85, 'Load (ms)', 'loadTime'),
	}

	-- Initial sort indicator
	UpdateColumnHeaders()
end

function UpdateColumnHeaders()
	if not TabState.ColumnHeaders then
		return
	end

	-- Clear all indicators
	for _, header in pairs(TabState.ColumnHeaders) do
		header.indicator:SetText('')
	end

	-- Set indicator on active column
	local activeHeader = TabState.ColumnHeaders[TabState.CurrentSortMode]
	if activeHeader then
		if TabState.SortDescending then
			activeHeader.indicator:SetText('|cffFFFF00\\/ |r') -- Down arrow (descending)
		else
			activeHeader.indicator:SetText('|cffFFFF00/\\ |r') -- Up arrow (ascending)
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Metrics Display
----------------------------------------------------------------------------------------------------

function RefreshMetricsDisplay()
	if not Performance or not TabState.MetricsDisplay then
		return
	end

	local scrollChild = TabState.MetricsDisplay

	-- Clear existing rows (except header)
	local children = { scrollChild:GetChildren() }
	for i = 2, #children do -- Skip first child (header)
		children[i]:Hide()
		children[i]:SetParent(nil)
	end

	-- Get sorted metrics with current sort direction
	local sorted = Performance.GetSortedMetrics(TabState.CurrentSortMode, TabState.SortDescending)

	-- Create rows
	local yOffset = -28 -- Start below header
	for i, entry in ipairs(sorted) do
		local row = CreateFrame('Frame', nil, scrollChild, 'BackdropTemplate')
		row:SetPoint('TOPLEFT', scrollChild, 'TOPLEFT', 0, yOffset)
		row:SetSize(scrollChild:GetWidth(), 20)

		-- Alternating background
		if i % 2 == 0 then
			row:SetBackdrop({ bgFile = 'Interface\\Buttons\\WHITE8x8' })
			row:SetBackdropColor(0.05, 0.05, 0.05, 0.5)
		end

		-- Addon name (fixed width column)
		local nameText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		nameText:SetPoint('LEFT', row, 'LEFT', 8, 0)
		nameText:SetText(entry.name)
		nameText:SetJustifyH('LEFT')
		nameText:SetWidth(250)

		-- CPU (absolute positioning to match header)
		local cpuText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		cpuText:SetPoint('LEFT', row, 'LEFT', 260, 0)
		cpuText:SetText(string.format('%.2f', entry.metrics.cpu or 0))
		cpuText:SetJustifyH('LEFT')

		-- Memory (absolute positioning to match header)
		local memText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		memText:SetPoint('LEFT', row, 'LEFT', 340, 0)
		memText:SetText(string.format('%.2f', entry.metrics.memory or 0))
		memText:SetJustifyH('LEFT')

		-- Load time (absolute positioning to match header)
		local loadText = row:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
		loadText:SetPoint('LEFT', row, 'LEFT', 450, 0)
		loadText:SetText(string.format('%.2f', entry.metrics.loadTime or 0))
		loadText:SetJustifyH('LEFT')

		yOffset = yOffset - 22
	end

	-- Update scroll height
	scrollChild:SetHeight(math.abs(yOffset) + 4)

	-- Update total label
	if TabState.TotalLabel then
		local totalCPU, totalMemory = Performance.GetTotalUsage()
		TabState.TotalLabel:SetText(string.format('Total: %.2f ms CPU | %.2f MB Memory', totalCPU, totalMemory))
	end
end

----------------------------------------------------------------------------------------------------
-- Sort Menu
----------------------------------------------------------------------------------------------------

function ShowSortMenu(anchorFrame)
	local menu = CreateFrame('Frame', 'LibAT_Performance_SortMenu', UIParent, 'UIDropDownMenuTemplate')
	UIDropDownMenu_Initialize(menu, function(self, level)
		local info = UIDropDownMenu_CreateInfo()

		-- CPU
		info.text = 'CPU'
		info.func = function()
			TabState.CurrentSortMode = 'cpu'
			TabState.SortDropdown:SetText('CPU')
			RefreshMetricsDisplay()
			CloseDropDownMenus()
		end
		info.checked = (TabState.CurrentSortMode == 'cpu')
		UIDropDownMenu_AddButton(info, level)

		-- Memory
		info = UIDropDownMenu_CreateInfo()
		info.text = 'Memory'
		info.func = function()
			TabState.CurrentSortMode = 'memory'
			TabState.SortDropdown:SetText('Memory')
			RefreshMetricsDisplay()
			CloseDropDownMenus()
		end
		info.checked = (TabState.CurrentSortMode == 'memory')
		UIDropDownMenu_AddButton(info, level)

		-- Load Time
		info = UIDropDownMenu_CreateInfo()
		info.text = 'Load Time'
		info.func = function()
			TabState.CurrentSortMode = 'loadTime'
			TabState.SortDropdown:SetText('Load Time')
			RefreshMetricsDisplay()
			CloseDropDownMenus()
		end
		info.checked = (TabState.CurrentSortMode == 'loadTime')
		UIDropDownMenu_AddButton(info, level)
	end, 'MENU')

	ToggleDropDownMenu(1, nil, menu, anchorFrame, 0, 0)
end

----------------------------------------------------------------------------------------------------
-- Tracking Control
----------------------------------------------------------------------------------------------------

function StartTracking()
	if Performance then
		Performance.StartTracking()
	end

	-- Start auto-refresh if enabled
	if TabState.AutoRefreshEnabled then
		StartAutoRefresh()
	end
end

function StopTracking()
	if Performance then
		Performance.StopTracking()
	end

	-- Stop auto-refresh
	StopAutoRefresh()
end

function StartAutoRefresh()
	if TabState.AutoRefreshTimer then
		return -- Already running
	end

	TabState.AutoRefreshTimer = C_Timer.NewTicker(5, function()
		RefreshMetricsDisplay()
	end)
end

function StopAutoRefresh()
	if TabState.AutoRefreshTimer then
		TabState.AutoRefreshTimer:Cancel()
		TabState.AutoRefreshTimer = nil
	end
end
