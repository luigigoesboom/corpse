extends "res://tests/test_case.gd"
## Debug builds: clicking the debug map (M) puts the host on the floor
## under the click, for checking parts of the map quickly.


func run() -> void:
	await start_scene("res://game.tscn")
	var map = game.find_child("DebugMap", true, false)
	check(map != null, "debug map found")
	# The first open tile down a column of the chamber.
	var tile := Vector2i(100, 50)
	while map.floor_below(tile) == Vector2.INF and tile.y < 98:
		tile.y += 1
	var at: Vector2 = map.floor_below(tile)
	check(at != Vector2.INF, "a floor under the chamber (%s)" % at)
	map.visible = true
	await process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = map.get_global_transform_with_canvas() * (map._origin() + (Vector2(tile) + Vector2(0.5, 0.5)) * map._px())
	map._unhandled_input(click)
	await physics_frame
	check(player.global_position.distance_to(at) < 40, "click teleports (%s vs %s)" % [player.global_position, at])
	check(not map.visible, "map closes")
