extends RefCounted
## One frame of pixel art, built from shapes and rendered with light (D-028).
##
## Shapes are recorded first (ellipse, capsule, polygon, rect), each with a
## palette ramp and options, then render() rasterizes them in z order and
## shades every pixel from the shape's own form: an ellipse is a dome, a
## capsule a tube, a polygon a flat slab with bevelled edges. Light comes
## from the top left and a little from the front. Each pixel's brightness
## picks a step of the shape's ramp (with optional ordered dither between
## steps). Then outlines: near-black around the silhouette, but on the lit
## (top/left) side the shape's own darkest color ("selective outline"), and
## a dark line where a shape in front meets one behind.
##
## Details (eyes, mouths, stitches) are single pixels drawn after shading.
## Glowing shapes and details go to a second image, drawn unshaded in game.
##
##   var c := Canvas.new(64, 64, pal)
##   c.ellipse(Vector2(32, 20), 7, 7, &"skin")
##   c.capsule(Vector2(30, 30), Vector2(26, 44), 3, 2, &"skin", {"z": -1})
##   c.detail(Vector2i(35, 18), pal.step(&"eye", 0))
##   var images := c.render()  # {"body": Image, "glow": Image}

const LIGHT := Vector3(-0.55, -0.75, 0.65)
const AMBIENT := 0.18
## 4 x 4 ordered dither thresholds (Bayer), 0..1.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var width: int
var height: int
var pal: RefCounted
## Off for backgrounds: no silhouette outlines and no lines between shapes.
var outlines := true

var _shapes: Array = []
var _details: Array = []  # [Vector2i, Color, glow]
var _ids: PackedInt32Array
var _normals: PackedVector3Array
var _light: Vector3


func _init(w: int, h: int, palette: RefCounted) -> void:
	width = w
	height = h
	pal = palette
	_light = LIGHT.normalized()


# --- Shapes ---------------------------------------------------------------------
## Options for every shape (all optional):
##   z: float         draw order (higher = in front); default = order added
##   tone: float      shifts brightness, -1..1 (cloth in shadow: -0.2)
##   dither: bool     ordered dither between ramp steps (soft forms)
##   glow: bool       goes to the glow image, unshaded, brightest step
##   flat: bool       no form shading: one tone, lit along its top edge
##   lo, hi: int      use only ramp steps lo..hi (e.g. keep cloth out of highlights)
##   line: bool       dark line where it lies behind another shape (default true)
##   rot: float       ellipse rotation, radians
##   alpha: float     see-through (wings), 0..1
##   seam: bool       dark line even behind a shape of the same ramp (segments)

func ellipse(center: Vector2, rx: float, ry: float, ramp: StringName, opts := {}) -> void:
	_add("ellipse", {"c": center, "rx": maxf(rx, 0.5), "ry": maxf(ry, 0.5)}, ramp, opts)


func circle(center: Vector2, r: float, ramp: StringName, opts := {}) -> void:
	ellipse(center, r, r, ramp, opts)


## A tube from a to b, radius ra at a and rb at b (limbs, tails, stalks).
func capsule(a: Vector2, b: Vector2, ra: float, rb: float, ramp: StringName, opts := {}) -> void:
	_add("capsule", {"a": a, "b": b, "ra": maxf(ra, 0.5), "rb": maxf(rb, 0.5)}, ramp, opts)


func polygon(points: PackedVector2Array, ramp: StringName, opts := {}) -> void:
	_add("polygon", {"p": points}, ramp, opts)


func rect(r: Rect2, ramp: StringName, opts := {}) -> void:
	polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), ramp, opts)


## A single pixel in an exact palette color, drawn after shading.
func detail(at: Vector2i, color: Color, glow := false) -> void:
	_details.append([at, color, glow])


## A 1 px line of details (Bresenham, no doubled corners).
func stroke(a: Vector2, b: Vector2, color: Color, glow := false) -> void:
	var p0 = Vector2i(floori(a.x), floori(a.y))
	var p1 = Vector2i(floori(b.x), floori(b.y))
	var dx = absi(p1.x - p0.x)
	var dy = -absi(p1.y - p0.y)
	var sx = 1 if p0.x < p1.x else -1
	var sy = 1 if p0.y < p1.y else -1
	var err = dx + dy
	while true:
		detail(p0, color, glow)
		if p0 == p1:
			break
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			p0.x += sx
		if e2 <= dx:
			err += dx
			p0.y += sy


func _add(kind: String, geo: Dictionary, ramp: StringName, opts: Dictionary) -> void:
	_shapes.append({"kind": kind, "geo": geo, "ramp": ramp, "opts": opts,
		"z": float(opts.get("z", 0.0)), "order": _shapes.size()})


# --- Rendering -------------------------------------------------------------------

## Returns {"body": Image, "glow": Image}, both width x height RGBA.
func render() -> Dictionary:
	var n = width * height
	_ids = PackedInt32Array()
	_ids.resize(n)
	_ids.fill(-1)
	_normals = PackedVector3Array()
	_normals.resize(n)
	var glow_ids = PackedInt32Array()
	glow_ids.resize(n)
	glow_ids.fill(-1)
	var glow_normals = PackedVector3Array()
	glow_normals.resize(n)
	var order = range(_shapes.size())
	order.sort_custom(func(a, b): return _shapes[a].z < _shapes[b].z or (_shapes[a].z == _shapes[b].z and a < b))
	for i in order:
		var s: Dictionary = _shapes[i]
		if s.opts.get("glow", false):
			_raster(i, glow_ids, glow_normals)
		else:
			_raster(i, _ids, _normals)
	var body = Image.create(width, height, false, Image.FORMAT_RGBA8)
	var glow = Image.create(width, height, false, Image.FORMAT_RGBA8)
	_prune(_ids)
	_prune(glow_ids)
	# Shade.
	for y in height:
		for x in width:
			var k = y * width + x
			var id = _ids[k]
			if id >= 0:
				body.set_pixel(x, y, _shade(_shapes[id], _normals[k], x, y, id))
			var gid = glow_ids[k]
			if gid >= 0:
				glow.set_pixel(x, y, pal.step(_shapes[gid].ramp, -1))
	# Lines where a shape lies behind another.
	var lines: Array = []
	for y in (height if outlines else 0):
		for x in width:
			var id = _ids[y * width + x]
			if id < 0 or not _shapes[id].opts.get("line", true):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= width or q.y >= height:
					continue
				var other = _ids[q.y * width + q.x]
				if other >= 0 and other != id and _in_front(other, id) and (_shapes[other].ramp != _shapes[id].ramp or _shapes[id].opts.get("seam", false)):
					lines.append([Vector2i(x, y), pal.step(_shapes[id].ramp, int(_shapes[id].opts.get("lo", 0)))])
					break
	for l in lines:
		body.set_pixelv(l[0], l[1])
	# Outline: selective on the lit side, near-black elsewhere.
	var outline: Color = pal.outline()
	var marks: Array = []
	for y in (height if outlines else 0):
		for x in width:
			if _ids[y * width + x] >= 0:
				continue
			var lit_neighbour = -1
			var any = false
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x < 0 or q.y < 0 or q.x >= width or q.y >= height:
					continue
				var other = _ids[q.y * width + q.x]
				if other >= 0:
					any = true
					if (d == Vector2i(1, 0) or d == Vector2i(0, 1)) and lit_neighbour < 0:
						lit_neighbour = other  # We are above / left of it: the lit side.
			if any:
				var c: Color = outline
				if lit_neighbour >= 0 and pal.ramp(_shapes[lit_neighbour].ramp).size() >= 3:
					c = pal.step(_shapes[lit_neighbour].ramp, 0)
				marks.append([Vector2i(x, y), c])
	for m in marks:
		body.set_pixelv(m[0], m[1])
	# Details last.
	for d in _details:
		var at: Vector2i = d[0]
		if at.x >= 0 and at.y >= 0 and at.x < width and at.y < height:
			(glow if d[2] else body).set_pixelv(at, d[1])
	return {"body": body, "glow": glow}


## Cleanup: a lone pixel sticking out of a shape (at most one neighbour of
## the same shape) is a rasterizing nub, not a feature. Two passes.
func _prune(ids: PackedInt32Array) -> void:
	for pass_i in 2:
		var gone: Array = []
		for y in height:
			for x in width:
				var id = ids[y * width + x]
				if id < 0:
					continue
				var same = 0
				var any = 0
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = Vector2i(x, y) + d
					if q.x < 0 or q.y < 0 or q.x >= width or q.y >= height:
						continue
					var other = ids[q.y * width + q.x]
					if other >= 0:
						any += 1
						if other == id:
							same += 1
				if any <= 1 and same <= 1:
					gone.append(y * width + x)
		for k in gone:
			ids[k] = -1


func _in_front(a: int, b: int) -> bool:
	var sa: Dictionary = _shapes[a]
	var sb: Dictionary = _shapes[b]
	return sa.z > sb.z or (sa.z == sb.z and a > b)


func _shade(s: Dictionary, n: Vector3, x: int, y: int, id: int) -> Color:
	var r: Array = pal.ramp(s.ramp)
	var hi: int = mini(s.opts.get("hi", r.size() - 1), r.size() - 1)
	var lo: int = mini(s.opts.get("lo", 0), hi)
	var t: float
	if s.opts.get("flat", false):
		var above = y > 0 and _ids[(y - 1) * width + x] == id
		t = 0.55 if above else 0.9
	else:
		var diffuse = maxf(0.0, n.dot(_light))
		t = AMBIENT + (1.0 - AMBIENT) * diffuse
	t = clampf(t + float(s.opts.get("tone", 0.0)), 0.0, 1.0)
	var steps = hi - lo + 1
	var f = t * steps - 0.5
	var i = floori(f)
	if s.opts.get("dither", false):
		var frac = f - i
		var threshold = (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0
		if frac > threshold:
			i += 1
	else:
		i = roundi(f)
	return Color(r[clampi(lo + i, lo, hi)], float(s.opts.get("alpha", 1.0)))


func _raster(id: int, ids: PackedInt32Array, normals: PackedVector3Array) -> void:
	var s: Dictionary = _shapes[id]
	var g: Dictionary = s.geo
	match s.kind:
		"ellipse":
			var c: Vector2 = g.c
			var rot: float = s.opts.get("rot", 0.0)
			var reach = maxf(g.rx, g.ry) + 1.0
			for y in range(floori(c.y - reach), ceili(c.y + reach) + 1):
				for x in range(floori(c.x - reach), ceili(c.x + reach) + 1):
					var p = (Vector2(x + 0.5, y + 0.5) - c).rotated(-rot)
					var u = p.x / g.rx
					var v = p.y / g.ry
					var d = u * u + v * v
					if d <= 1.0:
						var local = Vector2(u, v).rotated(rot)
						_put(ids, normals, x, y, id, Vector3(local.x, local.y, sqrt(1.0 - d)).normalized())
		"capsule":
			var a: Vector2 = g.a
			var b: Vector2 = g.b
			var reach = maxf(g.ra, g.rb) + 1.0
			var lo = a.min(b) - Vector2.ONE * reach
			var hi = a.max(b) + Vector2.ONE * reach
			var ab = b - a
			var len2 = maxf(ab.length_squared(), 0.0001)
			for y in range(floori(lo.y), ceili(hi.y) + 1):
				for x in range(floori(lo.x), ceili(hi.x) + 1):
					var p = Vector2(x + 0.5, y + 0.5)
					var t = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
					var r = lerpf(g.ra, g.rb, t)
					var off = p - (a + ab * t)
					var d = off.length() / r
					if d <= 1.0:
						var o = off / r
						_put(ids, normals, x, y, id, Vector3(o.x, o.y, sqrt(maxf(0.0, 1.0 - d * d))).normalized())
		"polygon":
			var pts: PackedVector2Array = g.p
			var lo = Vector2(INF, INF)
			var hi = Vector2(-INF, -INF)
			for q in pts:
				lo = lo.min(q)
				hi = hi.max(q)
			var mine: Array[Vector2i] = []
			for y in range(floori(lo.y), ceili(hi.y) + 1):
				for x in range(floori(lo.x), ceili(hi.x) + 1):
					if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
						mine.append(Vector2i(x, y))
			# A slab facing you, bevelled 2 px at its edges toward the outside.
			var inside = {}
			for q in mine:
				inside[q] = true
			for q in mine:
				var out = Vector2.ZERO
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]:
					if not inside.has(q + d):
						out += Vector2(d) / Vector2(d).length_squared()
				var n = Vector3(out.x, out.y, 1.6).normalized() if out != Vector2.ZERO else Vector3(0, 0, 1)
				_put(ids, normals, q.x, q.y, id, n)


func _put(ids: PackedInt32Array, normals: PackedVector3Array, x: int, y: int, id: int, n: Vector3) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	ids[y * width + x] = id
	normals[y * width + x] = n
