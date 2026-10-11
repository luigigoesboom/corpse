extends "res://tests/test_case.gd"
## The body's rot (D-033): a field over the map that settles from the
## painting, spreads through open space, is fed by bodies, burned back by
## the Flesh-Tenders, turns rock into rot rock, is logged when it reaches a
## named place, and is saved.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn", 4242)
	var data = state.data
	var rot: GDScript = load("res://src/sim/body/rot.gd")
	var body: Dictionary = game.body()
	check(data.rot.size() == body.w * body.h and data.rot_width == body.w, "a new world has a rot field the size of the map (%d cells)" % data.rot.size())
	var total := 0
	for v in data.rot:
		total += v
	check(total > 0, "the painted rot has settled into it")

	# A host's body rots where it lies.
	var spot := Vector2(3216, 2600)  # Open air in the central chamber.
	var cell: int = rot.cell_of_point(body, spot)
	var before: int = data.rot[cell]
	var life = data.lives[0]
	life.death_year = data.year
	life.corpse_position = spot
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	rot.run(data, body, 10, rng)
	check(data.rot[cell] > before, "a body feeds the rot around it (%d -> %d)" % [before, data.rot[cell]])

	# The Flesh-Tenders burn it back around their camp.
	var camp := -1
	for place in body.places:
		if place.get("slot", "") == "TenderCamp":
			camp = place.cell
	check(camp >= 0, "the camp is a place of the body")
	for i in data.rot.size():
		data.rot[i] = 200 if body.air[i] else 0
	rot.run(data, body, 10, rng)
	var far := 0
	var far_n := 0
	for i in data.rot.size():
		if body.air[i] and absi(i % body.w - camp % body.w) > 12:
			far += data.rot[i]
			far_n += 1
	check(data.rot[camp] < far / maxf(1.0, far_n), "around the Tender camp the rot is lower (%d there, %d elsewhere)" % [data.rot[camp], far / maxi(1, far_n)])

	# Rot reaching a named place is logged, and reads as a sentence: just
	# under heavy everywhere, with rot painted all over, it wells up past.
	var welling: Dictionary = body.duplicate()
	welling.painted = PackedByteArray()
	welling.painted.resize(body.w * body.h)
	welling.painted.fill(255)
	for i in data.rot.size():
		data.rot[i] = 130
	var events: Array = rot.run(data, welling, 1, rng)
	var spread: Array = events.filter(func(e): return e.type == &"rot_spread")
	check(not spread.is_empty(), "rot reaching named places is logged (%d)" % spread.size())
	if not spread.is_empty():
		var text: String = load("res://src/sim/history/event_text.gd").describe(spread[0], data)
		check("rot" in text.to_lower(), "and told: \"%s\"" % text)

	# Heavy rot turns rock into rot rock.
	var map = game.get_node("ChunkManager").map
	var wm: GDScript = load("res://src/world/world_map.gd")
	wm.set_rot(data.rot, data.rot_width)
	var rock := Vector2i(100, 100)  # The chamber's floor.
	check(map.kind_at(rock) == load("res://src/world/rock_kinds.gd").IDS.find(&"rot"), "rock in heavy rot is rot rock")
	for i in data.rot.size():
		data.rot[i] = 0
	wm.set_rot(data.rot, data.rot_width)
	check(map.kind_at(rock) == map.painted_kind_at(rock), "without rot it is what was painted")

	# Saved and loaded.
	data.rot[cell] = 123
	saves.save_game(98)
	data.rot[cell] = 0
	saves.load_game(98)
	await process_frame
	check(state.data.rot[cell] == 123 and state.data.rot_width == body.w, "the rot is saved")
