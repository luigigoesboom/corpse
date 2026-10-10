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

@warning_ignore_start("unused_signal")

## WorldState.data was replaced (new world or loaded save). Rebuild from it.
signal world_loaded
## The player wants to pick up this WorldItem.
signal pickup_requested(item: Node)
## The player wants to drop what is in this inventory pocket.
signal drop_requested(slot: int)
## Something (e.g. a dying creature) leaves an item in the world.
signal item_drop_requested(item: StringName, position: Vector2)
## WorldState.data.inventory changed.
signal inventory_changed
## The player wants to eat what is in this inventory pocket.
signal eat_requested(slot: int)
## WorldState.data.mutations changed.
signal mutations_changed
## The player searches an old body: WorldData.lives[life_index].
signal corpse_search_requested(life_index: int)
## Show a short message to the player (pickups, saves, warnings).
signal notify(text: String)
## The player's host died.
signal player_died
## Something with a Hurtbox took damage (for hitstop, shake, sound).
signal hit_landed(target: Node, amount: int)
## A hand-placed entity (child of Entities in world.tscn) died for good.
signal entity_killed(entity: Node)

@warning_ignore_restore("unused_signal")

## A boss noticed the player: show its health bar.
signal boss_engaged(boss: Node)
## A boss died.
signal boss_defeated(boss: Node)
## Something big happened (a slam, a roar): shake the camera, strength ~ px.
signal shake_requested(strength: float)
