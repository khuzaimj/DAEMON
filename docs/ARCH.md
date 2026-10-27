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

### 2.7 Pixel art pipeline

The art rules in §1.11 apply to every asset. Godot imports PNGs as Lossless with no mipmaps (the 2D defaults); the project default filter is Nearest and transforms snap to pixels (§2.8).

Asset contract: a sprite is a sheet `assets/sprites/<id>.png` plus metadata `assets/sprites/<id>.json`. Each row of the sheet is one animation. The emissive sheet has the same layout and contains only glowing pixels.

Two production ways:
1. Text-authored: `art/sprites/<id>.sprite.json` baked via `tools/bake_art.gd`.
2. Drop-in PNG: Hand-drawn or external assets satisfying the contract.

### 2.8 Rendering and project settings

Viewport 480×270, integer scaling. GL Compatibility renderer. Nearest texture filter. Pixel-snapped transforms and vertices. 60 physics ticks per second.

### 2.9 Audio

`tools/bake_audio.gd` (headless) synthesizes WAV files from recipes (`data/sfx/*.json`) and tracker files (`data/music/*.json`). `AudioBus` autoload manages runtime players and stems.

### 2.10 Save and load

Atomic write to `user://saves/slot1.json` - `slot3.json` and `user://settings.json`. Versioned schema with explicit migration functions.

### 2.11 Input

`InputRouter` autoload samples inputs once per tick, mapping keyboard and gamepad actions from `data/bindings_default.json` with user overrides.

### 2.12 Debug tools

F1 help, F2 collision shapes, F3 perf overlay, F4 toggle light and CRT, F5 reload data, F6 warp to room, F7 god mode, F8 cycle body, F9 screenshot, F10 input recording. CLI args: `--smoke`, `--room <id>`, `--dev`.

### 2.13 Testing and verification

Quality gate driven by `tools/check.ps1` (import, load_all, validate_data, GUT) and `tools/check.ps1 -Full` (adds smoke and export verification).

### 2.14 Packaging (Windows)

Release export preset "Windows Desktop" (64-bit embedded PCK) built with `tools/build.ps1`.

### 2.15 Performance budgets

60 FPS at 1080p. Max 4 ms simulation per tick, max 150 active machines, startup under 3 s, memory under 500 MB.
