extends "res://tests/test_case.gd"
## The shaped world (after week 41): the new cave above the Tender camp can
## really be climbed, with the player's own jump, ledge by ledge.

const LEDGES := [[48.0, 85], [44.0, 82], [48.0, 79], [44.0, 76], [48.0, 73], [44.0, 70], [48.0, 67], [44.0, 64], [48.0, 61], [44.0, 58]]


func run() -> void:
	await start_scene("res://game.tscn")
	player.health.invulnerable = true
	# The camp's top step (row 88, x 44..49).
	await goto(Vector2(46.5 * 32, 87 * 32), 30)
	check(player.is_on_floor() and int(player.global_position.y / 32) == 87, "standing on the camp's top ledge")
	var climbed := 0
	for ledge in LEDGES:
		if not await _hop_to(ledge[0] * 32.0, ledge[1]):
			break
		climbed += 1
	check(climbed == LEDGES.size(), "climbs the shaft ledge by ledge (%d of %d)" % [climbed, LEDGES.size()])
	# The last ledge is the cave's floor: walk in to the clot.
	await _walk_to(37.0 * 32.0)
	check(player.is_on_floor() and int(player.global_position.y / 32.0) == 57 and player.global_position.x < 38.5 * 32.0,
		"and walks into the cave above the camp (at %s)" % [(player.global_position / 32.0).snapped(Vector2(0.1, 0.1))])


## Jumps toward a ledge whose top is `row` near x, and reports whether the
## player ends up standing on it.
func _hop_to(x: float, row: int) -> bool:
	for attempt in 3:
		await _to_edge(signf(x - player.global_position.x))
		Input.action_press("jump")
		for i in 90:
			await physics_frame
			var dx: float = x - player.global_position.x
			# Steer toward the ledge the whole jump, as a player would.
			var want: float = signf(dx) if absf(dx) > 6.0 else 0.0
			Input.action_release("move_left")
			Input.action_release("move_right")
			if want > 0.0:
				Input.action_press("move_right")
			elif want < 0.0:
				Input.action_press("move_left")
			if i == 20:
				Input.action_release("jump")
			if i > 25 and player.is_on_floor():
				break
		Input.action_release("jump")
		Input.action_release("move_left")
		Input.action_release("move_right")
		await wait_frames(4)
		if player.is_on_floor() and int(player.global_position.y / 32.0) == row - 1:
			return true
	return false


## Walks to the edge of what the player stands on, toward `dir`, the way a
## player does before jumping across (so it does not jump into the ledge
## above it).
func _to_edge(dir: float) -> void:
	if dir == 0.0:
		return
	var action := "move_right" if dir > 0.0 else "move_left"
	for i in 40:
		var ahead: Vector2 = player.global_position + Vector2(dir * 14.0, 40.0)
		var space: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters2D.create(ahead + Vector2(0, -20), ahead + Vector2(0, 10), 1))
		if hit.is_empty():
			break  # The edge is right in front.
		Input.action_press(action)
		await physics_frame
	Input.action_release(action)
	await wait_frames(2)


func _walk_to(x: float) -> void:
	var action := "move_right" if x > player.global_position.x else "move_left"
	Input.action_press(action)
	for i in 120:
		await physics_frame
		if absf(player.global_position.x - x) < 8.0:
			break
	Input.action_release(action)
	await wait_frames(10)
