# 3. Roadmap

Four stages. Every system in the spec is built completely in Stage B, then Stage C fills the world with content, then Stage D finishes and ships. There is no MVP cut: the order below only decides sequencing. Sizes: S (1 to 2 sessions), M (3 to 5), L (6 to 10), XL (10+).

| Stage | Phases | Result |
|---|---|---|
| A. Foundation | P0 to P1 | project rails, tooling, engine core |
| B. Systems | P2 to P9 | every system complete and tested in the Debug Bay sandbox zone |
| C. Content | P10 to P17 | zones 1 to 8, one phase each |
| D. Finish | P18 to P20 | integration, endings, polish, release |

Playtest gates (the user plays and gives feel notes before the next phase): P1, P2, P3 (the most important), P4, P5, P7, P8, P9, P10, P13, P17, P19, P20.

Every phase starts with a Phase Brief and ends with a Phase Report (templates in `docs/TEMPLATES.md`). Task ids are `Pn.m`. The phase-end check is `tools/check.ps1 -Full`.

### Stage A: Foundation

**P0. Rails (S)**
- P0.1 User actions, listed in the Brief and confirmed by the user: install Godot (standard build, latest stable 4.7.x), install the matching export templates, set the `GODOT` environment variable to the console exe, install Git. Verify with `& $env:GODOT --version` and `git --version`.
- P0.2 Create the project and the §2.1 tree. `project.godot` per §2.8, `.gitignore`, `git init`.
- P0.3 Install GUT (approved), enable it, add `.gutconfig.json` and one sample test.
- P0.4 Main scene: 480x270 viewport with integer scaling, a palette-colored rectangle and debug text, Esc quits. The `--smoke` user arg exits after 120 frames with code 0.
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
- Tests: a script lists every screen's text nodes and fails when any exceeds the 480x270 viewport; a non-headless run saves a screenshot of every screen for review.
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

## 5.4 Workspace Skills Schedule

Write each skill in `.agents/skills/<name>/SKILL.md` in the phase where the thing it describes exists, so it matches the real formats. Keep each under about 80 lines; put helper scripts in a `scripts/` subfolder.

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
