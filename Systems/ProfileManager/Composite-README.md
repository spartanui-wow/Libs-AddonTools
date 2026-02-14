# ProfileManager Composite Export System

## Overview

The Composite Export system allows addons to bundle related dependencies (e.g., SpartanUI + Bartender4 + Edit Mode) into a single export. This eliminates the need for users to export/import multiple profiles separately.

## Quick Start

### Register a Composite (Simple)

```lua
-- In your addon's OnEnable()
LibAT.ProfileManager:RegisterComposite({
    id = 'myaddon_full',
    displayName = 'MyAddon (Full Profile)',
    description = 'Complete setup including action bars and UI positions',
    primaryAddonId = 'myaddon',  -- Your addon's ProfileManager ID

    -- Simple string IDs - BuiltInSystems handles the rest
    components = {
        'bartender4',  -- Built-in: auto-discovered addon
        'editmode',    -- Built-in: Blizzard Edit Mode (Retail only)
        'weakauras',   -- Built-in: WeakAuras addon
    },
})
```

### Built-In Systems

The following systems are pre-configured and only require string IDs:

**Action Bars:**

- `'bartender4'` - Bartender4 Action Bars
- `'dominos'` - Dominos Action Bars

**Blizzard Systems:**

- `'editmode'` - Edit Mode Layout (Retail only)

**Popular Addons:**

- `'weakauras'` - WeakAuras
- `'plater'` - Plater Nameplates
- `'details'` - Details! Damage Meter
- `'elvui'` - ElvUI
- `'betterbags'` - BetterBags

[See BuiltInSystems.lua for complete list]

## Advanced Usage

### Plugin Ecosystem (Self-Registration)

For addons with plugin systems, the core addon creates an empty composite and plugins add themselves:

```lua
-- Core addon (Libs-DataBar)
LibAT.ProfileManager:RegisterComposite({
    id = 'libsdatabar_full',
    displayName = 'Libs-DataBar (All Plugins)',
    primaryAddonId = 'libsdatabar',
    components = {},  -- Empty - plugins will add themselves
})

-- Each plugin adds itself during load
-- In Libs-DataBar-Durability:
LibAT.ProfileManager:AddToComposite('libsdatabar_full', 'discovered_libsdatabar_durability')

-- In Libs-DataBar-Currency:
LibAT.ProfileManager:AddToComposite('libsdatabar_full', 'discovered_libsdatabar_currency')

-- Result: Composite automatically includes all installed plugins
```

### Custom Data Sources

For non-addon systems (custom config, frame positions, etc.):

```lua
LibAT.ProfileManager:RegisterComposite({
    id = 'myui_full',
    primaryAddonId = 'myui',
    components = {
        'bartender4',  -- Built-in

        -- Custom component with export/import handlers
        {
            id = 'custom_positions',
            displayName = 'Custom Frame Positions',
            isAvailable = function()
                return MyAddon.HasCustomPositions()
            end,
            export = function()
                return { positions = MyAddon.GetAllPositions() }
            end,
            import = function(data)
                MyAddon.RestorePositions(data.positions)
                return true  -- success
            end,
        },
    },
})
```

## User Experience

### Export Flow

1. User runs `/myaddon export` or opens `/profiles`
2. Sees two buttons in right panel:
   - **MyAddon Only** (addon settings only)
   - **Full MyAddon Stack** (MyAddon, Bartender4, Edit Mode)
3. Clicks "Full Stack" → Side panel opens with component checkboxes
4. Toggles checkboxes → Export auto-updates in real-time
5. Copies export string with all selected components

### Import Flow

1. User pastes composite export into `/profiles`
2. System detects composite format automatically
3. Shows confirmation dialog with component breakdown
4. Imports all available components (gracefully skips missing ones)
5. Success message: "Imported 3 component(s). Please /reload"

## API Reference

### RegisterComposite

```lua
LibAT.ProfileManager:RegisterComposite(config)
```

**Parameters:**

- `id` (string) - Unique composite ID
- `displayName` (string) - User-friendly name
- `description` (string) - Optional description
- `primaryAddonId` (string) - Your addon's ProfileManager ID (always included)
- `components` (table) - Array of component IDs or definitions

**Component Formats:**

- String: `'bartender4'` (uses built-in system)
- Table: `{ id, displayName, isAvailable, export, import }` (custom)

### AddToComposite

```lua
LibAT.ProfileManager:AddToComposite(compositeId, component)
```

**Parameters:**

- `compositeId` (string) - The composite ID to add to
- `component` (string|table) - Component ID or definition

**Returns:** `success (boolean), error (string|nil)`

### GetComposite

```lua
local composite = LibAT.ProfileManager:GetComposite(compositeId)
```

**Returns:** Composite definition or `nil`

### GetCompositeForAddon

```lua
local compositeId = LibAT.ProfileManager:GetCompositeForAddon(addonId)
```

**Returns:** Composite ID if addon has one registered, otherwise `nil`

## Export Format

### Composite Export (v4.0.0)

```lua
{
    version = '4.0.0',
    format = 'ProfileManager_Composite',
    compositeId = 'spartanui_full',
    timestamp = '2026-02-11 02:30:00',

    components = {
        spartanui = {
            version = '3.0.0',
            addon = 'SpartanUI',
            addonId = 'spartanui',
            data = { ... },  -- All SUI namespaces
            profiles = { ... },
            activeProfile = 'Default',
        },

        bartender4 = {
            version = '3.0.0',
            addon = 'Bartender4',
            addonId = 'discovered_bartender4',
            data = { ... },
            profiles = { ... },
        },

        editmode = {
            version = '1.0.0',
            format = 'EditMode_Layout',
            layoutInfo = '...',  -- Base64-encoded
            accountSettings = { ... },
        },
    },

    included = {
        spartanui = true,
        bartender4 = true,
        editmode = true,
    },
}
```

### Backward Compatibility

- **Single-addon exports (v3.0.0)** continue to work via existing ProfileManager import
- **Format detection** is automatic - no user action required
- **Version check** rejects major versions > 4

## Adding New Built-In Systems

To add a new system to BuiltInSystems.lua:

```lua
newsystem = {
    displayName = 'New System Name',
    addonId = 'discovered_newsystem',  -- ProfileManager addon ID
    isAvailable = function()
        return ProfileManagerState.registeredAddons['discovered_newsystem'] ~= nil
    end,
},
```

For systems with custom export/import (like Edit Mode):

```lua
newsystem = {
    displayName = 'New System Name',
    isAvailable = function()
        return C_NewSystem ~= nil
    end,
    export = function()
        return { data = C_NewSystem.Export() }
    end,
    import = function(data)
        C_NewSystem.Import(data.data)
        return true
    end,
},
```

## Examples

See:

- **SpartanUI:** `C:\code\SpartanUI\Core\Handlers\Profiles.lua` (lines 60-75)
- **Built-in systems:** `C:\code\libsaddontools\Systems\ProfileManager\BuiltInSystems.lua`
- **Core logic:** `C:\code\libsaddontools\Systems\ProfileManager\Composite.lua`
