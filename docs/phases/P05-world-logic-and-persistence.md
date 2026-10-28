# P05 — World logic and persistence · Brief

**Status:** APPROVED 2026-10-28 with guardrails G1–G9 (below). Reviewed by Claude, standing in for Argon at the user's request. P5.1 core is delivered (see "P5.1 contract"); Gemini starts at P5.1 integration.

**Goal:** Implement the logic graph simulation, puzzle interactables and actuators, hazard terrain mechanics, gate clearance and firewall node systems, progression items and pickups, and the atomic versioned save/load system.

---

## Tasks
- **P5.1 Logic Graph & Puzzle Entities (Division of Labor: Argon-Authored Task):**
  - Integrate `src/core/logic_graph.gd` (`RefCounted`: evaluates signals once per tick in System 6 `_step_logic`, resolving cyclic loops with a deterministic 1-tick delay) and its unit test `tests/unit/test_logic_graph.gd`.
  - Implement/complete all logic entity kinds from `docs/ARCH.md` §2.6 and `docs/SPEC.md` §1.10: `plate` (weight threshold check against machines/crates), `switch` (interact or projectile/melee hit toggles), `latch` (set/reset inputs; `persist: true` saves state across loads), `timer` (active for N seconds / ticks upon trigger), logic gates (`and`, `or`, `not`), and actuators (`door` with clearance L0-L4, `lift`, `bridge` over pits, `crusher`, `beam_gate` + emitter).
- **P5.2 Hazards, Terrain Behaviors & Breakables:**
  - Complete terrain & hazard rules in `data/tiles.json`, `RoomRuntime`, and `Machine`: `coolant` (`~`: drains 15 Heat/s for non-Diver hosts), `pit` (`o`: layer-10 barrier already built in P2.4a; see G4 for what "voids" means), `spikes` (`^`: periodic or contact damage; Crawler `insulated` ignores), `electrified` floor (adds Heat + electric damage; Crawler `insulated` ignores), `magnetic` wall (Crawler `cling` traverses), `conveyor` belts (`}` E, `{` W, `A` N, `V` S with `push: [dx, dy]` velocity offset; `^` stays spikes, see G1), `collapsing` floor (collapses into pit as a whole connected region after a non-Courier steps on it (G5); Courier `collapse_cross` crosses safely), `grime` (`,`: cleared by Janitor `sweep`), `cracked` wall (`X`: broken by Loader `ram`), `weld` barrier (`%`: cut by Welder `torch` or `arc`), and `broken_structure` entity (repaired by Medic `repair_beam` to activate/open).
- **P5.3 Gates, Clearance, Link Range & Node/Firewall Integration:**
  - Enforce clearance checks (`clearance` L1-L4 on doors and machines; L2 unlocked automatically upon collecting 3 boss `shards` per §1.7/§1.8).
  - Hop targeting: enforce Link Range levels (`link_range` upgrades) when calculating max distance to dormant hosts and Nodes.
  - Node & Firewall integration: `node` interactable (Cursor hops in to remotely toggle linked machinery or disable connected Firewall barriers); `firewall` lines block Cursor hops until disabled at source node.
  - Fix P4 tracking in `CombatSystem._process_enemy_death`: only append unique `enemy.entity_id` (not shared template `enemy.enemy_id`) to `defeated_enemies_in_room` so defeating one enemy of a type doesn't suppress other instances of the same type on room reload. Two-tier rule in G6.
- **P5.4 Pickups, Progression Items, Logs, Map Discovery & Bus Fast Travel:**
  - Implement progression pickups: `link_range` (+2 max distance x3), `integrity_chip` (+1 max integrity on every body x12), `heat_sink` (+10 Heat max x8), `ttl_extender` (+3s Cursor TTL x4), `garage_slot` (+1 slot x3), `clearance` (L1-L4), boss `shard` (x3), and `bus_pass`.
  - Implement `LogPickup` / terminal log reader data (`Events.log_found`, stored in `Game.logs`).
  - Track discovered rooms (`Game.discovered_rooms`) on room transitions.
  - Implement Bus fast travel between visited Docks once `bus_pass` is acquired.
- **P5.5 Save and Load System (`src/autoload/save_system.gd`):**
  - Register `SaveSystem` autoload in `project.godot`.
  - Save files `user://saves/slot1.json` to `slot3.json` and settings in `user://settings.json` using atomic writes (write to `.tmp` then rename, keeping one `.bak`).
  - Schema per `docs/ARCH.md` §2.10 (determinism rules in G7): `version`, `build_id`, `playtime`, `player` (current host, registered models, Garage slots, upgrades, clearance), `flags`, `rooms` (per-room deltas only: opened doors, broken/cleared tiles, parked hosts with routine and state, defeated unique enemies, taken pickups, persistent latches), `map` (discovered rooms), `logs`, `scrap`.
  - Numbered migration functions (e.g. v0 -> v1 fixture migration test) and round-trip equality test (`save -> load -> save` produces equal dictionaries).
  - Author Debug Bay "Logic Lab" rooms (`debug_11.json` and `debug_12.json`, updating `data/zones/debug.json` `rooms_target` to 12) testing logic gates, hazards, progression pickups, and save/load state restoration.

---

## Files and Data Touched
- `src/core/logic_graph.gd` (Argon-authored)
- `src/sim/systems/logic_system.gd`
- `src/sim/world.gd`
- `src/sim/room_runtime.gd`
- `src/sim/machine.gd`
- `src/sim/entities/door.gd`
- `src/sim/entities/plate.gd`
- `src/sim/entities/switch.gd`
- `src/sim/entities/latch.gd`
- `src/sim/entities/timer_entity.gd`
- `src/sim/entities/lift.gd`
- `src/sim/entities/bridge.gd`
- `src/sim/entities/crusher.gd`
- `src/sim/entities/beam_gate.gd`
- `src/sim/entities/remote_node.gd`
- `src/sim/entities/firewall_node.gd`
- `src/sim/entities/broken_structure.gd`
- `src/sim/entities/progression_pickup.gd`
- `src/sim/entities/log_pickup.gd`
- `src/autoload/game.gd`
- `src/autoload/events.gd`
- `src/autoload/save_system.gd`
- `project.godot`
- `data/tiles.json`
- `data/zones/debug.json`
- `data/rooms/debug/debug_11.json`
- `data/rooms/debug/debug_12.json`
- `docs/STATE.md`
- `docs/phases/P05-world-logic-and-persistence.md`

---

## Tests to Add
- `tests/unit/test_logic_graph.gd` (Argon-authored): Evaluation order, AND/OR/NOT evaluation, latches, timers, and deterministic 1-tick cycle resolution.
- `tests/unit/test_puzzle_entities.gd`: Plate weight thresholds, switch toggles, persistent latches, timers, doors, lifts, bridges, and crushers.
- `tests/unit/test_terrain_hazards.gd`: Coolant Heat accumulation, pit voids, spikes/electrified floors, conveyors, collapsing floors, cracked walls, weld barriers, and broken structure repair.
- `tests/unit/test_clearance_and_firewalls.gd`: Clearance L1-L4 door/machine gating, 3 Shards -> L2 unlock, Link Range hop limit enforcement, and Remote Node / Firewall disabling.
- `tests/unit/test_progression_and_pickups.gd`: Pickups for Link Range, Integrity Chips, Heat Sinks, TTL Extenders, Garage Slots, Logs, and Bus Pass fast travel.
- `tests/unit/test_save_system.gd`: Atomic write mechanics, `.bak` backup recovery, round-trip equality test (`save -> load -> save`), schema compliance, and version migration function tests.
- `tests/scenario/test_logic_lab.gd`: Full scenario run through `debug_11` and `debug_12`, solving puzzles, altering room deltas, saving, reloading, and asserting complete delta restoration.

---

## Acceptance
- `tools/check.ps1 -Full` green with zero test failures, zero errors, and zero orphan nodes.
- Validator v1 validates all 12 Debug Bay rooms, bodies, enemies, AI presets, and save schemas.
- Logic graph propagates signals correctly once per tick in System 6, resolving cyclic links with 1-tick delay.
- All hazards, conveyors, collapsing floors, and breakables respond according to spec and host immunities.
- Unique enemy death persistence fix verified: defeating an enemy records its unique `entity_id` so remaining identical enemies persist across reload.
- Save files (`slot1.json`-`slot3.json`, `settings.json`) write atomically with `.bak` backups; round-trip save-load-save produces identical dicts; version migrations pass.
- Logic Lab rooms `debug_11` and `debug_12` demonstrate every logic entity, hazard, pickup, and save/load state.
- Windows binary (`build/Daemon.exe`) builds and passes smoke test.

---

## Evidence I Will Attach
- Test output from `tools/check.ps1 -Full` showing passing unit, scenario, and persistence tests.
- Screenshots `shots/debug_11.png` and `shots/debug_12.png` (Logic Lab rooms).
- Verification log showing round-trip save-load JSON diff is empty.

---

## Assumptions and Risks
1. **Argon Logic Graph Handoff**: `src/core/logic_graph.gd` and its unit tests will be provided by Argon and conform strictly to pure `RefCounted` core rules without scene tree or input dependencies.
2. **Room Delta Granularity**: Room persistence stores only mutations/deltas (opened doors, broken tiles, persistent latches, taken pickups, unique enemy deaths, parked hosts), not full room snapshots, keeping save files compact (< 50 KB).
3. **Atomic File Safety on Windows**: File rename over existing files on Windows requires deleting the target or renaming the target to `.bak` first before renaming `.tmp` to target. `SaveSystem` will handle this sequence cleanly.

---

## Questions for the User
1. **P5.1 Division of Labor**: Confirm that you will provide Argon's implementation of `src/core/logic_graph.gd` and `tests/unit/test_logic_graph.gd` upon approval before we start P5.1?
   *(Recommended: Yes, user will provide Argon's code for P5.1).*
   **Resolved:** Claude authored `src/core/logic_graph.gd`, `src/core/logic_validation.gd`, and the tests in place of Argon (33 new tests; with the 45 P02 tests that is 78/78 on the pinned Godot 4.7.2 with zero leaks, measured against the P02 tree on GitHub, so re-run `check.ps1` on your P4 tree). Copy them in; P5.1 is then integration only.
2. **Conveyor Physics Interaction**: Should conveyor belts apply push velocity during System 5 movement via an additive velocity vector `push * speed` (e.g. 32 px/s) while a machine is occupying the tile?
   *(Recommended: Yes, add conveyor push to velocity in System 5 movement so players/enemies can fight or ride the current).*
   **Approved: Yes**, with the speed stored in data (G2), applied additively before `move_and_slide()` so weight pushing still works. Machines only; hovering bodies (Drone) are unaffected. Crates on belts wait for P11 where belts and crates are introduced (§1.7).
3. **Collapsing Floor Delay**: Set collapsing floor delay to 30 ticks (0.5 seconds) after step-on before it transforms into a pit tile?
   *(Recommended: Yes, 30 ticks allows Courier to cross safely and gives other bodies a brief reaction window).*
   **Approved: Yes as a data default (G2), but collapse is region-wide, not per tile (G5).** Per tile, every walking body outruns 30 ticks (1.2 to 2.75 tiles covered) and the floor would not gate anything.

---

## Approval guardrails (all binding for P5)

- **G1 Glyph collision.** The brief gave `^` to conveyor-north, but `^` is spikes in §2.6 and `data/tiles.json`, and 8 cells of existing debug rooms use it. Final table: `}` belt_e (exists), `{` belt_w, `A` belt_n, `V` belt_s, `=` electrified, `M` magnetic wall, `-` collapsing floor. Existing rooms use only `# % , . : X ^ o ~`, so these are free. Add them to `tiles.json` and ARCH §2.6 before any room uses them. Magnetic wall needs a new physics layer 11 `magnetic` (project.godot edit, then check) so only the Crawler's `cling` drops that mask bit; record it in DECISIONS.
- **G2 Tunables are data.** Coolant 15 Heat/s, spike and electric damage and interval, conveyor speed, collapse delay, and fall rules go in `data/tiles.json` (or a `rules` block in it), with `Schema` extended in the same task. Q2's 32 px/s and Q3's 30 ticks are default values in data, never literals in logic (hard rule).
- **G3 Pure core and file size.** On `master`, `machine.gd` is 414 lines and `world.gd` 553, already over the 300-line rule. Put hazard and terrain math in `src/core/terrain_rules.gd` (RefCounted, unit-tested) with a thin adapter system under `src/sim/systems/`. Put clearance and upgrade math in core too. `SaveSystem` stays a thin autoload over `src/core/save_data.gd` (normalize, migrate, validate: pure, no file IO). `machine.gd`, `world.gd`, `room_runtime.gd` get call sites only, no net growth of logic.
- **G4 Pit meaning.** A pit is already a layer-10 barrier (P2.4a): bodies cannot walk into it, and a dash that ends over `void` is lethal via `take_damage(..., "void")`. P5.2 must not make walking into a pit kill (impossible) or duplicate that. The only new fall case is a floor collapsing under a unit; it uses the same `void` rule.
- **G5 Collapsing floor is a region.** On first non-Courier contact, the whole 4-connected region of `-` tiles collapses together after the data delay (default 30 ticks). Courier (`collapse_cross`) and Drone (`pit_hover`) never trigger it. Collapse state is session-only: resets on room re-entry, never saved (no softlock, nothing to put in the save).
- **G6 Enemy death is two-tier** (§1.2.10 and §1.2.11: Docks and reboot respawn enemies). Session: `defeated_enemies_in_room` holds the room-JSON entity `id` (never the template `enemy_id`, never the Godot instance id), cleared on Dock rest or reboot. Saved: `rooms[room].defeated_unique` only for entities flagged `"unique": true`. Test: kill 1 of 2 identical enemies, leave, re-enter, exactly 1 remains.
- **G7 Save determinism.** `JSON.parse_string` turns every integer into a float. Verified on 4.7.2: after one round trip `3` is written as `3.0`, and even `original == loaded` is false. A naive save, load, save therefore fails both acceptance checks. Required: write with `JSON.stringify(data, "\t", true)` (sorted keys); restore integer types on load through the schema; JSON-native types only (`Vector2i` as `[x, y]`, string keys only); `playtime` in ticks. Load order: `slotN.json`, then `.bak` if the main file is missing, unparseable, or fails the schema; a stray `.tmp` is ignored. Write order: `.tmp`, re-parse to verify, move old file to `.bak`, rename `.tmp`; on failure restore `.bak`. Save visited Docks (Bus travel needs them) under `map`. The P3.3 Dock save stub calls `SaveSystem.save_slot()`.
- **G8 Upgrades and clearance.** Upgrades are counts in `Game.upgrades`; effect per count lives in data; applied when a body spawns and to the live host on pickup. Any literal `100` Heat becomes `heat_max`. Every pickup has a stable room-entity id, recorded in `taken_pickups`. Clearance is an integer level that only ever rises (`max`); the L2 grant at 3 shards is computed on pickup and stored in `player.clearance`.
- **G9 Lab capacity.** If `debug_11` and `debug_12` cannot hold every element, hazard and pickup, stop and ask before adding `debug_13` (it changes `rooms_target`).

## P5.1 contract (core delivered; Gemini does the integration)

**Delivered, do not rewrite** (extend only through review): `src/core/logic_graph.gd`, `src/core/logic_validation.gd`, `tests/unit/test_logic_graph.gd`, `test_logic_graph_cycles.gd`, `test_logic_validation.gd`, `logic_fixtures.gd` (+ `.uid` files). 33 tests. Run `--import` once (new `class_name`s), then `tools/check.ps1`.

**Room JSON.** Elements use their existing `kind`. Params: plate `weight` (default 1); timer `duration` in seconds; latch `persist`, `on`; switch `on`. Links gain an optional `port`: `in` (default; all but latch) or `set` (default for latch) / `reset`. Kind strings assumed: `plate switch latch timer and or not door lift bridge crusher beam_gate emitter node firewall broken_structure`. A different spelling is a one-line edit in `LogicGraph.BEHAVIOR_BY_KIND` plus `test_logic_kinds`.

**Per tick, System 6 only** (`src/sim/systems/logic_system.gd`; entities never step the graph themselves):
1. `set_load(plate_id, summed_weight_of_machines_and_crates_on_it)` for each plate. Cursor weighs 0, so it never presses one.
2. `set_sensor(node_id, cursor_inside)` for each Node. `trigger(switch_id)` for each interact or hit that tick.
3. `step()` exactly once.
4. For ids in `get_changed()`, push `is_active(id)` to the actuator and emit its `Events` signal. The first step reports everything that starts high, which is the initial sync.

**Lifecycle.** Room load: `setup(entities, links)`, then `restore_persistent_state(room_delta.latches)` before the first step. Save or unload: `get_persistent_state()` (deltas only). Repair finished: `force_state(id, true)`. `setup` returns errors and leaves the graph empty on bad data (fails closed).

**Entity semantics stay in the entity.** The graph only says "energized". Recommended: door opens when energized and `Game.clearance >= door.clearance` (an unlinked door is energized by default); firewall is disabled while energized. Record each choice in DECISIONS.

**Gemini checklist for P5.1:** (a) wire the above; (b) call `LogicGraph.validate(room.entities, room.links)` for every room in `tools/validate_data.gd`; (c) add `port` and the params to ARCH §2.6; (d) append to DECISIONS: one-tick delay goes on the loop-closing link found by depth-first search from sorted ids (authoring order never matters); empty gates are false, NOT of several inputs is NOR; latch reset beats set; timer restarts on a rising edge and lasts exactly N ticks; switch toggles at most once per tick; edges reference sources by index so puzzle loops never become RefCounted cycles (a regression test guards this); (e) STATE.md: `Last task: P5.1 core delivered`, `Next task: P5.1 integration`.

---

# P05 — World logic and persistence · Report
Done: P5.1, P5.2, P5.3, P5.4, P5.5 · Commits: 11 · Tests: 161 passing (1198 asserts) · check.ps1 -Full: green
Evidence: shots/debug_11.png, shots/debug_12.png, tests/unit/test_save_system.gd (round-trip equality verified)
Deviations from the plan: Pure core SaveData and TerrainRules created in src/core/ per G3 to prevent Godot node file bloat.
Known issues: none
Playtest: Run `& build/Daemon.exe -- --room debug_11` to test plates, switches, latches, timers, conveyors, collapsing floors, and clearance doors; navigate east to `debug_12` for progression pickups and dock save/load testing.
Ask: accept, or changes?

