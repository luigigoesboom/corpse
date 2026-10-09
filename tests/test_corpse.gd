extends "res://tests/test_case.gd"
## The corpse (week 22): die, wake with nothing, walk back, take your things.


func run() -> void:
	var state := autoload("WorldState")
	var saves := autoload("SaveSystem")
	var bus := autoload("EventBus")
	await start_scene("res://game.tscn")
	var data = state.data
	var corpses = game.get_node("Corpses")

	# Carry a Bile Bulb, grow a Bone Spur, then die in the chamber (mid-air).
	await goto(Vector2(992, 3178))
	await press("interact")
	await goto(Vector2(736, 3082))
	await press("interact")
	bus.eat_requested.emit(1)
	await wait_frames(2)
	check(data.inventory[0] == &"bile_bulb" and data.mutations.get("arm") == &"bone_spur", "before death: a bulb in the pocket, a spur on the arm")
	await goto(Vector2(3000, 3100), 1)
	player.health.take_damage(99, player.global_position + Vector2(10, 0), 0.0, &"rot_fly")
	await create_timer(1.5).timeout
	check(corpses.corpse_count() == 1, "the body appears where the host died")
	var corpse = corpses.get_child(0)
	check(is_equal_approx(corpse.position.y, 3200.0), "the body lies on the floor, not in the air")
	check(not player.get_node("Visual").visible, "the dying host is replaced by its body")

	game.get_node("UI").death_screen.wake_pressed.emit({})  # Skips time passing (tested in test_aftermath).
	await wait_frames(3)
	check(data.inventory.all(func(item): return item == &"") and data.mutations.is_empty(), "the new host wakes with nothing")
	check(player.get_node("Mutations").get_child_count() == 0, "and without the old host's abilities")
	check(data.lives[0].corpse_items == [&"bile_bulb"] and data.lives[0].corpse_mutations == {"arm": &"bone_spur"}, "everything stays on the old body")

	# The body survives leaving the area and a save / load.
	await goto(Vector2(7100, 3800))
	check(corpses.corpse_count() == 0, "far away: the body's node is gone")
	data.player_position = player.global_position
	saves.save_game(98)
	saves.load_game(98)
	data = state.data
	await goto(Vector2(2950, 3178))
	check(corpses.corpse_count() == 1, "after a save and load, the body is back where it fell")

	# Search it: everything comes back.
	await goto(corpses.get_child(0).position + Vector2(-20, -22))
	await press("interact")
	await wait_frames(2)
	check(data.inventory[0] == &"bile_bulb" and data.mutations.get("arm") == &"bone_spur", "searching the body takes back the bulb and regrows the spur")
	check(player.get_node("Mutations").get_child_count() == 1, "the reclaimed spur works again")
	check(not data.lives[0].has_corpse_loot(), "the body is empty now")
	check("empty body" in corpses.get_child(0).get_node("Prompt").text, "and says so")

	# What does not fit stays on the body.
	data.lives[0].corpse_items = [&"bone_shard"]
	for i in WorldData.INVENTORY_SIZE:
		data.inventory[i] = &"bile_bulb"
	await press("interact")
	check(data.lives[0].corpse_items == [&"bone_shard"], "with full pockets the item stays on the body")
