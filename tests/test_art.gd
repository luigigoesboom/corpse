extends "res://tests/test_case.gd"
## Art pass 1 (week 39): no placeholder shapes left in the Gut, and the prop
## and item art keeps to the Gut palette (assets/art/_source/gut.gpl).

## Polygons that are effects, not placeholders: the sword's slash and the
## Matron's slam warning.
const EFFECTS := ["Slash", "Line", "Arrow"]


func run() -> void:
	# The palette.
	var palette := {}
	for line in FileAccess.get_file_as_string("res://assets/art/_source/gut.gpl").split("\n"):
		var bits := line.strip_edges().replace("\t", " ").split(" ", false)
		if bits.size() >= 3 and bits[0].is_valid_int():
			palette[Color8(int(bits[0]), int(bits[1]), int(bits[2])).to_html(false)] = true
	check(palette.size() >= 16, "the Gut palette has %d colors" % palette.size())

	# Every prop and item sprite uses only palette colors (cloth and panels
	# are light greys tinted in game, so they are left out).
	var off := []
	var checked := 0
	var dirs := ["res://assets/art/props/", "res://assets/art/items/"]
	# Everything the art program (tools/pixel, D-028) makes.
	for root in ["res://assets/art/hosts/", "res://assets/art/npcs/", "res://assets/art/mutations/", "res://assets/art/creatures/"]:
		for sub in DirAccess.get_directories_at(root):
			dirs.append(root + sub + "/")
			if DirAccess.dir_exists_absolute(root + sub + "/glow"):
				dirs.append(root + sub + "/glow/")
	for dir in dirs:
		for file in DirAccess.get_files_at(dir):
			if not file.ends_with(".png") or file.ends_with("_cloth.png"):
				continue
			checked += 1
			var img := Image.load_from_file(ProjectSettings.globalize_path(dir + file))
			var strays := 0
			for y in img.get_height():
				for x in img.get_width():
					var c := img.get_pixel(x, y)
					if c.a > 0.0 and not palette.has(c.to_html(false)):
						strays += 1
			if strays > 0:
				off.append("%s (%d px)" % [file, strays])
	check(checked >= 100 and off.is_empty(), "%d sprites (props, items, hosts, residents, mutations, creatures) keep to the palette %s" % [checked, off])

	# Nothing placed in the Gut is still made of placeholder polygons: the
	# world's entities, what settlements and ruins build, items, hazards.
	var scenes := {}
	var world: Node = load("res://scenes/world.tscn").instantiate()
	for node in world.get_node("Entities").get_children():
		if node.scene_file_path != "":
			scenes[node.scene_file_path] = true
	world.free()
	for def in [FactionDb.get_def(&"flesh_tenders"), FactionDb.get_def(&"choir_of_waking")]:
		for scene in def.settlement_props:
			scenes[scene.resource_path] = true
	for path in ["res://src/props/ruin/bone_heap.tscn", "res://src/props/ruin/broken_wall.tscn", "res://src/props/ruin/cold_hearth.tscn",
			"res://src/props/ruin/rubble.tscn", "res://src/props/ruin/toppled_pillar.tscn", "res://src/props/ruin/torn_banner.tscn",
			"res://src/items/world_item.tscn", "res://src/actors/bosses/bile_glob.tscn", "res://src/actors/bosses/bile_puddle.tscn",
			"res://src/actors/bosses/shockwave.tscn", "res://src/mutations/acid_projectile.tscn", "res://src/actors/player/player.tscn"]:
		scenes[path] = true
	var shapes := []
	for path in scenes:
		var root: Node = load(path).instantiate()
		_find_polygons(root, root, path.get_file(), shapes)
		root.free()
	check(scenes.size() >= 25 and shapes.is_empty(), "%d scenes in the Gut have no placeholder polygons left %s" % [scenes.size(), shapes])


func _find_polygons(node: Node, root: Node, scene: String, out: Array) -> void:
	for child in node.get_children():
		if child is Polygon2D and not String(child.name) in EFFECTS:
			out.append("%s:%s" % [scene, root.get_path_to(child)])
		_find_polygons(child, root, scene, out)
