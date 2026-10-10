@tool
class_name Settlement
extends Node2D
## A hand-made slot for a settlement (week 27). Put one under Entities in
## scenes/world.tscn on a FLAT floor (origin on the floor line: tile top +
## ChunkData.FLOOR_SINK) and set its width.
##
## What lives here is not placed by hand: it comes from WorldData.sites under
## this node's name (filled from faction territory when a world starts,
## changed by history later). At runtime the settlement builds itself from its
## owners' FactionDef: their props laid out along the floor, and residents
## who idle, stroll, work at the props, chat, and talk to you.

const RESIDENT := preload("res://src/actors/npcs/colony_npc.tscn")
## Room left at each end, in px.
const EDGE := 12.0

## Floor it covers, centred on the origin.
@export var width := 480.0:
	set(value):
		width = value
		queue_redraw()
## Most residents it can hold.
@export var capacity := 6
## Who settles here when a world starts. Empty = whoever holds the chunk.
@export var preferred_faction: StringName:
	set(value):
		preferred_faction = value
		queue_redraw()

var site: SiteData
var residents: Array[ColonyNpc] = []
## The resident closest to the player (only it shows its name), or null.
var nearest_to_player: ColonyNpc
## [{"x": float, "facing": float, "taken": bool}]
var _work_spots: Array = []
var _bark_timer := 4.0
var _player_inside := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	build()


## (Re)builds props and residents from the site record.
func build() -> void:
	for child in get_children():
		if child.has_meta(&"built"):
			remove_child(child)
			child.free()
	residents.clear()
	_work_spots.clear()
	if WorldState.data == null:
		return
	site = WorldState.data.sites.get(EntityLayer.key_of(self))
	if site == null or not site.is_lived_in():
		return
	var def := FactionDb.get_def(site.faction)
	if def == null:
		return
	var rng := SeededRng.make([WorldState.data.world_seed, "settlement", site.id])
	_lay_out_props(def, rng)
	var bounds := walk_bounds()
	for i in site.population:
		var npc: ColonyNpc = RESIDENT.instantiate()
		npc.setup(self, Names.resident_name(WorldState.data.world_seed, site.id, i), def.npc_frames_dir, rng.randi())
		npc.position = Vector2(rng.randf_range(bounds.x, bounds.y), 0)
		_add_built(npc)
		residents.append(npc)


## The kit's props in a shuffled (but repeatable) order, repeated until the
## floor is full, spread evenly.
func _lay_out_props(def: FactionDef, rng: RandomNumberGenerator) -> void:
	if def.settlement_props.is_empty():
		return
	var kit: Array[PackedScene] = def.settlement_props.duplicate()
	for i in range(kit.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := kit[i]
		kit[i] = kit[j]
		kit[j] = swap
	var chosen: Array[SettlementProp] = []
	var used := 0.0
	var i := 0
	while i < kit.size() * 3:
		var prop: SettlementProp = kit[i % kit.size()].instantiate()
		if used + prop.width > width - 2.0 * EDGE:
			prop.free()
			break
		used += prop.width
		chosen.append(prop)
		i += 1
	var gap := (width - 2.0 * EDGE - used) / (chosen.size() + 1)
	var x := -width / 2.0 + EDGE + gap
	for prop in chosen:
		prop.position = Vector2(roundf(x + prop.width / 2.0), 0)
		_add_built(prop)
		if prop.work_spot:
			var spot_x := prop.position.x + prop.work_offset
			_work_spots.append({"x": spot_x, "facing": signf(prop.position.x - spot_x) if prop.work_offset != 0.0 else 1.0, "taken": false})
		x += prop.width + gap


func _add_built(node: Node) -> void:
	node.set_meta(&"built", true)
	add_child(node)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or site == null or residents.is_empty():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	nearest_to_player = null
	for npc in residents:
		if nearest_to_player == null or npc.global_position.distance_to(player.global_position) < nearest_to_player.global_position.distance_to(player.global_position):
			nearest_to_player = npc
	var local := to_local(player.global_position)
	var inside := absf(local.x) < width / 2.0 + 40.0 and absf(local.y) < 140.0
	if inside and not _player_inside:
		var def := FactionDb.get_def(site.faction)
		EventBus.notify.emit("%s, a %s settlement" % [site.name, def.display_name if def else "?"])
	_player_inside = inside
	if not inside:
		return
	_bark_timer -= delta
	if _bark_timer <= 0.0:
		_bark_timer = randf_range(6.0, 12.0)  # Cosmetic timing: global randf is fine.
		bark_near(player.global_position)


## The resident closest to `where` says one of its faction's lines.
func bark_near(where: Vector2) -> ColonyNpc:
	var def := FactionDb.get_def(site.faction) if site else null
	if def == null or def.barks.is_empty() or residents.is_empty():
		return null
	var closest: ColonyNpc = residents[0]
	for npc in residents:
		if npc.global_position.distance_to(where) < closest.global_position.distance_to(where):
			closest = npc
	closest.say(def.barks[randi() % def.barks.size()])
	return closest


## Local x range residents may walk in.
func walk_bounds() -> Vector2:
	return Vector2(-width / 2.0 + EDGE, width / 2.0 - EDGE)


func claim_work_spot(_npc: ColonyNpc) -> int:
	var free: Array[int] = []
	for i in _work_spots.size():
		if not _work_spots[i].taken:
			free.append(i)
	if free.is_empty():
		return -1
	var index: int = free[_npc._rng.randi() % free.size()]
	_work_spots[index].taken = true
	return index


func release_work_spot(index: int) -> void:
	if index >= 0 and index < _work_spots.size():
		_work_spots[index].taken = false


func work_x(index: int) -> float:
	return _work_spots[index].x


func work_facing(index: int) -> float:
	return _work_spots[index].facing


func work_spot_count() -> int:
	return _work_spots.size()


## Another resident close by who is standing around, for a chat.
func idle_neighbour(npc: ColonyNpc, within: float) -> ColonyNpc:
	for other in residents:
		if other != npc and other.state == ColonyNpc.State.IDLE and absf(other.position.x - npc.position.x) < within:
			return other
	return null


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var half := width / 2.0
	var color := Color(0.9, 0.75, 0.3)
	draw_line(Vector2(-half, 0), Vector2(half, 0), color, 2.0)
	draw_line(Vector2(-half, 0), Vector2(-half, -40), color, 2.0)
	draw_line(Vector2(half, 0), Vector2(half, -40), color, 2.0)
	var label := "Settlement (%s, up to %d)" % [String(preferred_faction) if preferred_faction != &"" else "territory owner", capacity]
	draw_string(ThemeDB.fallback_font, Vector2(-half + 4, -44), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
