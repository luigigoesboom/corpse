extends "res://tests/test_case.gd"
## The two combat test arenas (week 19).


func run() -> void:
	var bus := autoload("EventBus")
	var messages: Array[String] = []
	bus.notify.connect(func(text): messages.append(text))

	# Tight arena: small, 3 hearts, no mutations, no friendly fire.
	await start_scene("res://scenes/arenas/arena_tight.tscn")
	check(game.get_node("Terrain").get_used_cells().size() > 100, "tight arena builds its room from the layout")
	check(player.health.max_health == 3 and player.is_on_floor(), "tight arena: 3 hearts, standing at the start")
	check(player.get_node("Mutations").get_child_count() == 0 and not CombatRules.friendly_fire, "tight arena: no mutations, no friendly fire")
	await _kill_all(game.get_node("Enemies"))
	check(game.enemies_left() == 0 and messages.any(func(m): return m.begins_with("Clear in")), "clearing the room reports the time")
	game.queue_free()
	await wait_frames(3)
	check(CombatRules.friendly_fire == CombatRules.DEFAULT_FRIENDLY_FIRE, "leaving an arena resets the combat rules")

	# Loose arena: big, 8 hearts, all mutations, friendly fire.
	await start_scene("res://scenes/arenas/arena_loose.tscn")
	check(player.health.max_health == 8 and player.get_node("Mutations").get_child_count() == 3, "loose arena: 8 hearts and all three mutations")
	check(CombatRules.friendly_fire, "loose arena: enemy attacks hurt other creatures")
	# Friendly fire for real: an enemy acid glob dropped on a leech hurts it.
	var leech = game.get_node("Enemies/Leech3")
	var leech_hp: int = leech.get_node("Health").current
	await _drop_enemy_acid_on(leech)
	check(leech.get_node("Health").current < leech_hp, "enemy acid hurts a leech when friendly fire is on")
	CombatRules.friendly_fire = false
	leech_hp = leech.get_node("Health").current
	await _drop_enemy_acid_on(leech)
	check(leech.get_node("Health").current == leech_hp, "and does not when it is off")
	game.queue_free()
	await wait_frames(3)


func _kill_all(enemies: Node) -> void:
	for enemy in enemies.get_children():
		enemy.get_node("Health").take_damage(99, enemy.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout


func _drop_enemy_acid_on(target: Node2D) -> void:
	var glob = load("res://src/mutations/acid_projectile.tscn").instantiate()
	glob.position = target.global_position + Vector2(0, -10)
	glob.get_node("Hitbox").collision_layer = CombatRules.enemy_attack_layer()
	target.get_parent().add_child(glob)
	await wait_frames(5)
