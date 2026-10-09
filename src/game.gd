extends Node2D
## Top-level game scene: starts a world, handles quick save / quick load,
## and rebuilds the scene whenever WorldState gets a new world.

## Seed for the world created on start. 0 = a random seed every run.
## The terrain is hand-painted and always the same; the seed is for things
## that should differ per save (history, later).
@export var new_world_seed := 0

var _toast_tween: Tween

@onready var _player: Player = $Player
@onready var _chunks: ChunkManager = $ChunkManager
@onready var _world: Node2D = $World
@onready var _items: ItemLayer = $Items
@onready var _toast: Label = $UI/Toast


func _ready() -> void:
	EventBus.world_loaded.connect(_on_world_loaded)
	(_world.get_node("Entities") as EntityLayer).attach(_chunks)
	_items.attach(_chunks)
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
		_show_toast("Map reloaded (%d x %d)" % [_chunks.map.size.x, _chunks.map.size.y])


func quick_save() -> void:
	# The sim never reads nodes, so the game copies node state into the data first.
	WorldState.data.player_position = _player.global_position
	var err := SaveSystem.save_game(0)
	_show_toast("Saved" if err == OK else "Save failed: %s" % error_string(err))


func quick_load() -> void:
	var err := SaveSystem.load_game(0)
	_show_toast("Loaded" if err == OK else "Load failed: %s" % error_string(err))


func _on_world_loaded() -> void:
	_player.global_position = WorldState.data.player_position
	_player.velocity = Vector2.ZERO
	_chunks.reset()
	# Jump the camera straight there instead of smoothly panning across the map.
	_player.get_node("Camera2D").reset_smoothing()


func _show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
