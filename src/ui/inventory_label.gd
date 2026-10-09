extends Label
## Placeholder inventory display: lists what the current host carries.


func _ready() -> void:
	EventBus.inventory_changed.connect(_refresh)
	EventBus.world_loaded.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if WorldState.data == null or WorldState.data.inventory.is_empty():
		text = ""
		return
	var names := PackedStringArray()
	for id in WorldState.data.inventory:
		names.append(ItemDb.display_name(id))
	text = "Carrying: %s   (Q to drop)" % ", ".join(names)
