class_name HostDb
extends RefCounted
## Finds HostDefs by id. Loads every .tres in data/hosts/ the first time it is asked.

const DIR := "res://data/hosts"

static var _defs := {}


static func get_def(id: StringName) -> HostDef:
	if _defs.is_empty():
		_load_all()
	return _defs.get(id)


static func all_ids() -> Array:
	if _defs.is_empty():
		_load_all()
	return _defs.keys()


static func _load_all() -> void:
	for file in DirAccess.get_files_at(DIR):
		# Exported builds list "colonist.tres.remap" instead of the .tres itself.
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var def := load(DIR.path_join(file)) as HostDef
			if def:
				_defs[def.id] = def
