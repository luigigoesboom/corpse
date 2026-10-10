@tool
class_name GuardPost
extends Settlement
## A guard post (week 36): a few sentries of one people holding a way
## through (the Choir watching the shaft down to the deep). Put one under
## Entities in world.tscn with its origin over the gap it guards; the
## sentries stand on the floor to its right, looking back across the gap
## (and now and then the other way); `width` covers both sides.
##
## A bone grate covers the gap; the watch opens it for those it lets pass.
## Only friends of its people pass. Anyone else has four ways past:
## - sneak up to the latch on the near lip while the sentries look the other
##   way (they see in front, hear running, and the brazier by the latch
##   lights you up), lift it and drop through;
## - bribe a sentry with ichor (talk to it);
## - become their friend (offer ichor at their altar, and so on);
## - fight (a deed against them, as anywhere).
## Seen, a sentry steps in your way and warns you; walk on and the post
## attacks. Dead sentries may be replaced between lives (removed_entities).

const BRAZIER_RADIUS := 80.0
const WARN_SECONDS := 4.0
## Ichor a sentry takes to look away.
const BRIBE_COST := 20

## Who keeps the post.
@export var keeper: StringName = &"choir_of_waking"
@export var sentries := 2
@export var post_name := "the Choir's watch"
@export var warning := "Halt. Only the faithful go down."

## Half the width of the gap the grate covers, in px.
@export var gap_half_width := 64.0

var _alarm := false
var _warned := 0.0
var _announced := false
## The latch was lifted this visit (by a sneaking host).
var latched := false
var _grate: StaticBody2D


func build() -> void:
	for child in get_children():
		if child.has_meta(&"built"):
			remove_child(child)
			child.free()
	residents.clear()
	if WorldState.data == null:
		return
	var def := FactionDb.get_def(keeper)
	if def == null:
		return
	# Not a place in history: a stand-in SiteData so residents work as usual.
	site = SiteData.new()
	site.id = "post:" + EntityLayer.key_of(self)
	site.kind = &"post"
	site.faction = keeper
	site.name = post_name
	var data := WorldState.data
	for i in sentries:
		if data.removed_entities.has(_sentry_key(i)):
			continue
		var npc: ColonyNpc = RESIDENT.instantiate()
		npc.setup(self, Names.resident_name(data.world_seed, site.id, i), def.npc_frames_dir, data.world_seed + i)
		npc.home_x = gap_half_width + 30.0 + 46.0 * i
		npc.position = Vector2(npc.home_x, 0)
		npc.is_guard = true
		npc.stationed = true
		npc.set_meta(&"sentry", i)
		_add_built(npc)
		residents.append(npc)
	_grate = _make_grate()
	_add_built(_grate)
	var latch := Latch.new()
	latch.post = self
	latch.position = Vector2(-gap_half_width - 12.0, 0)  # The near lip, across from the sentries.
	_add_built(latch)
	var brazier := Brazier.new()
	brazier.position = Vector2(-gap_half_width - 50.0, 0)  # Lights the way to the latch.
	brazier.radius = BRAZIER_RADIUS
	_add_built(brazier)


## Kept out: not their friend, and no bribe.
func bars_player() -> bool:
	var data := WorldState.data
	return site != null and data != null and Standing.tier(data.standing(keeper)) != Standing.FRIENDLY and not _bribed()


func is_hostile() -> bool:
	return bars_player() and _alarm


func watches_player() -> bool:
	return bars_player()


func warning_line() -> String:
	return warning


func bribe_offer() -> Array:
	return [site.id, BRIBE_COST] if bars_player() else ["", 0]


func walk_bounds() -> Vector2:
	return Vector2(gap_half_width + 8.0, width / 2.0 - EDGE)


func resident_hurt(npc: ColonyNpc) -> void:
	if npc.health.last_hit_source == &"player":
		_alarm = true
	super.resident_hurt(npc)


func resident_died(npc: ColonyNpc) -> void:
	WorldState.data.removed_entities[_sentry_key(npc.get_meta(&"sentry", 0))] = &"sentry"
	super.resident_died(npc)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or site == null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	nearest_to_player = null
	for npc in residents:
		if nearest_to_player == null or npc.global_position.distance_to(player.global_position) < nearest_to_player.global_position.distance_to(player.global_position):
			nearest_to_player = npc
	_set_grate_open(latched or not bars_player())
	var local := to_local(player.global_position)
	var near := absf(local.x) < width / 2.0 + 80.0 and local.y > -160.0 and local.y < 60.0
	if near and not _announced:
		EventBus.notify.emit("%s, over the way down" % post_name.capitalize())
	_announced = near
	if not near or not bars_player():
		_alarm = false  # Left, got past, or let through.
		_warned = 0.0
		if not near and local.y < 0.0:
			latched = false  # Gone; the watch closes it behind you.
		return
	if _alarm:
		return
	if residents.any(func(n): return n.noticed):
		_warned += delta
		var at_the_gap := absf(local.x) < 60.0
		if _warned > WARN_SECONDS or (at_the_gap and _warned > 1.0):
			_alarm = true
			raise_alarm()
			EventBus.notify.emit("The watch draws on you")
	else:
		_warned = maxf(0.0, _warned - delta)


func is_grate_open() -> bool:
	return _grate != null and _grate.get_node("Shape").disabled


func _make_grate() -> StaticBody2D:
	var grate := StaticBody2D.new()
	grate.collision_layer = 1
	grate.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(gap_half_width * 2.0, 10.0)
	shape.shape = rect
	shape.position = Vector2(0, 5)
	grate.add_child(shape)
	var bars := Polygon2D.new()
	bars.name = "Bars"
	bars.polygon = PackedVector2Array([Vector2(-gap_half_width, -3), Vector2(gap_half_width, -3), Vector2(gap_half_width, 6), Vector2(-gap_half_width, 6)])
	bars.color = Color(0.82, 0.78, 0.66)
	grate.add_child(bars)
	return grate


func _set_grate_open(open: bool) -> void:
	if _grate == null or is_grate_open() == open:
		return
	_grate.get_node("Shape").set_deferred(&"disabled", open)
	_grate.get_node("Bars").visible = not open
	Sfx.play(&"land", global_position)


func _sentry_key(i: int) -> String:
	return "%s/sentry_%d" % [EntityLayer.key_of(self), i]


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := Color(0.9, 0.4, 0.3)
	draw_line(Vector2(-width / 2.0, 0), Vector2(0, 0), color, 2.0)
	draw_line(Vector2(0, -60), Vector2(0, 30), color, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-width / 2.0 + 4, -44), "Guard post (%s, %d)" % [keeper, sentries], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)


## The grate's latch, on the near lip of the gap: lift it (E) to open the way.
## Quiet, but the sentries see you do it if they are looking.
## Quiet, but the sentries see you do it if they are looking.
class Latch extends Area2D:
	var post: GuardPost

	func _ready() -> void:
		collision_layer = 2
		collision_mask = 4
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(28, 40)
		shape.shape = rect
		shape.position = Vector2(0, -20)
		add_child(shape)

	func interact() -> void:
		if post.is_grate_open():
			return
		post.latched = true
		EventBus.notify.emit("You lift the latch. The grate swings down.")

	func _draw() -> void:
		draw_rect(Rect2(-2, -22, 4, 22), Color(0.6, 0.55, 0.45))
		draw_circle(Vector2(0, -22), 3.0, Color(0.85, 0.8, 0.7))


## A fire in a bone bowl: whoever stands near it is easy to see.
class Brazier extends Node2D:
	var radius := 80.0

	func _ready() -> void:
		add_to_group(&"watch_lights")
		var light := PointLight2D.new()
		light.texture = preload("res://assets/lights/light_banded.tres")
		light.color = Color(1, 0.7, 0.35)
		light.energy = 1.1
		light.shadow_enabled = true
		light.position = Vector2(0, -26)
		add_child(light)

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		draw_colored_polygon(PackedVector2Array([Vector2(-10, -18), Vector2(10, -18), Vector2(6, -8), Vector2(-6, -8)]), Color(0.85, 0.8, 0.68))
		draw_rect(Rect2(-2, -8, 4, 8), Color(0.7, 0.65, 0.55))
		var flick := 2.0 * sin(Time.get_ticks_msec() / 90.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-7, -18), Vector2(0, -34 - flick), Vector2(7, -18)]), Color(1, 0.6, 0.2))
		draw_colored_polygon(PackedVector2Array([Vector2(-3, -18), Vector2(0, -27 + flick), Vector2(3, -18)]), Color(1, 0.9, 0.5))
