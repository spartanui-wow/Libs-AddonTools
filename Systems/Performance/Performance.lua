---@class LibAT
local LibAT = LibAT

-- Performance: CPU/memory/load time tracking system
-- IMPORTANT: Only active when Performance UI is open to avoid performance drag

local Performance = LibAT:NewModule('Handler.Performance', 'AceEvent-3.0') ---@class LibAT.Performance : AceAddon, AceEvent-3.0
Performance.description = 'Performance profiling for CPU, memory, and load time tracking'

----------------------------------------------------------------------------------------------------
-- Module Lifecycle
----------------------------------------------------------------------------------------------------

function Performance:OnInitialize()
	-- Register database namespace
	local defaults = {
		profile = {
			tracking = {
				enabled = false, -- Only true when UI is open
				updateInterval = 1.0, -- Update metrics every 1 second
				showSystemAddons = false, -- Include Blizzard_ addons
			},
			metrics = {}, -- Current metrics cache
		},
	}
	Performance.Database = LibAT.Database:RegisterNamespace('Performance', defaults)
	Performance.DB = Performance.Database.profile

	-- Register logger category
	if LibAT.InternalLog then
		Performance.logger = LibAT.InternalLog:RegisterCategory('Performance')
	end

	if Performance.logger then
		Performance.logger.info('Performance system initialized (tracking OFF)')
	end
end

function Performance:OnEnable()
	-- Don't start tracking here - wait for UI to open
	if Performance.logger then
		Performance.logger.info('Performance system enabled (tracking OFF)')
	end
end

function Performance:OnDisable()
	-- Stop tracking if active
	Performance.StopTracking()

	if Performance.logger then
		Performance.logger.info('Performance system disabled')
	end
end

----------------------------------------------------------------------------------------------------
-- Tracking Control
----------------------------------------------------------------------------------------------------

---Start performance tracking
function Performance.StartTracking()
	if Performance.DB.tracking.enabled then
		return -- Already tracking
	end

	Performance.DB.tracking.enabled = true

	-- Enable CPU and memory profiling
	ResetCPUUsage()
	UpdateAddOnCPUUsage()
	UpdateAddOnMemoryUsage()

	-- Start update timer
	if not Performance.updateTimer then
		Performance.updateTimer = C_Timer.NewTicker(Performance.DB.tracking.updateInterval, function()
			Performance.UpdateMetrics()
		end)
	end

	if Performance.logger then
		Performance.logger.info('Performance tracking started')
	end
end

---Stop performance tracking
function Performance.StopTracking()
	if not Performance.DB.tracking.enabled then
		return -- Already stopped
	end

	Performance.DB.tracking.enabled = false

	-- Stop update timer
	if Performance.updateTimer then
		Performance.updateTimer:Cancel()
		Performance.updateTimer = nil
	end

	if Performance.logger then
		Performance.logger.info('Performance tracking stopped')
	end
end

---Check if tracking is active
---@return boolean active Whether tracking is active
function Performance.IsTracking()
	return Performance.DB.tracking.enabled or false
end

----------------------------------------------------------------------------------------------------
-- Metrics Collection
----------------------------------------------------------------------------------------------------

---Update all performance metrics
function Performance.UpdateMetrics()
	if not Performance.DB.tracking.enabled then
		return
	end

	-- Update CPU and memory usage
	UpdateAddOnCPUUsage()
	UpdateAddOnMemoryUsage()

	-- Collect metrics for all addons
	local numAddons = C_AddOns and C_AddOns.GetNumAddOns() or GetNumAddOns()

	for i = 1, numAddons do
		local name = (C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo)(i)

		-- Skip if this is a system addon and we're not showing them
		if not Performance.DB.tracking.showSystemAddons and name and name:match('^Blizzard_') then
			-- Skip
		else
			Performance.UpdateAddonMetrics(i, name)
		end
	end
end

---Update metrics for a specific addon
---@param index number Addon index
---@param name string Addon name
function Performance.UpdateAddonMetrics(index, name)
	if not name then
		return
	end

	-- Initialize metrics if needed
	if not Performance.DB.metrics[name] then
		Performance.DB.metrics[name] = {
			cpu = 0,
			memory = 0,
			loadTime = 0,
			calls = 0,
			peak = {
				cpu = 0,
				memory = 0,
			},
		}
	end

	local metrics = Performance.DB.metrics[name]

	-- Get CPU usage (milliseconds)
	local cpu = GetAddOnCPUUsage(index)
	if cpu then
		metrics.cpu = cpu
		metrics.peak.cpu = math.max(metrics.peak.cpu, cpu)
	end

	-- Get memory usage (kilobytes, convert to megabytes)
	local memory = GetAddOnMemoryUsage(index)
	if memory then
		metrics.memory = memory / 1024 -- Convert KB to MB
		metrics.peak.memory = math.max(metrics.peak.memory, metrics.memory)
	end

	-- Load time is captured separately during ADDON_LOADED event
	-- We don't update it here as it's a one-time measurement
end

----------------------------------------------------------------------------------------------------
-- Load Time Tracking
----------------------------------------------------------------------------------------------------

-- Track load times during addon loading
Performance.loadTimes = {}

---Record addon load time
---@param addonName string Addon name
function Performance.RecordLoadTime(addonName)
	if not Performance.loadTimes[addonName] then
		Performance.loadTimes[addonName] = {
			start = debugprofilestop(),
		}
	else
		Performance.loadTimes[addonName].finish = debugprofilestop()
		local loadTime = Performance.loadTimes[addonName].finish - Performance.loadTimes[addonName].start

		-- Store in metrics
		if not Performance.DB.metrics[addonName] then
			Performance.DB.metrics[addonName] = {
				cpu = 0,
				memory = 0,
				loadTime = loadTime,
				calls = 0,
				peak = { cpu = 0, memory = 0 },
			}
		else
			Performance.DB.metrics[addonName].loadTime = loadTime
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Metrics Retrieval
----------------------------------------------------------------------------------------------------

---Get metrics for all addons
---@return table<string, table> metrics Map of addon name to metrics
function Performance.GetAllMetrics()
	return Performance.DB.metrics
end

---Get metrics for a specific addon
---@param addonName string Addon name
---@return table|nil metrics Metrics or nil if not found
function Performance.GetAddonMetrics(addonName)
	return Performance.DB.metrics[addonName]
end

---Get sorted addon list by metric
---@param sortBy string Metric to sort by ('cpu', 'memory', 'loadTime')
---@param descending? boolean Sort descending (default: true)
---@return table[] sorted List of {name, metrics} sorted by metric
function Performance.GetSortedMetrics(sortBy, descending)
	if descending == nil then
		descending = true
	end

	local sorted = {}

	for name, metrics in pairs(Performance.DB.metrics) do
		table.insert(sorted, {
			name = name,
			metrics = metrics,
		})
	end

	table.sort(sorted, function(a, b)
		local aVal = a.metrics[sortBy] or 0
		local bVal = b.metrics[sortBy] or 0

		if descending then
			return aVal > bVal
		else
			return aVal < bVal
		end
	end)

	return sorted
end

---Reset all metrics
function Performance.ResetMetrics()
	wipe(Performance.DB.metrics)
	wipe(Performance.loadTimes)

	-- Reset WoW's internal counters
	ResetCPUUsage()

	if Performance.logger then
		Performance.logger.info('Performance metrics reset')
	end
end

----------------------------------------------------------------------------------------------------
-- Summary Statistics
----------------------------------------------------------------------------------------------------

---Get total CPU/memory usage across all addons
---@return number totalCPU Total CPU in milliseconds
---@return number totalMemory Total memory in megabytes
function Performance.GetTotalUsage()
	local totalCPU = 0
	local totalMemory = 0

	for name, metrics in pairs(Performance.DB.metrics) do
		totalCPU = totalCPU + (metrics.cpu or 0)
		totalMemory = totalMemory + (metrics.memory or 0)
	end

	return totalCPU, totalMemory
end

---Get average metrics
---@return number avgCPU Average CPU per addon
---@return number avgMemory Average memory per addon
function Performance.GetAverageUsage()
	local count = 0
	for _ in pairs(Performance.DB.metrics) do
		count = count + 1
	end

	if count == 0 then
		return 0, 0
	end

	local totalCPU, totalMemory = Performance.GetTotalUsage()
	return totalCPU / count, totalMemory / count
end
