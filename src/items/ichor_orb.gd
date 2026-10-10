class_name IchorOrb
extends Node2D
## A drop of ichor flying to the player (week 34). Only a view: the ichor is
## already in WorldData when this spawns. Bursts out, then homes in.

var target: Node2D
var _velocity := Vector2.ZERO
var _age := 0.0


func _init() -> void:
	z_index = 5
	material = preload("res://assets/materials/additive_glow.tres")


func launch(from: Vector2, to: Node2D, rng_angle: float) -> void:
	global_position = from
	target = to
	_velocity = Vector2.from_angle(rng_angle) * 160.0 + Vector2(0, -80)


func _process(delta: float) -> void:
	_age += delta
	if not is_instance_valid(target) or _age > 2.0:
		queue_free()
		return
	var goal := target.global_position + Vector2(0, -24)
	var pull := clampf((_age - 0.2) * 3.0, 0.0, 1.0)
	_velocity = _velocity.lerp((goal - global_position).normalized() * 420.0, pull * 8.0 * delta)
	global_position += _velocity * delta
	if pull > 0.0 and global_position.distance_to(goal) < 10.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(1, 0.3, 0.32))
	draw_circle(Vector2.ZERO, 1.5, Color(1, 0.8, 0.75))
