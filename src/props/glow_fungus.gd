@tool
extends Node2D
## Glowing fungus: a small light source to place in caves. Set `hanging` for
## ones that grow down from a ceiling. @tool so the flip shows in the editor.

@export var hanging := false:
	set(value):
		hanging = value
		scale.y = -1.0 if value else 1.0
@export var light_color := Color(0.55, 1.0, 0.75):
	set(value):
		light_color = value
		if is_node_ready():
			$Light.color = value

var _phase := 0.0
var _base_energy := 0.0


func _ready() -> void:
	scale.y = -1.0 if hanging else 1.0
	$Light.color = light_color
	_base_energy = $Light.energy
	_phase = position.x * 0.13  # Neighbors do not pulse in sync.


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_phase += delta
	$Light.energy = _base_energy + sin(_phase * 1.7) * 0.12
