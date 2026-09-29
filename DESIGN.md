---
name: "Lib's AddonTools Setup"
description: "A faction-neutral guided setup world with one clear path and two owned material skins."
colors:
  accent-default: "#e21f1f"
  stage-ground: "rgba(20, 20, 26, 0.42)"
  stage-panel: "rgba(43, 46, 51, 0.88)"
  stage-card: "rgba(31, 33, 38, 0.94)"
  stage-rim: "#9ca1ab"
  stage-text: "#e8ebf0"
  stage-secondary: "#abb0b8"
  stage-dim: "#a3a8b0"
  stage-complete: "#52b36b"
  wartable-ground: "rgba(23, 17, 11, 0.25)"
  wartable-panel: "rgba(31, 38, 41, 0.90)"
  wartable-card: "rgba(27, 31, 31, 0.96)"
  wartable-rim: "#ad874f"
  wartable-text: "#ede8d9"
  wartable-secondary: "#b8ad96"
  wartable-dim: "#a69e8f"
  wartable-complete: "#59ab63"
  combat-scrim: "rgba(0, 0, 0, 0.55)"
typography:
  display:
    fontFamily: "Roboto Condensed, Arial Narrow, sans-serif"
    fontSize: "26px"
    fontWeight: 700
  headline:
    fontFamily: "Roboto Condensed, Arial Narrow, sans-serif"
    fontSize: "18px"
    fontWeight: 700
  title:
    fontFamily: "Roboto Condensed, Arial Narrow, sans-serif"
    fontSize: "14px"
    fontWeight: 700
  body:
    fontFamily: "Roboto Condensed, Arial Narrow, sans-serif"
    fontSize: "12px"
    fontWeight: 700
  label:
    fontFamily: "Roboto Condensed, Arial Narrow, sans-serif"
    fontSize: "11px"
    fontWeight: 700
rounded:
  control: "8px"
  surface: "18px"
  pill: "999px"
spacing:
  xxs: "4px"
  xs: "8px"
  sm: "10px"
  md: "12px"
  lg: "16px"
  xl: "18px"
  section: "24px"
components:
  button-primary:
    backgroundColor: "{colors.accent-default}"
    typography: "{typography.title}"
    rounded: "{rounded.control}"
    padding: "0 15px"
    height: "28px"
  button-secondary:
    typography: "{typography.title}"
    rounded: "{rounded.control}"
    padding: "0 15px"
    height: "28px"
  switch-track:
    rounded: "{rounded.pill}"
    size: "36px 18px"
  choice-card:
    typography: "{typography.title}"
    rounded: "{rounded.surface}"
    padding: "8px 11px"
  chapter-row:
    typography: "{typography.body}"
    height: "26px"
  combat-blocker:
    backgroundColor: "{colors.combat-scrim}"
    textColor: "{colors.stage-text}"
    typography: "{typography.headline}"
    width: "100%"
    height: "100%"
---

# Design System: Lib's AddonTools Setup

## Overview

**Creative North Star: "The Guided Campaign"**

Setup is a short route through a familiar Warcraft world, not a stack of generic dialogs. The interface keeps the next decision obvious, ranks information through depth, and lets the host addon supply identity through a restrained accent.

Classic preserves the established compatibility presentation. The two owned skins share one interaction system: **The Selection Stage** places smoked glass over the active theme or a neutral fantasy fallback; **The War Table** translates the same hierarchy into dark oak, antique brass, map slate, and an inked route. Neither skin uses faction marks, named places, copied game art, or client-version-dependent chrome.

**Key Characteristics:**

- Mid-tone layered surfaces over owned, dimmed backdrops.
- One host accent reserved for selected, current, checked, progress, and primary states.
- Compact decisions, explicit status text, and one filled footer action.
- Owned assets and controls that render consistently across supported WoW clients.

## Colors

The palettes remain neutral enough to accept any host accent: cool graphite for The Selection Stage and warm slate, oak, and brass for The War Table.

### Primary

- **Host Accent:** Supplied at runtime; the default token is only the LibAT fallback. Use it for the current chapter, selected-card rim and glow, checked switch, progress fill, and the single filled primary action.

### Neutral

- **Stage Ground / Panel / Card:** A dim veil, smoked glass, and a darker decision surface establish three readable layers without becoming near-black.
- **Stage Rim / Text / Secondary / Dim:** Cool metal and near-white type provide structure; muted roles remain readable rather than disappearing.
- **War Table Ground / Panel / Card:** A warm veil, map-slate panel, and deep ink card sit beneath oak title and footer material.
- **War Table Rim / Text / Secondary / Dim:** Antique brass and parchment neutrals communicate the skin without allegiance to either faction.
- **Complete:** Green is reserved for completed route states; it never competes with the host accent for current state.
- **Combat Scrim:** The blocker darkens the inactive setup while its message remains fully legible.

**The One Signal Rule.** The host accent means selected, current, checked, progress, or primary; recommendation and decoration stay neutral.

**The Contrast Chooses the Ink Rule.** Filled primary labels automatically use whichever of near-black or white gives the stronger contrast against the live host accent.

## Typography

**Display Font:** Roboto Condensed Bold  
**Body Font:** Roboto Condensed Bold  
**Label Font:** Roboto Condensed Bold

**Character:** Condensed, sturdy, and quick to scan at game-UI scale. All owned-skin text uses the shipped font with an outline and a one-pixel dark shadow; Classic retains its existing client font objects.

### Hierarchy

- **Display** (700, 26px): Current step heading.
- **Headline** (700, 18px): Window title and blocking combat message.
- **Title** (700, 14px): Buttons, cards, addon labels, and prominent content.
- **Body** (700, 12px): Chapter rows, setting labels, and summaries.
- **Label** (700, 11px): Captions, badges, descriptions, progress, and quiet actions.

**The Plain Words Rule.** Labels are short, literal, and readable at a 6th-grade level; status never depends on an icon or color alone.

## Layout

Owned skins use a centered 1024x650 window with a 36px title bar, 52px footer, 10px outer content inset, 218px chapter rail, and 12px gap before the main panel. The rail is one depth layer behind the decision panel. The footer keeps Back at left, progress centered, optional quiet skip behavior beside the primary, and exactly one filled action at right.

Choice content uses compact adaptive grids: look cards allow up to three columns at a 210px minimum with 12px gaps; ordinary choice cards allow up to two columns at a 240px minimum. Toggle groups use two columns when at least 560px is available and one otherwise, with 14px between columns and a 42px row pitch. Scrollbars are owned 5px tracks with a thumb of at least 24px.

Classic remains an 800x538 resizable compatibility view. Do not force owned-skin dimensions, imagery, or font assumptions into Classic.

**The One Route Rule.** Chapters stay in the left rail, the current decision stays in the main panel, and progress plus completion actions stay in the footer.

## Elevation & Depth

Depth is structural. A cropped, dimmed backdrop forms the ground; the chapter rail is quieter; the main panel is brighter; cards rise within it; selected cards add a soft accent glow. Owned windows use the shipped soft-shadow and rim rasters, low-alpha one-pixel edges, and a subtle inner highlight. The War Table swaps panel and bar fills for owned oak and map-slate textures while preserving the same rank.

**The Rank Is Depth Rule.** Brightness, opacity, rim strength, and shadow identify hierarchy; do not flatten every surface or add arbitrary shadows.

## Shapes

Owned surfaces have gently rounded silhouettes and fine one-pixel rims. Buttons read as compact soft rectangles, switches as pills with circular knobs, and chapter markers as circular route points. Geometry comes from shipped PNG assets and shared Lua dimensions, not Blizzard templates or atlases. Cards never use a colored stripe on one edge.

## Components

### Buttons

- **Primary:** One 28px-high filled action, tinted by the live host accent. Its label switches between light and dark for contrast.
- **Secondary:** The same geometry with a neutral owned texture and light label. Hover reduces texture alpha to 82%; disabled buttons remain visible at 62% overall alpha.
- **Quiet actions:** 11px text controls for reversible or secondary paths. Skip choices live in a small surfaced menu rather than becoming competing filled buttons.

### Choice Cards

Cards use the active skin's card surface, 1px material rim, 14px title, 11px caption, and explicit Recommended, Selected/In use, Done, Skipped, or New badges. Hover strengthens the neutral rim; selection replaces it with the accent and adds a soft accent glow. Disabled cards remain present at 48% alpha with their status visible.

### Switch Rows

Settings are 28px rows, or 38px when a description is present. A 36x18 switch leads the row; a 16px knob moves left/right. Checked tracks take the host accent. Core settings are disabled at 60% alpha and say **Always on**. Group-level Turn all on/off actions remain quiet text.

### Chapter Rail

Addon rows are 30px high and step rows 26px high. Current steps use accent-colored text, marker, and a faint fill; completed steps use the owned check asset. The War Table may add its banner, waypoint, and inked route; The Selection Stage uses the simpler lit marker. Both preserve the same labels and navigation behavior.

### Progress, Badges, and Scrollbars

Progress is a 2px accent fill beneath an 11px step label. Badges are 18px high with neutral rims; recommendations do not borrow the accent. Owned scrollbars use a 5px material track and a minimum 24px thumb.

### Combat Blocker

When combat starts, the visual root dims to 40%, a full-window scrim appears, and **Waiting for combat to end** remains at full contrast. Finish and finish-without-reload are disabled until combat ends.

## Do's and Don'ts

### Do:

- **Do** keep the host accent scarce and semantic.
- **Do** use the shipped Roboto Condensed Bold and owned setup rasters for both owned skins.
- **Do** show recommended, selected, disabled, completed, skipped, reload, and combat states in words.
- **Do** preserve the same content, state model, and control ownership on every supported WoW client.
- **Do** keep The Selection Stage cool and glassy and The War Table warm, tactile, and faction-neutral.

### Don't:

- **Don't** add a second filled primary action, decorative accent wash, or colored card-edge stripe.
- **Don't** turn switches into cards or expand compact setup decisions into dashboard tiles.
- **Don't** depend on Blizzard templates, atlases, arbitrary Unicode, remote assets, or browser behavior for an owned skin.
- **Don't** hide a blocked or disabled reason behind color, opacity, hover, or an icon alone.
- **Don't** let Classic-specific chrome redefine the owned-skin contract.
