extends "res://tests/test_case.gd"
## The breath (week 52): the god breathes in a slow cycle, and the wind it
## makes changes how you move through the Lungs: the Bellows' inhale slows
## a fall and carries a glider up, the Trachea's exhale lifts you, walking
## into the Bronchus against the breath is slow, Puffsacs drift with it.

const T := 32.0


func run() -> void:
	await start_scene("res://game.tscn", 4242)
	player.health.invulnerable = true
	var breath: GDScript = load("res://src/world/breath.gd")

	# The cycle.
	breath.time = 4.0
	check(breath.phase() == &"inhale" and is_equal_approx(breath.strength(), 1.0), "mid-inhale the breath is strongest (%.2f)" % breath.strength())
	breath.time = 9.0
	check(breath.phase() == &"hold" and breath.strength() == 0.0, "then it holds")
	breath.time = 14.0
	check(breath.phase() == &"exhale" and is_equal_approx(breath.strength(), -1.0), "and blows out")
	breath.time = 19.0
	check(breath.phase() == &"rest" and breath.wind_at(Vector2(335 * T, 58 * T)) == Vector2.ZERO, "and rests: no wind")
	breath.time = 4.0
	check(breath.wind_at(Vector2(335 * T, 58 * T)).y < -1000.0, "the Bellows draw air up on the inhale")
	check(breath.wind_at(Vector2(100 * T, 90 * T)) == Vector2.ZERO, "and the Gut feels nothing")

	# A fall in the Bellows: slower while it breathes in.
	# (Open air east of the membrane ladder, below its wide membrane.)
	var still := await _fall_speed(Vector2(350 * T, 52 * T), 9.0)
	var inhale := await _fall_speed(Vector2(350 * T, 52 * T), 3.0)
	check(inhale < still * 0.7, "falling through the Bellows' inhale is slower (%.0f vs %.0f px/s)" % [inhale, still])

	# A glider rides the updraft up.
	var data = autoload("WorldState").data
	data.graft("back", &"lung_sac")
	autoload("EventBus").mutations_changed.emit()
	await wait_frames(3)
	await goto(Vector2(350 * T, 70 * T), 2)  # Open air, clear of the ladder.
	breath.time = 2.0
	Input.action_press("jump")
	var y0: float = player.global_position.y
	for i in 120:
		await physics_frame
		breath.time = 3.5  # Hold it at a strong inhale.
	Input.action_release("jump")
	check(player.global_position.y < y0 - 100.0, "gliding in the inhale carries the host up (%.0f px)" % (y0 - player.global_position.y))

	# The Trachea's exhale lifts you.
	await goto(Vector2(478.5 * T, 60 * T), 2)
	var y1: float = player.global_position.y
	for i in 40:
		breath.time = 14.0
		await physics_frame
	var lifted: float = y1 - player.global_position.y
	await goto(Vector2(478.5 * T, 60 * T), 2)
	for i in 40:
		breath.time = 9.0
		await physics_frame
	var dropped: float = y1 - player.global_position.y
	check(lifted > dropped + 100.0, "the Trachea's exhale holds you up (%.0f vs %.0f px)" % [lifted, dropped])

	# Walking into the Bronchus (east) against the exhale is slow.
	var against := await _walk(14.0)
	var with_it := await _walk(4.0)
	check(against < with_it * 0.85, "walking against the breath is slower (%.0f vs %.0f px)" % [against, with_it])

	# A Puffsac drifts with the breath.
	var sac: Node2D = load("res://src/actors/creatures/puffsac.tscn").instantiate()
	sac.position = Vector2(335 * T, 50 * T)
	sac.sight_range = 0.0  # Only the wind moves it.
	game.add_child(sac)
	await wait_frames(2)
	var start: Vector2 = sac.global_position
	for i in 60:
		breath.time = 4.0
		await physics_frame
	check(sac.global_position.y < start.y - 20.0, "a Puffsac is drawn up with the inhale (%.0f px)" % (start.y - sac.global_position.y))
	sac.queue_free()


## How fast the host falls (px/s) a third of a second after letting go at
## `from`, the breath held at `at`.
func _fall_speed(from: Vector2, at: float) -> float:
	var breath: GDScript = load("res://src/world/breath.gd")
	await goto(from, 2)
	for i in 20:
		breath.time = at
		await physics_frame
	return player.velocity.y


## How far the host walks east along the Bronchus in a second, the breath held at `at`.
func _walk(at: float) -> float:
	var breath: GDScript = load("res://src/world/breath.gd")
	await goto(Vector2(262 * T + 16, 75 * T - 22), 10)
	var x0: float = player.global_position.x
	Input.action_press("move_right")
	for i in 40:
		breath.time = at
		await physics_frame
	Input.action_release("move_right")
	return player.global_position.x - x0
