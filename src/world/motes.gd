class_name Motes
extends Node2D
## Motes and spores floating in the air around the camera (atmosphere pass):
## single pixels and specks drifting slowly, flickering, carried by the
## breath where it blows; a few glow. Only a view. Atmosphere sets `colors`
## (per region) and `amount` (the Atmosphere setting).

const COUNT := 80
## How far around the camera they live (px); out of it, one comes back on
## the other side.
const SPREAD := Vector2(360, 220)

var colors: Array = [Color8(227, 154, 168)]
var amount := 1.0
var _motes: Array = []  # [position, velocity, phase, size, color index]
var _rng := RandomNumberGenerator.new()
var _time := 0.0


func _ready() -> void:
	z_index = 2
	material = preload("res://assets/materials/unshaded.tres")
	_rng.seed = 7


func _process(delta: float) -> void:
	_time += delta
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var centre := camera.get_screen_center_position()
	while _motes.size() < COUNT:
		_motes.append(_new_mote(centre + Vector2(_rng.randf_range(-SPREAD.x, SPREAD.x), _rng.randf_range(-SPREAD.y, SPREAD.y))))
	for m in _motes:
		var wind := Breath.wind_at(m[0]) * 0.02
		m[1] = (m[1] + wind * delta * 30.0).limit_length(60.0)
		m[0] += (m[1] + Vector2(sin(_time * 0.7 + m[2]) * 4.0, cos(_time * 0.5 + m[2]) * 3.0)) * delta
		var off: Vector2 = m[0] - centre
		if absf(off.x) > SPREAD.x:
			m[0].x -= signf(off.x) * SPREAD.x * 2.0
		if absf(off.y) > SPREAD.y:
			m[0].y -= signf(off.y) * SPREAD.y * 2.0
	queue_redraw()


func _new_mote(at: Vector2) -> Array:
	var drift := Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-8.0, 3.0))
	return [at, drift, _rng.randf() * TAU, 1 + int(_rng.randf() < 0.18), _rng.randi() % 8]


func _draw() -> void:
	if amount <= 0.01 or colors.is_empty():
		return
	for m in _motes:
		var flicker := 0.5 + 0.5 * sin(_time * 2.0 + m[2] * 3.0)
		var c: Color = colors[m[4] % colors.size()]
		c.a = (0.25 + 0.5 * flicker) * amount
		var size: int = m[3]
		draw_rect(Rect2((m[0] as Vector2).floor(), Vector2(size, size)), c)
