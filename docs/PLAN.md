# 3. Roadmap

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
- P0.1 User actions: install Godot (4.7.2 stable), export templates, set `GODOT` env var, install Git.
- P0.2 Create project and §2.1 tree. `project.godot` per §2.8, `.gitignore`, `git init`.
- P0.3 Install GUT, enable it, add `.gutconfig.json` and one sample test.
- P0.4 Main scene: 480×270 viewport, integer scaling, debug text, Esc quits, `--smoke` exits after 120 frames with code 0.
- P0.5 `tools/check.ps1` (fast and `-Full`), `tools/load_all.gd`, `tools/validate_data.gd` stub.
- P0.6 Export preset, `tools/build.ps1`, first export and frozen smoke.
- P0.7 Split plan into `docs/`. Create `docs/STATE.md` and `docs/DECISIONS.md`. Create `AGENTS.md`, `.agents/rules/daemon.md`, `tools/sync_rules.ps1`, and P0 skills and workflows.

**P1. Engine core (M)**
- P1.1 Autoloads: `Events`, `Data`, `Game`.
- P1.2 `InputRouter`, InputMap from `bindings_default.json`, keyboard and gamepad, hold detection.
- P1.3 `core/` basics: `Intent`, `Controller` base, `RngStreams`, grid helpers, schema validator.
- P1.4 Room JSON loader and `RoomRuntime`: glyph grid, visual `TileMapLayer`, collision, terrain queries, exits. Validator v0.
- P1.5 Placeholder `Machine` with `PlayerController`: movement, size classes, conduit gate layer, medium rules.
- P1.6 `World` node and tick, world grid, room transitions (0.3 s slide), Debug Bay zone with 4 rooms, HUD strip placeholder.
- P1.7 Debug overlay (F2, F3, F6), `tools/shot.gd`, input recorder (F10).

### Stage B: Systems (Debug Bay sandbox)

- **P2. Machines, bodies, abilities (L)**: `Machine` scene, `BodyState`, ability runner, 10 body definitions, ability kinds.
- **P3. Hijack, Park, Garage (L)**: Hijack state machine, Cursor TTL, targeting, Open rules, routines, Docks, Garage.
- **P4. Combat and AI (L)**: Damage types, knockback, statuses, FSM runner, enemy roster, boss framework.
- **P5. World logic and persistence (L)**: Logic graph, puzzle elements, hazards, gates, save/load system.
- **P6. Content tooling (M)**: Room validator, solver bot DSL and runner, `progression_check.gd`, `map_export.gd`.
- **P7. Art pipeline (L)**: Sprite baker, tile recipes, shaders, complete body and enemy art, visual effects.
- **P8. Audio (M)**: SFX synth, music tracker baker, `AudioBus` stem mixing.
- **P9. UI and UX (M)**: HUD strip, menus, settings, map screen, log reader.

### Stage C: Content (Zones 1-8)

- **P10 Boot Sector (Zone 1)**: Janitor, Bootloader boss.
- **P11 Bus Depot (Zone 2)**: Loader, Bus Pass, Dispatcher boss.
- **P12 Cache (Zone 3)**: Sentry, Link Range +1, Prefetcher boss.
- **P13 Swap (Zone 4)**: Diver, Pager boss.
- **P14 Heap (Zone 5)**: Welder, Garbage Collector boss.
- **P15 Stack (Zone 6)**: Drone, Overflow boss.
- **P16 Registers (Zone 7)**: Crawler, Courier, Scheduler boss.
- **P17 Kernel (Zone 8)**: Medic, Kernel boss, ROLLBACK & COMMIT endings.

### Stage D: Finish

- **P18 Integration and endings (M)**: Full world progression verification, narrative pass, balancing.
- **P19 Polish and QA (M)**: Feel, performance budgets, accessibility, bug fixes.
- **P20 Release (S)**: Windows build, packaging, release tagging.
