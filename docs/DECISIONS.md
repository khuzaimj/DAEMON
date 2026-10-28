# DAEMON Decision Log

- 2026-10-27 · D1 · Engine Version · Pinned Godot standard build version 4.7.2.stable.official.ed1daf0bf.
- 2026-10-27 · D2 · Renderer · Pinned GL Compatibility renderer for broad Windows hardware support.
- 2026-10-27 · D3 · Testing Addon · Approved GUT v9.6.1 as unit/scenario test framework.
- 2026-10-28 · D4 · Logic Graph Semantics · One-tick delay on loop-closing link by DFS from sorted ids; empty gates false; NOT of multi-input is NOR; latch reset beats set; timer restarts on rising edge and lasts N ticks; switch toggles <= once per tick; edges index into sorted array to avoid RefCounted cycles.
- 2026-10-28 · D5 · Entity Logic Semantics · Graph outputs boolean energized state; unlinked doors/beam_gates default energized; doors open when energized and clearance met; firewalls disabled while energized; broken structures latched on completion.
