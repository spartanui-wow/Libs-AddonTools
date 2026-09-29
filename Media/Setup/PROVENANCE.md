# Setup skin asset provenance

| Asset | Source | Prompt or construction |
| --- | --- | --- |
| `stage/backdrop.png` | OpenAI built-in image generation, then resized to 1024x512, blurred, dimmed and desaturated with Pillow | `stage/backdrop.prompt.txt` contains the exact generation prompt. |
| `wartable/backdrop.png` | OpenAI built-in image generation, then resized to 1024x512, blurred, dimmed and desaturated with Pillow | `wartable/backdrop.prompt.txt` contains the exact generation prompt. |
| `stage/button.png`, `stage/button-filled.png`, `stage/chapter-check.png`, `stage/chapter-marker.png`, `stage/chevron.png`, `stage/glass-rim.png`, `stage/soft-shadow.png`, `stage/switch-knob.png`, `stage/switch-track.png` | Deterministic Pillow drawing at 4x, Lanczos downsample | Rounded geometry, brushed-metal gray rim, smoked-glass shadow, neutral switch and chapter states. See `tools/generate_setup_assets.py`. |
| `wartable/button.png`, `wartable/button-filled.png`, `wartable/chapter-check.png`, `wartable/chapter-marker.png`, `wartable/chevron.png`, `wartable/glass-rim.png`, `wartable/soft-shadow.png`, `wartable/switch-knob.png`, `wartable/switch-track.png`, `wartable/waypoint.png`, `wartable/banner.png` | Deterministic Pillow drawing at 4x, Lanczos downsample | The shared control geometry translated to antique brass and dark cloth. See `tools/generate_setup_assets.py`. |
| `wartable/oak-tile.png`, `wartable/brass-tile.png`, `wartable/map-slate-tile.png` | Deterministic Pillow drawing | Procedural wood grain, brushed brass and faction-neutral contour lines. See `tools/generate_setup_assets.py`. |

The painted assets contain no logos, named locations, faction crests or copied game art.
