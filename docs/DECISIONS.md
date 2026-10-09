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

---

## Open questions

| ID | Question | Decide by |
|---|---|---|
| Q-001 | Combat difficulty: precision (Hollow Knight) or forgiving and systemic (Noita, Qud)? | Week 20 |
| Q-002 | How many years pass on death, fixed or variable? | Week 23 |
| Q-003 | Do any mutations carry over between lives without reclaiming the corpse? | Week 25 |
| Q-004 | Outlines or no outlines in the art style? | Week 15 |
| Q-005 | Final name of the game. | Before the Steam page, week 45 |
