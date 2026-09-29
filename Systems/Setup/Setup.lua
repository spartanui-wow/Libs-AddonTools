---@class LibAT
local LibAT = LibAT

----------------------------------------------------------------------------------------------------
-- Setup - one first-run hub for every addon that registers with it
--
-- Addons register steps (look, choice, toggles, import, form, custom, summary). LibAT decides once
-- per addon whether the player is new ('fresh') or already used the addon ('upgrade'), opens one
-- window after login for the addons that are due, stages anything that needs a reload, and shows
-- a toast for what changed in an update. The window lives in SetupHub.lua.
----------------------------------------------------------------------------------------------------

---@alias LibAT.SetupStepKind 'look'|'choice'|'toggles'|'import'|'form'|'custom'|'summary'
---@alias LibAT.SetupScope 'account'|'profile'

---@class LibAT.SetupOption
---@field value any
---@field title string
---@field caption? string
---@field tag? string
---@field art? LibAT.CardArt
---@field accent? number[]
---@field recommended? boolean
---@field variants? LibAT.CardVariant[] look steps only

---@class LibAT.SetupToggle
---@field key any
---@field title string
---@field caption? string
---@field core? boolean Always on; shown with a Core tag and cannot be turned off
---@field needsReload? boolean Changing it adds a "needs a reload" entry
---@field recommended? boolean

---@class LibAT.SetupToggleGroup
---@field title? string
---@field items LibAT.SetupToggle[]

---@class LibAT.SetupImportSource
---@field id string
---@field title string
---@field caption? string
---@field detect? fun(): boolean Only sources that return true are shown
---@field apply fun(ctx: LibAT.SetupContext) Runs when the player finishes and reloads

---@class LibAT.SetupStep
---@field id string
---@field kind LibAT.SetupStepKind
---@field title string Header text
---@field name? string Label in the step list (defaults to title)
---@field text? string A short line under the header
---@field order? number Lower comes first
---@field scope? LibAT.SetupScope 'profile' steps are asked again for a brand-new profile
---@field hidden? fun(): boolean Leave the step out when this returns true
---@field recommended? any Recommended value (look/choice); or mark an option with recommended = true
---@field get? fun(key?: any): any
---@field set? fun(valueOrKey: any, ctxOrValue: any, ctx?: LibAT.SetupContext) look/choice: set(value, ctx); toggles: set(key, value, ctx)
---@field choices? LibAT.SetupOption[] choice steps (look steps may use it too)
---@field cards? LibAT.SetupOption[] look steps
---@field getVariant? fun(value: any): any look steps with variants
---@field setVariant? fun(value: any, variant: any, ctx: LibAT.SetupContext)
---@field items? LibAT.SetupToggle[] toggles steps
---@field groups? LibAT.SetupToggleGroup[] toggles steps
---@field sources? LibAT.SetupImportSource[] import steps
---@field widgets? table<string, LibAT.WidgetDef> form steps (BuildWidgets definitions, set(info, value))
---@field build? fun(frame: Frame, ctx: LibAT.SetupContext) custom steps
---@field onShow? fun(frame: Frame, ctx: LibAT.SetupContext) custom steps: called when a built page is shown again
---@field onLeave? fun(ctx: LibAT.SetupContext) Called when the player leaves the step
---@field cache? boolean custom steps: build once and reuse (default true; legacy pages default false)

---@class LibAT.SetupWhatsNew
---@field version string
---@field title string
---@field caption? string
---@field art? LibAT.CardArt
---@field action? {text?: string, options?: string|fun(), step?: string}

---@class LibAT.SetupConfig
---@field name string Display name
---@field icon? string|number
---@field summary? string One line about the addon for the Start page
---@field priority? number Lower opens first (SpartanUI uses 10; default 100)
---@field isExistingUser? fun(): boolean True when the player used this addon before Setup knew about it
---@field isNewProfile? fun(): boolean True when the current profile has never been set up
---@field profileKey? fun(): string Name of the current profile (needed for scope = 'profile')
---@field scope? LibAT.SetupScope Default scope for steps (default 'account')
---@field optionsCommand? string|fun() Opens the addon's settings, e.g. '/ldb'
---@field onComplete? fun() Runs once, the first time the player finishes this addon's setup
---@field addonName? string Folder name; when given and the addon is still loading, detection waits for its ADDON_LOADED

---@class LibAT.Setup
LibAT.Setup = LibAT.Setup or {}
local Setup = LibAT.Setup

Setup.KINDS = { look = true, choice = true, toggles = true, import = true, form = true, custom = true, summary = true }
Setup.WIDGET_TYPES = { button = true, slider = true, checkbox = true, dropdown = true, header = true, description = true, divider = true }
Setup.MAX_REMINDERS = 3
Setup.DEFAULT_PRIORITY = 100

Setup.registrations = {} ---@type table<string, LibAT.SetupRegistration>
Setup.order = {} ---@type string[]
Setup.staged = {} ---@type {key: string, label: string, apply: fun()|nil, addonId: string}[]
Setup.inCombat = false
Setup.loginReady = false

local seq = 0
local pendingLogs = {}

---Log through the LibAT logger. Messages sent before the logger exists are kept and sent later.
---@param level 'debug'|'info'|'warning'|'error'
---@param message string
local function Log(level, message)
	local log = LibAT.InternalLog
	if log and log[level] then
		log[level]('Setup: ' .. message)
	else
		pendingLogs[#pendingLogs + 1] = { level, message }
	end
end
Setup.Log = Log

local function FlushLogs()
	if not LibAT.InternalLog or #pendingLogs == 0 then
		return
	end
	local list = pendingLogs
	pendingLogs = {}
	for _, entry in ipairs(list) do
		Log(entry[1], entry[2])
	end
end

---Call a function from an addon without letting its error break the window
---@param where string Used in the log line
---@param fn function|nil
---@return boolean ok
---@return any result
local function SafeCall(where, fn, ...)
	if type(fn) ~= 'function' then
		return false, nil
	end
	local ok, a, b, c = pcall(fn, ...)
	if not ok then
		Log('error', where .. ' failed: ' .. tostring(a))
		return false, nil
	end
	return true, a, b, c
end
Setup.SafeCall = SafeCall

----------------------------------------------------------------------------------------------------
-- Saved state
----------------------------------------------------------------------------------------------------

---@class LibAT.SetupRecord
---@field status 'pending'|'done'|'skipped'
---@field how 'fresh'|'upgrade'|'converted'
---@field remind number Times the window was closed while this addon was due
---@field muted? boolean Player asked not to be shown this addon again
---@field whatsNew? string Newest What's new version the player has seen
---@field profiles table<string, boolean> Profiles whose profile steps are done
---@field completeRan? boolean

---Saved state, or nil before LibAT's database exists
---@return table|nil
function Setup:GetStore()
	local global = LibAT.Database and LibAT.Database.global
	if not global then
		return nil
	end
	if type(global.setup) ~= 'table' then
		global.setup = {}
	end
	local store = global.setup
	if type(store.addons) ~= 'table' then
		store.addons = {}
	end
	if store.autoOpen == nil then
		store.autoOpen = true
	end
	if not self.storeChecked then
		self.storeChecked = true
		-- The old window had one account-wide "Don't Ask Again". Honor it once for the addons that are
		-- registered this session, then drop it: from now on each addon has its own setting.
		if global.setupWizardDismissed then
			self.legacyDismissed = true
			global.setupWizardDismissed = false
			Log('info', 'Old "Don\'t Ask Again" found; addons registered this session are treated as set up')
		end
	end
	return store
end

---Does the old wizard have saved progress for this addon?
---@param addonId string
---@return boolean
local function HasLegacyProgress(addonId)
	local global = LibAT.Database and LibAT.Database.global
	local completed = global and global.setupWizardCompleted
	if type(completed) ~= 'table' then
		return false
	end
	local dot = addonId .. '.'
	local hash = addonId .. '#'
	for key in pairs(completed) do
		if type(key) == 'string' and (key:sub(1, #dot) == dot or key:sub(1, #hash) == hash) then
			return true
		end
	end
	return false
end

---Old-style pages can say they are complete. The first page is the one that knows whether the player
---has been through setup before (later pages may always say true, or be new since then).
---@param reg LibAT.SetupRegistration
---@return boolean
local function LegacyPagesSayDone(reg)
	local first = reg.steps[1]
	local page = first and first._legacyPage
	if page and type(page.isComplete) == 'function' then
		local ok, done = SafeCall(reg.id .. ' page ' .. tostring(page.id) .. ' isComplete', page.isComplete)
		return ok and done and true or false
	end
	return false
end

---Decide whether this is a new install or an existing user. Runs once per registration.
---@param reg LibAT.SetupRegistration
function Setup:Detect(reg)
	if reg.detected then
		return
	end
	self:GetStore()
	local how = 'fresh'
	if HasLegacyProgress(reg.id) then
		how = 'converted'
	elseif self.legacyDismissed then
		how = 'converted'
	elseif reg.config.isExistingUser then
		local ok, existing = SafeCall(reg.id .. ' isExistingUser', reg.config.isExistingUser)
		if ok and existing then
			how = 'upgrade'
		end
	elseif reg.legacy and LegacyPagesSayDone(reg) then
		how = 'converted'
	end
	reg.detected = how
	Log('debug', reg.id .. ' detected as ' .. how)
end

---Current profile name of an addon, or nil
---@param reg LibAT.SetupRegistration
---@return string|nil
local function ProfileKey(reg)
	if type(reg.config.profileKey) ~= 'function' then
		return nil
	end
	local ok, key = SafeCall(reg.id .. ' profileKey', reg.config.profileKey)
	if ok and key ~= nil then
		return tostring(key)
	end
	return nil
end

---Remember that the current profile has been set up
---@param reg LibAT.SetupRegistration
---@param rec LibAT.SetupRecord
local function StampProfile(reg, rec)
	local key = ProfileKey(reg)
	if key then
		rec.profiles = rec.profiles or {}
		rec.profiles[key] = true
	end
end

---Saved record for an addon. Creates it (and decides fresh or existing) the first time.
---@param reg LibAT.SetupRegistration
---@return LibAT.SetupRecord|nil
function Setup:GetRecord(reg)
	local store = self:GetStore()
	if not store then
		return nil
	end
	local rec = store.addons[reg.id]
	if rec then
		rec.profiles = rec.profiles or {}
		rec.remind = rec.remind or 0
		return rec
	end
	if reg.legacy and not self.loginReady and not reg.forceDetect then
		-- Old-style addons may still be writing their saved progress; decide after login
		return nil
	end
	if reg.waitForAddon then
		return nil
	end
	self:Detect(reg)
	rec = {
		status = reg.detected == 'fresh' and 'pending' or 'done',
		how = reg.detected,
		remind = 0,
		profiles = {},
	}
	if rec.status == 'done' then
		StampProfile(reg, rec)
	end
	store.addons[reg.id] = rec
	reg.createdThisSession = true
	return rec
end

----------------------------------------------------------------------------------------------------
-- Steps
----------------------------------------------------------------------------------------------------

---The options list of a look or choice step
---@param step LibAT.SetupStep
---@return LibAT.SetupOption[]
function Setup:GetOptions(step)
	return step.choices or step.cards or {}
end

---Every toggle item of a toggles step, in order
---@param step LibAT.SetupStep
---@return LibAT.SetupToggle[]
function Setup:GetToggleItems(step)
	if step.items then
		return step.items
	end
	local list = {}
	for _, group in ipairs(step.groups or {}) do
		for _, item in ipairs(group.items or {}) do
			list[#list + 1] = item
		end
	end
	return list
end

---Import sources that were found on this client
---@param reg LibAT.SetupRegistration
---@param step LibAT.SetupStep
---@return LibAT.SetupImportSource[]
function Setup:GetDetectedSources(reg, step)
	local list = {}
	for _, source in ipairs(step.sources or {}) do
		local found = true
		if type(source.detect) == 'function' then
			local ok, result = SafeCall(reg.id .. '.' .. step.id .. ' detect ' .. tostring(source.id), source.detect)
			found = ok and result and true or false
		end
		if found then
			list[#list + 1] = source
		end
	end
	return list
end

---The recommended value of a look or choice step, if it has one
---@param step LibAT.SetupStep
---@return any
function Setup:GetRecommended(step)
	if step.recommended ~= nil then
		return step.recommended
	end
	for _, option in ipairs(self:GetOptions(step)) do
		if option.recommended then
			return option.value
		end
	end
	return nil
end

---Scope of a step
---@param reg LibAT.SetupRegistration
---@param step LibAT.SetupStep
---@return LibAT.SetupScope
local function StepScope(reg, step)
	return step.scope or reg.config.scope or 'account'
end

---Is the step shown right now?
---@param reg LibAT.SetupRegistration
---@param step LibAT.SetupStep
---@return boolean
function Setup:IsStepVisible(reg, step)
	if type(step.hidden) == 'function' then
		local ok, hidden = SafeCall(reg.id .. '.' .. step.id .. ' hidden', step.hidden)
		if ok and hidden then
			return false
		end
	end
	if step.kind == 'import' and #self:GetDetectedSources(reg, step) == 0 then
		return false
	end
	return true
end

---Steps of an addon in display order, leaving out hidden ones
---@param reg LibAT.SetupRegistration
---@return LibAT.SetupStep[]
function Setup:GetVisibleSteps(reg)
	local list = {}
	for _, step in ipairs(reg.steps) do
		if self:IsStepVisible(reg, step) then
			list[#list + 1] = step
		end
	end
	return list
end

---Does this addon have profile steps waiting for the current profile?
---@param reg LibAT.SetupRegistration
---@param rec LibAT.SetupRecord
---@return boolean
local function ProfileStepsDue(reg, rec)
	local hasProfileSteps = false
	for _, step in ipairs(reg.steps) do
		if StepScope(reg, step) == 'profile' then
			hasProfileSteps = true
			break
		end
	end
	if not hasProfileSteps then
		return false
	end
	local key = ProfileKey(reg)
	if not key or (rec.profiles and rec.profiles[key]) then
		return false
	end
	if type(reg.config.isNewProfile) == 'function' then
		local ok, isNew = SafeCall(reg.id .. ' isNewProfile', reg.config.isNewProfile)
		return ok and isNew and true or false
	end
	return true
end

---Steps the player still has to see: every step while the addon is pending, or only the profile
---steps when a finished addon meets a new profile.
---@param reg LibAT.SetupRegistration
---@return LibAT.SetupStep[]
function Setup:GetDueSteps(reg)
	local rec = self:GetRecord(reg)
	if not rec then
		return {}
	end
	local list = {}
	if rec.status == 'pending' then
		return self:GetVisibleSteps(reg)
	end
	if rec.status == 'done' and ProfileStepsDue(reg, rec) then
		for _, step in ipairs(self:GetVisibleSteps(reg)) do
			if StepScope(reg, step) == 'profile' then
				list[#list + 1] = step
			end
		end
	end
	return list
end

----------------------------------------------------------------------------------------------------
-- Validation
----------------------------------------------------------------------------------------------------

---Check a step and return a list of problems. A step with problems is not added.
---@param reg LibAT.SetupRegistration
---@param step LibAT.SetupStep
---@return string[] problems
function Setup:ValidateStep(reg, step)
	local problems = {}
	local function Problem(text)
		problems[#problems + 1] = text
	end
	if type(step) ~= 'table' then
		Problem('step must be a table')
		return problems
	end
	if type(step.id) ~= 'string' or step.id == '' then
		Problem('id must be a non-empty string')
	elseif reg:GetStep(step.id) then
		Problem('id "' .. step.id .. '" is already used')
	end
	if not Setup.KINDS[step.kind] then
		Problem('kind must be look, choice, toggles, import, form, custom or summary (got ' .. tostring(step.kind) .. ')')
	end
	if type(step.title) ~= 'string' and type(step.name) ~= 'string' then
		Problem('title is required')
	end
	if step.scope ~= nil and step.scope ~= 'account' and step.scope ~= 'profile' then
		Problem("scope must be 'account' or 'profile'")
	end
	if step.hidden ~= nil and type(step.hidden) ~= 'function' then
		Problem('hidden must be a function')
	end
	if step.onLeave ~= nil and type(step.onLeave) ~= 'function' then
		Problem('onLeave must be a function')
	end

	local kind = step.kind
	if kind == 'look' or kind == 'choice' then
		local options = self:GetOptions(step)
		if #options == 0 then
			Problem(kind .. ' steps need a choices (or cards) list')
		end
		local hasVariants = false
		for i, option in ipairs(options) do
			if option.value == nil then
				Problem('option ' .. i .. ' has no value')
			end
			if type(option.title) ~= 'string' then
				Problem('option ' .. i .. ' has no title')
			end
			if option.variants then
				hasVariants = true
			end
		end
		if type(step.get) ~= 'function' then
			Problem('get must be a function: get() returns the current value')
		end
		if type(step.set) ~= 'function' then
			Problem('set must be a function: set(value, ctx)')
		end
		if hasVariants and (type(step.getVariant) ~= 'function' or type(step.setVariant) ~= 'function') then
			Problem('options with variants need getVariant(value) and setVariant(value, variant, ctx)')
		end
	elseif kind == 'toggles' then
		local items = self:GetToggleItems(step)
		if #items == 0 then
			Problem('toggles steps need an items or groups list')
		end
		for i, item in ipairs(items) do
			if item.key == nil then
				Problem('toggle ' .. i .. ' has no key')
			end
			if type(item.title) ~= 'string' then
				Problem('toggle ' .. i .. ' has no title')
			end
		end
		if type(step.get) ~= 'function' then
			Problem('get must be a function: get(key) returns true or false')
		end
		if type(step.set) ~= 'function' then
			Problem('set must be a function: set(key, value, ctx)')
		end
	elseif kind == 'import' then
		if type(step.sources) ~= 'table' or #step.sources == 0 then
			Problem('import steps need a sources list')
		end
		for i, source in ipairs(step.sources or {}) do
			if type(source.id) ~= 'string' then
				Problem('source ' .. i .. ' has no id')
			end
			if type(source.title) ~= 'string' then
				Problem('source ' .. i .. ' has no title')
			end
			if type(source.apply) ~= 'function' then
				Problem('source ' .. i .. ' needs apply(ctx)')
			end
			if source.detect ~= nil and type(source.detect) ~= 'function' then
				Problem('source ' .. i .. ' detect must be a function')
			end
		end
	elseif kind == 'form' then
		if type(step.widgets) ~= 'table' then
			Problem('form steps need a widgets table (BuildWidgets definitions)')
		end
		for key, def in pairs(step.widgets or {}) do
			if type(def) ~= 'table' or not Setup.WIDGET_TYPES[def.type] then
				Problem('widget "' .. tostring(key) .. '" has an unknown type ' .. tostring(type(def) == 'table' and def.type or def))
			else
				if def.set ~= nil and type(def.set) ~= 'function' then
					Problem('widget "' .. tostring(key) .. '" set must be a function: set(info, value)')
				end
				if def.get ~= nil and type(def.get) ~= 'function' then
					Problem('widget "' .. tostring(key) .. '" get must be a function')
				end
			end
		end
	elseif kind == 'custom' then
		if type(step.build) ~= 'function' then
			Problem('custom steps need build(frame, ctx)')
		end
		if step.onShow ~= nil and type(step.onShow) ~= 'function' then
			Problem('onShow must be a function')
		end
	end
	return problems
end

----------------------------------------------------------------------------------------------------
-- Registration object
----------------------------------------------------------------------------------------------------

---@class LibAT.SetupRegistration
---@field id string
---@field name string
---@field config LibAT.SetupConfig
---@field steps LibAT.SetupStep[]
---@field whatsNew LibAT.SetupWhatsNew[]
---@field legacy? boolean
---@field detected? 'fresh'|'upgrade'|'converted'
local Registration = {}
Registration.__index = Registration
Setup.Registration = Registration

---Sort steps by order. Old-style child pages stay right after their parent.
function Registration:SortSteps()
	local top, children = {}, {}
	for _, step in ipairs(self.steps) do
		if step._parentId then
			children[step._parentId] = children[step._parentId] or {}
			table.insert(children[step._parentId], step)
		else
			top[#top + 1] = step
		end
	end
	local function ByOrder(a, b)
		local oa, ob = a.order or 999, b.order or 999
		if oa ~= ob then
			return oa < ob
		end
		return a._seq < b._seq
	end
	table.sort(top, ByOrder)
	local sorted = {}
	for _, step in ipairs(top) do
		sorted[#sorted + 1] = step
		local kids = children[step.id]
		if kids then
			table.sort(kids, ByOrder)
			for _, child in ipairs(kids) do
				sorted[#sorted + 1] = child
			end
		end
	end
	self.steps = sorted
end

---Add a step. Returns the step, or nil when it has problems (they are logged).
---@param step LibAT.SetupStep
---@return LibAT.SetupStep|nil
function Registration:AddStep(step)
	local problems = Setup:ValidateStep(self, step)
	if #problems > 0 then
		Log('error', self.id .. ' step "' .. tostring(type(step) == 'table' and step.id) .. '" was not added: ' .. table.concat(problems, '; '))
		return nil
	end
	seq = seq + 1
	step._seq = seq
	if step.kind == 'custom' and step.cache == nil and not step._legacyPage then
		step.cache = true
	end
	self.steps[#self.steps + 1] = step
	self:SortSteps()
	if Setup.Hub and Setup.Hub.OnRegistrationChanged then
		Setup.Hub:OnRegistrationChanged(self)
	end
	return step
end

---Remove a step
---@param stepId string
function Registration:RemoveStep(stepId)
	for i = #self.steps, 1, -1 do
		if self.steps[i].id == stepId then
			table.remove(self.steps, i)
		end
	end
	if Setup.Hub and Setup.Hub.OnRegistrationChanged then
		Setup.Hub:OnRegistrationChanged(self)
	end
end

---@param stepId string
---@return LibAT.SetupStep|nil
function Registration:GetStep(stepId)
	for _, step in ipairs(self.steps) do
		if step.id == stepId then
			return step
		end
	end
	return nil
end

---Add a "What's new" entry. Only the newest entry the player has not seen is shown.
---@param version string|number
---@param spec {title: string, caption?: string, art?: LibAT.CardArt, action?: {text?: string, options?: string|fun(), step?: string}}
---@return boolean added
function Registration:AddWhatsNew(version, spec)
	if (type(version) ~= 'string' and type(version) ~= 'number') or type(spec) ~= 'table' or type(spec.title) ~= 'string' then
		Log('error', self.id .. ' AddWhatsNew needs (version, { title = ... })')
		return false
	end
	local entry = {
		version = tostring(version),
		title = spec.title,
		caption = spec.caption,
		art = spec.art,
		action = spec.action,
	}
	for i, existing in ipairs(self.whatsNew) do
		if existing.version == entry.version then
			self.whatsNew[i] = entry
			return true
		end
	end
	self.whatsNew[#self.whatsNew + 1] = entry
	return true
end

---Is this addon waiting for the player?
---@return boolean
function Registration:IsPending()
	return Setup:IsPending(self.id)
end

---Open the setup window at this addon
---@param stepId? string
function Registration:Open(stepId)
	Setup:Open(self.id, stepId)
end

----------------------------------------------------------------------------------------------------
-- Public API
----------------------------------------------------------------------------------------------------

---Register an addon with Setup. Call it from your addon's OnInitialize, before you create your
---database, so isExistingUser can still tell a new install from an old one.
---@param addonId string Unique id, e.g. 'libs-databar'
---@param config LibAT.SetupConfig
---@return LibAT.SetupRegistration|nil registration
function Setup:Register(addonId, config)
	if type(addonId) ~= 'string' or addonId == '' or type(config) ~= 'table' then
		Log('error', 'Register needs (addonId, config)')
		return nil
	end
	if type(config.name) ~= 'string' then
		Log('error', addonId .. ' Register: config.name is required')
		return nil
	end
	for _, field in ipairs({ 'isExistingUser', 'isNewProfile', 'profileKey', 'onComplete' }) do
		if config[field] ~= nil and type(config[field]) ~= 'function' then
			Log('error', addonId .. ' Register: ' .. field .. ' must be a function')
			config[field] = nil
		end
	end
	if config.scope ~= nil and config.scope ~= 'account' and config.scope ~= 'profile' then
		Log('error', addonId .. " Register: scope must be 'account' or 'profile'")
		config.scope = nil
	end

	local reg = self.registrations[addonId]
	if reg then
		for k, v in pairs(config) do
			reg.config[k] = v
		end
		reg.name = reg.config.name
		return reg
	end

	seq = seq + 1
	reg = setmetatable({
		id = addonId,
		name = config.name,
		config = config,
		steps = {},
		whatsNew = {},
		_seq = seq,
	}, Registration)
	self.registrations[addonId] = reg
	self.order[#self.order + 1] = addonId

	if not config._legacy then
		local folder = config.addonName
		if folder and C_AddOns and C_AddOns.IsAddOnLoaded and not C_AddOns.IsAddOnLoaded(folder) and not IsLoggedIn() then
			reg.waitForAddon = folder
		else
			self:Detect(reg)
		end
	else
		reg.legacy = true
	end

	if self.Hub and self.Hub.OnRegistrationChanged then
		self.Hub:OnRegistrationChanged(reg)
	end
	return reg
end

---Remove an addon from Setup (its saved state is kept)
---@param addonId string
function Setup:Unregister(addonId)
	if not self.registrations[addonId] then
		return
	end
	self.registrations[addonId] = nil
	for i = #self.order, 1, -1 do
		if self.order[i] == addonId then
			table.remove(self.order, i)
		end
	end
	if self.Hub and self.Hub.OnRegistrationChanged then
		self.Hub:OnRegistrationChanged()
	end
end

---Registered addon by id
---@param addonId string
---@return LibAT.SetupRegistration|nil
function Setup:GetRegistration(addonId)
	return addonId and self.registrations[addonId] or nil
end

---Registrations sorted by priority, then registration order
---@return LibAT.SetupRegistration[]
function Setup:GetSortedRegistrations()
	local list = {}
	for _, id in ipairs(self.order) do
		list[#list + 1] = self.registrations[id]
	end
	table.sort(list, function(a, b)
		local pa = a.config.priority or Setup.DEFAULT_PRIORITY
		local pb = b.config.priority or Setup.DEFAULT_PRIORITY
		if pa ~= pb then
			return pa < pb
		end
		return a._seq < b._seq
	end)
	return list
end

---Is this addon waiting for the player? Addon-owned first-run popups should stay quiet while it is.
---@param addonId string
---@return boolean
function Setup:IsPending(addonId)
	local reg = self.registrations[addonId]
	if not reg then
		return false
	end
	reg.forceDetect = true
	return #self:GetDueSteps(reg) > 0
end

---State of an addon: 'pending', 'done', 'skipped', or nil when unknown
---@param addonId string
---@return string|nil status
---@return LibAT.SetupRecord|nil record
function Setup:GetStatus(addonId)
	local reg = self.registrations[addonId]
	if not reg then
		return nil, nil
	end
	reg.forceDetect = true
	local rec = self:GetRecord(reg)
	return rec and rec.status, rec
end

---Addons that are due, in priority order
---@param forAutoOpen? boolean Leave out muted addons and those closed three times
---@return LibAT.SetupRegistration[]
function Setup:GetDueAddons(forAutoOpen)
	local list = {}
	for _, reg in ipairs(self:GetSortedRegistrations()) do
		local rec = self:GetRecord(reg)
		if rec and #self:GetDueSteps(reg) > 0 then
			local skip = forAutoOpen and (rec.muted or (rec.remind or 0) >= Setup.MAX_REMINDERS)
			if not skip then
				list[#list + 1] = reg
			end
		end
	end
	return list
end

---Mark an addon finished. byPlayer runs its onComplete the first time.
---@param reg LibAT.SetupRegistration
---@param byPlayer? boolean
function Setup:MarkDone(reg, byPlayer)
	local rec = self:GetRecord(reg)
	if not rec then
		return
	end
	local wasDone = rec.status == 'done'
	rec.status = 'done'
	StampProfile(reg, rec)
	if not wasDone then
		Log('info', reg.id .. ' setup finished')
	end
	if byPlayer and not rec.completeRan and reg.config.onComplete then
		rec.completeRan = true
		SafeCall(reg.id .. ' onComplete', reg.config.onComplete)
	end
	if self.Hub and self.Hub.OnStatusChanged then
		self.Hub:OnStatusChanged(reg)
	end
end

---Mark an addon skipped: it will not be shown again unless the player opens it.
---@param reg LibAT.SetupRegistration
function Setup:MarkSkipped(reg)
	local rec = self:GetRecord(reg)
	if not rec then
		return
	end
	if rec.status == 'pending' then
		rec.status = 'skipped'
		Log('info', reg.id .. ' setup skipped')
	end
	StampProfile(reg, rec)
	if self.Hub and self.Hub.OnStatusChanged then
		self.Hub:OnStatusChanged(reg)
	end
end

---Turn "Don't show this again" on or off for an addon
---@param addonId string
---@param muted boolean
function Setup:SetMuted(addonId, muted)
	local reg = self.registrations[addonId]
	local rec = reg and self:GetRecord(reg)
	if rec then
		rec.muted = muted and true or nil
	end
end

---Make an addon due again, as if it was just installed
---@param addonId string
function Setup:Reset(addonId)
	local reg = self.registrations[addonId]
	local rec = reg and self:GetRecord(reg)
	if rec then
		rec.status = 'pending'
		rec.remind = 0
		rec.muted = nil
		rec.profiles = {}
	end
end

---Should the window open by itself after login?
---@return boolean
function Setup:GetAutoOpen()
	local store = self:GetStore()
	return not store or store.autoOpen ~= false
end

---@param enabled boolean
function Setup:SetAutoOpen(enabled)
	local store = self:GetStore()
	if store then
		store.autoOpen = enabled and true or false
	end
end

----------------------------------------------------------------------------------------------------
-- Recommended settings
----------------------------------------------------------------------------------------------------

---Apply the recommended value of each step and finish the addon. Values that already match are not
---written, so the addon's saved settings stay as small as they were.
---@param reg LibAT.SetupRegistration
---@param steps? LibAT.SetupStep[] Default: the addon's due steps
function Setup:ApplyRecommended(reg, steps)
	steps = steps or self:GetDueSteps(reg)
	for _, step in ipairs(steps) do
		local ctx = self:CreateContext(reg, step)
		ctx.recommendedRun = true
		if step.kind == 'look' or step.kind == 'choice' then
			local recommended = self:GetRecommended(step)
			if recommended ~= nil then
				local ok, current = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get)
				if not ok or current ~= recommended then
					self:CallSet(reg, step, ctx, recommended)
				end
			end
		elseif step.kind == 'toggles' then
			for _, item in ipairs(self:GetToggleItems(step)) do
				if item.recommended ~= nil and not item.core then
					local ok, current = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get, item.key)
					local want = item.recommended and true or false
					if not ok or (current and true or false) ~= want then
						self:CallToggle(reg, step, ctx, item, want, current and true or false)
					end
				end
			end
		end
	end
	self:MarkDone(reg, true)
end

---Call a look/choice setter as set(value, ctx) and catch the old set(info, value) mistake
---@param reg LibAT.SetupRegistration
---@param step LibAT.SetupStep
---@param ctx LibAT.SetupContext
---@param value any
---@return boolean ok
function Setup:CallSet(reg, step, ctx, value)
	local ok = SafeCall(reg.id .. '.' .. step.id .. ' set', step.set, value, ctx)
	if ok and type(step.get) == 'function' then
		local gotOk, now = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get)
		if gotOk and rawequal(now, ctx) then
			Log('error', reg.id .. '.' .. step.id .. ': set stored its second argument. Setup steps call set(value, ctx), not set(info, value)')
		end
	end
	return ok
end

---Call a toggles setter as set(key, value, ctx), and stage a reload when the item needs one
---@param reg LibAT.SetupRegistration
---@param step LibAT.SetupStep
---@param ctx LibAT.SetupContext
---@param item LibAT.SetupToggle
---@param value boolean
---@param original? boolean Value before the player started changing it
---@return boolean ok
function Setup:CallToggle(reg, step, ctx, item, value, original)
	local ok = SafeCall(reg.id .. '.' .. step.id .. ' set', step.set, item.key, value, ctx)
	if ok and type(step.get) == 'function' then
		local gotOk, now = SafeCall(reg.id .. '.' .. step.id .. ' get', step.get, item.key)
		if gotOk and (rawequal(now, ctx) or type(now) == 'table') then
			Log('error', reg.id .. '.' .. step.id .. ': toggles call set(key, value, ctx) and get(key) should return true or false')
		end
	end
	if item.needsReload then
		local key = 'toggle:' .. step.id .. ':' .. tostring(item.key)
		if original ~= nil and value == original then
			ctx:CancelReload(key)
		else
			ctx:NeedsReload(key, item.title .. (value and ' (on)' or ' (off)'))
		end
	end
	return ok
end

----------------------------------------------------------------------------------------------------
-- Reload staging
----------------------------------------------------------------------------------------------------

---Stage a change that needs a reload. Staging the same key again replaces it.
---@param key string
---@param label string What the player sees in the list
---@param apply? fun() Runs just before the reload (in a pcall)
---@param addonId? string
function Setup:StageReload(key, label, apply, addonId)
	if type(key) ~= 'string' or key == '' then
		Log('error', 'NeedsReload needs a key')
		return
	end
	if apply ~= nil and type(apply) ~= 'function' then
		Log('error', 'NeedsReload "' .. key .. '": apply must be a function')
		apply = nil
	end
	for _, entry in ipairs(self.staged) do
		if entry.key == key then
			entry.label = label or entry.label
			entry.apply = apply
			entry.addonId = addonId
			self:OnStagedChanged()
			return
		end
	end
	self.staged[#self.staged + 1] = { key = key, label = label or key, apply = apply, addonId = addonId }
	self:OnStagedChanged()
end

---Remove a staged change
---@param key string
function Setup:CancelReload(key)
	for i = #self.staged, 1, -1 do
		if self.staged[i].key == key then
			table.remove(self.staged, i)
		end
	end
	self:OnStagedChanged()
end

---@return number
function Setup:GetStagedCount()
	return #self.staged
end

function Setup:OnStagedChanged()
	if self.Hub and self.Hub.OnStagedChanged then
		self.Hub:OnStagedChanged()
	end
end

---Run every staged change, each in its own pcall, and clear the list
---@return number applied
---@return number failed
function Setup:ApplyStaged()
	local list = self.staged
	self.staged = {}
	local applied, failed = 0, 0
	for _, entry in ipairs(list) do
		if entry.apply then
			local ok, err = pcall(entry.apply)
			if ok then
				applied = applied + 1
			else
				failed = failed + 1
				Log('error', 'Change "' .. tostring(entry.label) .. '" failed: ' .. tostring(err))
			end
		else
			applied = applied + 1
		end
	end
	self:OnStagedChanged()
	return applied, failed
end

---Mark the addons of a finished run done, leaving skipped ones skipped
---@param regs? LibAT.SetupRegistration[]
function Setup:FinishRegistrations(regs)
	for _, reg in ipairs(regs or {}) do
		local rec = self:GetRecord(reg)
		if rec and rec.status ~= 'skipped' then
			self:MarkDone(reg, true)
		end
	end
end

---Finish the given addons, run the staged changes and reload once. Refused in combat.
---@param regs? LibAT.SetupRegistration[]
---@return boolean started
function Setup:FinishAndReload(regs)
	if self.inCombat then
		Log('info', 'Finish and reload waits until combat ends')
		return false
	end
	self:FinishRegistrations(regs)
	self:ApplyStaged()
	if LibAT.SafeReloadUI then
		return LibAT:SafeReloadUI(false)
	end
	ReloadUI()
	return true
end

---Finish the given addons and keep staged changes for the next reload
---@param regs? LibAT.SetupRegistration[]
function Setup:FinishWithoutReload(regs)
	self:FinishRegistrations(regs)
	local count = #self.staged
	if count > 0 and self.Hub and self.Hub.ShowToast then
		local text = count == 1 and '1 change will apply the next time you reload.' or (count .. ' changes will apply the next time you reload.')
		self.Hub:ShowToast(text, 'Reload now', function()
			Setup:FinishAndReload()
		end)
	end
end

----------------------------------------------------------------------------------------------------
-- Step context
----------------------------------------------------------------------------------------------------

---@class LibAT.SetupContext
---@field addonId string
---@field stepId string
---@field registration LibAT.SetupRegistration
---@field step LibAT.SetupStep
---@field frame? Frame The page frame (custom steps)
---@field recommendedRun? boolean
local Context = {}
Context.__index = Context
Setup.Context = Context

---Stage a change that needs a reload. Steps never reload by themselves: apply runs when the player
---presses "Finish and reload" (or at the next reload if they finish without reloading).
---@param key string Unique within this addon; staging the same key again replaces it
---@param label string Short text for the list, e.g. 'Use SpartanUI action bars'
---@param apply? fun() Optional work to do just before the reload
function Context:NeedsReload(key, label, apply)
	Setup:StageReload(self.addonId .. ':' .. tostring(key), label, apply, self.addonId)
end

---Remove a staged change
---@param key string
function Context:CancelReload(key)
	Setup:CancelReload(self.addonId .. ':' .. tostring(key))
end

---Draw the step again (for example after a setting changed what it shows)
function Context:Refresh()
	if Setup.Hub and Setup.Hub.RenderCurrent then
		Setup.Hub:RenderCurrent()
	end
end

---Go to the next step
function Context:Next()
	if Setup.Hub and Setup.Hub.GoNext then
		Setup.Hub:GoNext()
	end
end

---Go back one step
function Context:Back()
	if Setup.Hub and Setup.Hub.GoBack then
		Setup.Hub:GoBack()
	end
end

---Tell the window how tall a custom page is, so it scrolls
---@param height number
function Context:SetHeight(height)
	self.height = height
	if self.frame then
		self.frame:SetHeight(math.max(height or 1, 1))
	end
	if Setup.Hub and Setup.Hub.UpdateScrollHeight then
		Setup.Hub:UpdateScrollHeight()
	end
end

---Show a short message
---@param text string
function Context:Toast(text)
	if Setup.Hub and Setup.Hub.ShowToast then
		Setup.Hub:ShowToast(text)
	end
end

---True when the step runs because the player chose recommended settings
---@return boolean
function Context:IsRecommendedRun()
	return self.recommendedRun and true or false
end

---True while the player is in combat
---@return boolean
function Context:InCombat()
	return Setup.inCombat and true or false
end

---Tell LibAT the accent color may have changed (the window repaints)
function Context:AccentChanged()
	LibAT.UI.NotifyAccentChanged()
end

---Create the context handed to a step's functions
---@param reg LibAT.SetupRegistration
---@param step LibAT.SetupStep
---@return LibAT.SetupContext
function Setup:CreateContext(reg, step)
	return setmetatable({ addonId = reg.id, stepId = step.id, registration = reg, step = step }, Context)
end

----------------------------------------------------------------------------------------------------
-- What's new
----------------------------------------------------------------------------------------------------

---Compare two version strings by their numbers ('2.10.0' > '2.9.1')
---@param a string
---@param b string
---@return number -1, 0 or 1
function Setup.CompareVersions(a, b)
	local na, nb = {}, {}
	for n in tostring(a):gmatch('%d+') do
		na[#na + 1] = tonumber(n)
	end
	for n in tostring(b):gmatch('%d+') do
		nb[#nb + 1] = tonumber(n)
	end
	for i = 1, math.max(#na, #nb) do
		local x, y = na[i] or 0, nb[i] or 0
		if x ~= y then
			return x < y and -1 or 1
		end
	end
	if tostring(a) == tostring(b) then
		return 0
	end
	return tostring(a) < tostring(b) and -1 or 1
end

---Newest What's new entry of an addon
---@param reg LibAT.SetupRegistration
---@return LibAT.SetupWhatsNew|nil
function Setup:GetNewestWhatsNew(reg)
	local newest
	for _, entry in ipairs(reg.whatsNew) do
		if not newest or Setup.CompareVersions(entry.version, newest.version) > 0 then
			newest = entry
		end
	end
	return newest
end

---Newest entry the player has not seen yet
---@param reg LibAT.SetupRegistration
---@return LibAT.SetupWhatsNew|nil
function Setup:GetUnseenWhatsNew(reg)
	local newest = self:GetNewestWhatsNew(reg)
	local rec = newest and self:GetRecord(reg)
	if not newest or not rec then
		return nil
	end
	if rec.whatsNew and Setup.CompareVersions(newest.version, rec.whatsNew) <= 0 then
		return nil
	end
	return newest
end

---Addons with an unseen What's new entry
---@return LibAT.SetupRegistration[]
function Setup:GetUnseenWhatsNewAddons()
	local list = {}
	for _, reg in ipairs(self:GetSortedRegistrations()) do
		if self:GetUnseenWhatsNew(reg) then
			list[#list + 1] = reg
		end
	end
	return list
end

---Remember the newest entry as seen
---@param reg LibAT.SetupRegistration
function Setup:MarkWhatsNewSeen(reg)
	local newest = self:GetNewestWhatsNew(reg)
	local rec = self:GetRecord(reg)
	if newest and rec then
		rec.whatsNew = newest.version
	end
end

---Run a What's new or options action
---@param reg LibAT.SetupRegistration
---@param action? {options?: string|fun(), step?: string}
function Setup:RunAction(reg, action)
	action = action or {}
	if action.step then
		self:Open(reg.id, action.step)
		return
	end
	local target = action.options or reg.config.optionsCommand
	if type(target) == 'function' then
		SafeCall(reg.id .. ' options action', target)
		if self.Hub then
			self.Hub:Close()
		end
	elseif type(target) == 'string' then
		if self:RunSlashCommand(target) and self.Hub then
			self.Hub:Close()
		end
	else
		self:Open(reg.id)
	end
end

---Run a slash command such as '/ldb config' by finding its handler
---@param text string
---@return boolean ran
function Setup:RunSlashCommand(text)
	local command, rest = text:match('^(/%S+)%s*(.*)$')
	if not command then
		return false
	end
	command = command:lower()
	for key, handler in pairs(SlashCmdList or {}) do
		local i = 1
		while true do
			local slash = _G['SLASH_' .. key .. i]
			if not slash then
				break
			end
			if slash:lower() == command then
				SafeCall('slash command ' .. command, handler, rest or '')
				return true
			end
			i = i + 1
		end
	end
	Log('warning', 'No slash command ' .. command)
	return false
end

----------------------------------------------------------------------------------------------------
-- Login, combat and slash commands
----------------------------------------------------------------------------------------------------

---Find an addon by id or a piece of its name ('databar' finds 'libs-databar')
---@param query string
---@return LibAT.SetupRegistration|nil
function Setup:FindRegistration(query)
	local function Simplify(text)
		text = tostring(text or ''):lower():gsub('[^%w]', '')
		return text
	end
	local wanted = Simplify(query)
	if wanted == '' then
		return nil
	end
	local partial
	for _, reg in ipairs(self:GetSortedRegistrations()) do
		local id = Simplify(reg.id)
		local name = Simplify(reg.name)
		local shortId = id:gsub('^libs', '')
		local shortName = name:gsub('^libs', '')
		if wanted == id or wanted == name or wanted == shortId or wanted == shortName then
			return reg
		end
		if not partial and (id:find(wanted, 1, true) or name:find(wanted, 1, true)) then
			partial = reg
		end
	end
	return partial
end

---Open the setup window. With no addon: the Start page when several addons are due, otherwise the
---first unfinished step. With an addon: that addon's steps (all of them when it is already done).
---@param addonId? string
---@param stepId? string
function Setup:Open(addonId, stepId)
	if not self.Hub then
		return
	end
	self.Hub:Open(addonId, stepId)
end

---Close the window
function Setup:Close()
	if self.Hub then
		self.Hub:Close()
	end
end

---Handle /setup and /libat setup
---@param msg? string Anything after the command
function Setup:HandleSlash(msg)
	msg = strtrim and strtrim(msg or '') or (msg or '')
	if msg == '' then
		if self.Hub and self.Hub:IsShown() then
			self.Hub:Close()
		else
			self:Open()
		end
		return
	end
	local reg = self:FindRegistration(msg)
	if reg then
		self:Open(reg.id)
		return
	end
	local names = {}
	for _, r in ipairs(self:GetSortedRegistrations()) do
		names[#names + 1] = r.id
	end
	LibAT:Print('No setup found for "' .. msg .. '". Try: ' .. (#names > 0 and table.concat(names, ', ') or 'none registered'))
end

---After login: decide who is new, stamp What's new for new installs, and open the window or show a toast
function Setup:OnLoginReady()
	if self.loginReady then
		return
	end
	self.loginReady = true
	FlushLogs()
	if not self:GetStore() then
		return
	end

	for _, reg in ipairs(self:GetSortedRegistrations()) do
		reg.waitForAddon = nil
		self:GetRecord(reg)
		-- New installs have nothing to catch up on
		if reg.createdThisSession and reg.detected == 'fresh' then
			self:MarkWhatsNewSeen(reg)
		end
	end

	local due = self:GetDueAddons(true)
	if #due > 0 then
		if not self:GetAutoOpen() then
			local text = #due == 1 and (due[1].name .. ' is ready to set up.') or (#due .. ' addons are ready to set up.')
			if self.Hub then
				self.Hub:ShowToast(text, 'Set up', function()
					Setup:Open()
				end)
			end
		elseif self.inCombat then
			self.openAfterCombat = true
		else
			self:AutoOpen()
		end
		return
	end

	self:ShowWhatsNewToast()
end

---Open the window by itself, once per session
function Setup:AutoOpen()
	if self.autoOpened or not self.Hub then
		return
	end
	if self.Hub:IsShown() then
		self.autoOpened = true
		return
	end
	self.autoOpened = true
	self.Hub.autoOpenedThisSession = true
	self.Hub:Open(nil, nil, true)
end

---Toast for addons that were updated with something new to show
function Setup:ShowWhatsNewToast()
	local unseen = self:GetUnseenWhatsNewAddons()
	if #unseen == 0 or not self.Hub then
		return
	end
	local text
	if #unseen == 1 then
		local entry = self:GetUnseenWhatsNew(unseen[1])
		text = unseen[1].name .. ': ' .. (entry and entry.title or 'new features')
	else
		text = 'New in ' .. #unseen .. ' of your addons.'
	end
	self.Hub:ShowToast(text, "See what's new", function()
		Setup.Hub:OpenWhatsNew()
	end, {
		onDismiss = function()
			for _, reg in ipairs(unseen) do
				Setup:MarkWhatsNewSeen(reg)
			end
		end,
	})
end

local eventFrame = CreateFrame('Frame')
Setup.eventFrame = eventFrame
eventFrame:RegisterEvent('PLAYER_REGEN_DISABLED')
eventFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
eventFrame:RegisterEvent('PLAYER_LOGOUT')
eventFrame:RegisterEvent('ADDON_LOADED')
eventFrame:SetScript('OnEvent', function(_, event, arg1)
	if event == 'PLAYER_REGEN_DISABLED' then
		-- InCombatLockdown() is still false while this event runs, so the event itself means combat
		Setup.inCombat = true
		if Setup.Hub then
			Setup.Hub:OnCombatChanged(true)
		end
	elseif event == 'PLAYER_REGEN_ENABLED' then
		Setup.inCombat = false
		if Setup.Hub then
			Setup.Hub:OnCombatChanged(false)
		end
		if Setup.openAfterCombat then
			Setup.openAfterCombat = nil
			Setup:AutoOpen()
		end
	elseif event == 'ADDON_LOADED' then
		for _, reg in pairs(Setup.registrations) do
			if reg.waitForAddon and reg.waitForAddon == arg1 then
				reg.waitForAddon = nil
				Setup:Detect(reg)
			end
		end
	elseif event == 'PLAYER_LOGOUT' then
		-- Changes the player finished without reloading are applied now, before saved variables are written
		if #Setup.staged > 0 then
			Setup:ApplyStaged()
		end
	elseif event == 'PLAYER_LOGIN' then
		eventFrame:UnregisterEvent('PLAYER_LOGIN')
		Setup:ScheduleLoginReady()
	end
end)

function Setup:ScheduleLoginReady()
	-- Addons register from their own OnEnable, which runs after LibAT's in the same login
	C_Timer.After(2, function()
		Setup:OnLoginReady()
	end)
end

---Called from LibAT:OnEnable
function Setup:Enable()
	self.inCombat = (UnitAffectingCombat and UnitAffectingCombat('player')) or InCombatLockdown() or false
	-- AceAddon enables addons while PLAYER_LOGIN is being dispatched, so a PLAYER_LOGIN registered here would never fire
	if IsLoggedIn() then
		self:ScheduleLoginReady()
	else
		eventFrame:RegisterEvent('PLAYER_LOGIN')
	end
end
