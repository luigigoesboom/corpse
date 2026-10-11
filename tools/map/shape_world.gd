extends SceneTree
## Turns the blocky painted world into caves (after week 41, at the
## developer's request): reads data/maps/_source/world_painted.png, writes
## data/maps/world.png.
##
##   Godot --headless --path . --script res://tools/map/shape_world.gd
##
## What it changes, and what it never touches:
## - Walls are eroded with noise (pockets up to 3 tiles deep), tall ceilings
##   get hollows and hanging lumps, single stray tiles are cleaned up.
## - Floors never change: every rock tile with air above stays rock, the one
##   under it too, and the air above it stays air (so walking, D-022 floor
##   faces and everything placed in world.tscn stay as they were).
## - Narrow places only get wider; nothing is filled where it could block.
## - A few alcoves are dug into thick walls at floor level, each written to
##   tools/map/alcoves.json (ichor clots go there).
## - Afterwards every open tile reachable before is checked to be reachable
##   still; if not, it says so and writes nothing.
## Seeded: the same source always gives the same world.

const SOURCE := "res://data/maps/_source/world_painted.png"
const TARGET := "res://data/maps/world.png"
const ALCOVES := "res://tools/map/alcoves.json"
const WORLD_SCENE := "res://scenes/world.tscn"

var w: int
var h: int
var rock: PackedByteArray  # 1 = rock
var keep: PackedByteArray  # 1 = must not change
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var macro := FastNoiseLite.new()


func _initialize() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	w = img.get_width()
	h = img.get_height()
	rock.resize(w * h)
	keep.resize(w * h)
	for y in h:
		for x in w:
			rock[y * w + x] = 1 if _is_rock(img.get_pixel(x, y)) else 0
	var before := _reachable(_start())
	noise.seed = 13
	noise.frequency = 0.11
	noise2.seed = 29
	noise2.frequency = 0.17
	macro.seed = 5
	macro.frequency = 0.035
	var caves := _new_caves()
	_protect_floors()
	_protect_placed()
	_erode_walls()
	_shape_ceilings()
	_clean()
	var alcoves: Array = caves + _dig_alcoves(2)
	var after := _reachable(_start())
	var lost := 0
	for i in before.size():
		if before[i] == 1 and after[i] == 0 and rock[i] == 0:  # Still open, but cut off.
			lost += 1
	for spot in alcoves:  # Every new cave and alcove must be reachable too.
		if after[(spot.ty - 1) * w + spot.tx] == 0:
			print("NOT WRITTEN: %s at (%d, %d) cannot be reached" % [spot.get("cave", "an alcove"), spot.tx, spot.ty])
			for y in range(spot.ty - 14, spot.ty + 30):
				var line := "%3d " % y
				for x in range(spot.tx - 12, spot.tx + 26):
					line += "#" if _at(x, y) else ("o" if after[y * w + x] else ".")
				print(line)
			quit(1)
			return
	if lost > 0:
		print("NOT WRITTEN: %d open tiles would become unreachable" % lost)
		quit(1)
		return
	# The world may be wider than the Gut's painting (the Lungs, painted by
	# tools/map/paint_lungs.gd): those columns are kept as they are.
	var old := Image.load_from_file(ProjectSettings.globalize_path(TARGET))
	var out := Image.create(maxi(w, old.get_width()), maxi(h, old.get_height()), false, Image.FORMAT_RGBA8)
	out.blit_rect(old, Rect2i(Vector2i.ZERO, old.get_size()), Vector2i.ZERO)
	for y in h:
		for x in w:
			out.set_pixel(x, y, Color.BLACK if rock[y * w + x] else Color(1, 1, 1, 0))
	out.save_png(ProjectSettings.globalize_path(TARGET))
	var file := FileAccess.open(ALCOVES, FileAccess.WRITE)
	file.store_string(JSON.stringify(alcoves, "\t"))
	file.close()
	var changed := 0
	for y in h:
		for x in w:
			if (rock[y * w + x] == 1) != _is_rock(img.get_pixel(x, y)):
				changed += 1
	print("world shaped: %d tiles changed, %d alcoves, everything still reachable" % [changed, alcoves.size()])
	quit()


func _is_rock(c: Color) -> bool:
	return c.a >= 0.5 and c.r + c.g + c.b < 1.5


func _at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 1
	return rock[y * w + x]


func _put(x: int, y: int, v: int) -> void:
	if x < 0 or y < 0 or x >= w or y >= h or keep[y * w + x]:
		return
	rock[y * w + x] = v


func _keep(x: int, y: int) -> void:
	if x >= 0 and y >= 0 and x < w and y < h:
		keep[y * w + x] = 1


## Floors: rock with air above stays rock (and the tile under it), and the
## three tiles of air above it stay air.
func _protect_floors() -> void:
	for y in range(1, h):
		for x in w:
			if _at(x, y) == 1 and _at(x, y - 1) == 0:
				_keep(x, y)
				_keep(x, y + 1)
				for k in range(1, 4):
					if _at(x, y - k) == 0:
						_keep(x, y - k)


## Everything placed in world.tscn: a box of untouched air above its floor.
func _protect_placed() -> void:
	var text := FileAccess.get_file_as_string(WORLD_SCENE)
	var re := RegEx.create_from_string('\\[node name="([^"]+)"[^\\]]*\\]\\n(?:[^\\[]*?)position = Vector2\\(([-\\d.]+), ([-\\d.]+)\\)(?:\\n(?:[^\\[]*?)width = ([\\d.]+))?')
	for m in re.search_all(text):
		var tx := int(float(m.get_string(2)) / 32.0)
		var ty := int(float(m.get_string(3)) / 32.0)
		var half := 3
		if m.get_string(4) != "":
			half = int(float(m.get_string(4)) / 64.0) + 3
		for x in range(tx - half, tx + half + 1):
			for y in range(ty - 6, ty + 2):
				_keep(x, y)


## Rock within 3 tiles of open space, beside it (not above or below), may
## be eaten away where the noise says so.
func _erode_walls() -> void:
	var carve: Array[Vector2i] = []
	for y in h:
		for x in w:
			if _at(x, y) == 0 or keep[y * w + x]:
				continue
			if x < 2 or y < 2 or x > w - 3 or y > h - 3:
				continue  # The world's edge stays solid.
			var depth := 99
			for d in range(1, 6):
				if _at(x - d, y) == 0 or _at(x + d, y) == 0 or _at(x, y + d) == 0:
					depth = d
					break
			if depth > 5:
				continue
			var big := (macro.get_noise_2d(x, y) + 1.0) * 0.5
			var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5 * 0.35 + big * 0.65
			if n > 0.38 + 0.1 * depth:
				carve.append(Vector2i(x, y))
	for p in carve:
		_put(p.x, p.y, 0)


## Ceilings of tall caves: hollows going up, lumps hanging down.
func _shape_ceilings() -> void:
	var changes: Array = []
	for y in range(1, h - 1):
		for x in w:
			# A ceiling tile: rock with air below.
			if _at(x, y) != 1 or _at(x, y + 1) != 0:
				continue
			var height := 0
			while height < 12 and _at(x, y + 1 + height) == 0:
				height += 1
			if height < 8:
				continue  # A low passage: leave it.
			var n := noise2.get_noise_2d(x, y)
			if n > 0.25:
				for k in range(0, 1 + int((n - 0.25) * 8.0)):
					changes.append([Vector2i(x, y - k), 0])  # A hollow going up.
			elif n < -0.3:
				for k in range(1, 1 + mini(3, int((-0.3 - n) * 10.0) + 1)):
					changes.append([Vector2i(x, y + k), 1])  # A lump hanging down.
	# Hollows first (they only open things up), then each lump on its own,
	# kept only if nothing that was reachable is cut off by it.
	var lumps := {}  # column -> [Vector2i]
	for c in changes:
		if c[1] == 0:
			_put(c[0].x, c[0].y, 0)
		else:
			lumps.get_or_add(c[0].x, []).append(c[0])
	var baseline := _count(_reachable(_start()))
	for column in lumps:
		var placed: Array[Vector2i] = []
		for p in lumps[column]:
			if not keep[p.y * w + p.x] and rock[p.y * w + p.x] == 0:
				rock[p.y * w + p.x] = 1
				placed.append(p)
		if placed.is_empty():
			continue
		if _count(_reachable(_start())) < baseline - placed.size():
			for p in placed:
				rock[p.y * w + p.x] = 0  # It would block a way: take it back.


## Stray single tiles: rock alone in the air goes, a one-tile hole in rock fills.
func _clean() -> void:
	for pass_i in 2:
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var n := _at(x - 1, y) + _at(x + 1, y) + _at(x, y - 1) + _at(x, y + 1)
				if _at(x, y) == 1 and n <= 1:
					_put(x, y, 0)
				elif _at(x, y) == 0 and n >= 4:
					_put(x, y, 1)


## Small rooms dug sideways into thick walls at floor level, 3 tall, 6 deep.
## Returns their floor points in world pixels: [{"x": , "y": }].
func _dig_alcoves(count: int) -> Array:
	var found: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for attempt in 4000:
		if found.size() >= count:
			break
		var x := rng.randi_range(12, w - 13)
		var y := rng.randi_range(4, h - 5)
		# Standing on a floor (rock at y, air above), a wall beside us.
		if _at(x, y) != 1 or _at(x, y - 1) != 0 or _at(x, y - 2) != 0 or _at(x, y - 3) != 0:
			continue
		var dir := 1 if _at(x + 1, y - 1) == 1 else (-1 if _at(x - 1, y - 1) == 1 else 0)
		if dir == 0:
			continue
		# The wall must be solid 9 deep and 5 tall, and not near anything placed.
		var solid := true
		for d in range(1, 10):
			for k in range(1, 6):
				if _at(x + dir * d, y - k) == 0 or keep[(y - k) * w + x + dir * d] and k <= 3:
					solid = false
		if not solid:
			continue
		var too_close := false
		for f in found:
			if absi(f.tx - x) < 30 and absi(f.ty - y) < 10:
				too_close = true
		if too_close:
			continue
		for d in range(1, 7):
			for k in range(1, 4):
				rock[(y - k) * w + x + dir * d] = 0
			rock[y * w + x + dir * d] = 1  # Its floor.
		var end := x + dir * 5
		found.append({"tx": end, "ty": y, "x": end * 32 + 16, "y": y * 32 + 6})
	return found


func _count(cells: PackedByteArray) -> int:
	var n := 0
	for c in cells:
		n += c
	return n


## Two caves dug into rock nobody used (after week 41): one above the
## Tender camp, up a shaft with ledges 3 tiles apart (a jump is ~3.7), and
## one hollowed out of the block east of the tall corridor, through a tunnel
## from its ledge at row 52. Each gets an ichor clot (returned like alcoves).
func _new_caves() -> Array:
	var out: Array = []
	# Above the camp: a shaft x 43..48 over the camp's top ledge (row 88),
	# through its ceiling (row 81), up to a cave floor at row 58. Ledges hug
	# the walls (x 47..48 first, then x 43..44) every 3 rows from row 85:
	# 3 tiles apart sideways (a jump covers ~3.4), the middle 2 free to rise
	# through without bonking the ledge above; the last (61) is beside the floor.
	_dig_rect(43, 58, 48, 81)
	for i in 10:  # Rows 85, 82 ... 58: the last one is flush with the cave floor.
		var row = 85 - i * 3
		if i % 2 == 0:
			_fill_rect(47, row, 48, row)
		else:
			_fill_rect(43, row, 44, row)
	_dig_blob(Vector2(31, 50), 14.0, 7.5, 58, 41)
	_dig_rect(30, 54, 48, 57)  # A walk from the shaft's top into the cave.
	out.append(_spot_on_floor(36, 48, "above the camp"))
	# The hollow: a tunnel from the corridor's ledge at (153, 52) to a cave.
	_dig_rect(154, 49, 165, 51)
	_dig_blob(Vector2(176, 46), 13.0, 6.5, 52, 77)
	_dig_rect(165, 48, 172, 51)  # The tunnel runs right into it.
	out.append(_spot_on_floor(182, 44, "the hollow"))
	return out


## Where something dropped at (x, from_y) would land: the first rock below.
func _spot_on_floor(x: int, from_y: int, label: String) -> Dictionary:
	var y := from_y
	while y < h - 1 and _at(x, y) == 0:
		y += 1
	return {"tx": x, "ty": y, "x": x * 32 + 16, "y": y * 32 + 6, "cave": label}


func _dig_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			rock[y * w + x] = 0


func _fill_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			rock[y * w + x] = 1


## A cave of noisy ellipse shape whose floor is flat at row `floor_row`
## (everything below it inside the blob stays rock, except holes already dug).
func _dig_blob(centre: Vector2, rx: float, ry: float, floor_row: int, seed_value: int) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.2
	for y in range(int(centre.y - ry - 3), floor_row):
		for x in range(int(centre.x - rx - 3), int(centre.x + rx + 4)):
			var d := Vector2((x + 0.5 - centre.x) / rx, (y + 0.5 - centre.y) / ry).length()
			if d < 1.0 + n.get_noise_2d(x, y) * 0.25:
				rock[y * w + x] = 0


func _start() -> Vector2i:
	return Vector2i(14, 98)


## Open tiles reachable from `from` (4-neighbour flood fill).
func _reachable(from: Vector2i) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = [from]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		var i := p.y * w + p.x
		if seen[i] or rock[i]:
			continue
		seen[i] = 1
		stack.append_array([p + Vector2i(1, 0), p - Vector2i(1, 0), p + Vector2i(0, 1), p - Vector2i(0, 1)])
	return seen
