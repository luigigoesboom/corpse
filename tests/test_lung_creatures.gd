extends "res://tests/test_case.gd"
## The Lungs' creatures (week 49): the Cilia Lasher whips what comes within
## reach and leaves alone what does not; the Bellows Ray swoops down in a
## curve and up again, and drops a breath sac; Puffsacs, Lashers and Rays
## live in the Lungs and give ichor.

const T := 32.0


func run() -> void:
	await start_scene("res://game.tscn")
	var data = autoload("WorldState").data
	var entities = game.get_node("World/Entities")
	var kinds := {}
	for template in entities.templates():
		var kind: StringName = StringName(template.scene_file_path.get_file().get_basename())
		if kind in [&"puffsac", &"cilia_lasher", &"bellows_ray"]:
			kinds[kind] = kinds.get(kind, 0) + 1
			check(WorldMap.region_of(template.position) == Regions.LUNGS, "%s lives in the Lungs" % template.name)
	check(kinds.size() == 3 and kinds.values().all(func(n): return n >= 3), "three or more of each Lung creature are placed (%s)" % kinds)
	for kind in [&"puffsac", &"cilia_lasher", &"bellows_ray"]:
		check(Ichor.CREATURE_VALUES.has(kind), "%s gives ichor" % kind)

	# The Lasher on the Lower Lobe's floor: stand outside its reach, then in it.
	await goto(Vector2(420 * T + 16, 106 * T - 22), 30)
	var lasher: Node2D = load("res://src/actors/creatures/cilia_lasher.tscn").instantiate()
	lasher.position = player.global_position + Vector2(130, 22)
	game.add_child(lasher)
	await wait_frames(60)
	check(lasher.state == 0, "out of its reach, the Lasher leaves you alone")
	var hp: int = player.health.current
	player.teleport(lasher.global_position + Vector2(-60, -22))
	var drew := false
	for i in 120:
		await physics_frame
		drew = drew or lasher.state == 1  # WINDUP
		if player.health.current < hp:
			break
	check(drew, "in reach, it draws its lash back first (the tell)")
	check(player.health.current < hp, "then the lash lands")
	lasher.queue_free()

	# The Ray above the host: it swoops down at it and bends back up.
	player.health.heal_full()
	await wait_frames(40)
	var ray: Node2D = load("res://src/actors/creatures/bellows_ray.tscn").instantiate()
	ray.position = player.global_position + Vector2(160, -150)
	game.add_child(ray)
	hp = player.health.current
	var lowest := -INF
	var climbed_after := false
	var swooped := false
	for i in 500:
		await physics_frame
		if ray.state == 3:  # SWOOP
			swooped = true
			lowest = maxf(lowest, ray.global_position.y)
			if ray.velocity.y < -60.0 and ray.state_time > 0.2:
				climbed_after = true
		if swooped and climbed_after and ray.state != 3:
			break
	check(swooped, "the Ray swoops")
	check(climbed_after, "and pulls up out of the dive (a curve, not a line)")
	check(lowest > player.global_position.y - 30.0, "down to the host's height")
	check(player.health.current < hp, "and the swoop hurts")

	# Killed, it drops its breath sac.
	player.health.invulnerable = true
	ray.health.take_damage(99, player.global_position, 0.0, &"player")
	await wait_frames(80)
	var sacs: Array = game.get_node("Items").get_children().filter(func(item): return item.item_id == &"breath_sac")
	check(sacs.size() >= 1, "a dead Ray leaves its breath sac to eat")
	check(data.current_life().kills.get(&"bellows_ray", 0) == 1, "and counts as the host's kill")
