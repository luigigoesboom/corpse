extends SceneTree
## Which parts of the world the host cannot get to (MapReach), and which
## things placed in world.tscn sit there.
##
##   Godot --headless --path . --script res://tools/map/check_reach.gd [-- --png <file>]
##
## With --png it also draws the map: rock dark, stand spots reached green,
## stand spots never reached red, unreachable things as yellow crosses.

const WORLD := "res://data/maps/world.png"
const SCENE := "res://scenes/world.tscn"
const PARENTS := ["Entities", "SpawnPoints", "Landmarks"]


func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(WORLD))
	var reach := MapReach.from_image(img)
	var spawn: Vector2 = MapReach.placed(SCENE, ["."]).filter(func(p): return p[0] == "PlayerSpawn")[0][2]
	var t0 := Time.get_ticks_msec()
	var reached := reach.flood(Vector2i(int(spawn.x / 32.0), int(spawn.y / 32.0)))
	var total := 0
	for y in reach.h:
		for x in reach.w:
			total += 1 if reach.standable(x, y) else 0
	print("reached %d of %d stand spots (%d ms)" % [reached.size(), total, Time.get_ticks_msec() - t0])
	var lost := []
	for thing in MapReach.placed(SCENE, PARENTS):
		if thing[1] == "Landmarks":
			continue  # Big areas, not spots.
		if not reach.is_reached(reached, thing[2]):
			lost.append(thing)
			print("  cannot reach %s/%s at tile %s" % [thing[1], thing[0], Vector2i(thing[2] / 32.0)])
	var args := OS.get_cmdline_user_args()
	var at := args.find("--png")
	if at >= 0:
		var out := Image.create(reach.w, reach.h, false, Image.FORMAT_RGBA8)
		for y in reach.h:
			for x in reach.w:
				var c := Color8(24, 12, 16)
				if reach.cell(x, y) == MapReach.R:
					c = Color8(90, 50, 56)
				elif reach.cell(x, y) == MapReach.M:
					c = Color8(255, 120, 200)
				elif reached.has(Vector2i(x, y)):
					c = Color8(90, 220, 110)
				elif reach.standable(x, y):
					c = Color8(240, 50, 50)
				out.set_pixel(x, y, c)
		for thing in lost:
			var p := Vector2i(thing[2] / 32.0)
			for d in range(-2, 3):
				for q in [p + Vector2i(d, 0), p + Vector2i(0, d)]:
					if q.x >= 0 and q.y >= 0 and q.x < reach.w and q.y < reach.h:
						out.set_pixel(q.x, q.y, Color.YELLOW)
		out.resize(reach.w * 4, reach.h * 4, Image.INTERPOLATE_NEAREST)
		out.save_png(args[at + 1])
	quit(1 if not lost.is_empty() else 0)
