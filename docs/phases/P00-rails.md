# P00 — Rails · Brief

**Goal:** Establish project rails, directory layout, Godot 4.7.2 settings, GUT testing, verification scripts, export pipeline, documentation split, and agent skills.

## Tasks
- **P0.1 Environment & Verification:** Verify Godot 4.7.2 console binary and Git; ensure `$env:GODOT` is set; confirm export templates.
- **P0.2 Project Skeleton & Settings:** Initialize git repository, `.gitignore`, directory tree per §2.1, and `project.godot` configured per §2.8 (viewport 480x270, integer scaling, GL Compatibility, physics ticks 60, static typing warning=error, physics layers).
- **P0.3 GUT Test Harness:** Install approved GUT addon, enable in `project.godot`, add `.gutconfig.json`, and author an initial sanity unit test.
- **P0.4 Main Scene & Smoke Harness:** Build minimal `scenes/main.tscn` (480x270 viewport, integer-scaled test visual, Esc quits, `--smoke` exits after 120 frames with code 0).
- **P0.5 Quality Gate Tooling:** Author `tools/load_all.gd`, `tools/validate_data.gd` stub, and `tools/check.ps1` (with `-Full` support).
- **P0.6 Packaging & Build Pipeline:** Configure `export_presets.cfg` (Windows Desktop, embedded PCK), author `tools/build.ps1`, verify headless export and frozen smoke test.
- **P0.7 Docs Split & Agent Rules/Skills:** Split `DAEMON_PLAN.md` into `docs/SPEC.md`, `docs/ARCH.md`, `docs/PLAN.md`, `docs/CONTENT.md`, `docs/TEMPLATES.md`, `docs/ART.md`; create `docs/STATE.md` and `docs/DECISIONS.md` (record Godot 4.7.2); create `AGENTS.md`, `.agents/rules/daemon.md`, `tools/sync_rules.ps1`, P0 skills (`daemon-phase-protocol`, `daemon-verify`, `daemon-godot-guard`), and workflows.

## Files and data touched
- `project.godot`, `export_presets.cfg`, `.gitignore`, `.gutconfig.json`
- `AGENTS.md`, `.agents/rules/daemon.md`, `.agents/skills/*`, `.agents/workflows/*`
- `docs/SPEC.md`, `docs/ARCH.md`, `docs/PLAN.md`, `docs/CONTENT.md`, `docs/TEMPLATES.md`, `docs/ART.md`, `docs/STATE.md`, `docs/DECISIONS.md`
- `scenes/main.tscn`, `src/main.gd`
- `addons/gut/*`, `tests/test_sanity.gd`
- `tools/check.ps1`, `tools/build.ps1`, `tools/sync_rules.ps1`, `tools/load_all.gd`, `tools/validate_data.gd`

## Tests to add
- `tests/test_sanity.gd`: Basic GUT sanity check confirming test runner passes.
- Architecture / load check: `tools/load_all.gd` confirming all `.gd` and `.tscn` files load without errors.
- CLI smoke check: `& $env:GODOT --path . --quit-after 180 -- --smoke`.

## Acceptance
- `& powershell -File tools/check.ps1 -Full` exits 0 with all checks green (import, load_all, validate_data, GUT, graphics smoke, export build, frozen smoke).
- `build/Daemon.exe` runs and displays integer-scaled 480x270 window.
- Agent rules and skills are synchronized and present.

## Evidence I will attach
- Test summary output from GUT and `tools/check.ps1 -Full`.
- Console log and exit code from `build/Daemon.exe --quit-after 180 -- --smoke`.
- Directory listing showing the completed project scaffold and split documentation.

## Assumptions and risks
1. **Godot Binary:** Godot 4.7.2-stable console build is located at `C:\Users\Khuzaim\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`. We assume setting this to the user-level `GODOT` environment variable is acceptable.
2. **Export Templates:** Building `build/Daemon.exe` requires the Godot 4.7.2 export templates installed. If not present in `%APPDATA%\Godot\export_templates\4.7.2.stable`, they must be downloaded via Godot editor or placed there before P0.6.
3. **Headless Execution:** Headless execution cannot render shaders or display windows; all graphics smoke verification will use non-headless runs with `--quit-after`.

## Questions for the user
1. **Godot Environment Variable:** Can I automatically set the user environment variable `GODOT` to `C:\Users\Khuzaim\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`?
   *(Recommended default: Yes)*
2. **Export Templates for 4.7.2:** Have you downloaded the matching export templates in Godot (via Editor -> Manage Export Templates), or would you like to install them before we run the export step in P0.6?
   *(Recommended default: Download/install 4.7.2 templates before P0.6)*
