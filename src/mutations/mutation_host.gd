class_name MutationHost
extends Node
## Gives its parent (a host, see MutationAbility) its mutations: the ability
## nodes (children of this node) and, for the player, the visible parts.
##
## Player: leave `innate` empty. Mutations come from WorldData.mutations, parts
## are drawn as sprite layers over the host's frames (or a fallback polygon at
## the slot's socket), and eating an item that grants a mutation is handled here.
## Creatures: list mutation ids in `innate`. Their art already shows the part.

## Mutation ids a creature is born with. Empty = use the player's WorldData.
@export var innate: Array[StringName] = []

var _parts: Array[Node] = []
var _layer_ids: Array[StringName] = []

@onready var _host: CharacterBody2D = get_parent()


func _ready() -> void:
	if innate.is_empty():
		EventBus.eat_requested.connect(_on_eat_requested)
		EventBus.mutations_changed.connect(sync)
		EventBus.world_loaded.connect(sync)
	else:
		# A duplicated creature (EntityLayer copies templates) arrives with the
		# template's ability nodes, minus their host. Start clean.
		for child in get_children():
			remove_child(child)
			child.free()
		for id in innate:
			_add_ability(MutationDb.get_def(id))


## Called by the host every physics frame.
func physics_tick(delta: float) -> void:
	for ability in get_children():
		ability.physics_tick(delta)


## The ability node for a mutation, if the host has it.
func ability(id: StringName) -> MutationAbility:
	return get_node_or_null(String(id))


## Player only: rebuilds parts and abilities from WorldData.
func sync() -> void:
	for part in _parts:
		part.queue_free()
	_parts.clear()
	for id in _layer_ids:
		_host.sprite.remove_layer(id)
	_layer_ids.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if WorldState.data == null:
		return
	for slot in WorldState.data.mutations:
		var def := MutationDb.get_def(WorldState.data.mutations[slot])
		if def == null:
			continue
		if def.part_frames_dir != "":
			_host.sprite.add_layer(def.id, SpriteSheets.load_dir(def.part_frames_dir), def.part_behind)
			_layer_ids.append(def.id)
		else:
			var part := Polygon2D.new()
			part.polygon = def.part_polygon
			part.color = def.part_color
			_host.socket(slot).add_child(part)
			_parts.append(part)
		_add_ability(def)


func _add_ability(def: MutationDef) -> void:
	if def == null or def.ability == null:
		return
	var node: MutationAbility = def.ability.new()
	node.host = _host
	node.def = def
	node.name = String(def.id)
	add_child(node)


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
	Sfx.play(&"eat")
	EventBus.inventory_changed.emit()
	EventBus.mutations_changed.emit()
