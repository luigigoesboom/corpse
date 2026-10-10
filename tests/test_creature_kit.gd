extends "res://tests/test_case.gd"
## The creature kit (week 45): the Puffsac, the first creature started with
## tools/creature/new_creature.gd, does its job; and every behaviour the
## scaffold offers makes a creature that comes alive and goes for the player.

const SCAFFOLD := "res://tools/creature/new_creature.gd"
const PUFFSAC := "res://src/actors/creatures/puffsac.tscn"


func run() -> void:
	await start_scene("res://game.tscn")
	var data = autoload("WorldState").data
	# Flat floor east of the Tender camp, away from its residents.
	await goto(Vector2(2000, 3178), 30)

	# --- The Puffsac drifts in, swells, bursts: hurts the host and its neighbours.
	var sac: Node2D = load(PUFFSAC).instantiate()
	sac.position = player.global_position + Vector2(170, -40)
	game.add_child(sac)
	var leech: Node2D = load("res://src/actors/creatures/gut_leech.tscn").instantiate()
	leech.position = player.global_position + Vector2(40, 0)
	game.add_child(leech)
	await wait_frames(2)
	var leech_health: Node = leech.get_node("Health")
	var leech_hp: int = leech_health.current
	leech.set_physics_process(false)  # Holds still beside the host.
	var hp: int = player.health.current
	var swelled := false
	for i in 300:
		await physics_frame
		swelled = swelled or sac.state == 2  # State.SWELL
		if sac._burst:
			break
	check(swelled, "a Puffsac drifts up to the host and swells first (the tell)")
	await wait_frames(6)
	check(sac._burst and sac.is_dead(), "then bursts and is gone")
	check(player.health.current == hp - 2, "the burst hurts the host (%d -> %d)" % [hp, player.health.current])
	check(leech_health.current < leech_hp, "and the creature next to it (friendly fire)")
	check(leech_health.last_hit_source == &"puffsac", "which is the Puffsac's doing, not the host's")
	leech.queue_free()

	# --- Popped by the host up close: a short fuse, then it still bursts.
	player.health.heal_full()
	await wait_frames(40)  # Let the host get over the first burst (stun, knockback).
	var kills: int = data.current_life().kills.get(&"puffsac", 0)
	var ichor: int = data.ichor
	sac = load(PUFFSAC).instantiate()
	sac.position = player.global_position + Vector2(34, -20)
	sac.trigger_range = 0.0  # It would swell on its own this close.
	game.add_child(sac)
	await wait_frames(3)
	player._facing = 1.0
	await press("attack")
	await wait_frames(4)
	check(sac.is_dead() and not sac._burst, "one hit pops it, and it does not burst at once")
	# Roll away through the fuse.
	Input.action_press("move_left")
	await press("dodge")
	await wait_frames(30)
	Input.action_release("move_left")
	check(sac._burst, "it bursts after the fuse anyway")
	check(player.health.current == player.health.max_health, "rolling away in time takes no harm")
	await wait_frames(80)
	check(data.current_life().kills.get(&"puffsac", 0) == kills + 1 and data.ichor > ichor, "the pop counts as the host's kill and gives ichor")
	var carcasses := game.get_children().filter(func(c): return c.get_script() != null and c.get_script().resource_path.ends_with("carcass.gd"))
	check(carcasses.all(func(c): return c.kind != &"puffsac"), "a burst sac leaves no carcass to eat")

	# --- Every scaffold behaviour comes alive and goes for the player.
	var scaffold: GDScript = load(SCAFFOLD)
	DirAccess.make_dir_recursive_absolute("user://kit_test")
	player.health.invulnerable = true
	for behaviour in scaffold.BEHAVIOURS:
		var kind: String = "kit_test_" + behaviour
		var script_path := "user://kit_test/%s.gd" % kind
		var script_text: String = scaffold._fill(scaffold._read(behaviour), kind, "Test", 48, behaviour)
		_write(script_path, script_text)
		var scene: String = scaffold.scene_text(kind, kind.to_pascal_case(), behaviour, 48)
		scene = scene.replace("res://src/actors/creatures/%s.gd" % kind, script_path)
		scene = scene.replace("assets/art/creatures/%s" % kind, "assets/art/creatures/puffsac")
		var scene_path := "user://kit_test/%s.tscn" % kind
		_write(scene_path, scene)
		var packed: PackedScene = ResourceLoader.load(scene_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		check(packed != null, "%s: the scaffold's scene loads" % behaviour)
		if packed == null:
			continue
		var creature: Node2D = packed.instantiate()
		var flies: bool = behaviour in ["flyer", "floater"]
		creature.position = player.global_position + (Vector2(150, -90) if flies else Vector2(130 if behaviour == "walker" else 50, 0))
		game.add_child(creature)
		var first: int = creature.state
		var attacked := false
		for i in 360:
			await physics_frame
			if creature.attack_box and creature.attack_box.active:
				attacked = true
				break
		check(creature.state != first or attacked, "%s: notices the player" % behaviour)
		check(attacked, "%s: and attacks (its Attack hitbox switches on)" % behaviour)
		creature.queue_free()
		await wait_frames(2)
		for path in [script_path, scene_path]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://kit_test"))


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
