extends SceneTree
## Week 39 art pass: turns the Gut's placeholder props into pixel art in
## the Gut palette (assets/art/_source/gut.gpl), and draws the things that
## were drawn in code (carcass, key caches, brazier, grate, murals, items).
##
##   Godot --headless --path . --script res://tools/art/make_props.gd
##
## The polygon placeholders are gone now (swapped in week 39), so step 1
## finds nothing left to rasterize; the PNGs in assets/art/props are the art.
## Paint over them in Aseprite with the Gut palette. Step 2 still repaints
## the hand-painted ones below (it overwrites them: copy a file to a new
## name before editing it by hand, or delete its block here).
##
## 1. Every Polygon2D prop scene listed in SCENES is rasterized: each group
##    of polygons under one parent becomes a body PNG (colors snapped to the
##    palette, shaded below, lit along the top edge, 1 px dark outline), a
##    glow PNG (the unshaded parts, no outline) and, for faction-tinted
##    cloth, a cloth PNG in light greys (tinted in game). The offsets go to
##    tools/art/props_manifest.json for tools/art/swap_props.py, which
##    replaces the polygons in the scenes with Sprite2D nodes.
## 2. The code-drawn things and item icons are painted by hand below.
## Run it again after changing the palette or a placeholder: it overwrites.

const PALETTE := "res://assets/art/_source/gut.gpl"
const OUT := "res://assets/art/props/"
const ITEMS_OUT := "res://assets/art/items/"
const MANIFEST := "res://tools/art/props_manifest.json"
const SCENES := [
	"res://src/props/glow_fungus.tscn",
	"res://src/props/ruin/bone_heap.tscn",
	"res://src/props/ruin/broken_wall.tscn",
	"res://src/props/ruin/cold_hearth.tscn",
	"res://src/props/ruin/rubble.tscn",
	"res://src/props/ruin/toppled_pillar.tscn",
	"res://src/props/ruin/torn_banner.tscn",
	"res://src/props/settlement/banner.tscn",
	"res://src/props/settlement/bell.tscn",
	"res://src/props/settlement/bile_cistern.tscn",
	"res://src/props/settlement/candles.tscn",
	"res://src/props/settlement/drying_rack.tscn",
	"res://src/props/settlement/flesh_plot.tscn",
	"res://src/props/settlement/reliquary.tscn",
	"res://src/props/settlement/shrine.tscn",
	"res://src/props/settlement/tender_lamp.tscn",
	"res://src/props/settlement/tent.tscn",
	"res://src/world/heart_root.tscn",
	"res://src/world/ichor_clot.tscn",
	"res://src/actors/bosses/bile_glob.tscn",
	"res://src/actors/bosses/bile_puddle.tscn",
	"res://src/actors/bosses/shockwave.tscn",
	"res://src/mutations/acid_projectile.tscn",
	"res://src/actors/npcs/placeholder_npc.tscn",
	"res://src/actors/creatures/training_dummy.tscn",
]
## Polygons tinted in game (by name), drawn as light greys.
const TINTED := ["Cloth"]

var pal: Array[Color] = []
var outline: Color


func _initialize() -> void:
	pal = _load_palette()
	outline = pal[0]
	for dir in [OUT, ITEMS_OUT]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var manifest := {}
	for path in SCENES:
		manifest[path] = _rasterize_scene(path)
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	_paint_customs()
	_paint_items()
	print("props written: %d scenes, palette of %d colors" % [SCENES.size(), pal.size()])
	quit()


# --- Palette -------------------------------------------------------------------

func _load_palette() -> Array[Color]:
	var out: Array[Color] = []
	var text := FileAccess.get_file_as_string(PALETTE)
	for line in text.split("\n"):
		if line.begins_with("#") or line.begins_with("GIMP") or line.begins_with("Name") or line.begins_with("Columns"):
			continue
		var bits := line.strip_edges().replace("\t", " ").split(" ", false)
		if bits.size() >= 3 and bits[0].is_valid_int():
			out.append(Color8(int(bits[0]), int(bits[1]), int(bits[2])))
	return out


## The palette color nearest to `c` ("redmean" distance), keeping c's alpha.
func snap(c: Color) -> Color:
	var best := pal[0]
	var best_d := INF
	for p in pal:
		var rm := (c.r + p.r) * 0.5
		var dr := c.r - p.r
		var dg := c.g - p.g
		var db := c.b - p.b
		var d := (2.0 + rm) * dr * dr + 4.0 * dg * dg + (3.0 - rm) * db * db
		if d < best_d:
			best_d = d
			best = p
	return Color(best, c.a)


# --- Rasterizing polygon scenes ------------------------------------------------

func _rasterize_scene(path: String) -> Array:
	var root: Node = load(path).instantiate()
	var groups := {}  # parent path -> [Polygon2D]
	_collect(root, root, groups)
	var out := []
	var base := path.get_file().get_basename()
	for parent_path in groups:
		var polys: Array = groups[parent_path]
		var shapes := []  # {points, color, kind, name}
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for poly: Polygon2D in polys:
			var xform := _to_parent_space(poly, root.get_node(parent_path) if parent_path != "." else root)
			var points := PackedVector2Array()
			for p in poly.polygon:
				var q := xform * (p + poly.offset)
				points.append(q)
				lo = lo.min(q)
				hi = hi.max(q)
			var kind := "body"
			if poly.name in TINTED:
				kind = "cloth"
			elif poly.material != null:
				kind = "glow"
			shapes.append({"points": points, "color": poly.color, "kind": kind})
		var origin := Vector2i(floori(lo.x) - 1, floori(lo.y) - 1)
		var size := Vector2i(ceili(hi.x) - origin.x + 2, ceili(hi.y) - origin.y + 2)
		var name := base if parent_path == "." else "%s_%s" % [base, String(parent_path).to_lower().replace("/", "_")]
		for kind in ["body", "glow", "cloth"]:
			var mine := shapes.filter(func(s): return s.kind == kind)
			if mine.is_empty():
				continue
			var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
			for s in mine:
				_fill(img, origin, s.points, s.color, kind)
			if kind == "body":
				_outline(img)
			var file := "%s%s_%s.png" % [OUT, name, kind]
			img.save_png(ProjectSettings.globalize_path(file))
			out.append({"parent": String(parent_path), "kind": kind, "png": file, "offset": [origin.x, origin.y],
				"replaces": mine.size()})
		out.append({"parent": String(parent_path), "polygons": polys.map(func(p): return String(p.name))})
	root.free()
	return out


func _collect(node: Node, root: Node, groups: Dictionary) -> void:
	for child in node.get_children():
		if child is Polygon2D:
			var key := String(root.get_path_to(node))
			groups.get_or_add(key, []).append(child)
		_collect(child, root, groups)


## The transform from `node`'s space into `parent`'s space.
func _to_parent_space(node: Node2D, parent: Node) -> Transform2D:
	var xform := node.transform
	var p := node.get_parent()
	while p != parent and p is Node2D:
		xform = p.transform * xform
		p = p.get_parent()
	return xform


func _fill(img: Image, origin: Vector2i, points: PackedVector2Array, color: Color, kind: String) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in points:
		lo = lo.min(p)
		hi = hi.max(p)
	var height := hi.y - lo.y
	var base := snap(color)
	var shade := snap(color.darkened(0.3))
	var light := snap(color.lightened(0.2))
	if kind == "cloth":
		base = Color(0.92, 0.92, 0.92) * Color(1, 1, 1, color.a)
		shade = Color(0.7, 0.7, 0.7, color.a)
		light = Color(1, 1, 1, color.a)
	for y in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			var at := Vector2(x + 0.5, y + 0.5)
			if not Geometry2D.is_point_in_polygon(at, points):
				continue
			var c := base
			if kind != "glow" and height >= 5.0:
				var t := (at.y - lo.y) / height
				var top_edge := not Geometry2D.is_point_in_polygon(at - Vector2(0, 1), points)
				if t > 0.68:
					c = shade
				elif top_edge:
					c = light
			var px := Vector2i(x, y) - origin
			if px.x >= 0 and px.y >= 0 and px.x < img.get_width() and px.y < img.get_height():
				img.set_pixelv(px, c)


func _outline(img: Image) -> void:
	var marks: Array[Vector2i] = []
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.0:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixelv(q).a > 0.5:
					marks.append(Vector2i(x, y))
					break
	for m in marks:
		img.set_pixelv(m, outline)


# --- Painting by hand ------------------------------------------------------------

## A blank image to paint on, and helpers in palette colors.
func _canvas(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, snap(c))


func _rect(img: Image, r: Rect2i, c: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_px(img, x, y, c)


func _ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, c: Color, shade := Color(0, 0, 0, 0)) -> void:
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 1):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				_px(img, x, y, shade if shade.a > 0.0 and dy > 0.35 else c)


func _line(img: Image, a: Vector2, b: Vector2, c: Color) -> void:
	var steps := maxi(1, ceili(a.distance_to(b)))
	for i in steps + 1:
		var p := a.lerp(b, float(i) / steps)
		_px(img, floori(p.x), floori(p.y), c)


func _save(img: Image, file: String, with_outline := true) -> void:
	if with_outline:
		_outline(img)
	img.save_png(ProjectSettings.globalize_path(file))


func _paint_customs() -> void:
	var bone := Color8(238, 228, 200)
	var bone_sh := Color8(185, 171, 136)
	var wood := Color8(107, 74, 46)
	var wood_dk := Color8(74, 46, 26)
	var gold := Color8(184, 146, 58)
	var gold_lt := Color8(224, 184, 74)
	var flesh := Color8(116, 34, 42)
	var flesh_dk := Color8(62, 14, 21)
	var blood := Color8(220, 52, 62)
	var ash := Color8(90, 74, 68)
	var ash_lt := Color8(122, 106, 96)

	# Carcass: a slumped, opened body on the floor (32 x 14, origin bottom centre).
	var img := _canvas(34, 14)
	_ellipse(img, 17, 9, 14, 5, Color8(138, 44, 52), flesh_dk)
	_line(img, Vector2(8, 7), Vector2(24, 6), blood)
	_line(img, Vector2(9, 8), Vector2(23, 8), Color8(154, 58, 58))
	for i in 4:
		_px(img, 11 + i * 4, 5, bone)
	_px(img, 27, 9, bone)
	_save(img, OUT + "carcass_body.png")

	# Reliquary: a gilded box on bone legs (36 x 38).
	img = _canvas(36, 38)
	_rect(img, Rect2i(6, 26, 3, 12), bone_sh)
	_rect(img, Rect2i(27, 26, 3, 12), bone_sh)
	_rect(img, Rect2i(3, 6, 30, 22), gold)
	_rect(img, Rect2i(3, 6, 30, 2), gold_lt)
	_rect(img, Rect2i(7, 10, 22, 14), Color8(42, 7, 12))
	_rect(img, Rect2i(3, 24, 30, 4), Color8(134, 104, 42))
	for x in [5, 30]:
		_rect(img, Rect2i(x, 2, 1, 4), gold_lt)
	_save(img, OUT + "key_reliquary_body.png")

	# The Matron's nest: shed skin and gnawed bone (66 x 18).
	img = _canvas(66, 18)
	_ellipse(img, 33, 13, 30, 6, Color8(138, 90, 74), Color8(98, 56, 46))
	for i in 6:
		_line(img, Vector2(9 + i * 9, 15), Vector2(13 + i * 9, 5 - (i % 2) * 3), bone)
		_px(img, 13 + i * 9, 5 - (i % 2) * 3, bone_sh)
	_ellipse(img, 33, 11, 12, 3, Color8(98, 56, 46))
	_save(img, OUT + "key_nest_body.png")

	# The valve key, floating (14 x 14): a ring of grown bone with a wet mouth.
	img = _canvas(14, 14)
	_ellipse(img, 7, 7, 6, 6, bone, bone_sh)
	_ellipse(img, 7, 7, 3, 3, Color8(74, 15, 22))
	_px(img, 7, 4, Color8(220, 52, 62))
	_px(img, 4, 7, Color8(220, 52, 62))
	_save(img, OUT + "valve_key_body.png")
	img.save_png(ProjectSettings.globalize_path(ITEMS_OUT + "valve_key_gut.png"))

	# Brazier: a bone bowl on a stem (22 x 20) and four flame frames (16 x 18).
	img = _canvas(22, 20)
	_ellipse(img, 11, 5, 10, 4, bone, bone_sh)
	_rect(img, Rect2i(9, 8, 4, 12), bone_sh)
	_rect(img, Rect2i(6, 18, 10, 2), bone_sh)
	_rect(img, Rect2i(5, 2, 12, 2), Color8(42, 24, 16))
	_save(img, OUT + "brazier_body.png")
	var flames := _canvas(16 * 4, 18)
	for f in 4:
		var sway: int = [0, 1, 0, -1][f]
		var tall: int = [16, 14, 17, 15][f]
		for y in tall:
			var t: float = float(y) / tall
			var half: float = (1.0 - t) * 6.5 * (0.7 + 0.3 * sin(t * PI))
			var cx: float = 8.0 + sway * t * 2.0
			for x in range(floori(cx - half), ceili(cx + half)):
				var inner: bool = absf(x + 0.5 - cx) < half * 0.45 and t < 0.7
				_px(flames, f * 16 + x, 17 - y, Color8(255, 242, 192) if inner else Color8(255, 176, 64))
	flames.save_png(ProjectSettings.globalize_path(OUT + "brazier_flame_glow.png"))

	# Latch: a bone lever in a socket (10 x 26).
	img = _canvas(10, 26)
	_rect(img, Rect2i(2, 20, 6, 6), ash)
	_rect(img, Rect2i(4, 3, 2, 18), bone_sh)
	_ellipse(img, 5, 3, 3, 3, bone)
	_save(img, OUT + "latch_body.png")

	# Grate: bone bars lashed with sinew, 128 x 10 (spans the gap).
	img = _canvas(130, 12)
	_rect(img, Rect2i(1, 1, 128, 3), bone_sh)
	_rect(img, Rect2i(1, 7, 128, 2), Color8(130, 118, 92))
	for i in 16:
		_rect(img, Rect2i(2 + i * 8, 1, 4, 10), bone if i % 2 == 0 else Color8(212, 202, 170))
		_px(img, 3 + i * 8, 5, Color8(154, 58, 58))
	_save(img, OUT + "grate_body.png")

	# Mural slab (62 x 60) and its four panels in light grey (tinted in game).
	img = _canvas(62, 60)
	_rect(img, Rect2i(1, 1, 60, 59), ash)
	_rect(img, Rect2i(3, 3, 56, 54), ash_lt)
	_rect(img, Rect2i(1, 56, 60, 4), Color8(46, 34, 32))
	_save(img, OUT + "mural_body.png")
	var panels := _canvas(62, 60)
	for i in 4:
		var r := Rect2i(5 + (i % 2) * 27, 5 + (i / 2) * 25, 25, 23)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				panels.set_pixel(x, y, Color(0.62, 0.62, 0.62))
		# A figure and a shape on each panel, lighter.
		var c := r.get_center()
		for y in range(-5, 3):
			for x in range(-2, 2):
				panels.set_pixel(c.x - 4 + i + x, c.y + y, Color(1, 1, 1))
		for x in range(-9, 9):
			panels.set_pixel(c.x + x, c.y + 6 - (x * i) / 9, Color(0.85, 0.85, 0.85))
	panels.save_png(ProjectSettings.globalize_path(OUT + "mural_cloth.png"))

	# Bone tablet (26 x 30).
	img = _canvas(26, 30)
	var shard := PackedVector2Array([Vector2(1, 29), Vector2(3, 7), Vector2(11, 1), Vector2(22, 5), Vector2(25, 29)])
	for y in 30:
		for x in 26:
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), shard):
				_px(img, x, y, bone if y < 22 else bone_sh)
	for i in 5:
		_line(img, Vector2(6, 10 + i * 4), Vector2(19 - (i % 2) * 3, 9 + i * 4), Color8(130, 118, 92))
	_save(img, OUT + "tablet_body.png")


func _paint_items() -> void:
	# Item icons, 16 x 16, standing on the bottom edge.
	var img := _canvas(16, 16)
	_ellipse(img, 8, 9, 6, 6, Color8(184, 212, 58), Color8(127, 154, 34))
	_rect(img, Rect2i(7, 1, 2, 3), Color8(122, 138, 58))
	_px(img, 6, 6, Color8(232, 245, 144))
	_save(img, ITEMS_OUT + "bile_bulb.png")

	img = _canvas(16, 16)
	_line(img, Vector2(4, 14), Vector2(11, 2), Color8(238, 228, 200))
	_line(img, Vector2(5, 14), Vector2(12, 2), Color8(238, 228, 200))
	_line(img, Vector2(6, 14), Vector2(12, 4), Color8(185, 171, 136))
	_save(img, ITEMS_OUT + "bone_shard.png")

	img = _canvas(16, 16)
	_ellipse(img, 8, 9, 6, 5, Color8(227, 154, 168), Color8(184, 111, 128))
	_line(img, Vector2(5, 8), Vector2(11, 8), Color8(184, 111, 128))
	_rect(img, Rect2i(7, 2, 2, 3), Color8(184, 111, 128))
	_save(img, ITEMS_OUT + "breath_sac.png")

	img = _canvas(16, 16)
	_ellipse(img, 8, 9, 5, 6, Color8(224, 184, 74), Color8(134, 104, 42))
	_ellipse(img, 8, 8, 2, 2, Color8(255, 74, 74))
	_save(img, ITEMS_OUT + "artifact.png")

	img = _canvas(16, 16)
	_ellipse(img, 8, 9, 5, 5, Color8(212, 202, 170), Color8(130, 118, 92))
	_save(img, ITEMS_OUT + "unknown.png")
