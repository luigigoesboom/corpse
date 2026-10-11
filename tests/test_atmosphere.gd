extends "res://tests/test_case.gd"
## The atmosphere pass: the picture's look, the fog, the motes. The look
## follows the region (the Lungs pale and cold), the dark closes in red when
## the host is nearly dead, the heart beats in it, and the Atmosphere
## setting turns it all down to nothing.


func run() -> void:
	var settings = autoload("Settings")
	settings.path = "user://settings_test.cfg"
	await start_scene("res://game.tscn", 4242)
	player.health.invulnerable = true
	var atmosphere: Node = game.get_node("Atmosphere")
	var shade: ShaderMaterial = game.get_node("Vignette/Shade").material
	check(shade.shader.resource_path.ends_with("atmosphere.gdshader"), "the picture goes through the atmosphere shader")
	check(game.has_node("Fog") and game.has_node("Mist") and game.has_node("Motes"), "fog behind, mist in front, motes in the air")
	await wait_frames(20)
	var gut_lift: Vector3 = shade.get_shader_parameter("lift")
	check(gut_lift.x > gut_lift.z, "in the Gut the shadows are warm")

	# Into the Lungs: the look eases to cold.
	await goto(Vector2(420 * 32 + 16, 106 * 32 - 22), 10)
	for i in 240:
		await process_frame
	var lungs_lift: Vector3 = shade.get_shader_parameter("lift")
	check(lungs_lift.z > lungs_lift.x, "in the Lungs they turn cold (%s)" % lungs_lift)

	# Nearly dead: the dark closes in.
	check(shade.get_shader_parameter("hurt") == 0.0, "a healthy host sees clearly")
	player.health.invulnerable = false
	player.health.set_current(1)
	await process_frame
	await process_frame
	check(shade.get_shader_parameter("hurt") == 1.0, "with one heart left the edges close in")
	player.health.heal_full()

	# The heart beats in it: a strong thump, then quiet.
	var beat: GDScript = load("res://src/world/atmosphere.gd")
	check(beat.heartbeat(0.0) > 0.9 and beat.heartbeat(0.6) < 0.1, "the heartbeat thumps and fades")

	# Motes float about.
	var motes: Node = game.get_node("Motes")
	await process_frame
	check(motes._motes.size() == 80, "80 motes in the air")

	# The setting turns it down to nothing.
	settings.set_atmosphere(0.0)
	await process_frame
	await process_frame
	check(shade.get_shader_parameter("amount") == 0.0 and motes.amount == 0.0, "Atmosphere at 0 turns it off")
	settings.set_atmosphere(1.0)
	settings.set_film_grain(false)
	await process_frame
	await process_frame
	check(shade.get_shader_parameter("grain") == 0.0, "film grain can be turned off")
	settings.set_film_grain(true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_test.cfg"))
