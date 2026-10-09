extends Node
## Holds the current WorldData. Single source of truth for the sim.
##
## Replace the world only through set_data(), so everyone listening on
## EventBus.world_loaded can rebuild from it.

var data: WorldData


## Forget the current world (e.g. "New game" from the main menu).
func clear() -> void:
	data = null


func set_data(new_data: WorldData) -> void:
	data = new_data
	EventBus.world_loaded.emit()
