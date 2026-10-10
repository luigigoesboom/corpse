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

## Sites and settlements (week 27)

Places are hand-made slots; what fills them is data. A `Settlement` node (src/world/settlement.gd) under Entities in world.tscn marks a stretch of flat floor (width, capacity, optional preferred faction). `WorldData.sites` maps the slot's node name to a `SiteData` (src/sim/sites): kind (&"settlement" now; ruins and shrines in week 29), owning faction, generated name, population, founding year. `SiteSeeder` (src/world) fills it when a world starts or an old save has no sites: preferred faction, else whoever holds the chunk; residents = owner strength / 20, capped by capacity.

At runtime the Settlement builds itself from the owner's FactionDef: `settlement_props` (SettlementProp scenes: width, work spot, worker offset) shuffled with a SeededRng per site and spread along the floor, and `population` `ColonyNpc` residents (src/actors/npcs) in the faction's `npc_frames_dir` look. Residents walk along the floor without physics, idle, stroll, claim and work at work spots, chat with an idle neighbour, look at a nearby player; the settlement shows its name when you walk in and makes the resident nearest you say one of the faction's `barks` every few seconds. Residents are not saved individually; changing a SiteData (population, faction) and calling `build()` changes what is shown.

## History sim (week 28, D-025)

`HistorySim.run(data)` (src/sim/history) simulates the Gut's past, year by year, when a world is created: 2000 years ending in the year the game starts (new worlds start in year 2000 after the Fall). It runs once; between lives time still passes as rolled aftermath (D-021). Everything comes from one `SeededRng` for the world seed, so the same seed gives the same history, word for word; it takes about half a second.

| Thing | How |
|---|---|
| Peoples | 2-3 arrive in year 1, more later when few are left (`people_arrived`). Invented ones get a name, archetype and temperament from `HistoryNames` (farmers, diggers, hunters, cult, scavengers) and live only in `FactionData` (saved). |
| Destined factions | The Flesh-Tenders are founded early (year 5-220). The Choir of Waking is born in year 700-1500 as a prophet's schism from the most devout people of the day (or from pilgrims if nobody is devout). Neither can lose its last settlement or fall; if one ends small, pilgrims join it in the present (`pilgrims_joined`). |
| Population | Lives on sites (`SiteData.population`, people); a faction's strength is the sum. Settlements grow (faster with expansion, slower at war), crowd and send settlers out (`site_founded`). `GUT_CAPACITY` is how many people the Gut can feed: the fuller it is, the slower everyone grows and the more neighbours sour on each other. |
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

## Bosses (D-026)

`GulletMatron` (src/actors/bosses) is a CharacterBody2D with one state machine: DORMANT -> INTRO -> STALK <-> WINDUP -> ACTIVE -> RECOVER, plus STAGGER, PHASE_SHIFT (once, at half health: faster windups and rests, brood unlocked, bigger volleys) and DEAD. Attacks are a data table (`ATTACKS`: windup / active / recover seconds, distance band, phase, weight); she picks by distance and weight, never the same attack three times running, and reacts faster to a player hugging her (favouring the tail sweep). Spawned hazards (bile_glob -> bile_puddle, shockwave) live beside her and exclude her Hurtbox; with friendly fire on they hurt her brood. `telegraph_left()` exposes the windup for bots and tests. EventBus: `boss_engaged` (shows `BossBar` in the HUD), `boss_defeated`, `shake_requested` (GameCamera shakes). On death she drops loot through `item_drop_requested`, logs `boss_slain`, and emits `entity_killed`. Tests may opt into fixed frames with a `## run-with: --fixed-fps 60` line (tests/run_tests.sh), so long fights run faster than real time.

## Ichor and boons (week 34, D-027)

Ichor is what each life is after. `Ichor.for_kill(kind, position)` (src/sim/fragment): creature value (`CREATURE_VALUES`) x depth factor (+25% per chunk row down). The game adds it when the player kills something (`Game._on_entity_killed`), and `IchorClot` pickups (hand-placed under Entities, gone for good once taken) hold fixed amounts in ruins and deep places. `WorldData.ichor` is what the host carries; `end_life()` moves it onto the body (`LifeRecord.corpse_ichor`), `reclaim_corpse()` gives it back. Between lives up to 40% dries out of a body (x tier strength); CorpseFate: eaten and studied bodies lose all of it, looted half, enshrined none.

A `HeartRoot` (src/world) banks it: interact opens data/dialogue/heart_root.dialogue with a `RootTalk` (plain, like Talk): pour in everything carried (`bank_ichor()` -> `ichor_banked`, never lost), then buy `Boons` (`buy_boon()`, `WorldData.boons`). Unaffordable boons show greyed out. A root with a `keeper` faction (the Choir's altar in its chapel) refuses hostile hosts and turns offerings into a deed for its keepers (+1 per 5 ichor, at most +15).

| Boon | Cost | Where it acts |
|---|---|---|
| sense_bodies | 15 | HUD draws a mark toward the newest old body with anything on it |
| hardy | 30 | `Game._apply_host()`: +1 max heart |
| wider_choice | 40 | `Game.rebirth_options()`: 4 hosts |
| lasting_graft | 60 | `end_life()` keeps the first mutation slot in `kept_graft`; the next host is born with it |

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
