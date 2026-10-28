# DAEMON Decision Log

- 2026-10-27 · D1 · Engine Version · Pinned Godot standard build version 4.7.2.stable.official.ed1daf0bf.
- 2026-10-27 · D2 · Renderer · Pinned GL Compatibility renderer for broad Windows hardware support.
- 2026-10-27 · D3 · Testing Addon · Approved GUT v9.6.1 as unit/scenario test framework.
- 2026-10-28 · D4 · Logic Graph Semantics · One-tick delay on loop-closing link by DFS from sorted ids; empty gates false; NOT of multi-input is NOR; latch reset beats set; timer restarts on rising edge and lasts N ticks; switch toggles <= once per tick; edges index into sorted array to avoid RefCounted cycles.
- 2026-10-28 · D5 · Entity Logic Semantics · Graph outputs boolean energized state; unlinked doors/beam_gates default energized; doors open when energized and clearance met; firewalls disabled while energized; broken structures latched on completion.
- 2026-10-28 · D6 · Terrain Hazards and Magnetic Layer · Physics layer 11 is 'magnetic'; machines mask layer 11 by default and Crawler drops layer 11 mask bit when cling is active; conveyors apply push velocity additively in movement before move_and_slide(); collapsing floors trigger 4-connected flood-fill region collapse after data delay; pit damage on collapse applies lethal void damage.
- 2026-10-28 · D7 · Phase Reordering · P06 assigned to UI, HUD, Map, Logs, and Settings (originally P9 in PLAN.md); Content Tooling moved to P09. The rule "from P6 on, every room ships a .solve" is tied to Content Tooling (P09), not UI.
