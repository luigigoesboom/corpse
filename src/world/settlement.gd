@tool
class_name Settlement
extends Node2D
## A hand-made slot for a settlement (week 27). Put one under Entities in
## scenes/world.tscn on a FLAT floor (origin on the floor line: tile top +
## ChunkData.FLOOR_SINK) and set its width.
##
## What lives here is not placed by hand: it is the site in WorldData.sites
## whose `slot` is this node's name (SiteSeeder fills slots from history when
## a world starts). Residents shown scale with the site's population. At runtime the settlement builds itself from its
## owners' FactionDef: their props laid out along the floor, and residents
## who idle, stroll, work at the props, chat, and talk to you.
##
## Host standing (week 31): hurting a resident is a deed against its people;
## when they turn hostile, guards attack and the rest flee.

const RESIDENT := preload("res://src/actors/npcs/colony_npc.tscn")
## Standing lost for hitting a resident, and for killing one.
const HURT_DEED := -60
const KILL_DEED := -100
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
	site = WorldState.data.site_in_slot(EntityLayer.key_of(self))
	if site == null or not site.is_lived_in():
		return
	var def := FactionDb.get_def(site.faction)
	if def == null:
		return
	var rng := SeededRng.make([WorldState.data.world_seed, "settlement", site.id])
	_lay_out_props(def, rng)
	var bounds := walk_bounds()
	for i in site.residents_shown(capacity):
		var npc: ColonyNpc = RESIDENT.instantiate()
		npc.setup(self, Names.resident_name(WorldState.data.world_seed, site.id, i), def.npc_frames_dir, rng.randi())
		npc.position = Vector2(rng.randf_range(bounds.x, bounds.y), 0)
		npc.is_guard = i < ceili(site.residents_shown(capacity) / 3.0)
		_add_built(npc)
		residents.append(npc)


## The kit's props along the floor (PropLayout); work spots from the ones
## marked as such.
func _lay_out_props(def: FactionDef, rng: RandomNumberGenerator) -> void:
	for prop in PropLayout.lay_out(self, def.settlement_props, width, EDGE, rng):
		if prop.work_spot:
			var spot_x := prop.position.x + prop.work_offset
			_work_spots.append({"x": spot_x, "facing": signf(prop.position.x - spot_x) if prop.work_offset != 0.0 else 1.0, "taken": false})


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


## Its people are hostile to the current host: guards fight, others flee.
func is_hostile() -> bool:
	return site != null and WorldState.data != null and Standing.tier(WorldState.data.standing(site.faction)) == Standing.HOSTILE


## A resident was hit. By the player, that is a deed against its people.
func resident_hurt(npc: ColonyNpc) -> void:
	if npc.health.last_hit_source == &"player" and not npc.health.is_dead():
		_remember_attack()
		_deed(HURT_DEED)


## The first time this body attacks this settlement, it is a deed the
## fragment is remembered for (week 32).
func _remember_attack() -> void:
	var data := WorldState.data
	var life := data.current_life()
	if life == null:
		return
	for id in life.deed_event_ids:
		for event in data.events:
			if event.id == id and event.type == &"resident_attacked" and event.data.get("site") == site.id:
				return
	data.log_deed(&"resident_attacked", [site.faction, life.host_name], {"site": site.id})


## A resident died: one fewer, and if the player did it, the world knows.
func resident_died(npc: ColonyNpc) -> void:
	residents.erase(npc)
	if site == null:
		return
	site.population = maxi(0, site.population - SiteData.PEOPLE_PER_RESIDENT)
	if npc.health.last_hit_source == &"player":
		var life := WorldState.data.current_life()
		WorldState.data.log_deed(&"resident_killed", [site.faction, life.host_name if life else "someone"],
			{"site": site.id, "victim": npc.npc_name})
		_deed(KILL_DEED)


func _deed(amount: int) -> void:
	var changes := WorldState.data.record_deed(site.faction, amount)
	for faction in changes:
		var message := Standing.change_message(EventText._faction(WorldState.data, faction), changes[faction])
		if message != "":
			EventBus.notify.emit(message)


## The resident closest to `where` says one of its faction's lines (hostile
## lines when its people are hostile).
func bark_near(where: Vector2) -> ColonyNpc:
	var def := FactionDb.get_def(site.faction) if site else null
	if def == null or def.barks.is_empty() or residents.is_empty():
		return null
	var closest: ColonyNpc = residents[0]
	for npc in residents:
		if npc.global_position.distance_to(where) < closest.global_position.distance_to(where):
			closest = npc
	var lines: Array = def.greetings.get("hostile", def.barks) if is_hostile() else def.barks
	closest.say(lines[randi() % lines.size()])
	return closest


## Where bodies this faction claims are laid (week 33, CorpseFate): on the
## floor at the left end, in world coordinates.
func body_spot() -> Vector2:
	return position + Vector2(-width / 2.0 + EDGE + 24.0, 0)


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
