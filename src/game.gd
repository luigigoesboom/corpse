extends Node2D
## Top-level game scene: starts or continues a world, handles save / load,
## and rebuilds the scene whenever WorldState gets a new world.

## Seed for the world created on start. 0 = a random seed every run.
## The terrain is hand-painted and always the same; the seed is for things
## that should differ per save (history, later).
@export var new_world_seed := 0

@onready var _player: Player = $Player
@onready var _chunks: ChunkManager = $ChunkManager
@onready var _world: Node2D = $World
@onready var _items: ItemLayer = $Items
@onready var _entities: EntityLayer = $World/Entities


func _ready() -> void:
	EventBus.world_loaded.connect(_on_world_loaded)
	EventBus.player_died.connect(_on_player_died)
	_entities.attach(_chunks)
	_items.attach(_chunks, _player)
	$UI/HUD.bind_health(_player.health)
	_player.health.changed.connect(_on_player_health_changed)
	$UI/PauseMenu.save_pressed.connect(quick_save)
	$UI/PauseMenu.load_pressed.connect(quick_load)
	if WorldState.data:
		# "Continue" in the main menu already loaded a save.
		_on_world_loaded()
	else:
		_start_new_world()


func _start_new_world() -> void:
	# randi() is fine here: picking a seed is not generation.
	var seed_value := new_world_seed if new_world_seed != 0 else randi()
	var data := WorldData.create(seed_value)
	data.player_position = _world.get_node("PlayerSpawn").global_position
	WorldState.set_data(data)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		quick_save()
	elif event.is_action_pressed("quick_load"):
		quick_load()
	elif event.is_action_pressed("reload_map"):
		_chunks.reload_map()
		EventBus.notify.emit("Map reloaded (%d x %d)" % [_chunks.map.size.x, _chunks.map.size.y])


func quick_save() -> void:
	if _player.is_dead():
		EventBus.notify.emit("Cannot save now")
		return
	# The sim never reads nodes, so the game copies node state into the data first.
	WorldState.data.player_position = _player.global_position
	var err := SaveSystem.save_game(0)
	EventBus.notify.emit("Saved" if err == OK else "Save failed: %s" % error_string(err))


func quick_load() -> void:
	var err := SaveSystem.load_game(0)
	EventBus.notify.emit("Loaded" if err == OK else "Load failed: %s" % error_string(err))


func _on_world_loaded() -> void:
	var data := WorldState.data
	var saved_health := data.player_health  # respawn() heals, which overwrites it.
	_player.respawn(data.player_position)
	if saved_health >= 0:
		_player.health.set_current(saved_health)
	_entities.rebuild()
	_chunks.reset()
	# Jump the camera straight there instead of smoothly panning across the map.
	_player.get_node("Camera2D").reset_smoothing()


func _on_player_health_changed(current: int, max_value: int) -> void:
	WorldState.data.player_health = -1 if current == max_value else current


## Placeholder until death and rebirth (roadmap week 21): wake up at the spawn.
func _on_player_died() -> void:
	EventBus.notify.emit("Your host has died")
	await get_tree().create_timer(2.0).timeout
	_player.respawn(_world.get_node("PlayerSpawn").global_position)
	_player.get_node("Camera2D").reset_smoothing()
