extends RefCounted
## The rock tiles (D-022/D-023 look, D-028 colors): one 4 x 5 block of 32 px
## tiles per kind of rock (ChunkData.KINDS: flesh, bile, bruise, bone, rot),
## stacked downward in assets/art/tiles/gut_tiles.png. Each block: the 16
## open-sides masks (rims on open sides, a 12 px paved face on top when the
## tile has air above), then NEAR and DEEP fill. Every kind is the same
## drawing in its own 7-step ramp, with dither between steps.
##
## Also writes the tileset's extra rows (gut_tileset.tres): every kind's
## tiles get the collision and light occluders of the flesh tiles.

const Sheet := preload("res://tools/pixel/sheet.gd")
const T := 32
const FACE := 12  # Top face rows 0..11; row 11 is the lip.
const R := 7.0  # Rounding of lower corners.
const FACE_R := 4.0
const RAMPS := {&"flesh": &"flesh", &"bile": &"rock_bile", &"bruise": &"rock_bruise", &"bone": &"rock_bone", &"rot": &"rock_rot"}
const KINDS := [&"flesh", &"bile", &"bruise", &"bone", &"rot"]  # Same order as ChunkData.KINDS.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const ATLAS := "res://assets/art/tiles/gut_tiles.png"
const TILESET := "res://assets/art/tiles/gut_tileset.tres"


static func make(pal, out: Array) -> void:
	var cells := _voronoi_points()
	var atlas := Image.create(T * 4, T * 5 * KINDS.size(), false, Image.FORMAT_RGBA8)
	for k in KINDS.size():
		var ramp: Array = pal.ramp(RAMPS[KINDS[k]])
		var block := Image.create(T * 4, T * 5, false, Image.FORMAT_RGBA8)
		for mask in 16:
			_tile(block, Vector2i(mask % 4, mask / 4) * T, mask, ramp, cells)
		_fill(block, Vector2i(0, 4) * T, -1.0, ramp, cells)  # NEAR
		_fill(block, Vector2i(1, 4) * T, -1.7, ramp, cells)  # DEEP
		atlas.blit_rect(block, Rect2i(0, 0, T * 4, T * 5), Vector2i(0, T * 5 * k))
		out.append({"name": "tiles_%s" % KINDS[k], "body": block})
	Sheet.save(atlas, ATLAS)
	_write_tileset()


# --- Drawing (tones are ramp steps, 0 = darkest, fractions dither) -------------

static func _px(img: Image, at: Vector2i, x: int, y: int, tone: float, ramp: Array) -> void:
	var i := floori(tone)
	if tone - i > (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0:
		i += 1
	img.set_pixel(at.x + x, at.y + y, ramp[clampi(i, 0, ramp.size() - 1)])


## Seven Voronoi points that tile every 32 px, with a tone each.
static func _voronoi_points() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var points := []
	for i in 7:
		points.append({"p": Vector2(rng.randf_range(0, T), rng.randf_range(0, T)), "tone": [2.2, 2.6, 3.0, 2.4, 3.3, 2.0, 2.8][i]})
	return points


static func _voronoi(x: int, y: int, cells: Array) -> Dictionary:
	var p := Vector2(posmod(x, T) + 0.5, posmod(y, T) + 0.5)
	var d1 := INF
	var d2 := INF
	var best := 0
	for i in cells.size():
		var d: Vector2 = p - cells[i].p
		d = Vector2(minf(absf(d.x), T - absf(d.x)), minf(absf(d.y), T - absf(d.y)))
		var dist := d.length()
		if dist < d1:
			d2 = d1
			d1 = dist
			best = i
		elif dist < d2:
			d2 = dist
	return {"gap": d2 - d1 < 1.1, "tone": cells[best].tone}


## Cobbled flesh (or bile, or bone...): lumps with dark gaps, lit from above.
static func _cobble(x: int, y: int, cells: Array) -> float:
	var v := _voronoi(x, y, cells)
	if v.gap:
		return 0.4
	if _voronoi(x, y - 1, cells).gap or _voronoi(x - 1, y, cells).gap:
		return 4.0
	if _voronoi(x, y + 1, cells).gap or _voronoi(x + 1, y, cells).gap:
		return 1.0
	return v.tone


static func _fill(img: Image, at: Vector2i, shift: float, ramp: Array, cells: Array) -> void:
	for y in T:
		for x in T:
			_px(img, at, x, y, _cobble(x, y, cells) + shift, ramp)


static func _tile(img: Image, at: Vector2i, mask: int, ramp: Array, cells: Array) -> void:
	var up := mask & 1 != 0
	var right := mask & 2 != 0
	var down := mask & 4 != 0
	var left := mask & 8 != 0
	for y in T:
		for x in T:
			var tone := 0.0
			if up and y < FACE:
				tone = _face(x, y, left, right)
			else:
				tone = _side(x, y, mask == 0, right, down, left, cells)
				if up and tone >= 0.0:
					if y == FACE:
						tone = 0.0  # Shadow under the lip.
					elif y == FACE + 1:
						tone -= 1.0
			if tone >= 0.0:
				_px(img, at, x, y, tone, ramp)


## Tone of a wall / ceiling pixel, or -1 for transparent (a rounded corner).
static func _side(x: int, y: int, buried: bool, right: bool, down: bool, left: bool, cells: Array) -> float:
	var p := Vector2(x + 0.5, y + 0.5)
	var d := INF
	if right:
		d = minf(d, T - p.x)
	if down:
		d = minf(d, T - p.y)
	if left:
		d = minf(d, p.x)
	var corners := []
	if down and left:
		corners.append(Vector2(R, T - R))
	if down and right:
		corners.append(Vector2(T - R, T - R))
	for c in corners:
		if ((c.x < T / 2.0 and p.x < c.x) or (c.x > T / 2.0 and p.x > c.x)) and p.y > c.y:
			var cd: float = R - p.distance_to(c)
			if cd < 0.0:
				return -1.0
			d = minf(d, cd)
	var base := _cobble(x, y, cells)
	if buried:
		return base - 0.4
	if d < 1.5:
		return 0.0
	if d < 3.0:
		return 4.2 if down and absf(d - (T - p.y)) < 0.01 else 2.0
	if d < 5.0:
		return base - 1.2
	return base


## Tone of the paved top face of a floor, or -1 (rounded end).
static func _face(x: int, y: int, left: bool, right: bool) -> float:
	var p := Vector2(x + 0.5, y + 0.5)
	if left and p.x < FACE_R and p.y < FACE_R and p.distance_to(Vector2(FACE_R, FACE_R)) > FACE_R:
		return -1.0
	if right and p.x > T - FACE_R and p.y < FACE_R and p.distance_to(Vector2(T - FACE_R, FACE_R)) > FACE_R:
		return -1.0
	if (left and x == 0) or (right and x == T - 1):
		return 0.0
	if y == 0:
		return 3.0
	if y == FACE - 1:
		return 6.0
	var band := 0 if y <= 5 else 1
	var top_row := 1 if band == 0 else 6
	var joints := [0, 11, 22] if band == 0 else [5, 16, 27]
	if x in joints:
		return 2.0
	if y == top_row:
		return 5.8
	var stone := 0
	for j in joints:
		if x > j:
			stone += 1
	return [4.6, 5.0, 5.3][(stone + band) % 3] - (y - top_row) * 0.12


# --- Tileset ---------------------------------------------------------------------

## Copies the flesh tiles' lines (rows 0..4: collision, occluders) to every
## other kind's rows, replacing whatever was there.
static func _write_tileset() -> void:
	var text := FileAccess.get_file_as_string(TILESET)
	var lines := text.split("\n")
	var keep := PackedStringArray()
	var base := PackedStringArray()
	var re := RegEx.create_from_string("^(\\d+):(\\d+)/0")
	var last_tile_line := -1
	for line in lines:
		var m := re.search(line)
		if m:
			if int(m.get_string(2)) >= 5:
				continue  # Generated rows: rebuilt below.
			base.append(line)
		keep.append(line)
		if m:
			last_tile_line = keep.size() - 1
	var extra := PackedStringArray()
	for k in range(1, KINDS.size()):
		for line in base:
			var m := re.search(line)
			var row := int(m.get_string(2)) + 5 * k
			extra.append("%s:%d/0%s" % [m.get_string(1), row, line.substr(m.get_end())])
	var out := keep.slice(0, last_tile_line + 1)
	out.append_array(extra)
	out.append_array(keep.slice(last_tile_line + 1))
	var file := FileAccess.open(TILESET, FileAccess.WRITE)
	file.store_string("\n".join(out))
	file.close()
