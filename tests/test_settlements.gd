extends "res://tests/test_case.gd"
## Settlements (week 27): slots filled from faction data, built from the
## owners' kit, with residents who idle, walk, work, chat and talk.
## (No Settlement / ColonyNpc in types here: they use autoloads, see test_case.)


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	var bus := autoload("EventBus")
	var messages: Array[String] = []
	await start_scene("res://game.tscn")
	bus.notify.connect(func(text): messages.append(text))
	var data = state.data

	# Sites from faction data.
	var camp_site = data.sites["TenderCamp"]
	var chapel_site = data.sites["ChoirChapel"]
	check(camp_site.faction == &"flesh_tenders" and chapel_site.faction == &"choir_of_waking", "each slot is settled by its faction")
	check(camp_site.population == 6 and chapel_site.population == 4, "residents scale with strength, up to capacity (6 and 4)")
	check(camp_site.name != "" and camp_site.name == Names.place_name(data.world_seed, "TenderCamp"), "sites get repeatable generated names (%s)" % camp_site.name)

	# Built from the kit.
	await goto(Vector2(1220, 3170), 30)
	var camp = entity("TenderCamp")
	var props := camp.get_children().filter(func(c): return c.has_meta(&"built") and c.get(&"work_spot") != null)
	check(camp.residents.size() == 6 and props.size() >= 5 and camp.work_spot_count() >= 3, "the camp builds 6 residents and its props (%d props, %d work spots)" % [props.size(), camp.work_spot_count()])
	check(camp.residents.all(func(npc): return npc.sprite.body_frames_dir.ends_with("npcs/tender")), "residents wear their faction's look")
	var layout: Array = props.map(func(p): return [p.scene_file_path, p.position])
	camp.build()
	var again: Array = camp.get_children().filter(func(c): return c.has_meta(&"built") and c.get(&"work_spot") != null).map(func(p): return [p.scene_file_path, p.position])
	check(layout == again, "the layout is the same every time it is built")

	# Residents live: over half a game-minute they walk, work and stay home.
	var seen := {}
	var worked := false
	var inside := true
	var bounds: Vector2 = camp.walk_bounds()
	Engine.time_scale = 8.0
	for i in 240:
		await process_frame
		for npc in camp.residents:
			seen[npc.state] = true
			worked = worked or npc.state == 2  # ColonyNpc.State.WORK
			inside = inside and npc.position.x >= bounds.x - 0.5 and npc.position.x <= bounds.y + 0.5 and npc.position.y == 0.0
	Engine.time_scale = 1.0
	check(seen.has(0) and seen.has(1) and worked, "residents idle, walk and work (states seen: %s)" % [seen.keys()])
	check(inside, "and stay on their floor, inside the settlement")

	# They talk, and the place has a name.
	check(messages.any(func(m): return camp_site.name in m and "Flesh-Tenders" in m), "walking in shows the settlement's name")
	var talker = camp.bark_near(player.global_position)
	check(talker != null and talker.get_node("Bark").visible and talker.get_node("Bark").text in FactionDb.get_def(&"flesh_tenders").barks,
		"a resident near you says one of its faction's lines")

	# History owns the sites: changes are saved and show when rebuilt.
	camp_site.population = 2
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	await wait_frames(30)
	check(state.data.sites["TenderCamp"].population == 2 and entity("TenderCamp").residents.size() == 2, "a smaller population survives a save and shows")
	state.data.sites["TenderCamp"].faction = &""
	entity("TenderCamp").build()
	check(entity("TenderCamp").residents.is_empty(), "an abandoned site has nobody in it")

	# A save from before settlements gets them.
	var file := FileAccess.open(saves.slot_path(99), FileAccess.WRITE)
	file.store_var({"save_version": 10, "world": {"world_seed": 5, "player_position": Vector2(1220, 3170), "chunk_diffs": {}, "factions": []}})
	file.close()
	check(saves.load_game(99) == OK, "a version 10 save loads")
	await wait_frames(30)
	check(state.data.sites.size() == 2 and entity("TenderCamp").residents.size() == 6, "and gets its settlements")
