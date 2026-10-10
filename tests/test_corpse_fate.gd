extends "res://tests/test_case.gd"
## Corpse fate driven by factions (week 33): the people whose land a body
## lies in decide what becomes of it; the Choir carries the fragment's old
## bodies to its shrine.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn")
	var data = state.data
	var places := {}
	for template in game._entities.templates():
		if template.has_method("body_spot"):
			places[String(template.get_meta(&"entity_key"))] = template.body_spot()
	var chapel_spot: Vector2 = places.get("ChoirChapel", Vector2.ZERO)
	var choir_land := ChunkData.world_to_chunk(chapel_spot)
	check(data.faction_at(choir_land) == &"choir_of_waking", "the chapel stands in Choir land")
	var camp_spot: Vector2 = places.get("TenderCamp", Vector2.ZERO)
	check(data.faction_at(ChunkData.world_to_chunk(camp_spot)) == &"flesh_tenders", "the camp stands in Flesh-Tender land")

	# On plain data: who decides, and what they do, over many deaths.
	var choir_fates := _fates(data, chapel_spot + Vector2(-300, 0), places, 0)
	var tender_fates := _fates(data, camp_spot + Vector2(300, 0), places, 0)
	check(choir_fates.get(&"enshrined", 0) >= 20, "bodies in Choir land are mostly enshrined (%s)" % choir_fates)
	check(tender_fates.get(&"eaten", 0) + tender_fates.get(&"looted", 0) >= 25 and tender_fates.get(&"enshrined", 0) <= 8,
		"bodies in Flesh-Tender land are mostly eaten or looted; now and then the Choir senses one and fetches it (%s)" % tender_fates)
	var spite := _fates(data, chapel_spot + Vector2(-300, 0), places, -60)
	check(not spite.has(&"enshrined"), "a Choir that hates the fragment never enshrines its body (%s)" % spite)

	# In the game: die near the chapel with things in your pockets.
	player.health.invulnerable = true
	await goto(chapel_spot + Vector2(-200, -26), 30)
	player.health.invulnerable = false
	for i in data.inventory.size():
		data.inventory[i] = &""
	data.inventory[0] = &"bone_shard"
	data.inventory[1] = &"bile_bulb"
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	var body = data.lives[0]
	var site = data.site_in_slot("ChoirChapel")
	var hint: String = CorpseFate.claim(data, 0, &"choir_of_waking", &"enshrined", site, places)
	check(body.corpse_state == &"enshrined" and body.corpse_position.distance_to(chapel_spot) < 1.0, "the Choir carries the body to its chapel")
	check(site.name in hint and "shrine" in hint, "and the next host is told where (\"%s\")" % hint)
	check(body.corpse_items.size() == 2, "nothing is taken from an enshrined body")
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(5)

	# The new host finds the old body in the Choir's shrine.
	check(Aftermath.apply(data, 3, SeededRng.make(["fate", 1]), places) != null and body.corpse_items.size() == 2,
		"scavengers do not get into a shrine, even decades later")
	game._entities.rebuild()
	game._chunks.reset()
	await goto(chapel_spot + Vector2(-30, -26), 40)
	var corpse: Node = null
	for node in game._corpses.get_children():
		if node.life_index == 0:
			corpse = node
	check(corpse != null and corpse.global_position.distance_to(chapel_spot) < 1.0, "you find your old body in the Choir shrine")
	check(corpse != null and "enshrined" in corpse.get_node("Prompt").text, "it says so")
	var told := Rumors.candidates(data, &"choir_of_waking").filter(func(c): return c.event.type == &"corpse_claimed")
	check(not told.is_empty() and site.name in EventText.describe(told[0].event, data), "and the Choir talks about it")

	# Taking it back is robbing their shrine (unless they count you a friend).
	var before: int = data.standing(&"choir_of_waking")
	corpse.interact()
	await wait_frames(2)
	check(&"bone_shard" in data.inventory and data.standing(&"choir_of_waking") < before, "taking your things back angers the Choir (%d -> %d)" % [before, data.standing(&"choir_of_waking")])
	check(data.events.any(func(e): return e.type == &"shrine_robbed" and e.id in data.current_life().deed_event_ids), "and is a deed they remember")

	# Saved.
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	await wait_frames(5)
	var loaded = state.data.lives[0]
	check(loaded.corpse_state == &"enshrined" and loaded.corpse_faction == &"choir_of_waking" and loaded.corpse_site == site.id,
		"who claimed the body survives a save and load")


## Kills a fresh host at `where` 40 times (strongest time gap) and counts the fates.
func _fates(world, where: Vector2, places: Dictionary, legend: int) -> Dictionary:
	var counts := {}
	for i in 40:
		var data := WorldData.from_dict(world.to_dict())
		data.lives.clear()
		data.legend[&"choir_of_waking"] = legend
		data.start_life(&"colonist")
		data.inventory[0] = &"bone_shard"
		data.mutations = {"mouth": &"acid_gland"}
		data.end_life(where, where, &"")
		CorpseFate.apply(data, 1.0, SeededRng.make(["fates", i]), places, {"hints": []})
		var fate: StringName = data.lives[0].corpse_state
		counts[fate] = counts.get(fate, 0) + 1
	return counts
