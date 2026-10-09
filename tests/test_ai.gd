extends "res://tests/test_case.gd"
## Creature behaviour edge cases.


func run() -> void:
	await start_scene("res://game.tscn")
	# Hold the player in open air right above a chasing leech (in view, out of reach),
	# wobbling a little like a real player does.
	var leech = entity("LeechChamber")
	player.health.invulnerable = true
	leech.global_position = Vector2(2300, 3200)
	leech.velocity = Vector2.ZERO
	await wait_frames(2)
	leech.state = 3  # CHASE
	var flips := 0
	var last_dir: float = signf(leech.get_node("Visual").scale.x)
	var gave_up := false
	for i in 300:  # 5 seconds.
		player.global_position = Vector2(leech.global_position.x + sin(i * 0.7) * 6.0, 3080)
		player.velocity = Vector2.ZERO
		await physics_frame
		var dir: float = signf(leech.get_node("Visual").scale.x)
		if dir != last_dir:
			flips += 1
			last_dir = dir
		gave_up = gave_up or leech.state == 1  # WANDER
	check(flips <= 4, "a leech below the player does not flip back and forth (%d flips in 5 s)" % flips)
	check(gave_up, "it gives up on a player it cannot reach and wanders off")
