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
