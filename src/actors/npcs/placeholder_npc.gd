extends Node2D
## Stand-in NPC until real ones exist (roadmap week 27). Bobs so you can see
## it is alive, and shows its name. Rename it in the Inspector via `npc_name`.

@export var npc_name := "Parasite":
	set(value):
		npc_name = value
		if is_node_ready():
			$Name.text = value

var _time := 0.0


func _ready() -> void:
	$Name.text = npc_name
	_time = position.x  # So neighbors do not bob in sync.


func _process(delta: float) -> void:
	_time += delta
	$Visual.position.y = sin(_time * 3.0) * 2.0
