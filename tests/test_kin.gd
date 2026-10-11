extends "res://tests/test_case.gd"
## The Bellows-Kin (week 50): the Lungs have a past of their own with the
## Kin destined in it; the Kin hold the Lungs and live in the roost in the
## Lower Lobe, look like themselves and talk like themselves; the Lobe's
## ruin is from the Lungs' past; an old save gains the Lungs' past when it
## loads; a host can wake at the roost.


func run() -> void:
	await start_scene("res://game.tscn", 4242)
	var data = autoload("WorldState").data
	var kin: FactionData = data.factions.get(&"bellows_kin")
	check(kin != null and kin.is_alive() and kin.region == Regions.LUNGS, "the Bellows-Kin live in the Lungs")
	var lung_peoples: Array = data.factions.values().filter(func(f): return f.region == Regions.LUNGS)
	check(lung_peoples.size() >= 2, "with other peoples in the Lungs' past (%d)" % lung_peoples.size())
	check(not kin.territory.is_empty() and kin.territory.all(func(c): return c.x >= 4), "the Kin hold the Lungs' chunks (%d)" % kin.territory.size())
	check(data.faction_at(Vector2i(6, 1)) == &"bellows_kin", "the Lower Lobe is theirs")

	# The roost.
	var roost: SiteData = data.site_in_slot("KinRoost")
	check(roost != null and roost.faction == &"bellows_kin" and roost.region == Regions.LUNGS, "the roost is a Kin settlement")
	var ruin: SiteData = data.site_in_slot("LobeRuin")
	check(ruin != null and ruin.region == Regions.LUNGS and ruin.kind == &"ruin", "the Lobe's ruin is from the Lungs' past (%s)" % (ruin.name if ruin else "none"))
	await goto(Vector2(13456, 3370), 60)
	var settlement: Node = entity("KinRoost")
	var residents: Array = settlement.get_children().filter(func(c): return c.has_method("talk"))
	check(residents.size() >= 1, "Kin live there (%d)" % residents.size())
	if not residents.is_empty():
		var sprite = residents[0].get_node_or_null("Visual/Sprite")
		check(sprite != null and sprite.body_frames_dir.ends_with("npcs/kin"), "in the Kin's own look")

	# Their words.
	var talk_script: GDScript = load("res://src/dialogue/talk.gd")
	var talk = talk_script.new(data, "Aso", &"bellows_kin", 1)
	var def: FactionDef = FactionDb.get_def(&"bellows_kin")
	var greetings: Array = []
	for tier in def.greetings:
		greetings.append_array(def.greetings[tier])
	check(talk.greeting in greetings, "a Kin greets with Kin words (\"%s\")" % talk.greeting)

	# A host can wake at the roost.
	var places: Array = game.get_node("World/SpawnPoints").get_children().map(func(p): return p.place_name)
	check("the Bellows-Kin roost" in places, "the roost is a place to wake")

	# An old save (before the Lungs had a past) gains it when it loads.
	var saves = autoload("SaveSystem")
	var bytes := FileAccess.get_file_as_bytes("res://tests/fixtures/save_v24.save")
	var out := FileAccess.open(saves.slot_path(98), FileAccess.WRITE)
	out.store_buffer(bytes)
	out.close()
	check(saves.load_game(98) == OK, "the week 48 save loads")
	await wait_frames(10)
	var old = autoload("WorldState").data
	check(old.factions.has(&"bellows_kin") and old.factions[&"bellows_kin"].region == Regions.LUNGS, "and now the Lungs have their past in it")
	var ordered := true
	for i in range(1, old.events.size()):
		ordered = ordered and old.events[i - 1].year <= old.events[i].year
	check(ordered, "its log still reads in order")
	check(old.site_in_slot("KinRoost") != null, "and the roost is filled")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(98)))
