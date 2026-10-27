# 7. Content targets and tracker

| Item | Target | Built | Validated | Accepted |
|---|---|---|---|---|
| Zones | 8 | 0 | 0 | 0 |
| Bodies | 10 (including Cursor) | 0 | 0 | 0 |
| Enemy and hazard types | 14 | 0 | 0 | 0 |
| Bosses | 8 | 0 | 0 | 0 |
| Rooms | about 160 plus about 10 secret | 0 | 0 | 0 |
| Logs | 64 plus 6 secret | 0 | 0 | 0 |
| Upgrades | Link Range x3, Integrity Chips x12, Heat Sinks x8, TTL Extenders x4, Garage Slots x3 | 0 | 0 | 0 |
| Sprite sheets | 10 bodies, immune-system units, 8 boss kits, Docks, puzzle elements, pickups | 0 | 0 | 0 |
| Tile atlases | 8 (one per zone) | 0 | 0 | 0 |
| SFX | about 80 | 0 | 0 | 0 |
| Music | 8 zone loops, title, boss, stinger | 0 | 0 | 0 |
| Endings | 2 (ROLLBACK, COMMIT) | 0 | 0 | 0 |

Status values: `todo`, `briefed`, `built`, `validated`, `accepted`. `tools/validate_data.gd` regenerates the counts against these targets (from P6.5 onward).

### Zones
| id | zone | status | notes |
|---|---|---|---|
| boot | Boot Sector | todo | P10 |
| bus | Bus Depot | todo | P11 (hub) |
| cache | Cache | todo | P12 |
| swap | Swap | todo | P13 |
| heap | Heap | todo | P14 |
| stack | Stack | todo | P15 |
| registers | Registers | todo | P16 |
| kernel | Kernel | todo | P17 |

### Bodies
| id | zone | status | notes |
|---|---|---|---|
| cursor | boot | todo | XS base body |
| janitor | boot | todo | M · Sweep / Suction |
| loader | bus | todo | L · Ram / Lift |
| sentry | cache | todo | M · Shoot / Overwatch |
| diver | swap | todo | M · Harpoon / Bubble |
| welder | heap | todo | M · Torch / Arc |
| drone | stack | todo | S · Pulse / Tow |
| crawler | registers | todo | S · Claw / Cling |
| courier | registers | todo | S · Parcel / Dash |
| medic | kernel | todo | M · Repair Beam / Patch |

### Bosses
| id | zone | status | notes |
|---|---|---|---|
| bootloader | boot | todo | Grants Clearance L1 |
| dispatcher | bus | todo | Grants Bus Pass |
| prefetcher | cache | todo | Grants Shard (1/3) |
| pager | swap | todo | Grants Shard (2/3) |
| garbage_collector | heap | todo | Grants Shard (3/3) |
| overflow | stack | todo | Grants Clearance L3 |
| scheduler | registers | todo | Grants Clearance L4 |
| kernel | kernel | todo | ROLLBACK / COMMIT endings |
