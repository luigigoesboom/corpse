class_name Swarms
extends Node
## Where a kind of creature swarms (Ecology, D-033), more of it turns up
## around the host while you are in its region: every so often one crawls or
## flies in from off screen, at most MAX at a time. Spawned, not placed: they
## are not saved and leave no mark when killed. Game adds one.

const MAX := 4
const EVERY := Vector2(25.0, 50.0)

var player: Node2D
var _wait := 20.0
var _alive: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_wait = _rng.randf_range(EVERY.x, EVERY.y)


func _process(delta: float) -> void:
	if get_tree().paused or player == null or WorldState.data == null:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _rng.randf_range(EVERY.x, EVERY.y)
	_alive = _alive.filter(func(c): return is_instance_valid(c))
	if _alive.size() >= MAX:
		return
	var kinds := Ecology.swarming(WorldState.data, WorldMap.region_of(player.global_position))
	if kinds.is_empty():
		return
	spawn(kinds[_rng.randi() % kinds.size()])


## One of `kind` from off screen, on a floor near the host. Returns it (or null).
func spawn(kind: StringName) -> Node2D:
	var chunks := get_parent().get_node_or_null("ChunkManager")
	if chunks == null or chunks.map == null or not BeastLair.SCENES.has(kind):
		return null
	var map: WorldMap = chunks.map
	for attempt in 8:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var tile := Vector2i(((player.global_position + Vector2(side * _rng.randf_range(360, 480), -60)) / 32.0).floor())
		if map.is_solid(tile) or map.is_solid(tile + Vector2i.UP):
			continue
		var y := tile.y
		while y < tile.y + 12 and not map.is_solid(Vector2i(tile.x, y + 1)):
			y += 1
		if not map.is_solid(Vector2i(tile.x, y + 1)):
			continue
		var creature: Node2D = load(BeastLair.SCENES[kind]).instantiate()
		creature.position = Vector2(tile.x * 32 + 16, (y + 1) * 32 - 22)
		get_parent().add_child(creature)
		_alive.append(creature)
		return creature
	return null
