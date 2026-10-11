extends "res://tests/test_case.gd"
## The Lungs (week 47): you can walk in from the Gut through the Great
## Bronchus, land on membranes and bounce, drop through them, and climb the
## Bellows' membrane ladder with the host's own jump.

const T := 32.0


func run() -> void:
	await start_scene("res://game.tscn")
	player.health.invulnerable = true
	var chunks = game.get_node("ChunkManager")
	check(chunks.map.size == Vector2i(512, 128), "the world is twice as wide (%s)" % chunks.map.size)
	check(WorldMap.region_of(Vector2(330 * T, 60 * T)) == Regions.LUNGS and WorldMap.region_of(Vector2(100 * T, 90 * T)) == Regions.GUT,
		"the Lungs lie east of the Gut")

	# From the east cavern's ledge, east along the bronchus into the Bellows.
	await goto(_stand(240, 74), 30)
	check(player.is_on_floor(), "standing on the east cavern's ledge")
	Input.action_press("move_right")
	for i in 600:
		await physics_frame
		if player.is_on_wall() and player.is_on_floor():
			await press("jump", 12)  # A ring's hump.
		if player.global_position.x > 312 * T:
			break
	Input.action_release("move_right")
	await wait_frames(60)
	check(player.global_position.x > 305 * T, "walks the Great Bronchus out onto the Bellows' balcony (at tile %s)" % (player.global_position / T).floor())
	check(WorldMap.region_of(player.global_position) == Regions.LUNGS, "which is the Lungs")
	var backdrop = game.find_child("Backdrop", true, false)
	await wait_frames(120)
	check(backdrop == null or backdrop.lungs > 0.3, "the back wall turns to the Lungs' (%.2f)" % (backdrop.lungs if backdrop else 1.0))

	# A membrane: fall onto it and bounce; stand on it; drop through it.
	var shelf := _membrane_in_row(102, 300, 372)
	check(shelf.x >= 0, "the Bellows has a membrane at row 102")
	player.teleport(Vector2(shelf.x * T + 16, 92 * T))
	var bounced := false
	for i in 120:
		await physics_frame
		if player.velocity.y < -200.0:
			bounced = true
			break
	check(bounced, "falling onto a membrane bounces the host back up")
	await wait_frames(150)
	check(player.is_on_membrane() and int(player.global_position.y / T) == 101, "and it comes to rest on it (row %d)" % int(player.global_position.y / T))
	Input.action_press("move_down")
	await press("jump", 3)
	await wait_frames(40)
	Input.action_release("move_down")
	check(player.global_position.y > 103 * T, "down and jump drops through it")
	await wait_frames(30)

	# Climb the ladder: membranes every 3 rows, hop by hop.
	await goto(_stand(_membrane_in_row(102, 300, 372).x + 4, 104), 20)
	var climbed := 0
	for row in [102, 99, 96, 93, 90]:
		var span := _membrane_in_row(row, 300, 372)
		if span.x < 0 or not await _hop_to((span.x + span.y) * 0.5 * T + 16, row):
			break
		climbed += 1
	check(climbed == 5, "climbs the Bellows' membranes one by one (%d of 5)" % climbed)


## Where the host stands on top of tile row `row` + 1, at column x.
func _stand(x: int, row: int) -> Vector2:
	return Vector2(x * T + 16, (row + 1) * T - 22)


## The first and last column of the membrane in a row between x0 and x1,
## as Vector2i(first, last), or (-1, -1).
func _membrane_in_row(row: int, x0: int, x1: int) -> Vector2i:
	var map = game.get_node("ChunkManager").map
	var first := -1
	var last := -1
	for x in range(x0, x1):
		if map.is_membrane(Vector2i(x, row)):
			if first < 0:
				first = x
			last = x
		elif first >= 0:
			break
	return Vector2i(first, last)


## Jumps toward a membrane `row` near x, and reports whether the host ends
## up standing on it (as tests/test_map.gd does with ledges).
func _hop_to(x: float, row: int) -> bool:
	for attempt in 3:
		await _to_edge(signf(x - player.global_position.x))
		Input.action_press("jump")
		for i in 90:
			await physics_frame
			var dx: float = x - player.global_position.x
			var want: float = signf(dx) if absf(dx) > 6.0 else 0.0
			Input.action_release("move_left")
			Input.action_release("move_right")
			if want > 0.0:
				Input.action_press("move_right")
			elif want < 0.0:
				Input.action_press("move_left")
			if i == 22:
				Input.action_release("jump")
			if i > 25 and player.is_on_floor():
				break
		Input.action_release("jump")
		Input.action_release("move_left")
		Input.action_release("move_right")
		await wait_frames(40)  # Let any bounce settle.
		if player.is_on_floor() and int(player.global_position.y / T) == row - 1:
			return true
	return false


## Walks toward `dir` to the edge of what the host stands on (rock or
## membrane), the way a player does before jumping across.
func _to_edge(dir: float) -> void:
	if dir == 0.0:
		return
	var action := "move_right" if dir > 0.0 else "move_left"
	for i in 90:
		var ahead: Vector2 = player.global_position + Vector2(dir * 14.0, 40.0)
		var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(ahead + Vector2(0, -20), ahead + Vector2(0, 10), 1 | 64)
		if space.intersect_ray(query).is_empty():
			break
		Input.action_press(action)
		await physics_frame
	Input.action_release(action)
	await wait_frames(4)
