---@class LibAT
local LibAT = LibAT

-- Type definitions for the Performance system (IDE only, not listed in the TOC)

---@class LibAT.Performance : AceAddon, AceEvent-3.0
---@field description string
---@field Database AceDB
---@field DB LibAT.Performance.DBProfile Preferences only; samples are never saved
---@field logger LoggerObject
---@field samples LibAT.Performance.Sample[] Latest sample of every loaded addon
---@field lastSample number GetTime() of the latest sample
---@field HasProfiler fun(): boolean
---@field Sample fun(force?: boolean)
---@field GetTotals fun(): number, number, number|nil
---@field GetSorted fun(field: string, descending: boolean): LibAT.Performance.Sample[]
---@field ResetPeaks fun()

---@class LibAT.Performance.DBProfile
---@field showSystemAddons boolean Include Blizzard addons
---@field sort string title|cpuRecent|cpuSession|cpuPeak|memory
---@field sortDescending boolean
