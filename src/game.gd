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


func _ready() -> void:
	EventBus.world_loaded.connect(_on_world_loaded)
	(_world.get_node("Entities") as EntityLayer).attach(_chunks)
	_items.attach(_chunks, _player)
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
	# The sim never reads nodes, so the game copies node state into the data first.
	WorldState.data.player_position = _player.global_position
	var err := SaveSystem.save_game(0)
	EventBus.notify.emit("Saved" if err == OK else "Save failed: %s" % error_string(err))


func quick_load() -> void:
	var err := SaveSystem.load_game(0)
	EventBus.notify.emit("Loaded" if err == OK else "Load failed: %s" % error_string(err))


func _on_world_loaded() -> void:
	_player.global_position = WorldState.data.player_position
	_player.velocity = Vector2.ZERO
	_chunks.reset()
	# Jump the camera straight there instead of smoothly panning across the map.
	_player.get_node("Camera2D").reset_smoothing()

