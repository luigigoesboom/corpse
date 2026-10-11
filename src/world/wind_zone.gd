@tool
class_name WindZone
extends Node2D
## Where the god's breath blows (week 52): an area of the Lungs and which
## way the air moves there on the inhale (`inhale`, px/s^2; the exhale is
## the reverse). Breath.wind_at() sums the zones a point is in, softened
## near their edges. Put them under World/WindZones in world.tscn (never
## streamed out). While the wind blows, streaks of air drift through the
## part of the zone on screen.
##
##   the Bellows: drawn up on the inhale (ride it up gliding), down on the exhale
##   the Trachea: down on the inhale, up and out on the exhale
##   the Great Bronchus: in (east) on the inhale, out on the exhale

## Half the area's size, px.
@export var extents := Vector2(320, 320)
## The inhale's wind here (px/s^2). The exhale blows the other way.
@export var inhale := Vector2(0, -1200)
## The outer part (fraction of the extents) where the wind fades out.
@export_range(0.0, 0.9) var soft_edge := 0.25

const STREAKS := 26
const AIR := Color8(214, 220, 232)

var _streaks: Array = []  # [position in the zone (local), length]
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"wind_zones")
	Breath.zones.append(self)
	z_index = 3
	material = preload("res://assets/materials/unshaded.tres")
	_rng.seed = hash(name)


func _exit_tree() -> void:
	Breath.zones.erase(self)


## This zone's inhale wind at a point, faded toward the edges (0 outside).
func wind_in(point: Vector2) -> Vector2:
	var local := (point - global_position).abs() / extents
	if local.x > 1.0 or local.y > 1.0:
		return Vector2.ZERO
	var edge := maxf(local.x, local.y)
	var fade := 1.0 if soft_edge <= 0.0 else clampf((1.0 - edge) / soft_edge, 0.0, 1.0)
	return inhale * fade


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	var camera := get_viewport().get_camera_2d()
	var s := Breath.strength()
	if camera == null or absf(s) < 0.05 or camera.get_screen_center_position().distance_to(global_position) > extents.length() + 700.0:
		if not _streaks.is_empty():
			_streaks.clear()
			queue_redraw()
		return
	var dir := inhale.normalized() * signf(s)
	var speed := 60.0 + absf(s) * inhale.length() * 0.25
	var view := Rect2(camera.get_screen_center_position() - Vector2(340, 200) - global_position, Vector2(680, 400))
	var area := Rect2(-extents, extents * 2.0).intersection(view)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		return
	while _streaks.size() < STREAKS:
		_streaks.append([_random_in(area), _rng.randf_range(6.0, 16.0)])
	for streak in _streaks:
		streak[0] += dir * speed * delta
		if not area.has_point(streak[0]):
			streak[0] = _random_in(area)  # Blown out: comes back in somewhere else.
	queue_redraw()


func _random_in(area: Rect2) -> Vector2:
	return area.position + Vector2(_rng.randf() * area.size.x, _rng.randf() * area.size.y)


func _draw() -> void:
	if Engine.is_editor_hint():
		var color := Color(0.75, 0.85, 1.0, 0.7)
		draw_rect(Rect2(-extents, extents * 2.0), color, false, 2.0)
		draw_line(Vector2.ZERO, inhale.normalized() * 120.0, color, 4.0)
		draw_string(ThemeDB.fallback_font, -extents + Vector2(8, 24), "Wind: inhale this way", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
		return
	var s := Breath.strength()
	var dir := inhale.normalized() * signf(s)
	var alpha := clampf(absf(s), 0.0, 1.0) * 0.45
	for streak in _streaks:
		var p: Vector2 = streak[0]
		draw_line(p.floor(), (p - dir * streak[1]).floor(), Color(AIR, alpha), 1.0)
