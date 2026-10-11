extends "res://tests/test_case.gd"
## Mutation strains (D-033): a graft rolls a strain; the strain changes the
## ability (a quick one recovers faster, a potent one hits harder, a hungry
## one eats ichor and fails without it); eating tells you; a reclaimed
## mutation takes root anew; strains are saved.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	var bus := autoload("EventBus")
	var strains: GDScript = load("res://src/sim/mutation_strains.gd")
	await start_scene("res://game.tscn", 4242)
	strains.rolling = true  # start_scene turns it off for other tests.
	var data = state.data

	# Rolled strains, over many grafts: mostly plain, but not only.
	var seen := {}
	for i in 60:
		data.graft("arm", &"bone_spur")
		seen[data.strains["arm"]] = seen.get(data.strains["arm"], 0) + 1
	check(seen.get(&"plain", 0) > 10 and seen.size() >= 5, "grafts roll strains, plain most often %s" % seen)

	# What a strain does, through the ability.
	data.mutations.clear()
	data.strains.clear()
	data.graft("arm", &"bone_spur")
	data.strains["arm"] = &"potent"
	bus.mutations_changed.emit()
	await physics_frame
	var dash = player.get_node("Mutations").ability(&"bone_spur")
	check(dash.strain == &"potent" and dash.damage_bonus() == 1, "a potent bone spur hits harder")
	data.strains["arm"] = &"quick"
	bus.mutations_changed.emit()
	await physics_frame
	dash = player.get_node("Mutations").ability(&"bone_spur")
	check(dash.cooldown_scale() < 1.0, "a quick one recovers faster")
	data.strains["arm"] = &"hungry"
	bus.mutations_changed.emit()
	await physics_frame
	dash = player.get_node("Mutations").ability(&"bone_spur")
	data.ichor = 0
	check(not dash.try_use(), "a hungry one fails with no ichor")
	data.ichor = 5
	check(dash.try_use() and data.ichor == 4, "and eats one when there is")

	# Eating tells you its strain.
	var notes := []
	bus.notify.connect(func(t): notes.append(t))
	data.inventory.fill(&"")
	data.add_to_inventory(&"breath_sac")
	var tries := 0
	while tries < 40:
		notes.clear()
		data.add_to_inventory(&"breath_sac")
		bus.eat_requested.emit(data.inventory.find(&"breath_sac"))
		await process_frame
		if data.strains.get("back", &"plain") != &"plain":
			break
		tries += 1
	check(notes.any(func(n): return "strain" in n), "eating one tells you its strain: %s" % [notes])

	# A reclaimed mutation takes root anew; strains are saved.
	data.strains["back"] = &"wild"
	saves.save_game(98)
	data.strains.clear()
	saves.load_game(98)
	await process_frame
	check(state.data.strains.get("back") == &"wild", "strains are saved")
	strains.rolling = false
