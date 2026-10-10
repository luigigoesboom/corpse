class_name ItemDb
extends RefCounted
## Finds ItemDefs by id. Loads every .tres in data/items/ the first time it is asked.

const DIR := "res://data/items"

static var _defs := {}
## Items made by the world rather than by hand (artifacts, week 29): set by
## the game whenever a world loads, from ArtifactText.item_defs().
static var _generated := {}


static func get_def(id: StringName) -> ItemDef:
	if _defs.is_empty():
		_load_all()
	return _defs.get(id, _generated.get(id))


static func set_generated(defs: Dictionary) -> void:
	_generated = defs


static func display_name(id: StringName) -> String:
	var def := get_def(id)
	return def.display_name if def else String(id)


static func _load_all() -> void:
	for file in DirAccess.get_files_at(DIR):
		# Exported builds list "bile_bulb.tres.remap" instead of the .tres itself.
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var def := load(DIR.path_join(file)) as ItemDef
			if def:
				_defs[def.id] = def
