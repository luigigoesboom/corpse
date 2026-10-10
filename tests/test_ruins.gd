extends "res://tests/test_case.gd"
## History into the world (week 29): ruins in hand-made slots, artifacts whose
## descriptions match the event log.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn")
	var data = state.data
	var log_lines: Array = data.events.map(func(e): return EventText.line(e, data))

	# Ruin slots hold settlements history ended.
	var ruined := true
	for key in ["ChamberRuin", "CavernRuin"]:
		var site = data.site_in_slot(key)
		ruined = ruined and site != null and site.kind == &"ruin" and site.ended_year >= 0 and site.ended_year < data.year
	check(ruined, "both ruin slots hold settlements that history destroyed or abandoned")

	# The ruin tells how it ended, in the log's words.
	await goto(entity("ChamberRuin").global_position + Vector2(0, -30), 60)
	var ruin = entity("ChamberRuin")
	var props: Array = ruin.get_children().filter(func(c): return c.has_meta(&"built") and c.get(&"width") != null)
	check(props.size() >= 3, "the ruin is built of broken things (%d props)" % props.size())
	check(ruin.title_text() == "The ruins of %s" % ruin.site.name and ruin.story_text() in log_lines,
		"it is named and tells its end exactly as the log does: \"%s\"" % ruin.story_text())
	check(ruin.is_title_visible(), "walking in shows its name and story")

	# Its artifact lies in it, and says what the log says.
	var artifact = data.artifacts.values().filter(func(a): return a.site_id == ruin.site.id)
	check(artifact.size() == 1, "the ruin has its own artifact")
	var art = artifact[0]
	var def = ItemDb.get_def(StringName(art.id))
	var found := false
	for chunk in data.chunk_diffs:
		for record in data.items_in_chunk(chunk):
			if record.item == StringName(art.id) and absf(record.pos.x - ruin.global_position.x) <= ruin.width / 2.0:
				found = true
	check(found, "it lies on the floor inside the ruin")
	var quoted: Array = Array(def.description.split("\n")).filter(func(line): return line.begins_with("Year "))
	check(def != null and def.display_name != "" and not quoted.is_empty() and quoted.all(func(line): return line in log_lines),
		"%s: its description quotes the event log (%d lines)" % [def.display_name, quoted.size()])

	# Pick it up: it is an item like any other.
	var where: Vector2 = Vector2.ZERO
	for chunk in data.chunk_diffs:
		for record in data.items_in_chunk(chunk):
			if record.item == StringName(art.id):
				where = record.pos
	await goto(where + Vector2(0, -30), 20)
	await press("interact")
	check(StringName(art.id) in data.inventory, "you can pick it up")
	check(ItemDb.display_name(StringName(art.id)) == def.display_name, "and it keeps its name in your pockets")

	# It lasts: saves, and time passing between lives does not rot it.
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	await wait_frames(10)
	data = state.data
	check(StringName(art.id) in data.inventory and ItemDb.get_def(StringName(art.id)).description == def.description,
		"after a save and load it is still yours, with the same history")
	var other = data.artifacts.values().filter(func(a): return a.id != art.id)
	if not other.is_empty():
		var rng := RandomNumberGenerator.new()
		for i in 5:
			Aftermath.apply(data, 3, rng)  # Decades, five times over.
		var still := false
		for chunk in data.chunk_diffs:
			for record in data.items_in_chunk(chunk):
				still = still or record.item == StringName(other[0].id)
		check(still, "artifacts lying in ruins do not rot away between lives")

	# A save from before artifacts still loads, and its ruins get them.
	var file := FileAccess.open(saves.slot_path(99), FileAccess.WRITE)
	file.store_var({"save_version": 12, "world": {"world_seed": 5, "year": 2000, "player_position": Vector2(1220, 3170), "chunk_diffs": {}}})
	file.close()
	check(saves.load_game(99) == OK, "a version 12 save loads")
	await wait_frames(10)
	check(state.data.site_in_slot("ChamberRuin") != null and state.data.artifacts.size() >= 1, "and its ruins and artifacts are filled in")
