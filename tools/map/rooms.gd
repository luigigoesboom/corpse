extends SceneTree
## Breaks the Gut's big box halls into smaller rooms and makes sure every
## place in the world can be reached with the host's own jump (after the
## Lungs, at the developer's request: "too flat boxes", "some of it isn't
## even traversable"). Run it last, after shape_world.gd and paint_lungs.gd:
##
##   Godot --headless --path . --script res://tools/map/rooms.gd [-- --show] [--preview] [--refresh]
##
## Reads data/maps/_source/world_shaped.png (the map as shape_world.gd and
## paint_lungs.gd left it) and writes data/maps/world.png. --refresh first
## copies world.png to world_shaped.png: do that after running either of
## those tools again (they write world.png). --preview writes
## user://rooms_preview.png instead of world.png; --show draws what can be
## reached to user://rooms_reach.png. Seeded: the same map in gives the
## same map out. What it does:
## 1. In each hall of HALLS: takes out the thin floating ledges nothing is
##    placed on, lays new floors across the hall every few rows (thick, with
##    lumpy undersides and gaps to climb through) and hangs curtains of rock
##    from the ceilings down to a few rows above the floor, so a hall becomes
##    a stack of rooms.
## 2. Gives every floating ledge left an underside (it hangs, it does not end
##    in a flat line).
## 3. Puts up the LADDERS (shelf columns) where storeys alone do not connect,
##    then checks with MapReach that everything placed can be reached from
##    the player's spawn by walking, jumping and falling, and left again.
## Never touches: things placed in world.tscn (a box of air above them, the
## floor under them), the air just above any floor kept, KEEP_CLEAR.
## Writes nothing if anything placed in world.tscn is still out of reach.

const WORLD := "res://data/maps/world.png"
const SHAPED := "res://data/maps/_source/world_shaped.png"
const SCENE := "res://scenes/world.tscn"
const PARENTS := ["Entities", "SpawnPoints"]

## Halls to turn into rooms: [x0, y0, x1, y1] (tiles, inclusive), the rows a
## new floor may be laid in, and how far apart floors are (rows).
const HALLS := [
	{"name": "the central chamber", "rect": [70, 46, 141, 99], "floors": [52, 90], "spacing": 9},
	{"name": "the upper caves", "rect": [143, 15, 196, 66], "floors": [20, 57], "spacing": 9},
	{"name": "the east cavern", "rect": [196, 15, 250, 107], "floors": [21, 101], "spacing": 9},
]
## Never put rock here: [x0, y0, x1, y1]. The Matron's arena and the deep
## tunnel, the way into the Lungs, the Bellows (its membrane ladder and the
## updraft), the Trachea.
const KEEP_CLEAR := [
	[212, 111, 252, 120],
	[226, 64, 312, 75],
	[298, 10, 372, 106],
	[470, 4, 486, 104],
]
## Ladders: [name, shaft columns x0..x1 (5-6 wide: 2-wide shelves 1-2
## apart), from the walking row `bottom` up to `top`].
const LADDERS := [
	{"name": "up to the corridor", "x0": 150, "x1": 154, "bottom": 66, "top": 27},
	{"name": "out of the deep", "x0": 128, "x1": 133, "bottom": 120, "top": 101},
	{"name": "into the east cavern", "x0": 197, "x1": 202, "bottom": 120, "top": 102},
	{"name": "to the fungus ledge", "x0": 113, "x1": 117, "bottom": 99, "top": 93, "first": "right"},
]
## Membranes added as steps (the Lungs' way): [x0, x1, row]. The Lower
## Lobe's shelves hung 5-6 rows over its floor; the Hives' low pocket had no
## way back up.
const MEMBRANE_STEPS := [
	[386, 390, 104],
	[436, 440, 103],
	[431, 433, 55],
	[431, 434, 52],
]
## Rock dug out first: [x0, y0, x1, y1]. The shaft from the upper caves to
## the corridor was 4 wide, too narrow to climb; now 7.
const DIG := [
	[154, 27, 156, 47],
	[150, 48, 156, 62],  # And on down to the ledge from the chamber.
	[127, 101, 135, 110],  # The hole down into the deep, wide enough to climb back.
]

const S := 9  # Default floor spacing.

var m: MapReach
var keep := PackedByteArray()  # 1 = never change this cell
var keep_placed := PackedByteArray()  # 1 = around something placed
var rng := RandomNumberGenerator.new()
var noise := FastNoiseLite.new()
var spawn: Vector2i
var things: Array
var log_lines: Array[String] = []


func _initialize() -> void:
	rng.seed = 4517
	noise.seed = 88
	noise.frequency = 0.21
	var args := OS.get_cmdline_user_args()
	if "--refresh" in args or not FileAccess.file_exists(SHAPED):
		Image.load_from_file(ProjectSettings.globalize_path(WORLD)).save_png(ProjectSettings.globalize_path(SHAPED))
		print("world_shaped.png taken from world.png")
	m = MapReach.from_image(Image.load_from_file(ProjectSettings.globalize_path(SHAPED)))
	keep.resize(m.w * m.h)
	keep_placed.resize(m.w * m.h)
	things = MapReach.placed(SCENE, PARENTS)
	var spawn_px: Vector2 = MapReach.placed(SCENE, ["."]).filter(func(p): return p[0] == "PlayerSpawn")[0][2]
	spawn = Vector2i(int(spawn_px.x / 32.0), int(spawn_px.y / 32.0))
	var before := m.cells.duplicate()
	for r in DIG:
		for y in range(r[1], r[3] + 1):
			for x in range(r[0], r[2] + 1):
				m.cells[_i(x, y)] = MapReach.A
	_protect_placed()
	for hall in HALLS:
		_clear_ledges(hall)
	_protect_floors()
	for hall in HALLS:
		_lay_floors(hall)
		_hang_curtains(hall)
	_undersides()
	_clean()
	var missing := _connect()
	var changed := 0
	for i in before.size():
		changed += 1 if before[i] != m.cells[i] else 0
	for line in log_lines:
		print(line)
	if not missing.is_empty():
		if "--preview" in OS.get_cmdline_user_args():
			_write()
		print("NOT WRITTEN: cannot reach ", missing)
		quit(1)
		return
	_write()
	print("rooms made: %d tiles changed, everything placed can be reached" % changed)
	quit()


func _i(x: int, y: int) -> int:
	return y * m.w + x


func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < m.w and y < m.h


func _keep(x: int, y: int) -> void:
	if _inside(x, y):
		keep[_i(x, y)] = 1


func _in_rects(x: int, y: int, rects: Array) -> bool:
	for r in rects:
		if x >= r[0] and x <= r[2] and y >= r[1] and y <= r[3]:
			return true
	return false


## Rock may go here: air now, not kept, not in KEEP_CLEAR.
func _free(x: int, y: int) -> bool:
	return _inside(x, y) and m.cell(x, y) == MapReach.A and not keep[_i(x, y)] and not _in_rects(x, y, KEEP_CLEAR)


func _rock(x: int, y: int) -> void:
	if _free(x, y):
		m.cells[_i(x, y)] = MapReach.R


## Everything placed: its floor stays, and a box of air above it.
func _protect_placed() -> void:
	for t in things:
		var tx := int(t[2].x / 32.0)
		var ty := int(t[2].y / 32.0)
		var half := 2 + int(t[3] / 64.0)
		for x in range(tx - half, tx + half + 1):
			for y in range(ty - 5, ty + 2):
				_keep(x, y)
				if _inside(x, y) and y >= ty - 2:  # Steps may pass above its head.
					keep_placed[_i(x, y)] = 1


## The three rows of air above every floor stay air, and the floor stays.
func _protect_floors() -> void:
	for y in range(1, m.h):
		for x in m.w:
			if m.standable(x, y):
				for k in 3:
					_keep(x, y - k)
				_keep(x, y + 1)


# --- 1. Halls into rooms -----------------------------------------------------------

## Thin floating ledges (rock islands of a few rows, not part of a wall) with
## nothing placed on them go: new floors and steps replace them.
func _clear_ledges(hall: Dictionary) -> void:
	var r: Array = hall.rect
	var seen := {}
	var removed := 0
	for y in range(r[1], r[3] + 1):
		for x in range(r[0], r[2] + 1):
			var p := Vector2i(x, y)
			if seen.has(p) or m.cell(x, y) != MapReach.R:
				continue
			var island := _island(p, r, seen)
			if island.is_empty() or island.size() > 60:
				continue
			var kept := false
			for c in island:
				kept = kept or keep[_i(c.x, c.y)] == 1
			if kept:
				continue
			for c in island:
				m.cells[_i(c.x, c.y)] = MapReach.A
			removed += 1
	log_lines.append("%s: %d old ledges taken out" % [hall.name, removed])


## The rock connected to `p`, if it stays inside the hall and is small;
## [] if it touches the hall's edge (part of a wall).
func _island(p: Vector2i, r: Array, seen: Dictionary) -> Array:
	var out := []
	var stack: Array[Vector2i] = [p]
	var wall := false
	while not stack.is_empty():
		var q: Vector2i = stack.pop_back()
		if not _inside(q.x, q.y) or seen.has(q) or m.cell(q.x, q.y) != MapReach.R:
			continue
		seen[q] = true
		if q.x <= r[0] or q.x >= r[2] or q.y <= r[1] or q.y >= r[3] or out.size() > 60:
			wall = true
		out.append(q)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			stack.append(q + d)
	return [] if wall else out


## New floors across the hall every `spacing` rows (counted up from its
## bottom floor), in pieces 9-20 wide with gaps of 4-6 to climb through. A
## floor is two rows thick, rounded at the ends, with a lumpy underside.
func _lay_floors(hall: Dictionary) -> void:
	var r: Array = hall.rect
	var spacing: int = hall.get("spacing", S)
	var count := 0
	var row: int = hall.floors[1]
	var shift := rng.randi_range(0, 8)
	while row >= hall.floors[0]:
		# The open runs along this row, wall to wall.
		var x: int = r[0]
		while x <= r[2]:
			if not _free(x, row + 1):
				x += 1
				continue
			var x_end := x
			while x_end + 1 <= r[2] and _free(x_end + 1, row + 1):
				x_end += 1
			count += _pieces(x, x_end, row, shift)
			x = x_end + 1
		row -= spacing  # Exactly: the gap ladders count on it.
		shift += 7
	log_lines.append("%s: %d pieces of floor laid" % [hall.name, count])


## A storey's floor along an open run x0..x1 whose walking row is `row`
## (rock goes in row + 1 and row + 2): wall to wall, but for a gap of 4 to
## climb through, in the left or the right third (alternating up the hall),
## and a second one in runs over 34 wide. In each gap two little shelves
## make the climb: one 3 rows up by one side, one 6 rows up by the other,
## and from there the storey is a hop up and sideways. Returns how many
## pieces went down.
func _pieces(x0: int, x1: int, row: int, shift: int) -> int:
	if x1 - x0 < 12:
		return 0
	var gaps := []
	var third := (x1 - x0) / 3
	if shift % 2 == 0:
		gaps.append(x0 + 2 + rng.randi_range(0, maxi(0, third - 8)))
	else:
		gaps.append(x1 - 5 - rng.randi_range(0, maxi(0, third - 8)))
	if x1 - x0 > 34:
		var other: int = x0 + x1 - gaps[0] - 4
		if absi(other - gaps[0]) > 12:
			gaps.append(other)
	gaps.sort()
	var placed := 0
	var x := x0
	for g in gaps + [x1 + 1]:
		var end: int = g - 1
		if end - x >= 3 and _room_above(x, end, row):
			_slab(x, end, row)
			placed += 1
		x = g + 4
	for g in gaps:
		_gap_ladder(g, row, shift)
	return placed


## The shelves in a gap whose columns are g..g+3, under a storey walking at
## `row`: walking rows row + 6 and row + 3, on alternate sides. The upper
## one is a hop from the storey on either side of the gap.
func _gap_ladder(g: int, row: int, shift: int) -> void:
	var low_left := shift % 4 < 2
	var low_x := g if low_left else g + 2
	var high_x := g + 2 if low_left else g
	for x in range(low_x, low_x + 2):
		_shelf_cell(x, row + 7)
	for x in range(high_x, high_x + 2):
		_shelf_cell(x, row + 4)


## Rock for a shelf: anywhere in the air except around placed things, in
## KEEP_CLEAR, or where someone stands or has their head.
func _shelf_cell(x: int, y: int) -> void:
	if not _inside(x, y) or m.cell(x, y) != MapReach.A or keep_placed[_i(x, y)] or _in_rects(x, y, KEEP_CLEAR):
		return
	if m.standable(x, y) or m.standable(x, y + 1):
		return
	m.cells[_i(x, y)] = MapReach.R


## Enough air above a new floor: 4 rows over it are free (not inside a kept
## box or another floor's head room).
func _room_above(x0: int, x1: int, row: int) -> bool:
	for x in range(x0, x1 + 1):
		for k in range(0, 4):
			if m.cell(x, row - k) != MapReach.A:
				return false
		if not _free(x, row + 1):
			return false
	return true


## One floor piece: the top row full, the second row rounded at the ends,
## then lumps hanging from the middle (0-3 rows, blobby).
func _slab(x0: int, x1: int, row: int) -> void:
	for x in range(x0, x1 + 1):
		_rock(x, row + 1)
	for x in range(x0 + 1, x1):
		_rock(x, row + 2)
	_lumps(x0 + 2, x1 - 2, row + 3, 2)


## Lumps hanging under a stretch of rock: depth from noise, shrinking toward
## the ends, never into kept air.
func _lumps(x0: int, x1: int, top: int, deepest: int) -> void:
	var length := x1 - x0 + 1
	if length < 1:
		return
	for x in range(x0, x1 + 1):
		var t := float(x - x0 + 1) / float(length + 1)
		var edge := minf(t, 1.0 - t) * 2.0  # 0 at the ends, 1 in the middle
		var n := (noise.get_noise_2d(x * 1.0, top * 1.0) + 1.0) * 0.5
		var depth := int(round(deepest * edge * (0.35 + n)))
		for k in depth:
			if not _free(x, top + k) or m.cell(x, top + k - 1) != MapReach.R:
				break
			_rock(x, top + k)


## Curtains of rock hanging from a ceiling to 3 rows above the floor below,
## every 14-24 columns: rooms side by side, walked under, not through.
func _hang_curtains(hall: Dictionary) -> void:
	var r: Array = hall.rect
	var count := 0
	var x: int = r[0] + rng.randi_range(8, 14)
	while x < r[2] - 6:
		var width := rng.randi_range(2, 3)
		# Every ceiling in this column of the hall: rock with air below.
		var y: int = r[1]
		while y < r[3]:
			if m.cell(x, y) == MapReach.R and m.cell(x, y + 1) == MapReach.A:
				var floor_row := y + 1
				while floor_row < m.h - 1 and m.cell(x, floor_row + 1) == MapReach.A:
					floor_row += 1
				var bottom := floor_row - 3  # Keep 3 rows to walk under.
				if bottom - y >= 3 and floor_row - y < 16:
					for cx in range(x, x + width):
						var edge := cx == x or cx == x + width - 1
						var reach_down := bottom - (1 if edge and width > 2 else 0)  # Rounded sides.
						for cy in range(y + 1, reach_down + 1):
							if m.cell(cx, cy - 1) != MapReach.R or not _free(cx, cy):
								break
							_rock(cx, cy)
					count += 1
				y = floor_row
			y += 1
		x += rng.randi_range(14, 24)
	log_lines.append("%s: %d curtains hung" % [hall.name, count])


# --- 2. Undersides -----------------------------------------------------------------

## Every floating ledge (rock with air above and below, at most 2 rows thick)
## gets a lumpy underside.
func _undersides() -> void:
	var count := 0
	for y in range(1, m.h - 3):
		var x := 0
		while x < m.w:
			# A run of rock whose underside is air.
			if m.cell(x, y) == MapReach.R and m.cell(x, y + 1) == MapReach.A and m.cell(x, y - 2) == MapReach.A:
				var x_end := x
				while x_end + 1 < m.w and m.cell(x_end + 1, y) == MapReach.R and m.cell(x_end + 1, y + 1) == MapReach.A:
					x_end += 1
				if x_end - x >= 3:
					_lumps(x + 1, x_end - 1, y + 1, 2)
					count += 1
				x = x_end + 1
			else:
				x += 1
	log_lines.append("undersides: %d ledges" % count)


## Stray tiles: rock alone in the air goes (unless kept).
func _clean() -> void:
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if m.cell(x, y) != MapReach.R or keep[_i(x, y)]:
				continue
			var n := 0
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				n += 1 if m.cell(x + d.x, y + d.y) == MapReach.R else 0
			if n == 0:
				m.cells[_i(x, y)] = MapReach.A


# --- 3. Ladders, and the check ------------------------------------------------------

## Shelf columns where the halls alone do not connect, like the shaft above
## the Tender camp (tests/test_map.gd): 2-wide shelves every 3 rows on
## alternate sides of a shaft x0..x1, from just above `bottom` (a walking
## row) up to `top`.
func _ladders() -> void:
	for l in LADDERS:
		var row: int = l.bottom - 3
		var left: bool = l.get("first", "left") == "left"
		var count := 0
		while row >= l.top:
			var x: int = l.x0 if left else l.x1 - 1
			for cx in range(x, x + 2):
				_shelf_cell(cx, row + 1)
			left = not left
			row -= 3
			count += 1
		log_lines.append("ladder %s: %d shelves" % [l.name, count])
	for step in MEMBRANE_STEPS:
		for x in range(step[0], step[1] + 1):
			if m.cell(x, step[2]) == MapReach.A:
				m.cells[_i(x, step[2])] = MapReach.M


## Whether everything placed can be reached and left again. Returns what
## cannot (names).
func _connect() -> Array:
	_ladders()
	var t0 := Time.get_ticks_msec()
	var reached := m.flood(spawn)
	var back := m.back(reached, spawn)
	var stranded := 0
	for p in reached:
		stranded += 0 if back.has(p) else 1
	var out_of_reach := 0
	for y in m.h:
		for x in m.w:
			out_of_reach += 1 if m.standable(x, y) and not reached.has(Vector2i(x, y)) else 0
	log_lines.append("reach: %d floor tiles reached, %d with no way back, %d out of reach (%d ms)" % [reached.size(), stranded, out_of_reach, Time.get_ticks_msec() - t0])
	var missing := []
	for t in things:
		if not m.is_reached(reached, t[2]):
			missing.append(t[0])
		elif not m.is_reached(back, t[2]):
			missing.append(t[0] + " (no way back)")
	if "--show" in OS.get_cmdline_user_args():
		_show(reached, back)
	return missing


func _show(reached: Dictionary, back: Dictionary) -> void:
	var img := Image.create(m.w, m.h, false, Image.FORMAT_RGBA8)
	for y in m.h:
		for x in m.w:
			var c := Color8(24, 12, 16)
			if m.cell(x, y) == MapReach.R:
				c = Color8(90, 50, 56)
			elif m.cell(x, y) == MapReach.M:
				c = Color8(255, 120, 200)
			elif back.has(Vector2i(x, y)):
				c = Color8(90, 220, 110)
			elif reached.has(Vector2i(x, y)):
				c = Color8(240, 200, 60)  # Reached, but no way back.
			elif m.standable(x, y):
				c = Color8(240, 50, 50)
			img.set_pixel(x, y, c)
	img.resize(m.w * 4, m.h * 4, Image.INTERPOLATE_NEAREST)
	img.save_png(ProjectSettings.globalize_path("user://rooms_reach.png"))
	print("drawn: ", ProjectSettings.globalize_path("user://rooms_reach.png"))


func _write() -> void:
	var old := Image.load_from_file(ProjectSettings.globalize_path(SHAPED))
	var img := Image.create(m.w, m.h, false, Image.FORMAT_RGBA8)
	for y in m.h:
		for x in m.w:
			var c := m.cell(x, y)
			if c == MapReach.R:
				var was := old.get_pixel(x, y)
				img.set_pixel(x, y, was if WorldMap.is_rock_color(was) else Color.BLACK)
			elif c == MapReach.M:
				img.set_pixel(x, y, Color8(255, 0, 255))
			else:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
	if "--preview" in OS.get_cmdline_user_args():
		img.save_png(ProjectSettings.globalize_path("user://rooms_preview.png"))
		print("preview: ", ProjectSettings.globalize_path("user://rooms_preview.png"))
	else:
		img.save_png(ProjectSettings.globalize_path(WORLD))
