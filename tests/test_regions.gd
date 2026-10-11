extends "res://tests/test_case.gd"
## Regions and rock kinds as data (week 46, D-030): every people and place
## knows its region, a region's past only involves its own peoples, and the
## rock kinds come from one table.


func run() -> void:
	var data := WorldData.create(1234)
	data.year = HistorySim.YEARS
	HistorySim.run(data)
	check(not data.factions.is_empty() and data.factions.values().all(func(f): return f.region == Regions.GUT),
		"the Gut's past makes Gut peoples")
	check(data.sites.values().all(func(s): return s.region == Regions.GUT), "and Gut places")
	check(HistorySim.regions_without_past(data).is_empty(), "every simulated region has its past")

	# Nobody wars, trades or splits across regions.
	var crossed := false
	for e in data.events:
		var regions := {}
		for actor in e.actors:
			if data.factions.has(actor):
				regions[data.factions[actor].region] = true
		crossed = crossed or regions.size() > 1
	check(not crossed, "no event joins peoples of two regions")

	# Adding an older past to a world keeps its log in order.
	var later := WorldData.create(1234)
	later.year = HistorySim.YEARS
	later.log_event(&"site_founded", [], {})  # Something already in the log.
	HistorySim.run_regions(later, [Regions.GUT])
	var ordered := true
	for i in range(1, later.events.size()):
		ordered = ordered and later.events[i - 1].year <= later.events[i].year
	check(ordered, "a past added to a world with events is sorted in")

	# Painted regions: unpainted and outside the map are the Gut.
	check(WorldMap.region_at(Vector2i(-5, -5)) == Regions.GUT and WorldMap.region_at(Vector2i(10, 100)) == Regions.GUT,
		"unpainted places are the Gut")
	check(Regions.of_paint(Regions.INFO[Regions.LUNGS].paint) == Regions.LUNGS, "the Lungs' paint means the Lungs")

	# Rock kinds: one table, every kind complete.
	check(ChunkData.KINDS == RockKinds.IDS, "the chunk cells use the kinds table")
	var complete := true
	for kind in RockKinds.IDS:
		for key in ["ramp", "paint", "tint", "map", "sound"]:
			complete = complete and RockKinds.INFO[kind].has(key)
	check(complete, "every kind has a ramp, paint, tint, map color and sound")
	for i in RockKinds.count():
		var kind: StringName = RockKinds.IDS[i]
		if i > 0:
			check(RockKinds.of_paint(RockKinds.INFO[kind].paint) == i, "%s paint reads back as %s" % [kind, kind])
