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

**D-014 32 px tiles, 1280 x 720 base resolution** (2026-10-09, answers Q-008)
- What: the game renders at 1280 x 720 (stretch mode "viewport", pixels snapped) and scales up to the window (opens at 1920 x 1080). Tiles stay 32 x 32; the host is about 48 px tall. About 40 x 22 tiles on screen.
- Why: more detail per tile and character (closer to Blasphemous than Celeste), and current tile size and movement numbers stay valid.
- Trade-off: crisp at 1440p (2x) and 4K (3x); at 1080p the scale is 1.5x, so some pixels are one screen pixel wider than others. Accepted, common for 720p-based pixel games. Each tile is ~4x the pixels of a 16 px tile, so drawing takes longer; reuse and variation tiles help.

**D-015 Progression lives in the body, not a skill tree** (2026-10-09)
- What: no XP, no skill tree on the character. Mutations come from eating (later grafting) god-matter and fill body slots (head, mouth, back, arm, belly), one per slot; a new one replaces the old. Mutations are lost with the body (recoverable from the corpse, week 22). A small cross-life tree for the fragment itself (unlocked by deeds and legend, not XP) is an idea for after phase 3.
- Why: a classic tree gives the player a reason to never die, which fights the core loop (death moves history forward). Body slots make the build visible and physical, as VISION describes.
- Rules out: XP-based character skill trees.

**D-016 Basic UI, combat and mutations pulled forward** (2026-10-09)
- What: built together after week 9: main menu, pause menu, 8-pocket inventory, HUD (roadmap week 41 basics); combat components, player attack, training dummy, Gut Leech (weeks 13-14); mutations v1 with three abilities (week 17). All grey-box.
- Why: developer wanted a playable loop sooner. Weeks 10-12 (set pieces, light, milestone) still to do; weeks 13, 14 and 17 are largely done but get re-checked against their "done when" when reached, and week 15-16 art rigs wait on Q-007.

**D-017 Layered frame animation** (2026-10-09, answers Q-007, replaces the cutout-rig part of D-002)
- What: frame-by-frame pixel animation from PNG strips (one per animation, square frames) loaded by `SpriteSheets`. `LayeredSprite` plays the body and keeps overlay layers (mutation parts, glow) on the same animation and frame, in front or behind.
- Why: classic pixel-art look; rotating rig parts would smear pixels. A mutation only needs its own small overlay frames per animation, not a redraw of the host.
- Costs: more drawing per animation than a rig; overlays must match the host's frame counts; several host body types will need one overlay set each. Squash and stretch removed (fractional scaling distorts pixels).
- Rules out: Skeleton2D cutout rigs.

**D-018 Combat style: loose and systemic** (2026-10-10, answers Q-001)
- What: forgiving, systemic combat (Noita, Caves of Qud) over precision (Hollow Knight). More health, more tools (mutations), creatures that interact (friendly fire on enemy attacks), many ways through a fight.
- Why: the developer preferred the loose arena after playing both. Fits pillar 4 (many answers to one problem).
- Consequences: friendly fire becomes the default in the world; tuning favors readable but not twitchy enemies; precision platforming stays in movement, not in combat.

**D-019 Base resolution 960 x 540** (2026-10-10, replaces the resolution part of D-014; replaced by D-023)
- What: the game renders at 960 x 540 (was 1280 x 720). Tiles stay 32 px; about 30 x 17 tiles on screen.
- Why: the developer wanted the view slightly zoomed in, and 960 x 540 scales by exactly 2 on 1080p (and 4 on 4K), so pixels stay even. 1280 x 720 scaled by 1.5 on 1080p, which made pixels uneven and camera motion steppy. A Camera2D zoom would have brought uneven pixels back.
- Trade-off: less of the world visible at once. 1440p scales by 2.67 (uneven), acceptable.

**D-020 Nothing carries over between hosts except through the body** (2026-10-10, answers Q-003)
- What: on death every item and mutation stays on the corpse. The next host starts with nothing; the only way back to them is reclaiming the body.
- Why: makes the corpse the point of the loop and keeps each host a fresh start. Cross-life progression, if any, belongs to the fragment (legend), not to inherited mutations.
- Rules out: mutations surviving death in weakened form (the VISION idea), for now.

**D-021 Time passes on death as rolled aftermath, not simulation** (2026-10-10, answers Q-002)
- What: each death rolls a time gap tier (a few days / some months / years / decades). The tier sets a strength 0..1 and advances the year. A short list of aftermath rules applies at that strength: old bodies get scavenged and their mutations rot (the newest body always keeps something), killed creatures may be replaced, dropped items may vanish, and the death plus what happened is written to an event log. The player sees "N years later" and a hint or two, not a list.
- Why: keeps the pitch (every death moves history forward) without simulating years: nothing ages, the hand-placed world stays hand-placed, and each system opts in with its own small rule. Phase 4 factions add rules instead of a calendar sim.
- Rules out: year-by-year simulation between lives, for now.

**D-022 Floors have a 2.5D top face** (2026-10-10; face depth and sink changed by D-023: 12 px and 6 px)
- What: tiles with air above show a top face along their top 6 px, lighter than the side, like Blasphemous. Walls and ceilings stay flat. Floor collision starts `ChunkData.FLOOR_SINK` (4) px below the tile's top edge, so characters stand in the face instead of on its back edge. Hand-placed floor things go at tile top + 4.
- Why: gives the flat side view depth and makes floors read as walkable surfaces at a glance, at the cost of one face per up-open tile.
- Consequences: tile art reserves the top 6 px of up-open tiles for the face. Ledges are 4 px lower to land on and 1-tile platforms 4 px thinner; jump heights are unchanged. Anything placed by raycast (corpses, dropped items) needs no change.

**D-023 Blasphemous-like view: 640 x 360, 64 px hosts, low camera, stone ground** (2026-10-10, replaces D-019; changes D-022's numbers)
- What: the game renders at 640 x 360 (was 960 x 540). Hosts are 64 x 64 frames, drawn about 56 px tall (was 48 / 41), collision capsule 52 px. The camera is Phantom Camera (`GameCamera`, src/camera): the player stands at about 77% of the screen height, the view leads horizontally with movement, swings down when falling fast, damped; shake is a Phantom Camera noise emitter. Floors have a 12 px top face (was 6) and `FLOOR_SINK` is 6 (was 4); all rock gets a textured cobble fill instead of fading to black. UI: 10 px text, anti-aliasing off, layouts shrunk to fit.
- Why: the developer wanted the point of view and style of Blasphemous: bigger tiles and characters on screen, less empty rock below the floor. 640 x 360 is also an exact integer scale on 1080p (3x), 1440p (4x, which 960 x 540 was not) and 4K (6x).
- Trade-offs: about 20 x 11 tiles on screen (was 30 x 17): less of the world visible at once. 2-tile tunnels are now tight. Creatures stay 48 px for now and look smaller next to the host. 10 px text with the default font is small; a pixel font would fix it (assets/fonts).

**D-024 Dodge roll; Shift is dodge** (2026-10-10, from the week 25 playtest)
- What: a ground roll on Shift / LB: about 100 px in 0.32 s, hits ignored for the first 0.26 s, 0.45 s cooldown, jump cancels it into a fast jump. The arm ability (Bone Spur) moves to L / RB only. In menus, Q / E and LB / RB switch inventory tabs, X / pad X drops.
- Why: the developer found movement stiff and wanted a dodge; it is also the systemic answer to a hit you can see coming, which fits loose combat (D-018).
- Consequences: every host needs a `dodge` animation (placeholders generated); mutation overlays too.

**D-025 The past is simulated at world creation; destined factions** (2026-10-10, week 28)
- What: a new world gets 2000 years of history, simulated year by year from its seed before play starts (the game starts in year 2000 after the Fall). Invented peoples arrive, settle, trade, war, split and die out; the hand-made factions are destined: the Flesh-Tenders appear early, the Choir of Waking is born mid-history as a schism from the most devout people of the time, and neither can vanish. Surviving invented peoples live elsewhere in the body. History is saved (factions, sites, events), not regenerated, so improving the sim never rewrites an existing world's past.
- Why: VISION's "generated history" pillar, while keeping the hand-made world (D-010) and the hand-written present-day factions the game is built around. Year-by-year simulation is fine here because it happens once, before play; D-021 still keeps death-to-death time cheap.
- Consequences: settlement slots take their sites from history (names, founding years, populations); SiteData.population is people (residents shown = people / 25); FactionData carries its own identity. Save version 12.

**D-026 First boss pulled forward: the Gullet Matron** (2026-10-10, roadmap week 38 done early)
- What: a two-phase boss with an explicit state machine (DORMANT, INTRO, STALK, WINDUP, ACTIVE, RECOVER, STAGGER, PHASE_SHIFT, DEAD) and five attacks, tested in its own arena (main menu: "Boss: the Gullet Matron"). Not placed in the world yet.
- Fairness rules it is built and tested on: every attack telegraphs (>= 0.35 s even in phase 2) and leaves a punish window (>= 0.5 s); every attack can be avoided by moving, jumping or rolling; her body only hurts while it moves into you or a slam comes down on you; her own attacks never hurt her (they do hurt her brood); a burning puddle burns once per step; staggers reward pressure but cannot be chained.
- How "feels good" is checked: tests/test_boss.gd plays seeded fights with a bot that reads telegraphs like a decent player (tests/boss_bot.gd): it must win most fights in 40-120 s, while walking up and mashing and standing still must lose.
- Why now: the developer asked for a boss interlude between weeks 31 and 32.

**D-027 Ichor: a reason for each life** (2026-10-10, after week 33)
- What: ichor, the god's dried blood, is what each life is after. Creatures, ruins, deep places and bosses give it (deeper gives more); the host carries it and it stays on the corpse at death, like everything else. Pouring it into a heart-root (a Choir altar, or a wild vein of living god-tissue) banks it for good, and banked ichor buys boons for the fragment that last across lives (more host choices, a graft that survives death, sensing old bodies, a sturdier host).
- Why: playtesting weeks 21-33 felt a bit pointless: a life had no goal, death cost little, and nothing found mattered later. Ichor gives a go in, gather, risk, bank-or-die loop that every later system can plug into (bribes, shrine robbing, valve keys).
- Rejected for now: a burn-out timer per host and per-life "whisper" goals. Both may come back once there is more content.
- Roadmap: ichor is a new week 34; murals, non-combat options, the milestone and the valve key move down one week; the mini-boss week is gone (built early, D-026), so the art pass stays at week 39.

---

## Open questions

| ID | Question | Decide by |
|---|---|---|
| Q-004 | Outlines or no outlines in the art style? | Week 15 |
| Q-005 | Final name of the game. | Before the Steam page, week 45 |
| Q-007 | Mutation art at scale: the goal is tens to hundreds of mutations (like Isaac items), but D-017 overlays need one strip per animation per host body (about 33 frames each now). Proposal: hosts get a per-frame anchor layer (socket points, maybe rotation), drawn once per host; a mutation is one small part sprite per slot (optionally a 2-4 frame loop) placed on the anchor every frame. Hand-drawn overlays stay possible for showcase parts. | Before drawing mutation art |
| Q-006 | Breakable terrain at all? Developer doubts it. If not, week 8 becomes "chunk diffs for entity state only" (dead NPCs, taken items, corpses). | Week 8 |
