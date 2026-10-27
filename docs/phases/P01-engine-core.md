# P01 — Engine Core · Brief

**Goal:** Build the engine core: autoloads, input router with hold detection, pure RefCounted core types, room loader & runtime with collision, placeholder Machine with 2D movement and size/medium constraints, the 60-tick World simulation loop with sliding transitions, and a 4-room Debug Bay sandbox.

## Tasks
- **P1.1 Autoloads:** Create and register in `project.godot`:
  - `src/autoload/events.gd`: Typed signals bus (`room_transition_started`, `room_transition_finished`, `tick_advanced`, etc.).
  - `src/autoload/data.gd`: JSON registry and cache (loads and caches all files under `data/`).
  - `src/autoload/game.gd`: Global tick counter (`Game.tick`), state flags, and game lifecycle control.
- **P1.2 Input Router:**
  - Create `data/bindings_default.json` with keyboard and gamepad defaults per §1.13.
  - Create `src/autoload/input_router.gd` registered as autoload in `project.godot`.
  - Samples inputs once per physics tick.
  - Exposes snapshot with press edges, hold detection (0.5s hold-to-eject, hold-to-pin), and 8-way aim vector.
- **P1.3 Pure Core Classes:**
  - Pure `RefCounted` classes in `src/core/` (strictly no `Node` or `Input` access, verified by `test_arch_guard.gd`):
    - `src/core/intent.gd`: `class_name Intent extends RefCounted` with `move`, `aim`, `primary`, `secondary`, `hop`, `eject`, `routine_cycle`, `pin`, `interact`.
    - `src/core/rng_streams.gd`: Deterministic named `RandomNumberGenerator` instances seeded from world seed.
    - `src/core/grid.gd`: Coordinate conversions between tile cells (`Vector2i`) and pixels (`Vector2`).
    - `src/core/schema.gd`: Base JSON validation helper enforcing snake_case keys and rejecting unknown properties.
  - `src/sim/controllers/controller.gd`: `class_name Controller extends Node` base controller scene-tree node with `decide(machine, tick) -> Intent`.
- **P1.4 Room Loader & Runtime:**
  - Author `data/tiles.json` with tile properties per §2.6 (`solid`, `clear_by`, `medium`, `hazard`, `fits`, `break_by`, `push`).
  - Create `src/world/room_loader.gd`: Loads room JSON and validates grid syntax.
  - Create `src/world/room_runtime.gd`:
    - Generates visual `TileMapLayer` with placeholder tiles.
    - Generates merged `StaticBody2D` collision for `solid` tiles (layer 1) and `conduit_gate` tiles (layer 2).
    - Exposes `terrain_at(pixel_pos: Vector2) -> Dictionary` querying medium (`liquid`, `void`), hazards (`spikes`), conveyors (`push`), and debris.
    - Resolves exit boundaries and neighbor room transitions.
  - Update `tools/validate_data.gd` with v0 checks (30×15 grid dimensions, valid glyphs, neighbor exit alignment).
- **P1.5 Placeholder Machine & Movement:**
  - Author `data/sizes.json` with hitbox dimensions (XS: 8, S: 12, M: 14, L: 24, XL: 48).
  - Create `src/sim/machine.gd` (`CharacterBody2D`) and `scenes/machine.tscn`.
  - Create `src/sim/controllers/player_controller.gd` (`extends Controller`), translating `InputRouter` snapshot into `Intent`.
  - Create `src/sim/controllers/script_controller.gd` (`extends Controller`), enabling automated bot commands (`move`, `wait`) for testing.
  - Enforce collision layers/masks:
    - Layer 3 (`machines`) colliding with layer 1 (`solid`), layer 3 (`machines`), and layer 2 (`conduit_gate`) unless XS.
    - 1-tile gaps (16px) admit colliders up to 14px (S, M) and block L (24px).
  - Enforce terrain medium checks in physics step: liquid/coolant drains/slows non-swimmers, pits block ground units.
- **P1.6 World & Simulation Loop:**
  - Create `src/sim/world.gd` and `scenes/world.tscn`.
  - Owns the 60-tick loop in `_physics_process` (controllers -> movement -> world systems in fixed order).
  - Implements 0.3s sliding room transition freezing simulation ticks during slide.
  - World grid loader managing active and standby rooms.
  - Create Debug Bay zone (`data/zones/debug.json`) and 4 connected rooms (`data/rooms/debug/debug_01.json` to `debug_04.json`).
  - Add placeholder HUD strip (y 240 to 270) displaying tick count, current room, and body size.
  - Update launch routing: default to `debug_01` when run without `--room`, accept `--room <id>` override, ensure `--smoke` exits 0 after 120-180 frames.
- **P1.7 Debug Tools, Tooling & Profiling:**
  - F2: Toggle debug collision shapes.
  - F3: Performance overlay (FPS, tick simulation ms, active machine count).
  - F6: In-game room warp dialog / console prompt.
  - F10: Toggle input recording (records tick-stamped `Intent` stream to `user://input_record.json`).
  - Author `tools/shot.gd` (non-headless tool rendering room view to `shots/`).
  - Profile simulation per §2.15 to confirm <= 4 ms per tick at 60 FPS.

## Files and data touched
- `project.godot`, `data/bindings_default.json`, `data/tiles.json`, `data/sizes.json`
- `data/zones/debug.json`, `data/rooms/debug/debug_01.json` - `debug_04.json`
- `src/autoload/events.gd`, `src/autoload/data.gd`, `src/autoload/game.gd`, `src/autoload/input_router.gd`
- `src/core/intent.gd`, `src/core/rng_streams.gd`, `src/core/grid.gd`, `src/core/schema.gd`
- `src/sim/controllers/controller.gd`, `src/sim/controllers/player_controller.gd`, `src/sim/controllers/script_controller.gd`
- `src/sim/machine.gd`, `src/sim/world.gd`
- `src/world/room_loader.gd`, `src/world/room_runtime.gd`, `src/world/world_grid.gd`
- `scenes/main.tscn`, `scenes/world.tscn`, `scenes/machine.tscn`
- `tools/shot.gd`, `tools/validate_data.gd`
- `tests/unit/test_core_math.gd`, `tests/unit/test_room_loader.gd`, `tests/unit/test_arch_guard.gd`
- `tests/scenario/test_movement_and_gaps.gd`, `tests/scenario/test_room_traversal.gd`

## Tests to add
- `tests/unit/test_core_math.gd`: `Intent` values, `RngStreams` deterministic sequence, `Grid` coordinate conversions.
- `tests/unit/test_room_loader.gd`: Parses 30×15 grid, queries terrain by pixel coordinate, exit coordinate mapping.
- `tests/unit/test_arch_guard.gd`: Architecture test proving no class in `src/core/` extends `Node` or touches `Input`.
- `tests/scenario/test_movement_and_gaps.gd`: L-sized machine blocked by 1-tile gap; non-XS blocked by conduit; XS traverses conduit.
- `tests/scenario/test_room_traversal.gd`: `ScriptController` walks placeholder Cursor across all 4 Debug Bay rooms with 0.3s transitions.

## Acceptance
- `tools/check.ps1` and `tools/check.ps1 -Full` green with zero errors and all new tests passing.
- Cursor traverses 4 Debug Bay rooms at constant 60 FPS tick rate.
- 1-tile gap blocks 24px bodies; only XS enters conduit tiles.
- Default launch runs `debug_01`; `--room debug_02` directly loads room 2; `--smoke` exits cleanly with code 0.
- `tools/shot.gd` successfully generates screenshots of the Debug Bay rooms in `shots/`.
- F2 (collision), F3 (perf overlay), F6 (warp), and F10 (input recorder toggle) functional.
- §2.15 Performance budget met: simulation tick <= 4 ms, 60 FPS on integrated graphics.
- Exported binary `build/Daemon.exe` passes frozen smoke test.

## Evidence I will attach
- GUT run summary with 5 new test scripts passing.
- Rendered screenshot in `shots/debug_01.png` via `tools/shot.gd`.
- Performance profiling log showing tick simulation time <= 4 ms and 60 FPS.
- Scenario test log confirming 4-room traversal.

## Assumptions and risks
1. **Simulation Ordering:** Gameplay systems execute strictly inside `World._physics_process` in §2.5 order. Machines never run gameplay logic inside their own independent process loops.
2. **Room Transition Freezing:** When transitioning between rooms, simulation ticks are paused for 0.3s during the visual slide.
3. **Determinism:** Tests assert discrete outcomes (room id, cell coordinates, flags, collision states) rather than floating-point positions.

## Questions for the user
1. **Launch Routing:** Default to `debug_01` when run without `--room`, support `--room <id>` override, support `--smoke`. *(Approved: Yes)*

---

# P01 — Engine Core · Report
Done: P1.1 Autoloads; P1.2 Input Router; P1.3 Pure Core Classes; P1.4 Room Loader & Runtime; P1.5 Machine, Controllers & Movement; P1.6 World Node & Room Transitions; P1.7 Debug Tools & Profiling · Commits: 6 · Tests: 15 passing (91 asserts, 0 orphans) · check.ps1 -Full: green
Evidence:
- Tests: `tests/unit/test_perf_budget.gd`, `tests/scenario/test_room_traversal.gd`, `tests/scenario/test_movement_and_gaps.gd`
- Profiling: avg=0.019 ms / max=0.059 ms per tick (budget: <= 4.0 ms)
- Visual renders: `shots/debug_01.png`, `shots/debug_02.png`, `shots/debug_03.png`, `shots/debug_04.png`
- Binary export: `build/Daemon.exe` verified with frozen smoke test
Deviations from the plan: None
Known issues: None
Playtest:
- Run: `& build/Daemon.exe` (or `& $godot --path . --room debug_01`)
- Controls: Arrow keys / WASD to move Cursor (XS body)
- Walk East in `debug_01` to trigger 0.3s sliding room transition to `debug_02`
- Press F2 (collision overlay), F3 (FPS/sim ms overlay), F6 (warp prompt), F10 (input recorder toggle to `user://input_record.json`), ESC to quit
Ask: accept, or changes?

