extends "res://tests/test_case.gd"
## Soak test (milestone 1): a bot plays for 10 game-minutes. It walks, jumps,
## attacks, uses all three mutations, and teleports to a random open spot every
## few seconds, so every chunk streams in and out many times.
##
## Run headless with --fixed-fps 60: every frame is exactly 1/60 s of game time
## and the engine runs as fast as it can, so 10 game-minutes take far less.
## Looks for leaks (memory, nodes) and broken state; frame times are measured
## separately by perf_render.gd.

const GAME_SECONDS := 600.0
const SAMPLE_EVERY := 60.0


func run() -> void:
	var state := autoload("WorldState")
	await start_scene("res://game.tscn")
	var chunks = game.get_node("ChunkManager")
	var entities = game.get_node("World/Entities")
	state.data.mutations = {"mouth": &"acid_gland", "arm": &"bone_spur", "back": &"lung_sac"}
	autoload("EventBus").mutations_changed.emit()

	var memory: Array[float] = []
	var nodes: Array[int] = []
	var orphans: Array[int] = []
	var max_loaded := 0
	var out_of_world := 0
	var entity_total: int = entities.count_total()
	var frames := int(GAME_SECONDS * 60.0)
	var next_teleport := 180
	var map_rect := Rect2(Vector2.ZERO, Vector2(chunks.map.size * ChunkData.TILE_PX))

	for frame in frames:
		player.health.invulnerable = true  # Testing stability, not survival.
		bot_step()
		await process_frame
		max_loaded = maxi(max_loaded, chunks.loaded_count())
		if not map_rect.has_point(player.global_position):
			out_of_world += 1
		if frame >= next_teleport:
			next_teleport = frame + _rng.randi_range(120, 360)
			await goto(random_open_spot(), 1)
		if frame % int(SAMPLE_EVERY * 60.0) == 0:
			memory.append(snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1))
			nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
			orphans.append(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))

	for action in ["move_left", "move_right", "jump", "attack", "ability_mouth", "ability_arm"]:
		Input.action_release(action)
	print("memory MB per game-minute: ", memory)
	print("nodes per game-minute:     ", nodes)
	print("orphan nodes:              ", orphans)
	# Compare the second half with the first sample after warm-up: growth means a leak.
	check(memory[-1] - memory[1] < 8.0, "memory stays flat (%.1f -> %.1f MB)" % [memory[1], memory[-1]])
	check(nodes.max() - nodes.min() < 400, "node count stays bounded (%d..%d)" % [nodes.min(), nodes.max()])
	check(orphans[-1] <= orphans[1] + 50, "detached nodes do not pile up (%d -> %d)" % [orphans[1], orphans[-1]])
	check(max_loaded <= 9, "never more than 9 chunks loaded")
	check(out_of_world == 0, "the player never left the map")
	check(entities.count_total() == entity_total, "no placed entities duplicated or lost")
