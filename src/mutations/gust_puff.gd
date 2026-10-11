class_name GustPuff
extends Node2D
## A puff of breath (week 51): streaks of air flying off in `direction` and
## fading, for the Gust Bladder and the Bellows Heart. Only a view.

const LIFE := 0.35
const AIR := Color8(214, 220, 232)

var direction := Vector2.RIGHT
var _t := 0.0
var _streaks: Array = []  # [offset, length, speed]


func _ready() -> void:
	material = preload("res://assets/materials/unshaded.tres")
	z_index = 4
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	for i in 9:
		var side := direction.orthogonal() * rng.randf_range(-16.0, 16.0)
		_streaks.append([side, rng.randf_range(6.0, 14.0), rng.randf_range(120.0, 260.0)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade := 1.0 - _t / LIFE
	for s in _streaks:
		var start: Vector2 = s[0] * (1.0 + _t * 2.0) + direction * s[2] * _t
		draw_line(start.floor(), (start + direction * s[1]).floor(), Color(AIR, 0.7 * fade), 1.0)
