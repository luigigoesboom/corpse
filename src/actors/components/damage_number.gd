class_name DamageNumber
extends Label
## Floating number that rises and fades. Debug-style feedback for hits.


static func spawn(parent: Node, world_position: Vector2, amount: int, color := Color.WHITE) -> void:
	var label := DamageNumber.new()
	label.text = str(amount)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.position = world_position + Vector2(-8, -40)
	label.z_index = 50
	parent.add_child(label)


func _ready() -> void:
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position:y", position.y - 28.0, 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(queue_free)
