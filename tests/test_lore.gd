extends "res://tests/test_case.gd"
## Murals and lore objects (week 35): history painted and carved where it
## happened, learned by reading, pieced together in the History tab.


func run() -> void:
	var state := autoload("WorldState")
	var dm := autoload("DialogueManager")
	await start_scene("res://game.tscn")
	var data = state.data

	# The Choir paints its own story in its chapel.
	await goto(Vector2(3560, 3170), 40)
	var chapel = entity("ChoirChapel")
	var murals: Array = chapel.get_children().filter(func(n): return n.has_method("event_ids"))
	check(murals.size() == 1, "the Choir's chapel has a mural")
	if murals.is_empty():
		return
	var mural = murals[0]
	var ids: Array = mural.event_ids()
	var shown: Array = ids.map(func(id): return Lore.event_by_id(data, id))
	check(ids.size() >= 2 and shown.all(func(e): return e != null and &"choir_of_waking" in e.actors), "it shows %d moments of the Choir's own past" % ids.size())
	check(shown[0].type in [&"faction_founded", &"schism", &"people_arrived"], "starting with how they began (%s)" % shown[0].type)
	var text: String = mural.text()
	check("gold leaf" in text and EventText.describe(shown[-1], data).substr(1) in text, "told in the words of the event log, on the Choir's gold and bile")
	check(mural.event_ids() == ids, "the same mural always shows the same moments")

	# Reading it: through the balloon, and into what you know.
	var reading := Reading.new(mural.title(), text)
	var line = await dm.get_next_dialogue_line(load("res://data/dialogue/reading.dialogue"), "start", [reading])
	check(line != null and line.text.begins_with("A mural of"), "reading opens the mural's first page")
	mural.interact()
	await wait_frames(2)
	for balloon in get_root().get_children().filter(func(n): return n.has_method("start")):
		balloon.queue_free()
	get_root().get_tree().paused = false
	check(ids.all(func(id): return data.known_events.has(id)), "reading it teaches you what it shows")

	# The ruins tell other pieces: a people's mural and a bone at the place.
	var pieces := 0
	for key in ["ChamberRuin", "CavernRuin"]:
		var ruin = null
		for template in game._entities.templates():
			if template.get_meta(&"entity_key", "") == key:
				await goto(template.position + Vector2(0, -36), 10)
				for wait in 120:  # Until its chunk has streamed in.
					ruin = entity(key)
					if ruin:
						break
					await physics_frame
		if ruin == null or ruin.site == null:
			continue
		for piece in ruin.get_children().filter(func(n): return n.has_method("event_ids")):
			pieces += 1
			data.learn(piece.event_ids())
	check(pieces == 4, "each ruin has a mural and a bone tablet (%d pieces, paused %s)" % [pieces, get_root().get_tree().paused])

	# Pieced together: several peoples, each in order, across centuries.
	var known: Dictionary = Lore.known_by_people(data)
	var choir: Array = known.get(&"choir_of_waking", [])
	check(known.size() >= 2, "you now know something of %d peoples" % known.size())
	var ordered := true
	for people in known:
		for i in range(1, known[people].size()):
			ordered = ordered and known[people][i].year >= known[people][i - 1].year
	check(ordered and choir.size() >= 3 and choir[-1].year - choir[0].year >= 100,
		"the Choir's past reads in order and spans centuries (years %d-%d)" % [choir[0].year, choir[-1].year])

	# The History tab shows it.
	var screen = game.get_node("UI/InventoryScreen")
	game.get_node("UI")._open(screen)
	screen.show_tab(3)
	await process_frame
	var tab_text := ""
	for label in screen._history_list.get_children():
		tab_text += label.text + "\n"
	check("Choir of Waking" in tab_text and EventText.line(choir[0], data) in tab_text, "the History tab lists what you learned, per people")
	game.get_node("UI").close_all()

	# Saved.
	var saves := autoload("SaveSystem")
	var count: int = data.known_events.size()
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	await wait_frames(5)
	check(state.data.known_events.size() == count, "what you learned survives a save and load")
