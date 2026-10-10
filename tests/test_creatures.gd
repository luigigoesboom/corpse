extends "res://tests/test_case.gd"
## Creatures from week 18: Bile Spitter (uses the Acid Gland) and Rot Fly.


func run() -> void:
	var state := autoload("WorldState")
	await start_scene("res://game.tscn")

	# Bile Spitter on a ledge over the chamber (3920, 2816; moved off the shaft
	# watch in week 36): stand in sight and get spat at.
	await goto(Vector2(3800, 2794), 30)
	var spitter = entity("SpitterChamber")
	# Hand-placed creatures are copies of templates that already ran _ready():
	# runtime-built nodes must not be copied along (a second, stale body
	# drawn a frame behind the real one).
	var sprite = spitter.get_node("Visual/Sprite")
	check(sprite.get_child_count() == 1 + sprite._layers.size(), "a placed creature draws one body, not a stale copy too (%d sprites)" % sprite.get_child_count())
	check(spitter.get_node("Mutations").ability(&"acid_gland") != null, "the spitter has the same Acid Gland ability as the player")
	await goto(Vector2(3790, 2794), 1)
	var hp: int = player.health.current
	var spat := false
	for i in 150:
		await physics_frame
		for child in spitter.get_parent().get_children():  # Projectiles spawn beside their shooter.
			if child.has_node("Hitbox") and child.get_node("Hitbox").collision_layer & 32:
				spat = true
		if player.health.current < hp:
			break
	check(spat, "the spitter fires acid on the enemy attack layer")
	check(player.health.current < hp, "its aimed spit hits the player")

	# Kill it: it drops a Bile Bulb and stays dead.
	player.health.invulnerable = true
	for i in 6:
		if spitter.get_parent() == null:
			break
		await goto(spitter.global_position + Vector2(-36, -22), 1)
		player._facing = 1.0
		await press("attack")
		await wait_frames(20)
	await create_timer(1.2).timeout
	var bulbs := game.get_node("Items").get_children().filter(func(item): return item.item_id == &"bile_bulb")
	check(bulbs.size() == 1, "a dead spitter drops a Bile Bulb")
	check(state.data.removed_entities.has("SpitterChamber"), "a killed spitter is gone for good")

	# Rot Fly: put it above the player, it should stalk and dive into them.
	player.health.invulnerable = false
	player.health.heal_full()
	await goto(Vector2(3500, 3178), 5)  # Away from the chamber leech.
	var fly = entity("FlyChamber")
	fly.position = player.global_position + Vector2(120, -160)
	var dove := false
	for i in 400:
		await physics_frame
		dove = dove or fly.state == 3  # State.DIVE
		if player.health.current < player.health.max_health:
			break
	check(dove, "the fly stalks and dives")
	check(player.health.current < player.health.max_health, "the dive hurts the player")

	# Friendly fire switch for the systemic style.
	check(CombatRules.friendly_fire, "friendly fire is on by default (D-018)")
	check(CombatRules.enemy_attack_layer() == 48, "so enemy attacks also hit creatures")
	CombatRules.friendly_fire = false
	check(CombatRules.enemy_attack_layer() == 32, "with it off they only hit the player")
	CombatRules.friendly_fire = CombatRules.DEFAULT_FRIENDLY_FIRE
