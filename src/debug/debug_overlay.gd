class_name DebugOverlay
extends CanvasLayer
## F3 overlay: FPS, position, velocity, chunk coord, region, chunk loading.
##
## A CanvasLayer draws on top of the game, ignoring the camera, which is
## what you want for UI and debug text.

@export var player: Player
## Optional. Scenes without chunk streaming (the test room) leave it empty.
@export var chunks: ChunkManager
## Optional, like chunks.
@export var entities: EntityLayer

var _label := Label.new()


func _ready() -> void:
	layer = 100
	_label.position = Vector2(8, 48)  # Below the HUD health pips.
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(_label)
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_overlay"):
		visible = not visible
		if chunks:
			chunks.debug_draw = visible


func _process(_delta: float) -> void:
	if not visible or not player:
		return
	var pos := player.global_position
	var lines := PackedStringArray([
		"FPS %d" % Engine.get_frames_per_second(),
		"pos %.0f, %.0f   tile %d, %d" % [pos.x, pos.y, floori(pos.x / ChunkData.TILE_PX), floori(pos.y / ChunkData.TILE_PX)],
		"vel %.0f, %.0f" % [player.velocity.x, player.velocity.y],
		"chunk %s  region %s" % [ChunkData.world_to_chunk(pos), WorldMap.region_of(pos)],
		"floor %s  wall %s  cling %s  membrane %s" % [player.is_on_floor(), player.is_on_wall(), player.is_clinging(), player.is_on_membrane()],
	])
	if WorldState.data:
		lines.append("seed %d  year %d" % [WorldState.data.world_seed, WorldState.data.year])
		var life := WorldState.data.current_life()
		if life:
			lines.append("life %d: %s, %d s, kills %s" % [WorldState.data.lives.size(), life.host_name, life.seconds_alive, life.kills])
	if chunks:
		lines.append("chunks loaded %d  building %d" % [chunks.loaded_count(), chunks.pending_count()])
	if entities:
		lines.append("entities active %d / %d" % [entities.count_active(), entities.count_total()])
	_label.text = "\n".join(lines)
