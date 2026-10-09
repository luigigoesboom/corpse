class_name ChunkManager
extends Node2D
## Keeps the chunks around `target` loaded and frees the rest.
##
## The world is the hand-painted WorldMap. Each loaded chunk is a 64 x 64 tile
## piece of it, built into its own TileMapLayer at the chunk's origin.
## Filling 4096 cells into a TileMapLayer in one frame causes a hitch, so new
## chunks are built a slice at a time (`cells_per_frame`).
##
## Nothing loads until reset() is called, after WorldState has a world.

signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

const TILE_SET := preload("res://assets/art/tiles/test_tileset.tres")
const ATLAS_EDGE := Vector2i(1, 1)   # Has collision.
const ATLAS_INNER := Vector2i(8, 2)  # No collision.

@export var target: Node2D
## Chunks loaded in each direction around the target's chunk. 1 means 3x3.
@export var load_radius := 1
@export var cells_per_frame := 2048

## Draws loaded chunk borders. Toggled by the F3 overlay.
var debug_draw := false:
	set(value):
		debug_draw = value
		queue_redraw()

var map := WorldMap.load_from()
var _ready_to_stream := false
var _layers := {}        # Vector2i -> TileMapLayer
var _pending := []       # [{coord, data, next}] chunks still being built
var _center := Vector2i(-9999, -9999)


## Drops every chunk and rebuilds the ones around the target, immediately.
## Call after starting or loading a world, once the target is in place.
func reset() -> void:
	for c in _layers.keys():
		_unload(c)
	_center = Vector2i(-9999, -9999)
	_ready_to_stream = true
	if target:
		_update_center(true)


## Reads the PNG again and rebuilds. For painting: save in Krita, press F4.
func reload_map() -> void:
	map = WorldMap.load_from()
	reset()


func _process(_delta: float) -> void:
	if not _ready_to_stream:
		return
	if target:
		_update_center(false)
	_build_some(cells_per_frame)


func is_loaded(coord: Vector2i) -> bool:
	return _layers.has(coord)


func loaded_count() -> int:
	return _layers.size()


func pending_count() -> int:
	return _pending.size()


func _update_center(build_now: bool) -> void:
	var center := ChunkData.world_to_chunk(target.global_position)
	if center == _center:
		return
	_center = center

	var wanted := {}
	for dy in range(-load_radius, load_radius + 1):
		for dx in range(-load_radius, load_radius + 1):
			var c := center + Vector2i(dx, dy)
			if map.has_chunk(c):
				wanted[c] = true

	for c in _layers.keys():
		if not wanted.has(c):
			_unload(c)
	# Nearest first, so the chunk you are walking into is ready soonest.
	var to_load := wanted.keys().filter(func(c): return not _layers.has(c))
	to_load.sort_custom(func(a, b): return (a - center).length_squared() < (b - center).length_squared())
	for c in to_load:
		_load(c)

	if build_now:
		_build_some(-1)
	queue_redraw()


func _load(coord: Vector2i) -> void:
	var layer := TileMapLayer.new()
	layer.name = "Chunk_%d_%d" % [coord.x, coord.y]
	layer.tile_set = TILE_SET
	layer.position = ChunkData.chunk_origin(coord)
	layer.show_behind_parent = true  # So the debug borders in _draw() sit on top.
	add_child(layer)
	_layers[coord] = layer
	# Cut from the map lazily in _build_some(), so loading 3 chunks costs 3 frames, not 1.
	_pending.append({"coord": coord, "data": null, "next": 0})


func _unload(coord: Vector2i) -> void:
	_pending = _pending.filter(func(job): return job.coord != coord)
	# Remove right away so a reloaded chunk can reuse the name this frame.
	remove_child(_layers[coord])
	_layers[coord].queue_free()
	_layers.erase(coord)
	chunk_unloaded.emit(coord)


## Fills up to `budget` cells into pending chunks. A budget of -1 means no limit.
## Cuts at most one chunk from the map per call unless the budget is unlimited.
func _build_some(budget: int) -> void:
	var cut := false
	while not _pending.is_empty() and budget != 0:
		var job: Dictionary = _pending[0]
		if job.data == null:
			if cut and budget > 0:
				return
			job.data = map.make_chunk(job.coord)
			cut = true
		var layer: TileMapLayer = _layers[job.coord]
		var cells: PackedByteArray = job.data.cells
		var total := cells.size()
		var end := total if budget < 0 else mini(total, job.next + budget)
		for i in range(job.next, end):
			match cells[i]:
				ChunkData.Cell.SOLID_EDGE:
					layer.set_cell(Vector2i(i % ChunkData.SIZE, i / ChunkData.SIZE), 0, ATLAS_EDGE)
				ChunkData.Cell.SOLID_INNER:
					layer.set_cell(Vector2i(i % ChunkData.SIZE, i / ChunkData.SIZE), 0, ATLAS_INNER)
		if budget > 0:
			budget -= end - job.next
		job.next = end
		if end == total:
			_pending.pop_front()
			chunk_loaded.emit(job.coord)
			queue_redraw()


func _draw() -> void:
	if not debug_draw:
		return
	var building := {}
	for job in _pending:
		building[job.coord] = true
	for c in _layers:
		var color := Color.YELLOW if building.has(c) else Color.LIME
		draw_rect(Rect2(ChunkData.chunk_origin(c), Vector2.ONE * ChunkData.SIZE_PX), color, false, 4.0)
