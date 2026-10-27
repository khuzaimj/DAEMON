# P02 — Machines, Bodies, Abilities · Brief

**Goal:** Implement the 10 machine bodies and 19 ability kinds driven by `Intent`, backed by pure `RefCounted` state and math, with full schema validation, status effects, weight pushing, terrain passives, and Debug Bay testing grounds.

## Tasks
- **P2.1 Machine Architecture & BodyState:**
  - Finalize `scenes/machine.tscn` per §2.3: `Collider` (CollisionShape2D), `Sprite` (AnimatedSprite2D/visual), `Glow` (AnimatedSprite2D/emissive), `HurtBox` (Area2D on layer 6 `hurtbox`), `Abilities` runner node, and `Controller` child node.
  - Create `src/core/body_state.gd` (`RefCounted`): Integrity, Heat (max 100, cooldown 20/s), active statuses (`stun`, `overload`, `burn`), ability cooldown timers in ticks, and lifecycle flags (`crashed`, `overheated`).
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
  - Implement pushing by weight after `move_and_slide()` (§2.3): machines inspect slide collisions against pushables (layer 4) and other machines (layer 3); heavier bodies push lighter bodies/objects.
- **P2.4b Melee & Suction Abilities:**
  - Implement melee ability kinds: `melee_arc` (Janitor Sweep: 90° arc query, clears grime/debris/bitrot, knocks back), `claw` (Crawler Claw: fast close-range strike).
  - Implement suction ability kind: `suction` (Janitor Suction: pulls scrap, pickups, and light debris within radius toward machine).
- **P2.4c Ranged Abilities:**
  - Implement ranged ability kinds: `projectile` (Sentry Shoot: aimed bolt on layer 9), `overwatch` (Sentry Overwatch: locks arc, auto-fires on target enter, low Heat), `overload_shot` (Drone Pulse: short electric bolt applying Overload status), `harpoon` (Diver Harpoon: piercing line that tethers objects), `throw_parcel` (Courier Parcel: thrown projectile arcing to target).
- **P2.4d Channelled Abilities:**
  - Implement channelled ability kinds: `flame_cone` (Welder Torch: short thermal cone, cuts weld seams, ignites/burns), `beam_channel` (Welder Arc: continuous beam cutting barriers, high Heat accumulation), `repair_beam` (Medic Repair Beam: continuous beam restoring host Integrity and repairing structures).
- **P2.4e Utility Abilities & Body Passives:**
  - Implement utility ability kinds: `ping` (Cursor Ping: reveals hidden conduits/links/secrets in radius for 3s), `lift_carry` (Loader Lift: pick up, carry, and throw crates or bodies up to size M), `tow` (Drone Tow: latch and pull objects up to size S), `bubble_shield` (Diver Bubble: short temporary protective barrier), `patch` (Medic Patch: instant small self-repair).
  - Implement body passive rules (§1.3):
    - Drone hover: passes over pits; drains 8 Heat/s while over pit medium.
    - Coolant medium: Diver swims freely; other bodies take 15 Heat/s and suffer reduced speed.
    - Crawler: immune to floor hazards (spikes, electrified floors).
    - Welder: immune to fire/thermal damage.
    - Janitor: immune to Bitrot corrupt tiles.
- **P2.5 10 Bodies, Debug Bay Body Range, F8 Cycle Hotkey & Add-Body Skill:**
  - Author all 10 body definitions in `data/bodies/` (`cursor.json`, `janitor.json`, `loader.json`, `sentry.json`, `drone.json`, `welder.json`, `diver.json`, `crawler.json`, `courier.json`, `medic.json`).
  - Author all 19 ability definitions in `data/abilities/`.
  - Author Debug Bay "Body Range" test room (`data/rooms/debug/debug_range.json`) containing conduits, narrow gaps, cracked walls, weld seams, pits, coolant, spikes, and crates.
  - Implement F8 debug hotkey: cycles the player's active machine across all 10 body models live in the Debug Bay.
  - Create `.agents/skills/daemon-add-body/SKILL.md` per §5.4 detailing body JSON schema, ability parameters, tests, and registration steps.

## Files and data touched
- `scenes/machine.tscn`
- `src/sim/machine.gd`
- `src/core/body_state.gd`
- `src/core/ability_math.gd`
- `src/core/schema.gd`
- `src/sim/abilities_runner.gd`
- `src/sim/abilities/*.gd`
- `src/sim/controllers/null_controller.gd`
- `src/sim/world.gd`
- `src/autoload/input_router.gd`
- `tools/validate_data.gd`
- `data/bodies/*.json` (10 files)
- `data/abilities/*.json` (19 files)
- `data/enemies/*.json`
- `data/ai/*.json`
- `data/rooms/debug/debug_range.json`
- `.agents/skills/daemon-add-body/SKILL.md`

## Tests to add
- `tests/unit/test_body_state.gd`: Heat accumulation, tick-based 20/s cooling, status effects (stun, overload, burn), crash at 0 Integrity, overheat lockout at 100 Heat.
- `tests/unit/test_ability_math.gd`: Pure math tests for melee arc cones, ray intersections, knockback vectors, and range calculations.
- `tests/unit/test_abilities.gd`: Unit tests verifying activation, cooldowns, heat costs, and execution for all 19 ability kinds.
- `tests/data/test_data_validation.gd`: Schema validation tests for all 10 bodies, 19 abilities, enemies, AI presets, and sizes.
- `tests/scenario/test_bodies.gd`: Scenario integration test verifying all 10 bodies in simulation (movement speeds, size/medium rules, primary/secondary ability triggers, passive immunities).
- `tests/scenario/test_weight_pushing.gd`: Integration test for weight-based pushing of pushables and other machines.

## Acceptance
- `tools/check.ps1 -Full` green with all new unit and scenario tests passing without orphan nodes.
- `tools/validate_data.gd` validates all 10 body files and 19 ability files against schemas with zero errors.
- In `debug_range`, player can switch bodies using F8 and verify unique size, speed, abilities, and passives:
  - Cursor (XS) passes through conduits.
  - Loader (L) breaks cracked walls with Ram and pushes heavy objects; blocked by 1-tile gaps.
  - Drone (S) hovers over pits with 8 Heat/s drain.
  - Diver (M) navigates coolant while non-Divers take 15 Heat/s.
  - Crawler (S) walks across spike hazard tiles undamaged.
  - Janitor (M) clears grime/debris with Sweep.
- Exported Windows executable (`build/Daemon.exe`) builds cleanly and passes smoke test.

## Evidence I will attach
- Test runner output from `tools/check.ps1 -Full` showing passing tests and assertion count.
- Validator v1 output confirming all schemas and references pass.
- Screenshots from `debug_range` showcasing distinct bodies and ability visual feedback.

## Assumptions and risks
1. **Visual Placeholders:** Abilities will use procedural visual feedback (colored shapes, lines, arcs, particles) until Phase 7 art baking.
2. **Hitbox/Hurtbox Interaction:** Abilities interact cleanly with HurtBoxes on layer 6 and Projectiles on layer 9, establishing the interface for Phase 4 combat.
3. **Weight Pushing:** Push interactions use slide collision impulses after `move_and_slide()` rather than full rigid-body physics, ensuring determinism.

## Questions for the user
1. **Ability Visual Placeholders:** Would you prefer ability effects (melee arcs, beams, projectiles, cones) rendered using procedural 2D draw calls (`_draw()` / `Line2D` / `Polygon2D`) with palette colors?
   - *Recommended default:* Yes, use clean procedural 2D geometry with active palette colors for readable feedback before P7 art baking.
2. **F8 Body Cycling Order:** Should F8 cycle sequentially through all 10 bodies in unlock/table order (Cursor -> Janitor -> Loader -> Sentry -> Drone -> Welder -> Diver -> Crawler -> Courier -> Medic)?
   - *Recommended default:* Yes, standard sequential cycling with a HUD toast/overlay notification showing the switched body name.
