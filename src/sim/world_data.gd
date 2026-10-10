class_name WorldData
extends RefCounted
## The whole simulated world as plain data. No nodes, no object references.
##
## Anything that must survive save/load lives here (or in data this points to by
## ID). The painted map is NOT stored: it ships with the game. Only changes to
## the world are, mostly in chunk_diffs.
##
## Nodes in the scene are views of this data. Change the data through the
## functions below, then let the views update.
##
## To add a field: add it here, write it in to_dict(), read it with a default in
## from_dict(), bump SaveSystem.SAVE_VERSION and add a step in SaveSystem._migrate().

## Pockets the current host has. An empty pocket holds &"".
const INVENTORY_SIZE := 8

var world_seed: int
var year: int = 0
## Where the current host is. Written by the game right before saving.
var player_position := Vector2.ZERO
## Current host's health. -1 = full.
var player_health := -1
## Current host's body: slot ("mouth", "arm", ...) -> MutationDef id.
var mutations: Dictionary = {}
## Item id per pocket (INVENTORY_SIZE entries, &"" = empty). Moves into
## LifeRecord in week 21.
var inventory: Array = []
## Vector2i chunk coord -> Dictionary of runtime changes in that chunk:
##   "items": Array of {"id": int, "item": StringName, "pos": Vector2}
## Unloaded chunks keep their changes here, so they survive leaving the area
## and saving. Empty chunks are removed to keep saves small.
var chunk_diffs: Dictionary = {}
## Hand-placed entities (children of Entities in world.tscn) that are gone,
## by node name -> what they were: &"item" (picked up, never returns) or a
## creature kind like &"gut_leech" (killed; may be replaced after a death).
var removed_entities: Dictionary = {}
## Next free ID for things created at runtime (dropped items, later corpses).
var next_id := 1
## Every host the player has had, oldest first (LifeRecord). The last one is
## the current host while it is alive.
var lives: Array[LifeRecord] = []
## Everything that happened, oldest first (EventRecord). Append only.
var events: Array[EventRecord] = []
## Faction id -> FactionData (week 26). Filled when a world starts, from
## data/factions and the painted territory map (FactionTerritory).
var factions: Dictionary = {}
## Site id -> SiteData (weeks 27, 28): every place history founded, lived
## in or ruined. Some sit in a hand-made slot (SiteData.slot).
var sites: Dictionary = {}
## Artifact id (also its item id) -> ArtifactData (week 29).
var artifacts: Dictionary = {}
## The fragment's legend (week 32): faction id -> -100..100, from deeds in
## every life. Only factions that sense the fragment act on it directly.
var legend: Dictionary = {}
## Ichor (week 34, D-027): what the current host carries (lost to the corpse
## at death), what the fragment has banked at heart-roots (kept forever, spent
## on Boons), and the boons it owns (id -> true).
var ichor := 0
var ichor_banked := 0
var boons: Dictionary = {}
## Slot -> mutation id the fragment keeps through death (Boons lasting_graft);
## the next host is born with it.
var kept_graft: Dictionary = {}


static func create(seed_value: int) -> WorldData:
	var data := WorldData.new()
	data.world_seed = seed_value
	data._fit_inventory()
	return data


## The site in a hand-made slot (a Settlement node's name), or null.
func site_in_slot(slot: String) -> SiteData:
	for site: SiteData in sites.values():
		if site.slot == slot:
			return site
	return null


## The faction holding a chunk, or &"" if nobody does.
func faction_at(chunk: Vector2i) -> StringName:
	for id in factions:
		if factions[id].is_alive() and factions[id].holds(chunk):
			return id
	return &""


## How faction `a` feels about faction `b`: -100 (war) .. 100 (kin).
func relation(a: StringName, b: StringName) -> int:
	if not factions.has(a):
		return 0
	return int(factions[a].relations.get(b, 0))


## Sets how two factions feel about each other, both ways.
func set_relation(a: StringName, b: StringName, value: int) -> void:
	value = clampi(value, -100, 100)
	if factions.has(a):
		factions[a].relations[b] = value
	if factions.has(b):
		factions[b].relations[a] = value


## The current host's record, or null between death and the next host.
func current_life() -> LifeRecord:
	if lives.is_empty() or not lives[-1].is_alive():
		return null
	return lives[-1]


## Starts the next host. The name defaults to the world's next host name.
func start_life(host_type: StringName, host_name := "", origin := "") -> LifeRecord:
	var life := LifeRecord.new()
	life.host_type = host_type
	life.host_name = host_name if host_name != "" else Names.host_name(world_seed, lives.size())
	life.origin = origin
	life.start_year = year
	lives.append(life)
	return life


## Closes the current life: when, where, how, and what the body held.
## Everything the host had moves onto the corpse at `corpse_position`; the
## next host starts with empty pockets and an unchanged body.
func end_life(position: Vector2, corpse_position: Vector2, killed_by: StringName) -> LifeRecord:
	var life := current_life()
	if life == null:
		return null
	life.death_year = year
	life.death_position = position
	life.corpse_position = corpse_position
	life.killed_by = killed_by
	life.carried_items = inventory.filter(func(item): return item != &"")
	life.carried_mutations = mutations.duplicate()
	life.corpse_items = life.carried_items.duplicate()
	life.corpse_mutations = life.carried_mutations.duplicate()
	life.carried_ichor = ichor
	life.corpse_ichor = ichor
	ichor = 0
	kept_graft.clear()
	if has_boon(&"lasting_graft") and not mutations.is_empty():
		var slots := mutations.keys()
		slots.sort()
		kept_graft[slots[0]] = mutations[slots[0]]
		life.corpse_mutations.erase(slots[0])
	for i in inventory.size():
		inventory[i] = &""
	mutations.clear()
	log_event(&"host_died", [life.host_name], {"killed_by": killed_by, "position": corpse_position})
	return life


## The current host searches an old body (lives[index]): items go into free
## pockets, mutations into empty body slots. What does not fit stays.
## Ichor always fits. Returns what was taken:
## {"items": [...], "mutations": [...], "ichor": int}.
func reclaim_corpse(index: int) -> Dictionary:
	var taken := {"items": [], "mutations": [], "ichor": 0}
	var life: LifeRecord = lives[index]
	taken.ichor = life.corpse_ichor
	ichor += life.corpse_ichor
	life.corpse_ichor = 0
	for item in life.corpse_items.duplicate():
		if add_to_inventory(item) >= 0:
			life.corpse_items.erase(item)
			taken.items.append(item)
	for slot in life.corpse_mutations.keys():
		if not mutations.has(slot):
			mutations[slot] = life.corpse_mutations[slot]
			taken.mutations.append(life.corpse_mutations[slot])
			life.corpse_mutations.erase(slot)
	return taken


func log_event(type: StringName, actors: Array, details: Dictionary) -> EventRecord:
	var event := EventRecord.new()
	event.id = new_id()
	event.year = year
	event.type = type
	event.actors = actors
	event.data = details
	events.append(event)
	return event


## How a faction feels about the current host, -100..100: this body's own
## standing (week 31) plus what the faction knows of the fragment inside it,
## as much as it can sense the fragment (week 32, VISION.md):
##   standing = host_standing + legend_standing * senses_fragment
func standing(faction: StringName) -> int:
	var senses: float = factions[faction].senses_fragment if factions.has(faction) else 0.0
	return clampi(host_standing(faction) + roundi(legend_standing(faction) * senses), -100, 100)


## This body only: starts at the faction's attitude to this host type.
func host_standing(faction: StringName) -> int:
	var life := current_life()
	if life == null:
		return 0
	if life.standing.has(faction):
		return int(life.standing[faction])
	var def := FactionDb.get_def(faction)
	return int(def.host_attitudes.get(life.host_type, 0)) if def else 0


## The fragment's legend with a faction, built from deeds in every life.
func legend_standing(faction: StringName) -> int:
	return int(legend.get(faction, 0))


## Moves one faction's standing with this body. Returns [tier before, tier
## after] of the full standing (see Standing.tier()).
func change_standing(faction: StringName, amount: int) -> Array:
	var life := current_life()
	if life == null or faction == &"":
		return [&"", &""]
	var before := standing(faction)
	life.standing[faction] = clampi(host_standing(faction) + amount, -100, 100)
	return [Standing.tier(before), Standing.tier(standing(faction))]


## A deed that matters to `faction` (weeks 31, 32): moves its standing with
## this body by `amount` and the fragment's legend by half of it; its friends
## feel a quarter, its enemies a tenth the other way.
## Returns {faction id: [tier before, tier after]} for every faction moved.
func record_deed(faction: StringName, amount: int) -> Dictionary:
	var changes := {faction: _deed_on(faction, amount)}
	for other: FactionData in factions.values():
		if other.id == faction or not other.is_alive():
			continue
		var feeling := relation(faction, other.id)
		if feeling > 30:
			changes[other.id] = _deed_on(other.id, amount / 4)
		elif feeling < -40:
			changes[other.id] = _deed_on(other.id, -amount / 10)
	return changes


func _deed_on(faction: StringName, amount: int) -> Array:
	var before := standing(faction)
	var life := current_life()
	if life:
		life.standing[faction] = clampi(host_standing(faction) + amount, -100, 100)
	legend[faction] = clampi(legend_standing(faction) + amount / 2, -100, 100)
	return [Standing.tier(before), Standing.tier(standing(faction))]


## Logs an event as a deed of the current host (week 32): fragment-sensing
## people remember it across lives (Legend).
func log_deed(type: StringName, actors: Array, details: Dictionary) -> EventRecord:
	var event := log_event(type, actors, details)
	var life := current_life()
	if life:
		life.deed_event_ids.append(event.id)
	return event


func add_ichor(amount: int) -> void:
	ichor = maxi(0, ichor + amount)


## Pours everything the host carries into the fragment's bank. Returns how much.
func bank_ichor() -> int:
	var amount := ichor
	ichor_banked += amount
	ichor = 0
	return amount


func has_boon(id: StringName) -> bool:
	return boons.has(id)


## Buys a boon with banked ichor. False if owned, unknown or too dear.
func buy_boon(id: StringName) -> bool:
	if has_boon(id) or not Boons.ALL.has(id) or ichor_banked < Boons.cost(id):
		return false
	ichor_banked -= Boons.cost(id)
	boons[id] = true
	return true


func record_kill(creature_kind: StringName) -> void:
	var life := current_life()
	if life:
		life.kills[creature_kind] = life.kills.get(creature_kind, 0) + 1


func new_id() -> int:
	next_id += 1
	return next_id - 1


## Puts the item in the first empty pocket. Returns the pocket, or -1 if full.
func add_to_inventory(item: StringName) -> int:
	var slot := inventory.find(&"")
	if slot >= 0:
		inventory[slot] = item
	return slot


## Empties the pocket and returns what was in it (&"" if it was empty).
func take_from_inventory(slot: int) -> StringName:
	if slot < 0 or slot >= inventory.size():
		return &""
	var item: StringName = inventory[slot]
	inventory[slot] = &""
	return item


## Grows a mutation into a body slot. Returns what was there before (&"" if empty).
func graft(slot: String, mutation: StringName) -> StringName:
	var old: StringName = mutations.get(slot, &"")
	mutations[slot] = mutation
	return old


func items_in_chunk(chunk: Vector2i) -> Array:
	return chunk_diffs.get(chunk, {}).get("items", [])


func add_dropped_item(chunk: Vector2i, item: StringName, pos: Vector2) -> Dictionary:
	var record := {"id": new_id(), "item": item, "pos": pos}
	chunk_diffs.get_or_add(chunk, {}).get_or_add("items", []).append(record)
	return record


func remove_dropped_item(chunk: Vector2i, record_id: int) -> void:
	var diff: Dictionary = chunk_diffs.get(chunk, {})
	var items: Array = diff.get("items", [])
	for i in items.size():
		if items[i].id == record_id:
			items.remove_at(i)
			break
	if items.is_empty():
		diff.erase("items")
	if diff.is_empty():
		chunk_diffs.erase(chunk)


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"year": year,
		"player_position": player_position,
		"player_health": player_health,
		"mutations": mutations.duplicate(),
		"inventory": inventory.duplicate(),
		"chunk_diffs": chunk_diffs.duplicate(true),
		"removed_entities": removed_entities.duplicate(),
		"next_id": next_id,
		"lives": lives.map(func(life): return life.to_dict()),
		"events": events.map(func(event): return event.to_dict()),
		"factions": factions.values().map(func(faction): return faction.to_dict()),
		"sites": sites.values().map(func(site): return site.to_dict()),
		"artifacts": artifacts.values().map(func(artifact): return artifact.to_dict()),
		"legend": legend.duplicate(),
		"ichor": ichor, "ichor_banked": ichor_banked, "boons": boons.duplicate(), "kept_graft": kept_graft.duplicate(),
	}


static func from_dict(d: Dictionary) -> WorldData:
	var data := WorldData.new()
	data.world_seed = int(d.get("world_seed", 0))
	data.year = int(d.get("year", 0))
	data.player_position = d.get("player_position", Vector2.ZERO)
	data.player_health = int(d.get("player_health", -1))
	data.mutations = d.get("mutations", {})
	data.inventory = d.get("inventory", [])
	data.chunk_diffs = d.get("chunk_diffs", {})
	data.removed_entities = d.get("removed_entities", {})
	data.next_id = int(d.get("next_id", 1))
	for life in d.get("lives", []):
		data.lives.append(LifeRecord.from_dict(life))
	for event in d.get("events", []):
		data.events.append(EventRecord.from_dict(event))
	for faction_dict in d.get("factions", []):
		var faction := FactionData.from_dict(faction_dict)
		data.factions[faction.id] = faction
	for site_dict in d.get("sites", []):
		var site := SiteData.from_dict(site_dict)
		data.sites[site.id] = site
	for artifact_dict in d.get("artifacts", []):
		var artifact := ArtifactData.from_dict(artifact_dict)
		data.artifacts[artifact.id] = artifact
	data.legend = d.get("legend", {}).duplicate()
	data.ichor = int(d.get("ichor", 0))
	data.ichor_banked = int(d.get("ichor_banked", 0))
	data.boons = d.get("boons", {}).duplicate()
	data.kept_graft = d.get("kept_graft", {}).duplicate()
	data._fit_inventory()
	return data


func _fit_inventory() -> void:
	while inventory.size() < INVENTORY_SIZE:
		inventory.append(&"")
	inventory.resize(INVENTORY_SIZE)
