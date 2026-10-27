# DAEMON Art Bible & Pipeline (§1.11 & §2.7)

### 1. Resolution, Scaling & Rules (§1.11)
- **Style:** Pixel art. Base resolution 480x270, integer-scaled, nearest-neighbor filtering, no sub-pixel movement.
- **Layout:** Playfield 480x240 (30x15 tiles of 16 px) plus a 30 px terminal-style HUD strip at the bottom (y 240 to 270).
- **Frame Sizes:** Standard frames are 16x16. Loader and large bodies are 32x32. Bosses are 48 to 96 px, assembled from parts.
- **Facings:** Three facings are drawn (`down`, `up`, `side`). Left is the `side` sheet flipped at runtime (`flip_h`).
- **Required Animations per Body:**
  - `idle` (down, up, side)
  - `walk` — 4 frames (down, up, side)
  - `primary` — 3 frames (down, up, side)
  - `secondary` — 3 frames (down, up, side)
  - `hurt` — single facing
  - `crash` — single facing
  - `dormant` — single facing
- **Drawing Rules:** 1 px dark outline, 4-shade ramp per hue, at most 8 colors, light from the top left, no anti-aliasing, no rotated or non-integer-scaled sprites (use sheets and flips).
- **Color Language:**
  - **Cyan outline:** player-owned / piloted
  - **Red accent:** hostile
  - **White blink:** Open (Integrity <= 35% or Overloaded)
  - **Amber:** interactable
  - These are shader effects over a shared base palette, so one sheet serves every variant.
- **Zone Palettes & Lighting:** Zone palettes (3 hues plus accent) live in `data/palettes/`:
  - P10 Boot Sector: `amber_dim`
  - P11 Bus Depot: `green_lume`
  - P12 Cache: `cyan_cold`
  - P13 Swap: `teal_deep`
  - P14 Heap: `rust_orange`
  - P15 Stack: `violet_neon`
  - P16 Registers: `yellow_white`
  - P17 Kernel: `mono_white`
  - Lighting uses Godot 2D lights (`CanvasModulate` + `PointLight2D`). An optional CRT shader (vignette and faint row darkening) is toggleable.

---

### 2. Asset Contract (§2.7)
Every sprite consists of a sheet `assets/sprites/<id>.png` plus metadata `assets/sprites/<id>.json`. Each row of the sheet is one animation. The emissive sheet (`<id>_emissive.png`) has the same layout and contains only glowing pixels (rendered unshaded).

```json
{
  "id": "janitor",
  "frame_size": [16, 16],
  "emissive": "janitor_emissive.png",
  "anims": {
    "idle_down":    { "row": 0,  "frames": 2, "fps": 3,  "loop": true },
    "walk_down":    { "row": 1,  "frames": 4, "fps": 8,  "loop": true },
    "primary_down": { "row": 4,  "frames": 3, "fps": 12, "loop": false },
    "hurt":         { "row": 10, "frames": 1, "fps": 1,  "loop": false }
  }
}
```

`tools/validate_data.gd` enforces:
1. Sheet size is a multiple of `frame_size`.
2. No semi-transparent pixels.
3. Every animation required by §1.11 exists.
4. Pixels outside the declared base palette emit a warning.

---

### 3. Production Paths (Mix Freely)

1. **Text-authored (default):** `art/sprites/<id>.sprite.json` holds char-grid parts and animations composed from them. `tools/bake_art.gd` (headless, uses the Godot `Image` API) writes the sheet, the emissive sheet and the metadata.
   - **Legend:** `.` transparent, `o` outline, `1` to `4` ramp shades (dark to light), `a` zone accent, `e` emissive.

```json
{
  "id": "janitor",
  "frame_size": [16, 16],
  "palette": "metal",
  "parts": {
    "chassis_down": { "rows": [
      ".oooooooo.",
      "o22222222o",
      "o23333332o",
      "o23eaae32o",
      "o23333332o",
      "o22222222o",
      "o11111111o",
      ".oooooooo."
    ] },
    "treads_a_down": { "rows": ["oo.oo.oo.o", "o.oo.oo.oo"] },
    "treads_b_down": { "rows": ["o.oo.oo.oo", "oo.oo.oo.o"] }
  },
  "anims": {
    "walk_down": { "fps": 8, "loop": true, "frames": [
      [ { "part": "treads_a_down", "at": [3, 11] }, { "part": "chassis_down", "at": [3, 3] } ],
      [ { "part": "treads_b_down", "at": [3, 11] }, { "part": "chassis_down", "at": [3, 2] } ]
    ] }
  }
}
```

2. **Drop-in PNG:** Any hand-drawn (Pixelorama, LibreSprite, Piskel, Aseprite), AI-generated or CC0 sheet that satisfies the contract replaces the baked file. Delete its `.sprite.json` so the baker does not overwrite it.

---

### 4. Shaders, Tiles, Fonts & Review Loop

- **Runtime & Shaders:** `SpriteLibrary` builds and caches `SpriteFrames` from sheet plus metadata. Shaders in `src/render/shaders/`: `palette_swap`, `outline`, `flash`, `open_pulse`, `heat_tint`, `crt`. Damage cracks are an overlay sprite toggled at Integrity thresholds.
- **Tiles:** `art/tiles/<zone>.tiles.json` defines recipes baked into an atlas `assets/tiles/<zone>.png`:

```json
{
  "palette": "amber_dim",
  "floor": { "recipe": "plate",    "params": { "rivets": true, "seam": 8 }, "variants": 4 },
  "wall":  { "recipe": "bulkhead", "params": { "pipes": 0.3 },              "autotile": "mask8" }
}
```

- **Tile Recipe Kinds:** `plate`, `bulkhead`, `grate`, `circuit`, `stripes`, `conveyor` (animated), `coolant` (animated), `pit`, `decor`. Variants are seeded by tile coordinate. `TileLibrary` builds a visual-only `TileSet` from the atlas at runtime using our own 8-neighbor `mask8` lookup (no Godot Terrain system).
- **UI Font & Theme:** `art/font5x7.json` (glyph rows as strings) is baked to a BMFont (`.fnt` plus PNG) that Godot imports as a font. The UI theme uses baked nine-patch boxes.
- **Review Loop:** `tools/contact_sheet.gd` (headless) renders sprites or tiles at 4x to PNG in `shots/`. `tools/shot.gd` renders a room in the real engine (non-headless) to PNG. The user approves batches (bodies, enemies, each zone kit).
