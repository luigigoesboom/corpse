extends "res://tests/test_case.gd"
## Leaders (D-033): every living people has one, chosen, ruling and dying
## through history; their traits bend their people while they lead and are
## given back when they go; the leader lives at their people's seat, greets
## you in their own way and is spoken of; killing them is a deed; saved.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn", 4242)
	player.health.invulnerable = true
	var data = state.data
	var figures: GDScript = load("res://src/sim/figures/figures.gd")
	var leaderless := []
	for f in data.factions.values():
		if f.is_alive() and figures.leader_of(data, f.id) == null:
			leaderless.append(f.id)
	check(leaderless.is_empty(), "every living people has a leader %s" % [leaderless])
	var types := {}
	for e in data.events:
		if String(e.type).begins_with("leader_"):
			types[e.type] = types.get(e.type, 0) + 1
	check(types.get(&"leader_died", 0) > 5 and types.get(&"leader_deed", 0) > 0, "leaders rule, die, are succeeded and act through history %s" % types)
	var text_script: GDScript = load("res://src/sim/history/event_text.gd")
	for e in data.events:
		if e.type == &"leader_deed":
			print("  ", text_script.line(e, data))
	var tenders = data.factions[&"flesh_tenders"]
	var leader = figures.leader_of(data, &"flesh_tenders")
	print("  the Tenders are led by ", leader.full_name(), " ", leader.traits)

	# Their nature bends their people; given back when they go.
	var changed: Dictionary = leader.applied.duplicate()
	var before := {}
	for field in changed:
		before[field] = tenders.get(field)
	figures._die(data, leader, "a test")
	var restored := true
	for field in changed:
		restored = restored and is_equal_approx(tenders.get(field), before[field] - changed[field])
	check(restored, "a leader's mark on their people goes with them %s" % [changed])
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	figures.ensure(data, rng)
	var heir = figures.leader_of(data, &"flesh_tenders")
	check(heir != null and heir != leader, "a people without a leader gets one: %s" % heir.full_name())

	# At the seat, in person.
	var camp = entity("TenderCamp")
	camp.build()
	var named: Array = camp.residents.filter(func(r): return r.npc_name == heir.full_name())
	check(not named.is_empty(), "the leader lives at the Tender camp")
	var talk_script: GDScript = load("res://src/dialogue/talk.gd")
	var talk = talk_script.new(data, heir.full_name(), &"flesh_tenders", 7)
	check(heir.name in talk.greeting, "the leader greets you as themselves: \"%s\"" % talk.greeting)
	var other = talk_script.new(data, "Somebody", &"flesh_tenders", 8)
	check(heir.full_name() in other.creed, "their people speak of them: \"%s\"" % other.creed)

	# Killed by the host: a deed, and they are dead.
	var npc = named[0]
	npc.health.take_damage(999, Vector2.ZERO, 0.0, &"player")
	await wait_frames(5)
	check(not heir.is_alive() and data.events.any(func(e): return e.type == &"leader_killed"), "killing the leader is remembered")

	# Saved.
	var count: int = data.figures.size()
	saves.save_game(98)
	saves.load_game(98)
	await process_frame
	var loaded = state.data
	check(loaded.figures.size() >= count and not loaded.figures[heir.id].is_alive(), "leaders are saved, the dead stay dead (%d)" % count)
	check(figures.leader_of(loaded, &"flesh_tenders") != null, "and a people whose leader was killed has a new one when the world loads")
