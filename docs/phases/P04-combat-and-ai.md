# P04 — Combat and AI · Brief

**Goal:** Implement real-time combat, damage types, status effects, sensory perception, grid pathfinding, data-driven AI FSMs, full enemy roster, immune hazards, boss framework, and Combat Arena rooms.

---

## Tasks
- **P4.1 Combat System, Damage Types, Statuses & Pickups:**
  - Implement System 7 (`_step_combat()`) and System 1 (`_step_senses()`) in `World._physics_process` tick loop (§2.5).
  - Damage types (`kinetic`, `thermal`, `electric`), per-body resistances/vulnerabilities in `data/bodies/*.json`, Sentry `armored_front` passive (reduces frontal damage), knockback impulses, 0.5s invulnerability (30 ticks), hit-stop freeze hooks (2–4 frames), and small screen shake hooks (2–3 px).
  - Electric damage adding Heat (§1.9), status effects (`overload`: 2.0s / 120 ticks stun + forced Open; `burn`: damage over time; `stagger`: brief action interrupt).
  - Scrap drops on enemy kill (`drops.scrap` range in enemy data via `RngStreams`) and `ScrapPickup` entities on Layer 7 (`trigger`) that add to `Game.scrap` and emit `Events.pickup_taken`.
- **P4.2 Senses, Pathfinding & AI FSM Runner:**
  - Sensory perception in System 1: vision cones with field-of-view angles, hearing radii, and line-of-sight raycasts against Layer 1 (`solid`).
  - Room `AStarGrid2D` pathfinding per size class (`xs`, `s`, `m`, `l`) and medium (ground, liquid, void) cached on room load from glyph grid (§2.6).
  - `src/sim/controllers/ai_controller.gd` (`extends Controller`) executing data-driven FSM presets from `data/ai/*.json` with state `do` actions (`patrol_waypoints`, `move_to_target`, `use_primary`, `use_secondary`, `wander_last_seen`, `flee`, `guard`, `heal_ally`) and group alert broadcasts.
- **P4.3 Full Enemy Roster as Data:**
  - Author all hijackable enemy JSON definitions in `data/enemies/` and corresponding AI presets in `data/ai/`: `rogue_janitor` (swarmer and heavy variants), `rogue_loader` (charger), `rogue_sentry` (turret), `diver_bot` (coolant ambusher), `welder_bot` (thermal cone), `drone_patrol` (flying skirmisher), `crawler_bot` (hazard dasher), `courier_bot` (high-speed dasher), and `medic_bot` (heals enemy allies).
  - Extend `World._spawn_room_entities()` to instantiate enemies by enemy ID from `data/enemies/<id>.json` with `AIController`, distinct palette variants, and Open indicators.
- **P4.4 Immune System Units & Hazards (§1.5):**
  - Implement non-hijackable immune system entities (`is_immune_unit = true`):
    - `glitch_mite`: weak erratic swarmer, adds Heat on contact.
    - `antivirus_sentinel`: actively hunts exposed Cursor, fires seeking bolts.
    - `firewall_node`: projects Layer 8 barrier lines that block hops, disabled via linked maintenance Node.
    - `quarantine_pod`: traps nearby parked hosts when alert sounds.
    - `garbage_collector`: indestructible roaming unit that deletes parked hosts upon contact.
  - Spreading `bitrot` hazard: corrupt tiles spreading slowly on logic ticks, damaging non-Janitor hosts, cleared by Janitor `sweep`.
- **P4.5 Boss Framework, Test Boss, Combat Arena Rooms & Skill:**
  - Boss architecture (`src/sim/boss_controller.gd` and subsystem entities): multi-phase state machine, un-hijackable core boss body (`is_boss_body = true`), hijackable subsystems (actuators, lenses, valves), and arena scripting from `data/bosses/*.json` (timers, spawns, phase triggers).
  - Author prototype boss in data: `bootloader` (`data/bosses/bootloader.json` / `test_press.json`) with 3 hijackable hydraulic actuators.
  - Author Debug Bay Combat Arena rooms `debug_09.json` (enemy gauntlet) and `debug_10.json` (boss arena), updating `data/zones/debug.json` `rooms_target` to 10.
  - Create `.agents/skills/daemon-add-enemy/SKILL.md` per §5.4.
  - Benchmark performance profile per §2.15 (<= 4.0 ms per simulation tick with active pathfinding and 20+ combat entities).

---

## Files and Data Touched
- `src/sim/world.gd`
- `src/sim/machine.gd`
- `src/sim/controllers/ai_controller.gd`
- `src/sim/controllers/boss_controller.gd`
- `src/sim/entities/scrap_pickup.gd`
- `src/sim/entities/immune_unit.gd`
- `src/sim/entities/subsystem.gd`
- `src/core/schema.gd`
- `src/core/combat_math.gd`
- `src/autoload/events.gd`
- `src/autoload/game.gd`
- `data/bodies/*.json`
- `data/enemies/*.json`
- `data/ai/*.json`
- `data/bosses/bootloader.json`
- `data/zones/debug.json`
- `data/rooms/debug/debug_09.json`
- `data/rooms/debug/debug_10.json`
- `.agents/skills/daemon-add-enemy/SKILL.md`
- `docs/STATE.md`
- `docs/phases/P04-combat-and-ai.md`

---

## Tests to Add
- `tests/unit/test_combat_math.gd`: Damage type calculations, resistance/vulnerability multipliers, Sentry `armored_front` angle mitigation, knockback vectors, and invulnerability tick expiration.
- `tests/unit/test_statuses_and_pickups.gd`: Overload stun + Open flag, Burn damage over time, Stagger interrupt, and ScrapPickup collection.
- `tests/unit/test_senses_and_pathfinding.gd`: Vision cone checks, hearing distance thresholds, raycast obstruction, and `AStarGrid2D` multi-size path generation.
- `tests/unit/test_ai_fsm.gd`: FSM state transitions (patrol -> chase -> attack -> search), state `do` execution, and group alert propagation.
- `tests/scenario/test_enemy_roster.gd`: Spawning each of the 9 enemy types from data, behavior verification, and Open/hijackability rules.
- `tests/scenario/test_immune_units_and_bitrot.gd`: Glitch Mite contact heat, Antivirus Cursor targeting, Quarantine Pod trapping, Garbage Collector deletion, and Bitrot tile spreading/clearing.
- `tests/scenario/test_boss_fight.gd`: Multi-phase fight progression, subsystem hijacking, phase transitions, and victory conditions.
- `tests/perf/test_combat_perf.gd`: Tick duration assertion ensuring <= 4.0 ms tick simulation budget per §2.15 under heavy combat load.

---

## Acceptance
- `tools/check.ps1 -Full` green with zero test failures, zero errors, and zero orphan nodes.
- Validator v1 validates all 10 Debug Bay rooms, bodies, enemies, AI presets, and boss data with zero errors.
- All enemy types spawn cleanly from data, execute their assigned AI behaviors, and drop scrap on destruction.
- Immune units and Bitrot hazards interact according to spec: non-hijackable, hazard propagation, and host-specific counters.
- Bootloader boss prototype completes successfully across phases via subsystem hijack mechanics in automated scenario test.
- Simulation profiling confirms tick execution remains strictly <= 4.0 ms budget in `debug_09` with active enemies.
- Windows binary (`build/Daemon.exe`) builds with embedded PCK and passes smoke test.

---

## Evidence I Will Attach
- Test summary from `tools/check.ps1 -Full` showing passing unit, scenario, and performance tests.
- Screenshots `shots/debug_09.png` (Enemy Combat Arena) and `shots/debug_10.png` (Boss Arena).
- Microsecond timing logs confirming tick simulation is <= 4.0 ms under combat load.

---

## Assumptions and Risks
1. **AStarGrid2D Allocation & Memory**: Pathfinding grids will be generated per size class during room initialization rather than every frame or on-demand tick to prevent allocations inside hot loops.
2. **Hit-Stop Determinism**: Visual hit-stop (2–4 frames freeze) will be handled as an engine pause or frame delay without desynchronizing fixed-tick simulation time or corrupting input buffers.
3. **Subsystem Hijack Separation**: Boss subsystems will extend or adapt `Machine` or interactable targets so `HijackFSM` can target them without permitting hijack of the core boss root node.

---

## Questions for the User
1. **Test Boss Archetype**: Shall we implement the prototype boss directly as the Zone 1 boss `bootloader` (giant industrial press with 3 hijackable actuators per §1.6) so assets and logic carry directly into P10?
   *(Recommended: Yes, author `bootloader.json` with 3 actuator subsystems).*
2. **Hit-Stop & Screen Shake Defaults**: Default hit-stop duration to 3 frames (50 ms) and screen shake to 2 px with toggle support in settings for accessibility (§1.9, §1.13, §2.8)?
   *(Recommended: Yes, default to 3 frames and 2 px).*
