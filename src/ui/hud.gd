extends Control
## Always-on gameplay HUD: health pips, mutation controls, short messages.

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

@onready var _message: Label = $Message
@onready var _mutations: Label = $Mutations


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_message.modulate.a = 0.0
	EventBus.notify.connect(show_message)
	EventBus.mutations_changed.connect(_refresh_mutations)
	EventBus.world_loaded.connect(_refresh_mutations)
	_refresh_mutations()


func bind_health(health: Health) -> void:
	_health = health
	health.changed.connect(func(_c, _m): queue_redraw())
	queue_redraw()


func _draw() -> void:
	if _health == null:
		return
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
