class_name MutationDb
extends RefCounted
## Finds MutationDefs by id. Loads every .tres in data/mutations/ the first time it is asked.

const DIR := "res://data/mutations"

static var _defs := {}


static func get_def(id: StringName) -> MutationDef:
	if _defs.is_empty():
		_load_all()
	return _defs.get(id)


static func _load_all() -> void:
	for file in DirAccess.get_files_at(DIR):
		# Exported builds list "acid_gland.tres.remap" instead of the .tres itself.
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var def := load(DIR.path_join(file)) as MutationDef
			if def:
				_defs[def.id] = def
