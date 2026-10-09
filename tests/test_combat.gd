extends "res://tests/test_case.gd"
## Combat (weeks 13-14 pulled forward): dummy, Gut Leech, death and respawn.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn")
	check(player.health.current == player.health.max_health, "player starts at full health")

	# Training dummy at x = 1760.
	await goto(Vector2(1720, 3178))
	player._facing = 1.0  # Face right.
	var dummy = entity("TrainingDummy")
	var dummy_hp: int = dummy.get_node("Health").current
	for i in 3:
		await press("attack")
		await wait_frames(22)
	check(dummy.get_node("Health").current == dummy_hp - 3, "three swings hit the dummy three times")

	# The chamber leech notices and bites.
	var leech = entity("LeechChamber")
	await goto(Vector2(leech.global_position.x - 150, 3178), 5)
	var noticed := false
	for i in 240:
		await physics_frame
		noticed = noticed or leech.state >= 2
		if player.health.current < player.health.max_health:
			break
	check(noticed, "the leech notices the player")
	check(player.health.current < player.health.max_health, "the leech hurts the player")

	# Fight back until it flees and dies.
	var fled := false
	player.health.invulnerable = true
	for i in 12:
		if leech.get_parent() == null:
			break
		await goto(leech.global_position + Vector2(-40, -22), 1)
		player._facing = 1.0  # Face right.
		await press("attack")
		await wait_frames(20)
		fled = fled or leech.state == 5
	player.health.invulnerable = false
	await create_timer(0.6).timeout
	check(fled, "the leech flees when badly hurt")
	check(state.data.removed_entities.has("LeechChamber") and leech.get_parent() == null, "a killed leech is gone for good")

	# Health is saved; loading an older save brings the leech back fresh.
	state.data.player_position = player.global_position
	player.health.set_current(3)
	saves.save_game(98)
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await wait_frames(2)
	check(player.is_dead(), "lethal damage kills the host")
	await create_timer(2.2).timeout
	check(not player.is_dead() and player.health.current == player.health.max_health, "the host respawns with full health (placeholder)")
	saves.load_game(98)
	await wait_frames(5)
	check(player.health.current == 3, "loading restores the saved health")

	# Loading during the death pause must not be undone by the pending respawn.
	var saved_pos: Vector2 = state.data.player_position
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await wait_frames(2)
	saves.load_game(98)
	await create_timer(2.3).timeout
	check(player.global_position.distance_to(saved_pos) < 40.0, "loading while dead keeps the loaded position")
	state.data.removed_entities.erase("LeechChamber")
	saves.save_game(99)
	saves.load_game(99)
	await wait_frames(5)
	var fresh = entity("LeechChamber")
	check(fresh != null and fresh.get_node("Health").current == 3 and fresh.modulate.a == 1.0, "a save without the kill brings the leech back fresh")
