extends "res://tests/test_case.gd"
## The minimap (after week 41): walking reveals the caves around the host,
## the HUD shows what was seen with marks for places, and what was seen is
## kept in saves.


func run() -> void:
	await start_scene("res://game.tscn")
	player.health.invulnerable = true
	var data = autoload("WorldState").data
	var minimap = game.get_node("UI/HUD/Minimap")
	check(minimap != null and minimap.visible, "the HUD has a minimap")
	await wait_frames(30)
	var here := Vector2i((player.global_position / 32.0).floor())
	check(data.is_explored(here), "the tile the host stands on is seen")
	check(data.is_explored(here + Vector2i(10, 0)) and data.is_explored(here + Vector2i(0, -6)), "and about a screen around it")
	check(not data.is_explored(here + Vector2i(200, 0)), "but not far away")

	# The image shows walls in color where the host has been.
	var image: Image = minimap._image
	var lit := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.82:  # Unseen is 0.8, air and walls more.
				lit += 1
	check(lit > 100 and lit < image.get_width() * image.get_height() / 2, "the minimap draws what was seen, only that (%d pixels)" % lit)

	# Near the Tender camp: its mark shows.
	var camp: Node2D = entity("TenderCamp")
	await goto(camp.global_position + Vector2(0, -20), 30)
	check(minimap._marks.size() > 0, "a settlement shows as a mark")

	# Seen places are saved.
	var far := here + Vector2i(-3, 2)
	var save = autoload("SaveSystem")
	save.save_game(98)
	data.explored.clear()
	check(not data.is_explored(far), "(cleared)")
	save.load_game(98)
	check(autoload("WorldState").data.is_explored(far), "what was seen survives save and load")
