extends Control
## Always-on gameplay HUD: health pips, ichor, mutation controls, short
## messages, and (with the sense_bodies boon) a mark pointing to your last body.

## One heart per hit point, drawn as pixel rows (1 = filled).
const HEART := [
	"0110110",
	"1111111",
	"1111111",
	"0111110",
	"0011100",
	"0001000",
]
const HEART_PIXEL := 3.0
const HEART_GAP := 6.0

var _message_tween: Tween
var _health: Health
var minimap: Minimap
var _ichor: Label
var _ichor_shown := 0

@onready var _message: Label = $Message
@onready var _mutations: Label = $Mutations


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_message.modulate.a = 0.0
	EventBus.notify.connect(show_message)
	EventBus.mutations_changed.connect(_refresh_mutations)
	EventBus.world_loaded.connect(_refresh_mutations)
	_refresh_mutations()
	minimap = Minimap.new()
	minimap.name = "Minimap"
	add_child(minimap)
	minimap.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 8)
	_ichor = Label.new()
	_ichor.position = Vector2(30, 34)
	_ichor.add_theme_color_override(&"font_color", Color(1, 0.45, 0.45))
	_ichor.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_ichor.add_theme_constant_override(&"outline_size", 3)
	add_child(_ichor)
	EventBus.ichor_changed.connect(_refresh_ichor)
	EventBus.world_loaded.connect(_refresh_ichor)
	EventBus.inventory_changed.connect(_refresh_ichor)  # Reclaiming a body.
	_refresh_ichor()


## Shows the minimap (top right) for this map and player.
func bind_map(chunks: ChunkManager, player: Node2D) -> void:
	minimap.bind(chunks, player)


func bind_health(health: Health) -> void:
	_health = health
	health.changed.connect(func(_c, _m): queue_redraw())
	queue_redraw()


func _process(_delta: float) -> void:
	if WorldState.data and WorldState.data.has_boon(&"sense_bodies"):
		queue_redraw()  # The mark follows the camera.


func _refresh_ichor() -> void:
	var now: int = WorldState.data.ichor if WorldState.data else 0
	_ichor.text = str(now)
	if now > _ichor_shown:
		var tween := create_tween()
		_ichor.scale = Vector2.ONE * 1.3
		tween.tween_property(_ichor, "scale", Vector2.ONE, 0.25)
	_ichor_shown = now
	queue_redraw()


func _draw() -> void:
	if _health == null:
		return
	# Ichor: a drop beside the count.
	var drop := Vector2(20, 44)
	draw_colored_polygon(PackedVector2Array([drop + Vector2(0, -8), drop + Vector2(5, 0), drop + Vector2(0, 5), drop + Vector2(-5, 0)]), Color(0.86, 0.2, 0.24))
	draw_rect(Rect2(drop + Vector2(-1, -3), Vector2(2, 2)), Color(1, 0.75, 0.7))
	_draw_body_sense()
	var width: float = HEART[0].length() * HEART_PIXEL
	for i in _health.max_health:
		var origin := Vector2(16 + i * (width + HEART_GAP), 16)
		var full := i < _health.current
		for row in HEART.size():
			for col in HEART[row].length():
				if HEART[row][col] == "1":
					var color := Color(0.88, 0.22, 0.28) if full else Color(0.22, 0.07, 0.09)
					if full and row == 1 and col == 1:
						color = Color(1, 0.7, 0.7)  # Shine.
					draw_rect(Rect2(origin + Vector2(col, row) * HEART_PIXEL, Vector2.ONE * HEART_PIXEL), color)


func _refresh_mutations() -> void:
	var parts := PackedStringArray()
	if WorldState.data:
		for slot in WorldState.data.mutations:
			var def := MutationDb.get_def(WorldState.data.mutations[slot])
			if def:
				parts.append("%s: %s" % [def.control_hint, def.display_name])
	_mutations.text = "    ".join(parts)


func show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.2)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.5)


## Boons sense_bodies: a mark at the screen edge toward the newest old body
## with anything left on it, or on the body itself when it is on screen.
func _draw_body_sense() -> void:
	var data := WorldState.data
	if data == null or not data.has_boon(&"sense_bodies"):
		return
	var target: LifeRecord = null
	for i in range(data.lives.size() - 1, -1, -1):
		if not data.lives[i].is_alive() and data.lives[i].has_corpse_loot():
			target = data.lives[i]
			break
	if target == null:
		return
	var screen := get_viewport().get_canvas_transform() * (target.corpse_position + Vector2(0, -40))
	var rect := get_viewport_rect().grow(-24)
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
	var color := Color(1, 0.35, 0.35, pulse)
	if rect.has_point(screen):
		draw_colored_polygon(PackedVector2Array([screen + Vector2(-6, -8), screen + Vector2(6, -8), screen + Vector2(0, 0)]), color)
		return
	var center := rect.get_center()
	var dir := (screen - center).normalized()
	var t := INF
	if dir.x != 0.0:
		t = minf(t, (rect.size.x / 2.0) / absf(dir.x))
	if dir.y != 0.0:
		t = minf(t, (rect.size.y / 2.0) / absf(dir.y))
	var tip := center + dir * t
	var side := dir.orthogonal() * 6.0
	draw_colored_polygon(PackedVector2Array([tip, tip - dir * 12.0 + side, tip - dir * 12.0 - side]), color)
