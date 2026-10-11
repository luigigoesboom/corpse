extends "res://tests/test_case.gd"
## Landmarks (week 48): the Lungs' places have names that show when you walk
## in (a discovery the first time, remembered in saves), crossing into the
## Lungs says so, and each place has its set piece.


func run() -> void:
	await start_scene("res://game.tscn")
	player.health.invulnerable = true
	var data = autoload("WorldState").data
	var hud = game.get_node("UI/HUD")
	var landmarks: Array = game.get_tree().get_nodes_in_group(&"landmarks")
	check(landmarks.size() >= 6, "the Lungs have their named places (%d)" % landmarks.size())
	check(landmarks.all(func(l): return WorldMap.region_of(l.global_position) == Regions.LUNGS), "all of them in the Lungs")
	check(landmarks.all(func(l): return l.title != "" and l.line != ""), "each with a name and a line")

	# Into the Lungs, onto the Bellows' balcony.
	var shown := []
	var firsts := []
	autoload("EventBus").place_entered.connect(func(title, _line, first):
		shown.append(title)
		if first:
			firsts.append(title))
	for i in 3:
		await process_frame  # The game notes it starts in the Gut.
	player.teleport(Vector2(310 * 32 + 16, 75 * 32 - 22))
	await wait_frames(20)
	check("The Lungs" in shown and "The Lungs" in firsts, "crossing into the Lungs names them, as a discovery (%s)" % [shown])
	check("The Bellows" in firsts, "the Bellows are discovered")
	check(data.places_seen.has("Bellows") and data.places_seen.has("region:lungs"), "and remembered")
	check(hud.place_shown() in ["The Bellows", "The Lungs"], "the HUD shows the name (%s)" % hud.place_shown())

	# Back to the Gut and in again: named, but not discovered twice.
	shown.clear()
	firsts.clear()
	player.teleport(Vector2(1200, 3178))
	await wait_frames(20)
	check("The Gut" in shown, "walking back names the Gut (%s)" % [shown])
	player.teleport(Vector2(310 * 32 + 16, 75 * 32 - 22))
	await wait_frames(20)
	check("The Bellows" in shown and firsts.is_empty(), "the Bellows again: named, not a discovery (%s, new %s)" % [shown, firsts])

	# Saved and loaded, still found.
	var saves = autoload("SaveSystem")
	saves.save_game(98)
	data.places_seen.clear()
	saves.load_game(98)
	await wait_frames(5)
	check(autoload("WorldState").data.places_seen.has("Bellows"), "what was found survives a save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(saves.slot_path(98)))

	# Every place has its set piece placed in it.
	var world: Node = game.get_node("World")
	var pieces := {"GreatBronchus": "CartilageGate", "Bellows": "PleuraCurtain", "AlveolarHives": "HiveLanternMid", "LowerLobe": "WildRootLungs", "HighAerie": "AerieNest"}
	for place in pieces:
		var landmark: Node2D = world.get_node("Landmarks/" + place)
		var piece: Node2D = null
		for child in world.get_node("Entities").get_children():
			if child.get_meta(&"entity_key", String(child.name)) == pieces[place]:
				piece = child
		if piece == null:
			for template in world.get_node("Entities").templates():
				if template.name == pieces[place]:
					piece = template
		# Entities sits at the world's origin; templates are not in the tree.
		check(piece != null and landmark.contains(piece.position), "%s has its %s" % [place, pieces[place]])
