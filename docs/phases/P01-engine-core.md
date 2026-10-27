# P01 — Engine Core · Brief

**Goal:** Build the engine core: autoloads, input router with hold detection, RefCounted core types, room loader & runtime with collision, placeholder Machine with 2D movement and size/medium constraints, the 60-tick World simulation loop with sliding transitions, and a 4-room Debug Bay sandbox.

## Tasks
- **P1.1 Autoloads:** Create and register in `project.godot`: `Events` (typed signals bus), `Data` (JSON registry and cache), and `Game` (integer tick counter, simulation state).
- **P1.2 Input Router:** Create `data/bindings_default.json` and `src/autoload/input_router.gd` (loads default actions, samples input once per physics tick, captures press edges, detects hold-to-eject and hold-to-pin).
- **P1.3 Pure Core Classes:** Create pure `RefCounted` classes in `src/core/` (no `Node` or `Input` dependency):
  - `Intent`: Snapshot of actions (move, aim, primary, secondary, hop, eject, routine_cycle, pin, interact).
  - `Controller`: Base controller node class (`decide(machine, tick) -> Intent`).
  - `RngStreams`: Seeded named `RandomNumberGenerator` instances.
  - `Grid`: Coordinate conversions between tile (Vector2i) and pixel (Vector2) coordinates.
  - `Schema`: Base validation helper for data files.
- **P1.4 Room Loader & Runtime:**
  - Create `src/world/room_loader.gd` and `src/world/room_runtime.gd`.
  - Parse 30×15 glyph grids into a visual `TileMapLayer` and generated `StaticBody2D` collision on layers `solid` (layer 1) and `conduit_gate` (layer 2).
  - Implement terrain queries (`terrain_at(pos) -> Dictionary`) for medium (liquid, void), hazard, and push belt.
  - Update `tools/validate_data.gd` with v0 room checks (30×15 dimensions, valid glyphs, matching exits on neighbor borders).
- **P1.5 Placeholder Machine & Movement:**
  - Create `src/sim/machine.gd` (`CharacterBody2D`) and `scenes/machine.tscn`.
  - Sized by size class (`data/sizes.json`: XS 8px, S 12px, M 14px, L 24px).
  - Implement `PlayerController` reading `InputRouter` snapshot.
  - Enforce collision masks: conduit gate blocks all except XS; 1-tile corridors (16px) block L (24px) colliders naturally.
  - Enforce terrain medium rules: non-swimmers in liquid, ground bodies in pits.
- **P1.6 World & Simulation Loop:**
  - Create `src/sim/world.gd` and `scenes/world.tscn`.
  - Drive gameplay strictly in `_physics_process` at 60 ticks/s in §2.5 system order (controllers -> movement -> world).
  - Implement 0.3s sliding room transition freezing simulation.
  - Create Debug Bay zone (`data/zones/debug.json`) and 4 connected rooms (`data/rooms/debug/debug_01.json` to `debug_04.json`).
  - Add placeholder HUD strip (y 240 to 270).
- **P1.7 Debug Tools & Tooling:**
  - F2 collision shapes toggle, F3 perf overlay (FPS, tick ms, entity count), F6 warp to room.
  - CLI argument support: `--room <id>` to boot into a specific room.
  - Author `tools/shot.gd` (non-headless script to render a room screenshot to `shots/`).
  - F10 input recorder stub.

## Files and data touched
- `project.godot` (register autoloads `Events`, `Data`, `Game`, `InputRouter`, set main scene to `res://scenes/world.tscn` or launch routing)
- `data/bindings_default.json`, `data/sizes.json`, `data/tiles.json`
- `data/zones/debug.json`, `data/rooms/debug/debug_01.json` - `debug_04.json`
- `src/autoload/events.gd`, `src/autoload/data.gd`, `src/autoload/game.gd`, `src/autoload/input_router.gd`
- `src/core/intent.gd`, `src/core/rng_streams.gd`, `src/core/grid.gd`, `src/core/schema.gd`
- `src/sim/controllers/controller.gd`, `src/sim/controllers/player_controller.gd`, `src/sim/controllers/script_controller.gd`
- `src/sim/machine.gd`, `src/sim/world.gd`
- `src/world/room_loader.gd`, `src/world/room_runtime.gd`, `src/world/world_grid.gd`
- `scenes/world.tscn`, `scenes/machine.tscn`
- `tools/shot.gd`, `tools/validate_data.gd`
- `tests/unit/test_core_math.gd`, `tests/unit/test_room_loader.gd`, `tests/scenario/test_movement_and_gaps.gd`, `tests/scenario/test_room_traversal.gd`, `tests/unit/test_arch_guard.gd`

## Tests to add
- `tests/unit/test_core_math.gd`: `Intent` values, `RngStreams` deterministic seeding, `Grid` tile/pixel conversions.
- `tests/unit/test_room_loader.gd`: Parses 30×15 grid, queries terrain by pixel coordinate, exit coordinate mapping.
- `tests/unit/test_arch_guard.gd`: Enforces that no script in `src/core/` extends `Node` or references `Input`.
- `tests/scenario/test_movement_and_gaps.gd`: L-sized machine blocked by 1-tile gap; non-XS blocked by conduit gate; XS traverses conduit.
- `tests/scenario/test_room_traversal.gd`: `ScriptController` walks placeholder Cursor across all 4 Debug Bay rooms with room transition slides.

## Acceptance
- `tools/check.ps1` and `tools/check.ps1 -Full` green with zero errors and all new tests passing.
- Cursor traverses 4 Debug Bay rooms at constant 60 FPS tick rate.
- 1-tile gap blocks 24px bodies; only XS enters conduit tiles.
- `--room debug_02` directly loads room 2.
- `tools/shot.gd` successfully generates screenshots of the Debug Bay rooms in `shots/`.
- Exported binary `build/Daemon.exe` passes smoke test.

## Evidence I will attach
- GUT run summary with 5 new test scripts passing.
- Rendered screenshot in `shots/debug_bay_01.png` via `tools/shot.gd`.
- Log output from scenario test proving 4-room traversal and 60 FPS tick adherence.

## Assumptions and risks
1. **Simulation Ordering:** Entities do not tick independently; only `World._physics_process` calls controller and movement systems in fixed order.
2. **Room Transition Freezing:** When transitioning between rooms, simulation ticks are paused for 0.3s during the visual slide.
3. **Determinism:** Tests assert discrete outcomes (room id, cell coordinates, flags, collision states) rather than floating-point positions.

## Questions for the user
1. **Launch Routing:** Should launching the game without arguments start directly in Debug Bay room 1 (`debug_01`), with `--room <id>` available to warp?
   *(Recommended default: Yes, default to `debug_01`, override with `--room <id>`)*
