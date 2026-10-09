@tool
class_name MapPreview
extends Node2D
## Shows the painted world.png in the editor at real size, with a chunk grid,
## so you can place NPCs, props and the spawn point on top of it.
##
## @tool means this script also runs inside the editor, not just in the game.
## It refreshes by itself when the PNG changes (export from Krita, then click
## back into Godot). When the game runs it removes itself: the real terrain
## comes from ChunkManager.

@export var show_chunk_grid := true:
	set(value):
		show_chunk_grid = value
		if _grid:
			_grid.queue_redraw()

var _sprite: Sprite2D
var _grid: Node2D
var _map_size := Vector2i.ZERO
var _modified_time := 0
var _check_timer := 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		queue_free()
		return
	# Helper children are created in code and never saved into the scene.
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.scale = Vector2.ONE * ChunkData.TILE_PX
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/world/map_preview.gdshader")
	_sprite.material = material
	add_child(_sprite)
	_grid = Node2D.new()
	_grid.draw.connect(_draw_grid)
	add_child(_grid)
	_reload()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 1.0
	if FileAccess.get_modified_time(WorldMap.DEFAULT_PATH) != _modified_time:
		_reload()


func _reload() -> void:
	_modified_time = FileAccess.get_modified_time(WorldMap.DEFAULT_PATH)
	var img := WorldMap.read_image()
	_map_size = img.get_size()
	_sprite.texture = ImageTexture.create_from_image(img)
	_grid.queue_redraw()


func _draw_grid() -> void:
	if not show_chunk_grid:
		return
	var color := Color(1, 1, 1, 0.25)
	var world_px := Vector2(_map_size * ChunkData.TILE_PX)
	var chunks := (_map_size + Vector2i.ONE * (ChunkData.SIZE - 1)) / ChunkData.SIZE
	for x in chunks.x + 1:
		_grid.draw_line(Vector2(x * ChunkData.SIZE_PX, 0), Vector2(x * ChunkData.SIZE_PX, world_px.y), color, 4.0)
	for y in chunks.y + 1:
		_grid.draw_line(Vector2(0, y * ChunkData.SIZE_PX), Vector2(world_px.x, y * ChunkData.SIZE_PX), color, 4.0)
