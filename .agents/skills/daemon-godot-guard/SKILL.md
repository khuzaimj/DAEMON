---
name: daemon-godot-guard
description: Enforces Godot 4 GDScript syntax, static typing and project conventions for DAEMON. Use whenever writing or editing GDScript, scenes, shaders or project settings for the DAEMON game.
---

# DAEMON Godot guard

## Instructions
1. Godot 4 only: `@export`, `@onready`, `@tool`, `await`, `signal.connect(callable)`, `CharacterBody2D` (set `velocity`, call `move_and_slide()` with no arguments), `TileMapLayer`, `Vector2i` for cells.
2. Never write Godot 3 syntax (`export`, `onready`, `yield`, string-based `connect`, `KinematicBody2D`, `TileMap.set_cell(x, y, id)`, `instance()`).
3. Type everything: variables, parameters, returns, typed arrays such as `Array[Intent]`. Untyped declarations are errors in this project.
4. Gameplay lives only in `_physics_process`, called by the World node in system order. Never in `_process`.
5. Rules and math go in RefCounted classes under src/core with no scene-tree or Input access.
6. Prefer building nodes in code and keep `.tscn` files tiny. After editing a `.tscn`, shader or project.godot, run `tools/check.ps1`; for shaders also run `-Full`.
7. Unsure about an API? Read the official docs or run a 5-line experiment with `--script`. Do not guess.

## Constraints
- No new addons. Never hand-edit UIDs. Commit `.uid` and `.import` files.
