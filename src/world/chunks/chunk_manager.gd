class_name ChunkManager
extends Node2D
## Keeps the chunks around `target` loaded and frees the rest.
##
## Each loaded chunk is its own TileMapLayer, positioned at the chunk's origin.
## Generating a chunk is cheap, but filling 4096 cells into a TileMapLayer in
## one frame causes a hitch, so new chunks are built a slice at a time
## (`cells_per_frame`). Moving generation to a worker thread is roadmap week 6.

signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

const TILE_SET := preload("res://assets/art/tiles/test_tileset.tres")
const ATLAS_EDGE := Vector2i(1, 1)   # Has collision.
const ATLAS_INNER := Vector2i(8, 2)  # No collision.

@export var target: Node2D
@export var world_seed := 1337
## Chunks loaded in each direction around the target's chunk. 1 means 3x3.
@export var load_radius := 1
@export var cells_per_frame := 2048

## Draws loaded chunk borders. Toggled by the F3 overlay.
var debug_draw := false:
	set(value):
		debug_draw = value
		queue_redraw()

var _generator: ChunkGenerator
var _layers := {}        # Vector2i -> TileMapLayer
var _pending := []       # [{coord, data, next}] chunks still being built
var _center := Vector2i(-9999, -9999)


func _ready() -> void:
	_generator = ChunkGenerator.new(world_seed)
	if target:
		target.global_position = ChunkGenerator.spawn_position()
		_update_center(true)


func _process(_delta: float) -> void:
	if target:
		_update_center(false)
	_build_some(cells_per_frame)


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
			if ChunkGenerator.in_world(c):
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
	# Generated lazily in _build_some(), so loading 3 chunks costs 3 frames, not 1.
	_pending.append({"coord": coord, "data": null, "next": 0})


func _unload(coord: Vector2i) -> void:
	_pending = _pending.filter(func(job): return job.coord != coord)
	_layers[coord].queue_free()
	_layers.erase(coord)
	chunk_unloaded.emit(coord)


## Fills up to `budget` cells into pending chunks. A budget of -1 means no limit.
## Generates at most one chunk per call unless the budget is unlimited.
func _build_some(budget: int) -> void:
	var generated := false
	while not _pending.is_empty() and budget != 0:
		var job: Dictionary = _pending[0]
		if job.data == null:
			if generated and budget > 0:
				return
			job.data = _generator.generate(job.coord)
			generated = true
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
