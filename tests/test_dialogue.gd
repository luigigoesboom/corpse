extends "res://tests/test_case.gd"
## Dialogue v1 (week 30): greetings by faction and standing, rumors from the
## event log, simple barter, through Dialogue Manager.


func run() -> void:
	var state := autoload("WorldState")
	var dm := autoload("DialogueManager")
	await start_scene("res://game.tscn")
	var data = state.data
	var tenders: FactionDef = FactionDb.get_def(&"flesh_tenders")
	var choir: FactionDef = FactionDb.get_def(&"choir_of_waking")

	# Rumors are things that happened, told by someone who was there.
	var talk := Talk.new(data, "Ossa", &"flesh_tenders", 3)
	var matched := 0
	for i in 5:
		var text := talk.rumor()
		var event_id: int = talk.told_events()[-1]
		var event: EventRecord = data.events.filter(func(e): return e.id == event_id)[0]
		var told := Rumors.clause(EventText.describe(event, data))
		if told in text or event.type == &"host_died":
			matched += 1
	check(matched == 5 and talk.told_events().size() == 5, "five rumors, all different, each retelling an event from the log")

	# Your own death becomes gossip, and the Choir can tell it was you.
	player.health.take_damage(99, player.global_position + Vector2(10, 0), 0.0, &"gut_leech")
	await create_timer(1.5).timeout
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(3)
	var top: EventRecord = Rumors.candidates(data, &"choir_of_waking")[0].event
	check(top.type == &"host_died" and top.actors[0] == data.lives[0].host_name, "your last host's death is the talk of the town")
	var gossip := Rumors.tell(top, data, &"choir_of_waking", choir.senses_fragment)
	check(data.lives[0].host_name in gossip and "You were there" in gossip, "a chorister senses it was you (\"%s\")" % gossip)

	# Greetings depend on who you are to them.
	data.current_life().host_type = &"colonist"
	check(Talk.new(data, "Ossa", &"flesh_tenders", 1).greeting in tenders.greetings["neutral"], "a Flesh-Tender greets a colonist neutrally")
	data.current_life().host_type = &"antibody"
	var cold := Talk.new(data, "Ossa", &"flesh_tenders", 1)
	check(cold.hostile and cold.greeting in tenders.greetings["hostile"] and not cold.can_trade, "and an antibody with hostility, and won't trade with it")
	check(Talk.new(data, "Vexith", &"choir_of_waking", 1).greeting in choir.greetings["friendly"], "while the Choir welcomes an antibody")
	data.current_life().host_type = &"colonist"

	# Barter: their wares for what they want.
	for i in data.inventory.size():
		data.inventory[i] = &""
	data.inventory[2] = &"bone_shard"
	var deal := Talk.new(data, "Ossa", &"flesh_tenders", 1)
	var traded := [false]
	deal.traded.connect(func(): traded[0] = true)
	check(deal.can_trade and deal.has_payment and "Bone Shard" in deal.offer_text, "a Flesh-Tender offers a trade for your Bone Shard")
	deal.trade()
	check(&"bile_bulb" in data.inventory and not &"bone_shard" in data.inventory and traded[0], "trading swaps it for a Bile Bulb")
	for i in data.inventory.size():
		data.inventory[i] = &""
	data.inventory[2] = StringName(data.artifacts.keys()[0]) if not data.artifacts.is_empty() else &"bone_shard"
	var relic := Talk.new(data, "Vexith", &"choir_of_waking", 1)
	relic.trade()
	check(&"breath_sac" in data.inventory and data.inventory[2] == &"", "the Choir takes relics (or bone) for a Breath Sac")

	# The conversation itself, through Dialogue Manager.
	var resource = load("res://data/dialogue/resident.dialogue")
	var chat := Talk.new(data, "Ossa", &"flesh_tenders", 9)
	var line = await dm.get_next_dialogue_line(resource, "start", [chat])
	check(line != null and line.character == "Ossa" and line.text == chat.greeting, "the conversation opens with the greeting")
	line = await dm.get_next_dialogue_line(resource, line.next_id, [chat])
	var options: Array = line.responses.map(func(r): return r.text)
	check("What news?" in options and "Tell me about your people." in options and "Farewell." in options, "then offers news, their people, and farewell (%s)" % [options])
	var news = line.responses.filter(func(r): return r.text == "What news?")[0]
	line = await dm.get_next_dialogue_line(resource, news.next_id, [chat])
	check(line.text.ends_with(".") and chat.told_events().size() == 1, "asking for news gets a rumor: \"%s\"" % line.text)

	# E on a resident opens it in game, and the world waits.
	await goto(Vector2(1220, 3170), 40)
	var camp = entity("TenderCamp")
	var npc = camp.residents[0]
	await goto(npc.global_position + Vector2(0, -26), 2)
	npc.talk()
	await process_frame
	await process_frame
	var balloon = root.get_children().filter(func(n): return n.has_method("apply_dialogue_line"))
	check(balloon.size() == 1 and root.get_tree().paused, "talking opens the dialogue box and pauses the game")
	balloon[0].dialogue_line = null  # The conversation ends.
	await process_frame
	check(not root.get_tree().paused, "and the game goes on when it ends")
