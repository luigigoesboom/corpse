# Architecture

This is the plan, not the law. When the code disagrees with this file, either fix the code or update this file and log it in DECISIONS.md.

## The one rule

**The simulation never touches nodes.**

There are three layers:

| Layer | What lives here | Knows about |
|---|---|---|
| **Sim** | World state, factions, history, reputation, life records, chunk diffs. Plain GDScript classes (RefCounted / Resource). | Nothing below it. |
| **World** | Turning sim data into chunks: generation, streaming, applying diffs, spawning entities. | Sim. |
| **Presentation** | Nodes, scenes, rigs, UI, audio, camera. | Sim (read) and World. Writes to the sim only through clear functions or EventBus signals. |

Why: the whole body keeps "existing" when you are not looking, and history runs for thousands of years at worldgen. That only works if world state is plain data you can tick, save and inspect without spawning anything. This is the lesson from Dwarf Fortress.

## Folder layout

```
corpse/
  project.godot
  README.md
  docs/
  data/
    maps/            painted PNG layers (regions, markers, depth)
    factions/        faction definitions (.tres)
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
      gen/           region generators, noise, cellular automata
      setpieces/     authored rooms stamped into terrain
      map_reader.gd  reads painted PNG layers
    actors/
      components/    health, hitbox, hurtbox, ai state machine
      player/
      creatures/
      npcs/
    mutations/
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
| `GameClock` | Current year, in-life time, triggers time skips. |

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

Everything refers to other things by ID, never by object reference. That keeps saves simple and lets history point at anything.

## The painted maps

The macro world is drawn by hand. Generation fills it in.

| File | Meaning of a pixel |
|---|---|
| `data/maps/regions.png` | Which region a chunk belongs to (Gut, Lungs, Bones...). One color per region. |
| `data/maps/markers.png` | Special colors place set pieces or force features (vessel entrance, valve chamber). Transparent means nothing. |
| `data/maps/depth.png` | Grayscale "age". Darker means older and stranger. Feeds creature tiers, ruin age, rot. |

**One pixel = one chunk.** A 128 x 256 map is 32,768 chunks, which is plenty.

Import settings matter: select each map PNG in Godot, set **Compress Mode: Lossless**, turn **Mipmaps** off, then reimport. Lossy compression changes colors and breaks the lookup.

```gdscript
# src/world/map_reader.gd
class_name MapReader
extends RefCounted

const REGION_COLORS := {
    Color("8c2828"): &"gut",
    Color("c8a0aa"): &"lungs",
    Color("e6dcbe"): &"bones",
    Color("5078c8"): &"nerves",
}

var _regions: Image

func _init() -> void:
    _regions = load("res://data/maps/regions.png").get_image()

func region_at(chunk: Vector2i) -> StringName:
    if chunk.x < 0 or chunk.y < 0 or chunk.x >= _regions.get_width() or chunk.y >= _regions.get_height():
        return &"void"
    var c := _regions.get_pixelv(chunk)
    for key in REGION_COLORS:
        if c.is_equal_approx(key):
            return REGION_COLORS[key]
    return &"void"
```

## Chunks

- Chunk size: 64 x 64 tiles. Tile size: 32 px (revisit after the first art week).
- Each loaded chunk is a `Node2D` with its own `TileMapLayer` and an entity container.
- Load radius around the player: start with 2 chunks each way, tune later.

### Determinism

A chunk must always generate the same way from the same seed. Each chunk gets its own RNG:

```gdscript
static func chunk_rng(world_seed: int, chunk: Vector2i) -> RandomNumberGenerator:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash([world_seed, chunk.x, chunk.y])
    return rng
```

Never use the global `randi()` in generation code. It makes generation depend on load order.

### Streaming

1. Player crosses into a new chunk.
2. Chunk manager works out which chunks should be loaded.
3. For each missing chunk, generate tile data on a worker thread (`WorkerThreadPool.add_task`). Generation returns plain data (arrays of cell coords and atlas coords), no nodes.
4. Back on the main thread, apply the chunk's diff, then build the `TileMapLayer` a few hundred cells per frame.
5. Spawn entities from chunk data.
6. Unloading writes entity state back to the chunk diff, then frees the node.

### Diffs, not snapshots

Generated content is never saved. Only changes are:

```gdscript
class_name ChunkDiff
extends RefCounted

var removed_cells: Dictionary = {}   # Vector2i -> true
var placed_cells: Dictionary = {}    # Vector2i -> Vector2i (atlas coords)
var entities: Array = []             # serialized entity dictionaries
var rot_level: float = 0.0
```

Load = generate from seed, then apply diff. This keeps saves small even with a huge world.

## Saving

- File: `user://saves/slot_N.save`
- Format: `FileAccess.store_var()` with a header dictionary containing `save_version`. Do not use `full_objects = true`, it lets a save file run code.
- Convert sim classes to dictionaries with `to_dict()` / `from_dict()` on each class.
- When the format changes, bump `save_version` and add a migration step in `SaveSystem`. Never break old saves silently.
- Write to a temp file, then rename, so a crash mid-save cannot corrupt the slot.

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
