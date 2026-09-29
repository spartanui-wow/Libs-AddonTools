---
version: 1
slug: "systems-setup-setuphub-lua"
primary_target: "Systems/Setup/SetupHub.lua"
related_targets: ["Core/UI/Card.lua"]
---

# Setup window (LibAT.Setup hub)

Mode: Operate. Visitor: a WoW player right after installing or updating SpartanUI or a Lib's addon; success is finishing setup for every due addon in one sitting and reloading once.

Pinned by the owner: Warcraft-flavored but faction-neutral; mid-tone, never near-black; real depth (layers, not flat); modern finish, not 2004 game chrome; flexible across every SpartanUI theme (War, Midnight, Fel, Arcane, Digital, Classic, the flat looks); Roboto Condensed for all UI text; one Next as the only primary action; chapters in the left rail; on/off settings as compact switch rows, never cards; no colored bar on one edge of any card; identical on every client (no Blizzard templates or atlases the look depends on).

Approved decision comp: `.impeccable/mocks/decision/assigned-r2.png` (The Selection Stage).

Unresolved: which neutral backdrop players without SpartanUI see; whether other LibAT windows adopt the world later (owner intends to, after this one).

## Direction contract

THESIS: The window is a stage, not a panel. The look the player picked becomes the backdrop, and the setup floats in front of it on smoked glass. It refuses the category default: a boxed game panel with gold trim and red buttons.

OWN-WORLD: The ground is the active theme's own painted art, pre-blurred and dimmed. Smoked graphite glass panels (#2b2d31 to #3a3d42, roughly 80-88% opaque) have a soft inner top highlight, a 1px brushed-metal rim (#9a9ea5 at low alpha) and a soft drop shadow. Text is near-white #e8e9eb, with secondary #a9adb3. The theme accent is the only color, used only as light: a selected-card glow edge, the current-chapter marker, and the filled Next. Roboto Condensed.

STORY: The player sees their chosen look behind everything, understands each step at a glance, sees what is recommended and what they changed, and presses one Next. Setup ends with one reload into the look they built.

FIRST VIEWPORT: A thin title bar with close, over the backdrop. A left rail glass panel one layer back holds addon groups with chapters, the current chapter lit by the accent. The main glass panel is frontmost: caption, heading, one line of body, then content (picture cards for looks, switch rows for settings). A footer carries a quiet Back at left, step progress in the middle, and the accent-filled Next at right.

FORM: The Selection Stage, position 5 of 7 on the ordered grounded list; seed key 5a4d973d. Raises: rank is depth (current step frontmost and brightest); each on/off setting is its own labeled switch row; a disabled control says why in place.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
