# Lib's - Addon Tools

A shared toolkit that gives you a modern error handler, a profile manager, a macro editor, a Lua console, and more all in one place.

---

## What Does This Addon Do?

**Lib's - Addon Tools** adds a handful of useful tools to your game. You don't need to be a developer to use them! Here's the short version:

### Error Handler

Ever get random Lua errors popping up while you play? This addon replaces WoW's default error popup with a cleaner, more detailed error viewer. Errors are captured quietly in the background and you can browse them whenever you want.

- **Show All** formats every error into one clean, copyable block perfect for pasting into Discord or a GitHub issue.
- **Minimap button** shows how many errors happened this session. Click it to open the error window.
- **Ignore errors** hide the ones you don't care about.
- **Auto-popup** optionally have the window open automatically when a new error happens.
- Errors are color-coded and easy to read.

### Profile Manager

Import and export your addon settings so you can share them with friends or move them between characters.

- Works with most popular AceDB-based addons automatically.
- Built-in support for addons like **Bartender4**, **Masque**, and more.
- Export creates a shareable text string copy it, paste it in Discord, done.
- Import lets you paste a string and load it into your current profile or a new one.

Open it with **`/profiles`**.

### Macro Editor

This addon gives you a full-size macro editor with more room to work than WoW's default.

- Lists all your Account and Character macros.
- Big text area so you can actually see what you're writing.
- Icon picker built in.
- Drag-to-action-bar support.
- Character count so you know when you're near the 255 limit.

Open it with **`/macros`**.

### Lua Console (CLI)

A mini code editor inside WoW. Type Lua code, hit execute, and see the output. You can save scripts for later too.

Open it with **`/lua`**.

### Setup Wizard

Some addons that use this library can register setup pages. If any are available, you'll get a one-time prompt on login to walk through first-time configuration.

Open it anytime with **`/setup`**.

### Quick Commands

| Command          | What It Does                                                    |
| ---------------- | --------------------------------------------------------------- |
| `/libat`         | Shows all available commands                                    |
| `/errors`        | Opens the error viewer                                          |
| `/profiles`      | Opens the profile manager                                       |
| `/macros`        | Opens the macro editor                                          |
| `/cli` or `/lua` | Opens the Lua console                                           |
| `/log`           | Opens the log viewer                                            |
| `/setup`         | Opens the setup wizard                                          |
| `/rl`            | Reloads your UI (safe, won't reload during combat in instances) |

---

## For Developers

Everything below is aimed at addon developers who want to integrate with or build on top of Lib's - Addon Tools.

### Getting Started

Lib's - Addon Tools is an AceAddon-based framework. It registers itself globally as `LibAT` (`_G.LibAT`). All systems are accessible through this namespace.

### Logger System

A structured logging framework with 5 severity levels: **Debug**, **Info**, **Warning**, **Error**, and **Critical**.

Logs are organized in a three-level hierarchy: **Category → SubCategory → SubSubCategory** (auto-detected from dotted source names). Each module can override the global log level or inherit from it.

#### Registering a Logger

```lua
-- Simple registration (single category)
local log = LibAT.Logger.RegisterAddon("MyAddon")
log.info("Addon loaded")
log.debug("Initializing systems...")
log.warning("Something looks off")
log.error("Something went wrong")

-- Advanced registration (multiple categories)
local log = LibAT.Logger.RegisterAddon("MyAddon", { "Combat", "UI", "Data" })
log.Categories["Combat"].info("Combat module loaded")
log.Categories["UI"].debug("Building frames...")

-- Register sub-categories dynamically
local subLog = log:RegisterCategory("Networking")
subLog.info("Connected to server")
```

#### Logger Methods

| Method                       | Description                              |
| ---------------------------- | ---------------------------------------- |
| `log.log(msg, level?)`       | Log at optional level (defaults to Info) |
| `log.debug(msg)`             | Log at Debug level                       |
| `log.info(msg)`              | Log at Info level                        |
| `log.warning(msg)`           | Log at Warning level                     |
| `log.error(msg)`             | Log at Error level                       |
| `log.critical(msg)`          | Log at Critical level                    |
| `log.RegisterCategory(name)` | Create a new sub-category logger         |

Logs are viewable in-game via `/logs` or the DevUI Logs tab. See [Logger-TechDoc.md](Logger-TechDoc.md) for the full technical reference.

### Profile Manager API

Register your addon so users can import/export its settings through the profile manager UI.

```lua
local addonId = LibAT.ProfileManager:RegisterAddon({
    name = "My Addon",       -- Display name
    db = myAceDB,            -- Your AceDB instance
    namespaces = {           -- Optional: named AceDB namespaces
        { name = "Our Bars", db = myAceDB:GetNamespace("Bars") },
    },
    icon = 12345,            -- Optional: icon texture ID
})
```

#### Profile Manager Methods

| Method                            | Description                                                  |
| --------------------------------- | ------------------------------------------------------------ |
| `RegisterAddon(config)`           | Register an addon for profile management. Returns `addonId`. |
| `UnregisterAddon(addonId)`        | Remove a registered addon.                                   |
| `GetRegisteredAddons()`           | Get all registered addons.                                   |
| `ShowExport(addonId, namespace?)` | Open export UI for an addon.                                 |
| `ShowImport(addonId, namespace?)` | Open import UI for an addon.                                 |

#### Auto-Discovery Adapters

You can register a discovery adapter so your addon is automatically available in the profile manager even without explicit registration:

```lua
LibAT.ProfileManager.RegisterDiscoveryAdapter("MyAddon", {
    name = "My Addon",
    savedVariables = "MyAddonDB",
    wrapType = "acedb",  -- or "raw"
})
```

### Setup Wizard API (WIP)

Register setup pages so your addon can guide users through first-time configuration.

```lua
LibAT.SetupWizard:RegisterAddon("myaddon", {
    name = "My Addon",
    icon = 12345,  -- Optional
    pages = {
        {
            id = "welcome",
            name = "Welcome",
            builder = function(contentFrame)
                -- Build your setup UI into contentFrame
            end,
            isComplete = function()
                return MyAddonDB.setupDone == true
            end,
        },
    },
    onComplete = function()
        -- Called when user clicks Finish on the last page
    end,
})
```

#### Setup Wizard Methods

| Method                                              | Description                                |
| --------------------------------------------------- | ------------------------------------------ |
| `RegisterAddon(addonId, config)`                    | Register setup pages.                      |
| `UnregisterAddon(addonId)`                          | Remove setup pages.                        |
| `IsPageComplete(addonId, pageId)`                   | Check if a page is complete.               |
| `IsAddonComplete(addonId)`                          | Check if all pages are complete.           |
| `HasUncompletedAddons()`                            | Check if any addons have incomplete setup. |
| `OpenWindow()` / `CloseWindow()` / `ToggleWindow()` | Control the wizard window.                 |

### UI Component Library (WIP)

A shared UI toolkit styled after Blizzard's AuctionHouse frames. Used internally by all systems but available for other addons.

#### Window Creation

```lua
local window = LibAT.UI.CreateWindow({
    name = "MyWindow",
    title = "My Addon",
    width = 800,
    height = 600,
    portrait = texturePath,  -- Optional
    resizable = true,        -- Optional
})

local controlFrame = LibAT.UI.CreateControlFrame(window)
local contentFrame = LibAT.UI.CreateContentFrame(window, controlFrame)
local leftPanel = LibAT.UI.CreateLeftPanel(contentFrame)
local rightPanel = LibAT.UI.CreateRightPanel(contentFrame, leftPanel)
```

#### Widget Builder

Declarative widget creation from definition tables (similar to AceConfig):

```lua
LibAT.UI.BuildWidgets(container, {
    enabled = {
        type = "checkbox",
        name = "Enable Feature",
        order = 1,
        get = function() return db.enabled end,
        set = function(val) db.enabled = val end,
    },
    scale = {
        type = "slider",
        name = "UI Scale",
        order = 2,
        min = 0.5, max = 2.0, step = 0.1,
        get = function() return db.scale end,
        set = function(val) db.scale = val end,
    },
    apply = {
        type = "button",
        name = "Apply",
        order = 3,
        func = function() ApplySettings() end,
    },
})
```

Supported widget types: `button`, `slider`, `checkbox`, `dropdown`, `header`, `description`, `divider`.

#### Available UI Components

| Function                                              | Description                    |
| ----------------------------------------------------- | ------------------------------ |
| `CreateButton(parent, w, h, text, black?)`            | Standard or AH-styled button   |
| `CreateFilterButton(parent, name?)`                   | Navigation list button         |
| `CreateIconButton(parent, normal, highlight, pushed)` | Icon-only button               |
| `CreateSearchBox(parent, width)`                      | Search input with clear button |
| `CreateEditBox(parent, w, h, multiline?)`             | Text input                     |
| `CreateCheckbox(parent, label?)`                      | Checkbox                       |
| `CreateDropdown(parent, text, w, h)`                  | Dropdown menu                  |
| `CreateSlider(parent, w, h, min, max, step)`          | Slider control                 |
| `CreateScrollableTextDisplay(parent)`                 | Scrollable copyable text area  |
| `CreateMultiLineBox(parent, w, h)`                    | Multiline code editor          |
| `CreateNavigationTree(config)`                        | Expandable navigation tree     |

### Developer Tools Commands

Extra slash commands for frame inspection and debugging:

| Command                | Description                                                                       |
| ---------------------- | --------------------------------------------------------------------------------- |
| `/devcon`              | Toggle the WoW Developer Console                                                  |
| `/frame <name> [true]` | Set `_G.FRAME` to the named frame; pass `true` to also open TableAttributeDisplay |
| `/getpoint <name>`     | Print all anchor points for a frame                                               |
| `/texlist <name>`      | List all textures in a frame with paths and draw layers                           |
| `/framelist [opts]`    | Enhanced frame stack at cursor position                                           |

#### Enhanced `/tinspect` & Frame Stack

The addon hooks into Blizzard's `TableAttributeDisplay` (used by `/tinspect` and the Ctrl-click frame stack) to add extra mouse actions on any value row:

| Click            | Action                                                                                  |
| ---------------- | --------------------------------------------------------------------------------------- |
| **Right-click**  | Copies the value text into your chat edit box                                           |
| **Middle-click** | Sets the object to `_G.FRAME` (frames) or `_G.TEX` (textures) for easy `/script` access |
| **Left-click**   | Default Blizzard behavior (drill into the value)                                        |

### Utility Functions

| Function                             | Description                                        |
| ------------------------------------ | -------------------------------------------------- |
| `LibAT:Debug(...)`                   | Print debug output (only when debug mode is on)    |
| `LibAT:SafeReloadUI(showMessage?)`   | Reload UI safely blocks during combat in instances |
| `LibAT:RegisterSystem(name, system)` | Register a named system with the framework         |
