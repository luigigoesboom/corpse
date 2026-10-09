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
## Node names of hand-placed entities (children of Entities in world.tscn) that
## are gone for good, e.g. an item someone picked up. name -> true
var removed_entities: Dictionary = {}
## Next free ID for things created at runtime (dropped items, later corpses).
var next_id := 1
## Every host the player has had, oldest first (LifeRecord). The last one is
## the current host while it is alive.
var lives: Array[LifeRecord] = []


static func create(seed_value: int) -> WorldData:
	var data := WorldData.new()
	data.world_seed = seed_value
	data._fit_inventory()
	return data


## The current host's record, or null between death and the next host.
func current_life() -> LifeRecord:
	if lives.is_empty() or not lives[-1].is_alive():
		return null
	return lives[-1]


func start_life(host_type: StringName) -> LifeRecord:
	var life := LifeRecord.new()
	life.host_type = host_type
	life.host_name = Names.host_name(world_seed, lives.size())
	life.start_year = year
	lives.append(life)
	return life


## Closes the current life: when, where, how, and what the body held.
func end_life(position: Vector2, killed_by: StringName) -> LifeRecord:
	var life := current_life()
	if life == null:
		return null
	life.death_year = year
	life.death_position = position
	life.killed_by = killed_by
	life.carried_items = inventory.filter(func(item): return item != &"")
	life.carried_mutations = mutations.duplicate()
	return life


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
	data._fit_inventory()
	return data


func _fit_inventory() -> void:
	while inventory.size() < INVENTORY_SIZE:
		inventory.append(&"")
	inventory.resize(INVENTORY_SIZE)
