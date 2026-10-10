extends "res://tests/test_case.gd"
## Ichor (week 34, D-027): gathered by the host, left on the corpse at death,
## banked at heart-roots for boons that last across lives.


func run() -> void:
	# --- The rules, on plain data. ---
	var data := WorldData.create(3)
	data.start_life(&"colonist")
	data.add_ichor(20)
	data.mutations = {"mouth": &"acid_gland", "arm": &"bone_spur"}
	data.end_life(Vector2(100, 100), Vector2(100, 120), &"")
	check(data.ichor == 0 and data.lives[0].corpse_ichor == 20 and data.lives[0].has_corpse_loot(), "at death the ichor stays in the body")
	data.start_life(&"colonist")
	var taken := data.reclaim_corpse(0)
	check(taken.ichor == 20 and data.ichor == 20 and data.lives[0].corpse_ichor == 0, "going back for the body gets it all back")
	check(data.bank_ichor() == 20 and data.ichor == 0 and data.ichor_banked == 20, "banking moves it all into the fragment")
	check(data.buy_boon(&"sense_bodies") and data.ichor_banked == 5, "a boon costs banked ichor")
	check(not data.buy_boon(&"sense_bodies") and not data.buy_boon(&"hardy"), "you cannot buy a boon twice, or one you cannot afford")
	check(Ichor.for_kill(&"gut_leech", Vector2(0, 3200)) > Ichor.for_kill(&"gut_leech", Vector2(0, 100)), "deeper creatures give more ichor")
	data.boons[&"lasting_graft"] = true
	data.mutations = {"mouth": &"acid_gland", "arm": &"bone_spur"}
	data.end_life(Vector2.ZERO, Vector2.ZERO, &"")
	check(data.kept_graft == {"arm": &"bone_spur"} and not data.lives[1].corpse_mutations.has("arm"), "with a lasting graft, one mutation follows the fragment")
	data.lives[1].corpse_ichor = 100
	Aftermath.apply(data, 3, SeededRng.make(["ichor", 1]))
	check(data.lives[1].corpse_ichor >= 60 and data.lives[1].corpse_ichor < 100, "ichor dries out of a body over the years, but not all of it (%d)" % data.lives[1].corpse_ichor)
	var copy := WorldData.from_dict(data.to_dict())
	check(copy.ichor_banked == data.ichor_banked and copy.boons == data.boons and copy.kept_graft == data.kept_graft
		and copy.lives[1].corpse_ichor == data.lives[1].corpse_ichor, "ichor, boons and kept grafts are saved")

	# --- In the game. ---
	var state := autoload("WorldState")
	var dm := autoload("DialogueManager")
	await start_scene("res://game.tscn")
	data = state.data
	var hearts: int = player.health.max_health

	# Killing gives ichor; clots in ruins and deep places too.
	var leech = entity("LeechChamber")
	if leech:
		leech.get_node("Health").last_hit_source = &"player"
		var before := data.ichor
		game._on_entity_killed(leech)
		check(data.ichor == before + Ichor.for_kill(&"gut_leech", leech.global_position) and data.ichor > before, "killing a leech gives ichor (%d)" % (data.ichor - before))
	var before_clot := data.ichor
	await goto(Vector2(3200, 3180), 20)
	check(data.ichor == before_clot + 15 and data.removed_entities.has("ClotChamberRuin"), "walking into a clot in the ruin takes it, for good")

	# A heart-root speaks through the dialogue balloon.
	var resource = load("res://data/dialogue/heart_root.dialogue")
	var wild := RootTalk.new(data, &"")
	var line = await dm.get_next_dialogue_line(resource, "start", [wild])
	line = await dm.get_next_dialogue_line(resource, line.next_id, [wild])
	var options: Array = line.responses.filter(func(r): return r.is_allowed).map(func(r): return r.text)
	check("Pour in your ichor." in options and "Leave it." in options, "a root offers to drink your ichor (%s)" % [options])
	check(options.size() == 2, "and offers no boons the fragment cannot afford")

	# Offering at the Choir's altar pleases the Choir.
	var choir_before: int = data.standing(&"choir_of_waking")
	var altar := RootTalk.new(data, &"choir_of_waking")
	data.add_ichor(50)
	altar.bank()
	check(data.ichor == 0 and data.standing(&"choir_of_waking") > choir_before, "pouring ichor into the Choir's altar pleases them (%d -> %d)" % [choir_before, data.standing(&"choir_of_waking")])
	data.current_life().standing[&"choir_of_waking"] = -90
	check(RootTalk.new(data, &"choir_of_waking").refused and not RootTalk.new(data, &"").refused, "a hostile Choir keeps you from its altar, a wild root does not")
	data.current_life().standing.erase(&"choir_of_waking")

	# Done when: die carrying ichor, go back for it, bank it, next life is stronger.
	data.ichor_banked = 0
	data.add_ichor(40)
	await goto(Vector2(2000, 3180), 20)
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(5)
	check(data.ichor == 0, "the new host wakes with no ichor")
	var body = data.lives[data.lives.size() - 2]
	await goto(body.corpse_position + Vector2(0, -26), 20)
	for corpse in game._corpses.get_children():
		if corpse.life_index == data.lives.size() - 2:
			corpse.interact()
	await wait_frames(2)
	check(data.ichor >= 40, "searching the old body gets the ichor back (%d)" % data.ichor)
	wild = RootTalk.new(data, &"")
	wild.boon_bought.connect(func(id): autoload("EventBus").boon_bought.emit(id))  # As HeartRoot wires it.
	wild.bank()
	check(wild.can_buy("hardy"), "banked, it is enough for a sturdier host")
	wild.buy("hardy")
	await wait_frames(2)
	check(player.health.max_health == hearts + 1, "which works at once (%d -> %d hearts)" % [hearts, player.health.max_health])
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(5)
	check(player.health.max_health == hearts + 1 and player.health.current == hearts + 1, "and the next life starts stronger")

	data.boons[&"wider_choice"] = true
	check(game.rebirth_options().size() == mini(4, get_nodes_in_group(&"spawn_points").size()), "more bodies to choose from at rebirth")
