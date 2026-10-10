class_name TalkArea
extends Area2D
## Makes its parent talkable: the player's E finds this area (layer 2, like
## items) and calls interact(), which asks the parent to talk().


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false


func interact() -> void:
	get_parent().talk()
