# CLAUDE.md

Project memory for Claude Code. Read this first, then the docs it points to.

## What this project is

CORPSE (working title): a 2D side-view exploration game in Godot 4.x (GDScript), made solo by a developer who is also learning to draw (drawing tablet, hand-drawn art). Inspirations: Dwarf Fortress, Caves of Qud (systems, generated history, mutations), Subnautica, No Man's Sky (exploration, depth, dread), Hollow Knight and The Binding of Isaac (sprite style).

A god fell from the sky and died. Its body is a continent. Parasite civilizations lived and died inside it for thousands of years. The player is a fragment of the god's will: on death it wakes in a new host, in a different colony, years later. The world persists and remembers.

## Where to look

- @docs/VISION.md : design, pillars, regions, systems, non-goals
- @docs/ARCHITECTURE.md : folder layout, data model, chunks, saves, history sim
- @docs/ROADMAP.md : 104-week plan with "done when" criteria per week
- docs/ART_PIPELINE.md : drawing, cutout rigs, mutation socket names
- docs/DECISIONS.md : decision log and open questions
- docs/DEVLOG.md : weekly progress notes

## How we got here (summary of the planning conversation)

1. Started from "fun to make, fun to play, possibly big, proc gen or a large handmade world". Developer likes both deep systems (DF, Qud) and exploration (NMS, Subnautica).
2. First chose a hybrid world (painted layout + generated detail), then dropped generation entirely (D-010): the whole world is painted by hand in Krita as `data/maps/world.png`, one pixel = one tile. Same world every playthrough; history is what differs per save.
3. Chose 2D over 3D: 3D asset production would eat the time meant for systems.
4. Art: hand-drawn with the tablet, simple bold style (closer to Isaac than Hollow Knight in detail), animated as cutout rigs (Skeleton2D + AnimationPlayer). Mutations attach to the rig as body parts, so hosts visibly transform without redrawing.
5. Considered an underwater setting, dropped it (floaty controls, Subnautica comparisons). Kept its structure: descend through layers, deeper means older and stranger.
6. Setting: the corpse of a god. Regions are organs: Wound (entry), Gut (vertical slice), Lungs, Bones, Nerves, Heart (final boss). Blood vessels are fast travel and hazards. The body still twitches, rots, whispers.
7. Structure: persistent world with rebirth, NOT a reset roguelite. On death: life recorded, history sim advances years, old corpse stays and factions decide its fate (looted, eaten, enshrined, studied), player picks a new host in a different colony.
8. Player identity: all three ideas combined. Hosts can be parasite-born colonists, surface pilgrims, or things the corpse grew.
9. Reputation has two layers: host standing (this body, fresh each life) and legend standing (the fragment, across lives; only fragment-sensing factions like priests react directly, others hear rumors). Numbers hidden, consequences visible.
10. Goals across lives: find your old body, collect valve keys that seal the heart (held by regions/factions, can be stolen between lives), reach the heart. Who controls the heart decides the final fight. Endings: kill the god, revive it, take its place.
11. Combat: real-time, side-view, one tool among several (sneak, talk, bribe, eat, graft). Difficulty style (precision vs systemic) is open, decide in week 20.

## Rules for working in this repo

- **The simulation never touches nodes.** Sim = plain data (RefCounted/Resource). World layer turns data into chunks. Presentation = nodes. See ARCHITECTURE.md.
- No procedural terrain (D-010). The world is `data/maps/world.png`, read by `WorldMap`. Repeatable randomness (history, loot) uses `SeededRng`, never global `randi()`.
- Save diffs, never generated content. Version every save, write migrations, never break old saves silently.
- Refer to things by ID, not object references, in sim data.
- Snake_case files, PascalCase `class_name`. Keep autoloads under ~300 lines.
- Follow the roadmap week by week. A week is done when its "done when" is true.
- Placeholder art is fine until a roadmap art week says otherwise.
- Before changing direction, add an entry to docs/DECISIONS.md.
- After each work session, add a short entry to docs/DEVLOG.md (done / not done / next).
- Prefer small, playable steps. Explain Godot concepts briefly when introducing them; the developer is learning.

## Current status

Weeks 1 and 2 built: player with tuned movement and wall cling, F3 overlay, test room (`scenes/test_room.tscn`). Week 2 still needs an outside playtester.

Week 3 built: `WorldData` (src/sim), `WorldState.set_data()` -> `EventBus.world_loaded` -> `src/game.gd` moves the player and calls `ChunkManager.reset()`. `SaveSystem` writes versioned saves (F9 save, F10 load).

Weeks 4 and 5 built (D-010): `WorldMap` (src/world/world_map.gd) reads `data/maps/world.png` (1 px = 1 tile), `ChunkManager` cuts it into 64 x 64 `ChunkData` and streams one TileMapLayer per chunk (3 x 3 around the player). F4 reloads the map, M shows the debug map.

D-011: `scenes/world.tscn` is the authoring scene: `MapPreview` (@tool) shows world.png in the editor, `PlayerSpawn` marker, `Entities` (`EntityLayer`) holds hand-placed NPCs/props that stream with their chunk. Placeholder NPC: `src/actors/npcs/placeholder_npc.tscn`. Next: developer paints a real map; then ROADMAP week 7 (paint the Gut, autotiling) or week 8 (breakable tiles, chunk diffs).

Headless testing: `Godot_v4.7.2-stable_win64.exe --headless --path . --script <test.gd>` works. In such a test script, do not type variables as classes that use autoloads (e.g. `ChunkManager`), and reach autoloads via `root.get_node("/root/Name")`: the script compiles before autoloads exist.
