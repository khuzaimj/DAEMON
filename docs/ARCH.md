# 2. Architecture

### 2.1 Repository layout (the repo root is the Godot project)

```
daemon/
├─ project.godot  export_presets.cfg  .gitignore  .gutconfig.json
├─ AGENTS.md                      # = §0
├─ .agents/
│  ├─ rules/daemon.md             # = §0 (mirror; keep identical via tools/sync_rules.ps1)
│  ├─ skills/<name>/SKILL.md      # §5
│  └─ workflows/<name>.md         # §5
├─ docs/
│  ├─ SPEC.md ARCH.md PLAN.md CONTENT.md TEMPLATES.md ART.md
│  ├─ STATE.md                    # live status, read first every session
│  ├─ DECISIONS.md                # 1 to 3 lines per decision
│  └─ phases/P00-rails.md ...     # brief + report per phase
├─ addons/gut/                    # approved test addon
├─ scenes/                        # few and small: main.tscn world.tscn machine.tscn ui/
├─ src/
│  ├─ autoload/                   # events.gd data.gd game.gd input_router.gd save_system.gd audio_bus.gd sprite_library.gd
│  ├─ core/                       # RefCounted rules and math, no nodes, no Input
│  │  └─ intent.gd rng_streams.gd grid.gd schema.gd logic_graph.gd hijack_fsm.gd ability_math.gd
│  ├─ sim/                        # world.gd machine.gd controllers/ abilities/ systems/ ai/ bots/
│  ├─ world/                      # room_loader.gd room_runtime.gd room_collision.gd tile_library.gd world_grid.gd
│  ├─ render/                     # lighting.gd fx/ shaders/ (palette_swap outline flash open_pulse heat_tint crt)
│  ├─ ui/                         # hud.gd menus/ garage.gd map_screen.gd log_reader.gd settings_screen.gd
│  └─ audio/                      # music_player.gd sfx_player.gd
├─ data/                          # JSON content, no code
│  └─ sizes.json tiles.json bindings_default.json
│     palettes/ bodies/ abilities/ enemies/ ai/ bosses/ zones/ rooms/<zone>/*.json + *.solve  logs/ sfx/ music/
├─ art/                           # authoring sources, baked by tools
│  └─ sprites/*.sprite.json  tiles/*.tiles.json  font5x7.json
├─ assets/                        # PNG and WAV imported by Godot (committed with .import files)
│  └─ sprites/ tiles/ fonts/ audio/
├─ tests/                         # GUT: unit/ scenario/ data/
├─ tools/                         # check.ps1 build.ps1 sync_rules.ps1
│                                 # run with --headless --script: load_all.gd validate_data.gd bake_art.gd bake_audio.gd
│                                 #   contact_sheet.gd map_export.gd progression_check.gd run_bots.gd
│                                 # needs rendering (non-headless): shot.gd
└─ build/ shots/                  # git-ignored
```

Git: ignore `.godot/`, `build/`, `shots/`. Commit `.import` and `.uid` files.

### 2.2 Ticks, time and events

- Physics runs at 60 ticks per second (`physics/common/physics_ticks_per_second`). One `World` node owns the tick: its `_physics_process` runs the systems in §2.5 order. Machines and other entities do not run gameplay in their own `_physics_process`; they expose step methods the systems call.
- `Game.tick` is the integer tick counter. Cooldowns, TTL and statuses are stored in ticks.
- Targeting slow-motion sets `Engine.time_scale = 0.25` and restores it afterwards. Because logic counts ticks, nothing else needs special handling.
- RNG: `RngStreams` provides named `RandomNumberGenerator`s seeded from the world seed. Never the global `randi()` family.
- Events: the `Events` autoload holds typed signals (`hit`, `hopped`, `door_changed`, `pickup_taken`, `log_found`, ...). The simulation emits; UI, audio and FX connect. Signal up, call down.
- Determinism is best effort. Godot physics is not guaranteed bit-exact, so tests assert outcomes (flags, rooms, items, timeouts), never exact positions.
- Units: positions in pixels; speeds in tiles per second in data, converted to pixels per second at load; durations in ticks.

### 2.3 Entities and scenes

A `Machine` is every body, enemy, dormant machine and parked host:

```
Machine (CharacterBody2D)            # src/sim/machine.gd
├─ Collider (CollisionShape2D)       # rectangle sized by the body's size class
├─ Sprite (AnimatedSprite2D)         # SpriteFrames from SpriteLibrary, shader material
├─ Glow (AnimatedSprite2D)           # emissive sheet, unshaded
├─ HurtBox (Area2D)
├─ Abilities (Node)                  # runs the primary and secondary ability objects
└─ Controller (Node)                 # current controller; swapped by hijack
```

State lives in `RefCounted` objects (`BodyState`: Integrity, Heat, statuses, cooldowns; `ParkedState`: routine, waypoint). Other entity kinds (plate, door, lift, bridge, crusher, beam gate, Node, pickup, Dock, Firewall, boss parts) are small scripts or scenes built by `EntityFactory` from the room's `kind` strings.

Physics layers (named in project settings):

| Layer | Name | Used by |
|---|---|---|
| 1 | solid | walls, closed doors, cracked and weld tiles |
| 2 | conduit_gate | conduit tiles; blocks every body except XS |
| 3 | machines | bodies, enemies, parked and dormant machines |
| 4 | pushables | crates and other pushable props |
| 5 | hitbox | attack areas |
| 6 | hurtbox | damage receivers |
| 7 | trigger | plates, pickups, Docks, zones |
| 8 | firewall | hop-blocking fields |
| 9 | projectile | bolts, parcels, harpoons |

Machine collision mask: solid, machines, pushables, plus conduit_gate unless the body is XS. Narrow gaps need no special rule: a 1-tile (16 px) corridor admits colliders up to 14 px (S, M) and blocks L. Pushing by weight is done after `move_and_slide()` by inspecting slide collisions.

### 2.4 Intent and Controller (the enabler of the hijack hook)

```gdscript
class_name Intent extends RefCounted

var move: Vector2 = Vector2.ZERO    # zero or normalized
var aim: Vector2 = Vector2.ZERO     # zero means use facing
var primary: bool = false
var secondary: bool = false
var hop: bool = false               # press edge
var eject: bool = false             # hold-complete edge
var routine_cycle: bool = false
var pin: bool = false
var interact: bool = false
```

```gdscript
class_name Controller extends Node

## Called once per tick by the controllers system.
func decide(_machine: Machine, _tick: int) -> Intent:
	return Intent.new()
```

Controllers: `PlayerController` (reads the `InputRouter` snapshot), `AIController` (FSM preset from data), `RoutineController` (HOLD, GUARD, PATROL, REPEAT), `ScriptController` (solver bots and replays), `NullController` (dormant or crashed).

Hijack only swaps which Controller node a machine has. Abilities, movement and combat read Intents and never know who produced them.

### 2.5 System order per tick (run by the `World` node)

1. `senses`: vision cones, hearing, line-of-sight rays against `solid`
2. `controllers`: one Intent per controlled machine
3. `hijack`: targeting, transit, seize, eject, TTL (state machine in `core/hijack_fsm.gd`)
4. `abilities`: start, channel, cooldown, Heat
5. `movement`: velocity from Intent, `move_and_slide()`, pushing by weight, terrain effects (medium, hazards, conveyors)
6. `logic`: signals, plates, doors, lifts, crushers, Bitrot spread (`core/logic_graph.gd`)
7. `combat`: hitbox and hurtbox overlaps, damage, status, knockback, Open state, crash and death
8. `world`: room transitions, persistence deltas, pickups, progression flags, scrap
9. `cleanup`: spawn and despawn, event flush

### 2.6 Data formats (JSON, loaded by the `Data` autoload, validated by `core/schema.gd`)

Rules: UTF-8, snake_case keys, unknown keys are errors, keys starting with `_` (for example `_note`) are ignored because JSON has no comments. IDs are lower_snake_case and unique per kind. Room ids are `<zone>_<nn>`.

**Tiles** (`data/tiles.json`), one glyph per tile:

```json
{
  "tiles": {
    "#": { "name": "wall",    "solid": true },
    ".": { "name": "floor" },
    ",": { "name": "grime",   "clear_by": "sweep" },
    "~": { "name": "coolant", "medium": "liquid" },
    "o": { "name": "pit",     "medium": "void" },
    "^": { "name": "spikes",  "hazard": "spikes" },
    ":": { "name": "conduit", "fits": "xs" },
    "X": { "name": "cracked", "solid": true, "break_by": "ram" },
    "%": { "name": "weld",    "solid": true, "break_by": "torch" },
    "}": { "name": "belt_e",  "push": [1, 0] }
  }
}
```

Terrain rules: `solid` tiles become `StaticBody2D` collision on layer `solid` (horizontal runs merged). `fits: xs` tiles become collision on layer `conduit_gate`. `medium`, `hazard`, `push` and `clear_by` tiles have no collision; machines query them from the room's glyph grid by position (`RoomRuntime.terrain_at`). Tile art is a visual-only `TileMapLayer`.

**Body** (`data/bodies/loader.json`):

```json
{
  "id": "loader",
  "name": "Loader",
  "size": "L",
  "weight": 3,
  "medium": ["ground"],
  "speed": 2.6,
  "integrity": 14,
  "heat_max": 100,
  "heat_cooldown": 20,
  "primary": "ram",
  "secondary": "lift",
  "passives": ["knockback_resist"],
  "tags": ["machine"],
  "sprite": "loader",
  "clearance": 0,
  "garage_cost": 40,
  "unlock_zone": "bus"
}
```

**Ability** (`data/abilities/ram.json`). Code implements kinds; data sets parameters:

```json
{
  "id": "ram",
  "kind": "charge_dash",
  "heat_cost": 25,
  "cooldown": 1.4,
  "windup": 0.25,
  "params": { "distance": 5.0, "speed": 11.0, "damage": 3, "knockback": 2.0, "breaks": ["ram"] },
  "sfx": "ram"
}
```

Ability kinds to implement in `src/sim/abilities/`: `ping`, `melee_arc`, `suction`, `charge_dash`, `lift_carry`, `projectile`, `overwatch`, `overload_shot`, `tow`, `flame_cone`, `beam_channel`, `harpoon`, `bubble_shield`, `claw`, `cling`, `dash`, `throw_parcel`, `repair_beam`, `patch`.

**Enemy and AI preset** (`data/enemies/rogue_janitor.json`, `data/ai/melee_swarmer.json`):

```json
{
  "id": "rogue_janitor",
  "body": "janitor",
  "faction": "hostile",
  "integrity": 5,
  "ai": "melee_swarmer",
  "senses": { "vision": 6.0, "hearing": 4.0 },
  "open_threshold": 0.35,
  "drops": { "scrap": [1, 3] },
  "palette_variant": "hostile"
}
```

```json
{
  "id": "melee_swarmer",
  "initial": "patrol",
  "params": { "patrol_speed": 0.6, "chase_speed": 1.0, "attack_range": 1.1, "search_time": 4.0 },
  "states": {
    "patrol": { "do": "patrol_waypoints", "on": { "see_target": "chase" } },
    "chase":  { "do": "move_to_target",   "on": { "in_range": "attack", "lost_target": "search" } },
    "attack": { "do": "use_primary",      "on": { "out_of_range": "chase" } },
    "search": { "do": "wander_last_seen", "on": { "see_target": "chase", "timeout": "patrol" } }
  }
}
```

Pathfinding uses Godot's built-in `AStarGrid2D`, one per room and size class, built from the glyph grid.

**Zone** (`data/zones/boot.json`):

```json
{
  "id": "boot",
  "name": "Boot Sector",
  "palette": "amber_dim",
  "tileset": "boot",
  "music": "boot",
  "ambient": { "darkness": 0.35 },
  "rooms_target": 20
}
```

**Room** (`data/rooms/boot/boot_01.json`). One screen: 30 columns by 15 rows. Border cells that are not `#` are exits to the neighbor on that side, at the same row or column; the validator checks that the neighbor has a matching opening. This example is illustrative.

```json
{
  "id": "boot_01",
  "zone": "boot",
  "cell": [3, 11],
  "music": "boot",
  "ambient": { "darkness": 0.35 },
  "rules": { "pause_ttl_until_hijack": true },
  "exits": { "e": "boot_02" },
  "grid": [
    "##############################",
    "#............................#",
    "#............................#",
    "#....,,,.....................#",
    "#....,,,...........####......#",
    "#..................::::......#",
    "#..................####.......",
    "#..........oooooo.............",
    "#..........oooooo.............",
    "#..........oooooo............#",
    "#..........oooooo............#",
    "#............................#",
    "#......^^^^^^................#",
    "#............................#",
    "##############################"
  ],
  "entities": [
    { "id": "spawn",  "kind": "spawn_cursor", "at": [3, 12] },
    { "id": "jan1",   "kind": "machine", "model": "janitor", "state": "dormant", "at": [6, 10] },
    { "id": "plate1", "kind": "plate", "at": [20, 7], "weight": 1 },
    { "id": "door1",  "kind": "door",  "at": [26, 7], "clearance": 0 }
  ],
  "links": [ { "from": "plate1", "to": "door1" } ]
}
```

**Logic elements** (all evaluate once per tick; cycles resolve with a one-tick delay):

| Kind | Input | Output |
|---|---|---|
| plate | weight on it >= threshold | active while loaded |
| switch | interact or hit | toggles |
| latch | set / reset | stays on; `persist: true` saves it |
| timer | trigger | on for N seconds |
| and, or, not | signals | signal |
| door, lift, bridge, crusher, beam gate | signal | opens or moves; doors may need clearance |
| node | Cursor hops in | active while the Cursor is inside; operates remote machinery |

**Solver-bot script** (`data/rooms/boot/boot_01.solve`, one command per line). The bot drives a `ScriptController`. `goto` follows an `AStarGrid2D` path for the current body's size and medium, closed-loop (it re-aims every tick).

```
start                    # begin as Cursor at @spawn
hop jan1                 # seize the dormant Janitor
goto 20 7                # stand on plate1
expect door1.open
goto 29 7                # leave through the east exit
expect room boot_02
```

Commands: `start`, `hop <id|model>`, `goto x y`, `face <n|e|s|w>`, `primary [n]`, `secondary [n]`, `wait <ticks>`, `park <hold|guard|patrol|repeat>`, `pin`, `interact`, `expect <condition>`, `fail_if <condition>`. Every command has a timeout; a bot that times out fails the test.

### 2.7 Pixel art pipeline

The art rules in §1.11 apply to every asset. Godot imports PNGs as Lossless with no mipmaps (the 2D defaults); the project default filter is Nearest and transforms snap to pixels (§2.8).

**Asset contract (every source must satisfy it).** A sprite is a sheet `assets/sprites/<id>.png` plus metadata `assets/sprites/<id>.json`. Each row of the sheet is one animation. The emissive sheet has the same layout and contains only glowing pixels.

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

`validate_data.gd` enforces: sheet size is a multiple of `frame_size`; no semi-transparent pixels; every animation required by §1.11 exists; pixels outside the declared base palette are a warning.

**Two ways to produce assets (mix freely).**

1. **Text-authored (default).** `art/sprites/<id>.sprite.json` holds char-grid parts and animations composed from them. `tools/bake_art.gd` (headless, uses the Godot `Image` API) writes the sheet, the emissive sheet and the metadata. Legend: `.` transparent, `o` outline, `1` to `4` ramp shades (dark to light), `a` zone accent, `e` emissive.

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

2. **Drop-in PNG.** Any hand-drawn (Pixelorama, LibreSprite, Piskel, Aseprite), AI-generated or CC0 sheet that satisfies the contract replaces the baked file. Delete its `.sprite.json` so the baker does not overwrite it. Hand-made and baked assets can be mixed per asset, and the user can swap any asset at any time.

**Runtime.** `SpriteLibrary` builds and caches `SpriteFrames` from sheet plus metadata. Facings are down, up and side; left is the side animation with `flip_h`. Shaders live in `src/render/shaders/`: `palette_swap` (key colors to variant, for example the hostile red accent), `outline` (1 px ownership outline, cyan), `flash` (white hit flash), `open_pulse`, `heat_tint`. Damage cracks are an overlay sprite toggled at Integrity thresholds.

**Tiles.** `art/tiles/<zone>.tiles.json` defines recipes that are baked into an atlas `assets/tiles/<zone>.png`:

```json
{
  "palette": "amber_dim",
  "floor": { "recipe": "plate",    "params": { "rivets": true, "seam": 8 }, "variants": 4 },
  "wall":  { "recipe": "bulkhead", "params": { "pipes": 0.3 },              "autotile": "mask8" }
}
```

Recipe kinds: `plate`, `bulkhead`, `grate`, `circuit`, `stripes`, `conveyor` (animated), `coolant` (animated), `pit`, `decor`. Variants are seeded by tile coordinate. `TileLibrary` builds a visual-only `TileSet` from the atlas at runtime. Autotiling is our own 8-neighbor mask lookup (no Godot Terrain system).

**UI font and theme.** `art/font5x7.json` (glyph rows as strings) is baked to a BMFont (`.fnt` plus PNG) that Godot imports as a font. The UI theme uses baked nine-patch boxes. Keyboard and gamepad navigation use Godot's built-in focus system.

**Review loop.** `tools/contact_sheet.gd` (headless) renders sprites or tiles at 4x to PNG in `shots/`. `tools/shot.gd` renders a room in the real engine (non-headless) to PNG. The user approves batches (bodies, enemies, each zone kit). Approved rules go in `docs/ART.md` (palette values, light direction, silhouette per body, animation timings).

### 2.8 Rendering and project settings

Set these in `project.godot`. If a key is rejected, find its name in the editor's Project Settings.

```ini
[application]
config/name="Daemon"
run/main_scene="res://scenes/main.tscn"
config/use_custom_user_dir=true
config/custom_user_dir_name="Daemon"

[display]
window/size/viewport_width=480
window/size/viewport_height=270
window/size/window_width_override=1440
window/size/window_height_override=810
window/stretch/mode="viewport"
window/stretch/scale_mode="integer"

[physics]
common/physics_ticks_per_second=60

[rendering]
renderer/rendering_method="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
2d/snap/snap_2d_vertices_to_pixel=true

[debug]
gdscript/warnings/untyped_declaration=2

[layer_names]
2d_physics/layer_1="solid"
2d_physics/layer_2="conduit_gate"
2d_physics/layer_3="machines"
2d_physics/layer_4="pushables"
2d_physics/layer_5="hitbox"
2d_physics/layer_6="hurtbox"
2d_physics/layer_7="trigger"
2d_physics/layer_8="firewall"
2d_physics/layer_9="projectile"
```

- No camera. A room is exactly one screen, the room node sits at (0, 0), and the HUD strip covers y 240 to 270. Room transitions slide two rooms over 0.3 s while the simulation is frozen.
- Entities live under a Y-sorted `Node2D`.
- Lighting: `CanvasModulate` for ambient darkness and `PointLight2D` for emitters. `Glow` sprites are unshaded so they stay lit in the dark.
- CRT: optional `ColorRect` in a top `CanvasLayer` with a `hint_screen_texture` shader.
- Pixel rules: whole-pixel positions, screen shake in whole pixels, no sprite rotation.
- Habits: reuse `Intent` objects, cache `SpriteFrames` and shader materials, build a room's tile layer and collision once on load.

### 2.9 Audio

- `tools/bake_audio.gd` (headless) turns `data/sfx/*.json` recipes and `data/music/*.json` tracker files into WAV files in `assets/audio/` (committed).
- SFX recipe:

```json
{
  "id": "ram",
  "wave": "pulse",
  "duty": 0.25,
  "freq": [180, 60],
  "env": { "attack": 0.005, "decay": 0.18 },
  "noise_mix": 0.2,
  "bitcrush": 6,
  "gain": 0.8
}
```

- Music is a small tracker format (tempo, four channels, patterns as note strings, an order list), designed in the P8 brief. Each zone is baked as separate stems so adaptive layers can mute and unmute them in sync.
- Runtime: the `AudioBus` autoload creates the buses (Master, SFX, Music, UI) in code, pools `AudioStreamPlayer`s and sets loop modes on loaded streams.
- Tests: a recipe's output hash is deterministic, no clipping, loop seam check.

### 2.10 Save and load

- Files: `user://saves/slot1.json` to `slot3.json`, settings in `user://settings.json`. `user://` resolves to `%APPDATA%/Daemon` because of the custom user dir. Atomic write (temp file then rename), one `.bak` kept.
- Schema: `version`, `build_id`, `playtime`, `player` (current host, registered models, Garage Slots, upgrades), `flags`, `rooms` (per-room deltas only: opened doors, broken walls, cleared grime, parked hosts with routine and state, defeated unique enemies, taken pickups, latches), `map` (discovered rooms), `logs`, `scrap`.
- Migrations are numbered functions. Tests: save, load, save again gives equal dictionaries; an old-version fixture migrates.

### 2.11 Input

InputMap actions are registered in code from `data/bindings_default.json` (never hand-edit the input section of `project.godot`). Overrides live in `user://settings.json`. The `InputRouter` autoload samples once per physics tick and exposes a snapshot with press edges and hold detection (hold-to-eject, hold-to-pin). Keyboard and gamepads work through Godot's joypad support, including hot-plug.

### 2.12 Debug tools (debug builds, or the `--dev` user arg)

F1 help, F2 collision shapes, F3 perf overlay (FPS, tick ms, machine count), F4 toggle light and CRT, F5 reload data, F6 warp to room, F7 god mode, F8 cycle body, F9 screenshot to `user://shots/`, F10 start or stop input recording. Game user args (after `--`): `--smoke`, `--room <id>`, `--dev`.

### 2.13 Testing and verification

Commands (PowerShell; `$env:GODOT` is the console build):

```powershell
& $env:GODOT --headless --path . --import                                  # import and first parse
& $env:GODOT --headless --path . --script res://tools/load_all.gd          # load every .gd and .tscn
& $env:GODOT --headless --path . --script res://tools/validate_data.gd     # data, rooms, art rules
& $env:GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
& $env:GODOT --path . --quit-after 180 -- --smoke                          # graphics smoke (a window appears)
& $env:GODOT --path . --write-movie shots/frame.png --fixed-fps 30 --quit-after 30 -- --room boot_01
```

- `tools/check.ps1` runs import, load-all, validate and GUT. It fails on any non-zero exit or any `ERROR:` or `SCRIPT ERROR:` line in the output. `check.ps1 -Full` adds the graphics smoke, an export and the frozen smoke.
- Test layers: unit (RefCounted logic), data (validator), scenario (load `world.tscn`, attach a `ScriptController`, advance ticks with `await get_tree().physics_frame`; goal-based with timeouts), architecture (no Node or `Input` use in `src/core/`), visual (contact sheets and screenshots reviewed by the user, not asserted). Add `--fixed-fps 60` to run scenario tests faster than real time.
- Headless limits: no rendering, no shader compilation, no real screenshots. Shader and visual changes need the non-headless runs.
- Evidence rule: every claim in a report links an artifact (test summary, bot result, screenshot).
- Godot writes `user://logs/godot.log`; attach the relevant lines when reporting a crash.

### 2.14 Packaging (Windows)

- Export preset "Windows Desktop": 64-bit, `binary_format/embed_pck = true` (single exe), exclude filter `tests/*, tools/*, docs/*, art/*, shots/*, addons/gut/*`. `export_presets.cfg` is committed.
- Export templates must match the editor version exactly (Editor, Manage Export Templates; a user action).
- `tools/build.ps1`: `check.ps1`, then `& $env:GODOT --headless --path . --export-release "Windows Desktop" build/Daemon.exe`, then the frozen smoke `build/Daemon.exe --quit-after 180 -- --smoke`.
- Build at P0 and at the end of every phase.
- The exe is unsigned, so SmartScreen or Defender may warn. Expected; note it in the README.
- Release artifact: a zip of `build/Daemon.exe`. An Inno Setup installer is optional later.

### 2.15 Performance budgets

60 FPS at 1080p on an integrated-GPU laptop. At most 4 ms of simulation per tick, at most 150 active machines, startup under 3 s, memory under 500 MB. Profile with Godot's profiler and monitors at P1, P4, P7 and P19 and fix regressions before asking for accept. In GDScript, avoid per-tick allocations in hot loops and keep pathfinding on `AStarGrid2D`.
