extends SceneTree
## Base for test scripts. Each test extends this file and overrides run().
## Run one:  godot --headless --path . --script res://tests/test_movement.gd
## Run all:  tests/run_tests.sh
##
## Gotcha: a --script file compiles before autoloads exist. So tests reach
## autoloads with autoload("Name") and never mention project classes that
## use autoloads (Player, ChunkManager, WorldItem...), not even in type hints
## or `is` checks. Plain-data classes (WorldMap, ChunkData, WorldData) are fine.
##
## Save tests write to slots 98 and 99 in user://saves, never the player's slot 0.

var failures := 0
var game: Node
var player
var _rng := RandomNumberGenerator.new()
var _bot_dir := 1.0


func _initialize() -> void:
	_rng.seed = 42
	_run_and_finish.call_deferred()


## Override in each test.
func run() -> void:
	pass


func _run_and_finish() -> void:
	await run()
	print("%s: %d failed" % [get_script().resource_path.get_file(), failures])
	quit(1 if failures > 0 else 0)


func check(condition: bool, label: String) -> void:
	print(("PASS  " if condition else "FAIL  ") + label)
	if not condition:
		failures += 1


func autoload(autoload_name: String) -> Node:
	return root.get_node("/root/" + autoload_name)


## Starts a scene (usually res://game.tscn). `world_seed` makes the new
## world the same every run (0 = a random one, as in the game).
func start_scene(path: String, world_seed := 0) -> void:
	# Autosaves (each new life) must never touch the player's own slots.
	autoload("WorldState").slot = 97
	game = load(path).instantiate()
	if world_seed != 0 and "new_world_seed" in game:
		game.new_world_seed = world_seed
	if game.has_node("CombatFeel"):
		game.get_node("CombatFeel").hitstop_enabled = false  # Frame-counting tests.
	root.add_child(game)
	for i in 5:
		await physics_frame
	player = game.get_node("Player")


func wait_frames(n: int) -> void:
	for i in n:
		await physics_frame


## Puts the player at `pos` and waits. Far away, the chunks there are not
## built yet: the player is held in place until they are (or it would fall
## through a floor that is not there yet).
func goto(pos: Vector2, frames := 15) -> void:
	player.global_position = pos
	player.velocity = Vector2.ZERO
	var chunks: Node = game.get_node_or_null("ChunkManager")
	if chunks:
		var target := Vector2i(floori(pos.x / 2048.0), floori(pos.y / 2048.0))  # ChunkData.SIZE_PX
		for i in 180:
			await physics_frame
			player.global_position = pos
			player.velocity = Vector2.ZERO
			if i > 2 and chunks.is_loaded(target) and chunks.pending_count() == 0:
				break
	await wait_frames(frames)


func press(action: String, frames := 2) -> void:
	Input.action_press(action)
	await wait_frames(frames)
	Input.action_release(action)
	await physics_frame


## For UI actions handled in _unhandled_input (pause, inventory).
func ui_action(action: String) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventAction.new()
	up.action = action
	Input.parse_input_event(up)
	await process_frame


## A hand-placed entity from world.tscn, if it is currently in the tree.
func entity(key: String) -> Node:
	for child in game.get_node("World/Entities").get_children():
		if child.get_meta(&"entity_key", "") == key:
			return child
	return null


## One frame of a simple bot: walk, turn at walls, jump, attack, use abilities.
func bot_step() -> void:
	if player.is_on_wall() or _rng.randf() < 0.004:
		_bot_dir = -_bot_dir
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_press("move_right" if _bot_dir > 0 else "move_left")
	if _rng.randf() < 0.03:
		Input.action_press("jump")
	elif _rng.randf() < 0.1:
		Input.action_release("jump")
	for action in ["attack", "ability_mouth", "ability_arm"]:
		if _rng.randf() < 0.01:
			Input.action_press(action)
		else:
			Input.action_release(action)


## A random open spot on the map with headroom, as a player position.
func random_open_spot() -> Vector2:
	var map = game.get_node("ChunkManager").map
	for i in 200:
		var tile := Vector2i(_rng.randi_range(4, map.size.x - 5), _rng.randi_range(4, map.size.y - 5))
		if not map.is_solid(tile) and not map.is_solid(tile + Vector2i.UP):
			return Vector2(tile * ChunkData.TILE_PX) + Vector2(16, 10)
	return game.get_node("World/PlayerSpawn").global_position
