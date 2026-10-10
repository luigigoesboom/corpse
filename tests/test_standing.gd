extends "res://tests/test_case.gd"
## Host standing (week 31): per-faction standing for the current host, moved
## by deeds, with consequences you can see.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	var bus := autoload("EventBus")
	var messages: Array[String] = []
	await start_scene("res://game.tscn")
	bus.notify.connect(func(text): messages.append(text))
	var data = state.data

	# A new host starts from what each faction thinks of its kind.
	check(data.standing(&"flesh_tenders") == 20 and data.standing(&"choir_of_waking") == 0,
		"a colonist starts liked by the Flesh-Tenders (20) and unknown to the Choir (0)")

	# Hit a Flesh-Tender and the colony turns.
	await goto(Vector2(1220, 3170), 40)
	var camp = entity("TenderCamp")
	check(not camp.is_hostile(), "the camp is peaceful")
	var victim = camp.residents[camp.residents.size() - 1]
	await _strike(victim)
	check(Standing.tier(data.standing(&"flesh_tenders")) == Standing.HOSTILE and camp.is_hostile(),
		"one blow against a Flesh-Tender makes their camp hostile (%d)" % data.standing(&"flesh_tenders"))
	check(messages.any(func(m): return "Flesh-Tenders will remember that" in m), "and they let you know")

	# Guards come for you, everyone else runs.
	var hp: int = player.health.current
	var guards: Array = camp.residents.filter(func(n): return n.is_guard)
	var others: Array = camp.residents.filter(func(n): return not n.is_guard)
	await goto(guards[0].global_position + Vector2(-60, -26), 1)
	for i in 240:
		await physics_frame
		player.velocity = Vector2.ZERO
		if player.health.current < hp:
			break
	check(guards.all(func(g): return g.state == 5) and player.health.current < hp, "a guard closes in and lands a blow (%d -> %d hearts)" % [hp, player.health.current])
	check(others.is_empty() or others.all(func(n): return n.state == 4), "the others flee")
	check(Talk.new(data, "Ossa", &"flesh_tenders", 1).hostile and not Talk.new(data, "Ossa", &"flesh_tenders", 1).can_trade,
		"and nobody will talk or trade")

	# Killing one is history.
	player.health.invulnerable = true
	await wait_frames(30)  # Let the guard's hit stun wear off: a stunned host cannot swing.
	var people_before: int = camp.site.population
	var count: int = camp.residents.size()
	victim.health.set_current(1)
	await _strike(victim)
	await wait_frames(3)
	var killing = data.events.filter(func(e): return e.type == &"resident_killed")
	check(camp.residents.size() == count - 1 and camp.site.population == people_before - SiteData.PEOPLE_PER_RESIDENT, "killing a resident leaves one fewer, for good")
	check(killing.size() == 1 and killing[0].data.victim in Rumors.tell(killing[0], data, &"flesh_tenders"), "and the killing is told as a rumor")
	player.health.invulnerable = false

	# Friends feel it too.
	data.set_relation(&"flesh_tenders", &"choir_of_waking", 50)
	var choir_before: int = data.host_standing(&"choir_of_waking")
	data.record_deed(&"flesh_tenders", -40)
	check(data.host_standing(&"choir_of_waking") == choir_before - 10, "a deed against a faction's friends costs a quarter as much with it")

	# Prices follow standing.
	data.current_life().standing[&"flesh_tenders"] = -10
	for i in data.inventory.size():
		data.inventory[i] = &""
	data.inventory[0] = &"bone_shard"
	var wary := Talk.new(data, "Ossa", &"flesh_tenders", 1)
	check(wary.can_trade and not wary.has_payment and "two" in wary.offer_text, "when they are wary, it costs two")
	data.inventory[1] = &"breath_sac"
	wary = Talk.new(data, "Ossa", &"flesh_tenders", 1)
	wary.trade()
	check(data.inventory.count(&"bile_bulb") == 1 and not &"bone_shard" in data.inventory and not &"breath_sac" in data.inventory, "and takes both")
	data.current_life().standing[&"flesh_tenders"] = 50
	data.inventory[2] = &"bone_shard"
	Talk.new(data, "Ossa", &"flesh_tenders", 1).trade()
	check(data.inventory.count(&"bile_bulb") == 3, "friends get one extra")

	# Clearing their land of creatures wins a little favour.
	var leech = entity("LeechChamber")
	var holder: StringName = data.faction_at(ChunkData.world_to_chunk(leech.global_position)) if leech else &""
	if leech and holder != &"":
		var before: int = data.standing(holder)
		leech.get_node("Health").last_hit_source = &"player"
		game._on_entity_killed(leech)
		check(data.standing(holder) == before + 2, "killing a creature in a faction's land pleases it (+2)")

	# Saved with the host, and gone with it.
	data.current_life().standing[&"flesh_tenders"] = -70
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	await wait_frames(5)
	data = state.data
	check(data.standing(&"flesh_tenders") == -70, "standing survives a save and load")
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(5)
	check(data.standing(&"flesh_tenders") == 20 and not entity("TenderCamp").is_hostile(),
		"a new host is a new body: the Flesh-Tenders do not know it")


## Stands left of `target`, faces it and swings the sword.
func _strike(target: Node2D) -> void:
	await goto(target.global_position + Vector2(-40, -26), 2)
	player._facing = 1.0
	await press("attack", 2)
	await wait_frames(6)
