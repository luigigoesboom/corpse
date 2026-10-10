extends RefCounted
## The back wall of the caves (D-028): three seamless, parallax layers of the
## inside of a body, drawn dark and soft so the playfield stays readable.
##   far:  muscle-fibre walls with veins and pores (opaque)
##   mid:  huge dim shapes: rib arches, flesh pillars, hanging membranes
##   near: a few big tendrils and vessels close behind the playfield
## Writes assets/art/backdrop/backdrop_far.png, _mid.png, _near.png. Each
## tiles both ways (shapes near an edge are drawn again across it).
## scenes/backdrop.tscn scrolls them (assets/shaders/backdrop.gdshader) and
## tints them by the kind of rock around the camera (src/world/backdrop.gd).

const Canvas := preload("res://tools/pixel/canvas.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")
const DIR := "res://assets/art/backdrop/"


static func make(pal, out: Array) -> void:
	var far = _far(pal)
	var mid = _mid(pal)
	var near = _near(pal)
	Sheet.save(far, DIR + "backdrop_far.png")
	Sheet.save(mid, DIR + "backdrop_mid.png")
	Sheet.save(near, DIR + "backdrop_near.png")
	for item in [["far", far], ["mid", mid], ["near", near]]:
		var small: Image = item[1].duplicate()
		small.resize(small.get_width() / 3, small.get_height() / 3, Image.INTERPOLATE_NEAREST)
		out.append({"name": item[0], "body": small})
	var stack = far.duplicate()
	stack.blend_rect(mid.get_region(Rect2i(0, 0, far.get_width(), far.get_height())), Rect2i(0, 0, far.get_width(), far.get_height()), Vector2i.ZERO)
	stack.blend_rect(near.get_region(Rect2i(0, 0, far.get_width(), far.get_height())), Rect2i(0, 0, far.get_width(), far.get_height()), Vector2i.ZERO)
	stack.resize(stack.get_width() / 2, stack.get_height() / 2, Image.INTERPOLATE_NEAREST)
	out.append({"name": "stacked", "body": stack})


## Every shape in a tiling layer is drawn at 9 offsets so it wraps.
class Wrap:
	var c
	var w: float
	var h: float

	func _init(canvas, width: int, height: int) -> void:
		c = canvas
		w = width
		h = height

	func capsule(a: Vector2, b: Vector2, ra: float, rb: float, ramp: StringName, opts := {}) -> void:
		for dx in [-w, 0.0, w]:
			for dy in [-h, 0.0, h]:
				var o = Vector2(dx, dy)
				c.capsule(a + o, b + o, ra, rb, ramp, opts)

	func ellipse(at: Vector2, rx: float, ry: float, ramp: StringName, opts := {}) -> void:
		for dx in [-w, 0.0, w]:
			for dy in [-h, 0.0, h]:
				c.ellipse(at + Vector2(dx, dy), rx, ry, ramp, opts)

	## A wobbly chain of capsules from `a` heading along `dir`.
	func strand(a: Vector2, dir: Vector2, length: float, r0: float, r1: float, ramp: StringName, rng: RandomNumberGenerator, opts := {}, segs := 6) -> void:
		var p = a
		for i in segs:
			var t = float(i) / segs
			var q = p + dir.rotated(rng.randf_range(-0.35, 0.35)) * length / segs
			capsule(p, q, lerpf(r0, r1, t), lerpf(r0, r1, t + 1.0 / segs), ramp, opts.merged({"z": opts.get("z", 0.0) + i * 0.001}))
			p = q


static func _far(pal) -> Image:
	var W = 512
	var H = 384
	var c = Canvas.new(W, H, pal)
	c.outlines = false
	var w = Wrap.new(c, W, H)
	var rng = RandomNumberGenerator.new()
	rng.seed = 11
	c.rect(Rect2(0, 0, W, H), &"flesh", {"flat": true, "lo": 0, "hi": 0, "z": -10})
	# Muscle fibres: long bundles running across, gently curving.
	for i in 26:
		var y = rng.randf_range(0, H)
		var x = rng.randf_range(0, W)
		w.strand(Vector2(x, y), Vector2(1, rng.randf_range(-0.25, 0.25)), rng.randf_range(160, 320), rng.randf_range(5, 11), rng.randf_range(3, 6),
			&"flesh", rng, {"lo": 0, "hi": 2, "dither": true, "tone": -0.12, "z": i * 0.01}, 8)
	# Veins over them.
	for i in 10:
		var p = Vector2(rng.randf_range(0, W), rng.randf_range(0, H))
		w.strand(p, Vector2.from_angle(rng.randf_range(0, TAU)), rng.randf_range(60, 140), 1.6, 0.8, &"blood", rng, {"lo": 0, "hi": 0, "z": 1.0 + i * 0.01}, 7)
	# Pores.
	for i in 40:
		w.ellipse(Vector2(rng.randf_range(0, W), rng.randf_range(0, H)), rng.randf_range(1.5, 3.5), rng.randf_range(1.0, 2.5), &"outline", {"z": 2.0, "flat": true})
	return c.render().body


static func _mid(pal) -> Image:
	var W = 1024
	var H = 512
	var c = Canvas.new(W, H, pal)
	c.outlines = false
	var w = Wrap.new(c, W, H)
	var rng = RandomNumberGenerator.new()
	rng.seed = 23
	var dim = {"lo": 0, "hi": 1, "dither": true, "tone": -0.1}
	# Rib arches: great curved bones, far off.
	for k in 3:
		var base = Vector2(120 + k * 340 + rng.randf_range(-40, 40), H * 0.98)
		var span = rng.randf_range(180, 260)
		var rise = span * rng.randf_range(0.7, 0.95)
		for side in [-1.0, 1.0]:  # Each rib curves up from the floor toward the top of the arch.
			var p = base + Vector2(side * span * 0.5, 0)
			for i in 12:
				var a = PI * 0.5 * (i + 1) / 12.0
				var q = base + Vector2(side * cos(a) * span * 0.5, -sin(a) * rise)
				w.capsule(p, q, 9.0 - i * 0.45, 8.6 - i * 0.45, &"ash", {"lo": 0, "hi": 1, "dither": true, "tone": -0.3, "z": k + i * 0.001})
				p = q
	# Pillars of flesh, floor to ceiling, swelling in the middle.
	for k in 4:
		var x = rng.randf_range(0, W)
		var p = Vector2(x, -10)
		for i in 8:
			var q = p + Vector2(rng.randf_range(-14, 14), (H + 20) / 8.0)
			var r = 14.0 + sin(i / 7.0 * PI) * 12.0
			w.capsule(p, q, r, r, &"flesh", dim.merged({"z": 5 + k + i * 0.001, "lo": 1, "hi": 2}))
			p = q
	# Membranes hanging from above, ragged at the bottom.
	for k in 5:
		var x = rng.randf_range(0, W)
		var width = rng.randf_range(40, 90)
		for i in int(width / 8.0):
			w.strand(Vector2(x + i * 8.0, -5), Vector2(0, 1), rng.randf_range(80, 180), 5.0, 1.5, &"bulb", rng, {"lo": 0, "hi": 1, "dither": true, "tone": -0.2, "z": 10 + k + i * 0.01}, 5)
	return c.render().body


static func _near(pal) -> Image:
	var W = 1024
	var H = 512
	var c = Canvas.new(W, H, pal)
	c.outlines = false
	var w = Wrap.new(c, W, H)
	var rng = RandomNumberGenerator.new()
	rng.seed = 37
	var black = {"lo": 0, "hi": 0, "flat": true}
	# Big tendrils hanging close behind the playfield: near-black silhouettes.
	for k in 6:
		w.strand(Vector2(rng.randf_range(0, W), -10), Vector2(rng.randf_range(-0.2, 0.2), 1), rng.randf_range(140, 300), rng.randf_range(7, 12), 2.0,
			&"flesh", rng, black.merged({"z": k}), 9)
	# A great vessel crossing.
	w.strand(Vector2(0, H * 0.6), Vector2(1, -0.08), W * 0.55, 16, 14, &"flesh", rng, black.merged({"z": 20}), 10)
	w.strand(Vector2(W * 0.55, H * 0.6 - W * 0.04), Vector2(1, 0.08), W * 0.47, 14, 16, &"flesh", rng, black.merged({"z": 21}), 10)
	return c.render().body
