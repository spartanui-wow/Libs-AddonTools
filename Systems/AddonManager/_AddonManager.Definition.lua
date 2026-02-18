---@class LibAT
local LibAT = LibAT

-- Type Definitions for AddonManager System

----------------------------------------------------------------------------------------------------
-- AddonManager Module
----------------------------------------------------------------------------------------------------

---@class LibAT.AddonManager : AceAddon, AceEvent-3.0
---@field description string
---@field Database AceDB Database object
---@field DB table Profile data
---@field GDB table Global DB scope (favorites, lock state)
---@field logger LoggerObject Logger instance
---@field Core LibAT.AddonManager.Core Core API functions
---@field SpecialCases LibAT.AddonManager.SpecialCases Special case handling
---@field Metadata LibAT.AddonManager.Metadata Metadata utilities
---@field Favorites LibAT.AddonManager.Favorites Favorites system

----------------------------------------------------------------------------------------------------
-- Core System
----------------------------------------------------------------------------------------------------

---@class LibAT.AddonManager.Core
---@field GetNumAddOns fun(): number Get total number of addons
---@field GetAddOnInfo fun(index: number): string, string, string, boolean, string, string, boolean Get addon info
---@field GetAddOnMetadata fun(indexOrName: number|string, field: string): string|nil Get addon metadata
---@field GetAddOnDependencies fun(index: number): ... Get addon dependencies
---@field GetAddOnOptionalDependencies fun(index: number): ... Get optional dependencies
---@field IsAddOnLoaded fun(indexOrName: number|string): boolean Check if addon is loaded
---@field IsAddOnLoadOnDemand fun(index: number): boolean Check if addon is LOD
---@field LoadAddOn fun(indexOrName: number|string): boolean, string|nil Load an addon
---@field GetAddOnEnableState fun(index: number, character?: string): number Get addon enable state
---@field EnableAddOn fun(index: number, character?: string) Enable an addon
---@field DisableAddOn fun(index: number, character?: string) Disable an addon
---@field EnableAllAddOns fun(character?: string) Enable all addons
---@field DisableAllAddOns fun(character?: string) Disable all addons
---@field SaveAddOns fun() Save addon state
---@field ResetAddOns fun() Reset addon state
---@field AddonCache table<number, LibAT.AddonManager.AddonMetadata> Addon metadata cache
---@field ScanAddons fun() Scan all installed addons
---@field CheckCompatibility fun(addonIndex: number): boolean, string|nil Check addon compatibility
---@field EnableAddon fun(addonIndex: number, character?: string) Enable an addon with logging
---@field DisableAddon fun(addonIndex: number, character?: string) Disable an addon with logging
---@field GetAddonByName fun(addonName: string): LibAT.AddonManager.AddonMetadata|nil Get addon by name
---@field GetAddonsByCategory fun(category: string): LibAT.AddonManager.AddonMetadata[] Get addons in category
---@field GetAllCategories fun(): string[] Get all unique categories

----------------------------------------------------------------------------------------------------
-- Addon Metadata Structure
----------------------------------------------------------------------------------------------------

---@class LibAT.AddonManager.AddonMetadata
---@field index number Addon index
---@field name string Addon name (folder name)
---@field title string Addon display title
---@field notes string Addon description
---@field loadable boolean Whether addon can be loaded
---@field reason string Reason if not loadable
---@field security string Security level
---@field newVersion boolean Whether addon has new version available
---@field author string Addon author
---@field version string Addon version
---@field partOf string|nil X-Part-Of tag (multi-part addon grouping)
---@field minInterface number|nil X-Min-Interface tag
---@field maxInterface number|nil X-Max-Interface tag
---@field category string|nil X-Category tag
---@field dependencies string[] List of required dependencies
---@field optionalDeps string[] List of optional dependencies
---@field loaded boolean Whether addon is currently loaded
---@field loadOnDemand boolean Whether addon is LOD
---@field enabled boolean|nil Whether addon is enabled (nil = unknown)

----------------------------------------------------------------------------------------------------
-- Special Cases
----------------------------------------------------------------------------------------------------

---@class LibAT.AddonManager.SpecialCases
---@field TransformName fun(addonName: string): string Transform addon name for grouping
---@field GetAddonFamily fun(addonName: string): string|nil Get addon family name
---@field IsProtectedAddon fun(addonName: string): boolean Check if addon is protected
---@field IsCoreAddon fun(addonName: string): boolean Check if addon is family core

----------------------------------------------------------------------------------------------------
-- Metadata Utilities
----------------------------------------------------------------------------------------------------

---@class LibAT.AddonManager.Metadata
---@field STANDARD_TAGS string[] List of standard TOC tags
---@field CUSTOM_TAGS table<string, string> Map of custom TOC tag keys to tag names
---@field ExtractAll fun(addonIndex: number): table Extract all metadata for addon
---@field ParseDependencies fun(depsString: string): string[] Parse dependency string
---@field ParseInterfaceVersion fun(versionString: string|number): number|nil Parse interface version
---@field GetCurrentInterfaceVersion fun(): number Get current interface version
---@field CheckInterfaceCompatibility fun(minVersion: number|string|nil, maxVersion: number|string|nil): boolean, string|nil Check compatibility
---@field GetDefaultCategory fun(addonMetadata: table): string|nil Get default category
---@field NormalizeCategory fun(category: string): string Normalize category name

----------------------------------------------------------------------------------------------------
-- Database Structure
----------------------------------------------------------------------------------------------------

---@class LibAT.AddonManager.Profile
---@field enabled table<string, boolean> Map of addon names to enabled state

---@class LibAT.AddonManager.DBProfile
---@field profiles table<string, LibAT.AddonManager.Profile> Named profiles
---@field activeProfile string Currently active profile name
---@field categories table Categories configuration
---@field categories.custom table<string, string[]> Custom category assignments
---@field perCharacter table<string, table> Per-character settings

----------------------------------------------------------------------------------------------------
-- Search & Filter Types
----------------------------------------------------------------------------------------------------

---@alias LibAT.AddonManager.FilterMode
---| "all" # Show all addons
---| "enabled" # Show only enabled addons
---| "disabled" # Show only disabled addons
---| "loaded" # Show only loaded addons
---| "lod" # Show only LOD addons
---| "protected" # Show only protected addons

---@alias LibAT.AddonManager.SortMode
---| "name" # Sort by addon name
---| "title" # Sort by addon title
---| "author" # Sort by author
---| "category" # Sort by category

----------------------------------------------------------------------------------------------------
-- Profile System Types
----------------------------------------------------------------------------------------------------

---@class LibAT.AddonManager.ProfileData
---@field name string Profile name
---@field enabled table<string, boolean> Map of addon names to enabled state
---@field created number Timestamp of creation
---@field modified number Timestamp of last modification

----------------------------------------------------------------------------------------------------
-- Event Callback Types
----------------------------------------------------------------------------------------------------

---@alias LibAT.AddonManager.ChangeCallback fun(addonName: string, enabled: boolean)
---Callback when addon enable state changes

---@alias LibAT.AddonManager.ProfileCallback fun(profileName: string)
---Callback when active profile changes

----------------------------------------------------------------------------------------------------
-- Favorites System
----------------------------------------------------------------------------------------------------

---@class LibAT.AddonManager.Favorites
---@field PendingRemovals table<string, boolean> Tracks removed favorites until panel hides
---@field IsFavorite fun(addonName: string): boolean Check if addon is favorited
---@field AddFavorite fun(addonName: string) Add addon to favorites
---@field RemoveFavorite fun(addonName: string) Remove addon from favorites (pending removal)
---@field CommitRemovals fun() Clear pending removals
---@field GetFavorites fun(): string[] Get sorted list of favorited addon names
---@field GetNonFavorites fun(): string[] Get sorted list of non-favorited addon names
---@field IsLocked fun(): boolean Get lock state
---@field SetLocked fun(locked: boolean) Set lock state
---@field EnforceLock fun() Re-enable any disabled favorites when lock is on
