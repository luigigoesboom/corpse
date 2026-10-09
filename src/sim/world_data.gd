class_name WorldData
extends RefCounted
## The whole simulated world as plain data. No nodes, no object references.
##
## Anything that must survive save/load lives here (or in data this points to by
## ID). Generated terrain is NOT stored: it is regenerated from world_seed.
## Only changes to it are, in chunk_diffs.
##
## To add a field: add it here, write it in to_dict(), read it with a default in
## from_dict(), and if old saves need fixing up, add a step in SaveSystem._migrate().

var world_seed: int
var year: int = 0
## Where the current host is. Written by the game right before saving.
var player_position := Vector2.ZERO
## Vector2i chunk coord -> dictionary of changes to that chunk's generated
## terrain (broken walls, dropped items). Filled from roadmap week 8. Unloaded
## chunks keep their changes here, so they survive leaving the area and saving.
var chunk_diffs: Dictionary = {}


static func create(seed_value: int) -> WorldData:
	var data := WorldData.new()
	data.world_seed = seed_value
	return data


func to_dict() -> Dictionary:
	return {
		"world_seed": world_seed,
		"year": year,
		"player_position": player_position,
		"chunk_diffs": chunk_diffs.duplicate(true),
	}


static func from_dict(d: Dictionary) -> WorldData:
	var data := WorldData.new()
	data.world_seed = int(d.get("world_seed", 0))
	data.year = int(d.get("year", 0))
	data.player_position = d.get("player_position", Vector2.ZERO)
	data.chunk_diffs = d.get("chunk_diffs", {})
	return data
