---@class LibAT
local LibAT = LibAT
local AddonManager = LibAT:GetModule('Handler.AddonManager')

local ADDON_NAME = ...

-- Core: the addon model. Static TOC data is scanned once; enable state is always read live from
-- C_AddOns so this manager, the Blizzard list and profiles never disagree. Every change is saved
-- immediately, and a snapshot taken when the session started lets the UI show what needs a reload
-- and revert back to it.

---@class LibAT.AddonManager.Core
local Core = {}
AddonManager.Core = Core

local Enum_None = (Enum and Enum.AddOnEnableState and Enum.AddOnEnableState.None) or 0
local Enum_All = (Enum and Enum.AddOnEnableState and Enum.AddOnEnableState.All) or 2

---@class LibAT.AddonManager.Addon
---@field index number
---@field name string Folder name
---@field title string Display title with color codes
---@field plainTitle string Title stripped of escapes
---@field sortKey string Lowercase sort key
---@field searchText string Lowercase haystack for search
---@field notes string
---@field author string
---@field version string
---@field category string|nil TOC Category
---@field group string Parent addon name (self when top-level)
---@field security string
---@field lod boolean
---@field deps string[]
---@field optDeps string[]
---@field iconTexture string|nil
---@field iconAtlas string|nil
---@field interface number|nil
---@field children LibAT.AddonManager.Addon[]
---@field parent LibAT.AddonManager.Addon|nil

---@type LibAT.AddonManager.Addon[]
Core.addons = {}
---@type table<string, LibAT.AddonManager.Addon>
Core.byName = {}
Core.scanned = false

-- Enabled-for-this-character state when the session started, by addon name
local sessionState = {}
local playerGUID

-- nil = all characters, otherwise a character GUID
Core.character = nil

-- Addons that bulk actions and profiles never turn off
Core.protected = { [ADDON_NAME or 'LibsAddonTools'] = true }

local listeners = {}

---@param fn fun(reason: string)
function Core.OnChange(fn)
	table.insert(listeners, fn)
end

local notifyPending = false
local notifyReason

---Batch change notifications into one per frame
---@param reason string
local function Notify(reason)
	notifyReason = reason
	if notifyPending then
		return
	end
	notifyPending = true
	C_Timer.After(0, function()
		notifyPending = false
		for _, fn in ipairs(listeners) do
			local ok, err = pcall(fn, notifyReason)
			if not ok and AddonManager.logger then
				AddonManager.logger.error('Change listener failed: ' .. tostring(err))
			end
		end
	end)
end
Core.Notify = Notify

local savePending = false

---Persist the addon state shortly after a burst of changes
local function QueueSave()
	if savePending then
		return
	end
	savePending = true
	C_Timer.After(0, function()
		savePending = false
		C_AddOns.SaveAddOns()
	end)
end

----------------------------------------------------------------------------------------------------
-- Text helpers
----------------------------------------------------------------------------------------------------

---Strip color codes, texture/atlas markup and line breaks from a string
---@param text string|nil
---@return string
function Core.StripEscapes(text)
	if not text then
		return ''
	end
	text = text:gsub('|c%x%x%x%x%x%x%x%x', '')
	text = text:gsub('|cn[^:]*:', '')
	text = text:gsub('|r', '')
	text = text:gsub('|T.-|t', '')
	text = text:gsub('|A.-|a', '')
	text = text:gsub('|n', ' ')
	return strtrim(text)
end

---@param index number
---@param field string
---@return string|nil
local function Meta(index, field)
	local ok, value = pcall(C_AddOns.GetAddOnMetadata, index, field)
	if ok and value and value ~= '' then
		return value
	end
	return nil
end

---@param ... string|nil
---@return string[]
local function PackNames(...)
	local list = {}
	for i = 1, select('#', ...) do
		local dep = select(i, ...)
		if type(dep) == 'string' then
			dep = strtrim(dep)
			if dep ~= '' then
				table.insert(list, dep)
			end
		end
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- Scanning
----------------------------------------------------------------------------------------------------

---Build the static addon list from TOC data
function Core.Scan()
	wipe(Core.addons)
	wipe(Core.byName)

	for i = 1, C_AddOns.GetNumAddOns() do
		local name, title, notes, _, _, security = C_AddOns.GetAddOnInfo(i)
		if name then
			local plainTitle = Core.StripEscapes(title)
			if plainTitle == '' then
				plainTitle = name
			end
			local category = Meta(i, 'Category') or Meta(i, 'X-Category')
			local author = Core.StripEscapes(Meta(i, 'Author'))
			local version = Core.StripEscapes(Meta(i, 'Version'))

			---@type LibAT.AddonManager.Addon
			local addon = {
				index = i,
				name = name,
				title = (title and title ~= '') and title or name,
				plainTitle = plainTitle,
				sortKey = plainTitle:lower():gsub('^[%p%s]+', ''),
				notes = Core.StripEscapes(notes),
				author = author,
				version = version,
				category = category,
				group = Meta(i, 'Group') or Meta(i, 'X-Part-Of') or name,
				security = security or '',
				lod = C_AddOns.IsAddOnLoadOnDemand(i) and true or false,
				deps = PackNames(C_AddOns.GetAddOnDependencies(i)),
				optDeps = PackNames(C_AddOns.GetAddOnOptionalDependencies(i)),
				iconTexture = Meta(i, 'IconTexture'),
				iconAtlas = Meta(i, 'IconAtlas'),
				interface = C_AddOns.GetAddOnInterfaceVersion and tonumber(C_AddOns.GetAddOnInterfaceVersion(i)) or nil,
				children = {},
			}
			addon.searchText = table.concat({ plainTitle, name, addon.author, addon.notes, category or '' }, '\n'):lower()

			Core.addons[#Core.addons + 1] = addon
			Core.byName[name] = addon
		end
	end

	-- Attach children to their group parent. A group that points at a missing addon stays top-level.
	for _, addon in ipairs(Core.addons) do
		if addon.group ~= addon.name then
			local parent = Core.byName[addon.group]
			if parent and parent.group == parent.name then
				addon.parent = parent
				table.insert(parent.children, addon)
			end
		end
	end

	for _, addon in ipairs(Core.addons) do
		if #addon.children > 1 then
			table.sort(addon.children, function(a, b)
				return a.sortKey < b.sortKey
			end)
		end
	end

	Core.scanned = true
	if AddonManager.logger then
		AddonManager.logger.info(string.format('Scanned %d addons', #Core.addons))
	end
end

function Core.EnsureScanned()
	if not Core.scanned then
		Core.Scan()
	end
end

---@param name string
---@return LibAT.AddonManager.Addon|nil
function Core.Get(name)
	Core.EnsureScanned()
	return Core.byName[name]
end

----------------------------------------------------------------------------------------------------
-- Characters
----------------------------------------------------------------------------------------------------

---@return string|nil
function Core.PlayerGUID()
	if not playerGUID then
		playerGUID = UnitGUID('player')
	end
	return playerGUID
end

---@param guid string|nil nil for all characters
function Core.SetCharacter(guid)
	Core.character = guid
	Notify('character')
end

---@return boolean
function Core.IsAllCharacters()
	return Core.character == nil
end

---Remember this character so it can be picked later from the character menu
function Core.RecordCharacter()
	local realm = GetRealmName()
	local name = UnitName('player')
	local guid = Core.PlayerGUID()
	if not realm or not name or not guid then
		return
	end
	local _, class = UnitClass('player')
	AddonManager.DB.characterList[realm] = AddonManager.DB.characterList[realm] or {}
	AddonManager.DB.characterList[realm][name] = { name = name, class = class, guid = guid }
end

---Characters for the character menu: all, this character, then alts on this realm with a known GUID
---@return {label: string, guid: string|nil, class: string|nil, isPlayer: boolean|nil}[]
function Core.GetCharacters()
	local list = { { label = 'All characters', guid = nil } }
	local myGUID = Core.PlayerGUID()
	local _, myClass = UnitClass('player')
	table.insert(list, { label = UnitName('player'), guid = myGUID, class = myClass, isPlayer = true })

	local realm = GetRealmName()
	local known = realm and AddonManager.DB.characterList[realm]
	if known then
		local alts = {}
		for charName, info in pairs(known) do
			if info.guid and info.guid ~= myGUID then
				table.insert(alts, { label = charName, guid = info.guid, class = info.class })
			end
		end
		table.sort(alts, function(a, b)
			return a.label < b.label
		end)
		for _, alt in ipairs(alts) do
			table.insert(list, alt)
		end
	end
	return list
end

---@param guid string|nil
---@return string
function Core.CharacterLabel(guid)
	if not guid then
		return 'All characters'
	end
	for _, entry in ipairs(Core.GetCharacters()) do
		if entry.guid == guid then
			return entry.label
		end
	end
	return UnitName('player')
end

----------------------------------------------------------------------------------------------------
-- State (always live)
----------------------------------------------------------------------------------------------------

---Raw enable state for the selected character context: 0 none, 1 some characters, 2 all
---@param addon LibAT.AddonManager.Addon
---@return number
function Core.GetEnableState(addon)
	return C_AddOns.GetAddOnEnableState(addon.index, Core.character) or Enum_None
end

---@param addon LibAT.AddonManager.Addon
---@return boolean
function Core.IsEnabled(addon)
	return Core.GetEnableState(addon) > Enum_None
end

---Enabled for the logged-in character, which is what the next reload will load
---@param addon LibAT.AddonManager.Addon
---@return boolean
function Core.IsEnabledForPlayer(addon)
	return (C_AddOns.GetAddOnEnableState(addon.index, Core.PlayerGUID()) or Enum_None) > Enum_None
end

---@param addon LibAT.AddonManager.Addon
---@return boolean
function Core.IsLoaded(addon)
	return C_AddOns.IsAddOnLoaded(addon.index) and true or false
end

---Whether the addon can load for the selected character, and why not
---@param addon LibAT.AddonManager.Addon
---@return boolean loadable
---@return string|nil reason
function Core.GetLoadable(addon)
	if C_AddOns.IsAddOnLoadable then
		local loadable, reason = C_AddOns.IsAddOnLoadable(addon.index, Core.character)
		return loadable, reason
	end
	local _, _, _, loadable, reason = C_AddOns.GetAddOnInfo(addon.index)
	return loadable, reason
end

---Record what this character has enabled right now as the session baseline
function Core.TakeSnapshot()
	Core.EnsureScanned()
	Core.startVersionCheck = Core.IsVersionCheckEnabled()
	wipe(sessionState)
	for _, addon in ipairs(Core.addons) do
		sessionState[addon.name] = Core.IsEnabledForPlayer(addon)
	end
end

---@return boolean
function Core.IsVersionCheckEnabled()
	if C_AddOns.IsAddonVersionCheckEnabled then
		return C_AddOns.IsAddonVersionCheckEnabled() and true or false
	end
	return true
end

---True when "load out of date addons" was toggled this session
---@return boolean
function Core.VersionCheckChanged()
	return Core.startVersionCheck ~= nil and Core.startVersionCheck ~= Core.IsVersionCheckEnabled()
end

---@param addon LibAT.AddonManager.Addon
---@return boolean
function Core.WasEnabledAtStart(addon)
	local state = sessionState[addon.name]
	if state == nil then
		return Core.IsLoaded(addon)
	end
	return state
end

---True when the next reload will change whether this addon runs
---@param addon LibAT.AddonManager.Addon
---@return boolean
function Core.NeedsReload(addon)
	local enabled = Core.IsEnabledForPlayer(addon)
	local loaded = Core.IsLoaded(addon)
	if enabled == Core.WasEnabledAtStart(addon) then
		return false
	end
	if enabled and addon.lod then
		return false
	end
	if enabled and loaded then
		return false
	end
	if not enabled and not loaded then
		return false
	end
	return true
end

---@return LibAT.AddonManager.Addon[]
function Core.GetPendingReload()
	Core.EnsureScanned()
	local list = {}
	for _, addon in ipairs(Core.addons) do
		if Core.NeedsReload(addon) then
			table.insert(list, addon)
		end
	end
	return list
end

---Short status for display: key, label, tone ('good'|'warn'|'bad'|'muted'|nil)
---@param addon LibAT.AddonManager.Addon
---@return string key
---@return string label
---@return string|nil tone
function Core.GetStatus(addon)
	local enabled = Core.IsEnabled(addon)
	local loaded = Core.IsLoaded(addon)
	local loadable, reason = Core.GetLoadable(addon)

	if addon.security == 'BANNED' then
		return 'banned', ADDON_BANNED or 'Banned', 'bad'
	end
	if Core.NeedsReload(addon) then
		if Core.IsEnabledForPlayer(addon) then
			return 'reload-on', 'Loads after reload', 'warn'
		end
		return 'reload-off', 'Unloads after reload', 'warn'
	end
	if loaded then
		return 'loaded', 'Loaded', 'good'
	end
	if not enabled then
		return 'disabled', 'Disabled', 'muted'
	end
	if reason == 'DEMAND_LOADED' or reason == 'DEP_DEMAND_LOADED' or (loadable and addon.lod) then
		return 'lod', 'Loads on demand', 'muted'
	end
	if reason == 'DEP_DISABLED' then
		return 'dep-disabled', _G.ADDON_DEP_DISABLED or 'Dependency disabled', 'warn'
	end
	if reason and not loadable then
		return 'problem', _G['ADDON_' .. reason] or reason, 'bad'
	end
	return 'enabled', 'Enabled', 'good'
end

---True when the addon is enabled but cannot load (out of date, missing dependency, and so on)
---@param addon LibAT.AddonManager.Addon
---@return boolean
function Core.HasProblem(addon)
	local key = Core.GetStatus(addon)
	return key == 'problem' or key == 'banned' or key == 'dep-disabled'
end

----------------------------------------------------------------------------------------------------
-- Dependencies
----------------------------------------------------------------------------------------------------

---Required dependencies, depth first, excluding the addon itself
---@param addon LibAT.AddonManager.Addon
---@return string[]
function Core.GetRequiredChain(addon)
	local order, seen = {}, { [addon.name] = true }
	local function walk(a)
		for _, depName in ipairs(a.deps) do
			if not seen[depName] then
				seen[depName] = true
				local dep = Core.byName[depName]
				if dep then
					walk(dep)
				end
				table.insert(order, depName)
			end
		end
	end
	walk(addon)
	return order
end

---Installed addons that require this addon
---@param addon LibAT.AddonManager.Addon
---@return LibAT.AddonManager.Addon[]
function Core.GetDependents(addon)
	local list = {}
	for _, other in ipairs(Core.addons) do
		for _, depName in ipairs(other.deps) do
			if depName == addon.name then
				table.insert(list, other)
				break
			end
		end
	end
	table.sort(list, function(a, b)
		return a.sortKey < b.sortKey
	end)
	return list
end

----------------------------------------------------------------------------------------------------
-- Changing state
----------------------------------------------------------------------------------------------------

---@param addon LibAT.AddonManager.Addon
---@param enabled boolean
local function Apply(addon, enabled)
	if enabled then
		C_AddOns.EnableAddOn(addon.index, Core.character)
	else
		C_AddOns.DisableAddOn(addon.index, Core.character)
	end
end

---Whether bulk actions and profiles may turn this addon off
---@param addon LibAT.AddonManager.Addon
---@return boolean
function Core.IsProtected(addon)
	if Core.protected[addon.name] then
		return true
	end
	return AddonManager.Favorites and AddonManager.Favorites.IsLockedFavorite(addon.name) or false
end

---Enable or disable one addon. Enabling also enables the addons it requires.
---@param addon LibAT.AddonManager.Addon
---@param enabled boolean
function Core.SetEnabled(addon, enabled)
	if enabled then
		for _, depName in ipairs(Core.GetRequiredChain(addon)) do
			local dep = Core.byName[depName]
			if dep and not Core.IsEnabled(dep) then
				Apply(dep, true)
			end
		end
	elseif AddonManager.Favorites and AddonManager.Favorites.IsLockedFavorite(addon.name) then
		return
	end
	Apply(addon, enabled)
	QueueSave()
	Notify('state')
end

---Enable or disable many addons at once. Protected addons are never turned off.
---@param list LibAT.AddonManager.Addon[]
---@param enabled boolean
---@return number changed
function Core.SetEnabledMany(list, enabled)
	local changed = 0
	for _, addon in ipairs(list) do
		local skip = (not enabled) and Core.IsProtected(addon)
		if not skip and Core.IsEnabled(addon) ~= enabled then
			if enabled then
				for _, depName in ipairs(Core.GetRequiredChain(addon)) do
					local dep = Core.byName[depName]
					if dep and not Core.IsEnabled(dep) then
						Apply(dep, true)
						changed = changed + 1
					end
				end
			end
			Apply(addon, enabled)
			changed = changed + 1
		end
	end
	if changed > 0 then
		QueueSave()
		Notify('state')
	end
	return changed
end

---Put this character back to the way the session started
---@return number changed
function Core.RevertToSession()
	Core.EnsureScanned()
	local guid = Core.PlayerGUID()
	local changed = 0
	for _, addon in ipairs(Core.addons) do
		local wanted = Core.WasEnabledAtStart(addon)
		if Core.IsEnabledForPlayer(addon) ~= wanted then
			if wanted then
				C_AddOns.EnableAddOn(addon.index, guid)
			else
				C_AddOns.DisableAddOn(addon.index, guid)
			end
			changed = changed + 1
		end
	end
	if changed > 0 then
		QueueSave()
		Notify('state')
	end
	return changed
end

---Load an enabled load-on-demand addon right now
---@param addon LibAT.AddonManager.Addon
---@return boolean loaded
---@return string|nil reason
function Core.LoadNow(addon)
	if InCombatLockdown() then
		return false, 'Not available in combat'
	end
	local loaded, reason = C_AddOns.LoadAddOn(addon.index)
	Notify('loaded')
	return loaded and true or false, reason and (_G['ADDON_' .. reason] or reason) or nil
end

----------------------------------------------------------------------------------------------------
-- Performance
----------------------------------------------------------------------------------------------------

local lastMemoryUpdate = 0

---Refresh memory numbers, at most every 15 seconds unless forced
---@param force? boolean
function Core.UpdateMemory(force)
	local now = GetTime()
	if force or now - lastMemoryUpdate > 15 then
		lastMemoryUpdate = now
		UpdateAddOnMemoryUsage()
	end
end

---@param addon LibAT.AddonManager.Addon
---@return number kb
function Core.GetMemory(addon)
	if not Core.IsLoaded(addon) then
		return 0
	end
	return GetAddOnMemoryUsage(addon.index) or 0
end

---@return boolean
function Core.HasProfiler()
	return C_AddOnProfiler ~= nil and C_AddOnProfiler.IsEnabled ~= nil and C_AddOnProfiler.IsEnabled() and Enum.AddOnProfilerMetric ~= nil
end

---Share of UI time spent in this addon, averaged over the session (0-1), or nil when unavailable
---@param addon LibAT.AddonManager.Addon
---@return number|nil
function Core.GetCPUShare(addon)
	if not Core.HasProfiler() or not Core.IsLoaded(addon) then
		return nil
	end
	local metric = Enum.AddOnProfilerMetric.SessionAverageTime
	local appVal = C_AddOnProfiler.GetApplicationMetric(metric) or 0
	local overallVal = C_AddOnProfiler.GetOverallMetric(metric) or 0
	local addonVal = C_AddOnProfiler.GetAddOnMetric(addon.name, metric) or 0
	local relativeTotal = appVal - overallVal + addonVal
	if relativeTotal <= 0 then
		return nil
	end
	return addonVal / relativeTotal
end

----------------------------------------------------------------------------------------------------
-- Lifecycle
----------------------------------------------------------------------------------------------------

---Called once the player is in the world: scan, record the character and snapshot the session
function Core.Initialize()
	playerGUID = UnitGUID('player')
	Core.Scan()
	Core.RecordCharacter()
	Core.TakeSnapshot()
end

---Re-read loaded state after an addon loads on demand
function Core.OnAddonLoaded()
	if Core.scanned then
		Notify('loaded')
	end
end

Core.Enum_All = Enum_All
