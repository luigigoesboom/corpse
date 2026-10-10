class_name Carcass
extends Area2D
## What is left of a dead creature for a while (week 36): eat it (E) for a
## heart back and a drop of ichor. Not saved: it rots away in a minute and
## a half, or when its chunk unloads.

const LIFETIME := 90.0
const UNSHADED := preload("res://assets/materials/unshaded.tres")

var kind: StringName
var _age := 0.0
var _prompt: Label


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	shape.shape = circle
	shape.position = Vector2(0, -8)
	add_child(shape)
	_prompt = Label.new()
	_prompt.material = UNSHADED
	_prompt.text = "E: eat the %s" % _name()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-80, -44)
	_prompt.size = Vector2(160, 20)
	_prompt.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override(&"outline_size", 3)
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(func(body): if body is Player: _prompt.visible = true)
	body_exited.connect(func(body): if body is Player: _prompt.visible = false)


func _process(delta: float) -> void:
	_age += delta
	modulate.a = clampf((LIFETIME - _age) / 10.0, 0.0, 1.0)
	if _age > LIFETIME:
		queue_free()


func interact() -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if player:
		player.health.set_current(player.health.current + 1)
	WorldState.data.add_ichor(1)
	EventBus.ichor_changed.emit()
	EventBus.notify.emit("You eat the %s. It tastes of copper." % _name())
	Sfx.play(&"eat", global_position)
	queue_free()


func _name() -> String:
	return String(kind).replace("_", " ") if kind != &"" else "carcass"


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-10, -6), Vector2(-2, -8), Vector2(8, -6), Vector2(14, 0)]), Color(0.45, 0.16, 0.16))
	draw_line(Vector2(-8, -4), Vector2(6, -5), Color(0.75, 0.3, 0.3), 2.0)
	draw_circle(Vector2(9, -3), 1.5, Color(0.9, 0.85, 0.75))
