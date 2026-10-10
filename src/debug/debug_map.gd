class_name DebugMap
extends Control
## M toggles a full-screen view of the painted world map, with the player
## (red dot), the currently loaded chunks (green boxes), old bodies (crosses)
## and faction territory (tinted chunks, names, and a legend).

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
	_draw_factions(origin, chunk_px)
	for c in chunks.get_children():
		var coord := ChunkData.world_to_chunk(c.position + Vector2.ONE)
		draw_rect(Rect2(origin + Vector2(coord) * chunk_px, Vector2.ONE * chunk_px), Color.LIME, false, 2.0)

	# Old bodies: grey crosses (brighter while something is still on them).
	if WorldState.data:
		for life in WorldState.data.lives:
			if not life.is_alive():
				var c := origin + life.corpse_position / ChunkData.TILE_PX * px
				var col := Color(0.9, 0.85, 0.7) if life.has_corpse_loot() else Color(0.5, 0.5, 0.5)
				draw_line(c + Vector2(-4, -4), c + Vector2(4, 4), col, 2.0)
				draw_line(c + Vector2(-4, 4), c + Vector2(4, -4), col, 2.0)

	if player:
		var p := origin + player.global_position / ChunkData.TILE_PX * px
		draw_circle(p, maxf(3.0, px), Color.RED)

	var font := get_theme_default_font()
	var y := 20.0
	for line in legend_lines():
		draw_string(font, Vector2(10, y), line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, line.color)
		y += 14.0


## Each faction's chunks tinted in its color, its name over the middle of them.
func _draw_factions(origin: Vector2, chunk_px: float) -> void:
	if WorldState.data == null:
		return
	var font := get_theme_default_font()
	for faction: FactionData in WorldState.data.factions.values():
		var def := FactionDb.get_def(faction.id)
		if def == null or not faction.is_alive() or faction.territory.is_empty():
			continue
		var middle := Vector2.ZERO
		for chunk in faction.territory:
			var rect := Rect2(origin + Vector2(chunk) * chunk_px, Vector2.ONE * chunk_px)
			draw_rect(rect, Color(def.color, 0.35))
			draw_rect(rect.grow(-2.0), def.color, false, 2.0)
			middle += rect.get_center()
		middle /= faction.territory.size()
		var width := font.get_string_size(def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_string_outline(font, middle - Vector2(width / 2.0, 0), def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
		draw_string(font, middle - Vector2(width / 2.0, 0), def.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, def.color.lightened(0.4))


## The legend, one line per faction: name, strength, chunks held, relations.
func legend_lines() -> Array:
	var lines := []
	if WorldState.data == null:
		return lines
	var factions: Dictionary = WorldState.data.factions
	for id in FactionDb.all_ids():
		if not factions.has(id):
			continue
		var faction: FactionData = factions[id]
		var def := FactionDb.get_def(id)
		var feelings := PackedStringArray()
		for other in faction.relations:
			var other_def := FactionDb.get_def(other)
			feelings.append("%s %+d" % [other_def.display_name if other_def else String(other), faction.relations[other]])
		lines.append({
			"text": "%s: strength %d, %d chunks%s" % [def.display_name, faction.strength, faction.territory.size(),
				("; " + ", ".join(feelings)) if not feelings.is_empty() else ""],
			"color": def.color.lightened(0.3),
		})
	return lines
