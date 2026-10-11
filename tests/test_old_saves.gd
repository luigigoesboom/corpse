extends "res://tests/test_case.gd"
## Old saves still load (week 46): every save in tests/fixtures, written by
## an older build (tests/make_fixture.gd), goes through the migrations and
## comes back as the same world: one death in, the body remembered, a bile
## bulb in the pockets, its past intact. When the
## save format changes, bump SaveSystem.SAVE_VERSION, add the migration, and
## run tests/make_fixture.gd once for the new version.

const DIR := "res://tests/fixtures/"


func run() -> void:
	var saves = autoload("SaveSystem")
	var state = autoload("WorldState")
	await start_scene("res://game.tscn")
	var fixtures := Array(DirAccess.get_files_at(DIR)).filter(func(f): return f.ends_with(".save"))
	check(fixtures.size() >= 1, "there are old saves to try (%s)" % [fixtures])
	for file in fixtures:
		var bytes := FileAccess.get_file_as_bytes(DIR + file)
		var out := FileAccess.open(saves.slot_path(98), FileAccess.WRITE)
		out.store_buffer(bytes)
		out.close()
		var read := FileAccess.open(DIR + file, FileAccess.READ)
		var version: int = read.get_var().save_version
		read.close()
		check(version <= saves.SAVE_VERSION, "%s was written by version %d" % [file, version])
		check(saves.load_game(98) == OK, "%s loads" % file)
		await wait_frames(10)
		var data = state.data
		check(data.lives.size() == 2 and data.lives[0].death_year >= 0, "%s: one host dead, the next alive" % file)
		var body = data.lives[0]
		check(body.corpse_position != Vector2.ZERO and (&"bone_shard" in body.corpse_items or body.corpse_faction != &""),
			"%s: the first body is where it fell, with its bone shard or taken by a people" % file)
		check(&"bile_bulb" in data.inventory, "%s: the bulb is still in the pockets" % file)
		check(data.events.size() > 50 and not data.factions.is_empty() and not data.sites.is_empty(), "%s: its past is intact (%d events)" % [file, data.events.size()])
		check(data.factions.values().all(func(f): return f.region != &""), "%s: every people has a region" % file)
		check(data.sites.values().all(func(s): return s.region != &""), "%s: every place has a region" % file)
		check(player.global_position.distance_to(data.player_position) < 40.0, "%s: the host stands where it was saved" % file)
		# Saved again by this build, it loads the same.
		var events: int = data.events.size()
		var seed_value: int = data.world_seed
		check(saves.save_game(99) == OK and saves.load_game(99) == OK, "%s: saves again in the current format" % file)
		await wait_frames(5)
		check(state.data.events.size() == events and state.data.world_seed == seed_value, "%s: and comes back the same" % file)
	for slot in [98, 99]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(slot)))
