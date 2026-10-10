class_name EntityLayer
extends Node2D
## Holds everything placed by hand in the world scene: NPCs, enemies, props, items.
##
## In the editor, just add them as children of this node and drag them onto the
## map. When the game runs:
## - What you placed becomes a set of templates. Live entities are fresh
##   copies of them, made by rebuild() whenever a world starts or a save loads.
##   Placed entities are not saved; only whether one is gone for good is
##   (WorldData.removed_entities, keyed by the name you gave it in the editor).
## - Each live entity is only in the scene tree while its chunk is loaded.
##   Outside that it is detached: it keeps its state but costs no processing
##   or drawing. That keeps a huge world with thousands of things cheap.
##
## Keep this node at position (0, 0), unrotated and unscaled. Child names must
## stay unique and stable: saves refer to placed entities by name.

var _chunks: ChunkManager
var _templates: Array[Node2D] = []
var _buckets := {}  # Vector2i chunk coord -> Array of live Node2D


## The save key of a placed entity: the name it has in world.tscn.
static func key_of(entity: Node) -> String:
	return entity.get_meta(&"entity_key", String(entity.name))


## Turns the placed children into templates. Call once, then rebuild().
func attach(chunks: ChunkManager) -> void:
	_chunks = chunks
	for child in get_children():
		if child is Node2D:
			child.set_meta(&"entity_key", String(child.name))
			remove_child(child)
			_templates.append(child)
	chunks.chunk_loaded.connect(_on_chunk_loaded)
	chunks.chunk_unloaded.connect(_on_chunk_unloaded)
	EventBus.entity_killed.connect(_on_entity_killed)


## Throws away the live entities and makes fresh ones from the templates,
## skipping the ones WorldState says are gone. Call before ChunkManager.reset().
func rebuild() -> void:
	for list in _buckets.values():
		for entity in list:
			if entity.get_parent() == self:
				remove_child(entity)
			entity.free()
	_buckets.clear()
	for template in _templates:
		var key := key_of(template)
		if WorldState.data.removed_entities.has(key):
			continue
		var entity := template.duplicate() as Node2D
		entity.set_meta(&"entity_key", key)
		_buckets.get_or_add(ChunkData.world_to_chunk(entity.position), []).append(entity)


## Detached nodes are not in the tree, so Godot will not free them with the
## scene. Do it here when this layer goes away.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for list in _buckets.values():
			for entity in list:
				if is_instance_valid(entity) and entity.get_parent() == null:
					entity.free()
		for template in _templates:
			if is_instance_valid(template):
				template.free()


## What was placed in world.tscn (not live copies; never add these to the tree).
func templates() -> Array[Node2D]:
	return _templates


func count_active() -> int:
	return get_child_count()


func count_total() -> int:
	var n := 0
	for list in _buckets.values():
		n += list.size()
	return n


func _on_chunk_loaded(coord: Vector2i) -> void:
	for entity in _buckets.get(coord, []):
		# Entities gone for good (picked up, killed) stay detached.
		if entity.get_parent() == null and not WorldState.data.removed_entities.has(key_of(entity)):
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


func _on_entity_killed(entity: Node) -> void:
	if entity.get_parent() != self:
		return
	WorldState.data.removed_entities[key_of(entity)] = CombatRules.kind_of(entity)
	remove_child.call_deferred(entity)
