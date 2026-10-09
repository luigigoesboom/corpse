extends Control
## Always-on gameplay HUD: short messages now; health and mutations later.

var _message_tween: Tween

@onready var _message: Label = $Message


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_message.modulate.a = 0.0
	EventBus.notify.connect(show_message)


func show_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_interval(1.2)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.5)
