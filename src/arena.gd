extends Node2D
## Combat test arena (roadmap week 19). Two of these exist to compare combat
## styles before deciding in week 20: tight and punishing vs loose and systemic.
##
## The room comes from `layout` (# = rock, anything else = air), built with
## the same autotiling as the world. Creatures go under Enemies, the start
## under PlayerSpawn. Clear the room; R restarts, Esc goes back to the menu.

const MAIN_MENU := "res://scenes/main_menu.tscn"

@export var arena_name := "Arena"
@export_multiline var layout := ""
@export var player_health := 5
## Mutation ids the player starts with.
@export var mutations: Array[StringName] = []
## Enemy attacks also hurt other creatures (systemic style).
@export var friendly_fire := false

var _start_ms := 0
var _hits_taken := 0
var _enemies_left := 0
var _done := false

@onready var _player: Player = $Player


func _ready() -> void:
	CombatRules.friendly_fire = friendly_fire
	_build_terrain()
	# The player, HUD and mutations read WorldState: give them a throwaway world.
	var data := WorldData.create(1)
	for id in mutations:
		data.mutations[MutationDb.get_def(id).slot] = id
	WorldState.set_data(data)
	_player.health.max_health = player_health
	_player.respawn($PlayerSpawn.global_position)
	_player.get_node("Camera2D").reset_smoothing()
	$UI/HUD.bind_health(_player.health)
	EventBus.entity_killed.connect(_on_enemy_killed)
	EventBus.hit_landed.connect(_on_hit_landed)
	EventBus.player_died.connect(_on_player_died)
	_enemies_left = $Enemies.get_child_count()
	_start_ms = Time.get_ticks_msec()
	EventBus.notify.emit("%s: clear the room. R restarts, Esc for the menu" % arena_name)


func _exit_tree() -> void:
	CombatRules.friendly_fire = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
	elif event.is_action_pressed("pause"):
		get_tree().change_scene_to_file(MAIN_MENU)


func enemies_left() -> int:
	return _enemies_left


func _build_terrain() -> void:
	var rows := layout.strip_edges().split("\n")
	var image := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	for y in rows.size():
		for x in mini(rows[y].length(), image.get_width()):
			if rows[y][x] == "#":
				image.set_pixel(x, y, Color.BLACK)
	var map := WorldMap.new(image)
	# The room's chunk plus the ring around it, which is solid rock (outside
	# the layout counts as rock), so the camera never sees past the walls.
	for cy in range(-1, 2):
		for cx in range(-1, 2):
			var coord := Vector2i(cx, cy)
			ChunkManager.fill_layer($Terrain, map.make_chunk(coord), coord * ChunkData.SIZE)


func _on_enemy_killed(enemy: Node) -> void:
	enemy.queue_free()
	_enemies_left -= 1
	if _enemies_left == 0 and not _done:
		_done = true
		EventBus.notify.emit("Clear in %.1f s, %d hits taken. R to go again" % [
			(Time.get_ticks_msec() - _start_ms) / 1000.0, _hits_taken])


func _on_hit_landed(target: Node, _amount: int) -> void:
	if target == _player:
		_hits_taken += 1


func _on_player_died() -> void:
	EventBus.notify.emit("Your host died. R to try again")
