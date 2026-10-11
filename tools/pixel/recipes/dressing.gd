extends RefCounted
## Dressing for the rock (D-028): the stuff that grows on, hangs from and
## sticks out of every surface, so caves are not bare. For each kind of rock
## (ChunkData.KINDS) six things for floors, six for ceilings, six for walls.
##
## assets/art/tiles/dressing.png: 32 x 32 cells. Each kind is a block of five
## rows: floor, ceiling, wall (on a wall facing right), wall facing left (the
## same, mirrored), and inlay (things buried in the rock, drawn dark).
## Kinds stack downward in ChunkData.KINDS order. dressing_glow.png: the
## glowing bits, same layout (drawn unshaded).
## dressing_big.png / dressing_big_glow.png: rarer 64 x 64 pieces, per kind
## two rows (floor, ceiling) of four: curtains, rib arches, giant fungus.
##
## In a cell: floor things stand on the bottom edge, ceiling things hang from
## the top edge, wall things grow out of the left edge. ChunkDressing places them.

const Canvas := preload("res://tools/pixel/canvas.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")

const S := 32
const PER := 6
const KINDS := RockKinds.IDS
const ROWS := 5
const BIG := 64
const BIG_PER := 4
const BODY := "res://assets/art/tiles/dressing.png"
const GLOW := "res://assets/art/tiles/dressing_glow.png"
const BIG_BODY := "res://assets/art/tiles/dressing_big.png"
const BIG_GLOW := "res://assets/art/tiles/dressing_big_glow.png"


static func make(pal, out: Array) -> void:
	var body := Image.create(S * PER, S * ROWS * KINDS.size(), false, Image.FORMAT_RGBA8)
	var glow := Image.create(S * PER, S * ROWS * KINDS.size(), false, Image.FORMAT_RGBA8)
	for k in KINDS.size():
		for row in [0, 1, 2, 4]:
			for v in PER:
				var c = Canvas.new(S, S, pal)
				var rng = RandomNumberGenerator.new()
				rng.seed = hash([KINDS[k], row, v])
				if row == 4:
					Things.inlay(c, pal, KINDS[k], v, rng)
				else:
					_draw(c, pal, KINDS[k], ["floor", "ceiling", "wall"][row], v, rng)
				var img: Dictionary = c.render()
				var at = Vector2i(v * S, (k * ROWS + row) * S)
				body.blit_rect(img.body, Rect2i(0, 0, S, S), at)
				glow.blit_rect(img.glow, Rect2i(0, 0, S, S), at)
				if row == 2:  # The mirrored copy for walls facing left.
					var fb: Image = img.body.duplicate()
					var fg: Image = img.glow.duplicate()
					fb.flip_x()
					fg.flip_x()
					body.blit_rect(fb, Rect2i(0, 0, S, S), at + Vector2i(0, S))
					glow.blit_rect(fg, Rect2i(0, 0, S, S), at + Vector2i(0, S))
		var block = Rect2i(0, k * ROWS * S, S * PER, S * ROWS)
		out.append({"name": "dressing_%s" % KINDS[k], "body": body.get_region(block), "glow": glow.get_region(block)})
	Sheet.save(body, BODY)
	Sheet.save(glow, GLOW)
	# The big pieces.
	var big := Image.create(BIG * BIG_PER, BIG * 2 * KINDS.size(), false, Image.FORMAT_RGBA8)
	var big_glow := Image.create(BIG * BIG_PER, BIG * 2 * KINDS.size(), false, Image.FORMAT_RGBA8)
	for k in KINDS.size():
		for row in 2:
			for v in BIG_PER:
				var c = Canvas.new(BIG, BIG, pal)
				var rng = RandomNumberGenerator.new()
				rng.seed = hash([KINDS[k], "big", row, v])
				Big.draw(c, pal, KINDS[k], row == 0, v, rng)
				var img: Dictionary = c.render()
				var at = Vector2i(v * BIG, (k * 2 + row) * BIG)
				big.blit_rect(img.body, Rect2i(0, 0, BIG, BIG), at)
				big_glow.blit_rect(img.glow, Rect2i(0, 0, BIG, BIG), at)
		var region = Rect2i(0, k * 2 * BIG, BIG * BIG_PER, BIG * 2)
		out.append({"name": "big_%s" % KINDS[k], "body": big.get_region(region), "glow": big_glow.get_region(region)})
	Sheet.save(big, BIG_BODY)
	Sheet.save(big_glow, BIG_GLOW)


## One thing. Floors: base on y = 31. Ceilings: hanging from y = 0. Walls:
## growing out of x = 0, centred on y = 16.
static func _draw(c, pal, kind: StringName, where: String, v: int, rng: RandomNumberGenerator) -> void:
	var f = Callable(Things, "%s_%s" % [kind, where])
	f.call(c, pal, v, rng)


class Things:
	# --- helpers -----------------------------------------------------------------
	static func tuft(c, ramp: StringName, x: float, n: int, h: float, rng: RandomNumberGenerator, opts := {}) -> void:
		for i in n:
			var base = Vector2(x + (i - n / 2.0) * 2.6, 31.5)
			var tip = base + Vector2(rng.randf_range(-4.0, 4.0), -h * 1.5 * rng.randf_range(0.6, 1.0))
			c.capsule(base, tip, 1.5, 0.6, ramp, opts.merged({"z": i * 0.01}))

	static func hang(c, ramp: StringName, x: float, length: float, r: float, rng: RandomNumberGenerator, opts := {}) -> Vector2:
		var a = Vector2(x, -1)
		var segs = 3
		length = minf(length * 1.4, 30.0)
		r *= 1.25
		for i in segs:
			var b = a + Vector2(rng.randf_range(-2.0, 2.0), length / segs)
			c.capsule(a, b, r * (1.0 - i * 0.22), r * (1.0 - (i + 1) * 0.22), ramp, opts.merged({"z": i * 0.01}))
			a = b
		return a

	static func cluster(c, ramp: StringName, centre: Vector2, n: int, r: float, rng: RandomNumberGenerator, opts := {}) -> void:
		r *= 1.25
		for i in n:
			var p = centre + Vector2(rng.randf_range(-r * 1.4, r * 1.4), rng.randf_range(-r * 0.6, r * 0.4))
			c.circle(p, r * rng.randf_range(0.55, 1.0), ramp, opts.merged({"z": i * 0.01}))

	static func vein(c, pal, ramp: StringName, a: Vector2, b: Vector2, rng: RandomNumberGenerator, step := 0) -> void:
		var p = a
		for i in 4:
			var q = a.lerp(b, (i + 1) / 4.0) + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
			c.capsule(p, q, 1.3, 1.0, ramp, {"z": 0.1})
			p = q

	# --- flesh -------------------------------------------------------------------
	static func flesh_floor(c, pal, v: int, rng) -> void:
		match v:
			0: tuft(c, &"flesh", 16, 6, 10, rng, {"lo": 2})  # Cilia.
			1: cluster(c, &"lung", Vector2(16, 28), 5, 3.5, rng, {"dither": true})  # Polyps.
			2:  # Teeth growing out of the floor.
				for i in 3:
					c.capsule(Vector2(9 + i * 7, 31), Vector2(9 + i * 7 + rng.randf_range(-1, 1), 31 - rng.randf_range(5, 10)), 2.0, 0.8, &"bone", {"lo": 1})
			3:  # A pustule, about to burst.
				c.ellipse(Vector2(16, 27), 6, 5, &"blood", {"lo": 1, "hi": 2})
				c.circle(Vector2(14, 25), 2, &"blood", {"glow": true})
			4: tuft(c, &"blood", 16, 3, 7, rng, {"lo": 1, "hi": 2})
			5:
				c.ellipse(Vector2(16, 29), 9, 3, &"flesh", {"lo": 3, "dither": true})
				cluster(c, &"lung", Vector2(18, 27), 2, 2.0, rng)

	static func flesh_ceiling(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Tendrils.
				hang(c, &"flesh", 12, 18 + v * 6, 2.4, rng, {"lo": 2})
				hang(c, &"flesh", 20, 10 + v * 4, 1.8, rng, {"lo": 2})
			2:  # A dangling sac.
				var end = hang(c, &"flesh", 16, 10, 1.4, rng, {"lo": 2})
				c.ellipse(end + Vector2(0, 4), 4.5, 5.5, &"lung", {"dither": true})
			3:  # A drip of blood.
				c.ellipse(Vector2(16, 2), 4, 3, &"flesh", {"lo": 2})
				c.capsule(Vector2(16, 3), Vector2(16, 12), 1.5, 1.0, &"blood", {"lo": 1})
				c.circle(Vector2(16, 15), 1.8, &"blood", {"glow": true})
			4: cluster(c, &"lung", Vector2(16, 4), 4, 3.5, rng, {"dither": true})
			5:
				for i in 4:
					hang(c, &"blood", 8 + i * 5, rng.randf_range(6, 14), 1.0, rng, {"lo": 1, "hi": 2})

	static func flesh_wall(c, pal, v: int, rng) -> void:
		match v:
			0, 1: vein(c, pal, &"blood", Vector2(0, 6 + v * 4), Vector2(14, 26 - v * 6), rng)
			2: cluster(c, &"lung", Vector2(4, 16), 4, 3.5, rng, {"dither": true})
			3:  # A row of teeth.
				for i in 3:
					c.capsule(Vector2(0, 9 + i * 7), Vector2(8, 9 + i * 7 + rng.randf_range(-1, 1)), 2.0, 0.7, &"bone", {"lo": 1})
			4:
				c.ellipse(Vector2(3, 16), 5, 7, &"blood", {"lo": 1, "hi": 2})
				c.circle(Vector2(4, 14), 1.8, &"blood", {"glow": true})
			5: tuft(c, &"flesh", 4, 0, 0, rng)  # Bare: nothing here.

	# --- bile --------------------------------------------------------------------
	static func bile_floor(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Bubbles, some glowing.
				for i in 3 + v:
					var p = Vector2(rng.randf_range(6, 26), rng.randf_range(24, 29))
					c.circle(p, rng.randf_range(1.5, 3.5), &"bile", {"z": i})
					if i == 0:
						c.circle(p, 1.2, &"bile", {"glow": true})
			2:  # Crystals of dried bile.
				for i in 3:
					var x = 10.0 + i * 6.0
					c.polygon(PackedVector2Array([Vector2(x - 2.5, 31), Vector2(x - 0.5, 31 - rng.randf_range(8, 15)), Vector2(x + 2.5, 31)]), &"bile", {"z": i})
			3:  # A puddle that glows.
				c.ellipse(Vector2(16, 30), 11, 2.5, &"bile", {"glow": true})
			4: tuft(c, &"rock_bile", 16, 5, 8, rng, {"lo": 2})
			5: cluster(c, &"rock_bile", Vector2(16, 28), 4, 3.0, rng, {"lo": 2, "dither": true})

	static func bile_ceiling(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Slime strands.
				var end = hang(c, &"bile", 12 + v * 6, 12 + v * 8, 1.3, rng)
				c.circle(end + Vector2(0, 1), 1.8, &"bile", {"glow": true})
			2, 3:  # Stalactites.
				for i in 2:
					var x = 10.0 + i * 11.0 + v
					c.polygon(PackedVector2Array([Vector2(x - 3, 0), Vector2(x + 3, 0), Vector2(x + 0.5, rng.randf_range(10, 18))]), &"rock_bile", {"lo": 2, "z": i})
			4: cluster(c, &"bile", Vector2(16, 3), 4, 2.8, rng)
			5: hang(c, &"rock_bile", 16, 14, 2.2, rng, {"lo": 2})

	static func bile_wall(c, pal, v: int, rng) -> void:
		match v:
			0, 1: cluster(c, &"bile", Vector2(3, 16), 3 + v, 2.6, rng)
			2:
				for i in 3:
					c.polygon(PackedVector2Array([Vector2(0, 8 + i * 7), Vector2(rng.randf_range(7, 11), 10 + i * 7), Vector2(0, 13 + i * 7)]), &"bile", {"z": i})
			3: vein(c, pal, &"bile", Vector2(0, 4), Vector2(8, 28), rng)
			4: c.ellipse(Vector2(1, 16), 3, 8, &"bile", {"glow": true})
			5: tuft(c, &"rock_bile", 4, 0, 0, rng)

	# --- bruise ------------------------------------------------------------------
	static func bruise_floor(c, pal, v: int, rng) -> void:
		match v:
			0, 1: cluster(c, &"rock_bruise", Vector2(16, 28), 4 + v, 3.5, rng, {"lo": 2, "dither": true})
			2: c.ellipse(Vector2(16, 28), 8, 4, &"blood", {"lo": 0, "hi": 1, "dither": true})  # A clot.
			3: tuft(c, &"rock_bruise", 16, 6, 9, rng, {"lo": 3})
			4:  # Blisters.
				for i in 3:
					c.ellipse(Vector2(9 + i * 7, 29), 3, 2.5, &"lung", {"lo": 0, "hi": 1, "z": i})
			5: cluster(c, &"blood", Vector2(16, 29), 3, 2.0, rng, {"lo": 0, "hi": 1})

	static func bruise_ceiling(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Hanging clots.
				var end = hang(c, &"rock_bruise", 14 + v * 4, 8 + v * 6, 1.6, rng, {"lo": 2})
				c.circle(end + Vector2(0, 3), 3.5, &"blood", {"lo": 0, "hi": 1})
			2: cluster(c, &"rock_bruise", Vector2(16, 3), 5, 3.5, rng, {"lo": 2, "dither": true})
			3, 4: hang(c, &"rock_bruise", 16, 16 + v * 2, 2.6, rng, {"lo": 2})
			5:
				for i in 3:
					hang(c, &"blood", 9 + i * 7, rng.randf_range(5, 12), 0.9, rng, {"lo": 0, "hi": 1})

	static func bruise_wall(c, pal, v: int, rng) -> void:
		match v:
			0, 1: cluster(c, &"rock_bruise", Vector2(4, 16), 4, 3.5, rng, {"lo": 2, "dither": true})
			2, 3: vein(c, pal, &"blood", Vector2(0, 5 + v * 3), Vector2(10, 26), rng)
			4: c.ellipse(Vector2(2, 16), 4, 7, &"lung", {"lo": 0, "hi": 1})
			5: tuft(c, &"rock_bruise", 4, 0, 0, rng)

	# --- bone --------------------------------------------------------------------
	static func bone_floor(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Shards.
				for i in 3:
					var x = rng.randf_range(6, 26)
					c.capsule(Vector2(x, 30), Vector2(x + rng.randf_range(-6, 6), 30 - rng.randf_range(2, 6)), 1.5, 0.8, &"bone", {"lo": 1, "z": i})
			2:  # A rib, half buried.
				for i in 9:
					var a = PI + i * PI / 8.0
					c.circle(Vector2(16, 31) + Vector2(cos(a) * 11, sin(a) * 9), 1.6, &"bone", {"lo": 1})
			3:  # Vertebrae.
				for i in 3:
					c.ellipse(Vector2(9 + i * 7, 28), 3, 3, &"bone", {"lo": 1, "z": i})
					c.capsule(Vector2(9 + i * 7, 27), Vector2(9 + i * 7, 22), 1.2, 0.6, &"bone", {"lo": 1, "z": i})
			4:  # A knuckle of a skull, eyeless.
				c.ellipse(Vector2(16, 26), 7, 6, &"bone", {"lo": 1, "dither": true})
				c.stroke(Vector2(12, 27), Vector2(20, 28), pal.step(&"bone", 0))
			5: cluster(c, &"rock_bone", Vector2(16, 29), 4, 2.5, rng, {"lo": 2})

	static func bone_ceiling(c, pal, v: int, rng) -> void:
		match v:
			0, 1, 2:  # Bone spikes.
				for i in 2 + v % 2:
					var x = 8.0 + i * 9.0 + v
					c.capsule(Vector2(x, -1), Vector2(x + rng.randf_range(-2, 2), rng.randf_range(8, 17)), 2.6, 0.6, &"bone", {"lo": 1, "z": i})
			3: cluster(c, &"rock_bone", Vector2(16, 3), 4, 3.0, rng, {"lo": 2})
			4: hang(c, &"rock_bone", 16, 12, 1.4, rng, {"lo": 3})
			5:
				for i in 9:
					var a = i * PI / 8.0
					c.circle(Vector2(16, 0) + Vector2(cos(a) * 10, sin(a) * 8), 1.5, &"bone", {"lo": 1})

	static func bone_wall(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Ribs sticking out.
				for i in 2:
					c.capsule(Vector2(0, 9 + i * 12), Vector2(10, 8 + i * 12 + v * 2), 1.8, 1.0, &"bone", {"lo": 1, "z": i})
			2: cluster(c, &"rock_bone", Vector2(3, 16), 4, 3.0, rng, {"lo": 2})
			3: c.capsule(Vector2(0, 16), Vector2(12, 14), 2.6, 0.6, &"bone", {"lo": 1})
			4:
				for i in 3:
					c.ellipse(Vector2(3, 9 + i * 7), 3, 3, &"bone", {"lo": 1, "z": i})
			5: tuft(c, &"rock_bone", 4, 0, 0, rng)

	# --- rot ---------------------------------------------------------------------
	static func rot_floor(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Mushrooms with glowing caps.
				for i in 2 + v:
					var x = 9.0 + i * 7.0
					var h = rng.randf_range(5, 11)
					c.capsule(Vector2(x, 31), Vector2(x, 31 - h), 1.2, 1.0, &"bone", {"lo": 1, "z": i})
					c.ellipse(Vector2(x, 31 - h), 3.2, 1.8, &"glow_fungus", {"glow": true})
			2: cluster(c, &"rock_rot", Vector2(16, 28), 5, 3.5, rng, {"lo": 2, "dither": true})  # Mold.
			3:  # Maggots.
				for i in 4:
					var p = Vector2(rng.randf_range(7, 25), rng.randf_range(27, 30))
					c.capsule(p, p + Vector2(3, rng.randf_range(-1, 1)), 1.1, 0.9, &"skin", {"z": i})
			4: tuft(c, &"rock_rot", 16, 6, 9, rng, {"lo": 3})
			5:
				c.ellipse(Vector2(16, 29), 9, 3, &"rock_rot", {"lo": 1, "dither": true})
				c.circle(Vector2(12, 28), 1.4, &"glow_fungus", {"glow": true})

	static func rot_ceiling(c, pal, v: int, rng) -> void:
		match v:
			0, 1: hang(c, &"rock_rot", 12 + v * 6, 14 + v * 5, 1.4, rng, {"lo": 2})  # Roots.
			2: cluster(c, &"rock_rot", Vector2(16, 3), 5, 3.2, rng, {"lo": 2, "dither": true})
			3:
				for i in 4:
					hang(c, &"rock_rot", 7 + i * 6, rng.randf_range(6, 16), 0.9, rng, {"lo": 3})
			4:  # Glowing spores hanging in threads.
				for i in 2:
					var end = hang(c, &"rock_rot", 11 + i * 10, rng.randf_range(8, 16), 0.8, rng, {"lo": 3})
					c.circle(end, 1.6, &"glow_fungus", {"glow": true})
			5: cluster(c, &"rock_rot", Vector2(16, 2), 3, 2.5, rng, {"lo": 3})

	static func rot_wall(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Shelf fungus.
				for i in 2:
					c.ellipse(Vector2(2, 10 + i * 10 + v), 7, 2.2, &"rock_rot", {"lo": 3, "z": i})
			2: cluster(c, &"rock_rot", Vector2(3, 16), 5, 3.0, rng, {"lo": 2, "dither": true})
			3:
				c.ellipse(Vector2(3, 16), 5, 2, &"rock_rot", {"lo": 3})
				c.circle(Vector2(6, 15), 1.5, &"glow_fungus", {"glow": true})
			4: vein(c, pal, &"rock_rot", Vector2(0, 4), Vector2(9, 28), rng)
			5: tuft(c, &"rock_rot", 4, 0, 0, rng)

	# --- alveolus (the Lungs, week 47) ---------------------------------------------
	static func alveolus_floor(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Cilia, swaying all one way (the breath).
				for i in 6 + v * 2:
					var base = Vector2(4 + i * 3.2, 31.5)
					c.stroke(base, base + Vector2(3 + rng.randf_range(0, 2), -6 - rng.randf_range(0, 6)), pal.step(&"rock_alveolus", 5))
			2: cluster(c, &"lung", Vector2(16, 28), 6, 3.0, rng, {"dither": true})  # Little air sacs.
			3:  # A bubble of mucus, catching the light.
				c.ellipse(Vector2(16, 28), 7, 4, &"rock_alveolus", {"lo": 4, "alpha": 0.8})
				c.circle(Vector2(13, 26), 1.2, &"wing", {"glow": true})
			4: tuft(c, &"rock_alveolus", 16, 5, 7, rng, {"lo": 3})
			5:  # A pinched-off lobe.
				c.ellipse(Vector2(16, 27), 6, 5, &"lung", {"dither": true})
				c.stroke(Vector2(16, 22), Vector2(16, 31), pal.step(&"blood", 1))

	static func alveolus_ceiling(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Bronchioles: thin branching tubes ending in sacs.
				var end = hang(c, &"rock_alveolus", 12 + v * 6, 12 + v * 5, 1.2, rng, {"lo": 3})
				c.circle(end + Vector2(0, 2), 2.8, &"lung", {"dither": true})
			2: cluster(c, &"lung", Vector2(16, 4), 5, 3.2, rng, {"dither": true})
			3:  # Mucus strings.
				for i in 3:
					var end = hang(c, &"rock_alveolus", 8 + i * 8, rng.randf_range(8, 20), 0.7, rng, {"lo": 5})
					c.circle(end, 1.4, &"rock_alveolus", {"lo": 5, "alpha": 0.85})
			4:  # Glowing spores caught in the lining.
				cluster(c, &"rock_alveolus", Vector2(16, 3), 3, 2.5, rng, {"lo": 3})
				for i in 3:
					c.circle(Vector2(10 + i * 6, 6 + (i % 2) * 2), 1.0, &"glow_fungus", {"glow": true})
			5:
				for i in 5:
					c.stroke(Vector2(5 + i * 5, 0), Vector2(7 + i * 5, 5 + rng.randf_range(0, 5)), pal.step(&"rock_alveolus", 5))

	static func alveolus_wall(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Cilia along the wall.
				for i in 6:
					var base = Vector2(0, 5 + i * 4)
					c.stroke(base, base + Vector2(5 + rng.randf_range(0, 3), -2 + v * 2), pal.step(&"rock_alveolus", 5))
			2: cluster(c, &"lung", Vector2(4, 16), 4, 3.2, rng, {"dither": true})
			3: vein(c, pal, &"blood", Vector2(0, 6), Vector2(10, 26), rng)
			4:
				c.ellipse(Vector2(3, 16), 4, 6, &"rock_alveolus", {"lo": 4, "alpha": 0.8})
			5: tuft(c, &"rock_alveolus", 4, 0, 0, rng)

	# --- cartilage (the Lungs' airways, week 47) ----------------------------------
	static func cartilage_floor(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # Ring stubs: the ends of cartilage rings.
				for i in 2 + v:
					var x = 8.0 + i * 8.0
					c.ellipse(Vector2(x, 29), 3, 2.4, &"rock_cartilage", {"lo": 3})
			2: tuft(c, &"rock_cartilage", 16, 6, 6, rng, {"lo": 4})  # Pale cilia.
			3:  # A cast-off shell of mucus, dried hard.
				c.polygon(PackedVector2Array([Vector2(8, 31), Vector2(14, 24), Vector2(22, 25), Vector2(25, 31)]), &"rock_cartilage", {"lo": 4})
			4: cluster(c, &"rock_cartilage", Vector2(16, 29), 4, 2.4, rng, {"lo": 3})
			5:
				c.ellipse(Vector2(16, 30), 10, 2, &"rock_cartilage", {"lo": 2})

	static func cartilage_ceiling(c, pal, v: int, rng) -> void:
		match v:
			0, 1:  # A rim of a ring, overhanging.
				c.ellipse(Vector2(16, 2), 13 - v * 3, 3, &"rock_cartilage", {"lo": 3})
				c.ellipse(Vector2(16, 4), 11 - v * 3, 1.5, &"rock_cartilage", {"lo": 1, "z": -1})
			2:
				for i in 3:
					hang(c, &"rock_cartilage", 9 + i * 7, rng.randf_range(4, 10), 1.0, rng, {"lo": 3})
			3: cluster(c, &"rock_cartilage", Vector2(16, 3), 4, 2.6, rng, {"lo": 3})
			4:  # A drip of clear fluid.
				c.capsule(Vector2(16, 0), Vector2(16, 8), 1.2, 0.8, &"wing", {"lo": 0})
				c.circle(Vector2(16, 10), 1.3, &"wing", {"glow": true})
			5: tuft(c, &"rock_cartilage", 16, 0, 0, rng)

	static func cartilage_wall(c, pal, v: int, rng) -> void:
		match v:
			0, 1, 2:  # Ring ends sticking out of the wall.
				for i in 2:
					c.ellipse(Vector2(2, 9 + i * 12 + v), 4, 2, &"rock_cartilage", {"lo": 3, "z": i})
			3: cluster(c, &"rock_cartilage", Vector2(3, 16), 3, 2.6, rng, {"lo": 3})
			4: vein(c, pal, &"rock_cartilage", Vector2(0, 4), Vector2(8, 28), rng)
			5: tuft(c, &"rock_cartilage", 4, 0, 0, rng)

	# --- inlays: things buried in the rock ----------------------------------------
	static func inlay(c, pal, kind: StringName, v: int, rng) -> void:
		var rock: StringName = RockKinds.ramp(kind)
		var dark := {"lo": 0, "hi": 1, "line": false}
		match v:
			0, 1:  # A vein running through.
				var p = Vector2(rng.randf_range(0, 8), rng.randf_range(4, 28))
				for i in 4:
					var q = p + Vector2(rng.randf_range(5, 9), rng.randf_range(-5, 5))
					c.capsule(p, q, 1.6 - i * 0.2, 1.4 - i * 0.2, &"blood" if kind != &"bile" else &"bile", {"lo": 0, "hi": 0, "line": false})
					p = q
			2:  # A buried rib.
				for i in 7:
					var a = PI * 1.1 + i * PI / 7.0
					c.circle(Vector2(16, 22) + Vector2(cos(a) * 10, sin(a) * 8), 1.5, &"bone", {"lo": 0, "hi": 1, "line": false})
			3:  # A cyst.
				c.ellipse(Vector2(16, 16), 6, 5, rock, dark.merged({"dither": true}))
				c.ellipse(Vector2(15, 15), 3, 2.5, &"lung" if kind == &"flesh" else rock, {"lo": 0, "hi": 1, "line": false})
			4:  # A curled thing, long dead.
				for i in 12:
					var a = i * 0.55
					var r = 1.0 + i * 0.75
					c.circle(Vector2(16, 16) + Vector2(cos(a), sin(a)) * r, 1.2, &"bone", {"lo": 0, "hi": 0, "line": false})
			5:  # Pits.
				for i in 4:
					c.circle(Vector2(rng.randf_range(5, 27), rng.randf_range(5, 27)), rng.randf_range(1.2, 2.4), &"outline", {"line": false})


## The big pieces, 64 x 64: floors stand on the bottom edge, ceilings hang
## from the top.
class Big:
	static func draw(c, pal, kind: StringName, floor: bool, v: int, rng) -> void:
		var rock: StringName = RockKinds.ramp(kind)
		if floor:
			match [kind, v]:
				[&"bone", 0], [&"bone", 1]:  # A rib arch.
					for side in [-1, 1]:
						var p = Vector2(32 + side * 18, 63)
						for i in 8:
							var q = p + Vector2(-side * (2.0 + i * 0.6), -5.5)
							c.capsule(p, q, 3.0 - i * 0.2, 2.8 - i * 0.2, &"bone", {"lo": 1, "z": i * 0.01})
							p = q
				[&"rot", 0], [&"rot", 1]:  # A giant mushroom.
					c.capsule(Vector2(32, 63), Vector2(31 + v * 3, 30), 4.5, 3.0, &"bone", {"lo": 1})
					c.ellipse(Vector2(31 + v * 3, 28), 15, 6, rock, {"lo": 2, "dither": true, "z": 1})
					for i in 5:
						c.circle(Vector2(20 + i * 6 + v * 3, 30), 1.4, &"glow_fungus", {"glow": true})
				[&"alveolus", 0], [&"alveolus", 1]:  # A bronchiole tree: branches ending in clusters of sacs.
					var trunk = Vector2(32, 63)
					var top = Vector2(30 + v * 4, 34)
					c.capsule(trunk, top, 4.0, 2.6, &"rock_alveolus", {"lo": 2})
					for i in 4:
						var tip = top + Vector2(-16 + i * 11, -8 - rng.randf_range(0, 14))
						c.capsule(top, tip, 2.2, 1.2, &"rock_alveolus", {"lo": 2, "z": 0.5 + i * 0.01})
						Things.cluster(c, &"lung", tip, 4, 3.0, rng, {"dither": true, "z": 2 + i * 0.01})
				[&"cartilage", 0], [&"cartilage", 1]:  # A half ring standing out of the floor.
					for i in 14:
						var a = PI + i * PI / 13.0
						c.circle(Vector2(32, 64) + Vector2(cos(a) * 24, sin(a) * 26), 3.6, &"rock_cartilage", {"lo": 2, "z": i * 0.01})
				[&"bile", 0], [&"bile", 1]:  # Bile spires.
					for i in 3:
						var x = 18.0 + i * 13.0
						var h = rng.randf_range(28, 50)
						c.polygon(PackedVector2Array([Vector2(x - 6, 63), Vector2(x - 1, 63 - h), Vector2(x + 1, 63 - h), Vector2(x + 6, 63)]), &"bile", {"z": i})
						c.circle(Vector2(x, 66 - h), 2, &"bile", {"glow": true})
				_:  # Fleshy growths: tumours and polyp towers.
					c.ellipse(Vector2(32, 52), 18, 12, rock, {"lo": 2, "dither": true})
					for i in 4:
						c.circle(Vector2(18 + i * 9, 44 - (i % 2) * 6), rng.randf_range(5, 8), &"lung" if kind == &"flesh" else rock, {"z": 1 + i * 0.01, "dither": true, "lo": 1})
					if kind == &"flesh":
						c.circle(Vector2(30, 38), 2.2, &"blood", {"glow": true})
		else:
			match v:
				0, 1:  # A curtain of tendrils.
					for i in 6:
						var a = Vector2(10 + i * 8.5, -1)
						var length = rng.randf_range(20, 58)
						for j in 4:
							var b = a + Vector2(rng.randf_range(-3, 3), length / 4.0)
							c.capsule(a, b, 2.6 - j * 0.5, 2.1 - j * 0.5, rock if kind != &"flesh" else &"flesh", {"lo": 2, "z": i + j * 0.01})
							a = b
				2:  # A hanging mass.
					c.ellipse(Vector2(32, 14), 20, 14, rock, {"lo": 1, "dither": true})
					for i in 3:
						c.capsule(Vector2(20 + i * 12, 22), Vector2(20 + i * 12 + rng.randf_range(-3, 3), 40 + rng.randf_range(0, 14)), 3.0, 0.8, rock, {"lo": 2, "z": 1 + i * 0.01})
				3:  # Great spikes.
					for i in 3:
						var x = 14.0 + i * 18.0
						c.capsule(Vector2(x, -2), Vector2(x + rng.randf_range(-4, 4), rng.randf_range(30, 52)), 5.5, 0.8, &"bone" if kind == &"bone" else rock, {"lo": 1, "z": i})
