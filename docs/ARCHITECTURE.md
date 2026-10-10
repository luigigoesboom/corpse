# Architecture

This is the plan, not the law. When the code disagrees with this file, either fix the code or update this file and log it in DECISIONS.md.

## The one rule

**The simulation never touches nodes.**

There are three layers:

| Layer | What lives here | Knows about |
|---|---|---|
| **Sim** | World state, factions, history, reputation, life records, chunk diffs. Plain GDScript classes (RefCounted / Resource). | Nothing below it. |
| **World** | Turning the painted map and sim data into chunks: streaming, applying diffs, spawning entities. | Sim. |
| **Presentation** | Nodes, scenes, rigs, UI, audio, camera. | Sim (read) and World. Writes to the sim only through clear functions or EventBus signals. |

Why: the whole body keeps "existing" when you are not looking, and history runs for thousands of years at worldgen. That only works if world state is plain data you can tick, save and inspect without spawning anything. This is the lesson from Dwarf Fortress.

## Folder layout

```
corpse/
  project.godot
  README.md
  docs/
  data/
    maps/            world.png, the hand-painted world (1 px = 1 tile)
    factions/        faction definitions (.tres)
    items/           ItemDef resources (.tres), one per item kind
    mutations/       MutationData resources (.tres)
    names/           word lists for name generation
  assets/
    art/
      tiles/
      creatures/     one folder per creature, parts as separate PNGs
      hosts/
      mutations/
      props/
      ui/
    audio/
    fonts/
  src/
    autoload/        EventBus, WorldState, SaveSystem, GameClock
    sim/
      world_data.gd
      life_record.gd
      history/       history sim, event log, event types
      factions/
      reputation/
    world/
      chunks/        chunk manager, chunk data, streaming
      setpieces/     detailed rooms built as Godot scenes, placed on the map
      world_map.gd   reads the painted world PNG
    actors/
      components/    health, hitbox, hurtbox, ai state machine
      player/
      creatures/
      npcs/
    items/           ItemDef, ItemDb, WorldItem, ItemLayer
    mutations/       MutationDef, MutationDb, MutationHost, MutationAbility, abilities/
    ui/
    debug/           overlays, debug map, cheat console
  scenes/            top-level scenes (main, menus)
  tests/             optional unit tests for sim code
```

Naming: `snake_case` for files and folders, `PascalCase` for `class_name`.

## Autoloads

| Name | Job |
|---|---|
| `EventBus` | Global signals only. `player_died`, `deed_recorded`, `chunk_loaded`, `faction_standing_changed`. No logic. |
| `WorldState` | Holds the current `WorldData`. Single source of truth for the sim. |
| `SaveSystem` | Serializes `WorldData` to `user://` and back. Owns versioning and migration. |
| `GameClock` | Current year, in-life time, triggers time skips. (Not created yet.) |
| `Sfx` | Sound effects; `Sfx.play(&"hit", position)`. Plays assets/audio/sfx/<name>.wav if present (copied from the licensed pack by tools/copy_sfx.sh, not in git), else a sound generated in code. |

Keep autoloads small. If one passes 300 lines, split it.

## Data model (first version)

```gdscript
# src/sim/world_data.gd
class_name WorldData
extends RefCounted

var save_version: int = 1
var world_seed: int
var year: int

var factions: Dictionary = {}        # faction_id -> FactionData
var sites: Dictionary = {}           # site_id -> SiteData (settlements, ruins, shrines)
var figures: Dictionary = {}         # figure_id -> FigureData (notable people, including past hosts)
var artifacts: Dictionary = {}       # artifact_id -> ArtifactData
var events: Array = []               # EventRecord, append only
var lives: Array = []                # LifeRecord, one per host the player has had
var chunk_diffs: Dictionary = {}     # Vector2i -> ChunkDiff
var legend: Dictionary = {}          # faction_id -> legend standing
```

```gdscript
# src/sim/life_record.gd
class_name LifeRecord
extends RefCounted

var host_type: StringName
var start_year: int
var death_year: int = -1
var death_chunk: Vector2i
var death_position: Vector2
var carried_items: Array = []
var carried_mutations: Array = []
var deed_event_ids: Array = []       # links into WorldData.events
var corpse_state: StringName = &"intact"   # intact, looted, eaten, enshrined, studied
```

Implemented (week 21): `LifeRecord` as above plus `host_name`, `seconds_alive` and `kills` (creature kind -> count). `WorldData.lives` holds them; the last one is the current host while alive.

Everything refers to other things by ID, never by object reference. That keeps saves simple and lets history point at anything.

## The painted world

The whole world is painted by hand (D-010). There is no terrain generation.

`data/maps/world.png`: **one pixel = one tile.** `WorldMap` (src/world/world_map.gd) reads it once and classifies every pixel:

| Pixel | Meaning |
|---|---|
| Transparent, or light (white, light grey) | Open space |
| Dark (black, dark grey) | Rock |

Colors are matched loosely (dark vs light), so soft brush edges still work. Outside the image is rock. Pixels are only read when a chunk is cut, so startup does not grow with map size (an 8192 x 4096 map starts instantly, ~4 ms per chunk).

### The world scene

`scenes/world.tscn` is where the world is authored in the editor, on top of the painting:

| Node | Job |
|---|---|
| `MapPreview` | `@tool`: draws world.png at real size (rock colored, air transparent) with a chunk grid, in the editor only. Polls the PNG's modified time and refreshes. Frees itself at runtime. |
| `PlayerSpawn` | Marker2D. Where a fresh game puts the player. |
| `Entities` (`EntityLayer`) | Hand-placed NPCs, props, items. At runtime each child is bucketed by chunk and only kept in the tree while that chunk is loaded (detached otherwise: keeps state, costs nothing). Things that move are re-bucketed when their chunk unloads. |

`game.tscn` instances world.tscn next to the ChunkManager and Player. Later, when entity state must survive saves (a dead NPC stays dead), it goes into `WorldData` keyed by the entity's node name under Entities, which must therefore stay unique and stable. More colors (acid, flesh, one-way platforms, markers for set pieces and colonies) get added to this table as they are needed. How to paint it: docs/ART_PIPELINE.md, "Painting the world".

The PNG is imported as an **Image** (not a texture) via its `.import` file, so the pixels stay exact and exported builds can read it. In the editor, `WorldMap` reads the PNG straight from disk instead, so F4 in game picks up a fresh save from Krita without restarting.

Later, regions (Gut, Lungs...) and depth can be extra painted layers at the same resolution, or a coarser one.

The history sim does not invent places on the map. It fills hand-made slots (a painted marker or set piece: "a colony could be here", "a shrine could be here") with whatever its story produced.

## Chunks

- Chunk size: 64 x 64 tiles. Tile size: 32 px (revisit after the first art week).
- Each loaded chunk is a `Node2D` with its own `TileMapLayer` and an entity container.
- Load radius: 1 chunk each way (3 x 3). One chunk is 2048 px, much wider than the screen.
- Only rock tiles next to open space get collision. Buried rock uses a tile with no collision shape.

### Randomness

Anything random that must be repeatable (history events, loot rolls tied to a place) uses a seeded RNG from `SeededRng` (src/sim/seeded_rng.gd), never the global `randi()`. The global RNG depends on what ran before, so results would change with load order.

### Streaming

1. Player crosses into a new chunk.
2. Chunk manager works out which chunks should be loaded.
3. For each missing chunk, cut its tiles out of the WorldMap as plain data (`ChunkData`), no nodes. If this gets slow, move it to a worker thread (`WorkerThreadPool.add_task`).
4. Back on the main thread, apply the chunk's diff, then build the `TileMapLayer` a few hundred cells per frame.
5. Attach the hand-placed entities of that chunk (`EntityLayer`).
6. Unloading writes entity state back to the chunk diff, then frees the node.

### Diffs, not snapshots

Current format (D-013), in `WorldData.chunk_diffs[chunk]`:

```gdscript
{ "items": [ { "id": 12, "item": &"bile_bulb", "pos": Vector2(1624, 3200) } ] }
```

Runtime things are created in `WorldData` first (`add_dropped_item()`), and the matching node is only a view, spawned by `ItemLayer` when the chunk loads and freed when it unloads. Permanent changes to hand-placed things in world.tscn go into `WorldData.removed_entities` (node name -> true). Empty chunk entries are erased so saves stay small.

Original plan, kept for reference. The painted map is never saved, it ships with the game. Only changes to it are:

```gdscript
class_name ChunkDiff
extends RefCounted

var removed_cells: Dictionary = {}   # Vector2i -> true
var placed_cells: Dictionary = {}    # Vector2i -> Vector2i (atlas coords)
var entities: Array = []             # serialized entity dictionaries
var rot_level: float = 0.0
```

Load = cut the chunk from the painted map, then apply its diff. This keeps saves small even with a huge world.

## Saving

- File: `user://saves/slot_N.save`
- Format: `FileAccess.store_var()` with a header dictionary containing `save_version`. Do not use `full_objects = true`, it lets a save file run code.
- Convert sim classes to dictionaries with `to_dict()` / `from_dict()` on each class.
- When the format changes, bump `save_version` and add a migration step in `SaveSystem`. Never break old saves silently.
- Write to a temp file, then rename, so a crash mid-save cannot corrupt the slot.

## Factions (week 26)

Two halves, like items and mutations:

| Part | Where | What |
|---|---|---|
| `FactionDef` | data/factions/*.tres (src/sim/factions) | What a faction is, by hand: name, member name, creed, color, value tags, temperament (aggression, expansion, piety, trade, senses_fragment), starting strength, relations to other factions, attitude per host type. Looked up with `FactionDb`. |
| `FactionData` | `WorldData.factions` (id -> FactionData) | What it has now: strength (0 = gone), territory (chunks), relations, founded_year. Saved; history changes it. |

Starting territory is painted: `data/maps/territory.png`, same size as world.png, each faction's land in its color. `FactionTerritory` (src/world) reads it when a world starts (or an old save without factions loads): a chunk goes to the faction with the most paint in it, if that is at least 10% of the chunk. Relations start mutual (the average of what both defs say). `WorldData.faction_at(chunk)`, `relation(a, b)`, `set_relation(a, b, v)` (mutual, clamped to -100..100). NPCs have a `faction` id. The debug map (M) tints territory and lists each faction. Loop over factions with `FactionDb.all_ids()` (alphabetical), never over Dictionary keys of defs, so history stays repeatable.

## History sim

Two speeds, same code:

| Mode | When | Span | Detail |
|---|---|---|---|
| Worldgen | New world | ~2000 years | Coarse: factions found sites, war, decline. |
| Between lives | On death | 5 to 50 years | Finer: specific NPCs, your corpse, reactions to your deeds. |

Each tick:

1. Each faction acts based on its traits and situation (grow, expand, trade, attack, schism, worship).
2. Body systems tick (rot spread, spasms).
3. Every meaningful change becomes an `EventRecord`:

```gdscript
class_name EventRecord
extends RefCounted

var id: int
var year: int
var type: StringName                 # founded_site, war_declared, site_ruined, corpse_enshrined...
var actors: Array = []               # faction_ids or figure_ids
var site_id: int = -1
var data: Dictionary = {}            # type-specific details
```

Text is generated from events when shown (murals, rumors, artifact descriptions), not stored. That way you can improve the writing later and old saves get better text too.

## Death and rebirth flow

Current version (weeks 21-23, D-021): `end_life()` closes the LifeRecord and moves pockets and mutations onto the body; the epitaph shows; `Aftermath.run()` rolls a time gap tier and applies its rules to WorldData at that strength (no year-by-year simulation); EntityLayer rebuilds and chunks reload so the changes show; "N years later" with a hint; the next host starts. Factions will add their own aftermath rules in phase 4.

Original plan:

1. `player_died` on EventBus.
2. Finish the current `LifeRecord`, record a death event.
3. Turn the player's body into a `Corpse` entity in the chunk diff, with carried items and mutations.
4. `GameClock` picks the time skip length.
5. History sim runs in "between lives" mode. Factions near the corpse decide its fate.
6. Rebirth screen offers 3 hosts from different colonies, based on current world state.
7. New `LifeRecord`, spawn, autosave.

## Reputation

```
standing(faction, player) =
    host_standing[faction]                   # this body only
  + legend_standing[faction] * senses(faction)  # the fragment, if they can sense it
```

`senses` is 1.0 for priests, nerve-dwellers and heart factions, 0.0 for most others. Rumors can slowly move host standing for non-sensing factions when your current host matches a known description.

## Mutations

Current implementation (D-015): `MutationDef` resources in data/mutations (id, slot, ability script, placeholder polygon). `ItemDef.grants_mutation` makes an item edible. `WorldData.mutations` (slot -> id) is the truth; `MutationHost` on the player rebuilds parts (at `Visual/Sockets/socket_<slot>`) and ability nodes from it. The player calls each ability's `physics_tick()` after its own movement and before `move_and_slide()`, so abilities can change `player.velocity`.

Original plan:

- `MutationData` is a Resource: id, display name, part scene, socket name, ability script, stat changes, which regions it can come from.
- Grafting = instance the part scene, attach to the named socket on the host rig, add the ability node to the player.
- Creatures use the exact same system, so any creature mutation can in theory be taken by the player.

## Debug tools (build them early, they pay back fast)

- F3 overlay: FPS, position, chunk coord, region, rot, year.
- Debug map: painted map with loaded chunks, player, sites, corpses.
- History log viewer: scroll the event log in game.
- Console: `teleport x y`, `skip_years n`, `give_mutation id`, `kill_player`.

## Testing

Sim code is plain data, so it is easy to test. Optional: the GUT addon from the Godot Asset Library. Good first tests: same seed produces same chunk, save and load round-trip, history sim does not crash over 5000 years.
