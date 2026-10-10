class_name GroundShadow
extends Node2D
## A soft dark oval on the floor under its parent: grounds sprites in the
## 2.5D view (D-023), and shows how high something is when it jumps or flies.
## Add as the parent's FIRST child, so it is drawn under the parent's sprite.
## Looks straight down each physics frame (world layer only).

## Width of the oval when the parent stands on the floor, in px.
@export var width := 24.0
## Where the parent's feet are, relative to its origin.
@export var feet := Vector2.ZERO
## Higher than this above the floor, there is no shadow.
@export var max_height := 160.0
@export_range(0.0, 1.0) var opacity := 0.4

var _strength := 0.0


func _ready() -> void:
	top_level = true  # Placed on the floor, not where the parent is.


func _physics_process(_delta: float) -> void:
	var parent := get_parent() as Node2D
	if parent == null or not parent.is_visible_in_tree() or parent.get(&"body_hidden") == true:
		_set_strength(0.0)
		return
	var from := parent.global_position + feet - Vector2(0, 4)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, max_height + 4), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_set_strength(0.0)
		return
	global_position = hit.position
	_set_strength(1.0 - clampf((hit.position.y - from.y - 4.0) / max_height, 0.0, 1.0))


func _set_strength(value: float) -> void:
	if not is_equal_approx(value, _strength):
		_strength = value
		queue_redraw()


func _draw() -> void:
	if _strength <= 0.01:
		return
	var size := lerpf(0.5, 1.0, _strength)
	var radius := Vector2(width * 0.5 * size, maxf(2.0, width * 0.12 * size))
	var points := PackedVector2Array()
	for i in 16:
		var angle := TAU * i / 16.0
		points.append(Vector2(cos(angle) * radius.x, sin(angle) * radius.y - 1.0))
	draw_colored_polygon(points, Color(0, 0, 0, opacity * _strength))
