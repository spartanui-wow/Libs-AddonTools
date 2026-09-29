---
target: LibAT Setup hub window
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 4
target_identity: "file:C:\\code\\LibsAddonTools\\Systems\\Setup\\SetupHub.lua"
target_fingerprint: "sha256:2fe74817a149e48353e770c58701f5ddfc6827d9edb86706a987b2a20ea97c9e"
target_path: "C:\\code\\LibsAddonTools\\Systems\\Setup\\SetupHub.lua"
timestamp: 2026-09-29T20-45-37Z
slug: systems-setup-setuphub-lua
---
Method: dual-agent (A: design review, B: detector + manual inventory). Detector found no scannable markup in Lua (positive control confirmed it works); browser overlay not applicable (WoW client only).

Design health 24/40 (Acceptable). Scores: 1:3 2:3 3:3 4:1 5:2 6:3 7:3 8:2 9:2 10:2.

Verdict: mostly borrowed. Auction House frame (ButtonFrameTemplate, auctionhouse-background atlases, NineSlice, UIPanelButtonTemplate) around a generic flat card system, drawn in Friz. Product-specific: theme art cards, live accent, addon icons.

P1 Two design languages stacked (Blizzard frame / flat content / Blizzard text) - own the frame (title bar, close, panels, buttons, checkbox, scrollbar, one font).
P1 Frame is client-dependent (Forever title/close differ; unguarded AH atlases; ScrollUtil fallback invisible; variant picker menu vs cycle).
P1 Cards as the default container (owner confirmed): toggle settings as ~100px cards; 3px accent band on cards (side-stripe device, craft-floor refuse); 96-100px one-line start/welcome cards. Fix: compact toggle rows, sized choice rows, picture cards only for looks/presets, no edge bands.
P1 Footer: 4 equal red buttons, no primary; Skip vs Use recommended overlap; label overflow at 190px; disabled buttons unexplained.
P2 State markers: 8 text grays, 2 greens, mustard Recommended twice, all status badges green (Skipped == Done), yellow/cyan old-page boxes, "> " marker.

Personas: Jordan (reopen shows dead buttons; floating Recommended; 17 steps at step 1; skip vs recommended guess; reload unannounced), Sam (no keyboard; tooltip-only help; combat notice at 40% alpha; dim small list text; gold-on-red progress), Alex (bulk action without summary; looks unlike SUI's own tools).
