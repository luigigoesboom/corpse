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
@onready var _corpses: CorpseLayer = $Corpses


func _ready() -> void:
	EventBus.world_loaded.connect(_on_world_loaded)
	EventBus.player_died.connect(_on_player_died)
	_entities.attach(_chunks)
	_items.attach(_chunks, _player)
	_corpses.attach(_chunks)
	$UI/HUD.bind_health(_player.health)
	_player.health.changed.connect(_on_player_health_changed)
	$UI/PauseMenu.save_pressed.connect(quick_save)
	$UI/PauseMenu.load_pressed.connect(quick_load)
	$UI.death_screen.continue_pressed.connect(_pass_time)
	$UI.death_screen.wake_pressed.connect(_start_next_life)
	EventBus.entity_killed.connect(_on_entity_killed)
	EventBus.ichor_gained.connect(_on_ichor_gained)
	EventBus.boon_bought.connect(_on_boon_bought)
	if WorldState.data:
		# "Continue" in the main menu already loaded a save.
		_on_world_loaded()
	else:
		_start_new_world()


func _start_new_world() -> void:
	# randi() is fine here: picking a seed is not generation.
	var seed_value := new_world_seed if new_world_seed != 0 else randi()
	var data := WorldData.create(seed_value)
	data.year = HistorySim.YEARS  # The past is simulated when the world loads.
	data.player_position = _world.get_node("PlayerSpawn").global_position
	data.start_life(&"colonist", "", "the Flesh-Tender camp")
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
	if data.factions.is_empty():
		# A new world, or a save from before week 26: give it a past (D-025).
		HistorySim.run(data)
		FactionTerritory.apply_territory(data)
	SiteSeeder.fill_slots(data, _entities.templates().filter(func(t): return t is Settlement))
	SiteSeeder.fill_ruin_slots(data, _entities.templates().filter(func(t): return t is RuinSite))
	ItemDb.set_generated(ArtifactText.item_defs(data))  # Artifacts work like items.
	if data.current_life() == null:
		data.start_life(&"colonist")  # Saves from before week 21 have no lives.
	$UI.close_all()
	var saved_health := data.player_health  # respawn() heals, which overwrites it.
	_apply_host(HostDb.get_def(data.current_life().host_type))
	_player.respawn(data.player_position)
	if saved_health >= 0:
		_player.health.set_current(saved_health)
	_entities.rebuild()
	_chunks.reset()


func _on_player_health_changed(current: int, max_value: int) -> void:
	WorldState.data.player_health = -1 if current == max_value else current


## The host died: close its life record (its things go onto the body), let
## the death animation play, swap the host for its Corpse, show the epitaph.
func _on_player_died() -> void:
	var data := WorldState.data
	var life := data.end_life(_player.global_position, _ground_below(_player.global_position), _player.health.last_hit_source)
	await get_tree().create_timer(1.2).timeout
	if not _player.is_dead() or life == null:
		return  # A save was loaded in the meantime.
	_player.hide_body()
	_corpses.add_corpse(data.lives.find(life))
	$UI.show_death(life, data.lives.size())


## The floor under a point, so bodies never hang in the air.
func _ground_below(point: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(point, point + Vector2(0, 2000), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position if hit else point + Vector2(0, 26)  # The host's feet.


## Time passes (D-021): roll the gap, apply the aftermath, then rebuild what
## is shown from the changed data (respawned creatures, scavenged bodies).
func _pass_time() -> void:
	var places := {}  # Where factions lay the bodies they carry home (week 33).
	for template in _entities.templates():
		if template is Settlement:
			places[EntityLayer.key_of(template)] = template.body_spot()
	var report := Aftermath.run(WorldState.data, places)
	_entities.rebuild()
	_chunks.reset()
	$UI.death_screen.show_time(report, rebirth_options())


## Three ways to wake (week 24): different places, host types and names.
## Avoids the place the last host woke when there are enough others.
## Deterministic per world and death.
func rebirth_options() -> Array:
	var data := WorldState.data
	var rng := SeededRng.make([data.world_seed, "rebirth", data.lives.size()])
	var points: Array = _world.get_node("SpawnPoints").get_children()
	var last_origin: String = data.lives[-1].origin if not data.lives.is_empty() else ""
	var count := 4 if data.has_boon(&"wider_choice") else 3  # Boons (week 34).
	var elsewhere := points.filter(func(point): return point.place_name != last_origin)
	if elsewhere.size() >= count:
		points = elsewhere
	for i in range(points.size() - 1, 0, -1):  # Shuffle with the seeded generator.
		var j := rng.randi_range(0, i)
		var swap = points[i]
		points[i] = points[j]
		points[j] = swap
	var options := []
	for i in mini(count, points.size()):
		var point: SpawnPoint = points[i]
		var types: Array = point.host_types if not point.host_types.is_empty() else HostDb.all_ids()
		options.append({
			"host_type": types[rng.randi() % types.size()],
			"host_name": Names.host_name(data.world_seed, data.lives.size() * 7 + i + 1),
			"place": point.place_name,
			"position": point.global_position,
		})
	return options


## Starts the next host from a rebirth option (empty = a colonist at the start).
## It wakes with its host type's kit only: the old things are on the old body.
func _start_next_life(option: Dictionary = {}) -> void:
	var data := WorldState.data
	var host_type: StringName = option.get("host_type", &"colonist")
	var host := HostDb.get_def(host_type)
	data.start_life(host_type, option.get("host_name", ""), option.get("place", "the Flesh-Tender camp"))
	data.player_health = -1
	for item in host.start_items:
		data.add_to_inventory(item)
	for slot in host.start_mutations:
		data.graft(slot, host.start_mutations[slot])
	for slot in data.kept_graft:  # Boons: a graft that stays (week 34).
		data.graft(slot, data.kept_graft[slot])
	data.kept_graft.clear()
	_apply_host(host)
	_player.respawn(option.get("position", _world.get_node("PlayerSpawn").global_position))
	$UI.close_all()
	EventBus.inventory_changed.emit()
	EventBus.mutations_changed.emit()
	var life := data.current_life()
	EventBus.notify.emit("You wake as %s, a %s, at %s." % [life.host_name, host.display_name, life.origin])


## The host's body from its HostDef, plus what the fragment's boons add.
func _apply_host(host: HostDef) -> void:
	_player.apply_host(host)
	if WorldState.data.has_boon(&"hardy"):
		_player.health.max_health += 1


## Kills by the player count toward the current life's deeds, and give ichor.
func _on_entity_killed(entity: Node) -> void:
	var health := entity.get_node_or_null("Health") as Health
	if health and health.last_hit_source == &"player":
		var kind := CombatRules.kind_of(entity)
		WorldState.data.record_kill(kind)
		var ichor := Ichor.for_kill(kind, entity.global_position)
		if ichor > 0:
			WorldState.data.add_ichor(ichor)
			EventBus.ichor_gained.emit(ichor, entity.global_position)
		# Clearing creatures out of a faction's land wins it over, a little.
		var holder := WorldState.data.faction_at(ChunkData.world_to_chunk(entity.global_position))
		if holder != &"":
			var message := Standing.change_message(EventText._faction(WorldState.data, holder),
				WorldState.data.change_standing(holder, 2))
			if message != "":
				EventBus.notify.emit(message)


## Ichor gained somewhere: drops fly from there to the host (only a view).
func _on_ichor_gained(amount: int, from: Vector2) -> void:
	var rng := RandomNumberGenerator.new()  # Looks only; not saved, not repeatable.
	for i in clampi(amount, 1, 12):
		var orb := IchorOrb.new()
		add_child(orb)
		orb.launch(from + Vector2(0, -16), _player, rng.randf_range(-PI, 0.0))
	EventBus.ichor_changed.emit()


func _on_boon_bought(id: StringName) -> void:
	if id == &"hardy":
		_player.health.max_health += 1
		_player.health.set_current(_player.health.current + 1)
	EventBus.notify.emit("The fragment grows: %s" % Boons.display_name(id))
