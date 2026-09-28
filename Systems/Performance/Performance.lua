---@class LibAT
local LibAT = LibAT

-- Performance: per-addon CPU and memory sampling. Nothing runs until the Performance tab asks
-- for a sample, and all samples live in memory only; the database holds preferences.

local Performance = LibAT:NewModule('Handler.Performance', 'AceEvent-3.0') ---@class LibAT.Performance : AceAddon, AceEvent-3.0
Performance.description = 'Per-addon CPU and memory usage'

---@class LibAT.Performance.Sample
---@field name string Folder name
---@field title string Title without color codes
---@field memory number KB
---@field memoryPeak number Highest KB seen since the last reset
---@field cpuRecent number|nil ms per frame, recent average
---@field cpuSession number|nil ms per frame, session average
---@field cpuPeak number|nil Longest single frame in ms
---@field cpuShare number|nil Share of UI time this session (0-1)

---@type LibAT.Performance.Sample[]
Performance.samples = {}
Performance.lastSample = 0

local memoryPeaks = {}
local titles = {}
local lastMemoryUpdate = 0
local MEMORY_INTERVAL = 5

function Performance:OnInitialize()
	local defaults = {
		profile = {
			showSystemAddons = false,
			sort = 'cpuRecent',
			sortDescending = true,
		},
	}
	Performance.Database = LibAT.Database:RegisterNamespace('Performance', defaults)
	Performance.DB = Performance.Database.profile

	-- Older versions saved live tracking state and every sample; keep the preference, drop the rest
	local legacy = Performance.DB.tracking
	if type(legacy) == 'table' then
		if legacy.showSystemAddons ~= nil then
			Performance.DB.showSystemAddons = legacy.showSystemAddons
		end
		Performance.DB.tracking = nil
	end
	Performance.DB.metrics = nil

	if LibAT.InternalLog then
		Performance.logger = LibAT.InternalLog:RegisterCategory('Performance')
	end
end

----------------------------------------------------------------------------------------------------
-- Sampling
----------------------------------------------------------------------------------------------------

---@return boolean
function Performance.HasProfiler()
	return C_AddOnProfiler ~= nil and C_AddOnProfiler.IsEnabled ~= nil and C_AddOnProfiler.IsEnabled() and Enum ~= nil and Enum.AddOnProfilerMetric ~= nil
end

---@param name string
---@param metric number
---@return number
local function Metric(name, metric)
	return C_AddOnProfiler.GetAddOnMetric(name, metric) or 0
end

---@param index number
---@param name string
---@return string
local function TitleOf(index, name)
	if not titles[name] then
		local title = C_AddOns.GetAddOnTitle and C_AddOns.GetAddOnTitle(index) or select(2, C_AddOns.GetAddOnInfo(index))
		title = (title or name):gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[^:]*:', ''):gsub('|r', ''):gsub('|T.-|t', ''):gsub('|A.-|a', '')
		title = strtrim(title)
		titles[name] = title ~= '' and title or name
	end
	return titles[name]
end

---Take a fresh sample of every loaded addon. Memory is refreshed at most every few seconds and is
---skipped in combat, where the full heap walk would cause a hitch.
---@param force? boolean Refresh memory now, even in combat
function Performance.Sample(force)
	local now = GetTime()
	if force or (not InCombatLockdown() and now - lastMemoryUpdate >= MEMORY_INTERVAL) then
		lastMemoryUpdate = now
		UpdateAddOnMemoryUsage()
	end

	local profiler = Performance.HasProfiler()
	local metrics = profiler and Enum.AddOnProfilerMetric
	local appSession, overallSession = 0, 0
	if profiler then
		appSession = C_AddOnProfiler.GetApplicationMetric(metrics.SessionAverageTime) or 0
		overallSession = C_AddOnProfiler.GetOverallMetric(metrics.SessionAverageTime) or 0
	end

	local showSystem = Performance.DB.showSystemAddons
	local samples = Performance.samples
	wipe(samples)

	for i = 1, C_AddOns.GetNumAddOns() do
		local name, _, _, _, _, security = C_AddOns.GetAddOnInfo(i)
		if name and C_AddOns.IsAddOnLoaded(i) and (showSystem or security ~= 'SECURE') then
			local memory = GetAddOnMemoryUsage(i) or 0
			memoryPeaks[name] = math.max(memoryPeaks[name] or 0, memory)

			---@type LibAT.Performance.Sample
			local sample = {
				name = name,
				title = TitleOf(i, name),
				memory = memory,
				memoryPeak = memoryPeaks[name],
			}
			if profiler then
				sample.cpuRecent = Metric(name, metrics.RecentAverageTime)
				sample.cpuSession = Metric(name, metrics.SessionAverageTime)
				sample.cpuPeak = Metric(name, metrics.PeakTime)
				local relative = appSession - overallSession + sample.cpuSession
				sample.cpuShare = relative > 0 and sample.cpuSession / relative or 0
			end
			samples[#samples + 1] = sample
		end
	end
	Performance.lastSample = now
end

---Totals for the summary line
---@return number memoryKB
---@return number loaded Number of loaded addons sampled
---@return number|nil addonShare Share of UI time spent in all addons this session (0-1)
function Performance.GetTotals()
	local memory = 0
	for _, sample in ipairs(Performance.samples) do
		memory = memory + sample.memory
	end
	local share
	if Performance.HasProfiler() then
		local metric = Enum.AddOnProfilerMetric.SessionAverageTime
		local app = C_AddOnProfiler.GetApplicationMetric(metric) or 0
		if app > 0 then
			share = (C_AddOnProfiler.GetOverallMetric(metric) or 0) / app
		end
	end
	return memory, #Performance.samples, share
end

---Samples sorted by a field. Ties fall back to the title so rows do not jump between refreshes.
---@param field string title|cpuRecent|cpuSession|cpuPeak|memory
---@param descending boolean
---@return LibAT.Performance.Sample[]
function Performance.GetSorted(field, descending)
	local list = {}
	for i, sample in ipairs(Performance.samples) do
		list[i] = sample
	end
	table.sort(list, function(a, b)
		if field ~= 'title' then
			local av, bv = a[field] or 0, b[field] or 0
			if av ~= bv then
				if descending then
					return av > bv
				end
				return av < bv
			end
		end
		local at, bt = a.title:lower(), b.title:lower()
		if field == 'title' and descending then
			return at > bt
		end
		return at < bt
	end)
	return list
end

---Forget the highest memory values seen so far
function Performance.ResetPeaks()
	wipe(memoryPeaks)
	for _, sample in ipairs(Performance.samples) do
		memoryPeaks[sample.name] = sample.memory
		sample.memoryPeak = sample.memory
	end
end
