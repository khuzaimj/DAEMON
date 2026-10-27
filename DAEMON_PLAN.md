# DAEMON — Build Plan for the Coding Agent

Version 1.1 · 2026-10-27 · Target: Windows PC · Engine: Godot 4.7.x · Agent: Gemini Flash in Antigravity · Approver: the user (solo developer)

**Changes in 1.1.** The engine is now Godot 4 (GDScript) instead of Python + pygame-ce. Art is pixel art delivered as PNG assets imported by Godot; the default authoring source is text-authored sprites baked to PNG (§2.7), and any asset can be replaced by hand-made PNG pixel art. Content data is JSON. Tests use GUT. Architecture (§2), roadmap (§3), Antigravity setup (§5) and risks (§6) were rewritten for Godot. The product spec (§1) is unchanged except §1.11 (art) and §1.12 (audio).

**Reading order.** §0 is loaded every session (it becomes `AGENTS.md`). §1 product spec (locked). §2 architecture and data formats. §3 roadmap (21 phases). §4 templates. §5 Antigravity and Godot setup. §6 risks. §7 content targets. In P0 you split this file into `docs/` so later sessions load only what they need.

---

## 0. Quick Start

Copy this section verbatim into `AGENTS.md` and `.agents/rules/daemon.md`.

**Project.** DAEMON: a top-down pixel-art action-puzzle Metroidvania for Windows PC. The player is a daemon (a background process) that hijacks machines; each machine body is an ability. Spec §1, architecture §2, roadmap §3.

**Stack.** Godot 4.7.x (standard, non-.NET build; the latest stable at project start, check godotengine.org/download; record the exact version in `docs/DECISIONS.md` and never upgrade mid-project without asking). GDScript with static typing. GL Compatibility renderer. Content data in JSON. Art as PNG pixel art. Audio as WAV baked from recipes. Tests with GUT (approved addon). Export: Windows Desktop with embedded PCK. Run Godot from PowerShell through the `GODOT` environment variable, which points at the console build (`..._win64_console.exe`) so output is captured.

**Protocol (spec-first, confirm-then-build).**
1. Session start: read `docs/STATE.md` and the active `docs/phases/Pxx-*.md`. Read other docs only when a task needs them.
2. Before a phase starts, post a Phase Brief (template in `docs/TEMPLATES.md`) and STOP. Build only after the user says "go".
3. Inside an approved phase, run tasks one at a time. After each task: `tools/check.ps1` green, commit, update `docs/STATE.md`.
4. At phase end, run `tools/check.ps1 -Full`, post a Phase Report with evidence and STOP for "accept".
5. When something is undecided, ask one question and give a recommended default. Never guess silently.
6. Scope is the full spec. Never cut features or declare an "MVP"; ordering is set by the roadmap. If a task is too big, split it.
7. Be terse: no restating the task, no re-printing files, reports under 15 lines, paths instead of pasted code.

**Hard rules.**
- Static typing everywhere. The project treats untyped declarations as errors.
- Gameplay runs only in `_physics_process` at 60 ticks per second, driven by one `World` node that calls the systems in a fixed order. `_process` is for visuals only. Time is counted in ticks. Randomness comes only from seeded `RngStreams`.
- Rules and math live in `RefCounted` classes (`src/core/`) that never touch the scene tree or `Input`. Node scripts are thin adapters. A test enforces this.
- Everything controllable is driven by `Intent`s from a Controller node (player, AI, routine, script). Only `InputRouter` and `PlayerController` read input.
- Content is JSON data, not code: bodies, abilities, enemies, rooms, zones, palettes, sprites, sfx, music, logs. Code implements kinds; data composes them.
- Tunable numbers live in data files, never as literals in logic.
- Files under about 300 lines, functions under about 50.
- No new addons or dependencies without asking. Approved: GUT.
- Keep `.tscn` files few and small (main, world, machine, UI screens). Build entities and rooms in code from data. After any `.tscn`, shader or `project.godot` edit, run the check.
- From P6 on, every puzzle room ships a `.solve` bot script that passes in `tools/check.ps1`.
- Never copy names, layouts, sprites, or text from existing games.
- Windows first: saves in `user://` (custom user dir "Daemon"), no absolute paths, test the exported exe at every phase end.
- Godot 4 only. Never write Godot 3 syntax (list in §5.6). When unsure about an API, read the docs or run a 5-line experiment; do not guess.
- Headless runs cannot render or compile shaders. Visual and shader checks use non-headless runs (`tools/shot.gd`, `check.ps1 -Full`). You cannot see the live window; the user judges feel.

---

## 1. Product spec (locked)

All numbers are starting values. They live in data files and get tuned in playtests with the user.

### 1.1 Premise and tone

- Setting: THE MERIDIAN, a derelict arcology that is one giant machine, still running after its crew vanished.
- Player: a daemon, a background process that woke up with no body.
- Antagonists: the facility's immune system (Antivirus Sentinels, Firewalls, Quarantine Pods, Bitrot, the Garbage Collector).
- Tone: lonely, wry cassette-futurism. Amber, green and cyan phosphor palettes, one dominant per zone.
- Story bible (proposed, the user may edit): the crew uploaded themselves into the Kernel to escape a failing world and left the station running. The player is their rollback process, built to restore the last good state. The Kernel (what the crew became) treats it as malware. Terminal logs reveal this across zones. Ending choice at the Kernel: ROLLBACK (restore the crew, erase the Kernel) or COMMIT (accept the new state, the daemon retires). About 64 logs, dry humor, a few lines each. Story is delivered only through logs and environment.

### 1.2 Core hook: Hijack + Park

1. **Forms.** The player is Hosted (piloting a body), Cursor (the daemon's own XS body, exposed), or in Transit. Cursor is a normal body definition.
2. **Spark TTL.** While Cursor is exposed (not in a conduit, Dock or Node) a TTL timer runs: 8 s base, upgradable to 20 s. At 0 the daemon reboots at the last Dock. Transit does not consume TTL. The tutorial room pauses TTL until the first hijack.
3. **Targeting.** Press Hop while Hosted or Cursor. Time slows to 25% (max 1.0 s). Valid targets within Link Range (base 5 tiles, +2 per upgrade, max 11) and line of sight are highlighted. Aim selects, Hop confirms, Back cancels.
4. **Valid targets.** Dormant machines with clearance at or below the player's; hostile machines that are Open; parked hosts; Nodes (infrastructure ports). Never: immune-system units, boss bodies (only their subsystems).
5. **Open.** A hostile is Open when Integrity ≤ 35% or while Overloaded (status from Drone Pulse and some hazards). Open shows a pulsing port glow.
6. **Transit.** The old host is parked immediately. The spark flies straight at 20 tiles/s, invulnerable, and is stopped by Firewall fields (the hop fails and TTL starts where it stopped). On arrival the target becomes Piloted: its controller is swapped for the PlayerController and the old controller is kept in `Parked`.
7. **Registration.** The first seizure of a body model registers it permanently in the Garage and fires a log entry.
8. **Eject.** Voluntary: hold Hop 0.5 s, become Cursor at the host's position. Forced: Integrity 0 (host Crashed, disabled until a Medic repairs it or it is recycled) or Heat 100 (host Overheated, locked 3 s).
9. **Parking.** A host you leave is Parked with the routine selected on the HUD at the moment of hopping:
   - HOLD: inert blocker and weight.
   - GUARD: stays put, uses primary on hostiles in range and line of sight.
   - PATROL: walks between its park position and the player's last Pin (default 5 tiles forward), guarding while walking.
   - REPEAT: uses primary continuously in place, facing locked.
   The Routine button cycles the selection; holding it drops a Pin.
10. **Garage and Docks.** Docks are checkpoints: save, repair and cool the current host, respawn enemies, open the Garage. The Garage fabricates any registered body for scrap (cost by tier) in the Dock bay. Garage Slots cap parked hosts persisted outside the current room (3 base, +1 per upgrade, max 6). When exceeded, the oldest are recycled for a scrap refund unless they hold a latched puzzle state.
11. **Death.** Cursor TTL expiry or Cursor killed means reboot at the last Dock, enemies respawn, no scrap loss. Parked hosts in other rooms remain.
12. **Why it is its own thing.** Bodies persist in the room as puzzle pieces, and every enemy is a future body.

### 1.3 Bodies (abilities double as Metroidvania keys)

Heat max is 100 for all bodies; cooldown 20/s; each ability has its own Heat cost in data. Speed is tiles per second.

| Body | Size | Wt | Speed | Integrity | Primary | Secondary | Passive |
|---|---|---|---|---|---|---|---|
| Cursor (base) | XS | 0 | 7.0 | 2 | Ping: reveals hidden links, nodes, secrets for 3 s | none | Enters conduits; TTL when exposed |
| Janitor | M | 1 | 3.5 | 6 | Sweep: 90° melee arc, clears grime, debris, Bitrot | Suction: pulls scrap and light debris | Immune to Bitrot |
| Loader | L | 3 | 2.6 | 14 | Ram: charge, knockback, breaks cracked walls | Lift: carry and throw crates and bodies up to M | Knockback resistant |
| Sentry | M | 2 | 0 (rotates) | 8 | Shoot: aimed bolt | Overwatch: locks an arc, auto-fires, low Heat | Armored front |
| Drone | S | 0 | 4.5 | 4 | Pulse: short electric shot, applies Overload | Tow: carries objects up to S | Hovers over pits; Heat drains 8/s while over a pit |
| Welder | M | 1 | 3.2 | 7 | Torch: short thermal cone, cuts weld seams, ignites | Arc: channelled beam, cuts barriers, high Heat | Fire immune |
| Diver | M | 1 | 3.6 (land 2.4) | 8 | Harpoon: piercing line, tethers objects | Bubble: short shield | Swims in coolant |
| Crawler | S | 1 | 4.0 | 5 | Claw: fast melee | Cling: walks magnetic walls | Insulated: ignores floor hazards |
| Courier | S | 0 | 5.5 | 5 | Parcel: thrown projectile | Dash: 0.18 s invulnerable, crosses gaps up to 3 tiles | Crosses collapsing floors |
| Medic | M | 1 | 3.4 | 6 | Repair Beam: heals hosts, repairs structures | Patch: instant small self-heal | Parked on REPEAT it heals nearby parked hosts |

Size classes (hitbox px, in `data/sizes.json`): XS 8, S 12, M 14, L 24, XL 48+.

### 1.4 Gate matrix

| Gate | Needs | Notes |
|---|---|---|
| Conduit | Cursor (XS) | tubes and vents; no TTL drain inside |
| Narrow gap (1 tile) | size ≤ M | blocks Loader |
| Grime, debris, Bitrot | Janitor Sweep | |
| Cracked wall, heavy plate (weight ≥ 3) | Loader | |
| Pit | Drone hover, or Courier Dash for gaps ≤ 3 tiles | |
| Coolant | Diver | other bodies take 15 Heat/s and cannot swim |
| Weld seam, barrier | Welder Torch or Arc | |
| Electrified or spiked floor, magnetic wall | Crawler | |
| Collapsing floor, timed door | Courier Dash | |
| Broken structure | Medic Repair Beam | |
| Clearance door L1–L4 | clearance flag | granted by bosses |
| Remote Node beyond range | Link Range level | |
| Firewall field | disable at its Node | blocks hops |

### 1.5 Enemies

Hostile and dormant units of a body model appear only from that model's unlock zone onward (a validator rule), except Janitor in Zone 1.

| Enemy | Role | Hijackable | From zone |
|---|---|---|---|
| Glitch Mite | weak erratic swarm, drains Heat on contact | no | 1 |
| Rogue Janitor | melee swarmer, two AI variants (swarmer, heavy) | yes, Janitor | 1 |
| Bitrot | spreading corrupt tiles that damage hosts; cleared by Sweep | n/a | 1 |
| Rogue Loader | charger | yes, Loader | 2 |
| Antivirus Sentinel | hunts an exposed Cursor, seeking bolts | no | 2 (intro), common from 3 |
| Rogue Sentry | stationary shooter | yes, Sentry | 3 |
| Firewall Node | projects barrier lines that block hops; disabled from its maintenance Node | no | 3 |
| Diver Bot | water ambusher | yes, Diver | 4 |
| Quarantine Pod | traps parked hosts, spawns on alarm | no | 4 |
| Welder Bot | thermal cone | yes, Welder | 5 |
| Garbage Collector (roaming) | deletes parked hosts it touches | no | 5 |
| Drone Patrol | flying skirmisher | yes, Drone | 6 |
| Crawler, Courier Bot | hazard runner, dasher | yes, Crawler / Courier | 7 |
| Medic Bot | heals other enemies; priority target | yes, Medic | 8 |

### 1.6 Bosses

Every boss is a giant machine beaten by hijacking its subsystems (actuators, lenses, valves). Each fight is a puzzle with phases. A boss body itself is never hijackable.

| Boss | Zone | Idea | Reward |
|---|---|---|---|
| Bootloader | 1 | giant press; hijack its three actuators in order | Clearance L1 |
| Dispatcher | 2 | rail-bound train-bot; hijack carriages to ram it | Bus Pass (fast travel) |
| Prefetcher | 3 | predictive turret array that fires where you were; hijack its lenses | Shard |
| Pager | 4 | leviathan that swaps room contents; hijack swap valves | Shard |
| Garbage Collector | 5 | compactor that deletes parked hosts; bait it with parked hosts | Shard |
| Overflow | 6 | recursive tower; nested copies, hijack to reduce depth | Clearance L3 |
| Scheduler | 7 | time-slice boss; only one arm is active per slice | Clearance L4 |
| Kernel | 8 | multi-phase, needs every body; ending choice | Ending |

### 1.7 World

- One connected map on a world grid of 28×18 cells. One room per cell. One room is one screen (30×15 tiles). Rooms connect by edge exits, doors and Docks.
- Target about 20 rooms per zone (16 to 26), about 160 total, plus about 10 secret rooms.
- At least 25% of upgrades require a body from a later zone (backtracking).
- Fast travel: Bus stations (Docks) unlock with Dispatcher's Bus Pass.

| Phase | Zone | Palette | Unlocks | Verbs introduced | Boss |
|---|---|---|---|---|---|
| P10 | Boot Sector | amber_dim | Janitor | hijack tutorial, conduits, grime, narrow gaps, plates, Docks | Bootloader |
| P11 | Bus Depot (hub) | green_lume | Loader, Bus Pass | heavy plates, conveyors, cracked walls, lifts, crates | Dispatcher |
| P12 | Cache | cyan_cold | Sentry, Link Range +1 | beam gates, Firewall fields, parked-guard puzzles | Prefetcher |
| P13 | Swap | teal_deep | Diver | coolant, pumps, flow puzzles | Pager |
| P14 | Heap | rust_orange | Welder | weld seams, fire, heavy Bitrot, crushers | Garbage Collector |
| P15 | Stack | violet_neon | Drone | pits, tall loops, Tow, Overload hijacking | Overflow |
| P16 | Registers | yellow_white | Crawler, Courier | electrified floors, magnetic walls, collapsing floors, timed doors | Scheduler |
| P17 | Kernel | mono_white | Medic | broken structures, all-gate gauntlets, multi-body finale | Kernel |

Dependency graph (the validator in P6 proves it is completable and softlock-free):

```
Boot Sector --(Janitor, L1)--> Bus Depot (hub)
Bus Depot --> Cache | Swap | Heap        any order; each boss drops a Shard
3 Shards = Clearance L2 --> Stack
Stack boss (Overflow) --> L3 --> Registers (needs Drone for pits)
Registers boss (Scheduler) --> L4 --> Kernel (needs every body; Medic found in the antechamber)
Later bodies reopen earlier zones: secrets, upgrades, shortcuts.
```

### 1.8 Progression items

Link Range +2 (×3), Integrity Chips +1 on every body (×12), Heat Sinks +10 Heat max (×8), TTL Extenders +3 s (×4), Garage Slots +1 (×3), Clearance L1–L4 (bosses; L2 is 3 Shards), Logs (64 plus 6 secret), Scrap (currency, from kills and pickups; spent at Garage).

### 1.9 Combat

- Real-time. Hitboxes versus hurtboxes. Damage types: kinetic, thermal, electric. Resist and vulnerability per body in data.
- Hit response: knockback, 0.5 s invulnerability, 2 to 4 frames hit-stop, small screen shake.
- Heat: abilities add Heat, electric hits add Heat. At 100 the host Overheats and you are ejected.
- Status: Overload (2 s stun, target becomes Open), Burn (damage over time), Stagger.
- Kill gives scrap. Hijack gives the body. Bosses use phases defined in data.

### 1.10 Puzzle vocabulary

Pressure plate (weight threshold), switch, latch (persistent), timer, AND/OR/NOT, door (clearance colors), lift, bridge, conveyor, crusher, beam gate and emitter, crate, collapsing floor, cracked wall, weld barrier, grime and debris, Bitrot, coolant, hazard floors, magnetic wall, pit, conduit, Node (hop in to operate remote machinery), broken structure (repairable), Firewall field, parked-guard checks, REPEAT-loop machinery.

### 1.11 Art direction

- Style: pixel art. Base resolution 480×270, integer-scaled, nearest-neighbor filtering, no sub-pixel movement. Playfield 480×240 (30×15 tiles of 16 px) plus a 30 px terminal-style HUD strip at the bottom.
- Frames are 16×16. Loader and large bodies are 32×32. Bosses are 48 to 96 px, assembled from parts.
- Three facings are drawn (down, up, side). Left is the side sheet flipped at runtime.
- Required animations per body: idle, walk (4 frames), primary (3), secondary (3), each in down, up and side; plus hurt, crash and dormant (single facing).
- Each sprite: 1 px dark outline, 4-shade ramp per hue, at most 8 colors, light from the top left, no anti-aliasing, no rotated or non-integer-scaled sprites (use sheets and flips).
- Color language: cyan outline means yours, red accent means hostile, white blink means Open, amber means interactable. These are shader effects over a shared base palette, so one sheet serves every variant.
- Zone palettes (3 hues plus accent) live in `data/palettes/`. Lighting uses Godot 2D lights. An optional CRT shader (vignette and faint row darkening) is toggleable.

### 1.12 Audio

Chip-synth only: two pulse channels, one triangle, one noise. Authored as JSON recipes and tracker files, baked to WAV by a tool. About 80 SFX recipes, one music loop per zone plus title, boss and stinger. Adaptive layers (exposed Cursor, combat, boss phases) are separate stems mixed at runtime. Buses: sfx, music, ui.

### 1.13 UX defaults

| Action | Keyboard | Gamepad (Xbox layout) |
|---|---|---|
| Move | WASD / arrows | left stick / d-pad |
| Primary | J | X |
| Secondary | K | Y |
| Hop (hold: eject) | L | RB |
| Routine (hold: drop Pin) | Q | LB |
| Interact / confirm | E | A |
| Back / pause | Esc | B / Start |
| Map | Tab | Back |

- Aim follows facing (8-way). The right stick overrides aim on gamepad. Sentry rotates with Move.
- HUD strip: body name and icon, Integrity pips, Heat bar, TTL ring when Cursor, routine icon, scrap, Link Range pips, latest log line.
- Saves: 3 slots, autosave at Docks and on zone change. Length target 8 to 10 hours. One difficulty plus assists (damage taken, TTL length, aim assist, Heat rate).
- Settings: window mode, volume buses, CRT (off, low, on), screen shake, flash reduction, key rebinding.

---

## 2. Architecture

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
| plate | weight on it ≥ threshold | active while loaded |
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

**Review loop.** `tools/contact_sheet.gd` (headless) renders sprites or tiles at 4× to PNG in `shots/`. `tools/shot.gd` renders a room in the real engine (non-headless) to PNG. The user approves batches (bodies, enemies, each zone kit). Approved rules go in `docs/ART.md` (palette values, light direction, silhouette per body, animation timings).

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

---

## 3. Roadmap

Four stages. Every system in the spec is built completely in Stage B, then Stage C fills the world with content, then Stage D finishes and ships. There is no MVP cut: the order below only decides sequencing. Sizes: S (1 to 2 sessions), M (3 to 5), L (6 to 10), XL (10+).

| Stage | Phases | Result |
|---|---|---|
| A. Foundation | P0 to P1 | project rails, tooling, engine core |
| B. Systems | P2 to P9 | every system complete and tested in the Debug Bay sandbox zone |
| C. Content | P10 to P17 | zones 1 to 8, one phase each |
| D. Finish | P18 to P20 | integration, endings, polish, release |

Playtest gates (the user plays and gives feel notes before the next phase): P1, P2, P3 (the most important), P4, P5, P7, P8, P9, P10, P13, P17, P19, P20.

Every phase starts with a Phase Brief and ends with a Phase Report (templates in §4). Task ids are `Pn.m`. The phase-end check is `tools/check.ps1 -Full`.

### Stage A: Foundation

**P0. Rails (S)**
- P0.1 User actions, listed in the Brief and confirmed by the user: install Godot (standard build, latest stable 4.7.x), install the matching export templates, set the `GODOT` environment variable to the console exe, install Git. Verify with `& $env:GODOT --version` and `git --version`.
- P0.2 Create the project and the §2.1 tree. `project.godot` per §2.8, `.gitignore`, `git init`.
- P0.3 Install GUT (approved), enable it, add `.gutconfig.json` and one sample test.
- P0.4 Main scene: 480×270 viewport with integer scaling, a palette-colored rectangle and debug text, Esc quits. The `--smoke` user arg exits after 120 frames with code 0.
- P0.5 `tools/check.ps1` (fast and `-Full`), `tools/load_all.gd`, `tools/validate_data.gd` stub.
- P0.6 Export preset, `tools/build.ps1`, first export and frozen smoke.
- P0.7 Split this file into `docs/`. Create `docs/STATE.md` and `docs/DECISIONS.md` (record the exact Godot version). Create `AGENTS.md`, `.agents/rules/daemon.md`, `tools/sync_rules.ps1`, and the P0 skills and workflows from §5.
- Acceptance: `check.ps1 -Full` green; the exe launches; the user confirms integer scaling on their monitor and that the rules and skills show up in Antigravity.

**P1. Engine core (M)**
- P1.1 Autoloads: `Events`, `Data` (JSON loader and registry), `Game` (tick counter, state).
- P1.2 `InputRouter`, InputMap from `bindings_default.json`, keyboard and gamepad, hold detection.
- P1.3 `core/` basics: `Intent`, `Controller` base, `RngStreams`, grid helpers, schema validator.
- P1.4 Room JSON loader and `RoomRuntime`: glyph grid, visual `TileMapLayer` with placeholder tiles, generated collision, terrain queries, exits. Validator v0 (dimensions, glyphs, exits match).
- P1.5 Placeholder `Machine` (colored rectangle) with `PlayerController`: movement, size classes, conduit gate layer, medium rules (liquid, void).
- P1.6 `World` node and tick, world grid, room transitions (0.3 s slide), Debug Bay zone with 4 rooms, HUD strip placeholder.
- P1.7 Debug overlay (F2, F3, F6), `tools/shot.gd`, input recorder (F10).
- Tests: terrain queries, room loader, a 24 px body cannot enter a 1-tile gap, only XS enters conduits, a scenario test walking across 4 rooms with a `ScriptController`.
- Acceptance: a placeholder Cursor crosses 4 rooms at 60 FPS; conduit and gap rules hold; the exported exe runs.

### Stage B: Systems (all built in the Debug Bay)

**P2. Machines, bodies, abilities (L)**
- P2.1 Finalize the `Machine` scene (§2.3), `BodyState`, the `Abilities` runner, `NullController`, `ScriptController`.
- P2.2 Schema loaders and validators for bodies, abilities, enemies, AI presets, sizes.
- P2.3 Heat, Integrity, cooldowns, statuses (stun, Overload, Burn), crash and overheat rules.
- P2.4 Ability kinds, one task per group: movement (`charge_dash`, `dash`, `cling`), melee (`melee_arc`, `claw`, `suction`), ranged (`projectile`, `overwatch`, `overload_shot`, `harpoon`, `throw_parcel`), channelled (`flame_cone`, `beam_channel`, `repair_beam`), utility (`ping`, `lift_carry`, `tow`, `bubble_shield`, `patch`).
- P2.5 All 10 body definitions in data with placeholder visuals. "Body Range" rooms in the Debug Bay; F8 cycles bodies.
- Tests: ability math unit tests, data validation, one scenario test per body.
- Acceptance: every body moves and acts per §1.3; size, weight and medium rules are enforced.

**P3. Hijack, Park, Garage (L)** (the core hook; the most important gate)
- P3.1 `core/hijack_fsm.gd` (targeting, transit, seize, eject; unit-tested) and the `hijack` system, using ray queries for line of sight and Firewall fields.
- P3.2 Cursor TTL, safe zones (conduits, Docks, Nodes), reboot.
- P3.3 Open rules, Link Range, registration, Garage data, Docks (save stub, heal, cool, respawn, fabricate for scrap).
- P3.4 Parked hosts and `RoutineController`: HOLD, GUARD, PATROL, REPEAT; Routine button and Pin.
- P3.5 Per-room persistence of parked hosts, Garage Slots cap and recycling.
- P3.6 Firewall fields and Node hopping (remote operation interface).
- P3.7 Minimal UI: targeting reticle, routine icon, text Garage list.
- Acceptance (Hijack Lab rooms in the Debug Bay): tutorial hijack of a dormant machine; weaken-and-seize a hostile; Loader parked on a plate with a Sentry guarding the door; Welder on REPEAT cutting a seam while you operate elsewhere; Firewall blocking a hop. All five are bot-solvable.

**P4. Combat and AI (L)**
- P4.1 Damage types, resist and vulnerability, knockback, invulnerability frames, hit-stop hooks, hitbox and hurtbox areas, scrap drops and pickups.
- P4.2 AI: FSM runner, state `do` library (patrol, chase, attack patterns, flee, guard, wander), senses, `AStarGrid2D` pathfinding per size class, group alerts.
- P4.3 Enemy roster from §1.5 as data, functional with placeholder visuals; Open indicators.
- P4.4 Immune types: Antivirus Sentinel, Firewall Node, Quarantine Pod, Bitrot, Garbage Collector.
- P4.5 Boss framework: phases, hijackable subsystems, arena scripting from data (timers, spawns, triggers). One test boss.
- Tests: damage math, FSM transitions, boss phase flow with a bot.
- Acceptance: a Combat Arena room spawns every enemy type from data, all beatable or hijackable; the test boss completes by bot.

**P5. World logic and persistence (L)**
- P5.1 `core/logic_graph.gd` (signals, tick order, one-tick delay on cycles) and the entity kinds from §2.6.
- P5.2 Hazards and terrain behaviors: coolant, pits, electrified and spiked floors, magnetic walls, conveyors, crushers, collapsing floors, grime, debris, cracked walls, weld barriers, broken structures.
- P5.3 Gates, clearance, Link Range checks, Nodes, Firewall integration.
- P5.4 Pickups, upgrades, Logs, map discovery data, Bus fast travel.
- P5.5 Save and load (3 slots, versioned, atomic), per-room deltas, settings file.
- Tests: logic ordering and propagation, persistence round trip, migrations, gate checks.
- Acceptance: Logic Lab rooms cover every element; save, quit, load restores identical state.

**P6. Content tooling (M)**
- P6.1 `validate_data.gd` complete: schema for every data kind; room rules (dimensions, glyphs, exits match neighbors, unique ids, valid links, bodies not placed before their unlock zone); art contract checks.
- P6.2 Solver-bot interpreter (`src/sim/bots/`) and the DSL from §2.6; `tools/run_bots.gd`; `.solve` files run inside `check.ps1`.
- P6.3 `progression_check.gd`: builds the gate graph from rooms and items, simulates acquisition orders, proves completability and no softlocks.
- P6.4 `map_export.gd` (PNG of the world grid with zones and gates), `contact_sheet.gd`, `shot.gd` polish.
- P6.5 `docs/CONTENT.md` regenerated from data.
- Acceptance: the bot solves every Debug Bay puzzle; `progression_check` passes on a synthetic 3-zone graph.

**P7. Art pipeline (L)**
- P7.1 Palettes (zone palettes and ramps), color language from §1.11, start `docs/ART.md`, asset contract checks in the validator.
- P7.2 `bake_art.gd`: sprite parts and animations to sheet, emissive sheet and metadata; `SpriteLibrary`; facing and flip.
- P7.3 Shaders: `palette_swap`, `outline`, `flash`, `open_pulse`, `heat_tint`; damage crack overlays.
- P7.4 Tile recipes, atlas baking, `TileLibrary`, mask8 autotiling, animated tiles; base kit for all 8 zones (floor, wall, door, hazards, decor).
- P7.5 Art for all 10 bodies and all enemy types (variants by shader), Docks, puzzle elements, pickups, Cursor spark, Firewall fields, boss part kits.
- P7.6 FX (hit sparks, hop trail, smoke, steam, arcs, heat shimmer), lighting, CRT shader, bitmap font and UI theme bake.
- P7.7 Review in batches with contact sheets and in-engine screenshots: bodies, enemies, each zone kit. The user may replace any asset with hand-made PNGs through the drop-in path.
- Acceptance: no placeholders remain in the Debug Bay; 60 FPS in the Combat Arena with FX; `check.ps1 -Full` green (shaders compile); the user approves the sheets.

**P8. Audio (M)**
- P8.1 `bake_audio.gd` synth and about 80 SFX recipes across abilities, hijack, UI, hazards and bosses.
- P8.2 Music tracker format and baker: title, 8 zone loops as stems, boss loop, stinger, ambience.
- P8.3 `AudioBus` runtime: buses, pooled players, adaptive stem mixing (exposed Cursor, combat, boss phase), volume settings.
- Tests: deterministic hashes, clipping, loop seams.
- Acceptance: zone entry never hitches; the user approves the sound palette.

**P9. UI and UX (M)**
- P9.1 HUD strip, targeting UI polish, damage and Heat feedback.
- P9.2 Screens as Godot `Control` scenes with the baked theme: title, save slots, pause, settings (display, audio, rebinding, accessibility, assists), Garage, map, log reader, reboot sequence.
- P9.3 Tutorial prompts, terminal-style dialogs, credits stub.
- Tests: a script lists every screen's text nodes and fails when any exceeds the 480×270 viewport; a non-headless run saves a screenshot of every screen for review.
- Acceptance: the full menu flow works on keyboard and gamepad; rebinding persists.

### Stage C: Content (P10 to P17, one phase per zone, see the table in §1.7)

Every zone phase follows this template (8 tasks):

- Z.1 **Zone Brief** (post and STOP for "go"): theme and story beat, palette ramp, tileset recipes, room list with a one-line purpose each, verbs and gates introduced, enemy set and AI variants, boss design (phases, subsystems), upgrades, logs, secrets (including ones that need later bodies), map sketch on the world grid (ASCII), music motif.
- Z.2 **Art kit**: tileset, decor, zone-specific sprites; contact sheet; the user approves.
- Z.3 **Rooms** in batches of 4 to 5: room JSON plus `.solve` plus screenshot; `check.ps1` green; one commit per batch.
- Z.4 **Enemy variants** and AI presets; balance with bot runs.
- Z.5 **Boss**: arena, subsystems, phases, scripted solve, reward.
- Z.6 **Logs, upgrades, secrets**; update `docs/CONTENT.md`.
- Z.7 **Audio**: zone loop, ambience, boss loop.
- Z.8 **Integration**: connect to the world graph, `progression_check.gd`, Docks and Bus station, write `docs/phases/Pxx-playtest.md`.

Zone-specific notes:
- **P10 Boot Sector**: includes the wake-up sequence, hijack tutorial pacing (about 6 of 20 rooms teach), first Dock, tutorial prompts.
- **P11 Bus Depot**: the hub with three exits; builds the Bus fast-travel network; Dispatcher drops the Bus Pass.
- **P12 to P14 (Cache, Swap, Heap)**: playable in any order; each boss drops a Shard; design cross-zone shortcuts and secrets between them.
- **P15 Stack**: entry needs 3 Shards (L2); vertical loops; Overflow recursion boss.
- **P16 Registers**: Crawler and Courier; Scheduler boss; L4 on defeat.
- **P17 Kernel**: all-gate gauntlets, Medic in the antechamber, final boss, ROLLBACK and COMMIT endings, credits.

### Stage D: Finish

**P18. Integration and endings (M)**
- P18.1 Assemble the full world graph, run `progression_check` on the real game, fix softlocks, place remaining upgrades and secrets, verify the 25% backtracking rule.
- P18.2 Log placement and story continuity pass (64 plus 6 logs); ending sequences and credits.
- P18.3 Balance: scrap economy, Garage costs, TTL, Heat, boss difficulty (bot statistics plus the user's notes).
- P18.4 Assist options and difficulty tuning.
- Acceptance: a bot-assisted run from boot to each ending passes; no softlocks.

**P19. Polish and QA (M)**
- P19.1 Juice: hit-stop, shake, particles, transitions, audio polish.
- P19.2 Performance pass against §2.15.
- P19.3 Accessibility: reduce flashing, shake toggle, readable text, cues that are not color-only (Open and hostile states).
- P19.4 Bug bash from crash replays and the user's notes; a regression replay for every fixed bug.
- P19.5 Tutorial and onboarding refinement.
- Gate: the user plays the full game.

**P20. Release (S)**
- P20.1 Final `build.ps1` build, version stamp, README (controls, known issues, SmartScreen note).
- P20.2 Smoke test on a second Windows machine or a clean user profile.
- P20.3 Backup the repo, tag `v1.0`, zip artifact; optional Inno Setup installer.

---

## 4. Templates (becomes `docs/TEMPLATES.md`)

**Phase Brief** (`docs/phases/Pxx-name.md`, post it, then STOP):

```
# Pxx — <name> · Brief
Goal: <one line>
Tasks: Px.1 ...; Px.2 ... (at most 12, each about one session)
Files and data touched: <paths>
Tests to add: <list>
Acceptance: <observable checks and commands>
Evidence I will attach: <screenshots, replays, test summary>
Assumptions and risks: <at most 3>
Questions for the user: <at most 3, each with a recommended default>
```

**Phase Report** (append to the same file, then STOP):

```
# Pxx — <name> · Report
Done: <tasks> · Commits: <n> · Tests: <n passing> · check.ps1: green
Evidence: <paths>
Deviations from the plan: <none, or list>
Known issues: <list>
Playtest: <3 to 6 lines: how to run, what to try>
Ask: accept, or changes?
```

**`docs/STATE.md`** (rewrite after every task):

```
Phase: Pxx <name> (approved <date>)   Status: in progress | awaiting accept
Last task: Px.m <summary> (commit <hash>)
Next task: Px.n <summary>
Open questions: <none or list>
Run it: & $env:GODOT --path . -- --room <id>
Known issues: <list>
```

**`docs/DECISIONS.md`**: one line each: `date · Dn · decision · reason`.

**Commits**: `Pn.m: summary`. Tag `pNN-accepted` after each accept.

**Definition of Done (every task)**: code, data and tests written; `tools/check.ps1` green; evidence for gameplay or visual claims; `docs/STATE.md` updated (and `docs/CONTENT.md` for content); committed.
---

## 5. Antigravity and Godot setup

**5.1 Rules.** Keep `AGENTS.md` (repo root) and `.agents/rules/daemon.md` identical (`tools/sync_rules.ps1`). Antigravity versions differ in which they load, so mirror both. Leave the user's global rules alone.

**5.2 Planning and approval.** Use Planning mode for Phase Briefs. Set the artifact review option so plans need the user's approval before building (option names vary by version). Start a fresh conversation per task: `docs/STATE.md` carries the context.

**5.3 Running Godot from the agent.** The agent runs PowerShell commands on the user's PC. `$env:GODOT` must point at the console build of the pinned editor version so output is captured. Commands are in §2.13. Non-headless runs (`-Full`, `shot.gd`) open a window briefly; that is expected. Before and after any non-headless run, check that no Godot process is left running (`Get-Process godot*`).

**5.4 Skills.** Workspace skills live in `.agents/skills/<name>/SKILL.md` (the older `.agent/` folder is still read). Frontmatter: `name` and `description` (third person, keyword-rich, because the agent matches skills by description). Keep each under about 80 lines; put helper scripts in a `scripts/` subfolder.

| Skill | Created in | Purpose |
|---|---|---|
| daemon-phase-protocol | P0 | brief, report and STOP rules, STATE.md updates |
| daemon-verify | P0 | run the quality gate, interpret failures, produce evidence |
| daemon-godot-guard | P0 | Godot 4 GDScript syntax, typing, scene and settings editing rules |
| daemon-add-body | P2 | add a body: JSON, ability params, sprite, tests, Garage registration |
| daemon-add-enemy | P4 | enemy and AI preset, tests, validator rules |
| daemon-add-room | P6 | room JSON grid rules, entities, links, `.solve`, screenshot, CONTENT.md |
| daemon-art-bake | P7 | sprite and tile JSON formats, bake, validate, contact sheets, drop-in PNG rules |
| daemon-sfx-music | P8 | recipe and tracker syntax, bake, tests |
| daemon-zone-production | P10 | the zone template from Stage C |
| daemon-release | P20 | release checklist |

Write each skill in the phase where the thing it describes exists, so it matches the real formats. Starter drafts:

`.agents/skills/daemon-phase-protocol/SKILL.md`

```markdown
---
name: daemon-phase-protocol
description: Runs the DAEMON confirm-then-build workflow. Use when starting, continuing or finishing a phase or task of the DAEMON game, writing a Phase Brief or Phase Report, or updating docs/STATE.md.
---

# DAEMON phase protocol

## Goal
Keep work spec-first and approval-gated while spending few tokens.

## Instructions
1. Read docs/STATE.md and the active docs/phases file. Nothing else unless a task needs it.
2. New phase: write the Phase Brief (docs/TEMPLATES.md) to docs/phases/Pxx-name.md, post it, STOP until the user says "go".
3. Approved phase: one task at a time. After each task run `tools/check.ps1`. If red, fix first. Then commit `Pn.m: summary` and update docs/STATE.md.
4. Phase done: run `tools/check.ps1 -Full`, write the Phase Report with evidence paths, STOP until the user says "accept", then tag `pNN-accepted`.
5. Undecided question: ask one question with a recommended default.

## Constraints
- Never expand or cut scope; split tasks instead.
- Reports under 15 lines, no pasted code.
- Never start the next phase without "go".
```

`.agents/skills/daemon-verify/SKILL.md`

```markdown
---
name: daemon-verify
description: Verifies DAEMON changes with the quality gate and evidence. Use after finishing any task, when checks fail, or when a gameplay, shader or visual claim needs proof.
---

# DAEMON verify

## Instructions
1. Run `tools/check.ps1`. On failure list each failing item in one line (file:line, message) and fix before anything else.
2. Gameplay change: run the matching GUT scenario test or `.solve` bot and cite the result line.
3. Visual or shader change: run `tools/check.ps1 -Full`, then render with `tools/shot.gd` or `tools/contact_sheet.gd`; cite the PNG paths in shots/.
4. Path or data-loading change: run `tools/build.ps1` and the frozen smoke.
5. Make sure no Godot process is left running after non-headless runs.

## Constraints
- Do not claim something works without an artifact.
- You cannot see the live window; the user judges feel.
```

`.agents/skills/daemon-godot-guard/SKILL.md`

```markdown
---
name: daemon-godot-guard
description: Enforces Godot 4 GDScript syntax, static typing and project conventions for DAEMON. Use whenever writing or editing GDScript, scenes, shaders or project settings for the DAEMON game.
---

# DAEMON Godot guard

## Instructions
1. Godot 4 only: `@export`, `@onready`, `@tool`, `await`, `signal.connect(callable)`, `CharacterBody2D` (set `velocity`, call `move_and_slide()` with no arguments), `TileMapLayer`, `Vector2i` for cells.
2. Never write Godot 3 syntax (`export`, `onready`, `yield`, string-based `connect`, `KinematicBody2D`, `TileMap.set_cell(x, y, id)`, `instance()`).
3. Type everything: variables, parameters, returns, typed arrays such as `Array[Intent]`. Untyped declarations are errors in this project.
4. Gameplay lives only in `_physics_process`, called by the World node in system order. Never in `_process`.
5. Rules and math go in RefCounted classes under src/core with no scene-tree or Input access.
6. Prefer building nodes in code and keep `.tscn` files tiny. After editing a `.tscn`, shader or project.godot, run `tools/check.ps1`; for shaders also run `-Full`.
7. Unsure about an API? Read the official docs or run a 5-line experiment with `--script`. Do not guess.

## Constraints
- No new addons. Never hand-edit UIDs. Commit `.uid` and `.import` files.
```

**5.5 Workflows** live in `.agents/workflows/<name>.md` (YAML `description`, then numbered steps; run with `/name`). Create `/check`, `/brief`, `/report`, `/room-batch`. Starter:

```markdown
---
description: Run the DAEMON quality gate and report only failures
---
1. Run `tools/check.ps1`.
2. If it passes, reply "check: green" and stop.
3. If it fails, list each failing item in one line (file:line, message). Do not paste logs.
```

**5.6 Working with a fast model.**
- One task per conversation. Refer to files by path. Read line ranges, not whole files. Never paste whole files into chat.
- A task touching more than 3 files starts with a 10-line plan.
- Two failed attempts at the same error: stop, report what you tried, ask.
- No drive-by refactors. Touch only what the task needs.
- Change numbers in data files, not in code.
- Write large files in pieces. Keep each tool call small.
- Do not invent APIs. When unsure how a Godot class behaves, read its docs page or run a 5-line experiment first.
- Commit small and often so any step can be reverted.

Godot 3 habits to avoid (use the Godot 4 form): `export` to `@export`; `onready` to `@onready`; `tool` to `@tool`; `yield(...)` to `await ...`; `connect("sig", obj, "method")` to `sig.connect(callable)`; `KinematicBody2D` to `CharacterBody2D`; `move_and_slide(vel)` to set `velocity` then `move_and_slide()`; `TileMap.set_cell(x, y, id)` to `TileMapLayer.set_cell(Vector2i, source_id, atlas_coords)`; `instance()` to `instantiate()`; `rand_range` to `randf_range`.

**5.7 Optional extras (ask the user first).**
- GDScript language support: point the Godot editor's external editor setting at Antigravity and install a GDScript extension if its marketplace offers one. The language server needs the Godot editor running.
- A Godot MCP server (for example the open-source Coding-Solo/godot-mcp, which needs Node.js 18 or newer) lets the agent launch the editor, run the project and read debug output. It is not required; `check.ps1` covers verification.

---

## 6. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Godot 3 syntax or invented GDScript APIs | godot-guard skill, untyped declarations as errors, load-all check, 5-line experiments |
| Hand-edited `.tscn` or `project.godot` breaks the project | few small scenes, code-built entities and rooms, import check after every edit |
| Headless runs cannot render or compile shaders | `check.ps1 -Full` at phase end, screenshots from non-headless runs |
| Godot version drift or export template mismatch | pin the version in DECISIONS.md, templates must match exactly, no mid-project upgrades |
| Physics is not bit-exact | outcome-based tests with timeouts, closed-loop bots |
| Hijack and Park is not fun | P3 is the biggest gate; Hijack Lab rooms; tune numbers in data with the user |
| Unsolvable puzzles | solver bots in `check.ps1`, room validator, `progression_check` |
| Pixel art quality | art bible, contact-sheet and in-engine review per batch, drop-in PNG path, user approval before bulk production |
| Scope size | CONTENT.md tracker, zone template, batch production; split tasks, never cut scope |
| Save compatibility | versioned schema, migration tests, atomic writes |
| Packaging surprises | export at P0 and at every phase end (`-Full`) |
| Unsigned exe warnings | expected; documented in the README |
| GDScript performance | budgets in §2.15, RefCounted logic, `AStarGrid2D`, profile at P1, P4, P7, P19 |
| Model drift | small tasks, rules, STATE.md, tests, frequent commits |

---

## 7. Content targets and tracker

| Item | Target |
|---|---|
| Zones | 8 |
| Bodies | 10 (including Cursor) |
| Enemy and hazard types | 14 |
| Bosses | 8 |
| Rooms | about 160 plus about 10 secret |
| Logs | 64 plus 6 secret |
| Upgrades | Link Range ×3, Integrity Chips ×12, Heat Sinks ×8, TTL Extenders ×4, Garage Slots ×3 |
| Sprite sheets | 10 bodies, immune-system units, 8 boss kits, Docks, puzzle elements, pickups |
| Tile atlases | 8 (one per zone) |
| SFX | about 80 |
| Music | 8 zone loops, title, boss, stinger |
| Endings | 2 (ROLLBACK, COMMIT) |

`docs/CONTENT.md` holds one table per kind with columns `id | zone | status | notes`. Status values: `todo`, `briefed`, `built`, `validated`, `accepted`. `tools/validate_data.gd` regenerates the counts against these targets.

*End of plan.*
