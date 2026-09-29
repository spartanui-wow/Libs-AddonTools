# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

(Recorded as `web` because the record allows no other value. The real runtime is the World of Warcraft game client: Lua 5.1 against Blizzard's frame API, drawn inside the game, never in a browser. Web-only tooling such as the HTML detector and browser capture does not apply; in-game screenshots are the visual evidence.)

## Users

World of Warcraft players who have just installed SpartanUI or one of the "Lib's" addons (DataBar, Farm Assistant, Time Played, Social, Disenchant Assist, Totembar, Keystone Roulette, and others). Primary audience: SpartanUI players, who reach the shared windows through SpartanUI first. Secondary: players running a Lib's addon without SpartanUI, who see the same windows.

Their situation: logged into the game, often right after installing or updating, sometimes about to join a group, sometimes mid-session between fights. Their job in the setup window: get every installed addon set up the way they want in a few minutes, then get back to playing.

## Product Purpose

Libs-AddonTools (LibAT) is the shared toolkit behind SpartanUI and the Lib's addons: logging and error viewing, profile import and export, an addon manager, and the first-run setup window that every one of these addons registers with. Success for the setup window: a player finishes setup for all due addons in one sitting, trusts the recommended choices, and reloads once.

## Positioning

One setup window for a whole family of addons instead of a popup per addon: new installs are told apart from upgrades, recommended values are marked, changes that need a reload are collected and applied with a single reload at the end, and the window takes on the accent of the SpartanUI theme the player picked.

## Operating Context

- Opens by itself about two seconds after login (never in combat), or with `/setup`, `/setup <addon>`, `/libat setup`, or a "Run setup again" button in an addon's options.
- Must work the same on every client flavor the family supports: Retail (Midnight 12.x), WoW Forever, Mists of Pandaria Classic, Titan, TBC Anniversary and Classic Era. Blizzard's own templates and atlases look different or are missing on some of these clients.
- Combat can start while it is open; the window then waits and blocks finishing.
- Addons describe their steps (look, choice, toggles, import, form, custom, summary); LibAT draws them.

## Capabilities and Constraints

- Lua 5.1 only; no emojis or arbitrary Unicode in text (the game cannot render them).
- Art must ship as files inside the addon (TGA/BLP/PNG with explicit `.png` extension); Blizzard atlases are optional and must always have a fallback.
- The accent color is provided by the host addon (SpartanUI supplies its theme accent); LibAT's own default is red `e21f1f`.
- Setup changes never reload by themselves; they are staged and applied once.
- Other LibAT windows (error viewer, profile manager, addon manager) share base window pieces; the current redesign covers the setup window only, with the intent to carry the result to all LibAT windows afterwards.

## Brand Commitments

- Names: "SpartanUI", "Lib's AddonTools", and the "Lib's <Name>" addon family.
- No fixed Lib's family visual brand yet; the red accent and current icons are placeholders the redesign may replace.
- Never name other addons (outside the family) in user-facing text; import sources are the one current exception, pending review.
- User-facing text is plain, short and written at a 6th-grade reading level.

## Evidence on Hand

- SpartanUI theme art and setup preview images: `C:\code\SpartanUI\images\setup\` and `C:\code\SpartanUI\Themes\*\Images\`.
- Addon logos: each addon's `Logo-Icon` file where present.
- Bundled font available in SpartanUI: Roboto Condensed Bold (OFL).
- No testimonials, download counts or other claims are to be shown in the product.

## Product Principles

1. Get the player back to playing: every screen should be decidable in seconds, with a clear recommended choice.
2. One window, one reload: never interrupt the player with extra popups or mid-setup reloads.
3. Identical on every client: nothing the player sees may depend on a Blizzard asset that changes or vanishes between game versions.
4. SpartanUI's world first: the shared windows should feel like part of SpartanUI for its players, without breaking for players who only run a Lib's addon.
