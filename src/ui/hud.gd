extends Control
## Always-on gameplay HUD: health pips, mutation controls, short messages.

const PIP_SIZE := Vector2(18, 18)
const PIP_GAP := 6.0

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
	for i in _health.max_health:
		var rect := Rect2(Vector2(16 + i * (PIP_SIZE.x + PIP_GAP), 16), PIP_SIZE)
		draw_rect(rect.grow(2), Color(0.1, 0.03, 0.04))
		if i < _health.current:
			draw_rect(rect, Color(0.85, 0.25, 0.3))


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
