---@class LibAT
local LibAT = LibAT

-- DevUI Performance tab: CPU and memory per loaded addon. Sampling only runs while the tab is
-- visible, so leaving it closed costs nothing.

LibAT.DevUI = LibAT.DevUI or {}

local Performance ---@type LibAT.Performance
local T ---@type LibAT.AddonManager.Theme

local REFRESH_SECONDS = 5
local ROW_H = 24
local NUM_W = 74
local MEM_W = 86

local ui = {}
local search = ''
local paused = false

local COLUMNS = {
	{ key = 'title', label = 'Addon' },
	{ key = 'cpuRecent', label = 'CPU now', width = NUM_W, tip = 'Average time per frame over the last few seconds.' },
	{ key = 'cpuSession', label = 'CPU avg', width = NUM_W, tip = 'Average time per frame since you logged in or reloaded.' },
	{ key = 'cpuPeak', label = 'Peak', width = NUM_W, tip = 'The single slowest frame this addon caused.' },
	{ key = 'memory', label = 'Memory', width = MEM_W, tip = 'Memory in use right now.' },
}

---@param ms number|nil
---@return string
local function FormatMs(ms)
	if not ms then
		return '-'
	end
	if ms >= 10 then
		return string.format('%.0f ms', ms)
	elseif ms >= 0.01 then
		return string.format('%.2f ms', ms)
	end
	return '0 ms'
end

---@param kb number
---@return string
local function FormatMemory(kb)
	if kb >= 1024 then
		return string.format('%.1f MB', kb / 1024)
	end
	return string.format('%.0f KB', kb)
end

---@param share number
---@return string
local function FormatShare(share)
	local pct = share * 100
	if pct >= 1 then
		return string.format('%.0f%%', pct)
	end
	return string.format('%.1f%%', pct)
end

----------------------------------------------------------------------------------------------------
-- Rows
----------------------------------------------------------------------------------------------------

local function BuildRow(row)
	row:SetHeight(ROW_H)
	row.stripe = T.Fill(row, { 1, 1, 1, 0.02 }, 'BACKGROUND', 1)
	row.hover = T.Fill(row, T.color.hover, 'BACKGROUND', 2)
	row.hover:Hide()

	row.cells = {}
	local right = -10
	for i = #COLUMNS, 2, -1 do
		local col = COLUMNS[i]
		local cell = T.Text(row, 'meta', T.color.muted)
		cell:SetJustifyH('RIGHT')
		cell:SetWidth(col.width)
		cell:SetPoint('RIGHT', row, 'RIGHT', right, 0)
		right = right - col.width
		row.cells[col.key] = cell
	end
	row.title = T.Text(row, 'body')
	row.title:SetPoint('LEFT', row, 'LEFT', 12, 0)
	row.title:SetPoint('RIGHT', row, 'RIGHT', right - 8, 0)

	row:SetScript('OnEnter', function(self)
		self.hover:Show()
		local sample = self.sample
		if not sample then
			return
		end
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetText(sample.title, 1, 1, 1)
		if sample.title ~= sample.name then
			GameTooltip:AddLine(sample.name, T.color.faint[1], T.color.faint[2], T.color.faint[3])
		end
		if sample.cpuShare then
			GameTooltip:AddDoubleLine('Share of UI time', FormatShare(sample.cpuShare), 0.8, 0.8, 0.8, 1, 1, 1)
		end
		GameTooltip:AddDoubleLine('Memory', FormatMemory(sample.memory), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:AddDoubleLine('Highest memory', FormatMemory(sample.memoryPeak), 0.8, 0.8, 0.8, 1, 1, 1)
		GameTooltip:Show()
	end)
	row:SetScript('OnLeave', function(self)
		self.hover:Hide()
		GameTooltip:Hide()
	end)
	row.built = true
end

local function InitRow(row, data)
	if not row.built then
		BuildRow(row)
	end
	local sample = data.sample
	row.sample = sample
	row.stripe:SetShown(data.index % 2 == 0)
	row.title:SetText(sample.title)
	row.cells.cpuRecent:SetText(FormatMs(sample.cpuRecent))
	row.cells.cpuSession:SetText(FormatMs(sample.cpuSession))
	row.cells.cpuPeak:SetText(FormatMs(sample.cpuPeak))
	row.cells.memory:SetText(FormatMemory(sample.memory))

	-- The sorted column reads in full text color; the rest stay muted
	for key, cell in pairs(row.cells) do
		T.SetColor(cell, key == Performance.DB.sort and T.color.text or T.color.muted)
	end
	if sample.cpuShare and sample.cpuShare >= 0.05 then
		T.SetColor(row.cells.cpuSession, T.color.warn)
	end
end

----------------------------------------------------------------------------------------------------
-- Refresh
----------------------------------------------------------------------------------------------------

local function RefreshHeaders()
	for _, header in ipairs(ui.headers) do
		local active = header.key == Performance.DB.sort
		T.SetColor(header.label, active and T.color.accent or T.color.muted)
		header.arrow:SetShown(active)
		header.arrow:SetRotation(Performance.DB.sortDescending and 0 or math.pi)
	end
end

local function RefreshList()
	local list = Performance.GetSorted(Performance.DB.sort, Performance.DB.sortDescending)
	local needle = search:lower()
	local rows = {}
	for _, sample in ipairs(list) do
		if needle == '' or sample.title:lower():find(needle, 1, true) or sample.name:lower():find(needle, 1, true) then
			rows[#rows + 1] = { sample = sample, index = #rows + 1 }
		end
	end
	ui.scrollBox:SetDataProvider(CreateDataProvider(rows), ScrollBoxConstants.RetainScrollPosition)
	ui.empty:SetShown(#rows == 0)
	if #rows == 0 then
		ui.empty:SetText(needle ~= '' and string.format('No loaded addon matches "%s"', search) or 'No addons are loaded')
	end
end

local function RefreshSummary()
	local memory, loaded, share = Performance.GetTotals()
	local parts = { string.format('%d loaded addons', loaded), FormatMemory(memory) .. ' of memory' }
	if share then
		table.insert(parts, 'addons use ' .. FormatShare(share) .. ' of UI time')
	end
	ui.summary:SetText(table.concat(parts, '  -  '))

	if not Performance.HasProfiler() then
		ui.status:SetText('CPU numbers are not available on this client.')
	elseif paused then
		ui.status:SetText('Paused. Numbers stay as they were.')
	else
		ui.status:SetText(string.format('Updates every %d seconds while this tab is open.', REFRESH_SECONDS))
	end
end

local function Refresh(sample)
	if not ui.root then
		return
	end
	if sample then
		Performance.Sample()
	end
	RefreshHeaders()
	RefreshList()
	RefreshSummary()
end

local function StartTicker()
	if ui.ticker or paused then
		return
	end
	ui.ticker = C_Timer.NewTicker(REFRESH_SECONDS, function()
		if ui.root and ui.root:IsVisible() then
			Refresh(true)
		end
	end)
end

local function StopTicker()
	if ui.ticker then
		ui.ticker:Cancel()
		ui.ticker = nil
	end
end

----------------------------------------------------------------------------------------------------
-- Build
----------------------------------------------------------------------------------------------------

local function BuildContent(contentFrame)
	Performance = LibAT:GetModule('Handler.Performance')
	T = LibAT.UI.Flat

	local root = CreateFrame('Frame', nil, contentFrame)
	root:SetAllPoints(contentFrame)
	root:SetScript('OnHide', StopTicker)
	ui.root = root

	-- Toolbar
	local bar = CreateFrame('Frame', nil, root)
	bar:SetPoint('TOPLEFT', root, 'TOPLEFT', 6, -4)
	bar:SetPoint('TOPRIGHT', root, 'TOPRIGHT', -6, -4)
	bar:SetHeight(26)

	ui.pause = T.TextButton(bar, 'Pause', function(self)
		paused = not paused
		self:SetLabel(paused and 'Resume' or 'Pause')
		if paused then
			StopTicker()
		else
			StartTicker()
			Refresh(true)
		end
		RefreshSummary()
	end)
	ui.pause:SetPoint('RIGHT', bar, 'RIGHT', 0, 0)

	ui.resetPeaks = T.TextButton(bar, 'Reset peaks', function()
		Performance.ResetPeaks()
		Refresh(false)
	end)
	ui.resetPeaks:SetPoint('RIGHT', ui.pause, 'LEFT', -6, 0)
	ui.resetPeaks.tooltip = 'Reset peaks'
	ui.resetPeaks.hint = 'Forget the highest memory seen so far. CPU peaks are kept by the game for the whole session.'

	ui.system = T.Check(bar, 14)
	ui.system:SetPoint('RIGHT', ui.resetPeaks, 'LEFT', -14, 0)
	ui.systemLabel = T.Text(bar, 'meta', T.color.muted)
	ui.systemLabel:SetPoint('RIGHT', ui.system, 'LEFT', -2, 0)
	ui.systemLabel:SetText('Include Blizzard addons')
	ui.system:SetState(Performance.DB.showSystemAddons == true)
	ui.system:SetScript('OnClick', function(self)
		Performance.DB.showSystemAddons = not Performance.DB.showSystemAddons
		self:SetState(Performance.DB.showSystemAddons)
		Refresh(true)
	end)

	ui.search = T.SearchBox(bar, 'Filter loaded addons', function(text)
		search = text
		RefreshList()
	end)
	ui.search:SetPoint('LEFT', bar, 'LEFT', 0, 0)
	ui.search:SetWidth(240)

	-- Table
	local pane = CreateFrame('Frame', nil, root)
	pane:SetPoint('TOPLEFT', bar, 'BOTTOMLEFT', 0, -8)
	pane:SetPoint('BOTTOMRIGHT', root, 'BOTTOMRIGHT', -6, 38)
	T.Fill(pane, T.color.pane)
	T.Border(pane, T.color.line)

	local header = CreateFrame('Frame', nil, pane)
	header:SetPoint('TOPLEFT')
	header:SetPoint('TOPRIGHT')
	header:SetHeight(28)
	T.Fill(header, T.color.header, 'BACKGROUND', 1)
	T.Line(header, 'BOTTOM')

	local scrollBox = CreateFrame('Frame', nil, pane, 'WowScrollBoxList')
	local scrollBar = CreateFrame('EventFrame', nil, pane, 'MinimalScrollBar')
	LibAT.UI.SkinScrollBar(scrollBar)
	scrollBar:SetPoint('TOPRIGHT', header, 'BOTTOMRIGHT', -4, -6)
	scrollBar:SetPoint('BOTTOMRIGHT', pane, 'BOTTOMRIGHT', -4, 6)
	scrollBox:SetPoint('TOPLEFT', header, 'BOTTOMLEFT', 0, 0)
	scrollBox:SetPoint('BOTTOMRIGHT', scrollBar, 'BOTTOMLEFT', -2, -6)
	local view = CreateScrollBoxListLinearView(2, 2, 0, 0, 0)
	view:SetElementExtent(ROW_H)
	view:SetElementInitializer('Button', InitRow)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)
	ui.scrollBox = scrollBox

	-- Column headers line up with the row cells, which sit left of the scroll bar
	ui.headers = {}
	local right = -10 - 16
	for i = #COLUMNS, 1, -1 do
		local col = COLUMNS[i]
		local btn = CreateFrame('Button', nil, header)
		btn.key = col.key
		btn.label = T.Text(btn, 'small', T.color.muted)
		btn.arrow = btn:CreateTexture(nil, 'ARTWORK')
		btn.arrow:SetSize(12, 12)
		T.SetIcon(btn.arrow, 'chevron')
		btn.arrow:SetVertexColor(T.color.accent[1], T.color.accent[2], T.color.accent[3])
		if col.width then
			btn:SetSize(col.width, 28)
			btn:SetPoint('RIGHT', header, 'RIGHT', right, 0)
			right = right - col.width
			btn.label:SetPoint('RIGHT', btn, 'RIGHT', 0, 0)
			btn.arrow:SetPoint('RIGHT', btn.label, 'LEFT', -2, 0)
		else
			btn:SetPoint('TOPLEFT', header, 'TOPLEFT', 0, 0)
			btn:SetPoint('BOTTOMRIGHT', header, 'BOTTOMRIGHT', right - 8, 0)
			btn.label:SetPoint('LEFT', btn, 'LEFT', 12, 0)
			btn.arrow:SetPoint('LEFT', btn.label, 'RIGHT', 2, 0)
		end
		btn.label:SetText(col.label)
		btn.tooltip = col.tip
		btn:SetScript('OnClick', function(self)
			if Performance.DB.sort == self.key then
				Performance.DB.sortDescending = not Performance.DB.sortDescending
			else
				Performance.DB.sort = self.key
				Performance.DB.sortDescending = self.key ~= 'title'
			end
			Refresh(false)
		end)
		btn:SetScript('OnEnter', function(self)
			T.SetColor(self.label, T.color.text)
			if self.tooltip then
				T.ShowTip(self, COLUMNS[i].label, self.tooltip)
			end
		end)
		btn:SetScript('OnLeave', function()
			RefreshHeaders()
			GameTooltip:Hide()
		end)
		table.insert(ui.headers, btn)
	end

	ui.empty = T.Text(pane, 'title', T.color.muted)
	ui.empty:SetPoint('TOP', header, 'BOTTOM', 0, -40)
	ui.empty:Hide()

	-- Footer
	local footer = CreateFrame('Frame', nil, root)
	footer:SetPoint('BOTTOMLEFT', root, 'BOTTOMLEFT', 6, 4)
	footer:SetPoint('BOTTOMRIGHT', root, 'BOTTOMRIGHT', -6, 4)
	footer:SetHeight(28)

	-- In a kit window the status line and Reload UI live in the window's footer
	if LibAT.UI.PlaceInFooter(footer, root) then
		pane:SetPoint('BOTTOMRIGHT', root, 'BOTTOMRIGHT', -6, 6)
	end

	local reload = T.TextButton(footer, 'Reload UI', function()
		LibAT:SafeReloadUI()
	end)
	reload:SetPoint('RIGHT', footer, 'RIGHT', 0, 0)

	ui.summary = T.Text(footer, 'meta', T.color.text)
	ui.summary:SetPoint('TOPLEFT', footer, 'TOPLEFT', 4, -1)
	ui.summary:SetPoint('RIGHT', reload, 'LEFT', -12, 0)
	ui.status = T.Text(footer, 'small', T.color.faint)
	ui.status:SetPoint('TOPLEFT', ui.summary, 'BOTTOMLEFT', 0, -2)
	ui.status:SetPoint('RIGHT', reload, 'LEFT', -12, 0)
end

---@param devUIModule table The DevUI module
---@param state table The DevUI shared state
function LibAT.DevUI.InitPerformance(devUIModule, state)
	state.TabModules[state.GetTabIndex('Performance')] = {
		BuildContent = BuildContent,
		OnActivate = function()
			Refresh(true)
			StartTicker()
		end,
		OnDeactivate = function()
			StopTicker()
		end,
	}
end
