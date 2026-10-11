extends "res://tests/test_case.gd"
## Migration and creature ecology (D-033): peoples move between regions in
## history; creature kinds have numbers per region that breed, swarm and
## vanish; killed creatures come back by their kind's numbers; a swarming
## kind turns up around the host; numbers are saved.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn", 4242)
	player.health.invulnerable = true
	var data = state.data
	var ecology: GDScript = load("res://src/sim/body/ecology.gd")
	var text_script: GDScript = load("res://src/sim/history/event_text.gd")

	# Migration in the world's past.
	var moved: Array = data.events.filter(func(e): return e.type == &"people_migrated")
	check(not moved.is_empty(), "peoples moved between the regions in the past (%d times)" % moved.size())
	if not moved.is_empty():
		var exiles = data.factions[moved[0].actors[0]]
		var parent = data.factions[moved[0].actors[1]]
		check(exiles.region != parent.region and exiles.parent == parent.id, "the exiles live in the other region, kin to those they left")
		print("  ", text_script.line(moved[0], data))

	# Populations.
	check(data.fauna.has("gut") and data.fauna["gut"].get("gut_leech", 0) > 0, "every kind has numbers in its region %s" % [data.fauna])
	var before: int = ecology.count(data, &"gut", &"gut_leech")
	ecology.on_kill(data, &"gut_leech")
	check(ecology.count(data, &"gut", &"gut_leech") < before, "the host's kills thin a kind")
	data.fauna["gut"]["bile_spitter"] = 2
	check(ecology.return_chance(data, &"bile_spitter") == 0.0, "a kind that is nearly gone does not come back")
	data.removed_entities["SomeSpitter"] = &"bile_spitter"
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	load("res://src/sim/history/aftermath.gd")._creatures_return(data, 1.0, rng, {"hints": []})
	check(data.removed_entities.has("SomeSpitter"), "so a killed spitter stays dead")

	# Swarms, in history and around the host.
	data.fauna["gut"]["rot_fly"] = 100
	var swarmed := false
	for i in 10:
		data.year += 10
		var events: Array = ecology.run(data, 10, rng, {&"gut": 0.5})
		data.fauna["gut"]["rot_fly"] = 100
		if events.any(func(e): return e.type == &"kind_swarmed"):
			swarmed = true
			print("  ", text_script.line(events.filter(func(e): return e.type == &"kind_swarmed")[0], data))
			break
	check(swarmed, "a kind at its peak swarms a settlement")
	check(&"rot_fly" in ecology.swarming(data, &"gut"), "rot flies are swarming in the Gut")
	var swarms = game.get_node("Swarms")
	var fly = swarms.spawn(&"rot_fly")
	check(fly != null and fly.global_position.distance_to(player.global_position) > 300.0, "and one turns up near the host, off screen")

	# Saved.
	saves.save_game(98)
	data.fauna.clear()
	saves.load_game(98)
	await process_frame
	check(state.data.fauna["gut"]["rot_fly"] == 100, "creature numbers are saved")
