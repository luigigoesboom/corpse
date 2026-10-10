extends "res://tests/test_case.gd"
## UI and menus (week 41): settings that stick, rebinding, save slots with
## summaries, autosaves, and the menus a stranger needs.


func run() -> void:
	var settings := autoload("Settings")
	var saves := autoload("SaveSystem")
	var state := autoload("WorldState")
	settings.path = "user://settings_test.cfg"  # Never touch the player's own.

	# Volumes go to the buses and are kept.
	settings.set_volume(&"SFX", 0.5)
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	check(absf(sfx_db - linear_to_db(0.5)) < 0.01, "a volume slider sets its bus (SFX at %.1f dB)" % sfx_db)
	settings.set_volume(&"SFX", 1.0)
	settings.set_screen_shake(0.3)
	settings.screen_shake = 1.0
	settings.load_settings()
	check(absf(settings.screen_shake - 0.3) < 0.01, "settings are saved and read back")
	settings.set_screen_shake(1.0)

	# Rebinding.
	var key := InputEventKey.new()
	key.physical_keycode = KEY_K
	settings.rebind(&"jump", key)
	var events: Array = InputMap.action_get_events(&"jump")
	check(events.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_K) and not events.any(func(e): return e is InputEventKey and e.physical_keycode == KEY_SPACE),
		"jump can be moved to K (%s)" % settings.binding_text(&"jump"))
	check(events.any(func(e): return e is InputEventJoypadButton), "the gamepad button stays")
	settings.reset_bindings()
	check(InputMap.action_get_events(&"jump").any(func(e): return e is InputEventKey and e.physical_keycode == KEY_SPACE), "reset puts Space back")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://settings_test.cfg"))

	# The title screen.
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	get_root().add_child(menu)
	await process_frame
	var labels: Array = menu._buttons.get_children().map(func(b): return b.text)
	check("New game" in labels and "Settings" in labels and "Quit" in labels, "the title screen offers %s" % [labels])
	menu._settings.open(2)
	await process_frame
	check(menu._settings._key_buttons.size() == settings.REBINDABLE.size(), "the Controls tab lists every action")
	menu._settings.close()
	menu._slots.open(0)
	await process_frame
	check(menu._slots._list.get_child_count() == 3, "three save slots")
	menu.queue_free()
	await process_frame

	# Slots, summaries, autosaves (tests save into slot 97).
	await start_scene("res://game.tscn")
	game.get_node("UI/PauseMenu").leaving.emit()
	var info: Dictionary = saves.summary(97)
	check(info.get("host", "") == state.data.current_life().host_name and info.get("lives", 0) == 1, "leaving the game saves it (%s, life %d)" % [info.get("host", "?"), info.get("lives", 0)])
	player.health.take_damage(99, player.global_position + Vector2(10, 0))
	await create_timer(1.5).timeout
	game.get_node("UI").death_screen.wake_pressed.emit({})
	await wait_frames(5)
	check(saves.summary(97).get("lives", 0) == 2, "a new life autosaves")
	var pause = game.get_node("UI/PauseMenu")
	check(pause.get_node("%SettingsButton") != null and pause.get_node("%ControlsButton") != null, "the pause menu has Settings and Controls")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(97)))
