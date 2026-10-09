extends "res://tests/test_case.gd"
## Life records and the death screen (week 21).


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn")
	var data = state.data
	check(data.lives.size() == 1 and data.current_life() != null, "a new world starts the first life")
	var first_name: String = data.current_life().host_name
	check(first_name != "" and first_name == Names.host_name(data.world_seed, 0), "the host has a generated, repeatable name (%s)" % first_name)

	# Kill the chamber leech: the kill counts for this life.
	var leech = entity("LeechChamber")
	player.health.invulnerable = true
	for i in 12:
		if leech.get_parent() == null:
			break
		await goto(leech.global_position + Vector2(-40, -22), 1)
		player._facing = 1.0
		await press("attack")
		await wait_frames(20)
	await create_timer(1.0).timeout
	check(data.current_life().kills.get(&"gut_leech", 0) == 1, "killing a leech is recorded as a deed of this life")

	# Pick up something, then die to a leech.
	await goto(Vector2(992, 3178))
	await press("interact")
	player.health.invulnerable = false
	await wait_frames(30)  # Let the invulnerability timer run out.
	player.health.take_damage(99, player.global_position + Vector2(10, 0), 0.0, &"gut_leech")
	await wait_frames(2)
	var life = data.lives[0]
	check(not life.is_alive() and data.current_life() == null, "death closes the life")
	check(life.killed_by == &"gut_leech", "the killer is recorded")
	check(&"bile_bulb" in life.carried_items, "what the host carried is recorded")
	check(life.seconds_alive > 0.0, "time alive is recorded (%.1f s)" % life.seconds_alive)
	await create_timer(1.4).timeout
	var screen = game.get_node("UI").death_screen
	var summary: String = screen.get_node("%Summary").text
	check(screen.visible and "Gut Leech" in summary and "Bile Bulb" in summary and "Killed 1 Gut Leech" in summary,
		"the death screen tells the story of the life")

	# Wake in a new host.
	screen.wake_pressed.emit({})  # Skips time passing (tested in test_aftermath).
	await wait_frames(2)
	check(data.lives.size() == 2 and data.current_life() != null and data.current_life().host_name == Names.host_name(data.world_seed, 1),
		"the next host is a new life with its own name")

	# Lives survive saving.
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	await wait_frames(3)
	var loaded = state.data
	check(loaded.lives.size() == 2 and loaded.lives[0].killed_by == &"gut_leech" and loaded.lives[0].kills.get(&"gut_leech", 0) == 1,
		"life records survive save and load")
