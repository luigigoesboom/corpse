class_name DebugMap
extends Control
## M toggles a full-screen view of the painted world map, with the player
## (red dot) and the currently loaded chunks (green boxes).

@export var player: Node2D
@export var chunks: ChunkManager

var _texture: ImageTexture
var _map_image: Image


func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	# Keep pixels sharp when the map is scaled up.
	texture_filter = TEXTURE_FILTER_NEAREST


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_map"):
		visible = not visible


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if not chunks or not chunks.map:
		return
	# Rebuild the texture only when the map was reloaded.
	if chunks.map.image != _map_image:
		_map_image = chunks.map.image
		_texture = ImageTexture.create_from_image(_map_image)

	var map_size := Vector2(chunks.map.size)
	var px := minf(size.x * 0.9 / map_size.x, size.y * 0.9 / map_size.y)  # Screen px per tile.
	var origin := (size - map_size * px) / 2.0

	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(origin, map_size * px), Color(0.92, 0.9, 0.85))  # Shows through transparent air.
	draw_texture_rect(_texture, Rect2(origin, map_size * px), false)

	var chunk_px := ChunkData.SIZE * px
	for c in chunks.get_children():
		var coord := ChunkData.world_to_chunk(c.position + Vector2.ONE)
		draw_rect(Rect2(origin + Vector2(coord) * chunk_px, Vector2.ONE * chunk_px), Color.LIME, false, 2.0)

	if player:
		var p := origin + player.global_position / ChunkData.TILE_PX * px
		draw_circle(p, maxf(3.0, px), Color.RED)
