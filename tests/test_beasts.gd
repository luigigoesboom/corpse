extends "res://tests/test_case.gd"
## Legendary beasts (D-033): a new world has beasts of its recent past in
## its lairs, with names, traits and raids in the log; a living beast is a
## grown creature with its name over it, announced when you come close;
## killing it is a famous deed that leaves a trophy; between lives beasts
## raid, are hunted and arise; all of it is saved.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	var bus := autoload("EventBus")
	await start_scene("res://game.tscn", 4242)
	player.health.invulnerable = true
	var data = state.data
	var beasts: GDScript = load("res://src/sim/beasts/beasts.gd")
	check(data.beasts_seeded and data.beasts.size() >= 3, "a new world has beasts in its lairs (%d)" % data.beasts.size())
	var arose: Array = data.events.filter(func(e): return e.type == &"beast_arose")
	var raids: Array = data.events.filter(func(e): return e.type == &"beast_raided")
	check(arose.size() == data.beasts.size() and not raids.is_empty(), "their past is in the log (%d arose, %d raids)" % [arose.size(), raids.size()])
	var text_script: GDScript = load("res://src/sim/history/event_text.gd")
	print("  ", text_script.line(arose[0], data))
	print("  ", text_script.line(raids[0], data))
	check(" " in data.beasts.values()[0].full_name() and data.beasts.values()[0].traits.size() == 2, "each has a name, an epithet and two traits")

	# A living beast in its lair, grown.
	var lair: Node2D = null
	for e in game.get_node("World/Entities").find_children("Lair*", "", false, false):
		if beasts.living_in(data, e.get_meta(&"entity_key", String(e.name))) != null:
			lair = e
			break
	if lair == null:  # Templates only: bring one in.
		for t in game.get_node("World/Entities").templates():
			if t.name.begins_with("Lair") and beasts.living_in(data, String(t.name)) != null:
				await goto(t.global_position + Vector2(-200, -30), 30)
				break
		for e in game.get_node("World/Entities").find_children("Lair*", "", false, false):
			if beasts.living_in(data, e.get_meta(&"entity_key", String(e.name))) != null:
				lair = e
	check(lair != null, "a lair with a living beast is in the world")
	if lair == null:
		return
	var creature: Node2D = lair.creature
	var beast = data.beasts[creature.get_meta(&"beast_id")]
	check(creature.get_node("Health").max_health >= 4 and creature.scale.x > 1.0, "the beast is grown: %s, %d health, x%.2f" % [beast.full_name(), creature.get_node("Health").max_health, creature.scale.x])
	check(creature.has_node("BeastName") and creature.get_node("BeastName").text == beast.full_name(), "its name is over its head")
	var announced := []
	bus.place_entered.connect(func(title, line, _first): announced.append([title, line]))
	await goto(creature.global_position + Vector2(-150, -10), 10)
	for i in 10:
		await process_frame
	check(announced.any(func(a): return a[0] == beast.full_name()), "coming close announces it %s" % [announced])

	# Killed by the host: a famous deed and a trophy.
	var artifacts_before: int = data.artifacts.size()
	var health = creature.get_node("Health")
	health.take_damage(999, Vector2.ZERO, 0.0, &"player")
	await wait_frames(100)  # Creatures fade before they report their death.
	check(not beast.is_alive() and beast.slain_by == data.current_life().host_name, "the beast is dead, slain by the host")
	check(data.events.any(func(e): return e.type == &"beast_slain_by_host" and e.id in data.current_life().deed_event_ids), "it is one of this life's deeds")
	check(data.artifacts.size() == artifacts_before + 1 and data.artifacts.values()[-1].kind == &"trophy", "it leaves a trophy: %s" % data.artifacts.values()[-1].name)

	# Between lives: raids, hunts, new beasts.
	var lairs: Array = game.body().lairs
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	data.year += 300
	var happened: Array = beasts.between_lives(data, lairs, 300, rng)
	var types := {}
	for e in happened:
		types[e.type] = types.get(e.type, 0) + 1
	check(types.get(&"beast_raided", 0) > 0 and types.get(&"beast_arose", 0) > 0, "over the years beasts raid and new ones arise %s" % types)

	# Saved.
	var count: int = data.beasts.size()
	saves.save_game(98)
	saves.load_game(98)
	await process_frame
	check(state.data.beasts.size() == count and state.data.beasts.values()[0].traits.size() == 2, "beasts are saved")
