class_name FallingDebris
extends Node2D
## A lump of the god's flesh shaken loose from a ceiling by a spasm (D-033,
## BodyMoods). It trembles for a moment (dust trickles: the warning), then
## falls and hurts whatever it lands on (the host, creatures with friendly
## fire), and bursts on the floor.

const WARNING := 0.7
const GRAVITY := 1400.0
const COLORS := [Color8(92, 36, 46), Color8(140, 58, 66), Color8(186, 92, 96)]

var _t := 0.0
var _speed := 0.0
var _hit: Hitbox
var _shape := PackedVector2Array()
var _dust: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in 9:
		var a := TAU * i / 9.0
		_shape.append(Vector2(cos(a), sin(a)) * rng.randf_range(7.0, 12.0))
	_hit = Hitbox.new()
	_hit.damage = 1
	_hit.knockback = 180.0
	_hit.once_per_activation = true
	_hit.source = &"spasm"
	_hit.collision_layer = CombatRules.enemy_attack_layer()
	_hit.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	shape.shape = circle
	_hit.add_child(shape)
	add_child(_hit)
	_hit.deactivate()


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < WARNING:
		if randf() < 0.5:
			_dust.append(Vector2(randf_range(-10, 10), 0))
		for i in _dust.size():
			_dust[i].y += 60.0 * delta
		queue_redraw()
		return
	if not _hit.active:
		_hit.activate()
		_dust.clear()
	_speed += GRAVITY * delta
	position.y += _speed * delta
	rotation += delta * 4.0
	queue_redraw()
	var tile := Vector2i((global_position + Vector2(0, 10)) / 32.0)
	if _speed > 200.0 and _solid(tile) or _t > 4.0:
		Sfx.play(&"squelch", global_position)
		queue_free()


func _solid(tile: Vector2i) -> bool:
	var chunks := get_parent().get_node_or_null("ChunkManager")
	if chunks and chunks.map:
		return chunks.map.is_solid(tile)
	return false


func _draw() -> void:
	var colors := PackedColorArray()
	colors.resize(_shape.size())
	colors.fill(COLORS[1])
	var scaled := PackedVector2Array()
	for p in _shape:
		scaled.append(p * (0.6 if _t < WARNING else 1.0))
	draw_colored_polygon(scaled, COLORS[1])
	draw_polyline(scaled + PackedVector2Array([scaled[0]]), COLORS[0], 1.0)
	draw_circle(Vector2(-3, -3) * (0.6 if _t < WARNING else 1.0), 2.5, COLORS[2])
	for d in _dust:
		draw_rect(Rect2(d, Vector2(2, 2)), Color(0.6, 0.45, 0.45, 0.8))
