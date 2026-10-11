@tool
class_name Landmark
extends Node2D
## A named place (week 48): walking into its area shows its name on the
## screen, the first time as a discovery ("Discovered" with a sound),
## afterwards quietly. What has been discovered is kept in the world
## (WorldData.places_seen, by the node's name), and the minimap marks it.
##
## Put landmarks under World/Landmarks in scenes/world.tscn (not under
## Entities: they are never streamed out, as big places span chunks). The
## node's position is the area's centre; `extents` is half its size in px.
## In the editor the area is drawn as a box.

## Shown big: "The Bellows".
@export var title := ""
## Shown under it, smaller: a line about the place.
@export_multiline var line := ""
## Half the area's size, px.
@export var extents := Vector2(320, 160)
## Its dot on the minimap.
@export var minimap_color := Color8(214, 220, 232)

var _inside := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"minimap_marks")
	add_to_group(&"landmarks")
	set_meta(&"minimap_color", minimap_color)


func contains(point: Vector2) -> bool:
	var local := to_local(point)
	return absf(local.x) <= extents.x and absf(local.y) <= extents.y


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var inside := player != null and contains(player.global_position)
	if inside and not _inside and WorldState.data:
		var first := WorldState.data.see_place(String(name))
		EventBus.place_entered.emit(title, line, first)
	_inside = inside


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(0.6, 0.75, 0.9, 0.8)
	draw_rect(Rect2(-extents, extents * 2.0), color, false, 3.0)
	draw_string(ThemeDB.fallback_font, -extents + Vector2(8, 24), "Landmark: " + title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, color)
