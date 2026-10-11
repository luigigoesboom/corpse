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

## Sound (week 40)

Buses (res://default_bus_layout.tres): Master <- Music, Ambience (-6 dB), SFX (a small cave reverb), UI.

**Sfx** (autoload): `Sfx.play(id, position)`. `SOUNDS` lists every id with its volume, pitch and bus. A sound plays, first found: `assets/audio/sfx/<id>.wav` (copied from the licensed Ovani pack by `tools/copy_sfx.sh`, gitignored), `assets/audio/generated/<id>.wav` (ours, committed), or an inline recipe. Creatures, the Matron, guards, the watch, ichor, roots, boons, keys, murals, settlements, the death screen and rebirth all have their own sounds; `UiSounds.wire(node)` gives every button under a node hover and select sounds (also buttons added later).

**Ambience** (src/world/ambience.gd, added by Game): a looping layer per kind of rock plus three more on the Ambience bus, crossfaded by `targets_at(camera)`: the body (heartbeat and drone, louder deeper down), one per kind of rock (`WorldMap.kind_weights()` over the kinds painting, shared with the backdrop tint), settlement murmur (group `settlements`, within 600 px), and the boss layer while a boss fight is on. A layer uses `assets/audio/ambience/amb_<layer>.wav` from the pack if copied, else our own loop. Keeps playing while paused.

**Our own sounds**: `tools/sound/synth.gd` (tones, noise, squelches, bubbles, drips, heartbeats, filters, seamless loops, WAV writer) and `tools/sound/sounds.gd` (every recipe; run it with `--script res://tools/sound/sounds.gd`).

## Menus, settings and saves (week 41)

**Settings** (autoload, src/autoload/settings.gd): volume per bus, fullscreen, screen shake (GameCamera multiplies by it), and key bindings for `REBINDABLE` actions (a custom key or mouse button replaces the keyboard/mouse default; gamepad buttons stay). Kept in `user://settings.cfg` (`path`; tests use their own), applied at start and on every change.

**Screens** (src/ui, built in code): `SettingsScreen` (Sound / Display / Controls; click an action and press a key to rebind), `SlotScreen` (three slots with "host, life, year, time played"; NEW asks twice before overwriting, LOAD only offers used slots). The main menu (src/ui/main_menu.gd; the backdrop drifting behind the drawn title, Continue = `SaveSystem.latest_slot()`, New game, Load, Settings, Quit, controls along the bottom; test arenas only in debug builds) and the pause menu (Resume, Save, Load last save, Settings, Controls, Main menu, Quit) use them. Look: assets/ui (panel, buttons, slider, check box, title) drawn by tools/pixel/recipes/ui.gd, which also writes assets/ui/theme.tres (run it twice when images are new: they must be imported before the theme can use them).

**Slots**: `WorldState.slot` is where this world saves (1..3 from the menus; 0 = the old quick slot; tests use 97..99). Saves carry a `summary` (`SaveSystem.summary(slot)`); F9 / Save, the start of every life (`Game.autosave()`) and leaving to the menu or quitting all save to it.

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

## Sites and settlements (week 27)

Places are hand-made slots; what fills them is data. A `Settlement` node (src/world/settlement.gd) under Entities in world.tscn marks a stretch of flat floor (width, capacity, optional preferred faction). `WorldData.sites` maps the slot's node name to a `SiteData` (src/sim/sites): kind (&"settlement" now; ruins and shrines in week 29), owning faction, generated name, population, founding year. `SiteSeeder` (src/world) fills it when a world starts or an old save has no sites: preferred faction, else whoever holds the chunk; residents = owner strength / 20, capped by capacity.

At runtime the Settlement builds itself from the owner's FactionDef: `settlement_props` (SettlementProp scenes: width, work spot, worker offset) shuffled with a SeededRng per site and spread along the floor, and `population` `ColonyNpc` residents (src/actors/npcs) in the faction's `npc_frames_dir` look. Residents walk along the floor without physics, idle, stroll, claim and work at work spots, chat with an idle neighbour, look at a nearby player; the settlement shows its name when you walk in and makes the resident nearest you say one of the faction's `barks` every few seconds. Residents are not saved individually; changing a SiteData (population, faction) and calling `build()` changes what is shown.

## Regions (week 46, D-030)

`Regions` (src/sim/regions.gd) lists the body's regions as data: `IDS` (in the order history runs them; new ones at the end) and `INFO` per region (name, paint color in data/maps/regions.png, `capacity`, `history` on or off, `from`, `goods`). `WorldMap.region_at(tile)` / `region_of(point)` read the painting (unpainted or outside = the Gut; F4 re-reads it). `FactionDef.region`, `FactionData.region` and `SiteData.region` say where a people and a place belong (save version 23; older saves are all Gut). `HistorySim.run_regions(data, regions)` runs the pasts side by side, each with its own generator (the Gut's is the old `[seed, "history"]`), `DESTINED` lists each region's hand-made factions, and `HistorySim.region` is the region being simulated (`_alive()`, `_living_sites()`, pressure and new peoples use it). When a world loads, `HistorySim.regions_without_past()` names any simulated region it lacks (a new world: all of them; an old save: a region added since) and only those are run; the log is sorted back into order. `SiteSeeder` keeps slots inside their region: a ruin slot takes only ruins of its own region.

**The Lungs** (week 47) are columns 256-511 of world.png, painted by tools/map/paint_lungs.gd (ART_PIPELINE.md). Their rock is `alveolus` and `cartilage`; the backdrop blends to the Lungs' own three layers (`lungs` in the shader, eased from `WorldMap.region_share()`, the share of the view in the Lungs); the ambience has a layer per kind as always.

**Membranes**: magenta in world.png. `WorldMap.is_membrane()`; not solid (rock and the minimap's walls treat them as air). A membrane cell is `ChunkData.membrane_cell(variant)`: a pseudo-kind after the real ones, so its tiles are the atlas row after the last kind (variant 0 middle, 1 left end, 2 right end, 3 alone). The tileset gives them a one-way collision on physics layer 7 (value 64, "membranes"); only the player's mask has it. `Player.is_on_membrane()` (a test move down onto layer 7); landing faster than `MEMBRANE_MIN_BOUNCE` bounces back with `MEMBRANE_BOUNCE` (more with jump held), a jump off one is `MEMBRANE_JUMP` times as strong, and `move_down` + jump drops through (layer 7 off for `DROP_TIME`). Input `move_down`: S, Down, left stick down (rebindable).

**The Bellows-Kin** (week 50, data/factions/bellows_kin.tres): the Lungs' people, gliders who keep time to the god's breath and ride its winds on kites of lung; traders (trade 0.85), little aggression, a little sense of the fragment (0.3); they study bodies more than they loot them. `HistorySim.DESTINED[&"lungs"]`: founded early (years 40-400); the Lungs' past is now simulated (Regions INFO history on), with their own generator, side by side with the Gut's (whose story stays word for word the same: a new site's name is only checked against its own region's names in the Gut, against all names elsewhere). They hold all of the Lungs (territory.png, painted by paint_lungs.gd). Their roost is the `KinRoost` settlement slot on the Lower Lobe's floor (props: kite rack and breath drum, both work spots, membrane hammock, windsock, banner; residents in the `kin` look: a bladder mask with a breathing tube, a kite folded on the back), `LobeRuin` takes a ruin of the Lungs' past, and `SpawnPoints/KinRoost` lets a host wake there. An old save gains the Lungs' past when it loads (`regions_without_past()`).

**The breath** (week 52, D-031): `Breath` (src/world/breath.gd, a node Game adds): `time` counts while the game runs; `strength()` -1 (exhale) .. 1 (inhale) over a 20 s cycle (inhale 8, hold 2, exhale 8, rest 2), `phase()`, `phase_changed`, `wind_at(point)` = the sum of every `WindZone` there (`inhale` vector, faded over `soft_edge`) times the strength. Zones (World/WindZones): BellowsUpdraft (up 2000 on the inhale), BronchusDraught (east 650), TracheaDraught (down 3000: the exhale carries you up the windpipe), HivesEddy, LobeDraught. The host: sideways wind shifts its running target speed by `WIND_DRIFT` seconds of it, vertical wind pushes it in the air (`Player.wind()`); the Lung Sac's glide turns 15% of an updraft into a climb. `Creature.wind_weight` (Puffsac 0.5, Ray 0.3). Wind bones swing and click; WindZones draw streaks of air on screen; the ambience has a `breath` layer and Game plays `breath_in` / `breath_out` in the Lungs; the backdrop shader brightens with `breath`.

**Landmarks** (week 48): `Landmark` nodes (src/world/landmark.gd) under World/Landmarks in world.tscn (not Entities: big places span chunks and must not stream out), each a named area: `title`, `line`, `extents` (half size, px). Walking in emits `EventBus.place_entered(title, line, first)`; `first` comes from `WorldData.see_place(key)` (`places_seen`: node name or "region:<id>" -> year first seen; save version 24). The HUD shows it across the upper middle (`HUD.show_place()`, "Discovered" and the `discover` sound the first time). Crossing into another region does the same with the region's name (`Game._check_region()`; waking in the Gut is not announced). Landmarks are minimap marks. The Lungs' places: the Great Bronchus, the Bellows, the Alveolar Hives, the Lower Lobe, the Trachea, the High Aerie; their set pieces (cartilage gate, pleural curtains, hive lanterns, the aerie nest, wind bones) are src/props/lungs, drawn by tools/pixel/recipes/lung_props.gd. The Lungs also have a wild heart-root (WildRootLungs, Lower Lobe) and four ichor clots.

**Rock kinds** are one table, `RockKinds` (src/world/rock_kinds.gd): `IDS` (atlas and cell order; `ChunkData.KINDS` is it) and per kind its ramp, tiles.png paint, backdrop tint, minimap color and ambience layer. The tiles and dressing recipes, WorldMap, backdrop, minimap and ambience read it.

**Old saves**: tests/fixtures/save_v<N>.save, one per format since 22, written by tests/make_fixture.gd (run it whenever `SAVE_VERSION` goes up); tests/test_old_saves.gd loads every one.

## History sim (week 28, D-025)

`HistorySim.run(data)` (src/sim/history) simulates the Gut's past, year by year, when a world is created: 2000 years ending in the year the game starts (new worlds start in year 2000 after the Fall). It runs once; between lives time still passes as rolled aftermath (D-021). Everything comes from one `SeededRng` for the world seed, so the same seed gives the same history, word for word; it takes about half a second.

| Thing | How |
|---|---|
| Peoples | 2-3 arrive in year 1, more later when few are left (`people_arrived`). Invented ones get a name, archetype and temperament from `HistoryNames` (farmers, diggers, hunters, cult, scavengers) and live only in `FactionData` (saved). |
| Destined factions | The Flesh-Tenders are founded early (year 5-220). The Choir of Waking is born in year 700-1500 as a prophet's schism from the most devout people of the day (or from pilgrims if nobody is devout). Neither can lose its last settlement or fall; if one ends small, pilgrims join it in the present (`pilgrims_joined`). |
| Population | Lives on sites (`SiteData.population`, people); a faction's strength is the sum. Settlements grow (faster with expansion, slower at war), crowd and send settlers out (`site_founded`). The region's `capacity` (Regions; the Gut 2600) is how many people it can feed: the fuller it is, the slower everyone grows and the more neighbours sour on each other. |
| Relations | Drift each year toward a target from shared values, piety gap, aggression and Gut pressure. Low enough and an aggressive side declares war (`war_declared`, with a cause); wars have battles (`site_taken`, `site_razed`, `raid_repelled`, `last_stand`; a repeated siege is told once) until `peace`. Friendly traders make one `trade_pact` per pair. |
| Splits and wonders | Big factions split (`schism`, the splinter takes a settlement); devout ones have prophets (`prophet`); rarely something wonderful happens (`wonder`: relics, veins, hunts, salvage, harvests). |
| Disasters | Bile floods, rot plague, spasms, famine (`disaster`); a settlement left with almost nobody is abandoned (`site_abandoned`, becomes a ruin). |
| Endings | A faction with no settlements or almost nobody left is gone (`faction_fell`); its settlements are ruins (kind `&"ruin"`, `ended_year`). |

After history: `FactionTerritory.apply_territory()` gives the painted present-day territory to the factions that exist, and `SiteSeeder.fill_slots()` puts each hand-made Settlement slot's faction's biggest free settlement into it (`SiteData.slot`). Surviving invented peoples live "elsewhere" in the body: future regions can give them land.

Events are `EventRecord`s (id, year, type, actors = faction ids, data = site id, cause, dead, names...). `EventText.describe()` / `line()` turn them into sentences when shown, with a few phrasings per type picked by event id; nothing is stored as text, so better writing improves old saves. F2 in game shows the whole log (`HistoryLog`, a debug tool; players will learn history from murals and rumors).

## Ruins and artifacts (week 29)

`RuinSite` slots (src/world/ruin_site.gd) under Entities mark flat floor for a ruin. After history, `SiteSeeder.fill_ruin_slots()` gives each one the ended settlement (`kind == &"ruin"`) with the most events behind it, forges that site's artifact with `ArtifactForge` (the most memorable event there, by priority: wonder, schism, razing, last stand, fall, abandonment, disaster, ...) and drops it as an item on the ruin's floor. A RuinSite builds broken props (`PropLayout`, shared with settlements; the torn banner takes its people's color) and, when you walk in, shows "The ruins of X" and how it ended (`EventText.line()` of its ending event).

`ArtifactData` (src/sim/history) lives in `WorldData.artifacts`; its id is also its item id. Its name is stored; its description is made when shown by `ArtifactText.describe()`: a line about what it looks like, then the origin event and the site's ending event in the exact words of the log. The game registers every artifact as a generated `ItemDef` (`ItemDb.set_generated(ArtifactText.item_defs(data))`) whenever a world loads, so artifacts are picked up, carried, dropped and left on corpses like any item. Aftermath never rots artifacts lying in the world. Save version 13.

## Dialogue (week 30)

Uses the Dialogue Manager addon (Nathan Hoad, v4; plugin and its `DialogueManager` autoload are enabled). Residents (`ColonyNpc`) and wanderers (`placeholder_npc`) have a `TalkArea` (Area2D on layer 2, so the player's E finds it like an item) that calls their `talk()`. `Conversation.start()` (src/dialogue) makes a `Talk` and opens a `DialogueBalloon` (our restyled copy of the addon's example balloon) on the root; the balloon pauses the game until the conversation ends.

- **Shape** of a conversation: data/dialogue/resident.dialogue (greeting, then news / their people / trade / farewell). Edit it in Godot's Dialogue tab.
- **Words that depend on the world** come from the `Talk` object the dialogue reads by name: `{{greeting}}`, `{{creed}}`, `{{rumor()}}`, `{{offer_text}}`, `[if can_trade /]`, `do trade()`. `Talk` is plain (it changes WorldData and emits `traded`), so it can be tested without the UI.
- **Greetings** come from the speaker's FactionDef `greetings` by standing tier (hostile < -30, wary < 0, neutral < 30, friendly); standing is the faction's `host_attitudes` for the current host type for now (week 31 adds deeds). Hostile speakers greet and end the conversation.
- **Rumors**: `Rumors` (src/sim/history) weighs events (recent, about the speaker's people, at places you can walk to, and above all host deaths), picks one, and tells it with how long ago, the event's sentence from `EventText` (so it matches the log), and the speaker's stance (pride, grief, spite). Fragment-sensing speakers recognize the player in rumors of a host's death.
- **Barter**: FactionDef `wares` (what they give) and `wants` (what they take; `&"artifact"` = any artifact), one for one.

## Creatures from week 45 on

New creatures extend `Creature` (src/actors/creatures/creature.gd): the script fills in `think(delta)` (one physics frame of AI, with its own `State` enum in `state`) and `animation()`; the base finds the player, applies gravity (0 for flyers), shows the hurt flash and damage numbers, and on death stops the hitboxes, drops `drop_item`, fades and emits `entity_killed`. Helpers: `enter()`, `face()`, `turn()`, `sees_player(within, max_dy)`, `to_player()`, `strike(seconds)` (the melee Hitbox at Visual/Attack). `tools/creature/new_creature.gd` writes a working creature (recipe, script, scene) for one of four behaviours; see ART_PIPELINE.md. Kinds that leave no carcass: `Game.NO_CARCASS`.

**Puffsac** (the Lungs): a floater that drifts toward the host, swells (0.8 s, the tell) and bursts: its Attack ring (62 px, 2 damage) hurts everything, other creatures too; a `SporeCloud` shows the reach. One hit pops it, but then it bursts after `fuse_time` (0.35 s); a pop by the host counts as the host's kill.

**Cilia Lasher** (the Lungs, rooted): a mound of lung with one thick cilium; whatever comes within `reach` (84 px, 70 up or down) gets whipped: it draws the lash back (0.5 s), then a long low Attack box sweeps the floor ahead (76 x 18 px). It cannot move; jump or roll through the lash and hit it while it coils back (0.9 s).

**Bellows Ray** (the Lungs, flyer): circles over what moves, glides to a perch high to one side, tips over (0.55 s) and swoops: straight at the host, then, once down at the height the host was (`_floor_y`), it bends back up and away (`pull_up`). Drops a breath sac (the Lung Sac mutation).

Creatures in the Lungs: Puffsacs in the open chambers, Lashers on the floors, Rays in the high spaces (world.tscn Entities). Their ichor: Puffsac 3, Lasher 4, Ray 5.

## Bosses (D-026)

`GulletMatron` (src/actors/bosses) is a CharacterBody2D with one state machine: DORMANT -> INTRO -> STALK <-> WINDUP -> ACTIVE -> RECOVER, plus STAGGER, PHASE_SHIFT (once, at half health: faster windups and rests, brood unlocked, bigger volleys) and DEAD. Attacks are a data table (`ATTACKS`: windup / active / recover seconds, distance band, phase, weight); she picks by distance and weight, never the same attack three times running, and reacts faster to a player hugging her (favouring the tail sweep). Spawned hazards (bile_glob -> bile_puddle, shockwave) live beside her and exclude her Hurtbox; with friendly fire on they hurt her brood. `telegraph_left()` exposes the windup for bots and tests. EventBus: `boss_engaged` (shows `BossBar` in the HUD), `boss_defeated`, `shake_requested` (GameCamera shakes). On death she drops loot through `item_drop_requested`, logs `boss_slain`, and emits `entity_killed`. Tests may opt into fixed frames with a `## run-with: --fixed-fps 60` line (tests/run_tests.sh), so long fights run faster than real time.

## Stealth, guard posts and bribes (week 36)

**The player** holds `sneak` to move at 40% speed, crouched, with its light at 30%. `Player.noise_radius()`: 0 sneaking or standing, 110 px walking, 220 px for half a second after a swing, roll, jump or hard landing. `Player.visibility()`: 1.0, 0.3 sneaking, x2.5 inside any node in group `watch_lights` (radius).

**Residents** (`ColonyNpc`) perceive the player whenever their settlement `watches_player()` (a hostile settlement, or a guard post that bars you). `awareness` (0..1) rises from sight (in front, within 220 px, `SIGHT_RATE x visibility`), noise in earshot, and brushing past (softer when sneaking); at 1 they have `noticed` you ("?" then "!" over their heads) and forget after 4 s out of sight. In a hostile settlement guards attack and others flee only once they notice you, so you can sneak through; a player hit raises the alarm for everyone (`raise_alarm()`), a creature's hit does not.

**Guard posts** (`GuardPost`, extends Settlement but is not a site): sentries of a `keeper` faction stand on one side of a gap with a bone grate over it, looking back across it and now and then away (`stationed`). Only friends of the keeper pass (the grate opens); for anyone else a sentry that notices you steps into your way and warns you (`_block()`), and the post attacks after `WARN_SECONDS` or as soon as you stand at the gap. Ways past: sneak to the latch on the near lip while they look away and lift it (E); bribe; become their friend; fight (sentries killed are kept in removed_entities as &"sentry", so they may be replaced between lives).

**Bribes**: guards of a place that keeps you out offer to look away (`Settlement.bribe_offer()` = [place key, ichor]: hostile settlements 30 + |standing| / 2, posts 20). `Conversation.start()` passes it to `Talk.offer_bribe()`; resident.dialogue's `guarded` branch halts you and offers it; paying puts the place in `LifeRecord.bribes` (this body only) until you hurt one of them.

**Carcasses**: creatures leave a `Carcass` for 90 s (not saved); eating it (E) gives a heart and 1 ichor.

## Murals and lore (week 35)

History is read where it happened. Every settlement builds a mural of its people (`LorePiece`, kind MURAL) at its right end; every ruin builds the fallen people's mural and a bone tablet (kind TABLET) about that place. `Lore.mural_events(data, faction, seed)` picks up to four events the people would paint (`WORTH_PAINTING`): how they began, then the biggest moment in each stretch of their past (seed = site, so different murals of one people show different moments). `Lore.site_events()` is how a place began and ended. Text is made when read (`describe_mural()` in the people's medium, `describe_tablet()` quoting the log) and shown page by page through data/dialogue/reading.dialogue (`Reading`). Reading calls `WorldData.learn(ids)` (`known_events`, saved); the inventory's History tab lists everything known per people (an event shows under every people in it), oldest first, in `EventText.line()` words.

## Ichor and boons (week 34, D-027)

Ichor is what each life is after. `Ichor.for_kill(kind, position)` (src/sim/fragment): creature value (`CREATURE_VALUES`) x depth factor (+25% per chunk row down). The game adds it when the player kills something (`Game._on_entity_killed`), and `IchorClot` pickups (hand-placed under Entities, gone for good once taken) hold fixed amounts in ruins and deep places. `WorldData.ichor` is what the host carries; `end_life()` moves it onto the body (`LifeRecord.corpse_ichor`), `reclaim_corpse()` gives it back. Between lives up to 40% dries out of a body (x tier strength); CorpseFate: eaten and studied bodies lose all of it, looted half, enshrined none.

A `HeartRoot` (src/world) banks it: interact opens data/dialogue/heart_root.dialogue with a `RootTalk` (plain, like Talk): pour in everything carried (`bank_ichor()` -> `ichor_banked`, never lost), then buy `Boons` (`buy_boon()`, `WorldData.boons`). Unaffordable boons show greyed out. A root with a `keeper` faction (the Choir's altar in its chapel) refuses hostile hosts and turns offerings into a deed for its keepers (+1 per 5 ichor, at most +15).

| Boon | Cost | Where it acts |
|---|---|---|
| sense_bodies | 15 | HUD draws a mark toward the newest old body with anything on it |
| hardy | 30 | `Game._apply_host()`: +1 max heart |
| wider_choice | 40 | `Game.rebirth_options()`: 4 hosts |
| lasting_graft | 60 | `end_life()` keeps the first mutation slot in `kept_graft`; the next host is born with it |

## Valve keys (week 38)

Week 51: one key per region, all in `ValveKeys.KEYS` (keeper, kept place, settlement slot, wild place and its event, the signs in the keepers' past that make them keep it, price). The Lungs' key (`valve_key_lungs`) is kept by the Bellows-Kin on a string at the top of their roost (`KinKeyString`, `kin_roost`; signs: wonders, trade pacts; 120 ichor) or lies in the High Aerie (`AerieKey`, `high_aerie`, event `key_nested`), reached up the Trachea. `kept_by()` and `price_of()` serve Talk (`key_line` per key); a key's own keepers take it home from a body they claim. KeyCache `show_art` off where a set piece is already there.

A valve key is an item (`valve_key_gut`), so it is carried, dropped, left on a corpse and reclaimed like anything else, and never rots on the floor. While nobody carries it, it lies at a hand-made place: `WorldData.key_places[key]` = a place id (`ValveKeys.CHOIR_RELIQUARY`, `ValveKeys.MATRON_NEST`), "" while it is an item. A `KeyCache` under Entities with that `place` shows it and gives it (E). `ValveKeys.place_at_start()` runs when a world loads: a Choir with two or more wonders or prophets in its past keeps the Gut key in its reliquary (`key_kept`), otherwise it lies in the Gullet Matron's nest (`key_swallowed`).

| Held by | Ways to get it |
|---|---|
| The Choir (reliquary in the chapel) | Ask as a friend (`Talk.ask_key()`); pay `ValveKeys.CHOIR_PRICE` ichor (`buy_key()`); steal it from the reliquary: unseen, nobody knows (`key_stolen`, seen false); seen by a resident (in front, in reach for your visibility), it is a -100 deed and the chapel raises the alarm. |
| The Gullet Matron (nest at the east end of the deep) | Kill her; or come down the east cavern and sneak: she wakes at 35% of her range for a sneaking host. |

Between lives, a people who sense the fragment and claim a body carrying a key take it to their reliquary (`ValveKeys.reclaim_from_body()`, `key_taken`): keys can be lost across lives (roadmap week 77 builds on this).

## Between lives (week 37)

`Aftermath.apply()` now: rolls the gap, then `HistorySim.between_lives(data, years)` runs the same yearly simulation as worldgen for those years (with `protect_slots` on: sites in a hand-made slot cannot be taken, razed or abandoned, and peoples living in one do not fall), then `DeedEchoes.apply()` turns the last life's deeds into events with visible effects, then CorpseFate, scavengers, creatures returning (never bosses, `Aftermath.BOSSES`) and dropped items. The time screen hints at the biggest change involving a people you can meet ("While you were gone: ...") and at each echo.

| Deed (last life) | Echo |
|---|---|
| Killed residents of a people | `vengeance_sworn` (rumors) |
| Ichor offered at a keeper's root (`LifeRecord.offerings`) | `offerings_fed`: their home grows by half the ichor |
| Killed the Gullet Matron | `deep_settled`: the strongest destined people grows by 40 |
| A body of the fragment lies enshrined | `pilgrims_came`: +20 people at that site every gap |
| Robbed a shrine | `shrine_desecrated`: the keepers' relations with everyone drop 15 |

## Death and rebirth flow

Week 33: before scavengers, `CorpseFate.apply()` lets factions claim bodies nobody has claimed yet. The claimant is the faction holding the body's chunk (chance 0.9 x tier strength), else a fragment-sensing faction (strength x senses x 0.6). It picks a fate from its FactionDef `corpse_fates` weights (Choir: enshrined 6, studied 2, looted 1; Flesh-Tenders: eaten 5, looted 3, studied 1); a faction whose legend is below -30 loots instead of enshrining. Enshrined and studied bodies move to the faction's biggest lived-in settlement (`places`: slot -> `Settlement.body_spot()`, built by Game, so the sim stays node-free), 40 px apart. Enshrined: kept whole, scavengers skip it; taking from it is a `shrine_robbed` deed (-40) unless the keepers count you a friend. Studied: mutations cut out. Eaten: mutations gone, things left. Looted: pockets emptied. Each claim is a `corpse_claimed` event (rumors weigh it like a host death) and a hint for the newest body.

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

### Host standing (week 31)

`LifeRecord.standing` (faction id -> -100..100) is how each faction feels about the current body; every host starts fresh. A faction missing from it uses its FactionDef `host_attitudes` for the host type. `WorldData.standing(f)`, `change_standing(f, n)` (returns tiers before/after), `record_deed(f, n)` (also moves friends of f, relation > 30, by a quarter, and enemies, relation < -40, a tenth the other way). Tiers (`Standing`): hostile < -30, wary < 0, neutral < 30, friendly. Numbers are never shown; a tier change shows a line ("The Flesh-Tenders will remember that.").

| Deed | Standing |
|---|---|
| Hit a resident | -60 with its people (`Settlement.HURT_DEED`) |
| Kill a resident | -100, one fewer resident (population -25), a `resident_killed` event (rumors) |
| Trade | +3 |
| Kill a creature in a faction's territory | +2 |

| Tier | What you see |
|---|---|
| Hostile | Guards (a third of the residents) close in and swing (telegraphed, dodgeable, leashed to the settlement); the others flee; names turn red; barks become threats; talk ends at the greeting; no trade. |
| Wary | Trades cost two of what they want. |
| Neutral | One for one. |
| Friendly | One for one, plus an extra ware if you have room. |

### Legend standing (week 32)

`WorldData.legend` (faction id -> -100..100) is what each faction knows of the fragment, across every body; it is saved and never reset. `record_deed()` moves it by half the deed. `standing(f)` = `host_standing(f) + legend_standing(f) * senses_fragment` (Choir 0.9, Flesh-Tenders 0). Deeds that people remember are events logged with `log_deed()`, which also adds the event id to the current `LifeRecord.deed_event_ids`: `resident_attacked` (once per site per life), `resident_killed`, `boss_slain` (in `Legend.FAMOUS`: everyone remembers it, and in `Legend.GOOD`: they are glad of it). `Legend.recognition(data, f)` turns the latest remembered deed from an earlier body into a line ("Two bodies ago, you killed Belet at Sinewhearth. We have not forgiven it."); `Talk` sets `recognized` / `recognition` for speakers whose faction senses the fragment (>= 0.5), and resident.dialogue says it after the greeting.

Rumors can slowly move host standing for non-sensing factions when your current host matches a known description. (Not built yet.)

## Mutations

The Lungs' (week 51): **Bellows Heart** (belly, `air_jump.gd`, item Second Heart in the Hives): jump again in the air, once until the ground, a membrane or a wall (a tap cuts it short, like a jump). **Gust Bladder** (head, `gust.gd`, item Wind Bladder in the Hives and from the Kin's wares): input `ability_head` (R, pad X), a gust in front (96 x 56 px, 1 damage, knockback 560) that pops a Puffsac where it floats and throws creatures back, and pushes the host the other way (a hop back in the air); 0.8 s cooldown. `GustPuff` draws the breath. `Player.ABILITY_ACTIONS` maps belly to jump and head to ability_head.

Current implementation (D-015): `MutationDef` resources in data/mutations (id, slot, ability script, placeholder polygon). `ItemDef.grants_mutation` makes an item edible. `WorldData.mutations` (slot -> id) is the truth; `MutationHost` on the player rebuilds parts (at `Visual/Sockets/socket_<slot>`) and ability nodes from it. The player calls each ability's `physics_tick()` after its own movement and before `move_and_slide()`, so abilities can change `player.velocity`.

Original plan:

- `MutationData` is a Resource: id, display name, part scene, socket name, ability script, stat changes, which regions it can come from.
- Grafting = instance the part scene, attach to the named socket on the host rig, add the ability node to the player.
- Creatures use the exact same system, so any creature mutation can in theory be taken by the player.

## Atmosphere (after week 52)

`Atmosphere` (src/world/atmosphere.gd), added by Game, owns the air of the body; all of it is a view, none of it is saved:
- **The picture's look**: game.tscn's Vignette layer (layer 3, above the world and the mist, under the UI at 10) draws `assets/shaders/atmosphere.gdshader` over the screen: grading per region (`LOOKS`: lift, gain, saturation; the Gut warm and sick, the Lungs pale and cold, eased by `WorldMap.region_share()`), a deep vignette in steps whose edge wanders with noise, beats with the god's heart (`heartbeat()`, 52 bpm, matching the ambience) and swells with the breath, a one-pixel colour fringe toward the edges, grain on the 640 x 360 pixel grid, and, when the host is down to two hearts and then one, the dark closing in red.
- **Fog**: two CanvasLayers with `assets/shaders/fog.gdshader`: Fog (layer -5, between the back wall and the world: drifting banks, parallax 0.55, thicker in the Lungs and when they breathe in) and Mist (layer 2: a thin haze hugging the bottom of the screen in front of the playfield, drifting with the wind).
- **Motes** (src/world/motes.gd): 80 specks and spores floating around the camera in the region's colours, flickering, carried by `Breath.wind_at()`.
- **Settings**: Display tab "Atmosphere" (`Settings.atmosphere`, 0..1; 0 = the plain picture, no fog, no motes) and "Film grain". tests/perf_render.gd turns it off while it reads marker pixels.

## Rooms and reachability (D-032)

world.png is made in three steps, all offline tools: shape_world.gd (the Gut's painting into caves), paint_lungs.gd (the Lungs), then rooms.gd, which reads their result (data/maps/_source/world_shaped.png) and breaks the Gut's box halls into storeys of rooms, adds ladders and membrane steps, and writes world.png only if `MapReach` (tools/map/map_reach.gd) finds every thing placed in world.tscn reachable from the spawn with the host's own jump (3 tiles up, 4 across, falls, membranes; no wall jumps or mutations) and every reached floor able to get back. tests/test_terrain.gd checks the same on the committed map, so a repaint that cuts something off fails. Undersides (`ChunkDressing`, undersides.png) are only a view: no collision below a tile's edge.

## Minimap (after week 41)

`WorldData.explored` keeps which tiles the player has seen: chunk -> a 512-byte bitset (one bit per tile), saved (version 22). `Minimap` (src/ui/minimap.gd, made by the HUD, top right) reveals about a screen around the host four times a second (`reveal(rect)`) and redraws 120 x 68 tiles around it, one pixel per tile: seen air dark red, walls next to air in their rock kind's color, everything else dark. Marks: settlements gold, the guard post orange, anything in group `minimap_marks` in its `minimap_color` meta (ruins grey, heart-roots red), the last body if the host has the sense_bodies boon. The game calls `HUD.bind_map(chunks, player)`.

## Debug tools (build them early, they pay back fast)

- F3 overlay: FPS, position, chunk coord, region, rot, year.
- Debug map: painted map with loaded chunks, player, sites, corpses.
- History log viewer: scroll the event log in game.
- Console: `teleport x y`, `skip_years n`, `give_mutation id`, `kill_player`.
- F12 (debug builds, week 45): record a GIF clip (`GifRecorder`, `GifWriter` in src/debug) to user://captures.

## Testing

Sim code is plain data, so it is easy to test. Optional: the GUT addon from the Godot Asset Library. Good first tests: same seed produces same chunk, save and load round-trip, history sim does not crash over 5000 years.
