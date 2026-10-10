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


## Runs right for 2.5 s and tracks where the player is drawn on screen. With
## physics interpolation the camera keeps the drawn player steady; without it
## (60 physics steps on a faster screen) it zig-zags back and forth.
## The renderer draws interpolated nodes between their last two physics
## positions; the GameCamera's Camera2D is one of them (Phantom Camera moves it
## in physics frames), so both are modelled the same way here.
func _check_running_is_smooth() -> void:
	player.teleport(Vector2(300, 3178))
	await wait_frames(30)
	var interpolated: bool = ProjectSettings.get_setting("physics/common/physics_interpolation")
	var camera: Camera2D = get_viewport_camera()
	var camera_interpolated: bool = camera.is_physics_interpolated_and_enabled()
	var track := {"prev": player.global_position, "cur": player.global_position,  # Lambdas copy plain locals.
		"cam_prev": camera.get_screen_center_position(), "cam_cur": camera.get_screen_center_position()}
	var follow := func():
		track.prev = track.cur
		track.cur = player.global_position
		track.cam_prev = track.cam_cur
		track.cam_cur = camera.get_screen_center_position()
	physics_frame.connect(follow)
	Input.action_press("move_right")
	var xs: Array[float] = []
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 2500:
		await process_frame
		# Interpolation on: drawn between the last two physics positions. Off: drawn where it is.
		var f := Engine.get_physics_interpolation_fraction()
		var drawn: Vector2 = track.prev.lerp(track.cur, f) if interpolated else player.global_position
		var view: Vector2 = track.cam_prev.lerp(track.cam_cur, f) if camera_interpolated else camera.get_screen_center_position()
		xs.append(drawn.x - view.x)
	Input.action_release("move_right")
	physics_frame.disconnect(follow)
	var steady := xs.slice(xs.size() / 2)
	var reversals := 0
	for i in range(2, steady.size()):
		var a: float = steady[i - 1] - steady[i - 2]
		var b: float = steady[i] - steady[i - 1]
		if a * b < 0.0 and absf(a) > 0.25 and absf(b) > 0.25:
			reversals += 1
	check(reversals < steady.size() / 20, "running looks smooth on screen (%d zig-zags in %d frames, camera interpolated: %s)" % [reversals, steady.size(), camera_interpolated])


func get_viewport_camera() -> Camera2D:
	return root.get_viewport().get_camera_2d()
