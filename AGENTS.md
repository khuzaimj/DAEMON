## 0. Quick Start

Copy this section verbatim into `AGENTS.md` and `.agents/rules/daemon.md`.

**Project.** DAEMON: a top-down pixel-art action-puzzle Metroidvania for Windows PC. The player is a daemon (a background process) that hijacks machines; each machine body is an ability. Spec §1 (`docs/SPEC.md`), architecture §2 (`docs/ARCH.md`), roadmap §3 (`docs/PLAN.md`).

**Stack.** Godot 4.7.x (standard, non-.NET build; the latest stable at project start, check godotengine.org/download; record the exact version in `docs/DECISIONS.md` and never upgrade mid-project without asking). GDScript with static typing. GL Compatibility renderer. Content data in JSON. Art as PNG pixel art. Audio as WAV baked from recipes. Tests with GUT (approved addon). Export: Windows Desktop with embedded PCK. Run Godot from PowerShell through the `GODOT` environment variable, which points at the console build (`..._win64_console.exe`) so output is captured.

**Protocol (spec-first, confirm-then-build).**
1. Session start: read `docs/STATE.md` and the active `docs/phases/Pxx-*.md`. Read other docs only when a task needs them.
2. Before a phase starts, post a Phase Brief (template in `docs/TEMPLATES.md`) and STOP. Build only after the user says "go".
3. Inside an approved phase, run tasks one at a time. After each task: `tools/check.ps1` green, commit, update `docs/STATE.md`.
4. At phase end, run `tools/check.ps1 -Full`, post a Phase Report with evidence and STOP for "accept".
5. When something is undecided, ask one question and give a recommended default. Never guess silently.
6. Scope is the full spec. Never cut features or declare an "MVP"; ordering is set by the roadmap. If a task is too big, split it.
7. Be terse: no restating the task, no re-printing files, reports under 15 lines, paths instead of pasted code.

**Hard rules.**
- Static typing everywhere. The project treats untyped declarations as errors.
- Gameplay runs only in `_physics_process` at 60 ticks per second, driven by one `World` node that calls the systems in a fixed order. `_process` is for visuals only. Time is counted in ticks. Randomness comes only from seeded `RngStreams`.
- Rules and math live in `RefCounted` classes (`src/core/`) that never touch the scene tree or `Input`. Node scripts are thin adapters. A test enforces this.
- Everything controllable is driven by `Intent`s from a Controller node (player, AI, routine, script). Only `InputRouter` and `PlayerController` read input.
- Content is JSON data, not code: bodies, abilities, enemies, rooms, zones, palettes, sprites, sfx, music, logs. Code implements kinds; data composes them.
- Tunable numbers live in data files, never as literals in logic.
- Files under about 300 lines, functions under about 50.
- No new addons or dependencies without asking. Approved: GUT.
- Keep `.tscn` files few and small (main, world, machine, UI screens). Build entities and rooms in code from data. After any `.tscn`, shader or `project.godot` edit, run the check.
- From P6 on, every puzzle room ships a `.solve` bot script that passes in `tools/check.ps1`.
- Never copy names, layouts, sprites, or text from existing games.
- Windows first: saves in `user://` (custom user dir "Daemon"), no absolute paths, test the exported exe at every phase end.
- Godot 4 only. Never write Godot 3 syntax (list in §5.6). When unsure about an API, read the docs or run a 5-line experiment; do not guess.
- Headless runs cannot render or compile shaders. Visual and shader checks use non-headless runs (`tools/shot.gd`, `check.ps1 -Full`). You cannot see the live window; the user judges feel.
