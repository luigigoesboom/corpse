class_name ItemLayer
extends Node2D
## Keeps item nodes in sync with WorldData, and handles picking up and dropping.
##
## Dropped items live in WorldData.chunk_diffs from the moment they are
## dropped. When a chunk loads, this spawns a WorldItem node for each of its
## records; when it unloads, those nodes are freed. Nothing to write back,
## because items do not change while lying around.
##
## Placed items (hand-placed under Entities in world.tscn) are owned by
## EntityLayer. Picking one up marks it in WorldData.removed_entities, so it
## never comes back, even after a save and load.
##
## Keep this node at position (0, 0).

const ITEM_SCENE := preload("res://src/items/world_item.tscn")

var _chunks: ChunkManager
var _spawned := {}  # Vector2i chunk -> Array of WorldItem, so unloading never depends on the data


func attach(chunks: ChunkManager) -> void:
	_chunks = chunks
	chunks.chunk_loaded.connect(_on_chunk_loaded)
	chunks.chunk_unloaded.connect(_on_chunk_unloaded)
	EventBus.pickup_requested.connect(_on_pickup_requested)
	EventBus.drop_requested.connect(_on_drop_requested)


func _on_chunk_loaded(coord: Vector2i) -> void:
	for record in WorldState.data.items_in_chunk(coord):
		_spawn(coord, record)


func _on_chunk_unloaded(coord: Vector2i) -> void:
	for item in _spawned.get(coord, []):
		if is_instance_valid(item):
			item.queue_free()
	_spawned.erase(coord)


func _spawn(coord: Vector2i, record: Dictionary) -> void:
	var item: WorldItem = ITEM_SCENE.instantiate()
	item.item_id = record.item
	item.record_id = record.id
	item.record_chunk = coord
	item.position = record.pos
	add_child(item)
	_spawned.get_or_add(coord, []).append(item)


func _on_drop_requested(pos: Vector2) -> void:
	var data := WorldState.data
	if data.inventory.is_empty():
		return
	var item_id: StringName = data.inventory.pop_back()
	var coord := ChunkData.world_to_chunk(pos)
	var record := data.add_dropped_item(coord, item_id, pos)
	if _chunks.is_loaded(coord):
		_spawn(coord, record)
	EventBus.inventory_changed.emit()


func _on_pickup_requested(item: Node) -> void:
	var world_item := item as WorldItem
	if world_item == null or not is_instance_valid(world_item):
		return
	var data := WorldState.data
	data.inventory.append(world_item.item_id)
	if world_item.is_placed():
		data.removed_entities[String(world_item.name)] = true
		# EntityLayer keeps the node; it just never re-adds a removed one.
		world_item.get_parent().remove_child(world_item)
	else:
		data.remove_dropped_item(world_item.record_chunk, world_item.record_id)
		_spawned.get(world_item.record_chunk, []).erase(world_item)
		world_item.queue_free()
	EventBus.inventory_changed.emit()
