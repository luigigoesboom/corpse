# Decisions

Append only. When a decision changes, add a new entry that replaces the old one instead of editing it.

Format: ID, date, decision, why, what it rules out.

---

**D-001 2D side-view, not 3D** (2026-10)
- Why: 3D asset production would eat the time meant for systems. Side-view makes "depth" literal and suits traversal.
- Rules out: 3D, top-down.

**D-002 Hand-drawn art with cutout rigs** (2026-10)
- Why: drawing tablet available, closer to the games that inspired this than pixel art, and cutout rigs cut animation cost. Mutations can attach as rig parts.
- Rules out: frame-by-frame animation for most creatures.

**D-003 Setting: inside a dead god's body** (2026-10)
- Why: distinctive, anatomy gives natural biomes, deeper-is-older works as structure, fits a dark hand-drawn style.
- Rules out: underwater setting (floaty controls, Subnautica comparisons).

**D-004 Persistent world with rebirth, not a reset roguelite** (2026-10)
- Why: the history sim and hand-painted map only pay off if the world remembers. Death advancing time is the core idea.
- Rules out: wiping the world between runs.

**D-005 Painted macro map plus procedural detail** (2026-10)
- Why: authored structure and landmarks, generated texture. Redesigning a region takes minutes with a brush.
- Rules out: fully random world layout.

**D-006 Real-time combat, one tool among several** (2026-10)
- Why: fits exploration and traversal. Sneak, talk, bribe and eat are equal options.
- Rules out: turn-based combat.

**D-007 Godot 4.x with GDScript** (2026-10)
- Why: already chosen by the developer. GDScript is fast to iterate in. C# or GDExtension only if profiling shows a real need.

**D-008 Chunk streaming prototype pulled forward to week 2** (2026-10-09)
- Why: wanted a big world to test movement in. A basic version of week 5 (chunks load/unload around the player) was built alongside week 2. Weeks 3 and 4 still come next in order; week 5's "done when" is re-checked when it comes up.
- Details: 16 x 8 chunks, hard-coded until the painted map (week 4) sets the bounds. Load radius 1 (3 x 3 chunks) instead of the 2 in ARCHITECTURE.md, because one 64-tile chunk is already 2048 px, far wider than the screen. Only rock cells that touch open space get collision.
- Rules out: nothing. Generation is still on the main thread (week 6 moves it to a worker).

**D-009 Wall cling over ledge grab** (2026-10-09)
- Why: simpler, and climbing up flesh walls fits the setting. Push into a wall in the air to slide slowly, jump to kick off.
- Rules out: ledge grab, for now.

---

## Open questions

| ID | Question | Decide by |
|---|---|---|
| Q-001 | Combat difficulty: precision (Hollow Knight) or forgiving and systemic (Noita, Qud)? | Week 20 |
| Q-002 | How many years pass on death, fixed or variable? | Week 23 |
| Q-003 | Do any mutations carry over between lives without reclaiming the corpse? | Week 25 |
| Q-004 | Outlines or no outlines in the art style? | Week 15 |
| Q-005 | Final name of the game. | Before the Steam page, week 45 |
