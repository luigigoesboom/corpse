@tool
class_name RuinSite
extends Node2D
## A hand-made slot for a ruin (week 29). Put one under Entities in
## scenes/world.tscn on a flat floor (origin on the floor line) and set its
## width. When a world starts, SiteSeeder gives it one of the settlements
## history destroyed or abandoned (the one with the most story), and leaves
## that place's artifact lying in it. At runtime it builds broken props (a
## torn banner in its people's color) and, when you walk in, shows its name
## and how it ended, in the same words as the event log.

const KIT := [
	preload("res://src/props/ruin/rubble.tscn"),
	preload("res://src/props/ruin/broken_wall.tscn"),
	preload("res://src/props/ruin/toppled_pillar.tscn"),
	preload("res://src/props/ruin/bone_heap.tscn"),
	preload("res://src/props/ruin/cold_hearth.tscn"),
	preload("res://src/props/ruin/torn_banner.tscn"),
]
const EDGE := 16.0
const TITLE_FADE := 2.0

@export var width := 360.0:
	set(value):
		width = value
		queue_redraw()

var site: SiteData
var _title: Label
var _story: Label
var _shown := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	build()


func build() -> void:
	for child in get_children():
		if child.has_meta(&"built"):
			remove_child(child)
			child.free()
	_title = null
	_story = null
	if WorldState.data == null:
		return
	site = WorldState.data.site_in_slot(EntityLayer.key_of(self))
	if site == null or site.kind != &"ruin":
		return
	var rng := SeededRng.make([WorldState.data.world_seed, "ruin", site.id])
	var people: FactionData = WorldState.data.factions.get(site.faction)
	for prop in PropLayout.lay_out(self, KIT, width, EDGE, rng):
		var cloth := prop.get_node_or_null("Cloth") as Polygon2D
		if cloth:
			cloth.color = (people.color if people else Color(0.6, 0.55, 0.5)).darkened(0.25)
	# What is left to read (week 35): the fallen people's mural, and a bone
	# telling what happened here.
	var mural := LorePiece.new()
	mural.setup(LorePiece.Kind.MURAL, site.faction, site.id, site.id.hash() + 1)
	mural.position = Vector2(-width / 2.0 + EDGE + 34.0, 0)
	_add_built(mural)
	var tablet := LorePiece.new()
	tablet.setup(LorePiece.Kind.TABLET, site.faction, site.id, 0)
	tablet.position = Vector2(width / 2.0 - EDGE - 20.0, 0)
	_add_built(tablet)
	_title = _label(title_text(), 32, -156.0, false)
	_story = _label(story_text(), 16, -124.0, true)


## "The ruins of Cystmouth"
func title_text() -> String:
	return "The ruins of %s" % site.name if site else ""


## How it ended, as the event log tells it.
func story_text() -> String:
	if site == null:
		return ""
	var ending := ArtifactText.ending_event(WorldState.data, site.id)
	if ending == null:
		var events := ArtifactForge.events_at(WorldState.data, site.id)
		ending = events[-1] if not events.is_empty() else null
	return EventText.line(ending, WorldState.data) if ending else "Nobody remembers what happened here."


func _label(text: String, size: int, y: float, wrap: bool) -> Label:
	var label := Label.new()
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Before the width, or it will not wrap.
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.74))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	var w := maxf(width, 400.0)
	label.custom_minimum_size = Vector2(w, 0)
	label.size = Vector2(w, 0)
	label.position = Vector2(-w / 2.0, y)
	label.modulate.a = 0.0
	label.set_meta(&"built", true)
	add_child(label)
	return label


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _title == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var inside := false
	if player:
		var local := to_local(player.global_position)
		inside = absf(local.x) < width / 2.0 + 30.0 and absf(local.y) < 140.0
	# Fades in while you are inside, stays a few seconds, then fades out.
	_shown = minf(_shown + delta, TITLE_FADE + 4.0) if inside else maxf(_shown - delta * 2.0, 0.0)
	var alpha := clampf(_shown / TITLE_FADE, 0.0, 1.0) if inside or _shown > 0.0 else 0.0
	_title.modulate.a = alpha
	_story.modulate.a = alpha


func is_title_visible() -> bool:
	return _title != null and _title.modulate.a > 0.5


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var half := width / 2.0
	var color := Color(0.7, 0.6, 0.55)
	draw_line(Vector2(-half, 0), Vector2(half, 0), color, 2.0)
	draw_line(Vector2(-half, 0), Vector2(-half, -30), color, 2.0)
	draw_line(Vector2(half, 0), Vector2(half, -30), color, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-half + 4, -34), "Ruin slot", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


func _add_built(node: Node) -> void:
	node.set_meta(&"built", true)
	add_child(node)
