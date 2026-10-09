# Devlog

Three lines a week minimum. Newest at the top.

Template:

```
## Week N (YYYY-MM-DD)
Done:
Not done:
Next:
```

---

## Week 24: host choice (2026-10-10)
Done: HostDef resources in data/hosts (colonist 5 hearts; pilgrim 4 hearts, faster, starts with a Bone Shard; antibody 7 hearts, slower, born with a Bone Spur) with HostDb. SpawnPoint markers in world.tscn (Flesh-Tender camp, upper corridor, cavern floor, chamber heights), each listing which host types can wake there. After "N years later", three options: different places (never the last host's when avoidable), host types, generated names; deterministic per world and death. Player.apply_host() sets health, speed and body frames; the kit only comes with a new life. LifeRecord.origin. Placeholder pilgrim (hooded) and antibody (pale, round) art shares the colonist's poses, so mutation overlays fit all three. Corpses use their host's frames. Save v9.
Not done: Host standing with factions (phase 4).
Next: Week 25, milestone 3: play 5 lives in a row and write up how the loop feels.

## Week 23: time passes (2026-10-10)
Done: D-020 (nothing carries over except through the body) and D-021 (time passes as rolled aftermath, not simulation). `Aftermath` (src/sim/history): each death rolls a gap tier (days / months / years / decades) whose strength scales the rules: bodies scavenged and mutations rotting (the newest body always keeps one thing), killed creatures replaced, dropped items rotting. Year advances; new hosts are born in the new year. `EventRecord` log in WorldData.events (host_died, corpse_scavenged, corpse_rotted, creatures_returned), the seed of phase 4 history. Death screen has a second step: "Nine years later." plus a hint. removed_entities now stores what was removed (item or creature kind). Save v8. Deterministic per world and death.
Not done: Factions adding their own aftermath rules (phase 4).
Next: Week 24, host choice on rebirth.

## Week 22: the corpse (2026-10-10)
Done: On death, everything the host carried and grew moves onto its body (LifeRecord.corpse_items / corpse_mutations, corpse_position on the floor under the death spot). The dying host gives way to a Corpse (death pose, held on its last frame, with its mutation layers). The next host wakes with nothing. E on the body takes back what fits: items into free pockets, mutations into empty slots; the rest stays. CorpseLayer shows bodies per chunk from the life records, like ItemLayer. Every old body stays; the debug map (M) marks them. Interact now works on anything with interact(). Save v7.
Fixes found by tests: the dead host stayed visible over its corpse (the death screen pauses _process).
Not done: Anything happening to bodies over time (week 23).
Next: Week 23, time passes on death.

## Weeks 20-21 (2026-10-10)
Done:
- Week 20: developer chose loose and systemic combat (D-018). Friendly fire is now the default in the world (leech bites exclude their own hurtbox). Felt rigid: base resolution 960 x 540 (D-019, exact 2x on 1080p, zoomed in), camera with vertical drag margins and softer smoothing; inventory panel resized. Phantom Camera planned by the developer.
- Week 21: LifeRecord (src/sim): generated host name, start/death year, seconds alive, death position, killer, carried items and mutations, kills by kind. WorldData.lives, start_life / end_life / record_kill. Hitbox.source -> Health.last_hit_source says who dealt each blow, so kills by creatures (friendly fire) do not count as yours. Death screen epitaph; "Wake in a new host" starts the next life (placeholder: same spot, keeps items until week 22). Save v6.
- test_lives.gd; all tests pass.
Not done: Corpse and losing your things (week 22). Years do not pass yet (week 23).
Next: Week 22, the corpse.

## Weeks 17-19 (2026-10-09)
Done:
- Week 17 (mutations v1) was already done in the UI/combat sweep.
- Week 18: abilities work on any host (player or creature) through a small interface; creatures list `innate` mutations. Bile Spitter (rooted, aims lobs with the same Acid Gland as the player, drops a Bile Bulb so you can eat its gland) and Rot Fly (hovers, stalks above you, buzzes, dives). Placeholder pixel art for both with glowing eyes and gland.
- Week 19: CombatFeel (hit sound, screen shake, hitstop), Sfx autoload with generated placeholder sounds (jump, land, swing, hit, hurt, die, pickup, eat, spit, dash, buzz). Two arenas from the main menu: tight (3 hearts, no mutations, 2 leeches + fly) and loose (8 hearts, all mutations, 2 spitters, 3 leeches, 2 flies, friendly fire: enemy acid hurts creatures). Clear time and hits taken shown; R restarts.
- Fixes: death animation looped (one-shots now hold their last frame); duplicated creatures inherited host-less ability nodes; flyers without an idle animation errored; light leaked through inner rock corners (buried edge-ring tile now blocks light).
- Tests: test_creatures, test_arenas. All pass; soak flat; render median 163 fps, no spikes.
Not done: Real sounds and art. Tuning of every number by feel.
Next: Week 20 decision (precision vs systemic) after playing both arenas. Then phase 3, death and rebirth (weeks 21-25).

## Weeks 15-16, code side (2026-10-09)
Done: Q-007 answered: layered frame animation (D-017). `SpriteSheets` builds animations from PNG strips in a folder; `LayeredSprite` plays the body plus synced overlay layers (mutations in front or behind, unshaded glow layer). Player picks idle/run/jump/fall/cling/attack/hurt/die; Gut Leech picks idle/move/windup/attack/hurt/die. Placeholder pixel art generated by script: colonist host (8 animations), its three mutation overlays matched frame for frame, Gut Leech with glowing eyes. Squash and stretch removed. ART_PIPELINE rewritten for strips and overlays. All tests pass.
Not done: The developer's own drawings (the actual art weeks).
Next: Developer draws the leech (week 15) and the host (week 16) over the placeholders. Code: weeks 17-19 (more creatures using mutations, combat feel, two test arenas).

## Week 12: Milestone 1 (2026-10-09)
Done:
- Tests live in `tests/` now: test_movement, test_world, test_saves, test_items_ui, test_combat, test_mutations (60+ checks, ~30 s), run with `tests/run_tests.sh`. Shared helpers and a play bot in test_case.gd.
- Soak test (`--soak`): bot plays 10 game-minutes headless (fixed 60 fps, ~10 s real time), teleporting every few seconds. Memory 68-72 MB with no growth, node and orphan counts bounded, no script errors, no lost or duplicated entities.
- Render test (`--render`): 60 s bot in a window. Median 7.3 ms (137 fps), p99 ~20-23 ms. The only frames over 33 ms are in the first second (first-time shader compiles), none while exploring.
- Fixed: loading a save during the 2 s death pause was overridden by the pending respawn.
Not done: the developer's own 10 minutes of play (the real "done when"). Cutting chunks on a thread (week 6) would lower p99 further; not needed yet.
Phase 1 summary: a hand-painted, streamed, persistent Gut test region with saves, items, light and atmosphere, plus early UI, combat and mutations. Next phase per roadmap: combat and creatures (weeks 13-20), much of 13-14 and 17 already done (D-016); next real work is week 15 (first rig, waits on Q-007) and week 18-19.

## Weeks 10-11: set piece, light and atmosphere (2026-10-09)
Done:
- Terrain: banded pixel-art placeholder tiles with a bright membrane on top-facing edges, plus two depth tiles (rock 2 and 3+ tiles from air) so big rock masses fade to dark. Chunk cut ~5 ms.
- Light: CanvasModulate darkness, banded player light, rock casts shadows (occluders inset from open sides, so the surface rim stays lit). Glowing fungus prop (14 placed), camp lamp, glowing items, acid globs, leech eyes; additive halos on light sources. Player body ignores lighting so it stays readable.
- Backdrop: two scrolling noise layers drawn by one full-screen shader on a CanvasLayer (Parallax2D left gaps with this camera setup).
- Atmosphere: banded vignette, drifting spores. Juice: squash and stretch, landing dust, camera look-ahead. HUD hearts. NPC names fade in when close.
- Week 10: Flesh-Tender camp set piece (scenes/setpieces), placed in world.tscn. Slots for the history sim are left for phase 4.
- Checked with real-renderer screenshots: ~130-145 FPS with shadows on. All headless checks pass.
Not done: The developer's real tile and prop art (week 11 art pass). Pixel font (needs a font file; see ART_PIPELINE).
Next: Week 12 milestone: 10 minutes of exploring without bugs or stutter.

## UI, combat, mutations sweep (2026-10-09)
Done (D-015, D-016), three commits:
- UI: main menu (startup scene), pause menu, 8-pocket inventory with details, Eat and Drop, HUD messages, GameUI pauses the game while a screen is open. Save v3.
- Combat: Health / Hitbox / Hurtbox components, damage numbers, player attack (J / left mouse / pad X), knockback and i-frames, health pips, placeholder respawn on death. Training dummy, Gut Leech state machine (idle, wander, notice, chase, attack, flee, dead). Killed placed enemies stay dead; loading rebuilds placed entities fresh. Save v4.
- Mutations: eat Bile Bulb / Bone Shard / Breath Sac to grow Acid Gland (K, spit), Bone Spur (L / Shift, damaging dash with i-frames), Lung Sac (hold jump, glide). One per body slot, replacing withers the old one. Parts appear at sockets, HUD lists controls. Save v5.
All checked headless, including saves from v1 to v4 loading.
Not done: Death keeps everything (corpse and loss are week 21-22). Enemies do not use mutations yet (week 18). No hitstop or screen shake (week 19). `src/ui/inventory_label.gd` is unused and should be deleted.
Next: Playtest the loop. Then weeks 10-12 (set pieces, light, milestone 1).

## Week 9 (2026-10-09)
Done: Items that persist (D-013). ItemDef resources in data/items (Bile Bulb, Bone Shard), WorldItem scene, ItemLayer spawns dropped items from WorldData per chunk. E picks up the nearest item, Q drops the last one. Two items hand-placed in world.tscn; picking them up is permanent. Inventory shown top right. Save version 2 with a migration from v1. Checked headless: pick up, drop, leave (nodes freed, data kept), come back, save, change things, load: exactly the saved state. v1 save loads. Pixel art decided (D-012), Nearest filter on; Q-007 and Q-008 opened.
Not done: Dropping only works on the ground (no falling items). NPC state is not saved yet. Week 8 still waits on Q-006.
Also: Q-008 answered (D-014): 32 px tiles, 1280 x 720 base, viewport stretch with pixel snapping, window opens at 1920 x 1080.
Next: Week 10 (set pieces and slots) or week 11 (light and atmosphere).

## Weeks 6-7 (2026-10-09)
Done: Week 6 skipped: cutting a chunk is ~4 ms and building is spread over frames, no hitches seen; revisit only if one appears. Week 7 tech: autotiling. Each rock cell stores its open-sides mask, which picks one of 16 tiles. Placeholder Gut atlas (flesh, membrane rim, rounded corners) and `gut_tileset.tres` with chamfered collision on outer corners. Dark background color. Tile layout documented in ART_PIPELINE.md so real art can replace the placeholder 1:1.
Not done: Painting the actual Gut (developer). Inner corners stay sharp (16-tile set, not 47).
Next: Developer paints the Gut and draws tiles. Code: week 9 (item persistence) or week 11 (light and atmosphere).

## Weeks 4-5, part 2 (2026-10-09)
Done: The map shows up in the Godot editor (D-011): `scenes/world.tscn` with a @tool MapPreview that auto-refreshes from Krita exports, a PlayerSpawn marker (replaces the red pixel), and an Entities layer whose children stream with their chunk. Four placeholder NPCs placed on the starter map. WorldMap now reads pixels lazily per chunk: an 8192 x 4096 map starts instantly (was 6.6 s). Checked: spawn, entity streaming, an NPC walking into another chunk, save/load without duplicates, no leaks at exit, editor opens world.tscn without errors.
Not done: Entity state is not saved yet (Q-006 / week 8-9). Real-GPU performance only checked by the developer.
Next: Paint a real map, place things on it. Then week 7.

## Weeks 4-5 (2026-10-09)
Done: Dropped terrain generation (D-010). The world is `data/maps/world.png`, painted in Krita, 1 px = 1 tile: dark = rock, light/transparent = air, red = spawn. `WorldMap` reads it, `ChunkManager` cuts and streams it. Starter map (256 x 128, 4 x 2 chunks): start cave, climbing chamber, wall-jump shaft, upper corridor, big cavern, loop back. F4 reloads the PNG in game, M shows a debug map. PNG imports as Image so exports work. Docs updated (VISION, ARCHITECTURE, ROADMAP weeks 4-10, ART_PIPELINE painting section).
Not done: Painted edges are blocky squares until autotiling (week 7).
Next: Paint a real map in Krita. Then week 7 or 8.

## Week 3 (2026-10-09)
Done: `WorldData` (seed, year, player position, empty `chunk_diffs` for week 8) with to_dict/from_dict. `WorldState.set_data()` emits `EventBus.world_loaded`, and the game rebuilds from it (moves the player, ChunkManager.reset() regenerates chunks from the saved seed). `SaveSystem`: versioned header, temp file + rename, no objects in saves, migration hook, clean errors for corrupt / newer / missing saves. `SeededRng.for_chunk()`. F9 quick save, F10 quick load (F5 to F8 are editor run/stop keys). Each run starts a new random world unless Game's `new_world_seed` is set. Checked headless: save, quit, reopen in a new process, load: same seed, same position, identical terrain, 9 chunks loaded.
Not done: Autosave and save slot UI (later weeks). Nothing in chunks can change yet, so chunk_diffs is always empty.
Next: Week 4, painted map reader (regions.png drives world size and regions, debug map screen).

## Week 2 (2026-10-09)
Done: Movement feel: acceleration, coyote time, jump buffer, variable jump height, heavier fall, wall cling and wall jump, all tunable in the Inspector. F3 overlay (FPS, position, velocity, chunk, floor/wall state, chunk counts; also draws chunk borders). Bonus (D-008): `game.tscn` is now a streamed 16 x 8 chunk cave world (1024 x 512 tiles), generated from a seed. Test room moved to `scenes/test_room.tscn`.
Not done: Nobody else has tried the movement yet (the "done when"). Chunk generation still runs on the main thread, ~5 ms per chunk, one per frame.
Next: Have someone play it. Then week 3: WorldData, save/load with a version number.

## Week 1 (2026-10-09)
Done: Godot 4.7 project, folder layout, empty autoloads (EventBus, WorldState, SaveSystem). Player capsule (`src/actors/player/`) runs and jumps, camera follows with smoothing. Input actions move_left / move_right / jump (A/D/arrows, Space/W/Up, gamepad). Test room in `game.tscn` on a 32 px TileSet (was slicing the placeholder sheet at Godot's default 16 px).
Not done: GameClock autoload (not needed until week 23). Room has only one tile type.
Next: Week 2, movement feel (coyote time, jump buffer, variable jump height, acceleration) and the F3 debug overlay.

## Week 0 (2026-10-09)
Done: Concept, docs, roadmap.
Not done: Godot project.
Next: Week 1 of ROADMAP.md.
