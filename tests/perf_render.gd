extends "res://tests/test_case.gd"
## Frame times with the real renderer: the bot plays for 60 seconds in a window.
## Run windowed (not headless):
##   godot --path . --windowed --resolution 1280x720 --script res://tests/perf_render.gd
## Opens a game window for about a minute. Numbers depend on the machine.

const SECONDS := 60.0


func run() -> void:
	await start_scene("res://game.tscn")
	autoload("WorldState").data.mutations = {"mouth": &"acid_gland", "arm": &"bone_spur", "back": &"lung_sac"}
	autoload("EventBus").mutations_changed.emit()
	for i in 60:
		await process_frame  # Warm-up: shaders compile, first chunks build.

	await _check_running_is_smooth()

	var frame_ms: Array[float] = []
	var elapsed := 0.0
	var next_teleport := 3.0
	var last := Time.get_ticks_usec()
	while elapsed < SECONDS:
		player.health.invulnerable = true
		bot_step()
		await process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		frame_ms.append(ms)
		elapsed += ms / 1000.0
		if elapsed > next_teleport:
			next_teleport = elapsed + _rng.randf_range(2.0, 5.0)
			player.global_position = random_open_spot()
			player.velocity = Vector2.ZERO

	frame_ms.sort()
	var n := frame_ms.size()
	var spikes := frame_ms.filter(func(ms): return ms > 33.4).size()
	print("frames %d  median %.1f ms (%.0f fps)  p99 %.1f ms  worst %.1f ms  over 33 ms: %d" % [
		n, frame_ms[n / 2], 1000.0 / frame_ms[n / 2], frame_ms[int(n * 0.99)], frame_ms[n - 1], spikes])
	check(frame_ms[int(n * 0.99)] < 33.4, "99% of frames under 33 ms")
	check(spikes < n / 200, "fewer than 0.5% of frames are spikes")


## Runs right, then stops, and tracks where the player is actually drawn:
## a magenta marker on the player and a row of them in the world are found in
## every rendered frame (read back from the screen, so interpolation, camera
## damping and pixel snapping are all included).
## Running: the player must not wobble back and forth on screen (it did, 1 px,
## when camera and player were rounded to pixels separately).
## Stopping: the view must settle without swinging back (it bounced when the
## camera led by velocity).
func _check_running_is_smooth() -> void:
	# The plain picture: grading, grain and the colour fringe would move and
	# recolour the magenta markers this reads.
	var settings = autoload("Settings")
	var atmosphere: float = settings.atmosphere
	settings.atmosphere = 0.0
	player.teleport(Vector2(400, 3170))
	await wait_frames(60)
	var unshaded := load("res://assets/materials/unshaded.tres")
	var markers: Array[Node] = []
	for i in 13:
		var dot := ColorRect.new()
		dot.color = Color.MAGENTA
		dot.size = Vector2(2, 2)
		dot.z_index = 100
		dot.material = unshaded
		if i == 0:
			dot.position = Vector2(0, -40)  # Above the player's head.
			player.add_child(dot)
		else:
			dot.position = Vector2(300 + i * 100, 3100)  # A row in the world.
			game.add_child(dot)
		markers.append(dot)
	await wait_frames(3)
	var samples := []  # [ms, player screen x, world row phase]
	Input.action_press("move_right")
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 3500:
		await process_frame
		var ms := Time.get_ticks_msec() - start
		if ms > 2000 and Input.is_action_pressed("move_right"):
			Input.action_release("move_right")
		var found := _find_markers(root.get_texture().get_image())
		if found.size() == 2:
			samples.append([ms, found[0], found[1]])
	Input.action_release("move_right")
	settings.atmosphere = atmosphere
	for dot in markers:
		dot.queue_free()
	var running := samples.filter(func(s): return s[0] > 300 and s[0] < 1900).map(func(s): return s[1])
	var stopping := samples.filter(func(s): return s[0] > 2000).map(func(s): return s[1])
	var wobbles := _reversals(running)
	check(running.size() > 60 and wobbles < running.size() / 20, "running: the player is steady on screen (%d wobbles in %d frames)" % [wobbles, running.size()])
	var swings := _reversals(stopping)
	check(stopping.size() > 60 and swings <= 3, "stopping: the view settles without swinging back (%d reversals)" % swings)


## Screen x of the player marker and of the leftmost world marker, from the
## magenta pixels in a frame. The world row is the y with the most of them.
func _find_markers(img: Image) -> Array:
	var by_row := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.r > 0.85 and c.b > 0.85 and c.g < 0.2:
				if not by_row.has(y):
					by_row[y] = []
				by_row[y].append(x)
	if by_row.is_empty():
		return []
	var world_y: int = by_row.keys().reduce(func(a, b): return a if by_row[a].size() >= by_row[b].size() else b)
	var player_x := -1
	for y in by_row:
		if absi(y - world_y) > 3:
			player_x = by_row[y].min()
	if player_x < 0:
		return []
	return [player_x, by_row[world_y].min()]


## How often a sequence turns around (ignoring frames where it stands still).
func _reversals(xs: Array) -> int:
	var last_step := 0
	var count := 0
	for i in range(1, xs.size()):
		var step: int = signi(xs[i] - xs[i - 1])
		if step == 0:
			continue
		if last_step != 0 and step != last_step:
			count += 1
		last_step = step
	return count
