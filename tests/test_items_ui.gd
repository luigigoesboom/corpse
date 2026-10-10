extends "res://tests/test_case.gd"
## Items, pockets, inventory screen, pause menu (week 9, UI sweep).


func run() -> void:
	var state := autoload("WorldState")
	var bus := autoload("EventBus")
	var messages: Array[String] = []
	await start_scene("res://game.tscn")
	bus.notify.connect(func(text): messages.append(text))
	var items = game.get_node("Items")

	await goto(Vector2(992, 3178))
	await press("interact")
	await goto(Vector2(736, 3082))
	await press("interact")
	check(state.data.inventory.slice(0, 2) == [&"bile_bulb", &"bone_shard"], "pickups go into the first free pockets")
	check("+ Bile Bulb" in messages, "a pickup shows a message")
	check(entity("BileBulb") == null and state.data.removed_entities.has("BileBulb"), "a picked-up placed item is gone for good")

	# Inventory screen pauses; drop puts the item on the floor.
	await goto(Vector2(1500, 3178))
	await ui_action("inventory")
	var screen = game.get_node("UI/InventoryScreen")
	check(screen.visible and paused, "the inventory opens and pauses the game")
	screen.get_node("%Grid").get_child(1).grab_focus()
	await process_frame
	screen.get_node("%DropButton").pressed.emit()
	await process_frame
	check(items.get_child_count() == 1 and is_equal_approx(items.get_child(0).position.y, 3200.0 + ChunkData.FLOOR_SINK), "a dropped item lands on the floor")
	await ui_action("inventory")
	check(not screen.visible and not paused, "closing the inventory unpauses")

	await ui_action("pause")
	var pause_menu = game.get_node("UI/PauseMenu")
	check(pause_menu.visible and paused, "Esc opens the pause menu")
	await ui_action("inventory")
	check(not screen.visible, "the inventory cannot open over the pause menu")
	await ui_action("pause")
	check(not pause_menu.visible and not paused, "Esc again resumes")

	# A dropped item survives its chunk unloading.
	var dropped_x: float = items.get_child(0).position.x
	await goto(Vector2(7100, 3800))
	check(items.get_child_count() == 0 and state.data.chunk_diffs.size() == 1, "far away: the item node is gone, its data is kept")
	await goto(Vector2(1500, 3178))
	check(items.get_child_count() == 1 and is_equal_approx(items.get_child(0).position.x, dropped_x), "back again: the item is where it was dropped")

	# Full pockets refuse a pickup.
	for i in WorldData.INVENTORY_SIZE:
		state.data.inventory[i] = &"bone_shard"
	messages.clear()
	await goto(Vector2(dropped_x, 3178))
	await press("interact")
	check(messages == ["Pockets are full"] and items.get_child_count() == 1, "full pockets refuse a pickup")
