extends Node
## Global signals only. No logic, no state.
##
## Add a signal here when two systems that should not know about each other
## need to talk (e.g. player_died, deed_recorded, chunk_loaded).
## Emit:    EventBus.player_died.emit(record)
## Listen:  EventBus.player_died.connect(_on_player_died)
##
## No class_name on purpose: an autoload is already reachable by its name,
## and a matching class_name would clash with it.

## WorldState.data was replaced (new world or loaded save). Rebuild from it.
@warning_ignore("unused_signal")
signal world_loaded
