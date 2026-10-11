extends "res://tests/test_case.gd"
## The map after tools/map/rooms.gd (D-032): every thing placed in world.tscn
## can be reached from the player's spawn with the host's own jump, and the
## host can get back from it; ceilings hang undersides.


func run() -> void:
	var reach_script: GDScript = load("res://tools/map/map_reach.gd")
	var reach = reach_script.from_image(Image.load_from_file(ProjectSettings.globalize_path("res://data/maps/world.png")))
	var spawn: Vector2 = reach_script.placed("res://scenes/world.tscn", ["."]).filter(func(p): return p[0] == "PlayerSpawn")[0][2]
	var home := Vector2i(int(spawn.x / 32.0), int(spawn.y / 32.0))
	var reached: Dictionary = reach.flood(home)
	var back: Dictionary = reach.back(reached, home)
	var lost := []
	var stuck := []
	var things: Array = reach_script.placed("res://scenes/world.tscn", ["Entities", "SpawnPoints"])
	for thing in things:
		if not reach.is_reached(reached, thing[2]):
			lost.append(thing[0])
		elif not reach.is_reached(back, thing[2]):
			stuck.append(thing[0])
	check(things.size() > 80 and lost.is_empty(), "all %d placed things can be reached %s" % [things.size(), lost])
	check(stuck.is_empty(), "and left again %s" % [stuck])

	await start_scene("res://game.tscn")
	await wait_frames(10)
	var undersides := 0
	for dressing in game.find_children("Dressing", "", true, false):
		undersides += dressing.underside_count()
	check(undersides > 50, "ceilings and ledges hang undersides (%d)" % undersides)
