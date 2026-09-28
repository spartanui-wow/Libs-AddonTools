---@class LibAT
local LibAT = LibAT

-- Type definitions for the AddonManager system (IDE only, not listed in the TOC)

---@class LibAT.AddonManager : AceAddon, AceEvent-3.0
---@field description string
---@field Database AceDB
---@field DB LibAT.AddonManager.DB Global saved data
---@field GDB LibAT.AddonManager.DB Alias of DB
---@field logger LoggerObject
---@field initialized boolean|nil
---@field Core LibAT.AddonManager.Core
---@field Favorites LibAT.AddonManager.Favorites
---@field Profiles LibAT.AddonManager.Profiles
---@field BlizzardEnhance LibAT.AddonManager.BlizzardEnhance
---@field Theme LibAT.AddonManager.Theme
---@field View LibAT.AddonManager.View
---@field Open fun()

---@class LibAT.AddonManager.DB
---@field enabled boolean Show the shortcut on the Blizzard addon list
---@field favorites table<string, boolean>
---@field lockFavorites boolean Keep favorites enabled
---@field profiles table<number, LibAT.AddonManager.ProfileData> Shared profiles (ID 1 is Default)
---@field nextProfileId number
---@field activeProfile number
---@field perCharacter table<string, LibAT.AddonManager.CharacterData>
---@field characterList table<string, table<string, {name: string, class: string, guid: string|nil}>>
---@field characterScope 'player'|'all'
---@field collapsed table<string, boolean> Collapsed addon groups
---@field gameMenuOpensManager boolean

---@class LibAT.AddonManager.CharacterData
---@field activeProfile number|nil
---@field profiles table<number, LibAT.AddonManager.ProfileData>|nil
---@field nextProfileId number|nil

---@class LibAT.AddonManager.ProfileData
---@field displayName string
---@field enabled table<string, boolean> Addon name to enabled state
---@field created number|nil
---@field modified number|nil
