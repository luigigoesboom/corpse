extends Node2D
## Stand-in NPC until real ones exist (roadmap week 27). Bobs so you can see
## it is alive, and shows its name when you come close. Rename it in the
## Inspector via `npc_name`.

@export var npc_name := "Parasite":
	set(value):
		npc_name = value
		if is_node_ready():
			$Name.text = value
## FactionDef id this NPC belongs to (week 26), or empty for none. Tints the
## name in the faction's color.
@export var faction: StringName

var _time := 0.0


func _ready() -> void:
	$Name.text = npc_name
	var def := FactionDb.get_def(faction) if faction != &"" else null
	if def:
		$Name.add_theme_color_override("font_color", def.color.lightened(0.3))
	_time = position.x  # So neighbors do not bob in sync.


func _process(delta: float) -> void:
	_time += delta
	$Visual.position.y = sin(_time * 3.0) * 2.0
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var dist := player.global_position.distance_to(global_position) if player else INF
	$Name.modulate.a = clampf(1.0 - (dist - 90.0) / 80.0, 0.0, 1.0)
