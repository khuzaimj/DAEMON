---
name: daemon-add-enemy
description: Adds a new hostile, neutral, or allied enemy unit to DAEMON. Use whenever creating or modifying an enemy definition, its AI preset, sensory parameters, loot drops, or arena encounters.
---

# DAEMON Add Enemy

## Goal
Add a complete, data-driven enemy definition and AI preset conforming to the DAEMON combat and sensory architecture.

## Checklist
1. **Enemy Definition (`data/enemies/<id>.json`):**
   - Follow strict schema (§2.6):
     - `id`: lower_snake_case enemy identifier (e.g., `rogue_loader`).
     - `body`: referenced playable body ID in `data/bodies/*.json`.
     - `faction`: `"hostile"` (attacks player/parked machines), `"neutral"`, or `"allied"`.
     - `integrity`: base HP points.
     - `ai`: referenced AI preset ID in `data/ai/*.json`.
     - `senses`: dictionary with `vision_radius_px`, `vision_cone_deg`, `hearing_radius_px`, `alert_radius_px`.
     - `open_threshold`: health ratio below which hostile becomes Open for hijacking (e.g. `0.35`).
     - `drops`: dictionary with `scrap` range `[min, max]`.
     - `palette_variant`: visual tint/accent name.

2. **AI FSM Preset (`data/ai/<id>.json`):**
   - Follow AI FSM schema:
     - `id`: matching preset ID.
     - `initial`: starting state (`patrol`, `guard`, `ambush`, `idle`).
     - `params`: ranges, cooldowns, attack thresholds.
     - `states`: dictionary of state behaviors:
       - `do`: action verb (`patrol_waypoints`, `move_to_target`, `use_primary`, `use_secondary`, `wander_last_seen`, `flee`, `guard`, `heal_ally`).
       - `transitions`: condition checks (`see_target`, `target_lost`, `target_in_range`, `low_hp`, `ally_damaged`).

3. **Room Placement:**
   - In `data/rooms/<zone>/<room_id>.json`, add entity:
     `{ "id": "enemy_01", "kind": "enemy", "enemy_id": "<id>", "at": [x, y] }`
   - Ensure the enemy model only appears from its model's unlock zone onward (validator rule), except Janitor in Zone 1.

4. **Immune Entities vs Hijackable Enemies:**
   - Standard enemies extend `Machine` and can be weakened to become Open for hijacking.
   - Immune system units (`glitch_mite`, `antivirus_sentinel`, `quarantine_pod`, `garbage_collector`, `firewall_node`) are non-hijackable (`is_immune_unit = true`) and have no playable body file.

5. **Validation and Verification:**
   - Run `tools/check.ps1` to execute `tools/validate_data.gd`.
   - Verify enemy and AI schemas with zero errors.
   - Add/update scenario tests in `tests/scenario/test_enemy_roster.gd`.
