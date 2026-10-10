class_name LorePiece
extends Area2D
## Something to read (week 35): a mural a people painted about themselves,
## or a bone tablet telling what happened at one place. Settlements and ruins
## add these when they build. Press E to read it; what it shows is learned
## (WorldData.known_events) and appears in the History tab.

const DIALOGUE := preload("res://data/dialogue/reading.dialogue")
const UNSHADED := preload("res://assets/materials/unshaded.tres")

enum Kind { MURAL, TABLET }

var kind := Kind.MURAL
## Whose story a mural tells.
var faction: StringName
## The place a tablet tells about.
var site_id := ""
## Picks which moments a mural shows.
var rng_seed := 0
var tint := Color(0.8, 0.7, 0.5)

var _prompt: Label


## Call before adding to the tree.
func setup(piece_kind: Kind, faction_id: StringName, site: String, seed_value: int) -> void:
	kind = piece_kind
	faction = faction_id
	site_id = site
	rng_seed = seed_value
	var people: FactionData = WorldState.data.factions.get(faction_id) if WorldState.data else null
	if people:
		tint = people.color


func _ready() -> void:
	collision_layer = 2
	collision_mask = 4
	z_index = -1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 50) if kind == Kind.MURAL else Vector2(36, 30)
	shape.shape = rect
	shape.position = Vector2(0, -rect.size.y / 2.0)
	add_child(shape)
	_prompt = Label.new()
	_prompt.material = UNSHADED
	_prompt.text = "E: read the mural" if kind == Kind.MURAL else "E: read the bone"
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-80, -96 if kind == Kind.MURAL else -54)
	_prompt.size = Vector2(160, 20)
	_prompt.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override(&"outline_size", 3)
	_prompt.visible = false
	add_child(_prompt)
	body_entered.connect(func(body): if body is Player: _prompt.visible = true)
	body_exited.connect(func(body): if body is Player: _prompt.visible = false)


## The events this piece shows.
func event_ids() -> Array:
	var data := WorldState.data
	return Lore.mural_events(data, faction, rng_seed) if kind == Kind.MURAL else Lore.site_events(data, site_id)


func text() -> String:
	var data := WorldState.data
	return Lore.describe_mural(data, faction, event_ids()) if kind == Kind.MURAL else Lore.describe_tablet(data, event_ids())


func title() -> String:
	if kind == Kind.TABLET:
		return "Bone tablet"
	return "Mural of %s" % EventText._faction(WorldState.data, faction)


func interact() -> void:
	var fresh := WorldState.data.learn(event_ids())
	Conversation.open(self, DIALOGUE, Reading.new(title(), text()))
	if fresh > 0:
		EventBus.notify.emit("You learn %d new things about the past (History tab)" % fresh)


func _draw() -> void:
	if kind == Kind.TABLET:
		draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-10, -22), Vector2(-2, -28), Vector2(9, -24), Vector2(12, 0)]), Color(0.86, 0.82, 0.7))
		for i in 4:
			draw_line(Vector2(-7, -20 + i * 5), Vector2(6, -21 + i * 5), Color(0.45, 0.4, 0.33), 1.0)
		return
	# A slab with four painted panels.
	draw_rect(Rect2(-30, -58, 60, 58), Color(0.32, 0.26, 0.24))
	draw_rect(Rect2(-27, -55, 54, 52), Color(0.55, 0.47, 0.4))
	for i in 4:
		var panel := Rect2(-25 + (i % 2) * 26, -53 + (i / 2) * 25, 24, 23)
		draw_rect(panel, tint.darkened(0.2 + 0.15 * i))
		draw_circle(panel.get_center() + Vector2(-3 + i, -2), 3.0, tint.lightened(0.4))
		draw_line(panel.get_center() + Vector2(-8, 7), panel.get_center() + Vector2(8, 5 - i * 2), tint.lightened(0.2), 1.0)
