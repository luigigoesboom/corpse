extends Node
## Serializes WorldData to user://saves/ and back. Owns save versioning and migrations.
##
## user:// is Godot's per-user data folder. On Windows that is
## %APPDATA%\Godot\app_userdata\Corpse\.
##
## File layout: one Variant (store_var) holding
##   { "save_version": int, "saved_at": float, "summary": {...}, "world": WorldData.to_dict() }
## "summary" (week 41) is what the slot list shows: host name, lives, year,
## time played. Slots 1..3 are the player's (SLOTS); 0 is the old quick
## slot, still read; tests use 98 and 99.
##
## Rules (docs/ARCHITECTURE.md, "Saving"):
## - Never store_var/get_var with full_objects / allow_objects. A save file that
##   can hold objects can hold scripts, and loading it would run them.
## - Write to a temp file, then rename, so a crash mid-save keeps the old save.
## - When the format changes, bump SAVE_VERSION and add a step to _migrate().

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 21
const SLOTS := [1, 2, 3]


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
		"summary": summary_of(WorldState.data),
		"world": WorldState.data.to_dict(),
	})
	file.close()

	return DirAccess.rename_absolute(tmp_path, path)


## What a slot holds, for the slot list: {} if empty or unreadable, else
## {"host", "lives", "year", "seconds", "saved_at", "version"}.
func summary(slot: int) -> Dictionary:
	var file := FileAccess.open(slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var save: Variant = file.get_var()
	file.close()
	if typeof(save) != TYPE_DICTIONARY or typeof(save.get("world")) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = save.get("summary", {})
	if out.is_empty():  # Saves from before week 41: read it from the world.
		out = summary_of(WorldData.from_dict(save.world))
	out["saved_at"] = float(save.get("saved_at", 0.0))
	out["version"] = int(save.get("save_version", 0))
	return out


static func summary_of(world: WorldData) -> Dictionary:
	var seconds := 0.0
	for life in world.lives:
		seconds += life.seconds_alive
	var life := world.current_life()
	return {"host": life.host_name if life else "", "lives": world.lives.size(), "year": world.year, "seconds": seconds}


## The slot saved to most recently (player slots and the old quick slot),
## or -1 if there is none.
func latest_slot() -> int:
	var best := -1
	var best_time := -1.0
	for slot in [0] + SLOTS:
		var s := summary(slot)
		if not s.is_empty() and s.saved_at > best_time:
			best = slot
			best_time = s.saved_at
	return best


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
	if slot == 0 or slot in SLOTS:
		WorldState.slot = slot  # Later saves go back where this came from.
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
	if save.save_version == 5:
		# v6 (week 21): life records. The game starts a life for a world without one.
		save.world["lives"] = []
		save.save_version = 6
	if save.save_version == 6:
		# v7 (week 22): corpses. Dead hosts keep what they carried on the body.
		for life in save.world.get("lives", []):
			life["corpse_position"] = life.get("death_position", Vector2.ZERO)
			life["corpse_items"] = life.get("carried_items", []).duplicate()
			life["corpse_mutations"] = life.get("carried_mutations", {}).duplicate()
		save.save_version = 7
	if save.save_version == 7:
		# v8 (week 23): event log. removed_entities may now hold a kind instead
		# of true; old entries stay true, which Aftermath never brings back.
		save.world["events"] = []
		save.save_version = 8
	if save.save_version == 8:
		# v9 (week 24): where each host woke.
		for life in save.world.get("lives", []):
			life["origin"] = life.get("origin", "")
		save.save_version = 9
	if save.save_version == 9:
		# v10 (week 26): factions. Empty here; the game seeds them from
		# data/factions and the territory map when the world loads.
		save.world["factions"] = []
		save.save_version = 10
	if save.save_version == 10:
		# v11 (week 27): sites. Empty here; the game fills the settlement
		# slots from faction territory when the world loads.
		save.world["sites"] = []
		save.save_version = 11
	if save.save_version == 11:
		# v12 (week 28, D-025): history. Factions carry their own identity
		# (filled from their FactionDef when loaded); a site's population is
		# people, not residents shown, and sites say which slot they are in.
		for site in save.world.get("sites", []):
			site["population"] = int(site.get("population", 0)) * SiteData.PEOPLE_PER_RESIDENT
			site["slot"] = site.get("id", "")
		save.save_version = 12
	if save.save_version == 12:
		# v13 (week 29): artifacts made from history.
		save.world["artifacts"] = []
		save.save_version = 13
	if save.save_version == 13:
		# v14 (week 31): host standing per life. Nothing to convert: a life
		# without standing uses its factions' attitudes to its host type.
		save.save_version = 14
	if save.save_version == 14:
		# v15 (week 32): the fragment's legend with each faction.
		save.world["legend"] = {}
		save.save_version = 15
	if save.save_version == 15:
		# v16 (week 33): who claimed each body and where it was taken. Nothing
		# to convert: missing means nobody, and the body stays where it lay.
		save.save_version = 16
	if save.save_version == 16:
		# v17 (week 34): ichor carried, banked, on bodies; boons. Nothing to
		# convert: everything starts at none.
		save.save_version = 17
	if save.save_version == 17:
		# v18 (week 35): events read on murals. Nothing to convert.
		save.save_version = 18
	if save.save_version == 18:
		# v19 (week 36): bribes per life. Nothing to convert.
		save.save_version = 19
	if save.save_version == 19:
		# v20 (week 37): offerings per life. Nothing to convert.
		save.save_version = 20
	if save.save_version == 20:
		# v21 (week 38): where the valve keys lie. Nothing to convert: a world
		# without key places gets them from its history when it loads.
		save.save_version = 21
	return save
