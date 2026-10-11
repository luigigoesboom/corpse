extends "res://tests/test_case.gd"
## Village quests (D-033): peoples offer tasks made from the world as it is;
## each kind can be taken, done and handed in for ichor and standing; tasks
## that can no longer be done fail; all of it is saved.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	await start_scene("res://game.tscn", 4242)
	var data = state.data
	var quests: GDScript = load("res://src/sim/quests/quests.gd")
	var talk_script: GDScript = load("res://src/dialogue/talk.gd")
	var item_db: GDScript = load("res://src/items/item_db.gd")

	# Asking for work.
	var talk = talk_script.new(data, "Somebody", &"flesh_tenders", 1)
	check(talk.has_work and talk.work_text != "" and not talk.work_taken, "the Flesh-Tenders have work: \"%s\"" % talk.work_text)
	talk.accept_work()
	check(data.quests.size() == 1 and talk.work_taken, "taking it makes it yours")
	var again = talk_script.new(data, "Somebody else", &"flesh_tenders", 2)
	check(again.work_taken and "still have our task" in again.work_text, "they remind you of it: \"%s\"" % again.work_text)
	data.quests.clear()

	# Fetch: bring what they want.
	var fetch = quests._make(&"fetch", &"flesh_tenders", null, "bone_shard", 2, 16, 10)
	fetch.id = "q_fetch"
	quests.accept(data, fetch)
	check(not quests.ready(data, fetch), "a fetch is not ready with empty pockets")
	data.inventory.fill(&"")
	data.add_to_inventory(&"bone_shard")
	data.add_to_inventory(&"bone_shard")
	var ichor_before: int = data.ichor
	talk = talk_script.new(data, "Somebody", &"flesh_tenders", 3)
	check(talk.can_turn_in, "with two bone shards it can be handed in")
	talk.turn_in()
	check(fetch.state == &"rewarded" and data.ichor == ichor_before + 16 and not data.inventory.has(&"bone_shard"), "handing in takes the shards and pays: \"%s\"" % talk.turn_in_text)

	# Cull: kills count.
	var cull = quests._make(&"cull", &"flesh_tenders", null, "gut_leech", 3, 18, 15)
	cull.id = "q_cull"
	quests.accept(data, cull)
	for i in 3:
		quests.on_kill(data, &"gut_leech")
	check(cull.state == &"done", "three leeches killed: the cull is done")
	print("  ", quests.summary(data, cull))

	# Slay: a legendary beast.
	var beast = data.beasts.values().filter(func(b): return b.is_alive() and b.region == &"gut")
	if not beast.is_empty():
		var slay = quests._make(&"slay", &"flesh_tenders", null, beast[0].id, 1, 45, 25)
		slay.id = "q_slay"
		print("  ", quests.ask_text(data, slay))
		quests.accept(data, slay)
		quests.on_beast_slain(data, beast[0].id)
		check(slay.state == &"done", "killing the beast does the slay task")
		var slay2 = quests._make(&"slay", &"choir_of_waking", null, beast[0].id, 1, 45, 25)
		slay2.id = "q_slay2"
		quests.accept(data, slay2)
		beast[0].died_year = data.year
		quests.check(data)
		check(slay2.state == &"failed", "a beast killed by someone else fails the task")

	# Deliver: a sealed gift to another people.
	data.inventory.fill(&"")
	var deliver = quests._make(&"deliver", &"flesh_tenders", null, "choir_of_waking", 1, 20, 15)
	deliver.id = "q_deliver"
	check(quests.accept(data, deliver) and data.inventory.has(StringName(deliver.item)), "a delivery puts a gift in your pockets")
	item_db.refresh_generated(data)
	check(item_db.display_name(StringName(deliver.item)) == "Sealed gift", "the gift is an item")
	var choir_before: int = data.standing(&"choir_of_waking")
	talk = talk_script.new(data, "A chorister", &"choir_of_waking", 4)
	check(talk.can_turn_in, "the Choir takes the gift")
	talk.turn_in()
	check(deliver.state == &"rewarded" and data.standing(&"choir_of_waking") > choir_before, "and both peoples are warmer for it: \"%s\"" % talk.turn_in_text)

	# Saved.
	var count: int = data.quests.size()
	saves.save_game(98)
	saves.load_game(98)
	await process_frame
	check(state.data.quests.size() == count and state.data.quests["q_cull"].state == &"done", "tasks are saved")
