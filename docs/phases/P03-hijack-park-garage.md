# P03 — Hijack, Park, Garage · Brief

**Goal:** Implement the core Metroidvania hook: pure `RefCounted` Hijack FSM, targeting slow-motion, LOS / Firewall ray queries, Spark TTL and Dock reboot, Open/Link Range rules, Parked states with RoutineController, per-room persistence & Garage Slots, Firewall fields & Nodes, and 5 bot-solvable Hijack Lab scenarios in `debug_07` / `debug_08`.

## Division of Labor Notice
Per project workflow, **P3.1 (`src/core/hijack_fsm.gd`) and its accompanying GUT unit tests are authored directly by Argon**. The agent will integrate Argon's code, connect it to the `World` simulation pipeline, verify with `tools/check.ps1`, and proceed with subsequent tasks.

---

## Tasks
- **P3.1 Hijack FSM & Hijack System (Argon authored `src/core/hijack_fsm.gd`):**
  - Integrate Argon's pure `RefCounted` state machine: `HOSTED`, `CURSOR`, `TARGETING`, `TRANSIT`, `NODE_PILOT`.
  - Targeting slow-motion: sets `Engine.time_scale = 0.25` (max 60 ticks / 1.0s) and restores on confirm/cancel.
  - Valid target filtering: candidate machines within Link Range with direct line of sight (ray queries against Layer 1 `solid` and Layer 8 `firewall`).
  - Transit: spark moves straight at 20 tiles/s (320 px/s) invulnerable. If intercepted by Layer 8 `firewall`, hop fails, spark drops to Cursor, and TTL resumes. On arrival, swaps target's controller for `PlayerController` and parks old host.
  - Voluntary ejection: hold Hop for 0.5s (30 ticks) to eject as Cursor at current host position.
  - Forced ejection: host Crashed (Integrity 0) or Overheated (Heat 100, locked 3.0s / 180 ticks).
  - Implement `_step_hijack()` in `World` (System 3 in §2.5 order).
  - Integrate Argon's unit tests in `tests/unit/test_hijack_fsm.gd`.
- **P3.2 Spark TTL, Safe Zones & Reboot Lifecycle:**
  - Cursor Spark TTL timer: base 8.0s (480 ticks at 60 TPS), upgradable to 20s.
  - Safe zones pause TTL drain: inside conduits `:`, Docks, Nodes, during Transit, and when room rule `pause_ttl_until_hijack: true` until first hijack occurs.
  - TTL expiry (0 ticks) or Cursor death triggers Station Reboot at last visited Dock (enemies in room respawn, scrap preserved, hosts outside room preserved).
- **P3.3 Open Rules, Link Range, Registration & Docks:**
  - Open rules: hostile machine becomes Open when Integrity <= 35% or status `overload`. Open state triggers pulsing white/port glow.
  - Dormant machines and parked hosts with clearance <= player clearance are always valid targets.
  - Link Range: base 5 tiles (80 px), +2 tiles per upgrade, max 11 tiles (176 px).
  - Registration: first seizure of a body model permanently registers it in Garage data and emits `log_found` / registration event.
  - Docks: checkpoint save stub, heals host Integrity to max, resets Heat to 0, respawns room enemies, and fabricates registered bodies for scrap cost in Dock bay.
- **P3.4 ParkedState & RoutineController:**
  - Create `src/core/parked_state.gd` (`RefCounted`: routine, pin waypoint).
  - Create `src/sim/controllers/routine_controller.gd`:
    - `HOLD`: inert weight, blocker, maintains position.
    - `GUARD`: stationary, uses primary ability on hostiles in range and line of sight.
    - `PATROL`: walks between park position and pin waypoint (default 5 tiles forward), guarding while walking.
    - `REPEAT`: uses primary continuously in place with locked facing.
  - Medic passive `repeat_heal`: when parked on `REPEAT`, periodically heals nearby damaged parked hosts within 48 px.
  - Routine button cycling (`Q` / `LB`), hold Routine (30 ticks) to drop Pin waypoint.
- **P3.5 Per-Room Persistence & Garage Slots:**
  - Per-room persistence: parked hosts, their routine, and state persist across room transitions.
  - Garage Slots cap outside current room: base 3 slots, +1 per upgrade, max 6 slots.
  - When cap is exceeded, recycle oldest parked host outside current room for scrap refund (unless holding a latched puzzle plate).
- **P3.6 Firewall Fields & Node Hopping:**
  - Layer 8 `firewall` fields: blocks transit hops, drops Cursor where blocked, TTL resumes.
  - `Node` infrastructure ports: Cursor hops in to operate remote machinery (clearance doors, linked switches, firewall toggles).
- **P3.7 Minimal UI & Hijack Lab Rooms (`debug_07`, `debug_08`):**
  - Minimal HUD targeting reticle, candidate highlights, routine icon, and text Garage list.
  - Author Debug Bay "Hijack Lab" rooms `debug_07.json` and `debug_08.json` (updating `data/zones/debug.json` `rooms_target` to 8).
  - Implement and verify the 5 required P3 acceptance scenarios:
    - (a) Tutorial hijack of a dormant machine (`pause_ttl_until_hijack`)
    - (b) Weaken-and-seize a hostile machine (Open at <= 35% Integrity or Overloaded)
    - (c) Loader parked on a weight plate (`HOLD`) with a Sentry guarding (`GUARD`) a door
    - (d) Welder parked on `REPEAT` cutting a weld seam while player operates elsewhere
    - (e) Firewall field blocking a hop until disabled via its maintenance Node

---

## Files and Data Touched
- `src/core/hijack_fsm.gd` (Argon)
- `src/core/parked_state.gd`
- `src/sim/controllers/routine_controller.gd`
- `src/sim/entities/dock.gd`
- `src/sim/entities/firewall.gd`
- `src/sim/entities/node_port.gd`
- `src/sim/world.gd`
- `src/sim/machine.gd`
- `src/autoload/events.gd`
- `src/autoload/game.gd`
- `data/zones/debug.json`
- `data/rooms/debug/debug_07.json`
- `data/rooms/debug/debug_08.json`
- `docs/phases/P03-hijack-park-garage.md`
- `docs/STATE.md`

## Tests to Add
- `tests/unit/test_hijack_fsm.gd` (Argon): FSM state transitions, slow-mo time scale, LOS / Firewall query validation, voluntary eject hold, forced eject on crash/overheat.
- `tests/unit/test_spark_ttl.gd`: Cursor TTL countdown, conduit/Dock/Node safe zone pausing, room rule pause, reboot trigger.
- `tests/unit/test_parked_routines.gd`: RoutineController execution for HOLD, GUARD, PATROL, REPEAT, and Medic repeat healing.
- `tests/scenario/test_hijack_lab.gd`: Full automated scenario test covering all 5 required Hijack Lab scenarios (a through e).

## Acceptance
- `tools/check.ps1 -Full` green with zero test failures, zero errors, and zero orphan nodes.
- Validator v1 verifies all 8 Debug Bay rooms and data files with zero errors.
- All 5 Hijack Lab scenarios pass in simulation:
  1. Tutorial hijack of dormant machine with paused TTL.
  2. Weaken hostile machine to <= 35% HP / Overload, followed by successful seize.
  3. Loader parked on plate (`HOLD`) holds door open while Sentry (`GUARD`) shoots incoming targets.
  4. Welder on `REPEAT` continuously cuts weld seam while Cursor operates across the room.
  5. Hop intercepted and blocked by Firewall until disabled at Node port.
- Exported Windows binary (`build/Daemon.exe`) builds and passes frozen smoke test.

## Evidence I Will Attach
- Test summary from `tools/check.ps1 -Full` showing passing unit and scenario tests.
- Screenshots of Hijack Lab scenarios in `shots/debug_07.png` and `shots/debug_08.png`.
- Output log confirming softlock-free execution of all 5 hijack scenarios.

## Assumptions and Risks
1. **Targeting Slow-Mo**: Uses `Engine.time_scale = 0.25` during targeting; all simulation math operates on integer ticks, ensuring deterministic behavior unaffected by render time scale.
2. **Argon Division of Labor**: Task P3.1 (`src/core/hijack_fsm.gd`) and its test suite will be supplied directly by Argon; the agent will integrate without rewriting FSM core logic.
3. **Firewall Raycast Mask**: Raycast query scans Layer 1 (`solid`) and Layer 8 (`firewall`) to determine line of sight and hop obstruction.

## Questions for the User
1. **Argon Delivery**: Please provide Argon's `src/core/hijack_fsm.gd` and its unit tests when saying "go" to begin Task P3.1. *(Recommended: Yes, provide when ready to start P3.1).*

---

# P03 — Hijack, Park, Garage · Report
Done: P3.1–P3.7 · Commits: 8 (`8ebb742`..`3fdcc3f`) · Tests: 74 passing / 573 asserts · check.ps1 -Full: green
Evidence:
- `tests/scenario/test_hijack_lab_scenarios.gd`: 5/5 passing acceptance scenarios (a through e)
- `shots/debug_07.png`: Hijack Lab fundamentals (tutorial hijack, weaken/seize, plate/door holding)
- `shots/debug_08.png`: Hijack Lab advanced (welder cutting weld seam on REPEAT, node disabling firewall)
- `build/Daemon.exe`: Frozen binary built with embedded PCK, smoke tested clean
Deviations from the plan: None. All 3 user guardrails (ESC handling, timescale cleanup, plate/door linking) satisfied.
Known issues: None
Playtest:
- Run: `& build/Daemon.exe -- --room debug_07`
- Press Space (`hop`) to aim slow-mo (0.25 timescale); select dormant Janitor and press Space to seize.
- Hold Space (`eject`) for 0.5s to voluntary eject back to Cursor.
- Press `Q` to cycle parked routines (HOLD -> GUARD -> PATROL -> REPEAT).
- Warp to `debug_08` (`F6`), pilot maintenance Node to disable Firewall, then hop into vault courier.
Ask: accept, or changes?
