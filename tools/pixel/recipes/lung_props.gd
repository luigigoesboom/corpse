extends RefCounted
## The Lungs' set pieces (week 48): the landmarks that make each place of
## the Lungs recognisable. Like props.gd: assets/art/props/<name>_body.png
## (lit) and _glow.png (unshaded), in the frame the scene in src/props/lungs
## uses. Built from many small, uneven shapes (lumps, knots, frayed edges)
## rather than a few clean ones, so they read as grown, not made.
##
## `o` is the anchor in the canvas: the floor point for things standing on
## a floor, the ceiling point for things hanging (pleura_curtain, wind_bones).

const Canvas := preload("res://tools/pixel/canvas.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")
const OUT := "res://assets/art/props/"

## name: [width, height, anchor x, anchor y, outputs (b body, g glow)]
const FRAMES := {
	"cartilage_gate": [200, 300, 100, 298, "b"],
	"hive_lantern": [48, 64, 24, 62, "bg"],
	"pleura_curtain": [128, 180, 64, 0, "b"],
	"aerie_nest": [112, 48, 56, 46, "bg"],
	"wind_bones": [32, 96, 16, 0, "b"],
	# The Bellows-Kin's settlement props (week 50), standing on the floor.
	"kite_rack": [80, 72, 40, 70, "b"],
	"breath_drum": [56, 48, 28, 46, "b"],
	"membrane_hammock": [96, 56, 48, 54, "b"],
	"windsock": [40, 96, 8, 94, "b"],
}


static func make(pal, out: Array) -> void:
	for name in FRAMES:
		var f: Array = FRAMES[name]
		var c = Canvas.new(f[0], f[1], pal)
		var rng = RandomNumberGenerator.new()
		rng.seed = hash(name)
		Callable(Draw, name).call(c, pal, Vector2(f[2], f[3]), rng)
		var img: Dictionary = c.render()
		if "b" in f[4]:
			Sheet.save(img.body, OUT + name + "_body.png")
		if "g" in f[4]:
			Sheet.save(img.glow, OUT + name + "_glow.png")
		out.append({"name": name, "body": img.body, "glow": img.glow})


class Draw:
	## A lumpy tube from a to b: a chain of overlapping blobs of uneven size
	## and a little off the line, instead of one clean capsule.
	static func lumpy(c, a: Vector2, b: Vector2, r0: float, r1: float, ramp: StringName, rng: RandomNumberGenerator, opts := {}, steps := -1) -> void:
		var n: int = steps if steps > 0 else maxi(3, int(a.distance_to(b) / maxf(2.0, (r0 + r1) * 0.45)))
		var side = (b - a).orthogonal().normalized()
		for i in n + 1:
			var t = float(i) / n
			var r = lerpf(r0, r1, t) * rng.randf_range(0.8, 1.15)
			var p = a.lerp(b, t) + side * rng.randf_range(-0.6, 0.6) * r * 0.35
			c.ellipse(p, r, r * rng.randf_range(0.8, 1.0), ramp, opts.merged({"z": opts.get("z", 0.0) + i * 0.001, "rot": rng.randf_range(-0.5, 0.5)}))

	## Ragged hanging sheet: many thin strips side by side, of uneven length,
	## see-through, frayed at the bottom.
	static func sheet(c, pal, top_left: Vector2, width: float, length: float, ramp: StringName, rng: RandomNumberGenerator, opts := {}) -> void:
		var x = 0.0
		var i = 0
		while x < width:
			var w = rng.randf_range(3.0, 6.0)
			var l = length * rng.randf_range(0.55, 1.0)
			var top = top_left + Vector2(x + w * 0.5, 0)
			var sway = rng.randf_range(-6.0, 6.0)
			c.capsule(top, top + Vector2(sway, l), w * 0.6, w * 0.35, ramp, {"alpha": 0.72, "flat": true, "line": false, "z": opts.get("z", 0.0) + i * 0.01}.merged(opts))
			if rng.randf() < 0.4:
				c.stroke(top + Vector2(0, 4), top + Vector2(sway * 0.8, l * 0.8), pal.step(&"blood", 1))
			x += w * 0.8
			i += 1

	# --- the Great Bronchus: the first ring --------------------------------------
	## A great ring of cartilage standing over the airway, open at the bottom
	## (cartilage rings are C-shaped): one thick band that swells and thins,
	## with grooves across it, a chip broken out, and lung grown over it.
	static func cartilage_gate(c, pal, o: Vector2, rng) -> void:
		var centre = o + Vector2(0, -148)
		var n = 90
		var prev = Vector2.ZERO
		var noise = FastNoiseLite.new()
		noise.seed = 3
		noise.frequency = 0.08
		for i in n + 1:
			var a = PI * 0.62 + i * (PI * 1.76) / n
			var wob = noise.get_noise_1d(i) * 7.0
			var p = centre + Vector2(cos(a) * (84.0 + wob), sin(a) * (142.0 + wob))
			if i > 0 and not (i >= 58 and i <= 61):  # A chip broken out.
				var r = 11.0 + noise.get_noise_1d(i * 3 + 50) * 3.0
				c.capsule(prev, p, r, r, &"rock_cartilage", {"lo": 1, "hi": 5, "dither": true, "z": i * 0.001})
				if i % 7 == 0:  # A groove across the band.
					var across = Vector2(cos(a), sin(a))
					c.stroke(p - across * r * 0.8, p + across * r * 0.8, pal.step(&"rock_cartilage", 1))
			prev = p
		# Feet spreading into the floor.
		for side in [-1.0, 1.0]:
			lumpy(c, o + Vector2(side * 78, -38), o + Vector2(side * 66, 0), 10.0, 15.0, &"rock_cartilage", rng, {"lo": 1, "hi": 4, "z": 2})
		# Lung grown over it in patches.
		for k in 5:
			var a0 = PI * 1.05 + rng.randf_range(0.0, PI * 0.9)
			for j in 5:
				var a = a0 + j * 0.05
				var p = centre + Vector2(cos(a) * 88.0, sin(a) * 146.0)
				c.ellipse(p + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), rng.randf_range(3, 6), rng.randf_range(2.5, 5), &"rock_alveolus", {"lo": 2, "hi": 5, "dither": true, "z": 3 + k * 0.1 + j * 0.01})

	# --- the Hives: lanterns of glowing sacs -------------------------------------
	## A crooked stalk carrying a bunch of see-through sacs, spores glowing in them.
	static func hive_lantern(c, pal, o: Vector2, rng) -> void:
		var bend = o + Vector2(rng.randf_range(-6, 6), -22)
		var top = o + Vector2(rng.randf_range(-3, 3), -40)
		lumpy(c, o, bend, 3.2, 2.2, &"rock_alveolus", rng, {"lo": 1, "hi": 4})
		lumpy(c, bend, top, 2.2, 1.4, &"rock_alveolus", rng, {"lo": 1, "hi": 4})
		var spots = [Vector2(-9, -6), Vector2(0, -12), Vector2(9, -5), Vector2(-4, 2), Vector2(6, 4), Vector2(-12, 5), Vector2(12, -12)]
		for i in spots.size():
			var p = top + spots[i] + Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
			var r = rng.randf_range(4.0, 6.5)
			c.capsule(top, p, 1.0, 1.0, &"rock_alveolus", {"lo": 2, "hi": 4, "z": 0.5})
			c.ellipse(p, r, r * 0.9, &"lung", {"alpha": 0.85, "dither": true, "z": 1 + i * 0.01})
			c.ellipse(p + Vector2(0.5, 1), r * 0.5, r * 0.4, &"glow_fungus", {"glow": true})

	# --- the Bellows: the pleural curtain ----------------------------------------
	## Torn sheets of the lung's lining hanging from the Bellows' roof: strips
	## that taper and wave, overlapping, with holes and wandering veins.
	static func pleura_curtain(c, pal, o: Vector2, rng) -> void:
		var x = -58.0
		var i = 0
		while x < 58.0:
			var w = rng.randf_range(5.0, 11.0)
			var length = rng.randf_range(90.0, 172.0)
			var pts = []
			var phase = rng.randf_range(0.0, TAU)
			for k in 9:
				var t = k / 8.0
				pts.append(o + Vector2(x + sin(t * 5.0 + phase) * 4.0 * t, t * length))
			for k in 8:
				var r0 = w * (1.0 - k / 9.0) * 0.6
				var r1 = w * (1.0 - (k + 1) / 9.0) * 0.6
				c.capsule(pts[k], pts[k + 1], maxf(r0, 0.6), maxf(r1, 0.6), &"lung", {"alpha": 0.7, "dither": true, "lo": 1, "hi": 3, "z": i * 0.01 + k * 0.0001, "tone": rng.randf_range(-0.15, 0.1)})
			if rng.randf() < 0.6:  # A vein wandering down it.
				var v = o + Vector2(x, 6)
				for k in 6:
					var q = v + Vector2(rng.randf_range(-2.5, 2.5), length * 0.12)
					c.stroke(v, q, pal.step(&"blood", 1))
					v = q
			x += w * rng.randf_range(0.6, 0.9)
			i += 1
		for k in 7:  # Where it is stuck to the roof: lumps of tissue.
			c.ellipse(o + Vector2(-58 + k * 19 + rng.randf_range(-4, 4), rng.randf_range(1, 4)), rng.randf_range(7, 12), rng.randf_range(4, 6), &"rock_alveolus", {"lo": 1, "hi": 3, "dither": true, "z": 5 + k * 0.01})

	# --- the High Aerie: a nest -------------------------------------------------
	## A bowl of ribs and bones laid every which way and bound with strips of
	## dried membrane; something glows faintly at the bottom.
	static func aerie_nest(c, pal, o: Vector2, rng) -> void:
		# The bowl's shape: the lower half of an ellipse.
		for i in 22:  # Ribs and long bones, crossing.
			var a = PI * rng.randf_range(0.05, 0.95)
			var p = o + Vector2(cos(a) * 50.0, -4.0 - sin(a) * 4.0 - rng.randf_range(0.0, 14.0))
			var dir = Vector2.from_angle(rng.randf_range(-0.9, 0.9) + (PI if rng.randf() < 0.5 else 0.0))
			var length = rng.randf_range(14.0, 28.0)
			c.capsule(p - dir * length * 0.5, p + dir * length * 0.5, 1.8, 1.3, &"bone", {"lo": 1, "z": i * 0.01})
		for i in 9:  # Strips of membrane binding it.
			var a = PI * (0.1 + i * 0.1)
			var p = o + Vector2(cos(a) * 46.0, -8.0 - rng.randf_range(0.0, 10.0))
			c.capsule(p, p + Vector2(rng.randf_range(-10, 10), rng.randf_range(-6, 6)), 2.4, 1.6, &"lung", {"lo": 0, "hi": 2, "dither": true, "z": 1 + i * 0.01})
		for i in 6:  # Small bones in it.
			var p = o + Vector2(rng.randf_range(-26, 26), rng.randf_range(-16, -8))
			c.capsule(p, p + Vector2(rng.randf_range(-5, 5), rng.randf_range(-2, 2)), 1.2, 0.9, &"bone", {"lo": 2, "z": 2 + i * 0.01})
		c.ellipse(o + Vector2(3, -12), 8, 3, &"glow_red", {"glow": true})

	# --- the Bellows-Kin's camp (week 50) ---------------------------------------
	## A frame of bone poles with kites of lung stretched to dry on it.
	static func kite_rack(c, pal, o: Vector2, rng) -> void:
		for x in [-30.0, 30.0]:
			lumpy(c, o + Vector2(x, 0), o + Vector2(x * 0.9, -60), 2.6, 2.0, &"bone", rng, {"lo": 1})
		lumpy(c, o + Vector2(-33, -56), o + Vector2(33, -58), 2.0, 2.0, &"bone", rng, {"lo": 1, "z": 1})
		for k in 3:  # Kites hung by their spars, each a fan of ribbed sheet.
			var top = o + Vector2(-20 + k * 20, -56)
			for i in 6:
				var t = i / 5.0
				var a = top + Vector2(-8 + t * 16, 2)
				var b = top + Vector2(-5 + t * 10 + rng.randf_range(-1, 1), 30 + sin(t * PI) * 6)
				c.capsule(a, b, 1.8, 1.0, &"lung", {"alpha": 0.82, "dither": true, "lo": 0, "hi": 2, "z": 2 + k + i * 0.01, "line": false})
			c.stroke(top + Vector2(0, 2), top + Vector2(0, 36), pal.step(&"bone", 1))

	## A drum: a ring of bone with lung skin stretched over it, struck to
	## keep time with the breath.
	static func breath_drum(c, pal, o: Vector2, rng) -> void:
		c.ellipse(o + Vector2(0, -16), 20, 15, &"wood", {"lo": 1, "dither": true})
		c.ellipse(o + Vector2(0, -29), 19, 5, &"lung", {"lo": 1, "hi": 3, "z": 1})
		for k in 6:  # Lacing.
			var x = -16.0 + k * 6.4
			c.stroke(o + Vector2(x, -27), o + Vector2(x * 0.9, -4), pal.step(&"kin", 1))
		for side in [-1.0, 1.0]:  # Feet.
			lumpy(c, o + Vector2(side * 14, -4), o + Vector2(side * 18, 0), 2.4, 2.0, &"bone", rng, {"lo": 1, "z": -1})
		c.capsule(o + Vector2(22, -34), o + Vector2(14, -28), 1.4, 2.4, &"bone", {"lo": 1, "z": 2})  # A beater.

	## A sling of membrane between two poles, sagging under its own weight.
	static func membrane_hammock(c, pal, o: Vector2, rng) -> void:
		for x in [-42.0, 42.0]:
			lumpy(c, o + Vector2(x, 0), o + Vector2(x, -46), 2.4, 1.8, &"bone", rng, {"lo": 1})
		var n = 14
		for i in n + 1:
			var t = float(i) / n
			var p = o + Vector2(lerpf(-40, 40, t), -40 + sin(t * PI) * 18)
			c.ellipse(p, 4.5, 3.0, &"lung", {"alpha": 0.85, "dither": true, "lo": 0, "hi": 2, "z": 1 + i * 0.01})
		c.ellipse(o + Vector2(4, -26), 10, 3.5, &"kin", {"lo": 1, "z": 2})  # A blanket.

	## A pole with a long tube of membrane that shows which way the breath blows.
	static func windsock(c, pal, o: Vector2, rng) -> void:
		lumpy(c, o, o + Vector2(1, -90), 2.2, 1.6, &"bone", rng, {"lo": 1})
		var a = o + Vector2(2, -86)
		for i in 8:
			var t = float(i) / 7.0
			var p = a + Vector2(4 + t * 24, 4 + t * t * 18)
			c.ellipse(p, 3.5 - t * 1.5, 4.0 - t * 2.0, &"kin" if i % 2 == 0 else &"lung", {"lo": 1, "hi": 3, "z": 1 + i * 0.01})

	# --- wind bones: chimes the breath plays (week 52) ---------------------------
	static func wind_bones(c, pal, o: Vector2, rng) -> void:
		var p = o
		for i in 7:
			var q = p + Vector2(rng.randf_range(-1.5, 1.5), 11.0)
			c.stroke(p, q, pal.step(&"hide", 1))
			c.ellipse(q + Vector2(0, 3), rng.randf_range(3.0, 5.0), 2.6, &"bone", {"lo": 1, "z": i * 0.01, "rot": rng.randf_range(-0.4, 0.4)})
			p = q + Vector2(0, 3)
