# DAEMON Art Bible & Guidelines

### Resolution & Scaling
- Base resolution: 480×270 viewport, integer-scaled, nearest-neighbor filtering.
- Playfield: 480×240 (30×15 tiles of 16px).
- Bottom HUD: 480×30 terminal strip.
- No sub-pixel movement; whole-pixel transforms and screen shake.

### Sprites & Dimensions
- Base frame size: 16×16.
- Large bodies (e.g. Loader): 32×32.
- Bosses: 48×48 to 96×96 (assembled from modular parts).
- Three drawn facings: down, up, side (left is side flipped with `flip_h`).
- 1px dark outline, 4-shade ramp per hue, max 8 colors, light from top-left.
- No anti-aliasing; no runtime rotation of sprites.

### Color Language
- **Cyan outline:** Player-owned / hijacked.
- **Red accent:** Hostile.
- **White blink / pulse:** Open for hijacking (Integrity <= 35% or Overloaded).
- **Amber:** Interactable / terminal / puzzle element.

### Asset Pipeline Contract
- Asset path: `assets/sprites/<id>.png` with metadata `assets/sprites/<id>.json`.
- Emissive sheet: `assets/sprites/<id>_emissive.png` (matching animation layout, unshaded).
- Authored via `art/sprites/<id>.sprite.json` (baked) or drop-in PNGs.
