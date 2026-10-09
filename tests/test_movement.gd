extends "res://tests/test_case.gd"
## Movement feel (week 2) in the hand-made test room.


func run() -> void:
	await start_scene("res://scenes/test_room.tscn")

	# Full jump in a clear column (x = 272).
	await goto(Vector2(272, 500), 40)
	var ground_y: float = player.global_position.y
	var top := ground_y
	Input.action_press("jump")
	for i in 60:
		await physics_frame
		top = minf(top, player.global_position.y)
	Input.action_release("jump")
	check(ground_y - top > 110.0 and ground_y - top < 135.0, "full jump is about 120 px (got %.0f)" % (ground_y - top))

	# Short hop: tap jump.
	await wait_frames(40)
	top = player.global_position.y
	await press("jump", 3)
	for i in 50:
		await physics_frame
		top = minf(top, player.global_position.y)
	check(ground_y - top < 70.0, "tapping jump gives a short hop (got %.0f)" % (ground_y - top))

	# Coyote time: run off the ledge at tiles 4-7, row 14, then jump 3 frames later.
	await goto(Vector2(7 * 32 + 20, 448 - 22), 20)
	Input.action_press("move_right")
	while player.is_on_floor():
		await physics_frame
	await wait_frames(3)
	Input.action_press("jump")
	await wait_frames(2)
	check(player.velocity.y < -300.0, "coyote jump fires just after leaving a ledge")
	Input.action_release("jump")
	Input.action_release("move_right")

	# Jump buffer: press jump just before landing.
	await goto(Vector2(272, 300), 1)
	while player.global_position.y < 522 - 40:
		await physics_frame
	Input.action_press("jump")
	var buffered := false
	for i in 30:
		await physics_frame
		if player.velocity.y < -300.0:
			buffered = true
			break
	Input.action_release("jump")
	check(buffered, "a jump pressed just before landing still happens")

	# Wall cling and wall jump on the left wall.
	await goto(Vector2(60, 522), 10)
	Input.action_press("jump")
	Input.action_press("move_left")
	await wait_frames(4)
	Input.action_release("jump")
	await wait_frames(36)
	check(player.is_clinging() and is_equal_approx(player.velocity.y, player.wall_slide_speed), "clinging slides at wall_slide_speed")
	Input.action_press("jump")
	await wait_frames(2)
	check(player.velocity.x > 0.0 and player.velocity.y < 0.0, "wall jump kicks away and up")
	Input.action_release("jump")
	Input.action_release("move_left")
