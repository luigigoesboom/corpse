extends "res://tests/test_case.gd"
## Audio pass (week 40): every sound has something to play, the buses exist,
## and the ambience follows where you are.


func run() -> void:
	var sfx := autoload("Sfx")
	var bus := autoload("EventBus")
	var missing := []
	for id in sfx.SOUNDS:
		if not sfx.has_sound(id):
			missing.append(id)
	check(missing.is_empty(), "every one of %d sounds has a file or a recipe %s" % [sfx.SOUNDS.size(), missing])
	var own := 0
	for id in sfx.SOUNDS:
		if ResourceLoader.exists("res://assets/audio/generated/%s.wav" % id):
			own += 1
	check(own >= 30, "%d of them have our own generated version (the game sounds without the pack)" % own)
	for name in ["Music", "Ambience", "SFX", "UI"]:
		check(AudioServer.get_bus_index(name) >= 0, "the %s bus exists" % name)

	await start_scene("res://game.tscn")
	var ambience = game.get_node("Ambience")
	var layers: int = 4 + RockKinds.count()  # Body, settlement, boss, breath, and one per kind of rock.
	check(ambience.get_child_count() == layers, "%d ambience layers are playing (%d)" % [layers, ambience.get_child_count()])
	var top: Dictionary = ambience.targets_at(Vector2(5300, 820))
	var deep: Dictionary = ambience.targets_at(Vector2(5300, 3840))
	check(deep[&"body"] > top[&"body"], "the body's heartbeat is louder deeper down (%.2f > %.2f)" % [deep[&"body"], top[&"body"]])
	check(deep[&"bruise"] > 0.5 and top[&"bone"] > 0.5, "the deep sounds bruised, the upper tunnel boney")
	var camp: Dictionary = ambience.targets_at(Vector2(1220, 3170))
	check(camp[&"settlement"] > 0.9 and deep[&"settlement"] == 0.0, "people murmur near a settlement, not elsewhere")
	check(camp[&"boss"] == 0.0, "no boss music before a boss")
	ambience._boss = true  # What boss_engaged sets (emitting it needs a real boss for the HUD).
	check(ambience.targets_at(Vector2(1220, 3170))[&"boss"] == 1.0, "a boss fight brings in the boss layer")
	bus.boss_defeated.emit(null)
	check(ambience.targets_at(Vector2(1220, 3170))[&"boss"] == 0.0, "and it goes when the boss dies")
	for player in ambience.get_children():
		var wav := player.stream as AudioStreamWAV
		check(wav == null or wav.loop_mode != AudioStreamWAV.LOOP_DISABLED, "%s loops" % player.stream.resource_path.get_file())
