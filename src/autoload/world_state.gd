extends Node
## Holds the current WorldData. Single source of truth for the sim.
##
## Replace the world only through set_data(), so everyone listening on
## EventBus.world_loaded can rebuild from it.

var data: WorldData
## The save slot this world lives in (week 41): saves, autosaves and quick
## saves go here. 1..3 from the menus; tests use their own slots.
var slot := 1


## Forget the current world (e.g. "New game" from the main menu).
func clear() -> void:
	data = null


func set_data(new_data: WorldData) -> void:
	data = new_data
	EventBus.world_loaded.emit()
