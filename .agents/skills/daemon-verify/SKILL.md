---
name: daemon-verify
description: Verifies DAEMON changes with the quality gate and evidence. Use after finishing any task, when checks fail, or when a gameplay, shader or visual claim needs proof.
---

# DAEMON verify

## Instructions
1. Run `tools/check.ps1`. On failure list each failing item in one line (file:line, message) and fix before anything else.
2. Gameplay change: run the matching GUT scenario test or `.solve` bot and cite the result line.
3. Visual or shader change: run `tools/check.ps1 -Full`, then render with `tools/shot.gd` or `tools/contact_sheet.gd`; cite the PNG paths in shots/.
4. Path or data-loading change: run `tools/build.ps1` and the frozen smoke.
5. Make sure no Godot process is left running after non-headless runs.

## Constraints
- Do not claim something works without an artifact.
- You cannot see the live window; the user judges feel.
