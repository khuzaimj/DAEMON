# P02 — Machines, Bodies, Abilities · Brief

**Goal:** Implement the 10 machine bodies and 19 ability kinds driven by `Intent`, backed by pure `RefCounted` state and math, with full schema validation, status effects, weight pushing, terrain passives, and Debug Bay testing grounds.

## Tasks
- **P2.1 Machine Architecture & BodyState:**
  - Finalize `scenes/machine.tscn` per §2.3: `Collider` (CollisionShape2D), `Sprite` (AnimatedSprite2D/visual), `Glow` (AnimatedSprite2D/emissive), `HurtBox` (Area2D on layer 6 `hurtbox`), `Abilities` runner node, and `Controller` child node.
  - Create `src/core/body_state.gd` (`RefCounted`): Integrity, Heat (max 100, cooldown 20/s), active statuses (`stun`, `overload`, `burn`), ability cooldown timers in ticks, and lifecycle flags (`crashed`, `overheated` with 180-tick lockout).
  - Create `src/core/ability_math.gd` (`RefCounted`): pure math for melee arcs (90° swipe), conical spreads, projectile vectors, knockback impulses, and tick conversions.
  - Create `src/sim/abilities_runner.gd`: manages primary and secondary ability execution, windup, channeling, cooldowns, and Heat generation.
  - Create `src/sim/controllers/null_controller.gd` (`extends Controller`): yields neutral `Intent` for dormant, crashed, or overheated machines.
- **P2.2 Schemas & Data Validation (Validator v1):**
  - Extend `src/core/schema.gd` with strict schemas for:
    - Bodies (`data/bodies/*.json`): id, name, size, weight, medium, speed, integrity, heat_max, heat_cooldown, primary, secondary, passives, tags, sprite, clearance, garage_cost, unlock_zone.
    - Abilities (`data/abilities/*.json`): id, kind, heat_cost, cooldown, windup, params, sfx.
    - Enemies (`data/enemies/*.json`): id, body, faction, integrity, ai, senses, open_threshold, drops, palette_variant.
    - AI Presets (`data/ai/*.json`): id, initial, params, states.
    - Sizes (`data/sizes.json`): hitbox size mapping (XS: 8, S: 12, M: 14, L: 24, XL: 48).
  - Add sample `data/enemies/rogue_janitor.json` and `data/ai/melee_swarmer.json` from `docs/ARCH.md` §2.6 to test enemy/AI schemas against real JSON.
  - Update `tools/validate_data.gd` to validate all body, ability, enemy, AI, and size JSONs, verifying that referenced ability IDs and size classes exist.
- **P2.3 Core Stats, Cooldowns, Statuses & Lifecycle:**
  - Heat simulation: maximum 100, baseline cooling rate of 20 Heat/sec (decay per tick in `BodyState`), ability heat addition.
  - Integrity and damage reception: hit response, 0.5s invulnerability frames (30 ticks), crash rule (Integrity 0 triggers `crashed` state, disabling host until repaired/recycled).
  - Overheat rule: reaching 100 Heat triggers `overheated` state, locking the machine for 3.0 seconds (180 ticks).
  - Status effects in `BodyState`:
    - `stun`: prevents movement and ability execution for duration.
    - `overload`: applies stun + sets `is_open = true` for hijack vulnerability.
    - `burn`: periodic thermal damage ticks over time.
- **P2.4a Movement Abilities & Weight Pushing:**
  - Implement movement ability kinds: `charge_dash` (Loader Ram: windup, high-speed dash, breaks cracked tiles), `dash` (Courier Dash: 0.18s invulnerable dash, crosses gaps up to 3 tiles), `cling` (Crawler Cling: traverses magnetic walls).
  - Courier `dash` temporarily bypasses Layer 10 (`pit`) during dash ticks to cross <= 3-tile pit gaps per §1.3, and expires into a pit if dash ends over `void`.
  - Implement pushing by weight after `move_and_slide()` (§2.3): machines inspect slide collisions against pushables (layer 4) and other machines (layer 3); heavier bodies push lighter bodies/objects.
- **P2.4b Melee & Suction Abilities:**
  - Implement melee ability kinds: `melee_arc` (Janitor Sweep: 90° arc query, clears grime/debris/bitrot, knocks back), `claw` (Crawler Claw: fast close-range strike).
  - Implement suction ability kind: `suction` (Janitor Suction: pulls scrap, pickups, and light debris within radius toward machine).
  - In `RoomRuntime`, ensure `melee_arc` (`sweep`) clears `,` grime tiles (`clear_by: "sweep"`), and `charge_dash` (`ram`) breaks `X` cracked walls (`break_by: "ram"`) and refreshes room collision.
- **P2.4c Ranged Abilities & Projectile Entity:**
  - Implement ranged ability kinds: `projectile` (Sentry Shoot: aimed bolt on layer 9), `overwatch` (Sentry Overwatch: locks arc, auto-fires on target enter, low Heat), `overload_shot` (Drone Pulse: short electric bolt applying Overload status), `harpoon` (Diver Harpoon: piercing line that tethers objects), `throw_parcel` (Courier Parcel: thrown projectile arcing to target).
  - Implement `Projectile` entity on Layer 9 (`projectile`).
  - Sentry (`speed: 0`) still updates its facing/aim vector from `Intent.move` per §1.3 & §1.13.
- **P2.4d Channelled Abilities:**
  - Implement channelled ability kinds: `flame_cone` (Welder Torch: short thermal cone, cuts weld seams, ignites/burns), `beam_channel` (Welder Arc: continuous beam cutting barriers, high Heat accumulation), `repair_beam` (Medic Repair Beam: continuous beam restoring host Integrity and repairing structures).
  - In `RoomRuntime`, ensure `flame_cone` and `beam_channel` cut `%` weld tiles (`break_by: "torch"`) and refresh room collision.
- **P2.4e Utility Abilities & Body Passives:**
  - Implement utility ability kinds: `ping` (Cursor Ping: reveals hidden conduits/links/secrets in radius for 3s), `lift_carry` (Loader Lift: pick up, carry, and throw crates or bodies up to size M), `tow` (Drone Tow: latch and pull objects up to size S), `bubble_shield` (Diver Bubble: short temporary protective barrier), `patch` (Medic Patch: instant small self-repair).
  - Basic pushable/carryable crate prop (Layer 4 `pushables`, size S/M, weight) so weight-pushing, `lift_carry`, and `tow` are testable.
  - Implement body passive rules (§1.3):
    - Drone hover: passes over pits; drains 8 Heat/s while over pit medium.
    - Coolant medium: Diver swims freely; other bodies take 15 Heat/s and suffer reduced speed.
    - Crawler: immune to floor hazards (spikes, electrified floors).
    - Welder: immune to fire/thermal damage.
    - Janitor: immune to Bitrot corrupt tiles.
- **P2.5 10 Bodies, Debug Bay Body Range, F8 Hotkey & Add-Body Skill:**
  - Author all 10 body definitions in `data/bodies/` (`cursor.json`, `janitor.json`, `loader.json`, `sentry.json`, `drone.json`, `welder.json`, `diver.json`, `crawler.json`, `courier.json`, `medic.json`).
  - Author all 19 ability definitions in `data/abilities/`.
  - Author Debug Bay "Body Range" rooms following `<zone>_<nn>`: `debug_05.json` and `debug_06.json`, reciprocally connected to `debug_04` and each other. Update `rooms_target` in `data/zones/debug.json` to 6.
  - Implement F8 debug hotkey: cycles player machine through all 10 bodies in exact §1.3 table order (Cursor -> Janitor -> Loader -> Sentry -> Drone -> Welder -> Diver -> Crawler -> Courier -> Medic).
  - Update placeholder HUD strip in `World` to display current `body_id`, `Integrity`, and `Heat` alongside `TICK`, `ROOM`, and `SIZE`.
  - Create `.agents/skills/daemon-add-body/SKILL.md` per §5.4.

## Files and data touched
- `scenes/machine.tscn`
- `scenes/world.tscn`
- `src/sim/machine.gd`
- `src/core/body_state.gd`
- `src/core/ability_math.gd`
- `src/core/schema.gd`
- `src/sim/abilities_runner.gd`
- `src/sim/abilities/*.gd`
- `src/sim/entities/projectile.gd`
- `src/sim/entities/crate.gd`
- `src/sim/controllers/null_controller.gd`
- `src/sim/world.gd`
- `src/autoload/input_router.gd`
- `tools/validate_data.gd`
- `data/bodies/*.json` (10 files)
- `data/abilities/*.json` (19 files)
- `data/enemies/rogue_janitor.json`
- `data/ai/melee_swarmer.json`
- `data/zones/debug.json`
- `data/rooms/debug/debug_04.json`
- `data/rooms/debug/debug_05.json`
- `data/rooms/debug/debug_06.json`
- `.agents/skills/daemon-add-body/SKILL.md`

## Tests to add
- `tests/unit/test_body_and_ability_math.gd`: Unit tests for `BodyState` (Integrity, Heat cooling at 20/s, overheat lock at 100 for 180 ticks, crash at Integrity 0, statuses) and `AbilityMath` (arcs, cones, lines, impulses).
- `tests/unit/test_abilities.gd`: Unit tests verifying activation, cooldowns, heat costs, and execution for all 19 ability kinds.
- `tests/data/test_data_validation.gd`: Schema validation tests for all 10 bodies, 19 abilities, enemies, AI presets, and sizes.
- `tests/scenario/test_weight_pushing.gd`: Integration test for weight-based pushing of pushables and other machines.
- `tests/scenario/test_bodies.gd`: Scenario integration test verifying all 10 bodies in simulation (movement speeds, size/medium rules, primary/secondary ability triggers, passive immunities).

## Acceptance
- `tools/check.ps1 -Full` green with all unit and scenario tests passing without orphan nodes.
- `tools/validate_data.gd` validates all 10 bodies, 19 abilities, enemies, AI, sizes, and rooms with zero errors.
- In `debug_05` / `debug_06`, player can cycle all 10 bodies with F8, with HUD showing body id, integrity, and heat.
- Ability effects and projectiles render cleanly using procedural 2D canvas draw calls and palette colors.
- Exported Windows executable (`build/Daemon.exe`) builds cleanly and passes smoke test.

## Evidence I will attach
- Test runner output from `tools/check.ps1 -Full` showing passing tests and assertion count.
- Validator v1 output confirming all schemas and references pass.
- Screenshots from `debug_05` / `debug_06` showcasing distinct bodies and ability visual feedback.

## Assumptions and risks
1. **Visual Placeholders:** Abilities and projectiles use procedural 2D geometry (`_draw()`, `Line2D`, `Polygon2D`) colored with palette colors until Phase 7 art baking.
2. **Combat Interface:** Hitboxes (layer 5), HurtBoxes (layer 6), and Projectiles (layer 9) establish the interface for Phase 4 combat.
3. **Weight Pushing:** Post-`move_and_slide()` slide collision query pushes layer 4 (`pushables`) and layer 3 (`machines`) when pusher weight > target weight.

## Questions for the user
1. **Ability Visual Placeholders:** Procedural 2D canvas draw calls with palette colors before P7 art baking? — *Approved: Yes.*
2. **F8 Body Cycling:** Cycle player machine through all 10 bodies in exact §1.3 table order? — *Approved: Yes.*

# P02 — Machines, Bodies, Abilities · Report
Done: P2.1, P2.2, P2.3, P2.4a, P2.4b, P2.4c, P2.4d, P2.4e, P2.5 · Commits: 8 · Tests: 40 passing (348 asserts) · check.ps1 -Full: green
Evidence:
- `tools/validate_data.gd`: 41 JSON files verified (10 bodies, 19 abilities, enemies, AI, sizes, tiles, zones), 6 rooms verified with Validator v1 (0 errors).
- `tests/`: 18 test scripts, 40 tests, 348 assertions, 0 failures, 0 orphans.
- Performance: 60 FPS, average simulation tick 0.028 ms (budget <= 4.0 ms).
- Exported Windows executable: `build/Daemon.exe` (clean build and frozen smoke test passed).
- Screenshots: `shots/debug_05.png`, `shots/debug_06.png`.
Deviations from the plan: none
Known issues: none
Playtest:
1. Run `& build/Daemon.exe --room debug_05`
2. Press F8 to cycle player body across all 10 bodies (Cursor -> Janitor -> Loader -> Sentry -> Drone -> Welder -> Diver -> Crawler -> Courier -> Medic) and observe HUD updates (BODY, HP, HEAT, SIZE).
3. Test primary (J) and secondary (K) abilities: Janitor Sweep clears grime `,` tiles; Loader Ram breaks cracked walls `X`; Welder Torch cuts weld seams `%`.
4. Test passives: Diver navigates coolant `~` without heat penalty; Drone hovers over pits `o`; Crawler ignores spikes `^`.
Ask: accept, or changes?
