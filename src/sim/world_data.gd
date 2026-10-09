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

var world_seed: int
var year: int = 0
## Where the current host is. Written by the game right before saving.
var player_position := Vector2.ZERO
## Item ids the current host carries. Moves into LifeRecord in week 21.
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


static func create(seed_value: int) -> WorldData:
	var data := WorldData.new()
	data.world_seed = seed_value
	return data


func new_id() -> int:
	next_id += 1
	return next_id - 1


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
		"inventory": inventory.duplicate(),
		"chunk_diffs": chunk_diffs.duplicate(true),
		"removed_entities": removed_entities.duplicate(),
		"next_id": next_id,
	}


static func from_dict(d: Dictionary) -> WorldData:
	var data := WorldData.new()
	data.world_seed = int(d.get("world_seed", 0))
	data.year = int(d.get("year", 0))
	data.player_position = d.get("player_position", Vector2.ZERO)
	data.inventory = d.get("inventory", [])
	data.chunk_diffs = d.get("chunk_diffs", {})
	data.removed_entities = d.get("removed_entities", {})
	data.next_id = int(d.get("next_id", 1))
	return data
