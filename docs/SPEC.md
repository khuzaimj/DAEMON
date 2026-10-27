# 1. Product spec (locked)

All numbers are starting values. They live in data files and get tuned in playtests with the user.

### 1.1 Premise and tone

- Setting: THE MERIDIAN, a derelict arcology that is one giant machine, still running after its crew vanished.
- Player: a daemon, a background process that woke up with no body.
- Antagonists: the facility's immune system (Antivirus Sentinels, Firewalls, Quarantine Pods, Bitrot, the Garbage Collector).
- Tone: lonely, wry cassette-futurism. Amber, green and cyan phosphor palettes, one dominant per zone.
- Story bible (proposed, the user may edit): the crew uploaded themselves into the Kernel to escape a failing world and left the station running. The player is their rollback process, built to restore the last good state. The Kernel (what the crew became) treats it as malware. Terminal logs reveal this across zones. Ending choice at the Kernel: ROLLBACK (restore the crew, erase the Kernel) or COMMIT (accept the new state, the daemon retires). About 64 logs, dry humor, a few lines each. Story is delivered only through logs and environment.

### 1.2 Core hook: Hijack + Park

1. **Forms.** The player is Hosted (piloting a body), Cursor (the daemon's own XS body, exposed), or in Transit. Cursor is a normal body definition.
2. **Spark TTL.** While Cursor is exposed (not in a conduit, Dock or Node) a TTL timer runs: 8 s base, upgradable to 20 s. At 0 the daemon reboots at the last Dock. Transit does not consume TTL. The tutorial room pauses TTL until the first hijack.
3. **Targeting.** Press Hop while Hosted or Cursor. Time slows to 25% (max 1.0 s). Valid targets within Link Range (base 5 tiles, +2 per upgrade, max 11) and line of sight are highlighted. Aim selects, Hop confirms, Back cancels.
4. **Valid targets.** Dormant machines with clearance at or below the player's; hostile machines that are Open; parked hosts; Nodes (infrastructure ports). Never: immune-system units, boss bodies (only their subsystems).
5. **Open.** A hostile is Open when Integrity ≤ 35% or while Overloaded (status from Drone Pulse and some hazards). Open shows a pulsing port glow.
6. **Transit.** The old host is parked immediately. The spark flies straight at 20 tiles/s, invulnerable, and is stopped by Firewall fields (the hop fails and TTL starts where it stopped). On arrival the target becomes Piloted: its controller is swapped for the PlayerController and the old controller is kept in `Parked`.
7. **Registration.** The first seizure of a body model registers it permanently in the Garage and fires a log entry.
8. **Eject.** Voluntary: hold Hop 0.5 s, become Cursor at the host's position. Forced: Integrity 0 (host Crashed, disabled until a Medic repairs it or it is recycled) or Heat 100 (host Overheated, locked 3 s).
9. **Parking.** A host you leave is Parked with the routine selected on the HUD at the moment of hopping:
   - HOLD: inert blocker and weight.
   - GUARD: stays put, uses primary on hostiles in range and line of sight.
   - PATROL: walks between its park position and the player's last Pin (default 5 tiles forward), guarding while walking.
   - REPEAT: uses primary continuously in place, facing locked.
   The Routine button cycles the selection; holding it drops a Pin.
10. **Garage and Docks.** Docks are checkpoints: save, repair and cool the current host, respawn enemies, open the Garage. The Garage fabricates any registered body for scrap (cost by tier) in the Dock bay. Garage Slots cap parked hosts persisted outside the current room (3 base, +1 per upgrade, max 6). When exceeded, the oldest are recycled for a scrap refund unless they hold a latched puzzle state.
11. **Death.** Cursor TTL expiry or Cursor killed means reboot at the last Dock, enemies respawn, no scrap loss. Parked hosts in other rooms remain.
12. **Why it is its own thing.** Bodies persist in the room as puzzle pieces, and every enemy is a future body.

### 1.3 Bodies (abilities double as Metroidvania keys)

Heat max is 100 for all bodies; cooldown 20/s; each ability has its own Heat cost in data. Speed is tiles per second.

| Body | Size | Wt | Speed | Integrity | Primary | Secondary | Passive |
|---|---|---|---|---|---|---|---|
| Cursor (base) | XS | 0 | 7.0 | 2 | Ping: reveals hidden links, nodes, secrets for 3 s | none | Enters conduits; TTL when exposed |
| Janitor | M | 1 | 3.5 | 6 | Sweep: 90° melee arc, clears grime, debris, Bitrot | Suction: pulls scrap and light debris | Immune to Bitrot |
| Loader | L | 3 | 2.6 | 14 | Ram: charge, knockback, breaks cracked walls | Lift: carry and throw crates and bodies up to M | Knockback resistant |
| Sentry | M | 2 | 0 (rotates) | 8 | Shoot: aimed bolt | Overwatch: locks an arc, auto-fires, low Heat | Armored front |
| Drone | S | 0 | 4.5 | 4 | Pulse: short electric shot, applies Overload | Tow: carries objects up to S | Hovers over pits; Heat drains 8/s while over a pit |
| Welder | M | 1 | 3.2 | 7 | Torch: short thermal cone, cuts weld seams, ignites | Arc: channelled beam, cuts barriers, high Heat | Fire immune |
| Diver | M | 1 | 3.6 (land 2.4) | 8 | Harpoon: piercing line, tethers objects | Bubble: short shield | Swims in coolant |
| Crawler | S | 1 | 4.0 | 5 | Claw: fast melee | Cling: walks magnetic walls | Insulated: ignores floor hazards |
| Courier | S | 0 | 5.5 | 5 | Parcel: thrown projectile | Dash: 0.18 s invulnerable, crosses gaps up to 3 tiles | Crosses collapsing floors |
| Medic | M | 1 | 3.4 | 6 | Repair Beam: heals hosts, repairs structures | Patch: instant small self-heal | Parked on REPEAT it heals nearby parked hosts |

Size classes (hitbox px, in `data/sizes.json`): XS 8, S 12, M 14, L 24, XL 48+.

### 1.4 Gate matrix

| Gate | Needs | Notes |
|---|---|---|
| Conduit | Cursor (XS) | tubes and vents; no TTL drain inside |
| Narrow gap (1 tile) | size ≤ M | blocks Loader |
| Grime, debris, Bitrot | Janitor Sweep | |
| Cracked wall, heavy plate (weight ≥ 3) | Loader | |
| Pit | Drone hover, or Courier Dash for gaps ≤ 3 tiles | |
| Coolant | Diver | other bodies take 15 Heat/s and cannot swim |
| Weld seam, barrier | Welder Torch or Arc | |
| Electrified or spiked floor, magnetic wall | Crawler | |
| Collapsing floor, timed door | Courier Dash | |
| Broken structure | Medic Repair Beam | |
| Clearance door L1–L4 | clearance flag | granted by bosses |
| Remote Node beyond range | Link Range level | |
| Firewall field | disable at its Node | blocks hops |

### 1.5 Enemies

Hostile and dormant units of a body model appear only from that model's unlock zone onward (a validator rule), except Janitor in Zone 1.

| Enemy | Role | Hijackable | From zone |
|---|---|---|---|
| Glitch Mite | weak erratic swarm, drains Heat on contact | no | 1 |
| Rogue Janitor | melee swarmer, two AI variants (swarmer, heavy) | yes, Janitor | 1 |
| Bitrot | spreading corrupt tiles that damage hosts; cleared by Sweep | n/a | 1 |
| Rogue Loader | charger | yes, Loader | 2 |
| Antivirus Sentinel | hunts an exposed Cursor, seeking bolts | no | 2 (intro), common from 3 |
| Rogue Sentry | stationary shooter | yes, Sentry | 3 |
| Firewall Node | projects barrier lines that block hops; disabled from its maintenance Node | no | 3 |
| Diver Bot | water ambusher | yes, Diver | 4 |
| Quarantine Pod | traps parked hosts, spawns on alarm | no | 4 |
| Welder Bot | thermal cone | yes, Welder | 5 |
| Garbage Collector (roaming) | deletes parked hosts it touches | no | 5 |
| Drone Patrol | flying skirmisher | yes, Drone | 6 |
| Crawler, Courier Bot | hazard runner, dasher | yes, Crawler / Courier | 7 |
| Medic Bot | heals other enemies; priority target | yes, Medic | 8 |

### 1.6 Bosses

Every boss is a giant machine beaten by hijacking its subsystems (actuators, lenses, valves). Each fight is a puzzle with phases. A boss body itself is never hijackable.

| Boss | Zone | Idea | Reward |
|---|---|---|---|
| Bootloader | 1 | giant press; hijack its three actuators in order | Clearance L1 |
| Dispatcher | 2 | rail-bound train-bot; hijack carriages to ram it | Bus Pass (fast travel) |
| Prefetcher | 3 | predictive turret array that fires where you were; hijack its lenses | Shard |
| Pager | 4 | leviathan that swaps room contents; hijack swap valves | Shard |
| Garbage Collector | 5 | compactor that deletes parked hosts; bait it with parked hosts | Shard |
| Overflow | 6 | recursive tower; nested copies, hijack to reduce depth | Clearance L3 |
| Scheduler | 7 | time-slice boss; only one arm is active per slice | Clearance L4 |
| Kernel | 8 | multi-phase, needs every body; ending choice | Ending |

### 1.7 World

- One connected map on a world grid of 28×18 cells. One room per cell. One room is one screen (30×15 tiles). Rooms connect by edge exits, doors and Docks.
- Target about 20 rooms per zone (16 to 26), about 160 total, plus about 10 secret rooms.
- At least 25% of upgrades require a body from a later zone (backtracking).
- Fast travel: Bus stations (Docks) unlock with Dispatcher's Bus Pass.

| Phase | Zone | Palette | Unlocks | Verbs introduced | Boss |
|---|---|---|---|---|---|
| P10 | Boot Sector | amber_dim | Janitor | hijack tutorial, conduits, grime, narrow gaps, plates, Docks | Bootloader |
| P11 | Bus Depot (hub) | green_lume | Loader, Bus Pass | heavy plates, conveyors, cracked walls, lifts, crates | Dispatcher |
| P12 | Cache | cyan_cold | Sentry, Link Range +1 | beam gates, Firewall fields, parked-guard puzzles | Prefetcher |
| P13 | Swap | teal_deep | Diver | coolant, pumps, flow puzzles | Pager |
| P14 | Heap | rust_orange | Welder | weld seams, fire, heavy Bitrot, crushers | Garbage Collector |
| P15 | Stack | violet_neon | Drone | pits, tall loops, Tow, Overload hijacking | Overflow |
| P16 | Registers | yellow_white | Crawler, Courier | electrified floors, magnetic walls, collapsing floors, timed doors | Scheduler |
| P17 | Kernel | mono_white | Medic | broken structures, all-gate gauntlets, multi-body finale | Kernel |

Dependency graph (the validator in P6 proves it is completable and softlock-free):

```
Boot Sector --(Janitor, L1)--> Bus Depot (hub)
Bus Depot --> Cache | Swap | Heap        any order; each boss drops a Shard
3 Shards = Clearance L2 --> Stack
Stack boss (Overflow) --> L3 --> Registers (needs Drone for pits)
Registers boss (Scheduler) --> L4 --> Kernel (needs every body; Medic found in the antechamber)
Later bodies reopen earlier zones: secrets, upgrades, shortcuts.
```

### 1.8 Progression items

Link Range +2 (×3), Integrity Chips +1 on every body (×12), Heat Sinks +10 Heat max (×8), TTL Extenders +3 s (×4), Garage Slots +1 (×3), Clearance L1–L4 (bosses; L2 is 3 Shards), Logs (64 plus 6 secret), Scrap (currency, from kills and pickups; spent at Garage).

### 1.9 Combat

- Real-time. Hitboxes versus hurtboxes. Damage types: kinetic, thermal, electric. Resist and vulnerability per body in data.
- Hit response: knockback, 0.5 s invulnerability, 2 to 4 frames hit-stop, small screen shake.
- Heat: abilities add Heat, electric hits add Heat. At 100 the host Overheats and you are ejected.
- Status: Overload (2 s stun, target becomes Open), Burn (damage over time), Stagger.
- Kill gives scrap. Hijack gives the body. Bosses use phases defined in data.

### 1.10 Puzzle vocabulary

Pressure plate (weight threshold), switch, latch (persistent), timer, AND/OR/NOT, door (clearance colors), lift, bridge, conveyor, crusher, beam gate and emitter, crate, collapsing floor, cracked wall, weld barrier, grime and debris, Bitrot, coolant, hazard floors, magnetic wall, pit, conduit, Node (hop in to operate remote machinery), broken structure (repairable), Firewall field, parked-guard checks, REPEAT-loop machinery.

### 1.11 Art direction

- Style: pixel art. Base resolution 480×270, integer-scaled, nearest-neighbor filtering, no sub-pixel movement. Playfield 480×240 (30×15 tiles of 16 px) plus a 30 px terminal-style HUD strip at the bottom.
- Frames are 16×16. Loader and large bodies are 32×32. Bosses are 48 to 96 px, assembled from parts.
- Three facings are drawn (down, up, side). Left is the side sheet flipped at runtime.
- Required animations per body: idle, walk (4 frames), primary (3), secondary (3), each in down, up and side; plus hurt, crash and dormant (single facing).
- Each sprite: 1 px dark outline, 4-shade ramp per hue, at most 8 colors, light from the top left, no anti-aliasing, no rotated or non-integer-scaled sprites (use sheets and flips).
- Color language: cyan outline means yours, red accent means hostile, white blink means Open, amber means interactable. These are shader effects over a shared base palette, so one sheet serves every variant.
- Zone palettes (3 hues plus accent) live in `data/palettes/`. Lighting uses Godot 2D lights. An optional CRT shader (vignette and faint row darkening) is toggleable.

### 1.12 Audio

Chip-synth only: two pulse channels, one triangle, one noise. Authored as JSON recipes and tracker files, baked to WAV by a tool. About 80 SFX recipes, one music loop per zone plus title, boss and stinger. Adaptive layers (exposed Cursor, combat, boss phases) are separate stems mixed at runtime. Buses: sfx, music, ui.

### 1.13 UX defaults

| Action | Keyboard | Gamepad (Xbox layout) |
|---|---|---|
| Move | WASD / arrows | left stick / d-pad |
| Primary | J | X |
| Secondary | K | Y |
| Hop (hold: eject) | L | RB |
| Routine (hold: drop Pin) | Q | LB |
| Interact / confirm | E | A |
| Back / pause | Esc | B / Start |
| Map | Tab | Back |

- Aim follows facing (8-way). The right stick overrides aim on gamepad. Sentry rotates with Move.
- HUD strip: body name and icon, Integrity pips, Heat bar, TTL ring when Cursor, routine icon, scrap, Link Range pips, latest log line.
- Saves: 3 slots, autosave at Docks and on zone change. Length target 8 to 10 hours. One difficulty plus assists (damage taken, TTL length, aim assist, Heat rate).
- Settings: window mode, volume buses, CRT (off, low, on), screen shake, flash reduction, key rebinding.
