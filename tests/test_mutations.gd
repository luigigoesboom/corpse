extends "res://tests/test_case.gd"
## Mutations v1 (D-015): eating items grows body parts with abilities.


func run() -> void:
	var state := autoload("WorldState")
	var bus := autoload("EventBus")
	var saves := autoload("SaveSystem")
	var messages: Array[String] = []
	await start_scene("res://game.tscn")
	bus.notify.connect(func(text): messages.append(text))

	await goto(Vector2(992, 3178))
	await press("interact")
	await goto(Vector2(736, 3082))
	await press("interact")
	await goto(Vector2(3904, 2218))
	await press("interact")
	for i in 3:
		bus.eat_requested.emit(i)
	await physics_frame
	check(state.data.mutations == {"mouth": &"acid_gland", "arm": &"bone_spur", "back": &"lung_sac"}, "eating the three items fills three body slots")
	check(player.sprite.has_layer(&"acid_gland") and player.sprite.has_layer(&"bone_spur") and player.sprite.has_layer(&"lung_sac"),
		"each mutation adds a sprite layer over the body")
	check(player.sprite.get_child(0).name == "lung_sac", "the lung sac layer is drawn behind the body")
	check(player.get_node("Mutations").get_child_count() == 3, "each mutation adds its ability")

	# Acid spit hits the chamber leech.
	var leech = entity("LeechChamber")
	await goto(Vector2(leech.global_position.x - 120, 3178), 3)
	player._facing = 1.0  # Face right.
	player.health.invulnerable = true
	var leech_hp: int = leech.get_node("Health").current
	await press("ability_mouth")
	await wait_frames(40)
	check(leech.get_node("Health").current == leech_hp - 2, "acid spit hits a leech for 2")

	# Bone spur dash.
	var dummy = entity("TrainingDummy")
	await goto(Vector2(1640, 3178), 3)
	player._facing = 1.0  # Face right.
	player.health.invulnerable = false
	var dummy_hp: int = dummy.get_node("Health").current
	var start_x: float = player.global_position.x
	await press("ability_arm", 1)
	check(player.health.is_invulnerable(), "dashing makes the host invulnerable")
	await wait_frames(15)
	check(player.global_position.x - start_x > 80.0 and dummy.get_node("Health").current == dummy_hp - 2, "the dash travels and cuts the dummy")
	check(not player.health.invulnerable, "invulnerability ends with the dash")

	# Lung sac glide.
	await goto(Vector2(3300, 1700), 1)
	Input.action_press("jump")
	var max_fall := 0.0
	for i in 60:
		await physics_frame
		if not player.is_on_floor():
			max_fall = maxf(max_fall, player.velocity.y)
	Input.action_release("jump")
	check(max_fall <= 70.5, "holding jump glides (max fall %.0f)" % max_fall)

	# Replacing a slot, and save / load.
	state.data.mutations["arm"] = &"acid_gland"
	state.data.inventory[0] = &"bone_shard"
	messages.clear()
	bus.eat_requested.emit(0)
	check(messages.size() == 1 and "withers" in messages[0], "a new mutation replaces the old one in its slot")
	state.data.player_position = player.global_position
	saves.save_game(98)
	state.data.mutations.clear()
	bus.mutations_changed.emit()
	saves.load_game(98)
	await physics_frame
	check(player.get_node("Mutations").get_child_count() == 3, "loading regrows the saved body")
