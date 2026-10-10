extends "res://tests/test_case.gd"
## Floors with a top face (D-022): the collision of every tile with air above
## starts ChunkData.FLOOR_SINK px below the tile's top edge, and everything
## that stands on a floor stands on that line, not on the face's back edge.

const PLAYER_HALF_HEIGHT := 26.0  # Capsule height 52, centered on the origin.


func run() -> void:
	var sink := ChunkData.FLOOR_SINK
	var tileset: TileSet = load("res://assets/art/tiles/gut_tileset.tres")
	var source: TileSetAtlasSource = tileset.get_source(0)
	var floors_ok := true
	var others_ok := true
	for mask in range(1, 16):
		var top := INF
		for point in source.get_tile_data(Vector2i(mask % 4, mask / 4), 0).get_collision_polygon_points(0, 0):
			top = minf(top, point.y)
		if mask & ChunkData.OPEN_UP:
			floors_ok = floors_ok and is_equal_approx(top, -16.0 + sink)
		else:
			others_ok = others_ok and is_equal_approx(top, -16.0)
	check(floors_ok, "every tile with air above has its floor %d px below its top edge" % sink)
	check(others_ok, "tiles without air above keep collision up to their top edge")

	var map := WorldMap.load_from()

	# Hand-placed things that do not fall (items, props, NPCs, the camp).
	var world: Node = load("res://scenes/world.tscn").instantiate()
	var off_floor := []
	var on_floor := 0
	for node in world.get_node("Entities").get_children():
		if node is CharacterBody2D:
			continue  # Falls onto the floor by itself, checked below.
		if node.has_method("bars_player"):
			continue  # A guard post sits over the gap it guards.
		var pos: Vector2 = node.position
		if map.is_solid(_tile(pos - Vector2(0, sink + 1))):
			continue  # Hangs from a ceiling.
		on_floor += 1
		if not is_equal_approx(pos.y, _floor_line(map, pos)):
			off_floor.append("%s at y %d (floor %d)" % [node.name, pos.y, _floor_line(map, pos)])
	world.free()
	check(on_floor > 10 and off_floor.is_empty(), "%d hand-placed things stand on the floor line %s" % [on_floor, off_floor])

	await start_scene("res://game.tscn")
	await wait_frames(30)
	var feet: float = player.global_position.y + PLAYER_HALF_HEIGHT
	var line := _floor_line(map, player.global_position)
	check(player.is_on_floor() and absf(feet - line) < 0.5, "the player's feet are on the floor line (%.1f, floor %.1f)" % [feet, line])

	# Creatures, moved somewhere and left to settle.
	for kind in ["LeechChamber", "SpitterChamber"]:
		var creature = game.get_node("World/Entities/" + kind)
		creature.global_position = player.global_position + Vector2(160, -40)
		creature.velocity = Vector2.ZERO
		await wait_frames(40)
		var shape: CollisionShape2D = creature.get_node("CollisionShape2D")
		var bottom: float = creature.global_position.y + shape.position.y + shape.shape.size.y / 2.0
		var floor_y := _floor_line(map, creature.global_position)
		check(creature.is_on_floor() and absf(bottom - floor_y) < 0.5, "%s stands on the floor line (%.1f, floor %.1f)" % [kind, bottom, floor_y])

	# A dead host's body lies on the floor line, even when it died in the air.
	var corpses = game.get_node("Corpses")
	await goto(player.global_position + Vector2(0, -60), 1)
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	var corpse = corpses.get_child(0) if corpses.get_child_count() > 0 else null
	check(corpse != null and is_equal_approx(corpse.position.y, _floor_line(map, corpse.position)), "the body lies on the floor line")


func _tile(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / ChunkData.TILE_PX), floori(pos.y / ChunkData.TILE_PX))


## Where feet rest below `pos`: the top edge of the first rock tile under it
## (starting just above `pos`), plus FLOOR_SINK.
func _floor_line(map: WorldMap, pos: Vector2) -> float:
	var tile := _tile(pos - Vector2(0, ChunkData.FLOOR_SINK + 1))
	while not map.is_solid(tile):
		tile.y += 1
	return tile.y * ChunkData.TILE_PX + ChunkData.FLOOR_SINK
