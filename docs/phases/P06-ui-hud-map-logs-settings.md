# P06 — UI, HUD, map, logs, and settings · Brief

**Status:** APPROVED 2026-10-28 with Argon/Claude amendments and guardrails G1–G8.

**Goal:** Implement the structured pixel-art HUD, map overlay with Bus fast travel, terminal log reader, polished Dock/Garage modal, Title & Save Slot select screens, Pause menu, Settings with accessibility and key rebinding, and context-sensitive input prompts.

---

## Approved Answers to Questions
1. **HUD Strip Position:** Keep the HUD at the bottom (y=240..270) per SPEC §1.11 and ARCH §2.8. Room playfield remains (0, 0) to (480, 240).
2. **Infinite TTL Display:** Show `∞` and halt TTL timer decay in HijackFSM. If the baked 5x7 font lacks an `∞` glyph, render it as a custom pixel sprite.
3. **Map Grid Cell Display:** Hide unvisited rooms completely; render only discovered room cells and their corresponding exits.

---

## Approval Guardrails (Binding for P06)
- **G1 HUD Layout Budget & Missing Items:** Include Link Range pips and the latest log line (reusing the toast banner's latest message) per SPEC §1.13. Budget 480x30 tightly. Integrity displays pips up to 10, then switches to a compact bar format (`HP: [====] 18/26`) to accommodate max HP scaling up to 26 (Loader base 14 + 12 chips).
- **G2 Input Single Source of Truth:** Only `InputRouter` and `PlayerController` read raw input. Map (`Tab`), Pause (`Esc`), and the F3 toggle must route through `InputRouter` actions, snapshots, or signals—never direct `Input` queries inside UI scripts. Menu button navigation uses Godot's built-in focus system.
- **G3 Pause Semantics:** Pause must freeze the `World` tick and `Game.tick` rather than modifying `Engine.time_scale` (which targeting slow-mo already uses). UI pause nodes must have `process_mode = Node.PROCESS_MODE_ALWAYS`.
- **G4 Data-Driven Accessibility Multipliers:** Keep multiplier values in data (`data/settings_defaults.json`), not hardcoded literals in logic. Because `HijackFSM` lives in `src/core/`, pass `ttl_multiplier` in as a parameter instead of reading an autoload.
- **G5 Settings Scope & Audio Buses:** Audio buses must include the UI bus (`Master`, `SFX`, `Music`, `UI` per ARCH §2.9). Note that aim assist, Heat rate, flash reduction, and CRT shader toggles are deferred to P7 (Art/CRT) and P19 (Polish/Accessibility).
- **G6 Zero Orphan Nodes:** UI tests must strictly free all instantiated nodes (`queue_free()`) to ensure `tools/check.ps1` passes zero-orphan checks.
- **G7 Phase Renumbering:** UI is P06 in this repo; Content Tooling is deferred to P09. Recorded in `docs/DECISIONS.md` under D7.
- **G8 Division of Labor (Argon / Claude Authored Tasks):**
  - P6.1 (HUD), P6.4 (Settings & Accessibility), P6.5 (Input Prompts & UI Tests) implemented in the workspace.
  - P6.2 (Map Overlay, Log Reader, Dock Modal) and P6.3 (Title Screen, Slot Select, Pause Menu, Toasts) are authored by Claude/Argon.

---

## Tasks

- **P6.1 Pixel-Art HUD (`src/ui/hud.gd`, 480 x 30 px bottom bar):**
  - Replace the placeholder debug `HUDLabel` with a structured pixel-art HUD component in the 480 x 30 px bar (y=240..270).
  - Host model badge (e.g. `PATCH`, `LOADER`, `CURSOR`) + Integrity indicator (pips up to 10, bar beyond 10).
  - Heat bar (`current_heat / max_heat`) + visual overheat lockout flash warning when locked out.
  - Spark TTL bar & countdown indicator (active in `CURSOR` state; displays `∞` when infinite TTL assist is enabled; paused indicator inside safe zones).
  - Parked Routine selector badge (`HOLD`, `GUARD`, `PATROL`, `REPEAT`) + active Pin indicator.
  - Garage Slots pips (occupied outside parked slots vs `Game.garage_slots_cap`, distinguishing latched hosts).
  - Clearance badge (`L0`–`L4`), Scrap counter, Shard counter (`0/3`), Link Range pips, latest log line, and Primary/Secondary ability cooldown / charge indicators.
  - Retain toggleable debug/perf readout (`F3` via `InputRouter`) showing tick, FPS, entity counts, room id, and memory.

- **P6.2 Map Overlay, Log Reader & Enhanced Garage UI (`src/ui/` - Argon/Claude Authored Task):**
  - **Map Overlay (`src/ui/map_overlay.gd`, `Tab` / `map` action):** Renders discovered rooms (`Game.discovered_rooms`) by zone grid coordinates, highlights the player's current room, displays visited Docks and parked host icons, and enables Bus fast travel (`Game.fast_travel_to_dock`) when `Game.has_bus_pass` is true. Unvisited rooms are hidden completely.
  - **Log Reader Panel (`src/ui/log_reader.gd`):** Lists all logs collected in `Game.logs`, formatted with log title, source, timestamp/index, and lore body text (supporting data from `data/logs/*.json` or room definitions).
  - **Garage & Dock Modal (`src/ui/garage_modal.gd`):** Polished modal for Dock resting, fabricating registered models with scrap costs and stat comparisons, viewing parked host routines, and remotely recycling outside parked hosts for scrap.

- **P6.3 Title Screen, Save Slot Select, Pause Menu & Status Toasts (`src/ui/` - Argon/Claude Authored Task):**
  - **Title Screen & Slot Select (`src/ui/title_screen.gd`, `src/ui/slot_select.gd`):** `Continue`, `New Game`, `Save Slots 1–3` (displaying playtime, body, clearance, scrap, and last saved room), `Settings`, and `Quit`.
  - **CLI Argument Preservation in `src/main.gd`:** Strictly preserve `--room <id>` and `--smoke` bypass so test scripts and automated runs launch directly into `World` without requiring UI navigation.
  - **Pause Menu (`src/ui/pause_menu.gd`):** Opens on `ESC` / `back` through `InputRouter` when no targeting or modal is open. Freezes `World` tick and `Game.tick`. Provides `Resume`, `Map & Logs`, `Settings`, `Save & Quit to Title`, and `Quit to Desktop`.
  - **Status Toast Banners (`src/ui/toast_banner.gd`):** Non-blocking notification banner for events (`Events.model_registered`, `Events.pickup_taken`, `Events.log_found`, `Events.reboot_triggered`).

- **P6.4 Settings Menu, Rebinding & Accessibility (`src/ui/settings_menu.gd`, `user://settings.json`):**
  - Persist settings via `SaveSystem.save_settings()` / `load_settings()`. Data-driven defaults in `data/settings_defaults.json`.
  - **Audio Settings:** Master, Music, SFX, and UI volume sliders connected to `AudioServer` buses.
  - **Video & Game Feel:** Window mode (Windowed 1x/2x/3x, Fullscreen), `screen_shake_enabled` (respected by `World.trigger_screen_shake()`), and `hit_stop_enabled` (respected by `World.trigger_hit_stop()`).
  - **Accessibility (§1.13):** Spark TTL multiplier (`1.0x`, `1.5x`, `2.0x`, `infinite`), incoming damage multiplier (`1.0x`, `0.5x`), and full keyboard/gamepad action rebinding via `InputRouter`. Multipliers passed cleanly into core logic.

- **P6.5 Input Prompt Glyphs & UI Test Suite:**
  - **Input Prompt Component (`src/ui/input_prompts.gd`):** Dynamic input prompt helper displaying Keyboard labels (e.g. `[E]`, `[J]`, `[K]`) or Gamepad button icons (e.g. `[A]`, `[X]`, `[Y]`) based on the most recently used input device detected by `InputRouter`.
  - Comprehensive unit and scenario test suite verifying HUD state reactivity, Map & Log population, Bus fast-travel triggering, Settings serialization, accessibility multipliers, and Menu navigation flows. Zero orphan nodes enforced.

---

## Files and Data Touched
- `src/ui/hud.gd`
- `src/ui/map_overlay.gd`
- `src/ui/log_reader.gd`
- `src/ui/garage_modal.gd`
- `src/ui/title_screen.gd`
- `src/ui/slot_select.gd`
- `src/ui/pause_menu.gd`
- `src/ui/settings_menu.gd`
- `src/ui/toast_banner.gd`
- `src/ui/input_prompts.gd`
- `src/autoload/input_router.gd`
- `src/autoload/save_system.gd`
- `src/core/save_data.gd`
- `src/sim/world.gd`
- `src/main.gd`
- `scenes/world.tscn`
- `scenes/main.tscn`
- `data/bindings_default.json`
- `data/settings_defaults.json`
- `docs/DECISIONS.md`
- `docs/STATE.md`
- `docs/phases/P06-ui-hud-map-logs-settings.md`

---

## Tests to Add
- `tests/unit/test_hud.gd`: Unit tests for HUD state updates (Integrity pips/bar, Heat bar & lockout warning, Spark TTL decay & safe-zone pause / infinity symbol, Garage occupancy pips, Routine badges, Clearance level, Shard count, Link Range pips, latest log line, cooldown progress).
- `tests/unit/test_map_and_logs.gd`: Discovered rooms layout, current room indicator, visited Dock listing, Bus fast travel execution with Bus Pass, and Log Reader formatting and pagination.
- `tests/unit/test_settings.gd`: Audio volume slider math for Master/Music/SFX/UI, settings serialization/deserialization with `user://settings.json`, accessibility multiplier application (`ttl_multiplier`, `incoming_damage_multiplier`), feel toggles (`screen_shake_enabled`, `hit_stop_enabled`), and `InputRouter` key rebinding.
- `tests/unit/test_input_prompts.gd`: Dynamic device switching (keyboard vs joypad), prompt string generation, fallback unassigned bindings.
- `tests/scenario/test_ui_flow.gd`: Title Screen -> Save Slot Select -> World load; Pause Menu pause/resume/quit; CLI argument bypass (`--room` and `--smoke`); Toast notification queue and auto-dismiss.

---

## Acceptance
- `tools/check.ps1` and `tools/check.ps1 -Full` green with zero test failures, zero script errors, and zero orphan nodes.
- HUD renders all required elements (model, integrity, heat, spark TTL, routine, garage slots, clearance, scrap, shards, link range, cooldowns) responding reactively to game events; F3 toggles the debug overlay cleanly via InputRouter.
- Map overlay displays discovered rooms without unvisited ghost cells, highlights active room, shows docks/parked hosts, and executes Bus fast-travel when Bus Pass is owned.
- Log reader displays title, timestamp/index, and formatted body text for collected logs.
- Settings menu saves and loads audio (Master/SFX/Music/UI), video, feel toggles, accessibility multipliers, and custom keybindings to `user://settings.json`.
- Accessibility multipliers directly modify gameplay (Spark TTL decay, damage calculation).
- Title screen allows slot selection and pause menu offers resume/settings/quit; `--room <id>` and `--smoke` bypass UI navigation directly into `World`.
- Windows binary (`build/Daemon.exe`) builds and smoke tests pass.

---

## Evidence I Will Attach
- Test output from `tools/check.ps1 -Full`.
- Non-headless screenshots in `shots/`:
  - `shots/p06_hud_gameplay.png`: HUD with integrity pips/bar, heat bar, routine badge, link range, and garage slots.
  - `shots/p06_map_overlay.png`: Map overlay with discovered rooms, current room highlight, and visited docks.
  - `shots/p06_settings_menu.png`: Settings menu displaying sliders, accessibility options, and rebind prompts.
  - `shots/p06_title_screen.png`: Title screen and save slot select interface.
- Verification diff showing round-trip save and load of `user://settings.json`.

---

## Assumptions and Risks
1. **CLI Bypass Contract**: Automated tests and test scripts (`check.ps1`, `shot.gd`) rely on `--room <id>` and `--smoke`; `src/main.gd` must cleanly bypass the Title Screen directly into `World` when these flags are present.
2. **Coordinate & Viewport Budget**: The 480x270 viewport strictly allocates 480x240 for the playfield and 480x30 for the HUD bar without introducing camera panning or sub-pixel distortion.
3. **AudioBus Setup**: Volume settings interface with Godot's `AudioServer` buses (`Master`, `SFX`, `Music`, `UI`), persisted in `user://settings.json`.
