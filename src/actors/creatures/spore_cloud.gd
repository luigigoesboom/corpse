class_name SporeCloud
extends Node2D
## The cloud a Puffsac leaves when it bursts (week 45): spores flying out to
## the edge of what the burst hurt, then fading. Only a view; drawn unshaded
## so it shows in the dark, in the palette's fungus glow.

const SPORE := Color8(140, 255, 204)
const SKIN := Color8(227, 154, 168)
const LIFE := 0.7

## How far the spores fly (the burst's reach), px.
var radius := 62.0
var _t := 0.0
var _spores: Array = []  # [direction, speed 0..1, size]


func _ready() -> void:
	material = preload("res://assets/materials/unshaded.tres")
	z_index = 5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(global_position)
	for i in 40:
		_spores.append([Vector2.from_angle(rng.randf() * TAU), rng.randf_range(0.55, 1.0), 1 + int(rng.randf() < 0.3)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / LIFE
	var reach := radius * (1.0 - pow(1.0 - minf(k * 1.6, 1.0), 3.0))  # Fast out, then hangs.
	var fade := 1.0 - k * k
	# A thin ring at the edge of the burst for the first moments.
	if k < 0.35:
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 40, Color(SPORE, 0.5 * (1.0 - k / 0.35)), 1.0)
	for spore in _spores:
		var at: Vector2 = (spore[0] * reach * spore[1] + Vector2(0, k * 10.0)).floor()  # They settle a little.
		var size: int = spore[2]
		draw_rect(Rect2(at, Vector2(size, size)), Color(SPORE if size == 1 else SKIN, fade))
