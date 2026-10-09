class_name CorpseLayer
extends Node2D
## Shows the bodies of dead hosts (WorldData.lives) and handles searching them.
##
## Like ItemLayer: the life records are the truth. When a chunk loads, a Corpse
## node appears for every dead host whose body lies in it; when it unloads,
## the node goes. Keep this node at position (0, 0).

const CORPSE_SCENE := preload("res://src/actors/corpse/corpse.tscn")

var _chunks: ChunkManager
var _spawned := {}  # Vector2i chunk -> Array of Corpse


func attach(chunks: ChunkManager) -> void:
	_chunks = chunks
	chunks.chunk_loaded.connect(_on_chunk_loaded)
	chunks.chunk_unloaded.connect(_on_chunk_unloaded)
	EventBus.corpse_search_requested.connect(_on_search_requested)


## Shows a body that just appeared (the host died where the player can see).
func add_corpse(index: int) -> void:
	var life: LifeRecord = WorldState.data.lives[index]
	var coord := ChunkData.world_to_chunk(life.corpse_position)
	if _chunks.is_loaded(coord):
		_spawn(coord, index)


func corpse_count() -> int:
	var n := 0
	for list in _spawned.values():
		n += list.size()
	return n


func _on_chunk_loaded(coord: Vector2i) -> void:
	var lives := WorldState.data.lives
	for i in lives.size():
		if not lives[i].is_alive() and ChunkData.world_to_chunk(lives[i].corpse_position) == coord:
			_spawn(coord, i)


func _on_chunk_unloaded(coord: Vector2i) -> void:
	for corpse in _spawned.get(coord, []):
		if is_instance_valid(corpse):
			corpse.queue_free()
	_spawned.erase(coord)


func _spawn(coord: Vector2i, index: int) -> void:
	var life: LifeRecord = WorldState.data.lives[index]
	var corpse: Corpse = CORPSE_SCENE.instantiate()
	corpse.setup(index, life)
	add_child(corpse)
	corpse.refresh(life)
	_spawned.get_or_add(coord, []).append(corpse)


func _on_search_requested(index: int) -> void:
	var data := WorldState.data
	var life: LifeRecord = data.lives[index]
	if not life.has_corpse_loot():
		EventBus.notify.emit("Nothing left on %s" % life.host_name)
		return
	var taken := data.reclaim_corpse(index)
	var names := PackedStringArray()
	for item in taken.items:
		names.append(ItemDb.display_name(item))
	for mutation in taken.mutations:
		var def := MutationDb.get_def(mutation)
		names.append(def.display_name if def else String(mutation))
	if names.is_empty():
		EventBus.notify.emit("Your pockets and body are full")
	else:
		var text := "From %s you take back: %s" % [life.host_name, ", ".join(names)]
		if life.has_corpse_loot():
			text += " (some is left)"
		EventBus.notify.emit(text)
		Sfx.play(&"eat" if not taken.mutations.is_empty() else &"pickup")
	for list in _spawned.values():
		for corpse in list:
			if corpse.life_index == index:
				corpse.refresh(life)
	EventBus.inventory_changed.emit()
	EventBus.mutations_changed.emit()
