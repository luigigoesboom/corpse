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
	check(_ordinary(items).size() == 1 and is_equal_approx(_ordinary(items)[0].position.y, 3200.0 + ChunkData.FLOOR_SINK), "a dropped item lands on the floor")
	# Tabs (week 25 rework): E / Q (LB / RB) cycle Pockets, Body, Lives.
	await ui_action("ui_tab_next")
	check(screen.tab == 1, "E switches to the Body tab")
	await ui_action("ui_tab_next")
	check(screen.tab == 2, "and again to Lives")
	await ui_action("ui_tab_next")
	check(screen.tab == 0, "and wraps back to Pockets")
	await ui_action("ui_tab_prev")
	check(screen.tab == 2, "Q goes the other way")
	await ui_action("ui_tab_prev")
	await ui_action("ui_tab_prev")
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
	var dropped_x: float = _ordinary(items)[0].position.x
	await goto(Vector2(7100, 3800))
	var kept := 0
	for chunk in state.data.chunk_diffs:
		kept += state.data.items_in_chunk(chunk).filter(func(r): return not String(r.item).begins_with("artifact_")).size()
	check(_ordinary(items).size() == 0 and kept == 1, "far away: the item node is gone, its data is kept")
	await goto(Vector2(1500, 3178))
	check(_ordinary(items).size() == 1 and is_equal_approx(_ordinary(items)[0].position.x, dropped_x), "back again: the item is where it was dropped")

	# Full pockets refuse a pickup.
	for i in WorldData.INVENTORY_SIZE:
		state.data.inventory[i] = &"bone_shard"
	messages.clear()
	await goto(Vector2(dropped_x, 3178))
	await press("interact")
	check(messages == ["Pockets are full"] and _ordinary(items).size() == 1, "full pockets refuse a pickup")


## Item views except artifacts (week 29: ruins have one lying in them).
func _ordinary(items: Node) -> Array:
	return items.get_children().filter(func(item): return not String(item.item_id).begins_with("artifact_"))
