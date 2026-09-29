# LibAT.Setup - one first-run window for every addon

`LibAT.Setup` gives your addon a first-run setup in a shared window. You describe the steps; LibAT
draws them, sizes and scrolls them, remembers who has finished, stages anything that needs a
reload, and shows a toast when an update has something new.

Players open it with `/setup`, `/setup <addon>` (for example `/setup databar`) or
`/libat setup [addon]`.

## How it behaves

- **New or existing player.** When you register, LibAT asks your `isExistingUser()` once. New
  players are `pending`; existing players are stamped `done` and never see the window for your
  addon (they get a What's new toast instead).
- **After login** (out of combat, about 2 seconds after login) one window opens for every addon that
  is due, lowest `priority` first. With more than one due addon, a Start page lets the player check
  which to set up now, or use recommended settings for all of them. If the player turned
  "Open after login" off, a small toast appears instead.
- **Done** means the player moved past your last step, pressed Finish, or chose recommended settings.
  Just seeing a page does not finish it.
- **Skip this addon** marks it `skipped`; it is not shown again unless the player opens it.
- **Closing** the window means "remind me next login", at most 3 times. The Start page also has a
  per-addon "Don't show again".
- **Combat.** The window never opens by itself in combat. If combat starts while it is open, it fades
  to 40%, says "Waiting for combat to end", and Finish is blocked.
- **Reloads.** Steps never reload. They stage changes with `ctx:NeedsReload`. "Finish and reload" runs
  every staged change (each in a pcall) and reloads once. "Finish without reloading" keeps them;
  they run at the next reload or logout.

Saved state lives in `LibsAddonToolsDB.global.setup` (account-wide).

## Registering

Call `Register` from your addon's `OnInitialize`, **before** you create your database, so
`isExistingUser` can still tell a new install from an old one.

```lua
local reg = LibAT.Setup:Register('libs-databar', {
	name = "Lib's DataBar",
	icon = 'Interface\\AddOns\\Libs-DataBar\\Logo-Icon',
	summary = 'A thin bar that shows your gold, bags and the time.',
	priority = 50, -- lower opens first; SpartanUI uses 10, the default is 100
	isExistingUser = function()
		return type(LibsDataBarDB) == 'table' and next(LibsDataBarDB) ~= nil
	end,
	optionsCommand = '/ldb', -- string slash command or a function
})

reg:AddStep({
	id = 'position',
	kind = 'choice',
	title = 'Where should the bar go?',
	text = 'You can move it later.',
	choices = {
		{ value = 'top', title = 'Top', caption = 'Across the top of your screen.' },
		{ value = 'bottom', title = 'Bottom', caption = 'Along the bottom edge.', recommended = true },
	},
	get = function()
		return LibsDataBar.db.bars.main.position
	end,
	set = function(value, ctx)
		LibsDataBar:SetMainPosition(value)
	end,
})

reg:AddWhatsNew('2.5.0', {
	title = 'New: travel time',
	caption = 'See how long your flight takes.',
	action = { text = 'Show me', options = '/ldb' },
})
```

### Register config

| Field | Type | Notes |
| --- | --- | --- |
| `name` | string | Required. |
| `icon` | path or file ID | Shown next to the name. |
| `summary` | string | One line for the Start page card. |
| `priority` | number | Lower opens first. Default 100. |
| `isExistingUser` | `fun(): boolean` | True when the player used the addon before. Asked once. |
| `scope` | `'account'` or `'profile'` | Default scope for steps. Default `'account'`. |
| `profileKey` | `fun(): string` | Current profile name. Needed for `scope = 'profile'`. |
| `isNewProfile` | `fun(): boolean` | True when the current profile has never been set up. Strongly recommended with profile steps: without it, a profile LibAT has not seen before (including ones made before Setup existed) is asked once. |
| `optionsCommand` | string or function | Used by "More settings" and by What's new "Show me" when the entry has no action. |
| `onComplete` | `fun()` | Runs once, the first time the player finishes your setup (not when skipped, not for existing users). |
| `addonName` | string | Your folder name. Only needed if you register from a file's main chunk: detection then waits for your ADDON_LOADED. |

`Register` returns a registration object (or nil when the config is bad; the reason is logged).
Registering the same id again updates the config and returns the same object.

### Registration methods

| Method | Notes |
| --- | --- |
| `reg:AddStep(step)` | Returns the step, or nil when it has problems (logged). |
| `reg:RemoveStep(id)` / `reg:GetStep(id)` | |
| `reg:AddWhatsNew(version, spec)` | `spec = { title, caption?, art?, action? = { text?, options?, step? } }`. Only the newest unseen entry is shown. New installs are stamped silently. |
| `reg:IsPending()` | Same as `LibAT.Setup:IsPending(id)`. |
| `reg:Open(stepId?)` | Opens the window at your addon. |

## Steps

Every step has:

| Field | Notes |
| --- | --- |
| `id` | Unique within your addon. |
| `kind` | `look`, `choice`, `toggles`, `import`, `form`, `custom` or `summary`. |
| `title` | Header text. `name` (optional) is the label in the step list. |
| `text` | A short line under the header. |
| `order` | Lower first. |
| `scope` | `'profile'` steps are asked again for a brand-new profile (see `profileKey`, `isNewProfile`). |
| `hidden` | `fun(): boolean` - leave the step out when true. |
| `onLeave` | `fun(ctx)` - called when the player leaves the step. |

**Setters.** Setup steps call `set(value, ctx)` (toggles: `set(key, value, ctx)`). `form` widgets are
`LibAT.UI.BuildWidgets` definitions and keep the AceConfig style `set(info, value)` - write
`set = function(_, value)`. LibAT logs an error when a setter stores the wrong argument.

Every choice has a `recommended` value. Skipping writes nothing; "Use recommended" writes only values
that differ from the current one, so sparse saved settings stay small.

### look

Large picture cards, for themes and presets.

```lua
{
	id = 'theme', kind = 'look', title = 'Pick a look', text = 'This changes the art around your screen.',
	cards = {
		{ value = 'War', title = 'War', caption = 'Red and gold.', tag = 'Classic', recommended = true,
		  art = { texture = 'Interface\\AddOns\\MyAddon\\Previews\\War', texCoord = { 0, 1, 0, 0.62 } },
		  accent = { 0.8, 0.1, 0.1 },
		  variants = { { value = 'dark', text = 'Dark' }, { value = 'light', text = 'Light' } } },
		{ value = 'Fel', title = 'Fel', art = { atlas = 'some-atlas', texture = 'fallback\\path' } },
	},
	get = function() return MyAddon.db.profile.theme end,
	set = function(value, ctx) MyAddon:SetTheme(value) end,
	getVariant = function(value) return MyAddon.db.profile.variants[value] end,        -- only with variants
	setVariant = function(value, variant, ctx) MyAddon:SetVariant(value, variant) end, -- only with variants
	selectedLabel = 'In use', -- optional, this is the default for look steps
}
```

`cards` (and `choices`) may be a function returning the list instead. It is called on every draw,
so a list that an earlier step changes stays current.

`art` takes `texture` (path or file ID), `atlas` (used only when the client has it; otherwise
`texture` or `color` is used), `texCoord = { left, right, top, bottom }`, `color = { r, g, b, a }`,
`desaturate`. The window repaints its accent after every pick, so an accent provider that reads the
picked theme recolors the window live.

### choice

Two to four wide cards with a line saying what happens. Same fields as `look` with `choices`
instead of `cards`; no pictures. The selected card shows "Selected".

### toggles

Grouped toggle cards with "Turn all on" / "Turn all off".

```lua
{
	id = 'modules', kind = 'toggles', title = 'Pick your modules',
	groups = {
		{ title = 'Interface', items = {
			{ key = 'Minimap', title = 'Minimap', caption = 'A square minimap.', recommended = true },
			{ key = 'Chat', title = 'Chat', needsReload = true, recommended = true },
			{ key = 'Core', title = 'Core', core = true }, -- always on, cannot be turned off
		} },
	},
	-- or: items = { ... } for a single group
	get = function(key) return MyAddon:IsModuleEnabled(key) end,
	set = function(key, value, ctx) MyAddon:SetModuleEnabled(key, value) end,
}
```

`set` runs right away. Items with `needsReload` also add "Chat (on)" to the reload list; turning
them back removes it.

### import

Shows only sources that are detected; the step is hidden when there are none. Picking a source
stages its `apply` for "Finish and reload"; "Don't import" is always offered and is the default.

```lua
{
	id = 'import', kind = 'import', title = 'Copy your old setup',
	sources = {
		{ id = 'old', title = 'My old addon', caption = 'Bars and key bindings.',
		  detect = function() return C_AddOns.IsAddOnLoaded('OldAddon') end,
		  apply = function(ctx) MyAddon:ImportFromOld() end },
	},
}
```

### form

`widgets` is a `LibAT.UI.BuildWidgets` definition table. The form is built once, refreshed on later
visits, and sized automatically. Setters are `set(info, value)`.

### custom

The escape hatch: `build(frame, ctx)` fills `frame`. Report the height with `frame:SetHeight(h)`,
`frame.totalHeight = h` or `ctx:SetHeight(h)` so the page scrolls. Custom steps are built once and
`onShow(frame, ctx)` runs on later visits; set `cache = false` to build a new frame every visit
(the old frame is hidden, not freed, so prefer the default).

### summary

Built by the hub: every choice of your addon with its current value and a "Change" link. The window
always ends with a summary of every addon in the run plus the list of changes that need a reload,
so you only need this kind to show a summary in the middle of your own steps.

## The step context (`ctx`)

| Member | Notes |
| --- | --- |
| `ctx.addonId`, `ctx.stepId`, `ctx.registration`, `ctx.step` | |
| `ctx.frame` | The page frame (custom steps). |
| `ctx:NeedsReload(key, label, apply?)` | Stage a change. `key` is unique within your addon; staging it again replaces it. `apply` runs just before the reload, in a pcall. |
| `ctx:CancelReload(key)` | Remove a staged change. |
| `ctx:Refresh()` | Draw the step again. |
| `ctx:Next()` / `ctx:Back()` | Move through the steps. |
| `ctx:SetHeight(h)` | Height of a custom page. |
| `ctx:Toast(text)` | Show a short message. |
| `ctx:IsRecommendedRun()` | True when the set comes from "Use recommended". |
| `ctx:InCombat()` | True while the player is in combat. |
| `ctx:AccentChanged()` | Tell the window the accent color may have changed. |

## Other Setup functions

| Function | Notes |
| --- | --- |
| `LibAT.Setup:IsPending(addonId)` | True while the addon is due. Addon-owned first-run popups should stay quiet while it is. |
| `LibAT.Setup:GetStatus(addonId)` | `'pending'`, `'done'`, `'skipped'` or nil, plus the saved record. |
| `LibAT.Setup:Open(addonId?, stepId?)` | No addon: Start page or first unfinished step. With an addon: its steps (all of them when it is already done), for a "Run setup again" button. |
| `LibAT.Setup:Close()` | |
| `LibAT.Setup:Reset(addonId)` | Make the addon due again. |
| `LibAT.Setup:SetMuted(addonId, muted)` | Per-addon "Don't show this again". |
| `LibAT.Setup:ApplyRecommended(reg, steps?)` | Apply recommended values and finish. |
| `LibAT.Setup:GetStagedCount()` | Changes waiting for a reload. |

## Cards and accent (LibAT.UI)

| Function | Notes |
| --- | --- |
| `LibAT.UI.CreateCardGrid(parent, opts)` | `opts = { minWidth, maxColumns, cardHeight, artHeight, spacing, onClick(card, value), onVariant(card, value, variant), onCheck(card, value, checked) }`. `grid:SetCards(list)` reuses cards, `grid:Layout(width)` returns the height, `grid:GetCard(value)`, `grid:ApplyAccent()`, `grid:Release()`. |
| `LibAT.UI.CreateCard(parent, opts)` | One card. `card:SetData(data)`, `card:SetState(selected, enabled, label)`, `card:SetChecked(bool)`. Data fields: `value, title, caption, tag, art, accent, recommended, variants, variant, checkable, checked, link = { text, onClick }, tooltip, disabled`. |
| `LibAT.UI.SetAccentProvider(fn)` | `fn` returns `r, g, b` (0-1), `{ r, g, b }`, `{ r =, g =, b = }` or `'rrggbb'`. Nil goes back to LibAT red `e21f1f`. |
| `LibAT.UI.GetAccentColor()` / `GetAccentHex()` | |
| `LibAT.UI.NotifyAccentChanged(force?)` | Sends `LIBAT_SETUP_ACCENT_CHANGED (r, g, b)` through AceEvent when the color changed. Listen with `AceEvent:RegisterMessage(LibAT.UI.ACCENT_CHANGED, fn)`. |
| `LibAT.UI.HasAtlas(name)` / `AtlasMarkup(name, size)` | Atlas feature detection. |

## The old API (LibAT.SetupWizard)

`LibAT.SetupWizard:RegisterAddon(id, { name, icon, pages, onComplete })` and
`AddPage(id, page, parentPageId)` still work. Each page becomes a `custom` step; `builder(frame)` is
called as before and the window scrolls by the frame's height or `frame.totalHeight`. Child pages
follow their parent. `GetPage`, `IsAddonComplete`, `OpenWindow`, `ShowPage` and `window` keep
working.

Old saved progress is converted once: an addon with any old saved page is done, and so is one whose
first page's `isComplete()` returns true. The old account-wide "Don't Ask Again" is honored once and
then replaced by the per-addon setting. The old 3 second popup is gone.
