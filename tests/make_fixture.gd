extends "res://tests/test_case.gd"
## Writes tests/fixtures/save_v<N>.save for the current save version N
## (week 46): a world one death in, with ichor on the body, a seen map and a
## bile bulb in the pockets. tests/test_old_saves.gd loads every fixture, so
## each format the game ever wrote keeps loading. Run it once whenever
## SaveSystem.SAVE_VERSION goes up (not part of run_tests.sh):
##
##   Godot --headless --path . --script res://tests/make_fixture.gd


func run() -> void:
	var saves = autoload("SaveSystem")
	await start_scene("res://game.tscn")
	var data = autoload("WorldState").data
	await wait_frames(30)
	data.add_ichor(7)
	data.add_to_inventory(&"bone_shard")
	player.health.take_damage(99, Vector2.ZERO, 0.0)
	await wait_frames(150)
	var ui = game.get_node("UI")
	ui.death_screen.continue_pressed.emit()
	await wait_frames(20)
	ui.death_screen.wake_pressed.emit({})
	await wait_frames(30)
	data.add_to_inventory(&"bile_bulb")
	check(saves.save_game(96) == OK, "saved")
	var path := "res://tests/fixtures/save_v%d.save" % saves.SAVE_VERSION
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/fixtures"))
	check(DirAccess.copy_absolute(ProjectSettings.globalize_path(saves.slot_path(96)), ProjectSettings.globalize_path(path)) == OK, "wrote %s" % path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(96)))
