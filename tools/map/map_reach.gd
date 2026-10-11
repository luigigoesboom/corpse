class_name MapReach
extends RefCounted
## Where the host can get to on a painted map, by walking, jumping, falling
## and dropping through membranes (no wall jumps, no mutations: if a place
## needs those it is not counted as reachable). Used by the map tools before
## they write anything, and by tests/test_reach.gd.
##
##   var reach := MapReach.from_image(Image.load_from_file(...))
##   var reached := reach.flood(Vector2i(14, 98))   # stand spot -> true
##
## A stand spot is a tile the host's feet can be in: open, open above, and
## rock or membrane underneath.

enum { R, A, M }  # Rock, air, membrane.

## How far the host's jump reaches, in tiles (jump height 120 px = 3.75).
const JUMP_UP := 3
const JUMP_ACROSS := 4

var w: int
var h: int
var cells := PackedByteArray()


static func from_image(img: Image) -> MapReach:
	var r := MapReach.new()
	r.w = img.get_width()
	r.h = img.get_height()
	r.cells.resize(r.w * r.h)
	for y in r.h:
		for x in r.w:
			var c := img.get_pixel(x, y)
			r.cells[y * r.w + x] = M if WorldMap.is_membrane_color(c) else (R if WorldMap.is_rock_color(c) else A)
	return r


func cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return R
	return cells[y * w + x]


func standable(x: int, y: int) -> bool:
	return cell(x, y) != R and cell(x, y - 1) != R and cell(x, y + 1) != A


## Every stand spot reachable from `start` (Vector2i -> true).
func flood(start: Vector2i) -> Dictionary:
	var reached := {}
	if not standable(start.x, start.y):
		start = land(start)
	reached[start] = true
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for q in moves(p):
			if not reached.has(q):
				reached[q] = true
				queue.append(q)
	return reached


## The reached spots from which the host can get back to `home` (walking
## the moves backwards).
func back(reached: Dictionary, home: Vector2i) -> Dictionary:
	var into := {}  # q -> [p, ...]: the spots that move to q
	for p: Vector2i in reached:
		for q in moves(p):
			if reached.has(q):
				into.get_or_add(q, []).append(p)
	var out := {}
	if not reached.has(home):
		return out
	out[home] = true
	var queue: Array[Vector2i] = [home]
	var head := 0
	while head < queue.size():
		var q: Vector2i = queue[head]
		head += 1
		for p in into.get(q, []):
			if not out.has(p):
				out[p] = true
				queue.append(p)
	return out


## Grows a flood after rock was added inside `area` (Rect2i, tiles): carries
## on from every reached spot near it. Much cheaper than flood(), but it never
## takes spots away: check with a full flood() at the end.
func extend(reached: Dictionary, area: Rect2i) -> void:
	var near := area.grow(8)
	var queue: Array[Vector2i] = []
	for p: Vector2i in reached:
		if near.has_point(p):
			queue.append(p)
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		for q in moves(p):
			if not reached.has(q):
				reached[q] = true
				queue.append(q)


## Where something at `p` comes to rest: the first stand spot at or below it.
func land(p: Vector2i) -> Vector2i:
	var y := p.y
	while y < h - 1 and not standable(p.x, y):
		if cell(p.x, y) == R:
			return p  # Inside rock.
		y += 1
	return Vector2i(p.x, y)


## Where the host can go from a stand spot: walk a step, jump up to JUMP_UP
## rows and JUMP_ACROSS columns (if the air above is clear), or fall.
func moves(p: Vector2i) -> Array:
	var out := []
	for dx in [-1, 1]:
		var q := p + Vector2i(dx, 0)
		if cell(q.x, q.y) != R and cell(q.x, q.y - 1) != R:
			if standable(q.x, q.y):
				out.append(q)
			else:
				var y := q.y  # Off the edge: fall to whatever is below.
				while y < h - 1 and not standable(q.x, y):
					if cell(q.x, y + 1) == R:
						break
					y += 1
				if standable(q.x, y):
					out.append(Vector2i(q.x, y))
	# Jumps: rise first, then drift across, landing on any stand spot up to
	# JUMP_UP rows higher, or lower (then reaching a little further).
	var head_room := 0
	while head_room < JUMP_UP and cell(p.x, p.y - 2 - head_room) != R:
		head_room += 1
	for dy in range(-head_room, 7):
		var across := JUMP_ACROSS + (2 if dy > 0 else 0)
		var apex := p.y - 1 - maxi(head_room, -dy)
		for dx in range(-across, across + 1):
			if dx == 0 and dy == 0:
				continue
			var q := Vector2i(p.x + dx, p.y + dy)
			if standable(q.x, q.y) and _clear(p.x, q.x, apex) and _clear(p.x, q.x, mini(p.y, q.y) - 1) and _clear(p.x, q.x, mini(p.y, q.y)):
				out.append(q)
	# Dropping through a membrane.
	if cell(p.x, p.y + 1) == M:
		var y := p.y + 1
		while y < h - 1 and not standable(p.x, y):
			y += 1
		if standable(p.x, y):
			out.append(Vector2i(p.x, y))
	return out


## No rock in a row between two columns (the body's path across a jump).
func _clear(x0: int, x1: int, row: int) -> bool:
	for x in range(mini(x0, x1), maxi(x0, x1) + 1):
		if cell(x, row) == R:
			return false
	return true


## Is a point (world pixels) within `slack` tiles of a reached stand spot?
func is_reached(reached: Dictionary, point: Vector2, slack := 2) -> bool:
	var t := Vector2i(int(floor(point.x / 32.0)), int(floor(point.y / 32.0)))
	var spot := land(t)
	for dy in range(-slack, slack + 1):
		for dx in range(-slack, slack + 1):
			if reached.has(spot + Vector2i(dx, dy)) or reached.has(t + Vector2i(dx, dy)):
				return true
	return false


## The things placed in a scene directly under the given parents, as
## [name, parent, position, width] (positions are relative to the parent,
## which in world.tscn sits at the origin; width is a settlement's or ruin's
## `width`, else 0).
static func placed(scene_path: String, parents: Array) -> Array:
	var out := []
	var text := FileAccess.get_file_as_string(scene_path)
	var blocks := text.split("\n[")
	for block in blocks:
		var header := block.get_slice("\n", 0)
		var name_re := RegEx.create_from_string('node name="([^"]+)"[^\\]]*parent="([^"]+)"')
		var m := name_re.search(header)
		if m == null or not parents.has(m.get_string(2)):
			continue
		var pos_re := RegEx.create_from_string('\\nposition = Vector2\\(([-\\d.e]+), ([-\\d.e]+)\\)')
		var p := pos_re.search(block)
		if p:
			var width_re := RegEx.create_from_string('\\nwidth = ([\\d.]+)')
			var wm := width_re.search(block)
			var width := float(wm.get_string(1)) if wm else 0.0
			out.append([m.get_string(1), m.get_string(2), Vector2(float(p.get_string(1)), float(p.get_string(2))), width])
	return out
