extends "res://tests/test_case.gd"
## Painted map, chunk streaming, entity streaming (weeks 4-7, D-010, D-011).


func run() -> void:
	# Map reading on its own.
	var big := Image.create(8192, 4096, false, Image.FORMAT_RGBA8)
	var t := Time.get_ticks_usec()
	var big_map := WorldMap.new(big)
	check(Time.get_ticks_usec() - t < 50_000, "a huge map starts instantly")
	t = Time.get_ticks_usec()
	big_map.make_chunk(Vector2i(5, 5))
	var cut_ms := (Time.get_ticks_usec() - t) / 1000.0
	check(cut_ms < 15.0, "cutting a chunk is fast (%.1f ms)" % cut_ms)

	var soft := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	soft.set_pixel(0, 0, Color(0.3, 0.3, 0.3))
	soft.set_pixel(1, 0, Color(0.7, 0.7, 0.7))
	soft.set_pixel(2, 0, Color(0, 0, 0, 0))
	var soft_map := WorldMap.new(soft)
	check(soft_map.is_solid(Vector2i(0, 0)) and not soft_map.is_solid(Vector2i(1, 0)) and not soft_map.is_solid(Vector2i(2, 0)),
		"dark grey is rock, light grey and transparent are air")
	check(soft_map.is_solid(Vector2i(-1, 0)) and soft_map.is_solid(Vector2i(5, 0)), "outside the map is rock")

	# The game world.
	await start_scene("res://game.tscn")
	var chunks = game.get_node("ChunkManager")
	var entities = game.get_node("World/Entities")
	await wait_frames(30)
	check(player.is_on_floor(), "player starts standing at the spawn marker")
	check(not game.has_node("World/MapPreview"), "the editor map preview removes itself at runtime")

	var max_loaded := 0
	var size: Vector2i = chunks.map.size_in_chunks()
	for cy in size.y:
		for cx in size.x:
			await goto(ChunkData.chunk_origin(Vector2i(cx, cy)) + Vector2.ONE * ChunkData.SIZE_PX * 0.5, 4)
			max_loaded = maxi(max_loaded, chunks.loaded_count())
	check(max_loaded <= 9, "never more than 3 x 3 chunks loaded (max %d)" % max_loaded)

	await goto(game.get_node("World/PlayerSpawn").global_position, 10)
	check(entity("TenderCamp") != null and entity("LeechCavern") == null, "near spawn: nearby entities active, far ones detached")
	await goto(Vector2(7100, 3800), 10)
	check(entity("LeechCavern") != null and entity("TenderCamp") == null, "in the cavern: the reverse")

	var cells_before := _cell_count(chunks)
	var open := Image.create(chunks.map.size.x, chunks.map.size.y, false, Image.FORMAT_RGBA8)
	open.fill(Color.WHITE)
	chunks.map = WorldMap.new(open)
	chunks.reset()
	check(_cell_count(chunks) == 0, "a repainted (empty) map rebuilds the chunks")
	chunks.reload_map()
	check(_cell_count(chunks) == cells_before, "F4 reload reads world.png again")


func _cell_count(chunks) -> int:
	var n := 0
	for layer in chunks.get_children():
		n += layer.get_used_cells().size()
	return n
