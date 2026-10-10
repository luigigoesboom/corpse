extends "res://tests/test_case.gd"
## The dodge roll (week 25 playtest): Shift / LB.


func run() -> void:
	await start_scene("res://game.tscn")
	await goto(Vector2(1400, 3178), 20)
	player._facing = 1.0

	# A roll covers ground fast, ignores hits, then ends.
	var start_x: float = player.global_position.x
	await press("dodge", 1)
	check(player.is_dodging() and player.sprite.current_animation() == &"dodge", "Shift starts a roll (dodge animation)")
	var hit_landed: bool = player.health.take_damage(1, player.global_position + Vector2(10, 0))
	check(not hit_landed, "hits are ignored while rolling")
	while player.is_dodging():
		await physics_frame
	var rolled: float = player.global_position.x - start_x
	check(rolled > 80.0 and rolled < 130.0, "a roll covers about 100 px forward (got %.0f)" % rolled)
	await wait_frames(6)
	check(not player.health.is_invulnerable(), "invulnerability ends with the roll")
	check(player.health.current == player.health.max_health, "no damage was taken")

	# Cooldown: no second roll right away.
	await press("dodge", 1)
	check(not player.is_dodging(), "no new roll during the cooldown")
	await wait_frames(40)

	# The direction you push wins over the direction you face.
	start_x = player.global_position.x
	Input.action_press("move_left")
	await press("dodge", 1)
	Input.action_release("move_left")
	while player.is_dodging():
		await physics_frame
	check(player.global_position.x < start_x - 60.0 and player.facing() == -1.0, "pushing left rolls left")
	await wait_frames(40)

	# Not in the air.
	player.velocity.y = -300.0
	await wait_frames(4)
	await press("dodge", 1)
	check(not player.is_dodging(), "no roll in the air")
	await wait_frames(80)

	# Jumping out of a roll keeps its speed.
	await press("dodge", 1)
	await wait_frames(3)
	await press("jump", 1)
	check(player.velocity.y < -200.0 and absf(player.velocity.x) > player.run_speed and not player.is_dodging(),
		"jumping cancels the roll into a fast jump")
