extends "res://tests/test_case.gd"
## History sim v1 (week 28, D-025): 2000 years at world creation.


func run() -> void:
	# Repeatable: the same seed tells the same story.
	var first := _history(7)
	var again := _history(7)
	check(_lines(first) == _lines(again), "the same seed gives the same history, word for word")

	# Five seeds, five stories.
	var worlds := [first]
	for seed_value in [11, 23, 42, 99]:
		worlds.append(_history(seed_value))
	var logs := worlds.map(func(w): return "\n".join(_lines(w)))
	var distinct := {}
	for text in logs:
		distinct[text] = true
	check(distinct.size() == 5, "five seeds give five different histories")
	var casts := worlds.map(func(w): return _peoples(w))
	check(casts[0] != casts[1] and casts[1] != casts[2] and casts[2] != casts[3], "with different peoples in them")

	# What every history must have.
	var types := {}
	var all_ok := true
	var clean := true
	var ordered := true
	for w in worlds:
		var data: WorldData = w.data
		var count := data.events.size()
		# D-033: leaders, their deeds and their deaths fill the log too.
		all_ok = all_ok and count >= 60 and count <= 1000 and w.ms < 2500
		if count > 1000 or w.ms >= 2500:
			print("  %d events, %d ms" % [count, w.ms])
		for id in [&"flesh_tenders", &"choir_of_waking"]:
			var faction: FactionData = data.factions.get(id)
			var homes := data.sites.values().filter(func(s): return s.faction == id and s.is_lived_in())
			all_ok = all_ok and faction != null and faction.is_alive() and faction.strength >= HistorySim.DESTINED_PRESENT_MIN and not homes.is_empty()
		all_ok = all_ok and data.factions[&"choir_of_waking"].founded_year > data.factions[&"flesh_tenders"].founded_year
		var last_year := -100000
		for event in data.events:
			types[event.type] = true
			ordered = ordered and event.year >= last_year and event.year <= data.year
			last_year = event.year
		for line in _lines(w):
			if "<null>" in line or "people_" in line or "site_" in line or "&\"" in line or "%" in line:
				clean = false
				print("  bad line: ", line)
	check(all_ok, "each has 60-1000 events, takes under 2.5 s, and ends with both hand-made factions alive, at home, and big enough")
	check(ordered, "events are in order and none is in the future")
	check(clean, "every event reads as a sentence (no ids, no format codes)")
	var wanted := [&"people_arrived", &"faction_founded", &"site_founded", &"war_declared", &"peace", &"schism", &"disaster", &"faction_fell", &"wonder"]
	var missing := wanted.filter(func(t): return not types.has(t))
	check(missing.is_empty() and (types.has(&"site_taken") or types.has(&"site_razed")),
		"across them: arrivals, foundings, wars, peace, conquest, schisms, disasters, falls and wonders (missing %s)" % [missing])

	# Survives a save.
	var data: WorldData = first.data
	var copy := WorldData.from_dict(data.to_dict())
	check(_lines({"data": copy}) == _lines(first) and copy.factions.size() == data.factions.size(), "the history survives saving")

	# A new game starts with its past.
	await start_scene("res://game.tscn")
	var world = autoload("WorldState").data
	check(world.year == HistorySim.YEARS and world.events.size() >= 60, "a new game starts in year %d with its history (%d events)" % [world.year, world.events.size()])
	var viewer = game.get_node("UI/HistoryLog")
	viewer.refresh()
	check(viewer.line_count() == world.events.size(), "F2 shows the whole log")


func _history(seed_value: int) -> Dictionary:
	var data := WorldData.create(seed_value)
	data.year = HistorySim.YEARS
	var start := Time.get_ticks_msec()
	HistorySim.run(data)
	return {"data": data, "ms": Time.get_ticks_msec() - start}


func _lines(w: Dictionary) -> Array:
	return w.data.events.map(func(e): return EventText.line(e, w.data))


func _peoples(w: Dictionary) -> Array:
	var names: Array = w.data.factions.values().filter(func(f): return not f.defined).map(func(f): return f.display_name)
	names.sort()
	return names
