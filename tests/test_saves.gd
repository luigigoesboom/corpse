extends "res://tests/test_case.gd"
## Saving and loading (weeks 3, 9 and later): round trip, bad files, migrations.


func run() -> void:
	var saves := autoload("SaveSystem")
	var state := autoload("WorldState")
	await start_scene("res://game.tscn")

	# Round trip.
	await goto(Vector2(3000, 3178), 20)
	var data = state.data
	data.player_position = player.global_position
	data.year = 42
	data.inventory[0] = &"bone_shard"
	data.mutations = {"mouth": &"acid_gland"}
	data.removed_entities["BileBulb"] = true
	check(saves.save_game(98) == OK, "save succeeds")
	check(saves.save_game(98) == OK, "saving over an existing save succeeds")
	check(not FileAccess.file_exists(saves.slot_path(98) + ".tmp"), "no temp file left behind")
	var seed_value: int = data.world_seed

	var other = WorldData.create(seed_value + 1)
	other.player_position = game.get_node("World/PlayerSpawn").global_position
	state.set_data(other)
	await wait_frames(5)
	check(saves.load_game(98) == OK, "load succeeds")
	await wait_frames(5)
	data = state.data
	check(data.world_seed == seed_value and data.year == 42, "seed and year restored")
	check(player.global_position == data.player_position, "player is back where they saved")
	check(data.inventory[0] == &"bone_shard" and data.mutations.get("mouth") == &"acid_gland", "pockets and body restored")
	check(entity("BileBulb") == null, "an item picked up before saving stays gone")

	# Bad files must fail cleanly and leave the world alone.
	var file := FileAccess.open(saves.slot_path(99), FileAccess.WRITE)
	file.store_string("garbage!!")
	file.close()
	check(saves.load_game(99) == ERR_FILE_CORRUPT and state.data.world_seed == seed_value, "a corrupt save is refused, world untouched")
	file = FileAccess.open(saves.slot_path(99), FileAccess.WRITE)
	file.store_var({"save_version": 999, "world": {}})
	file.close()
	check(saves.load_game(99) == ERR_FILE_UNRECOGNIZED, "a save from a newer game version is refused")
	check(saves.load_game(97) == ERR_FILE_NOT_FOUND, "a missing save reports not found")

	# A version 1 save (week 3 format) still loads and is upgraded.
	file = FileAccess.open(saves.slot_path(99), FileAccess.WRITE)
	file.store_var({"save_version": 1, "saved_at": 0.0, "world": {
		"world_seed": 5, "year": 3, "player_position": Vector2(464, 3178), "chunk_diffs": {}}})
	file.close()
	check(saves.load_game(99) == OK, "a version 1 save loads")
	data = state.data
	check(data.inventory.size() == WorldData.INVENTORY_SIZE and data.mutations.is_empty() and data.player_health == -1,
		"migrations fill in pockets, body and health")
