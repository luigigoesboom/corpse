class_name EntityLayer
extends Node2D
## Holds everything placed by hand in the world scene: NPCs, props, items.
##
## In the editor, just add them as children of this node and drag them onto the
## map. When the game runs, each one is only in the scene tree while its chunk
## is loaded. Outside that it is detached: it keeps its state but costs no
## processing or drawing. That keeps a huge world with thousands of things cheap.
##
## Keep this node at position (0, 0), unrotated and unscaled.

var _chunks: ChunkManager
var _buckets := {}  # Vector2i chunk coord -> Array of Node2D


## Takes every child out of the tree until its chunk loads.
func attach(chunks: ChunkManager) -> void:
	_chunks = chunks
	for child in get_children():
		if child is Node2D:
			_buckets.get_or_add(ChunkData.world_to_chunk(child.position), []).append(child)
			remove_child(child)
	chunks.chunk_loaded.connect(_on_chunk_loaded)
	chunks.chunk_unloaded.connect(_on_chunk_unloaded)


## Detached entities are not in the tree, so Godot will not free them with the
## scene. Do it here when this layer goes away.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for list in _buckets.values():
			for entity in list:
				if is_instance_valid(entity) and entity.get_parent() == null:
					entity.free()


func count_active() -> int:
	return get_child_count()


func count_total() -> int:
	var n := 0
	for list in _buckets.values():
		n += list.size()
	return n


func _on_chunk_loaded(coord: Vector2i) -> void:
	for entity in _buckets.get(coord, []):
		if entity.get_parent() == null:
			add_child(entity)


func _on_chunk_unloaded(coord: Vector2i) -> void:
	var list: Array = _buckets.get(coord, [])
	_buckets.erase(coord)
	for entity in list:
		# Things that wandered into another chunk move to that chunk's list,
		# and stay active if that chunk is still loaded.
		var now := ChunkData.world_to_chunk(entity.position)
		_buckets.get_or_add(now, []).append(entity)
		if entity.get_parent() == self and (now == coord or not _chunks.is_loaded(now)):
			remove_child(entity)
