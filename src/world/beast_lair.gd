class_name BeastLair
extends Node2D
## A place a legendary beast can live (D-033), hand-placed under Entities
## on a floor. If WorldData.beasts has a living beast for this lair, it
## builds that beast: a creature of the beast's kind, grown by its traits
## (Beasts.TRAITS: size, health, speed, damage, sight, colour), its name over
## its head. Coming close announces it; its death is the game's to handle
## (Game: a famous deed and a trophy). Empty lairs show nothing.

const SCENES := {
	&"gut_leech": "res://src/actors/creatures/gut_leech.tscn",
	&"bile_spitter": "res://src/actors/creatures/bile_spitter.tscn",
	&"rot_fly": "res://src/actors/creatures/rot_fly.tscn",
	&"cilia_lasher": "res://src/actors/creatures/cilia_lasher.tscn",
	&"bellows_ray": "res://src/actors/creatures/bellows_ray.tscn",
	&"puffsac": "res://src/actors/creatures/puffsac.tscn",
}
const ANNOUNCE_RANGE := 300.0

## What the place is called in history ("the Weeping Hollow").
@export var lair_name := "a dark fold"
## Kinds of creature a beast here can grow from.
@export var kinds: Array[StringName] = [&"gut_leech"]

## The beast's creature while it lives here, or null.
var creature: Node2D
var _announced := false


func _ready() -> void:
	if Engine.is_editor_hint() or WorldState.data == null:
		return
	build()


func build() -> void:
	if is_instance_valid(creature):
		creature.queue_free()
	creature = null
	_announced = false
	var beast := Beasts.living_in(WorldState.data, EntityLayer.key_of(self))
	if beast == null or not SCENES.has(beast.kind):
		remove_from_group(&"minimap_marks")
		return
	creature = load(SCENES[beast.kind]).instantiate()
	grow(creature, beast)
	creature.set_meta(&"built", true)
	add_child(creature)
	add_to_group(&"minimap_marks")
	set_meta(&"minimap_color", Color(0.75, 0.2, 0.5))


## Makes a plain creature into the beast: before it enters the tree.
static func grow(c: Node2D, beast: BeastData) -> void:
	var health := c.get_node("Health") as Health
	health.max_health = ceili(health.max_health * Beasts.stat(beast, "hp", 3.0))
	var size := Beasts.stat(beast, "scale", 1.2)
	c.scale = Vector2(size, size)
	var speed := Beasts.stat(beast, "speed", 1.0)
	var sight := Beasts.stat(beast, "sight", 1.0)
	for prop in c.get_property_list():
		if prop.type != TYPE_FLOAT:
			continue
		var n: String = prop.name
		if n.ends_with("_speed") or n == "speed":
			c.set(n, c.get(n) * speed)
		elif n == "sight_range" or n == "lose_range":
			c.set(n, c.get(n) * sight)
	var extra := int(Beasts.stat(beast, "damage", 0.0))
	for box in c.find_children("*", "Hitbox", true, false):
		box.damage += extra
	c.modulate = Beasts.tint(beast)
	c.set_meta(&"beast_id", beast.id)
	c.add_to_group(&"beasts")
	var label := Label.new()
	label.text = beast.full_name()
	label.add_theme_color_override(&"font_color", Color(0.95, 0.75, 0.45))
	label.add_theme_color_override(&"font_outline_color", Color(0.08, 0.02, 0.03))
	label.add_theme_constant_override(&"outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(240, 16)
	label.position = Vector2(-120, -78)
	label.scale = Vector2.ONE / size
	label.name = "BeastName"
	c.add_child(label)


func _process(_delta: float) -> void:
	if _announced or not is_instance_valid(creature):
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player and player.global_position.distance_to(creature.global_position) < ANNOUNCE_RANGE:
		_announced = true
		var beast: BeastData = WorldState.data.beasts.get(creature.get_meta(&"beast_id"))
		if beast:
			var what := Beasts.describe(beast)
			EventBus.place_entered.emit(beast.full_name(), "%s %s" % [what.substr(0, 1).to_upper() + what.substr(1), _deeds(beast)], false)


static func _deeds(beast: BeastData) -> String:
	if beast.kills > 0:
		return "that has killed %d people" % beast.kills
	return "that nobody has yet lived to name"
