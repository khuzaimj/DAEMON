---
name: daemon-add-body
description: Adds a new playable/hijackable body to DAEMON. Use whenever creating or modifying a machine body definition, its abilities, sprites, tests, or Garage registration.
---

# DAEMON Add Body

## Goal
Add a complete, valid body definition conforming to the DAEMON architecture.

## Checklist
1. **JSON Data (`data/bodies/<id>.json`):**
   - Follow strict schema (§2.6): `id`, `name`, `size` (XS/S/M/L/XL), `weight`, `medium`, `speed`, `integrity`, `heat_max`, `heat_cooldown`, `primary`, `secondary`, `passives`, `tags`, `sprite`, `clearance`, `garage_cost`, `unlock_zone`.
   - Ensure `id` is lower_snake_case.
2. **Abilities (`data/abilities/<ability_id>.json`):**
   - Ensure referenced `primary` and `secondary` abilities exist in `data/abilities/`.
   - Ability `kind` must be one of the 19 registered kinds in `src/core/schema.gd`.
3. **Sprite & Sizing:**
   - Size must exist in `data/sizes.json` (XS: 8, S: 12, M: 14, L: 24, XL: 48).
   - Sprite identifier corresponds to art sprite assets.
4. **Validation:**
   - Run `tools/check.ps1` to execute `tools/validate_data.gd`.
   - Verify 0 schema errors and reciprocal exit/reference alignment.
5. **Testing:**
   - Ensure unit/scenario coverage in `tests/scenario/test_bodies.gd`.
   - Verify size, medium constraints, and ability activations pass.
