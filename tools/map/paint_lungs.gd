extends SceneTree
## Paints the Lungs (week 47) into the world: the second region, east of the
## Gut. The Lungs are drawn by this script instead of in Krita (D-028: the
## art is made by code), so this file is their painting; run it after
## changing it:
##
##   Godot --headless --path . --script res://tools/map/paint_lungs.gd
##
## It widens data/maps/world.png to WIDTH (the Gut's columns stay exactly as
## they are), carves the Lungs into columns 256 and up, opens the Great
## Bronchus through the east cavern's wall, and writes the matching columns
## of tiles.png (kinds of rock), regions.png and territory.png. Membranes
## (one-way, springy) are painted in MEMBRANE color. The same mouth of the
## bronchus is painted into data/maps/_source/world_painted.png, so
## tools/map/shape_world.gd keeps it.
##
## Places (tile coordinates; px = tile * 32):
##   the Great Bronchus  rows 66-74, from the east cavern's row-75 ledge (x 246) to x 303
##   the Bellows         a chamber x 303-367, rows 13-104, climbed by membranes
##   the Alveolar Hives  honeycomb of small chambers, x 374-440, rows 14-60
##   the Lower Lobe      a long hall, floor at row 106, x 372-500
##   the Trachea         a ledged shaft at x 476-481 up to the High Aerie (rows 4-12)
## Afterwards it checks every place can be walked to from the Gut with the
## host's jump (JUMP_UP tiles up, JUMP_ACROSS across) and writes nothing if not.

const WIDTH := 512
const HEIGHT := 128
const GUT_WIDTH := 256
const WORLD := "res://data/maps/world.png"
const SOURCE := "res://data/maps/_source/world_painted.png"
const KINDS := "res://data/maps/tiles.png"
const REGIONS := "res://data/maps/regions.png"
const TERRITORY := "res://data/maps/territory.png"
const PLACES := "res://tools/map/lungs.json"
## Magenta: a membrane (WorldMap.is_membrane_color).
const MEMBRANE := Color8(255, 0, 255)
const ROCK := Color.BLACK
const AIR := Color(1, 1, 1, 0)
## How far the host's jump reaches, in tiles (jump height 120 px = 3.75).
const JUMP_UP := 3
const JUMP_ACROSS := 4

enum { R, A, M }  # Rock, air, membrane.

var cells := PackedByteArray()  # WIDTH x HEIGHT, R / A / M
var cartilage := PackedByteArray()  # 1 = cartilage rock (rings), else alveolus
var places := {}  # name -> [tile x, tile y] of a floor spot


func _initialize() -> void:
	var world := Image.load_from_file(ProjectSettings.globalize_path(WORLD))
	cells.resize(WIDTH * HEIGHT)
	cartilage.resize(WIDTH * HEIGHT)
	for y in HEIGHT:
		for x in WIDTH:
			var open := x < world.get_width() and y < world.get_height() and not WorldMap.is_rock_color(world.get_pixel(x, y))
			cells[_i(x, y)] = A if open and x < GUT_WIDTH else R
	_bronchus()
	_bellows()
	_hives()
	_lower_lobe()
	_trachea()
	_links()
	var missing := _check()
	if not missing.is_empty():
		print("NOT WRITTEN: these places cannot be reached from the Gut: ", missing)
		quit(1)
		return
	_write(world)
	quit()


func _i(x: int, y: int) -> int:
	return y * WIDTH + x


func _cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT:
		return R
	return cells[_i(x, y)]


func _put(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < WIDTH and y < HEIGHT:
		cells[_i(x, y)] = v


func _dig_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(x, y, A)


func _fill_rect(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(x, y, R)


## An ellipse of air with a noisy edge; nothing below `floor_row` is dug.
func _dig_blob(centre: Vector2, rx: float, ry: float, floor_row: int, seed_value: int, wobble := 0.18) -> void:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.15
	for y in range(int(centre.y - ry - 4), mini(floor_row, int(centre.y + ry + 4))):
		for x in range(int(centre.x - rx - 4), int(centre.x + rx + 5)):
			var d := Vector2((x + 0.5 - centre.x) / rx, (y + 0.5 - centre.y) / ry).length()
			if d < 1.0 + n.get_noise_2d(x, y) * wobble:
				_put(x, y, A)


func _membrane(x0: int, x1: int, row: int) -> void:
	for x in range(x0, x1 + 1):
		if _cell(x, row) == A:
			_put(x, row, M)


func _ring_cartilage(x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(maxi(0, y0), mini(HEIGHT, y1 + 1)):
		for x in range(maxi(GUT_WIDTH, x0), mini(WIDTH, x1 + 1)):
			cartilage[_i(x, y)] = 1


# --- The places ------------------------------------------------------------------

## The Great Bronchus: a ringed tube from the east cavern's row-75 ledge
## into the side of the Bellows. Cartilage rings make low humps on the floor
## and lips on the ceiling every 9 tiles.
func _bronchus() -> void:
	_dig_rect(246, 66, 303, 74)
	_fill_rect(244, 75, 303, 80)  # The ledge runs on into the bronchus' floor.
	for x in range(258, 300, 9):
		_put(x, 74, R)  # A hump to hop.
		_put(x, 66, R)
		_put(x + 1, 66, R)
	_ring_cartilage(250, 60, 306, 80)
	places["the Great Bronchus"] = [262, 74]


## The Bellows: the great chamber. A flat floor at row 104 (rock at 105),
## and membranes in two staggered columns climbing to the top, where a
## bronchiole leads east to the Hives.
func _bellows() -> void:
	_dig_blob(Vector2(335, 58), 33, 47, 105, 71, 0.12)
	_dig_rect(306, 93, 366, 104)  # A broad flat floor instead of a bowl.
	_fill_rect(300, 105, 372, 112)
	# The membrane ladder: every 3 rows, alternating left and right of the
	# middle, overlapping so each is a short hop from the last.
	var row := 102  # The first one a jump from the floor (rock at 105).
	var k := 0
	while row > 17:
		var left := 318 + int(sin(k * 0.7) * 4.0)
		if k % 2 == 0:
			_membrane(left, left + 9, row)
		else:
			_membrane(left + 11, left + 20, row)
		row -= 3
		k += 1
	# Wide membranes across the middle, to land on when falling.
	_membrane(300, 330, 75)  # A balcony: the bronchus' floor goes on as a membrane.
	_membrane(338, 364, 50)
	places["the Bellows floor"] = [335, 104]
	places["the Bellows heights"] = [335, 19]


## The Alveolar Hives: round chambers on a hex grid, joined by short tubes.
func _hives() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	var centres := []
	for j in 5:
		for i in 6:
			var c := Vector2(380 + i * 11 + (5.5 if j % 2 == 1 else 0.0), 20 + j * 9)
			if c.x > 438:
				continue
			centres.append(c)
	for c in centres:
		_dig_blob(c, rng.randf_range(4.0, 5.5), rng.randf_range(3.5, 4.5), int(c.y) + 5, rng.randi(), 0.1)
	# Tubes between neighbours: all to the right, most downward.
	for a: Vector2 in centres:
		for b: Vector2 in centres:
			var d := b - a
			if d.length() < 13.0 and (d.x > 0.1 or d.y > 0.1) and rng.randf() < 0.75:
				for t in 12:
					var p := a.lerp(b, t / 11.0)
					_dig_rect(int(p.x) - 1, int(p.y) - 1, int(p.x) + 1, int(p.y) + 1)
	# A membrane across the bottom of every other chamber, so the round
	# floors have something flat.
	for idx in range(0, centres.size(), 2):
		var c: Vector2 = centres[idx]
		_membrane(int(c.x) - 3, int(c.x) + 3, int(c.y) + 2)
	var middle: Vector2 = centres[7]
	places["the Hives"] = [int(middle.x), int(middle.y) + 1]


## The Lower Lobe: a long low hall with a flat floor at row 106, where a
## people could live (week 50), and a ruin at its east end.
func _lower_lobe() -> void:
	_dig_rect(372, 92, 500, 105)
	_dig_blob(Vector2(400, 92), 20, 12, 106, 3, 0.2)
	_dig_blob(Vector2(445, 90), 26, 14, 106, 5, 0.2)
	_dig_blob(Vector2(485, 93), 16, 10, 106, 9, 0.2)
	_fill_rect(368, 106, 504, 112)
	# Membrane shelves along the hall.
	_membrane(380, 392, 101)
	_membrane(430, 444, 100)
	_membrane(455, 468, 97)
	places["the Lower Lobe"] = [420, 105]
	places["the lobe's east end"] = [490, 105]


## The Trachea: a shaft from the Lower Lobe's ceiling to the High Aerie,
## with ledges every 3 rows on alternate sides (like the shaft above the
## Tender camp, tests/test_map.gd).
func _trachea() -> void:
	_dig_rect(476, 12, 481, 92)
	var row := 89
	var i := 0
	while row > 13:
		if i % 2 == 0:
			_fill_rect(480, row, 481, row)
		else:
			_fill_rect(476, row, 477, row)
		row -= 3
		i += 1
	# From the Lower Lobe's floor up to the first ledge: membranes.
	for k in 5:
		var step := 103 - k * 3
		if k % 2 == 0:
			_membrane(469, 478, step)
		else:
			_membrane(474, 481, step)
	_dig_blob(Vector2(472, 8), 18, 5, 13, 21, 0.15)
	_fill_rect(452, 13, 475, 16)
	_fill_rect(482, 13, 492, 16)
	_ring_cartilage(470, 10, 488, 95)
	places["the High Aerie"] = [462, 12]


## Ways between the places.
func _links() -> void:
	# The Bellows' top to the Hives' west side: a bronchiole.
	_dig_rect(342, 17, 382, 21)
	_membrane(326, 372, 22)  # A bridge from the top of the ladder.
	_ring_cartilage(358, 13, 384, 25)
	# The bronchus' mouth, cut clean through the Bellows' wall.
	_dig_rect(296, 66, 312, 74)
	# The Bellows' floor to the Lower Lobe.
	_dig_rect(362, 99, 375, 104)
	# The Hives drop down into the Lower Lobe.
	_dig_rect(424, 55, 427, 92)
	# The Hives' east side to the Trachea, halfway up (a second way down).
	_dig_rect(436, 47, 475, 50)  # Up to the shaft's wall; its ledges stay.


# --- Can every place be reached? ------------------------------------------------

## A tile the host can stand on: open, with something solid or a membrane
## underneath and two open tiles above its feet.
func _standable(x: int, y: int) -> bool:
	return _cell(x, y) != R and _cell(x, y - 1) != R and _cell(x, y + 1) != A


## Places no one can get to by walking, jumping and falling from the Gut
## (the east cavern's row-75 ledge).
func _check() -> Array:
	var reached := {}
	var start := Vector2i(240, 74)
	var queue: Array[Vector2i] = [start]
	reached[start] = true
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		for q in _moves(p):
			if not reached.has(q):
				reached[q] = true
				queue.append(q)
	var missing := []
	for name in places:
		var spot := Vector2i(places[name][0], places[name][1])
		var ok := false
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				ok = ok or reached.has(spot + Vector2i(dx, dy))
		if not ok:
			missing.append(name)
	print("reachable stand spots: %d" % reached.size())
	if not missing.is_empty() and "--show" in OS.get_cmdline_user_args():
		for y in HEIGHT:  # # rock, - membrane, o reached, . air
			var line := "%3d " % y
			for x in range(GUT_WIDTH - 16, WIDTH):
				line += "o" if reached.has(Vector2i(x, y)) else ["#", ".", "-"][_cell(x, y)]
			print(line)
	return missing


## Where the host can go from a stand spot: walk a step, jump up to JUMP_UP
## rows and JUMP_ACROSS columns (if the air above is clear), or fall.
func _moves(p: Vector2i) -> Array:
	var out := []
	for dx in [-1, 1]:
		var q := p + Vector2i(dx, 0)
		if _cell(q.x, q.y) != R and _cell(q.x, q.y - 1) != R:
			if _standable(q.x, q.y):
				out.append(q)
			else:
				var y := q.y  # Off the edge: fall to whatever is below.
				while y < HEIGHT - 1 and not _standable(q.x, y):
					if _cell(q.x, y + 1) == R and not _standable(q.x, y):
						break
					y += 1
				if _standable(q.x, y):
					out.append(Vector2i(q.x, y))
	# Jumps: rise first, then drift across, landing on any stand spot up
	# to JUMP_UP rows higher, or lower (then reaching a little further).
	var head_room := 0
	while head_room < JUMP_UP and _cell(p.x, p.y - 2 - head_room) != R:
		head_room += 1
	for dy in range(-head_room, 7):
		var across := JUMP_ACROSS + (2 if dy > 0 else 0)
		var apex := p.y - 1 - maxi(head_room, -dy)
		for dx in range(-across, across + 1):
			var q := Vector2i(p.x + dx, p.y + dy)
			if dx == 0 and dy == 0:
				continue
			if _standable(q.x, q.y) and _clear(p.x, q.x, apex) and _clear(p.x, q.x, mini(p.y, q.y) - 1):
				out.append(q)
	# Dropping through a membrane.
	if _cell(p.x, p.y + 1) == M:
		var y := p.y + 1
		while y < HEIGHT - 1 and not _standable(p.x, y):
			y += 1
		if _standable(p.x, y):
			out.append(Vector2i(p.x, y))
	return out


## No rock in a row between two columns (the head's path across a jump).
func _clear(x0: int, x1: int, row: int) -> bool:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		if _cell(x, row) == R:
			return false
	return true


# --- Writing ----------------------------------------------------------------------

func _write(old_world: Image) -> void:
	var world := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in HEIGHT:
		for x in WIDTH:
			if x < GUT_WIDTH and x < 246 and x < old_world.get_width():
				world.set_pixel(x, y, old_world.get_pixel(x, y))  # The Gut, untouched.
			else:
				world.set_pixel(x, y, [ROCK, AIR, MEMBRANE][_cell(x, y)])
	world.save_png(ProjectSettings.globalize_path(WORLD))
	# The bronchus' mouth in the Gut's own painting, so shape_world keeps it.
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	for y in range(66, 75):
		for x in range(246, mini(GUT_WIDTH, source.get_width())):
			source.set_pixel(x, y, world.get_pixel(x, y))
	source.save_png(ProjectSettings.globalize_path(SOURCE))
	# Kinds: the Lungs are alveolus, cartilage around the airways.
	_widen(KINDS, func(x, y): return RockKinds.INFO[&"cartilage" if cartilage[_i(x, y)] else &"alveolus"].paint)
	_widen(REGIONS, func(_x, _y): return Regions.INFO[Regions.LUNGS].paint)
	_widen(TERRITORY, func(_x, _y): return AIR)
	var file := FileAccess.open(PLACES, FileAccess.WRITE)
	file.store_string(JSON.stringify(places, "\t"))
	file.close()
	var open := 0
	var membranes := 0
	for y in HEIGHT:
		for x in range(GUT_WIDTH, WIDTH):
			open += 1 if _cell(x, y) == A else 0
			membranes += 1 if _cell(x, y) == M else 0
	print("the Lungs painted: %d open tiles, %d membrane tiles, %d places" % [open, membranes, places.size()])


## Copies a WIDTH-wide painting: the Gut's columns as they were (or empty),
## the Lungs' columns from `paint(x, y)`.
func _widen(path: String, paint: Callable) -> void:
	var full := ProjectSettings.globalize_path(path)
	var old: Image = Image.load_from_file(full) if FileAccess.file_exists(path) else null
	var img := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	for y in HEIGHT:
		for x in WIDTH:
			if x < GUT_WIDTH:
				if old and x < old.get_width() and y < old.get_height():
					img.set_pixel(x, y, old.get_pixel(x, y))
			else:
				img.set_pixel(x, y, paint.call(x, y))
	img.save_png(full)
