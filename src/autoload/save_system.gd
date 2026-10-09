extends Node
## Serializes WorldData to user://saves/ and back. Owns save versioning and migrations.
##
## user:// is Godot's per-user data folder. On Windows that is
## %APPDATA%\Godot\app_userdata\Corpse\.
##
## File layout: one Variant (store_var) holding
##   { "save_version": int, "saved_at": float, "world": WorldData.to_dict() }
##
## Rules (docs/ARCHITECTURE.md, "Saving"):
## - Never store_var/get_var with full_objects / allow_objects. A save file that
##   can hold objects can hold scripts, and loading it would run them.
## - Write to a temp file, then rename, so a crash mid-save keeps the old save.
## - When the format changes, bump SAVE_VERSION and add a step to _migrate().

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 5


func slot_path(slot: int) -> String:
	return "%s/slot_%d.save" % [SAVE_DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


func save_game(slot: int) -> Error:
	if WorldState.data == null:
		return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := slot_path(slot)
	var tmp_path := path + ".tmp"

	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var({
		"save_version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"world": WorldState.data.to_dict(),
	})
	file.close()

	return DirAccess.rename_absolute(tmp_path, path)


## On success, replaces WorldState.data (which emits EventBus.world_loaded).
## On failure, the current world is left untouched.
func load_game(slot: int) -> Error:
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var save: Variant = file.get_var()
	file.close()

	if typeof(save) != TYPE_DICTIONARY or typeof(save.get("save_version")) != TYPE_INT \
			or typeof(save.get("world")) != TYPE_DICTIONARY:
		return ERR_FILE_CORRUPT
	if save.save_version > SAVE_VERSION:
		return ERR_FILE_UNRECOGNIZED  # Made by a newer build of the game.

	save = _migrate(save)
	WorldState.set_data(WorldData.from_dict(save.world))
	return OK


## Upgrades an old save one version at a time until it matches SAVE_VERSION.
## Never delete a step: someone may still have a version 1 save.
func _migrate(save: Dictionary) -> Dictionary:
	if save.save_version == 1:
		# v2 (week 9): inventory, dropped items, picked-up placed entities.
		save.world["inventory"] = []
		save.world["removed_entities"] = {}
		save.world["next_id"] = 1
		save.save_version = 2
	if save.save_version == 2:
		# v3: inventory became fixed pockets. Empty pockets are &"".
		var pockets: Array = save.world.get("inventory", []).duplicate()
		pockets.resize(WorldData.INVENTORY_SIZE)
		for i in pockets.size():
			if pockets[i] == null:
				pockets[i] = &""
		save.world["inventory"] = pockets
		save.save_version = 3
	if save.save_version == 3:
		# v4: host health (-1 = full).
		save.world["player_health"] = -1
		save.save_version = 4
	if save.save_version == 4:
		# v5: host mutations (slot -> mutation id).
		save.world["mutations"] = {}
		save.save_version = 5
	return save
