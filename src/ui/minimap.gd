class_name Minimap
extends Control
## The minimap (after week 41): the caves around the host as seen so far,
## one pixel per tile, in the HUD's top-right corner. Walls take the color
## of their kind of rock; unseen places stay dark. Marks: you (pulsing),
## settlements (gold), ruins (grey), heart-roots (red), the shaft watch
## (orange), and your last body if the fragment can sense it (Boons).
##
## The HUD makes it; the game calls HUD.bind_map() with its ChunkManager
## (for the map) and the player. Other things show up by joining the group
## "minimap_marks" with a "minimap_color" meta (ruins, heart-roots).
## Revealing happens here too: about a screen around the host, a few times
## a second (WorldData.reveal, saved with the world).

const VIEW := Vector2i(120, 68)  # Tiles shown.
const REFRESH := 0.25
const UNSEEN := Color(0.05, 0.02, 0.03, 0.8)
const AIR := Color(0.27, 0.11, 0.12, 0.85)
## How far around the host counts as seen (tiles): about the screen.
const SIGHT := Vector2i(11, 7)

var _chunks: ChunkManager
var _player: Node2D
var _image: Image
var _texture: ImageTexture
var _timer := 0.0
var _blink := 0.0
var _centre := Vector2i.ZERO
var _marks: Array = []  # [tile Vector2i, Color]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(VIEW) + Vector2(4, 4)
	size = custom_minimum_size
	_image = Image.create(VIEW.x, VIEW.y, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)


func bind(chunks: ChunkManager, player: Node2D) -> void:
	_chunks = chunks
	_player = player


func _process(delta: float) -> void:
	_blink += delta
	_timer -= delta
	if _timer > 0.0:
		queue_redraw()
		return
	_timer = REFRESH
	var data := WorldState.data
	if data == null or _chunks == null or not is_instance_valid(_player):
		return
	var tile := Vector2i((_player.global_position / ChunkData.TILE_PX).floor())
	data.reveal(Rect2i(tile - SIGHT, SIGHT * 2 + Vector2i.ONE))
	_centre = tile
	_redraw_image(data)
	queue_redraw()


func _redraw_image(data: WorldData) -> void:
	var map: WorldMap = _chunks.map
	var origin := _centre - VIEW / 2
	for y in VIEW.y:
		for x in VIEW.x:
			var t := origin + Vector2i(x, y)
			var c := UNSEEN
			if data.is_explored(t):
				if map.is_solid(t):
					# Only the rock next to open space is drawn: the walls.
					var edge := not map.is_solid(t + Vector2i.UP) or not map.is_solid(t + Vector2i.DOWN) \
						or not map.is_solid(t + Vector2i.LEFT) or not map.is_solid(t + Vector2i.RIGHT)
					c = RockKinds.map_color(ChunkData.KINDS[map.kind_at(t)]) if edge else UNSEEN
				else:
					c = AIR
			_image.set_pixel(x, y, c)
	_texture.update(_image)
	_marks = _find_marks(data, origin)


func _find_marks(data: WorldData, origin: Vector2i) -> Array:
	var out := []
	var view := Rect2i(origin, VIEW)
	for node in get_tree().get_nodes_in_group(&"settlements"):
		var t := Vector2i(((node as Node2D).global_position / ChunkData.TILE_PX).floor()) + Vector2i(0, -1)
		if view.has_point(t) and data.is_explored(t):
			out.append([t - origin, Color8(224, 184, 74) if not node is GuardPost else Color8(255, 176, 64)])
	for node in get_tree().get_nodes_in_group(&"minimap_marks"):
		var t := Vector2i(((node as Node2D).global_position / ChunkData.TILE_PX).floor()) + Vector2i(0, -1)
		if view.has_point(t) and data.is_explored(t):
			out.append([t - origin, node.get_meta(&"minimap_color", Color.WHITE)])
	if data.has_boon(&"sense_bodies"):
		for i in range(data.lives.size() - 1, -1, -1):
			var life: LifeRecord = data.lives[i]
			if not life.is_alive() and life.has_corpse_loot():
				var t := Vector2i((life.corpse_position / ChunkData.TILE_PX).floor()) + Vector2i(0, -1)
				if view.has_point(t):
					out.append([t - origin, Color.WHITE])
				break
	return out


func _draw() -> void:
	var frame := Rect2(Vector2.ZERO, Vector2(VIEW) + Vector2(4, 4))
	draw_rect(frame, Color8(30, 15, 18))
	draw_rect(frame.grow(-1), Color8(185, 171, 136), false, 1.0)
	draw_texture(_texture, Vector2(2, 2))
	for mark in _marks:
		draw_rect(Rect2(Vector2(mark[0]) + Vector2(1, 1), Vector2(3, 3)), mark[1])
	var you := Color.WHITE if fmod(_blink, 0.8) < 0.55 else Color(0.55, 0.85, 1.0)
	draw_rect(Rect2(Vector2(VIEW / 2) + Vector2(1, 1), Vector2(3, 3)), you)
