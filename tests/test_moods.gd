extends "res://tests/test_case.gd"
## The body's moods (D-033): spasms shake and drop debris that hurts,
## fevers speed the host and thicken the rot, surges double ichor, hushes
## stop the breath and muffle steps, dreams whisper history; each is
## announced; spasms and fevers are logged; ending one puts everything back.


func run() -> void:
	var state := autoload("WorldState")
	var bus := autoload("EventBus")
	await start_scene("res://game.tscn", 4242)
	var data = state.data
	var moods = game.get_node("BodyMoods")
	var moods_script: GDScript = load("res://src/world/body_moods.gd")
	var breath_script: GDScript = load("res://src/world/breath.gd")
	var shown := []
	var shakes := []
	var notes := []
	bus.place_entered.connect(func(title, _line, _first): shown.append(title))
	bus.shake_requested.connect(func(s): shakes.append(s))
	bus.notify.connect(func(text): notes.append(text))
	# A room in the central chamber with a ceiling close above.
	var map = game.get_node("DebugMapLayer/DebugMap") if game.has_node("DebugMapLayer/DebugMap") else game.find_child("DebugMap", true, false)
	var tile := Vector2i(100, 50)
	while map.floor_below(tile) == Vector2.INF and tile.y < 98:
		tile.y += 1
	await goto(map.floor_below(tile), 20)

	# Spasm.
	moods.begin(&"spasm", 20.0)
	check(moods_script.mood == &"spasm" and not shown.is_empty(), "a spasm is announced: %s" % [shown])
	for i in 200:
		await process_frame
	var debris := game.get_children().filter(func(c): return c.get_script() and c.get_script().resource_path.ends_with("falling_debris.gd"))
	check(not shakes.is_empty(), "the ground shakes (%d times)" % shakes.size())
	check(data.events.any(func(e): return e.type == &"body_mood"), "and the spasm is written into history")
	moods.end()
	# Debris hurts what it lands on.
	player.health.invulnerable = false
	player.health.heal_full()
	var hp: int = player.health.current
	var rock = load("res://src/world/falling_debris.gd").new()
	rock.position = player.global_position + Vector2(0, -120)
	game.add_child(rock)
	for i in 120:
		await physics_frame
	check(player.health.current < hp, "falling debris hurts the host (%d -> %d)" % [hp, player.health.current])
	player.health.invulnerable = true

	# Surge, hush, fever.
	moods.begin(&"surge", 5.0)
	check(moods_script.ichor_scale == 2.0, "a surge doubles ichor")
	moods.begin(&"hush", 5.0)
	var t: float = breath_script.time
	for i in 20:
		await physics_frame
	check(breath_script.time == t and moods_script.noise_scale == 0.5, "a hush stops the breath and muffles steps")
	moods.begin(&"fever", 5.0)
	var cell: int = int(player.global_position.y / 32.0 / 8) * data.rot_width + int(player.global_position.x / 32.0 / 8)
	var rot_before: int = data.rot[cell]
	for i in 150:
		await process_frame
	check(moods_script.speed_scale > 1.0 and data.rot[cell] > rot_before, "a fever speeds the host and thickens the rot (%d -> %d)" % [rot_before, data.rot[cell]])

	# Dream.
	notes.clear()
	moods.begin(&"dream", 30.0)
	await create_timer(1.0).timeout
	check(notes.any(func(n): return n.begins_with("...")), "the god dreams aloud: %s" % [notes])

	moods.end()
	check(moods_script.mood == &"" and moods_script.ichor_scale == 1.0 and moods_script.speed_scale == 1.0 and not breath_script.held, "ending a mood puts everything back")
