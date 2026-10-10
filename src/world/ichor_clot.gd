class_name IchorClot
extends Area2D
## A clot of dried ichor (week 34) lying in a ruin or a deep place. Walk
## into it to take it. Hand-placed under Entities in world.tscn; once taken
## it is gone for good (WorldData.removed_entities), like a placed item.

@export var amount := 10


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player or not is_inside_tree():
		return
	var data := WorldState.data
	data.add_ichor(amount)
	data.removed_entities[EntityLayer.key_of(self)] = &"item"
	EventBus.ichor_gained.emit(amount, global_position)
	EventBus.notify.emit("+%d ichor" % amount)
	Sfx.play(&"squelch")
	get_parent().remove_child.call_deferred(self)
