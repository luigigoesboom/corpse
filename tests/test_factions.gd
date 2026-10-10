extends "res://tests/test_case.gd"
## Factions as data (week 26): definitions, starting territory from the
## painted map, relations, saves, old saves, NPCs, the debug map.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")

	# Definitions.
	var ids := FactionDb.all_ids()
	check(ids == [&"choir_of_waking", &"flesh_tenders"], "two Gut factions are defined (%s)" % [ids])
	var tenders := FactionDb.get_def(&"flesh_tenders")
	var choir := FactionDb.get_def(&"choir_of_waking")
	check(tenders.creed != "" and choir.creed != "" and tenders.color != choir.color, "each has a creed and its own color")
	check(choir.senses_fragment > 0.5 and tenders.senses_fragment < 0.5, "the Choir senses the fragment, the Tenders do not")
	check(choir.host_attitudes[&"antibody"] > 0 and tenders.host_attitudes[&"antibody"] < 0, "they disagree about antibody hosts")

	# Territory from the painted map.
	var claims := FactionTerritory.read_claims()
	check(claims.get(Vector2i(0, 1)) == &"flesh_tenders", "the painted map gives the camp's chunk to the Flesh-Tenders")
	check(claims.get(Vector2i(1, 1)) == &"choir_of_waking", "and the chamber's chunk to the Choir")
	check(not claims.has(Vector2i(3, 1)), "the far cavern belongs to nobody")

	# A new world gets them.
	await start_scene("res://game.tscn")
	var data = state.data
	check(data.factions.size() == 2, "a new world has both factions")
	check(data.faction_at(Vector2i(0, 1)) == &"flesh_tenders" and data.faction_at(Vector2i(1, 1)) == &"choir_of_waking",
		"faction_at() knows who holds a chunk")
	check(data.relation(&"flesh_tenders", &"choir_of_waking") == data.relation(&"choir_of_waking", &"flesh_tenders")
		and data.relation(&"flesh_tenders", &"choir_of_waking") == -25, "relations start mutual: the average of both views (-25)")
	data.set_relation(&"flesh_tenders", &"choir_of_waking", -150)
	check(data.relation(&"choir_of_waking", &"flesh_tenders") == -100, "set_relation() is mutual and clamped")

	# Settlements belong to factions (week 27 builds them, see test_settlements).
	check(data.sites["TenderCamp"].faction == &"flesh_tenders" and data.sites["ChoirChapel"].faction == &"choir_of_waking",
		"each settlement slot is settled by a faction")

	# Saved and loaded.
	data.factions[&"choir_of_waking"].strength = 33
	data.factions[&"choir_of_waking"].territory.append(Vector2i(2, 0))
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	await wait_frames(3)
	data = state.data
	var loaded = data.factions[&"choir_of_waking"]
	check(loaded.strength == 33 and Vector2i(2, 0) in loaded.territory and data.relation(&"choir_of_waking", &"flesh_tenders") == -100,
		"strength, territory and relations survive a save and load")

	# A save from before factions gets them when it loads.
	var file := FileAccess.open(saves.slot_path(99), FileAccess.WRITE)
	file.store_var({"save_version": 9, "world": {"world_seed": 5, "year": 3, "player_position": Vector2(464, 3170), "chunk_diffs": {}}})
	file.close()
	check(saves.load_game(99) == OK, "a version 9 save still loads")
	await wait_frames(3)
	check(state.data.factions.size() == 2 and state.data.faction_at(Vector2i(0, 1)) == &"flesh_tenders",
		"and gets the starting factions")

	# The debug map lists them.
	var lines: Array = game.get_node("UI/DebugMap").legend_lines()
	check(lines.size() == 2 and lines[0].text.begins_with("Choir of Waking:") and lines[1].text.begins_with("Flesh-Tenders:") and "chunks" in lines[0].text,
		"the debug map's legend lists each faction")
