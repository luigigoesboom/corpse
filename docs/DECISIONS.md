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

**D-010 Hand-painted world, no terrain generation** (2026-10-09, replaces D-005 and the generation part of D-008)
- What: the whole world is painted in Krita as `data/maps/world.png`, 1 pixel = 1 tile (dark = rock, light/transparent = air, red = spawn). The game cuts it into 64 x 64 chunks and streams them as before. No noise, no procedural terrain.
- Why: the developer wants to craft every space by hand and has the time. The world persists across lives, so per-run variety from generation matters less than in a roguelite; variety comes from history instead. Painting is fast (big brushes for caves, small ones for details) and needs no level editor.
- Kept: chunk streaming, chunk diffs (now diffs against the painted map), saves, the history sim. The world seed stays for per-save things like history.
- Changes: the history sim places ruins, shrines and colonies into hand-made slots instead of generated spots. Detailed rooms (colonies, boss arenas) can still be built as Godot scenes and placed on the map (week 10).
- Rules out: procedural terrain, per-run random worlds.

**D-011 Author the world in Godot on top of the painting** (2026-10-09)
- What: terrain is still painted in Krita (D-010), but `scenes/world.tscn` shows the painting in the editor (`MapPreview`, @tool) so NPCs, props and the player spawn are placed in Godot as normal nodes. The red spawn pixel is gone; spawn is a Marker2D. Placed entities stream with their chunk (`EntityLayer`).
- Why: painting is great for terrain, bad for placing and configuring things. Godot's editor is the right tool for that.
- Rules out: encoding NPCs or items as pixel colors.

**D-012 Pixel art** (2026-10-09, replaces the art style part of D-002)
- What: all game art is pixel art. Project default texture filter is Nearest (crisp pixels).
- Why: developer's choice. Pixel art suits drawing on a tablet at small sizes, fits the Isaac / Noita side of the inspirations, and placeholder-to-final is a smooth path.
- Consequences: cutout rigs (Skeleton2D) look bad on pixel art when parts rotate, because pixels shear. Animation approach is reopened (Q-007). Mutations-as-body-parts still works: parts can be sprite layers drawn per animation frame, attached at socket positions. Base resolution and tile size are reopened (Q-008).
- Rules out: smooth hand-painted sprites, linear texture filtering.

**D-013 Sim data is the truth, nodes are views** (2026-10-09)
- What: runtime things (dropped items now, corpses later) live in `WorldData` from the moment they exist. Chunk loads spawn view nodes from the data; unloads free them. Hand-placed things live in world.tscn; their permanent changes (picked up, killed) go into `WorldData.removed_entities` by node name.
- Why: nothing to write back on unload, saves are always complete, and the history sim can act on things nobody is looking at.

---

## Open questions

| ID | Question | Decide by |
|---|---|---|
| Q-001 | Combat difficulty: precision (Hollow Knight) or forgiving and systemic (Noita, Qud)? | Week 20 |
| Q-002 | How many years pass on death, fixed or variable? | Week 23 |
| Q-003 | Do any mutations carry over between lives without reclaiming the corpse? | Week 25 |
| Q-004 | Outlines or no outlines in the art style? | Week 15 |
| Q-005 | Final name of the game. | Before the Steam page, week 45 |
| Q-007 | Pixel art animation: frame-by-frame sprites, or a pixel-friendly rig (no rotation, parts only move)? Decides how mutations attach. | Week 15 |
| Q-008 | Base resolution and tile size for pixel art (e.g. 640 x 360 with 16 px tiles, or 32 px tiles). Changes TILE_PX and movement numbers. | Before art week 11 |
| Q-006 | Breakable terrain at all? Developer doubts it. If not, week 8 becomes "chunk diffs for entity state only" (dead NPCs, taken items, corpses). | Week 8 |
