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
	$UI.death_screen.continue_pressed.connect(_start_next_life)
	EventBus.entity_killed.connect(_on_entity_killed)
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
	data.start_life(&"colonist")
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


func _process(delta: float) -> void:
	# Pausable node: does not count while a menu is open.
	var life := WorldState.data.current_life() if WorldState.data else null
	if life:
		life.seconds_alive += delta


func _on_world_loaded() -> void:
	var data := WorldState.data
	if data.current_life() == null:
		data.start_life(&"colonist")  # Saves from before week 21 have no lives.
	$UI.close_all()
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


## The host died: close its life record, then show the epitaph.
func _on_player_died() -> void:
	var life := WorldState.data.end_life(_player.global_position, _player.health.last_hit_source)
	await get_tree().create_timer(1.2).timeout  # Let the death animation play.
	if not _player.is_dead() or life == null:
		return  # A save was loaded in the meantime.
	$UI.show_death(life, WorldState.data.lives.size())


## Placeholder rebirth until week 24 (host choice): same host type, at the spawn.
## Items and mutations stay for now; week 22 leaves them on the corpse.
func _start_next_life() -> void:
	var data := WorldState.data
	data.start_life(&"colonist")
	data.player_health = -1
	_player.respawn(_world.get_node("PlayerSpawn").global_position)
	_player.get_node("Camera2D").reset_smoothing()
	$UI.close_all()
	EventBus.notify.emit("You wake as %s" % data.current_life().host_name)


## Kills by the player count toward the current life's deeds.
func _on_entity_killed(entity: Node) -> void:
	var health := entity.get_node_or_null("Health") as Health
	if health and health.last_hit_source == &"player":
		WorldState.data.record_kill(CombatRules.kind_of(entity))
