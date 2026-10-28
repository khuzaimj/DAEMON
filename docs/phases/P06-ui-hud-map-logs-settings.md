# P06 — UI, HUD, map, logs, and settings · Brief

**Goal:** Implement the structured pixel-art HUD, map overlay with Bus fast travel, terminal log reader, polished Dock/Garage modal, Title & Save Slot select screens, Pause menu, Settings with accessibility and key rebinding, and context-sensitive input prompts.

---

## Tasks

- **P6.1 Pixel-Art HUD & Top/Bottom Bar (`src/ui/hud.gd`, 480 x 30 px bar):**
  - Replace the placeholder debug `HUDLabel` with a modular pixel-art HUD component in the 480 x 30 px bar.
  - Host model badge (e.g. `PATCH`, `LOADER`, `CURSOR`, etc.) + Integrity bar/pips (`current_integrity / max_integrity`).
  - Heat bar (`current_heat / max_heat`) + visual overheat lockout flash warning when locked out.
  - Spark TTL bar & countdown indicator (active in `CURSOR` state; paused indicator inside safe zones).
  - Parked Routine selector badge (`HOLD`, `GUARD`, `PATROL`, `REPEAT`) + active Pin indicator.
  - Garage Slots pips: display occupied outside parked slots vs `Game.garage_slots_cap`, visually distinguishing latched hosts.
  - Clearance badge (`L0`–`L4`), Scrap counter, Shard counter (`0/3`), and Primary/Secondary ability cooldown / charge indicators.
  - Retain toggleable debug/perf overlay (`F3`) showing tick, FPS, entity counts, room id, and memory.

- **P6.2 Map Overlay, Log Reader & Enhanced Garage UI (`src/ui/`):**
  - **Map Overlay (`src/ui/map_overlay.gd`, `Tab` / `map` action):** Renders discovered rooms (`Game.discovered_rooms`) by zone grid coordinates, highlights the player's current room, displays visited Docks and parked host icons, and enables Bus fast travel (`Game.fast_travel_to_dock`) when `Game.has_bus_pass` is true.
  - **Log Reader Panel (`src/ui/log_reader.gd`):** Lists all logs collected in `Game.logs`, formatted with log title, source, timestamp/index, and lore body text (supporting data from `data/logs/*.json` or room definitions).
  - **Garage & Dock Modal (`src/ui/garage_modal.gd`):** Polished modal for Dock resting, fabricating registered models with scrap costs and stat comparisons, viewing parked host routines, and remotely recycling outside parked hosts for scrap.

- **P6.3 Title Screen, Save Slot Select, Pause Menu & Status Toasts (`src/ui/`):**
  - **Title Screen & Slot Select (`src/ui/title_screen.gd`, `src/ui/slot_select.gd`):** `Continue`, `New Game`, `Save Slots 1–3` (displaying playtime, body, clearance, scrap, and last saved room), `Settings`, and `Quit`.
  - **CLI Argument Preservation in `src/main.gd`:** Strictly preserve `--room <id>` and `--smoke` bypass so test scripts and automated runs launch directly into `World` without requiring UI navigation.
  - **Pause Menu (`src/ui/pause_menu.gd`):** Opens on `ESC` / `back` when no targeting or modal is open. Provides `Resume`, `Map & Logs`, `Settings`, `Save & Quit to Title`, and `Quit to Desktop`.
  - **Status Toast Banners (`src/ui/toast_banner.gd`):** Non-blocking notification banner for events (`Events.model_registered`, `Events.pickup_taken`, `Events.log_found`, `Events.reboot_triggered`).

- **P6.4 Settings Menu, Rebinding & Accessibility (`src/ui/settings_menu.gd`, `user://settings.json`):**
  - Persist settings via `SaveSystem.save_settings()` / `load_settings()`.
  - **Audio Settings:** Master, Music, and SFX volume sliders connected to `AudioServer` buses.
  - **Video & Game Feel:** Window mode (Windowed 1x/2x/3x, Fullscreen), `screen_shake_enabled` (respected by `World.trigger_screen_shake()`), and `hit_stop_enabled` (respected by `World.trigger_hit_stop()`).
  - **Accessibility (§1.13):** Spark TTL multiplier (`1.0x`, `1.5x`, `2.0x`, `infinite`), incoming damage multiplier (`1.0x`, `0.5x`), and full keyboard/gamepad action rebinding via `InputRouter`.

- **P6.5 Input Prompt Glyphs & UI Test Suite:**
  - **Input Prompt Component (`src/ui/input_prompts.gd`):** Dynamic input prompt helper displaying Keyboard labels (e.g. `[E]`, `[J]`, `[K]`) or Gamepad button icons (e.g. `[A]`, `[X]`, `[Y]`) based on the most recently used input device detected by `InputRouter`.
  - Comprehensive unit and scenario test suite verifying HUD state reactivity, Map & Log population, Bus fast-travel triggering, Settings serialization, accessibility multipliers, and Menu navigation flows.

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
- `docs/STATE.md`
- `docs/phases/P06-ui-hud-map-logs-settings.md`

---

## Tests to Add
- `tests/unit/test_hud.gd`: Unit tests for HUD state updates (Integrity pips, Heat bar & overheat warning, Spark TTL decay & safe-zone pause, Garage occupancy pips, Routine badges, Clearance level, Shard count, cooldown progress).
- `tests/unit/test_map_and_logs.gd`: Discovered rooms layout, current room indicator, visited Dock listing, Bus fast travel execution with Bus Pass, and Log Reader formatting and pagination.
- `tests/unit/test_settings.gd`: Audio volume slider math, settings serialization/deserialization with `user://settings.json`, accessibility multiplier application (`ttl_multiplier`, `incoming_damage_multiplier`), feel toggles (`screen_shake_enabled`, `hit_stop_enabled`), and `InputRouter` key rebinding.
- `tests/unit/test_input_prompts.gd`: Dynamic device switching (keyboard vs joypad), prompt string generation, fallback unassigned bindings.
- `tests/scenario/test_ui_flow.gd`: Title Screen -> Save Slot Select -> World load; Pause Menu pause/resume/quit; CLI argument bypass (`--room` and `--smoke`); Toast notification queue and auto-dismiss.

---

## Acceptance
- `tools/check.ps1` and `tools/check.ps1 -Full` green with zero test failures, zero script errors, and zero orphan nodes.
- HUD renders all required elements (model, integrity, heat, spark TTL, routine, garage slots, clearance, scrap, shards, cooldowns) responding reactively to game events.
- F3 toggles the debug overlay cleanly without obscuring primary playfield elements.
- Map overlay displays discovered rooms, highlights active room, shows docks/parked hosts, and executes Bus fast-travel when Bus Pass is owned.
- Log reader displays title, timestamp/index, and formatted body text for collected logs.
- Settings menu saves and loads audio, video, feel toggles, accessibility multipliers, and custom keybindings to `user://settings.json`.
- Accessibility multipliers directly modify gameplay (Spark TTL decay, damage calculation).
- Title screen allows slot selection and pause menu offers resume/settings/quit.
- Passing `--room <id>` or `--smoke` directly loads the requested room, preserving automated test runs.
- Windows binary (`build/Daemon.exe`) builds and smoke tests pass.

---

## Evidence I Will Attach
- Test output from `tools/check.ps1 -Full` showing passing unit and scenario UI test suites.
- Non-headless screenshots in `shots/`:
  - `shots/p06_hud_gameplay.png`: HUD with integrity pips, heat bar, routine badge, and garage slots.
  - `shots/p06_map_overlay.png`: Map overlay with discovered rooms, current room highlight, and visited docks.
  - `shots/p06_settings_menu.png`: Settings menu displaying sliders, accessibility options, and rebind prompts.
  - `shots/p06_title_screen.png`: Title screen and save slot select interface.
- Verification diff showing round-trip save and load of `user://settings.json`.

---

## Assumptions and Risks
1. **CLI Bypass Contract**: Automated tests and test scripts (`check.ps1`, `shot.gd`) rely on `--room <id>` and `--smoke` command line arguments; `src/main.gd` must cleanly bypass the Title Screen directly into `World` when these flags are present.
2. **Coordinate & Viewport Budget**: The 480x270 viewport strictly allocates 480x240 for the playfield and 480x30 for the HUD bar without introducing camera panning or sub-pixel distortion.
3. **AudioBus Fallback**: If custom audio synth buses are not yet fully baked (scheduled for P8), volume settings will interface with Godot's built-in `AudioServer` buses (`Master`, `SFX`, `Music`) to ensure functional volume control and persistence.

---

## Questions for the User
1. **HUD Strip Position**: SPEC §1.11 defines the 480x30 HUD bar at the bottom (y=240..270) below the 480x240 room playfield, while the prompt mentions a "top bar". Should the HUD remain at bottom (y=240..270) to preserve existing room/entity coordinates, or move to top (y=0..30) with an offset room container?
   *(Recommended: Keep at bottom y=240..270 matching SPEC §1.11 and current scenes/world.tscn layout).*
2. **Infinite TTL Accessibility**: When the accessibility option Spark TTL is set to "infinite", should TTL simply freeze at max value, or display an infinity symbol (`∞`) on the HUD?
   *(Recommended: Display `∞` and pause timer decay in HijackFSM).*
3. **Map Grid Cell Display**: Should the Map overlay render undiscovered rooms as empty fog-of-war grid slots or hide them completely until entered?
   *(Recommended: Hide unvisited room nodes completely, but display faint grid coordinates for visited zone boundaries).*
