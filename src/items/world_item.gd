class_name WorldItem
extends Area2D
## An item lying in the world. Only a view: the truth is WorldData (for dropped
## items) or the world scene plus WorldData.removed_entities (for placed ones).
##
## To place one by hand: instance world_item.tscn under Entities in
## scenes/world.tscn and set `item_id`. The node's origin is the ground point.

@export var item_id: StringName = &"bile_bulb"

## For dropped items: the WorldData record id and its chunk. -1 = placed by hand.
var record_id := -1
var record_chunk := Vector2i.ZERO


func _ready() -> void:
	var def := ItemDb.get_def(item_id)
	$Visual.texture = icon_for(item_id)
	if def:
		$Light.color = def.color
	$Prompt.text = "E: %s" % ItemDb.display_name(item_id)
	$Prompt.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## The item's icon (week 39): assets/art/items/<id>.png, artifacts share
## one, anything else gets a plain lump.
static func icon_for(id: StringName) -> Texture2D:
	var path := "res://assets/art/items/%s.png" % id
	if ResourceLoader.exists(path):
		return load(path)
	if String(id).begins_with("artifact_"):
		return load("res://assets/art/items/artifact.png")
	return load("res://assets/art/items/unknown.png")


func is_placed() -> bool:
	return record_id < 0


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		$Prompt.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		$Prompt.visible = false
