extends "res://tests/test_case.gd"
## Choosing a host on rebirth (week 24).


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn")
	var data = state.data
	check(data.current_life().origin == "the Flesh-Tender camp", "the first host wakes at the Flesh-Tender camp")

	# Die and look at the offer.
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	var options: Array = game.rebirth_options()
	var places := options.map(func(option): return option.place)
	check(options.size() == 3, "three hosts are offered")
	check(places.size() == 3 and places[0] != places[1] and places[1] != places[2] and places[0] != places[2], "each wakes somewhere different")
	check(not "the Flesh-Tender camp" in places, "none wakes where the last host woke")
	check(game.rebirth_options() == options, "the offer is the same every time for this death")
	var points := game.get_node("World/SpawnPoints").get_children()
	var fits := options.all(func(option):
		var point = points.filter(func(p): return p.place_name == option.place)[0]
		return point.allows(option.host_type))
	check(fits, "every host type fits its wake point")
	var screen = game.get_node("UI").death_screen
	screen.continue_pressed.emit()
	await wait_frames(2)
	check(screen.get_node("%Options").get_child_count() == 3 and not screen.get_node("%ContinueButton").visible, "the time screen shows one button per host")

	# Wake as a pilgrim at the upper corridor.
	var corridor: Vector2 = game.get_node("World/SpawnPoints/UpperCorridor").global_position
	screen.wake_pressed.emit({"host_type": &"pilgrim", "host_name": "Testa", "place": "the upper corridor", "position": corridor})
	await wait_frames(5)
	var life = data.current_life()
	check(life.host_type == &"pilgrim" and life.host_name == "Testa" and life.origin == "the upper corridor", "the life records host type, name and origin")
	check(player.global_position.distance_to(corridor) < 40.0, "the pilgrim wakes at the upper corridor")
	check(player.health.max_health == 4 and is_equal_approx(player.run_speed, 240.0 * 1.15), "a pilgrim has 4 hearts and runs faster")
	check(player.sprite.body_frames_dir.ends_with("pilgrim"), "and looks like a pilgrim")
	check(data.inventory[0] == &"bone_shard", "and starts with its kit (a Bone Shard)")

	# Die again, wake as an antibody.
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	screen.wake_pressed.emit({"host_type": &"antibody", "host_name": "Testb", "place": "the cavern floor",
		"position": game.get_node("World/SpawnPoints/CavernFloor").global_position})
	await wait_frames(5)
	check(player.health.max_health == 7 and player.health.current == 7, "an antibody has 7 hearts")
	check(data.mutations.get("arm") == &"bone_spur" and player.get_node("Mutations").get_child_count() == 1, "and is born with a Bone Spur")
	check(data.inventory.all(func(item): return item == &""), "but nothing from the pilgrim, whose things stay on its body")
	check(data.lives[1].corpse_items == [&"bone_shard"], "(the pilgrim's Bone Shard is on the pilgrim's body)")

	# The host type survives a save and load.
	data.player_position = player.global_position
	saves.save_game(98)
	player.apply_host(HostDb.get_def(&"colonist"))
	saves.load_game(98)
	await wait_frames(3)
	check(player.health.max_health == 7 and player.sprite.body_frames_dir.ends_with("antibody"), "loading restores the antibody body")
