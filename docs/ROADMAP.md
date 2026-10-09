# Roadmap

## Assumptions

- About 12 to 15 hours a week. If you have more, weeks finish early. If you have less, stretch them, do not cut the "done when" criteria.
- Godot 4.x, GDScript, solo.
- You are learning to draw as you go. Art tasks are spread out on purpose so they never block code.
- Total: 104 weeks (about two years). The first 44 weeks are planned in detail. Later phases are planned per week but will change after the vertical slice tells you what is fun. Re-plan at every milestone.

## Rules for using this plan

1. Every week has a **Done when**. A week is done when that is true, not when the time is up.
2. Placeholder art (grey boxes, scribbles) is fine until a week says otherwise.
3. If a week runs over, borrow from the next milestone week. Milestone weeks are buffers on purpose.
4. Write three lines in DEVLOG.md every week. Done, not done, next.
5. When you change direction, write it in DECISIONS.md first.

## Overview

| Phase | Weeks | Result |
|---|---|---|
| 0. Foundations | 1 to 4 | A character moving in a saved, seeded test world driven by a painted map |
| 1. The world | 5 to 12 | A streamed, persistent, generated Gut region with lighting and set pieces |
| 2. Combat and creatures | 13 to 20 | Fighting rigged creatures, grafting the first mutations |
| 3. Death and rebirth | 21 to 25 | The core loop: die, time passes, corpse persists, new host |
| 4. Factions and history | 26 to 36 | Generated history, two factions, reputation, dialogue, ruins |
| 5. Vertical slice | 37 to 44 | One complete, polished region you can show people |
| 6. Expansion | 45 to 76 | Lungs, Bones, Nerves, Wound, body systems |
| 7. The heart | 77 to 86 | Valve keys, heart region, final boss, endings |
| 8. Polish and release | 87 to 104 | Balance, performance, demo, launch |

---

## Phase 0: Foundations (weeks 1 to 4)

| Week | Goal | Done when |
|---|---|---|
| 1 | Project setup. Create the Godot project in this repo, folder layout from ARCHITECTURE.md, empty autoloads (EventBus, WorldState, SaveSystem). Player capsule with run and jump on a hand-placed TileMapLayer. Camera follows. | You can run and jump around a test room. First commit pushed. |
| 2 | Movement feel. Coyote time, jump buffering, variable jump height, acceleration curves, a simple wall cling or ledge grab (pick one). Debug overlay (F3) showing position, velocity, FPS, chunk coord. | Moving feels good with a grey box. Ask someone else to try it. |
| 3 | Data layer and saves. WorldData class (seed, year, player position). Seeded RNG helper per chunk. Save and load with a version number in the file. | Save, quit, reopen, load: player is where they were. Same seed gives same numbers. |
| 4 | Painted map reader. Load `data/maps/regions.png`, map colors to region IDs, one pixel = one chunk. Debug screen that draws the region map with the player's position on it. | Repaint the PNG in Krita, reload, and the debug map changes. |

## Phase 1: The world (weeks 5 to 12)

| Week | Goal | Done when |
|---|---|---|
| 5 | Chunk system. Chunk coords, generate a chunk's tiles from its region + noise, load chunks in a radius around the player, unload outside it. | You can walk across 20+ chunks and memory stays flat. |
| 6 | Threaded loading. Generate chunk data off the main thread, build TileMapLayers on the main thread in small batches. | No visible hitch when crossing chunk borders. |
| 7 | Gut terrain. Cave shapes from noise plus cellular automata smoothing, guaranteed connectivity between neighbor chunks (shared border openings). Gut-specific tile set (placeholder). | Gut tunnels look organic and you never hit a dead seam at a chunk edge. |
| 8 | Persistence of changes. Breakable tiles. Store only diffs per chunk, apply diffs after generation. | Break a wall, walk far away, come back, save and load: the wall is still broken. |
| 9 | Entities in chunks. Items and simple props live in chunk data, spawn when chunk loads, write back when it unloads. | Drop an item, leave, come back after a save and load: it is there. |
| 10 | Set pieces. A second painted layer `markers.png` where special colors mean "place authored room X here". Authored scenes get stamped into generated terrain. | Two hand-made rooms appear exactly where you painted them, blended into the caves. |
| 11 | Light and atmosphere. CanvasModulate darkness, player light, glowing fungus props, simple parallax background layer. First art pass: draw 5 Gut tiles and 3 props for real. | A screenshot of the Gut looks moody, even with rough art. |
| 12 | **Milestone 1.** Bug fixing, cleanup, performance check, write DEVLOG summary. | You can explore a big Gut region for 10 minutes without bugs or stutter. |

## Phase 2: Combat and creatures (weeks 13 to 20)

| Week | Goal | Done when |
|---|---|---|
| 13 | Components. Health, Hitbox, Hurtbox as reusable nodes. Player basic melee attack. Damage numbers or flash for debug. | Player can hit a training dummy and the dummy dies. |
| 14 | Enemy AI. Small state machine: idle, wander, notice, chase, attack, flee. One grey box enemy. | An enemy finds you, fights you, and runs when hurt. |
| 15 | **Art week: first rig.** Draw one Gut creature in separate parts, rig it with Skeleton2D and AnimationPlayer: idle, move, attack, hurt. Follow ART_PIPELINE.md. | The grey box enemy is replaced with your rigged creature. |
| 16 | Player rig with sockets. Draw and rig the first host body. Named sockets (Marker2D on bones) where mutations will attach. | Player is drawn and animated, sockets visible in debug. |
| 17 | Mutation system v1. MutationData resource (part scene, socket, ability, stats). Three mutations: acid gland (ranged spit), bone spur (dash attack), lung sac (slow fall / float). | Grafting a mutation adds the part to your body and the ability works. |
| 18 | Enemies use mutations too. Two more creature types built from the same system. | Three creature types, one of them using a mutation you can also get. |
| 19 | Combat feel. Hitstop, knockback, screen shake, invulnerability frames, placeholder sounds. Build two test arenas: one tight and punishing, one loose and systemic. | Both versions are playable. |
| 20 | **Milestone 2.** Decide combat difficulty (precision vs systemic) after playing both. Log in DECISIONS.md. | Decision written. Fighting through the Gut is fun for 10 minutes. |

## Phase 3: Death and rebirth (weeks 21 to 25)

This is the heart of the game. It comes before factions so everything after is built around it.

| Week | Goal | Done when |
|---|---|---|
| 21 | Life records. LifeRecord data (host type, start year, death year, death place, carried mutations and items, deeds list). Death screen showing the life summary. | Dying shows a summary and the record is saved. |
| 22 | The corpse. On death, spawn a Corpse entity in the world with the carried items and mutations. Walking up to it lets you reclaim them. | Die, respawn, walk back, reclaim your stuff. |
| 23 | Time skip v1. Advance the world year by a random amount. Simple world changes: rot spreads in a few chunks, item decay, corpse fate rolled randomly (stays, looted, moved). | After death, the world is visibly a bit different. |
| 24 | Host choice. Rebirth screen offering 3 hosts at different spawn points, with different starting bodies. | You pick a host and start in a different colony. |
| 25 | **Milestone 3.** Play 5 lives in a row. Note what feels good and what feels like busywork. | Write a one-page DEVLOG entry about how the loop feels. |

## Phase 4: Factions and history (weeks 26 to 36)

| Week | Goal | Done when |
|---|---|---|
| 26 | Faction data. Two Gut factions with beliefs, attitudes, territory. Suggested: the Flesh-Tenders (farmers who cultivate the gut lining) and the Choir of Waking (theocracy waiting for the god to rise). | Factions exist as data and show on the debug map. |
| 27 | Settlements. Colony set pieces built from faction data, with NPCs that idle, walk and work. | Walking into a colony feels like a place with people. |
| 28 | History sim v1, text only. Yearly ticks: factions grow, found sites, trade, fight, split, decline. Writes to an event log. Run 2000 years at worldgen. | Reading the generated log is interesting. Run it 5 times, get 5 different stories. |
| 29 | History into the world. Dead settlements become ruins placed in the Gut. Artifacts get generated names and descriptions from events. | You find a ruin and an artifact whose description matches the log. |
| 30 | Dialogue v1. Talk to NPCs: greetings by faction and standing, rumors pulled from recent events, simple barter. | NPCs mention things that actually happened in your world. |
| 31 | Host standing. Per-faction standing for the current host. Visible consequences: prices, hostility, guards refusing entry. | Attacking a Flesh-Tender makes their colony hostile. |
| 32 | Legend standing. Deeds from LifeRecords add to the fragment's legend. Fragment-sensing NPCs (Choir priests) recognize you across lives. | A priest reacts to something you did two lives ago. |
| 33 | Corpse fate driven by factions. Instead of random rolls, nearby factions decide: loot, eat, enshrine, study. | You find your old body in a Choir shrine. |
| 34 | Murals and lore objects. Readable history pieces generated from the event log, placed in ruins and settlements. | You can piece together a faction's past from what you find. |
| 35 | Non-combat options. Sneaking (light and noise), bribing, eating corpses or matter to gain small things. | You can get past a guarded area without fighting, two different ways. |
| 36 | **Milestone 4.** Bug fixing. Run the between-lives sim at higher detail (fewer years, more events). | The world after 5 lives feels shaped by what you did. |

## Phase 5: Vertical slice (weeks 37 to 44)

Goal: one region, complete and polished enough to show strangers.

| Week | Goal | Done when |
|---|---|---|
| 37 | Gut valve key. The first heart key, guarded by a mini-boss or held by a faction depending on history. | The key can be earned in at least two different ways. |
| 38 | Mini-boss. One rigged boss with 2 phases. | The boss is beatable and readable. |
| 39 | Art pass 1. Replace all remaining placeholders in the Gut. Consistent palette. | No grey boxes anywhere in the Gut. |
| 40 | Audio pass. Ambience per area, creature sounds, UI sounds. Free libraries or self-recorded. | The Gut sounds alive and gross. |
| 41 | UI and menus. Main menu, pause, settings (volume, keybinds, fullscreen), save slots. | A stranger can start, play and quit without help. |
| 42 | Onboarding. Teach movement, combat, death and rebirth without text walls. | A new player understands rebirth within their first death. |
| 43 | Playtests. 3 to 5 people, watch them play, do not explain. Write down where they get lost or bored. | Notes from every tester in DEVLOG. |
| 44 | **Milestone 5: Vertical slice done.** Fix the worst problems from playtests. Honest review: is it fun? Re-plan phases 6 to 8. | You would be happy showing this to anyone. |

---

## Phase 6: Expansion (weeks 45 to 76)

Each region follows the same six-week template. Adjust per region after the slice.

**Region template:**
1. Paint the region on the maps, write its terrain generator.
2. Set pieces and landmarks.
3. Creatures (two or three new rigs, one week of art).
4. Faction for the region, hooked into the history sim.
5. Region mutations and the region's valve key.
6. Region signature system and polish.

| Week | Goal | Done when |
|---|---|---|
| 45 | Steam page and a short GIF capture setup. Start a public devlog if you want one. | Store page draft exists (publishing can wait). |
| 46 | Refactor anything the slice proved fragile, especially save format and chunk code. | Save files from before the refactor still load (migration works). |
| 47 | Lungs: maps and terrain (huge open chambers, membranes). | You can explore the Lungs. |
| 48 | Lungs: set pieces. | Landmarks placed. |
| 49 | Lungs: creatures. | Three new creatures. |
| 50 | Lungs: faction (suggested: wind-riders who navigate breath cycles). | Faction in history and settlements. |
| 51 | Lungs: mutations and valve key. | Key obtainable. |
| 52 | Lungs: breath cycle system (winds on a timer change traversal). Polish. | Wind changes how you move through the region. |
| 53 | Bones: maps and terrain (mineral, mines, ossified cities). | Explorable. |
| 54 | Bones: set pieces. | Landmarks placed. |
| 55 | Bones: creatures. | Three new creatures. |
| 56 | Bones: faction (suggested: bone-carvers selling divine marrow). | In history and settlements. |
| 57 | Bones: mutations and valve key. | Key obtainable. |
| 58 | Bones: mining and collapsing marrow tunnels. Polish. | Mining works and collapses persist. |
| 59 | Nerves: maps and terrain. | Explorable. |
| 60 | Nerves: set pieces. | Landmarks placed. |
| 61 | Nerves: creatures and ghosts of past events (pulled from the event log). | Ghosts replay real history. |
| 62 | Nerves: faction (suggested: listeners who speak for the god). | In history and settlements. |
| 63 | Nerves: mutations and valve key. | Key obtainable. |
| 64 | Nerves: whispers system (the god's voice guides, lies, tempts). Polish. | Whispers react to your legend. |
| 65 | The Wound: rebuild the entry region properly as the start of the game. | A new player's first 15 minutes are good. |
| 66 | Blood vessels v1: currents connecting regions. | You can ride a current from the Gut to the Lungs. |
| 67 | Blood vessels v2: currents as hazards, vessel creatures. | Currents are both useful and dangerous. |
| 68 | Spasms: rare events that reshape chunks, written into diffs and history. | A spasm collapses a tunnel and NPCs talk about it. |
| 69 | Rot system v2: rot spreads between lives and changes biomes. | Rot visibly moves across lives. |
| 70 | Cross-region history: factions migrate and war across regions. | Gut factions can end up in the Lungs. |
| 71 | Legend v2: songs, statues, bounties about you. | Your past lives show up in the world in at least three forms. |
| 72 | Host types v2: surface pilgrims and corpse-grown hosts play differently. | Three host types with different starts and standings. |
| 73 | Mutation balance pass, 20+ mutations total. | Every mutation has a reason to pick it. |
| 74 | Performance pass across the full body. | Stable framerate on a mid-range PC everywhere. |
| 75 | Full playthrough of everything so far, notes. | DEVLOG entry with a ranked problem list. |
| 76 | **Milestone 6.** Fix the top of the problem list. | All regions except the heart are complete. |

## Phase 7: The heart (weeks 77 to 86)

| Week | Goal | Done when |
|---|---|---|
| 77 | Valve system: the heart opens only with all keys, keys can be stolen by factions between lives. | Collecting keys is a cross-life goal that can be disrupted. |
| 78 | Heart region terrain and set pieces. | Explorable. |
| 79 | Heart control: history decides who holds the heart (cult, fortress, untouched). | Three heart states exist. |
| 80 | Final boss design and art. | Boss drawn and rigged. |
| 81 | Final boss phase 1 and 2. | Playable. |
| 82 | Final boss variations per heart state. | Each heart state changes the fight. |
| 83 | Ending: kill the god. | Ending plays. |
| 84 | Ending: revive the god. | Ending plays. |
| 85 | Ending: take its place. | Ending plays. |
| 86 | **Milestone 7.** Full start-to-finish run. | The game can be finished. |

## Phase 8: Polish and release (weeks 87 to 104)

| Week | Goal | Done when |
|---|---|---|
| 87 | Balance pass: difficulty curve across regions. | No region is a wall or a walkover. |
| 88 | Balance pass: economy and reputation. | Standing changes feel fair and readable. |
| 89 | Art pass: weakest areas. | No region looks unfinished. |
| 90 | Art pass: UI, icons, title screen. | Menus look like the same game. |
| 91 | Audio pass: music or ambient score. | Each region has its own sound. |
| 92 | Accessibility: remappable controls, gamepad, text size, screen shake toggle. | All options work. |
| 93 | Save robustness: autosave, backup slot, corruption handling. | Killing the game mid-save never loses more than a few minutes. |
| 94 | Demo build: the Gut region. | Demo exported and tested on a clean PC. |
| 95 | Closed playtest round, 10+ people. | Feedback collected. |
| 96 | Fix playtest problems. | Top issues fixed. |
| 97 | Fix playtest problems, continued. | Second round of fixes. |
| 98 | Trailer capture and edit. | Trailer done. |
| 99 | Store page final, screenshots, description. | Page ready. |
| 100 | Release candidate build. | Feature freeze. |
| 101 | Bug bash. | No known crash bugs. |
| 102 | Bug bash, platform checks. | Builds work on target platforms. |
| 103 | Launch prep: patch notes, press kit, community posts. | Everything scheduled. |
| 104 | **Release.** | Shipped. |
