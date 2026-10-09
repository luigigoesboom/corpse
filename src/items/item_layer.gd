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
var _player: Player
var _spawned := {}  # Vector2i chunk -> Array of WorldItem, so unloading never depends on the data


func attach(chunks: ChunkManager, player: Player) -> void:
	_chunks = chunks
	_player = player
	chunks.chunk_loaded.connect(_on_chunk_loaded)
	chunks.chunk_unloaded.connect(_on_chunk_unloaded)
	EventBus.pickup_requested.connect(_on_pickup_requested)
	EventBus.drop_requested.connect(_on_drop_requested)
	EventBus.item_drop_requested.connect(_place_item)


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


func _on_drop_requested(slot: int) -> void:
	var item_id := WorldState.data.take_from_inventory(slot)
	if item_id == &"":
		return
	_place_item(item_id, _drop_position())
	EventBus.inventory_changed.emit()
	EventBus.notify.emit("Dropped %s" % ItemDb.display_name(item_id))


## Adds an item to the world data and shows it if its chunk is loaded.
func _place_item(item_id: StringName, pos: Vector2) -> void:
	var coord := ChunkData.world_to_chunk(pos)
	var record := WorldState.data.add_dropped_item(coord, item_id, pos)
	if _chunks.is_loaded(coord):
		_spawn(coord, record)


## On the ground a little in front of the player, so items never float.
func _drop_position() -> Vector2:
	var space := get_world_2d().direct_space_state
	var center := _player.global_position
	var front := center + Vector2(_player.facing() * 24.0, 0.0)
	# Not in front if a wall is there; then straight below the player.
	var wall := space.intersect_ray(PhysicsRayQueryParameters2D.create(center, front, 1))
	var from := center if wall else front
	var floor_hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 4000), 1))
	return floor_hit.position if floor_hit else from + Vector2(0, 22)


func _on_pickup_requested(item: Node) -> void:
	var world_item := item as WorldItem
	if world_item == null or not is_instance_valid(world_item):
		return
	var data := WorldState.data
	if data.add_to_inventory(world_item.item_id) < 0:
		EventBus.notify.emit("Pockets are full")
		return
	if world_item.is_placed():
		data.removed_entities[EntityLayer.key_of(world_item)] = true
		# EntityLayer keeps the node; it just never re-adds a removed one.
		world_item.get_parent().remove_child(world_item)
	else:
		data.remove_dropped_item(world_item.record_chunk, world_item.record_id)
		_spawned.get(world_item.record_chunk, []).erase(world_item)
		world_item.queue_free()
	EventBus.inventory_changed.emit()
	EventBus.notify.emit("+ %s" % ItemDb.display_name(world_item.item_id))
	Sfx.play(&"pickup")
