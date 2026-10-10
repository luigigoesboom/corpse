@tool
extends Node2D
## Shows every terrain tile in use, joined the way the game joins them, so you
## can check new tile art for seams. Open scenes/tools/tile_preview.tscn: it
## updates in the editor when the tile sheet is re-exported. Run it (F6) to see
## it in the game's darkness, with a light that follows the mouse.
##
## `layout` uses the same rules as the world: # = rock, anything else = air,
## everything outside it is rock.

@export var tileset: TileSet = preload("res://assets/art/tiles/gut_tileset.tres"):
	set(value):
		tileset = value
		_rebuild()
@export_multiline var layout := "":
	set(value):
		layout = value
		_rebuild()


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	var dark := CanvasModulate.new()
	dark.color = Color(0.46, 0.35, 0.39)  # Same as Darkness in game.tscn.
	add_child(dark)
	var light := PointLight2D.new()
	light.name = "MouseLight"
	light.texture = preload("res://assets/lights/light_banded.tres")
	light.texture_scale = 3.0
	light.color = Color(1, 0.86, 0.72)
	light.energy = 0.8
	light.shadow_enabled = true
	light.position = Vector2(14, 7) * ChunkData.TILE_PX  # Middle of the room until the mouse moves.
	add_child(light)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and has_node("MouseLight"):
		$MouseLight.global_position = get_global_mouse_position()


func _rebuild() -> void:
	if not is_inside_tree() or layout.strip_edges().is_empty():
		return
	var terrain: TileMapLayer = get_node_or_null("Terrain")
	if terrain == null:
		terrain = TileMapLayer.new()
		terrain.name = "Terrain"
		add_child(terrain)
	terrain.tile_set = tileset
	terrain.clear()
	var rows := layout.strip_edges().split("\n")
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for y in rows.size():
		for x in mini(rows[y].length(), image.get_width()):
			if rows[y][x] == "#":
				image.set_pixel(x, y, Color.BLACK)
	# The layout's chunk plus the solid rock around it, like the arenas.
	var map := WorldMap.new(image)
	for cy in range(-1, 2):
		for cx in range(-1, 2):
			var origin := Vector2i(cx, cy) * ChunkData.SIZE
			var data := map.make_chunk(Vector2i(cx, cy))
			for i in data.cells.size():
				var cell := data.cells[i]
				if cell != ChunkData.EMPTY:
					terrain.set_cell(origin + Vector2i(i % ChunkData.SIZE, i / ChunkData.SIZE), 0,
						Vector2i((cell - 1) % 4, (cell - 1) / 4))
