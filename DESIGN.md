---
name: "Lib's AddonTools UI Kit"
description: "Reusable theme-aware Warcraft UI components with art at the edges and flat reading surfaces."
colors:
  accent: "LibAT.UI.GetAccentColor()"
  text: "#edf0f4"
  text-secondary: "#b8bec7"
  text-muted: "#9198a3"
  text-disabled: "#676d75"
  done: "#52b36b"
  warning: "#efad38"
  skipped: "#8f949c"
spacing: [4, 8, 12, 16, 24]
type: [11, 12, 14, 16, 18, 26]
surface-elevation: [0, 1, 2, 3]
---

# Design System: Lib's AddonTools UI Kit

## Creative direction

**Art at the edges, flat where you read.** A window can carry the player's theme without making its controls noisy. Painted art belongs on the outer frame, title plate, divider ornament, active marker, or one corner. Text and controls always sit on a calm, flat surface.

**Windows wear the player's theme.** A host supplies a trim kit and live accent. LibAT supplies the structure, interaction, sizing, and neutral fallback. Changing either input repaints existing kit components in place.

The setup flow keeps its established Guided Campaign model: one visible route, one current decision, compact controls, explicit state labels, and one filled primary action. The War kit expresses that model with dark oak, antique brass, map slate, and a chapter flag rail. The Minimal kit preserves the same hierarchy with clean one-pixel lines and no ornament.

## Tokens

### Spacing

Use only the shared 4, 8, 12, 16, and 24 pixel spacing scale. A component may use a 1 or 2 pixel optical correction for borders and type baselines, but those values are not layout gaps.

### Type

All kit text uses the shipped Roboto Condensed Bold font objects at 11, 12, 14, 16, 18, or 26 pixels, with outline and a one-pixel shadow.

- 26: page display title.
- 18: window title, addon header, or blocking message.
- 16: section and chapter titles.
- 14: buttons, cards, and prominent body text.
- 12: ordinary labels and navigation.
- 11: captions, badges, progress, and quiet actions.

### Surfaces

Every kit provides four surface elevation colors.

- 0 Ground: window veil and lowest backdrop tint.
- 1 Rail: navigation, footer wells, and low-priority regions.
- 2 Panel: primary reading panel and ordinary cards.
- 3 Raised: popovers, focused groups, and title material.

Use elevation to communicate hierarchy. Do not add arbitrary shadows to every child.

### Text and state color

Text uses no more than four greys: text, secondary, muted, and disabled. The live accent comes only from `LibAT.UI.GetAccentColor()` and means current, selected, checked, progress, focus, or primary. Done, warning, and skipped use their dedicated status colors. State is also written in words or represented by a distinct shape.

## Six-layer panel model

Every kit-built panel has the same ordered layers:

1. Backdrop: optional scene or host artwork, cropped and dimmed.
2. Surface: flat elevation color that guarantees readable content.
3. Material: optional low-alpha repeating tile that carries theme texture.
4. Trim: one-pixel fallback edges or the kit's sliced border.
5. Ornament: at most one corner, header plate, divider center, or active marker.
6. Shadow: a restrained drop shadow behind the panel.

Content is placed above all six layers. Missing art never removes the surface, trim, text, or interaction state.

## Components and states

All components respond live to accent and kit changes. Hover strengthens the neutral trim. Pressed reduces or darkens the surface. Focus uses the accent rim without relying on glow alone. Selected uses the accent plus a written state where space allows. Disabled remains legible, cannot activate, and uses the disabled text token at about 60 percent overall strength.

### Window

The default window is 1024 by 650 with a 36 pixel title bar, 52 pixel footer, 218 pixel rail, 12 pixel column gap, and content inset supplied by the active trim. It owns movement, close behavior, backdrop crop, footer, and the six visual layers. War uses its painted 9-slice and scene. Minimal uses a one-pixel frame.

### Panel and Section

A Panel is the basic six-layer surface at elevation 0 through 3. A Section is a content-sized panel with a 16 pixel header and divider. A divider may include one centered ornament, but the text remains on a flat surface.

### Card

Cards contain title, caption, optional art, badges, and optional check control. States are normal, hover, pressed, focus, selected, and disabled. Selected cards keep the explicit `Selected` or `In use` label. Recommendation remains a neutral badge rather than borrowing the accent.

### Button

Buttons are primary, secondary, or ghost. Exactly one primary action should be visible in a footer. Primary uses the accent or confirmed host atlas and automatically chooses readable label ink. Secondary uses neutral material. Ghost is text-forward with no competing fill. Each supports normal, hover, pressed, focus, and disabled states.

### Switch row

A switch row is 28 pixels high, or 38 with a caption. A 36 by 18 track precedes the label. Checked uses the accent. Core settings are disabled and say `Always on`. Reload-dependent settings say `Needs reload`.

### Badge

Badges are 18 pixels high and size from content. Supported semantic styles are recommended, selected, done, warning, skipped, and new. Color reinforces the written label.

### Nav rail

The setup rail groups steps under addon and chapter rows. War uses 44 pixel chapter rows, 16 pixel chapter text, an 18 pixel addon header, a triangle, thin dividers, gold pole behind completed or current territory, the flag on the current chapter, and silver ahead. Minimal uses the same labels and spacing with flat markers and lines.

### Tabs

Tabs are a horizontal row of ghost buttons. The selected tab takes the accent and focus treatment. Keyboard or programmatic focus must remain visible independently of hover.

### Popover and menu

Popovers use elevation 3, a clear rim, and an outer shadow. Menus contain compact text actions and close when their owner route changes. Destructive or reload actions state their consequence in the label.

### Scroll area

The owned scroll area uses a 5 pixel track, a thumb of at least 24 pixels, mouse-wheel movement, and content-driven range. It never depends on client-version-specific templates.

## Trim kit contract

All asset paths include `.png`, and every shipping texture has a power-of-two canvas. Untinted metal retains its painted color. Tintable masks receive the trim or accent token at runtime. When an asset is absent, LibAT draws a flat color or one-pixel edge so the component remains complete.

| Piece | PNG canvas | Slice and placement | Tint rule | Missing-piece fallback |
| --- | --- | --- | --- | --- |
| Window border | Corners 32x32 or 64x64; horizontal and vertical beams 32x128 or 128x32 | 9-slice, with declared corner size, edge thickness, tile length, and edge crop | Tint only assets declared as masks; painted wood and metal never tint | One-pixel trim edges |
| Title/header plate | 256x64 | Tile or crop across the 36 pixel title bar | Painted plate never tints; a mask may take trim color | Elevation 3 flat surface |
| Divider | 256x16 | Horizontal tile or stretch at 1 to 8 pixels high | Line may take trim color; center ornament never tints | One-pixel trim line |
| Divider ornament | 64x32 | Center once over the divider | Untinted metal | Omit ornament |
| Button primary | Left 32x64, center 64x64, right 32x64 | 3-slice with a declared cap width | Fallback masks take accent; confirmed native red/gold art remains untinted | Flat accent fill with readable label |
| Button secondary | Left 32x64, center 64x64, right 32x64 | 3-slice with a declared cap width | Fallback masks take neutral trim; confirmed native red art remains untinted | Elevation 2 fill with trim edge |
| Active marker | 32x32 or 64x64 | Center without stretching | Minimal mask takes accent; painted War flag never tints | Flat accent circle or square |
| Inset well | 64x64 | 9-slice with 12 to 16 pixel corners | Neutral masks may take trim; painted recess never tints | Elevation 0 fill with inner edge |
| Material tile | 64x64, 128x128, or 256x256 | Repeat at low alpha | Never tint painted material | No material layer |
| Corner ornament | 64x64 or 128x128 | Place once in one declared corner | Untinted metal | Omit ornament |

Confirmed `128-RedButton`, `128-GoldRedButton`, and `RedButton-Exit` atlas families may replace kit fallbacks only when `C_Texture.GetAtlasInfo` reports them. No component assumes that an atlas exists.

## Layout helpers

`Kit:CreateStack(parent, gap)` lays children top to bottom. `Kit:CreateRow(parent, gap)` lays them left to right. Both accept one of the spacing tokens, re-anchor their registered children, and size themselves from the summed main axis plus the largest cross axis. This is the kit's flexbox-like primitive. Components should use it before inventing fixed intermediate containers.

## Graceful fallback

No provider, an invalid provider, an unknown kit, or any missing contract piece resolves to Minimal or a flat drawn substitute. The hierarchy, labels, button targets, focus, selected state, and disabled reason remain readable. A theme can therefore ship a partial kit and add painted pieces over time.

## One engine for every window

`LibAT.UI.Kit` is the only visual layer. Everything else is a consumer or an adapter:

| Layer | What it does |
|---|---|
| `Kit:CreateShell(options)` | A themed window: painted frame, title bar and footer inside the frame's beam, close button, drag, Escape, optional resize grip. Content goes in `shell.Body`. |
| `Kit:DressShell(frame, options)` | The same chrome on a frame someone else created (the SpartanUI options window is an AceGUI container). |
| `Kit:SkinPanel(frame, options)` | Surface, material and trim on any frame. `Kit:CreatePanel` is CreateFrame plus this. |
| `Kit:CreateButton(parent, text, style, width)` | Kit art, Blizzard atlases when the kit asks and the client has them, otherwise a gradient with an edge. Native Enable/Disable, `GetFontString` and `.Text` work like a template button. |
| `Kit:CreateWindow` | The setup window: a shell with the chapter rail and the page. |
| `LibAT.UI.CreateWindow` and helpers | The classic API, unchanged signatures, now drawn by the kit (see below). |
| `SUI.UI.Style` (SpartanUI) | Takes its colors and buttons from the active kit, so SpartanUI's widgets and tools match. |

### The classic `LibAT.UI` API on the kit

- `CreateWindow` returns a shell; place children in `window.Body`, not at template offsets.
- `CreateControlFrame`/`CreateContentFrame` measure from the shell body. Offsets callers pass are still relative to where the old template put content (-33 top, 12 bottom).
- `CreateLeftPanel`/`CreateRightPanel` are kit panels.
- `CreateActionButtons` turns the footer on and places buttons at its right end. Buttons stay parented to the frame passed in, so a tab's buttons hide with the tab.
- `LibAT.UI.GetFooter(frame)` returns the footer of the kit window a frame lives in (turned on) and the padding to keep from its ends. Use it for status text and left-side buttons.
- `CreateButton`, `CreateFilterButton` and `SetupFilterButton` keep their fields (`Text`, `NormalTexture`, `SelectedTexture`, `HighlightTexture`, `Lines`), painted from kit colors.
- Checkbox, edit, numeric and search boxes, dropdown, slider, radio, progress bar, info button, scroll frame, styled panel, label and header are all drawn by the kit and keep their old fields and methods (`checkbox`/`checkbg`/`check`/`Label`/`Desc`; `Instructions`/`clearButton`/`searchIcon`; `ScrollBar`; `bg`/`Border`/`text`). The dropdown and scroll bar keep Blizzard's behavior and only change look (`LibAT.UI.SkinDropdown`, `LibAT.UI.SkinScrollBar` work on any Blizzard dropdown button or MinimalScrollBar). Dropdowns keep the width they are given.
- Widgets that paint from their own scripts use `LibAT.UI.KeepScripts(frame, { Event = fn })`, so a caller's `SetScript` adds to the widget instead of silently removing its painting. Labels and progress bars keep a color the caller sets.
- Text on filled shapes (buttons, badges, inputs) uses `Kit:SetFont(fontString, size, true)`: no outline or shadow, which smeared dark text on light fills.

### Kits

A kit is data: `colors` (surfaces 0-3, `bar`, text, secondary, muted, trim, `trimHi`, rail `path`/`pathAhead`/`tick`), `button.primary`/`button.secondary` (`top`, `bottom`, `edge`, `text`), `layout` (`barInset`, `titleHeight`, `footerHeight`, `sideInset`, `barPadding`, `dividerHeight`) and `assets` (`windowBorder` 9-slice, `backdrop`, `materialTile`, `divider`, `marker`, `node-done`, `node-upcoming`, `titlePlate`; an asset may be `{ texture, coords }` to use part of a sheet). LibAT ships `minimal`; SpartanUI registers War (Alliance and Horde), Midnight, Classic, Fel and Digital in `Core/Handlers/WindowKits.lua` and picks one per theme with `SetKitProvider`.

## Adopting the kit

New windows: `Kit:CreateShell`, panels with `Kit:SkinPanel`, buttons with `Kit:CreateButton`. Existing windows on the classic API already follow the kit; check that nothing is anchored at the window's bottom edge (it sits under the painted frame) and move such pieces to `GetFooter`. Windows built straight on Blizzard templates (`ButtonFrameTemplate`) still need moving to a shell. A host adapter for native game panels should wrap their content in kit panels and feature-detect every client asset.

## Guardrails

- Keep the accent scarce and semantic.
- Keep one filled primary action per decision region.
- Keep recommendation, completion, skipped, reload, disabled, and combat states explicit in words.
- Keep text and controls on flat surfaces, even when painted art is present.
- Do not depend on remote assets, arbitrary Unicode, or client-version-specific templates.
- Do not add decorative edge stripes, stacked cards for ordinary switches, or a second visual language inside one window.
