---@class LibAT
local LibAT = LibAT

-- Type Definitions for Performance System

----------------------------------------------------------------------------------------------------
-- Performance Module
----------------------------------------------------------------------------------------------------

---@class LibAT.Performance : AceAddon, AceEvent-3.0
---@field description string
---@field Database AceDB Database object
---@field DB LibAT.Performance.DBProfile Profile data
---@field logger LoggerObject Logger instance
---@field updateTimer table|nil C_Timer ticker
---@field loadTimes table<string, table> Load time tracking data
---@field StartTracking fun() Start performance tracking
---@field StopTracking fun() Stop performance tracking
---@field IsTracking fun(): boolean Check if tracking is active
---@field UpdateMetrics fun() Update all performance metrics
---@field UpdateAddonMetrics fun(index: number, name: string) Update metrics for specific addon
---@field RecordLoadTime fun(addonName: string) Record addon load time
---@field GetAllMetrics fun(): table<string, LibAT.Performance.Metrics> Get all metrics
---@field GetAddonMetrics fun(addonName: string): LibAT.Performance.Metrics|nil Get metrics for addon
---@field GetSortedMetrics fun(sortBy: string, descending?: boolean): LibAT.Performance.SortedMetric[] Get sorted metrics
---@field ResetMetrics fun() Reset all metrics
---@field GetTotalUsage fun(): number, number Get total CPU and memory usage
---@field GetAverageUsage fun(): number, number Get average CPU and memory usage

----------------------------------------------------------------------------------------------------
-- Metrics Structure
----------------------------------------------------------------------------------------------------

---@class LibAT.Performance.Metrics
---@field cpu number CPU usage in milliseconds
---@field memory number Memory usage in megabytes
---@field loadTime number Load time in milliseconds
---@field calls number Number of function calls (reserved for future use)
---@field peak LibAT.Performance.PeakMetrics Peak usage values

---@class LibAT.Performance.PeakMetrics
---@field cpu number Peak CPU usage
---@field memory number Peak memory usage

---@class LibAT.Performance.SortedMetric
---@field name string Addon name
---@field metrics LibAT.Performance.Metrics Metrics data

----------------------------------------------------------------------------------------------------
-- Database Structure
----------------------------------------------------------------------------------------------------

---@class LibAT.Performance.DBProfile
---@field tracking LibAT.Performance.TrackingConfig Tracking configuration
---@field metrics table<string, LibAT.Performance.Metrics> Current metrics cache

---@class LibAT.Performance.TrackingConfig
---@field enabled boolean Whether tracking is currently active
---@field updateInterval number Update interval in seconds
---@field showSystemAddons boolean Include Blizzard_ addons in metrics
