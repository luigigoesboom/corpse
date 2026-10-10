class_name FactionDb
extends RefCounted
## Finds FactionDefs by id. Loads every .tres in data/factions/ the first time it is asked.

const DIR := "res://data/factions"

static var _defs := {}


static func get_def(id: StringName) -> FactionDef:
	if _defs.is_empty():
		_load_all()
	return _defs.get(id)


## Faction ids in alphabetical order, so anything that loops over them (the
## history sim) is repeatable. Sorted as text: Array.sort() does not sort
## StringNames alphabetically.
static func all_ids() -> Array:
	if _defs.is_empty():
		_load_all()
	var ids := _defs.keys()
	ids.sort_custom(func(a, b): return String(a) < String(b))
	return ids


static func _load_all() -> void:
	for file in DirAccess.get_files_at(DIR):
		# Exported builds list "x.tres.remap" instead of the .tres itself.
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var def := load(DIR.path_join(file)) as FactionDef
			if def:
				_defs[def.id] = def
