class_name KeyCache
extends Area2D
## Where a valve key lies while nobody carries it (week 38): the Choir's
## reliquary, or the Gullet Matron's nest. Put one under Entities in
## world.tscn, origin on the floor, and set `place` to a ValveKeys place id.
## The key shows only while WorldData.key_places says it lies here.
##
## Press E to take it. At a kept place (`keeper` set), anyone of the
## keepers who sees you take it calls it theft: a deed against them, and
## their settlement turns on you. Unseen, nobody knows until later.

const UNSHADED := preload("res://assets/materials/unshaded.tres")
const THEFT_DEED := -100

@export var place := ValveKeys.MATRON_NEST
@export var key := ValveKeys.GUT
## Whose reliquary this is (&"" = nobody's: a nest, a hole).
@export var keeper: StringName

var _prompt: Label
var _time := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40, 40)
	shape.shape = rect
	shape.position = Vector2(0, -20)
	add_child(shape)
	var light := PointLight2D.new()
	light.texture = preload("res://assets/lights/light_banded.tres")
	light.color = Color(1, 0.45, 0.35)
	light.energy = 0.9
	light.texture_scale = 0.6
	light.position = Vector2(0, -22)
	light.name = "Light"
	add_child(light)
	_prompt = Label.new()
	_prompt.material = UNSHADED
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-90, -66)
	_prompt.size = Vector2(180, 20)
	_prompt.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override(&"outline_size", 3)
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(func(body): if body is Player and has_key(): _prompt.visible = true)
	body_exited.connect(func(body): if body is Player: _prompt.visible = false)


func has_key() -> bool:
	return WorldState.data != null and ValveKeys.lies_at(WorldState.data, key, place)


func _process(delta: float) -> void:
	_time += delta
	$Light.visible = has_key()
	_prompt.text = "E: take the %s" % ItemDb.display_name(key)
	queue_redraw()


func interact() -> void:
	var data := WorldState.data
	if not has_key():
		return
	var watchers := _keepers_watching()
	if not ValveKeys.take(data, key, place):
		EventBus.notify.emit("Pockets are full")
		return
	_prompt.visible = false
	EventBus.inventory_changed.emit()
	Sfx.play(&"pickup", global_position)
	var life := data.current_life()
	if keeper == &"":
		data.log_deed(&"key_found", [life.host_name if life else "someone"], {"key": key})
		EventBus.notify.emit("You take the %s. It beats in your hand." % ItemDb.display_name(key))
	elif watchers.is_empty():
		data.log_deed(&"key_stolen", [keeper, life.host_name if life else "someone"], {"key": key, "seen": false})
		EventBus.notify.emit("You take the %s. Nobody saw." % ItemDb.display_name(key))
	else:
		data.log_deed(&"key_stolen", [keeper, life.host_name if life else "someone"], {"key": key, "seen": true})
		var changes := data.record_deed(keeper, THEFT_DEED)
		for faction in changes:
			var message := Standing.change_message(EventText._faction(data, faction), changes[faction])
			if message != "":
				EventBus.notify.emit(message)
		watchers[0].say("Thief! The heart-key!")
		for settlement in _settlements():
			settlement.raise_alarm()


## Keepers who can see the player right now: in front of them and close
## enough for how visible the player is (sneaking, dark, firelight).
func _keepers_watching() -> Array:
	var player := get_tree().get_first_node_in_group(&"player") as Player
	var out := []
	if player == null or keeper == &"":
		return out
	for settlement in _settlements():
		for npc in settlement.residents:
			var offset: Vector2 = player.global_position - npc.global_position
			var in_front: bool = signf(offset.x) == npc.facing() or absf(offset.x) < 4.0
			var reach := ColonyNpc.SIGHT_RANGE * minf(1.0, player.visibility())
			if offset.length() < ColonyNpc.TOUCH_RANGE or (in_front and absf(offset.x) < reach and absf(offset.y) < 70.0):
				out.append(npc)
	return out


## The keepers' settlements near this cache.
func _settlements() -> Array:
	var out := []
	for node in get_parent().get_children():
		if node is Settlement and node.site and node.site.faction == keeper and node.global_position.distance_to(global_position) < 600.0:
			out.append(node)
	return out


func _draw() -> void:
	if place == ValveKeys.MATRON_NEST:
		# A nest of shed skin and bone.
		draw_colored_polygon(PackedVector2Array([Vector2(-30, 0), Vector2(-24, -10), Vector2(-8, -14), Vector2(10, -13), Vector2(26, -9), Vector2(32, 0)]), Color(0.4, 0.26, 0.22))
		for i in 5:
			draw_line(Vector2(-22 + i * 11, -2), Vector2(-16 + i * 11, -11 - (i % 2) * 3), Color(0.8, 0.75, 0.62), 2.0)
	else:
		# A reliquary box on bone legs.
		draw_rect(Rect2(-14, -12, 28, 12), Color(0.55, 0.42, 0.28))
		draw_rect(Rect2(-16, -34, 32, 22), Color(0.78, 0.62, 0.3))
		draw_rect(Rect2(-12, -30, 24, 14), Color(0.3, 0.18, 0.14))
	if has_key():
		var bob := sin(_time * 3.0) * 1.5
		var center := Vector2(0, (-22 if place == ValveKeys.MATRON_NEST else -24) + bob)
		draw_arc(center, 6.0, 0.0, TAU, 16, Color(1, 0.55, 0.45), 3.0)
		draw_arc(center, 3.0, 0.0, TAU, 12, Color(0.6, 0.1, 0.12), 2.0)
