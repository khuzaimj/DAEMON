# P05 — World logic and persistence · Brief

**Goal:** Implement the logic graph simulation, puzzle interactables and actuators, hazard terrain mechanics, gate clearance and firewall node systems, progression items and pickups, and the atomic versioned save/load system.

---

## Tasks
- **P5.1 Logic Graph & Puzzle Entities (Division of Labor: Argon-Authored Task):**
  - Integrate `src/core/logic_graph.gd` (`RefCounted`: evaluates signals once per tick in System 6 `_step_logic`, resolving cyclic loops with a deterministic 1-tick delay) and its unit test `tests/unit/test_logic_graph.gd`.
  - Implement/complete all logic entity kinds from `docs/ARCH.md` §2.6 and `docs/SPEC.md` §1.10: `plate` (weight threshold check against machines/crates), `switch` (interact or projectile/melee hit toggles), `latch` (set/reset inputs; `persist: true` saves state across loads), `timer` (active for N seconds / ticks upon trigger), logic gates (`and`, `or`, `not`), and actuators (`door` with clearance L0-L4, `lift`, `bridge` over pits, `crusher`, `beam_gate` + emitter).
- **P5.2 Hazards, Terrain Behaviors & Breakables:**
  - Complete terrain & hazard rules in `data/tiles.json`, `RoomRuntime`, and `Machine`: `coolant` (`~`: drains 15 Heat/s for non-Diver hosts), `pit` (`o`: voids non-Drone / non-dashing units), `spikes` (`^`: periodic or contact damage; Crawler `insulated` ignores), `electrified` floor (adds Heat + electric damage; Crawler `insulated` ignores), `magnetic` wall (Crawler `cling` traverses), `conveyor` belts (`}`/`{`/`v`/`^` with `push: [dx, dy]` velocity offset), `collapsing` floor (collapses into pit ticks after a non-Courier steps on it; Courier `collapse_cross` crosses safely), `grime` (`,`: cleared by Janitor `sweep`), `cracked` wall (`X`: broken by Loader `ram`), `weld` barrier (`%`: cut by Welder `torch` or `arc`), and `broken_structure` entity (repaired by Medic `repair_beam` to activate/open).
- **P5.3 Gates, Clearance, Link Range & Node/Firewall Integration:**
  - Enforce clearance checks (`clearance` L1-L4 on doors and machines; L2 unlocked automatically upon collecting 3 boss `shards` per §1.7/§1.8).
  - Hop targeting: enforce Link Range levels (`link_range` upgrades) when calculating max distance to dormant hosts and Nodes.
  - Node & Firewall integration: `node` interactable (Cursor hops in to remotely toggle linked machinery or disable connected Firewall barriers); `firewall` lines block Cursor hops until disabled at source node.
  - Fix P4 tracking in `CombatSystem._process_enemy_death`: only append unique `enemy.entity_id` (not shared template `enemy.enemy_id`) to `defeated_enemies_in_room` so defeating one enemy of a type doesn't suppress other instances of the same type on room reload.
- **P5.4 Pickups, Progression Items, Logs, Map Discovery & Bus Fast Travel:**
  - Implement progression pickups: `link_range` (+2 max distance x3), `integrity_chip` (+1 max integrity on every body x12), `heat_sink` (+10 Heat max x8), `ttl_extender` (+3s Cursor TTL x4), `garage_slot` (+1 slot x3), `clearance` (L1-L4), boss `shard` (x3), and `bus_pass`.
  - Implement `LogPickup` / terminal log reader data (`Events.log_found`, stored in `Game.logs`).
  - Track discovered rooms (`Game.discovered_rooms`) on room transitions.
  - Implement Bus fast travel between visited Docks once `bus_pass` is acquired.
- **P5.5 Save and Load System (`src/autoload/save_system.gd`):**
  - Register `SaveSystem` autoload in `project.godot`.
  - Save files `user://saves/slot1.json` to `slot3.json` and settings in `user://settings.json` using atomic writes (write to `.tmp` then rename, keeping one `.bak`).
  - Schema per `docs/ARCH.md` §2.10: `version`, `build_id`, `playtime`, `player` (current host, registered models, Garage slots, upgrades, clearance), `flags`, `rooms` (per-room deltas only: opened doors, broken/cleared tiles, parked hosts with routine and state, defeated unique enemies, taken pickups, persistent latches), `map` (discovered rooms), `logs`, `scrap`.
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
2. **Conveyor Physics Interaction**: Should conveyor belts apply push velocity during System 5 movement via an additive velocity vector `push * speed` (e.g. 32 px/s) while a machine is occupying the tile?
   *(Recommended: Yes, add conveyor push to velocity in System 5 movement so players/enemies can fight or ride the current).*
3. **Collapsing Floor Delay**: Set collapsing floor delay to 30 ticks (0.5 seconds) after step-on before it transforms into a pit tile?
   *(Recommended: Yes, 30 ticks allows Courier to cross safely and gives other bodies a brief reaction window).*
