class_name MutationHost
extends Node
## Lives on the player. Grows the host's mutations from WorldData.mutations:
## a placeholder body part at the slot's socket and an ability node (child of
## this node). Also handles eating an item that grants a mutation.

var _parts: Array[Node] = []

@onready var _player: Player = get_parent()


func _ready() -> void:
	EventBus.eat_requested.connect(_on_eat_requested)
	EventBus.mutations_changed.connect(sync)
	EventBus.world_loaded.connect(sync)


## Called by the player every physics frame.
func physics_tick(delta: float) -> void:
	for ability in get_children():
		ability.physics_tick(delta)


## Rebuilds parts and abilities from the data.
func sync() -> void:
	for part in _parts:
		part.queue_free()
	_parts.clear()
	for ability in get_children():
		remove_child(ability)
		ability.queue_free()
	if WorldState.data == null:
		return
	for slot in WorldState.data.mutations:
		var def := MutationDb.get_def(WorldState.data.mutations[slot])
		if def == null:
			continue
		var part := Polygon2D.new()
		part.polygon = def.part_polygon
		part.color = def.part_color
		_player.socket(slot).add_child(part)
		_parts.append(part)
		if def.ability:
			var ability: MutationAbility = def.ability.new()
			ability.player = _player
			ability.def = def
			ability.name = String(def.id)
			add_child(ability)


func _on_eat_requested(slot: int) -> void:
	var data := WorldState.data
	var item := ItemDb.get_def(data.inventory[slot])
	if item == null or item.grants_mutation == &"":
		return
	var mutation := MutationDb.get_def(item.grants_mutation)
	if mutation == null:
		return
	data.take_from_inventory(slot)
	var lost := data.graft(mutation.slot, mutation.id)
	var text := "%s grows from your %s" % [mutation.display_name, mutation.slot]
	if lost != &"" and lost != mutation.id:
		text += ", your %s withers" % MutationDb.get_def(lost).display_name
	EventBus.notify.emit(text)
	EventBus.inventory_changed.emit()
	EventBus.mutations_changed.emit()
