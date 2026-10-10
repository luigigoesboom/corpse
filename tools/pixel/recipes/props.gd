extends RefCounted
## Props, world objects and items (D-028). Every prop is redrawn in the same
## frame its scene already uses (size and floor point), so the scenes need no
## changes: assets/art/props/<name>_body.png (lit), _glow.png (unshaded) and
## _cloth.png (light greys, tinted in game: banners, mural panels). Items are
## 16 x 16 icons in assets/art/items/<id>.png standing on the bottom edge.
##
## In each draw function `o` is the floor point (the scene's origin) in the
## canvas; draw up from it (negative y is up).

const Canvas := preload("res://tools/pixel/canvas.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")
const OUT := "res://assets/art/props/"
const ITEMS := "res://assets/art/items/"

## name: [width, height, floor point x, floor point y, outputs]
## (outputs: b = body, g = glow, c = cloth; only those the scene uses).
const FRAMES := {
	"banner": [26, 73, 2, 71, "bc"], "torn_banner": [24, 63, 2, 61, "bc"],
	"bell": [47, 60, 23, 58, "b"], "bile_cistern": [37, 38, 18, 36, "bg"],
	"candles": [33, 26, 15, 24, "bg"], "drying_rack": [67, 49, 33, 47, "b"],
	"flesh_plot": [83, 24, 41, 22, "b"], "reliquary": [43, 39, 21, 37, "bg"],
	"shrine": [67, 71, 33, 69, "bg"], "tender_lamp": [18, 55, 3, 53, "bg"],
	"tent": [111, 63, 55, 61, "b"],
	"bone_heap": [47, 22, 23, 20, "b"], "broken_wall": [67, 55, 33, 53, "b"],
	"cold_hearth": [43, 13, 21, 11, "bg"], "rubble": [61, 19, 29, 17, "b"],
	"toppled_pillar": [75, 17, 35, 15, "b"],
	"glow_fungus": [26, 25, 11, 23, "bg"], "heart_root_visual": [85, 65, 41, 63, "bg"],
	"ichor_clot": [27, 15, 13, 13, "bg"],
	"bile_glob": [15, 15, 7, 7, "g"], "bile_puddle": [43, 10, 21, 6, "g"],
	"shockwave": [31, 19, 15, 17, "g"], "acid_projectile": [19, 13, 9, 6, "g"],
	"placeholder_npc_visual": [27, 35, 13, 33, "b"], "training_dummy_visual": [35, 63, 17, 61, "b"],
	# Drawn by code at fixed sizes (carcass.gd, key_cache.gd, guard_post.gd, lore_piece.gd).
	"carcass": [34, 14, 17, 14, "b"], "key_reliquary": [36, 38, 18, 38, "b"], "key_nest": [66, 18, 33, 18, "b"],
	"valve_key": [14, 14, 7, 14, "b"], "brazier": [22, 20, 11, 20, "b"], "latch": [10, 26, 5, 26, "b"],
	"grate": [130, 12, 65, 4, "b"], "mural": [62, 60, 31, 60, "bc"], "tablet": [26, 30, 13, 30, "b"],
}


static func make(pal, out: Array) -> void:
	for name in FRAMES:
		var f: Array = FRAMES[name]
		var c = Canvas.new(f[0], f[1], pal)
		var o = Vector2(f[2], f[3])
		var cloth = Canvas.new(f[0], f[1], pal)
		Callable(Draw, name).call(c, cloth, pal, o)
		var img: Dictionary = c.render()
		var outs: String = f[4]
		if "b" in outs:
			Sheet.save(img.body, OUT + name + "_body.png")
		if "g" in outs:
			Sheet.save(img.glow, OUT + name + "_glow.png")
		var cloth_img: Image = null
		if "c" in outs:
			cloth_img = cloth.render().body
			Sheet.save(cloth_img, OUT + name + "_cloth.png")
		var shown: Image = img.body.duplicate()
		if cloth_img:
			shown.blend_rect(cloth_img, Rect2i(Vector2i.ZERO, cloth_img.get_size()), Vector2i.ZERO)
		out.append({"name": name, "body": shown, "glow": img.glow})
	_flames(pal, out)
	_items(pal, out)


## The brazier's flame, four frames of 16 x 18 (guard_post.gd animates it).
static func _flames(pal, out: Array) -> void:
	var frames = []
	for i in 4:
		var c = Canvas.new(16, 18, pal)
		var sway: float = [0.0, 1.0, 0.0, -1.0][i]
		var tall: float = [15.0, 13.0, 16.0, 14.0][i]
		c.capsule(Vector2(8, 16), Vector2(8 + sway * 2, 17 - tall), 5.0, 0.8, &"glow", {"glow": true})
		c.capsule(Vector2(8, 16), Vector2(8 + sway, 19 - tall * 0.7), 2.6, 0.5, &"glow", {"glow": true, "z": 1})
		var img: Dictionary = c.render()
		var glow: Image = img.glow
		# Outer flame orange, inner core pale.
		for y in 18:
			for x in 16:
				var p = glow.get_pixel(x, y)
				if p.a > 0.0:
					var inner = absf(x - 8 - sway) < 2.0 and y > 17 - tall * 0.7
					glow.set_pixel(x, y, pal.step(&"glow", 2) if inner else pal.step(&"glow", 0))
		frames.append(glow)
	var strip = Sheet.strip(frames)
	Sheet.save(strip, OUT + "brazier_flame_glow.png")
	out.append({"name": "flame", "body": Image.create(64, 18, false, Image.FORMAT_RGBA8), "glow": strip})


static func _items(pal, out: Array) -> void:
	var icons = {
		"bile_bulb": func(c): c.ellipse(Vector2(8, 10), 5.5, 5.0, &"bile"); c.capsule(Vector2(8, 5), Vector2(9, 1.5), 1.2, 0.8, &"leech", {"lo": 1}); c.detail(Vector2i(6, 8), pal.step(&"bile", -1)),
		"bone_shard": func(c): c.capsule(Vector2(4, 14), Vector2(12, 2), 2.2, 0.7, &"bone", {"lo": 1}); c.capsule(Vector2(7, 10), Vector2(10, 9), 1.0, 0.6, &"bone", {"lo": 1, "z": 1}),
		"breath_sac": func(c): c.ellipse(Vector2(8, 10), 5.5, 4.5, &"lung"); c.capsule(Vector2(8, 5.5), Vector2(7, 1.5), 1.4, 1.0, &"lung", {"lo": 0, "hi": 1}); c.stroke(Vector2(5, 10), Vector2(11, 9), pal.step(&"lung", 0)),
		"artifact": func(c): c.ellipse(Vector2(8, 9.5), 5, 5.5, &"gold"); c.circle(Vector2(8, 8.5), 2.0, &"blood", {"z": 1, "lo": 2}),
		"unknown": func(c): c.ellipse(Vector2(8, 10), 5, 4.5, &"ash", {"lo": 1, "dither": true}),
		"valve_key_gut": func(c): Draw.valve_key(c, null, pal, Vector2(7, 14)),
	}
	for id in icons:
		var c = Canvas.new(16, 16, pal)
		icons[id].call(c)
		var img: Dictionary = c.render()
		Sheet.save(img.body, ITEMS + id + ".png")
		out.append({"name": "item_" + id, "body": img.body})


class Draw:
	# --- settlements ---------------------------------------------------------------
	static func banner(c, cloth, pal, o: Vector2) -> void:
		c.capsule(o + Vector2(1, 0), o + Vector2(1, -68), 1.4, 1.2, &"wood", {"lo": 1})
		c.circle(o + Vector2(1, -69), 2.0, &"bone", {"lo": 1, "z": 1})
		cloth.polygon(PackedVector2Array([o + Vector2(2, -66), o + Vector2(23, -64), o + Vector2(22, -36), o + Vector2(17, -30),
			o + Vector2(13, -36), o + Vector2(8, -28), o + Vector2(2, -34)]), &"tint", {"lo": 1})
		cloth.circle(o + Vector2(12, -50), 4.0, &"tint", {"lo": 0, "hi": 0, "z": 1})  # A mark: their sign.

	static func torn_banner(c, cloth, pal, o: Vector2) -> void:
		c.capsule(o + Vector2(1, 0), o + Vector2(2, -46), 1.4, 1.1, &"wood", {"lo": 0, "hi": 2})
		c.capsule(o + Vector2(2, -46), o + Vector2(6, -58), 1.1, 0.8, &"wood", {"lo": 0, "hi": 2})  # Snapped and bent.
		cloth.polygon(PackedVector2Array([o + Vector2(3, -52), o + Vector2(19, -50), o + Vector2(14, -44), o + Vector2(20, -38),
			o + Vector2(10, -38), o + Vector2(12, -30), o + Vector2(3, -34)]), &"tint", {"lo": 0, "hi": 2, "dither": true})

	static func bell(c, cloth, pal, o: Vector2) -> void:
		for side in [-1.0, 1.0]:  # Two bone posts, leaning in.
			c.capsule(o + Vector2(side * 19, 0), o + Vector2(side * 16, -50), 2.4, 1.8, &"bone", {"lo": 1})
		c.capsule(o + Vector2(-20, -50), o + Vector2(20, -50), 2.2, 2.2, &"bone", {"lo": 1, "z": 1})
		c.capsule(o + Vector2(0, -50), o + Vector2(0, -42), 0.8, 0.8, &"wood", {"lo": 0, "z": 1.5})
		c.polygon(PackedVector2Array([o + Vector2(-5, -42), o + Vector2(5, -42), o + Vector2(10, -22), o + Vector2(-10, -22)]), &"gold", {"z": 2})
		c.ellipse(o + Vector2(0, -22), 10.5, 2.5, &"gold", {"z": 2.1, "lo": 1})
		c.circle(o + Vector2(0, -18), 2.0, &"bone", {"z": 2.2})  # A clapper of knucklebone.

	static func bile_cistern(c, cloth, pal, o: Vector2) -> void:
		c.polygon(PackedVector2Array([o + Vector2(-15, -30), o + Vector2(15, -30), o + Vector2(13, 0), o + Vector2(-13, 0)]), &"wood", {"lo": 1})
		for x in [-9, -3, 3, 9]:
			c.stroke(o + Vector2(x, -29), o + Vector2(x * 0.9, -1), pal.step(&"wood", 0))
		for y in [-24, -8]:
			c.capsule(o + Vector2(-15, y), o + Vector2(15, y), 1.2, 1.2, &"bone", {"lo": 1, "z": 1})
		c.ellipse(o + Vector2(0, -31), 14, 3.5, &"bile", {"glow": true})
		c.circle(o + Vector2(-5, -32), 1.5, &"bile", {"glow": true, "z": 1})

	static func candles(c, cloth, pal, o: Vector2) -> void:
		var hs = [10.0, 16.0, 7.0, 13.0, 9.0]
		for i in hs.size():
			var x = -12.0 + i * 6.0
			var h: float = hs[i]
			c.capsule(o + Vector2(x, 0), o + Vector2(x, -h), 2.2, 2.0, &"bone", {"lo": 1, "z": i})
			c.capsule(o + Vector2(x + 1.5, -h + 1), o + Vector2(x + 2, -h + 5), 0.9, 0.7, &"bone", {"lo": 2, "z": i + 0.5})  # Drip.
			c.capsule(o + Vector2(x, -h - 1), o + Vector2(x, -h - 5), 1.6, 0.5, &"glow", {"glow": true})

	static func drying_rack(c, cloth, pal, o: Vector2) -> void:
		for side in [-1.0, 1.0]:
			c.capsule(o + Vector2(side * 30, 0), o + Vector2(side * 27, -42), 1.8, 1.4, &"wood", {"lo": 1})
		c.capsule(o + Vector2(-31, -40), o + Vector2(31, -40), 1.4, 1.4, &"wood", {"lo": 1, "z": 1})
		var rng = RandomNumberGenerator.new()
		rng.seed = 5
		for i in 7:  # Strips of gut meat, drying.
			var x = -22.0 + i * 7.5
			c.capsule(o + Vector2(x, -40), o + Vector2(x + rng.randf_range(-1, 1), -40 + rng.randf_range(10, 22)), 2.2, 1.2, &"flesh" if i % 2 == 0 else &"blood", {"lo": 1, "hi": 4, "z": 2 + i * 0.01})

	static func flesh_plot(c, cloth, pal, o: Vector2) -> void:
		c.polygon(PackedVector2Array([o + Vector2(-40, 0), o + Vector2(-37, -7), o + Vector2(37, -7), o + Vector2(40, 0)]), &"flesh", {"lo": 1, "hi": 3, "dither": true})
		var rng = RandomNumberGenerator.new()
		rng.seed = 9
		for i in 9:  # Bulbs growing in rows.
			var x = -32.0 + i * 8.0
			var h = rng.randf_range(4, 9)
			c.capsule(o + Vector2(x, -6), o + Vector2(x + rng.randf_range(-1, 1), -6 - h), 1.0, 0.8, &"leech", {"lo": 1, "z": 1 + i * 0.01})
			c.circle(o + Vector2(x, -7 - h), 2.4, &"lung" if i % 3 else &"bile", {"z": 1.5 + i * 0.01})

	static func reliquary(c, cloth, pal, o: Vector2) -> void:
		for x in [-15, 15]:
			c.capsule(o + Vector2(x, 0), o + Vector2(x, -10), 1.6, 1.6, &"bone", {"lo": 1})
		c.rect(Rect2(o + Vector2(-19, -34), Vector2(38, 25)), &"gold", {"z": 1})
		c.rect(Rect2(o + Vector2(-13, -29), Vector2(26, 15)), &"outline", {"z": 2, "flat": true})
		c.circle(o + Vector2(0, -22), 4.0, &"glow", {"glow": true})
		for x in [-19, 19]:
			c.capsule(o + Vector2(x, -34), o + Vector2(x, -38), 1.0, 0.5, &"gold", {"lo": 2, "z": 1.5})

	static func shrine(c, cloth, pal, o: Vector2) -> void:
		c.rect(Rect2(o + Vector2(-31, -9), Vector2(62, 9)), &"bone", {"lo": 1, "dither": true})
		c.rect(Rect2(o + Vector2(-21, -20), Vector2(42, 11)), &"bone", {"lo": 1, "z": 0.5})
		for side in [-1.0, 1.0]:  # Ribs arching over the relic.
			var p = o + Vector2(side * 20, -20)
			for i in 8:
				var a = PI * 0.5 * (i + 1) / 8.0
				var q = o + Vector2(side * cos(a) * 20, -20 - sin(a) * 44)
				c.capsule(p, q, 2.4 - i * 0.12, 2.3 - i * 0.12, &"bone", {"lo": 1, "z": 1 + i * 0.001})
				p = q
		c.circle(o + Vector2(0, -40), 6.0, &"glow", {"glow": true})
		c.capsule(o + Vector2(0, -34), o + Vector2(0, -21), 1.2, 1.6, &"gold", {"z": 2})

	static func tender_lamp(c, cloth, pal, o: Vector2) -> void:
		c.capsule(o + Vector2(0, 0), o + Vector2(0, -50), 1.4, 1.2, &"wood", {"lo": 1})
		c.capsule(o + Vector2(0, -48), o + Vector2(10, -48), 1.0, 1.0, &"wood", {"lo": 1, "z": 1})
		c.capsule(o + Vector2(10, -48), o + Vector2(10, -42), 0.5, 0.5, &"wood", {"lo": 0, "z": 1})
		c.ellipse(o + Vector2(10, -36), 4.5, 6.0, &"bulb", {"z": 2, "lo": 1})  # A bladder lantern.
		c.ellipse(o + Vector2(10, -36), 2.6, 3.6, &"glow", {"glow": true})

	static func tent(c, cloth, pal, o: Vector2) -> void:
		c.capsule(o + Vector2(-50, 0), o + Vector2(0, -56), 1.6, 1.6, &"bone", {"lo": 1, "z": -1})
		c.capsule(o + Vector2(50, 0), o + Vector2(0, -56), 1.6, 1.6, &"bone", {"lo": 1, "z": -1})
		c.polygon(PackedVector2Array([o + Vector2(-52, 0), o + Vector2(-2, -55), o + Vector2(2, -55), o + Vector2(52, 0)]), &"hide", {"lo": 1, "hi": 3, "dither": true})
		c.polygon(PackedVector2Array([o + Vector2(-10, 0), o + Vector2(0, -26), o + Vector2(10, 0)]), &"outline", {"z": 1, "flat": true})
		for i in 3:  # Stitched patches.
			var at = o + Vector2(-30 + i * 22, -12 - (i % 2) * 14)
			c.stroke(at, at + Vector2(7, -1), pal.step(&"hide", 0))
			c.stroke(at + Vector2(0, 3), at + Vector2(7, 2), pal.step(&"hide", 0))
		c.capsule(o + Vector2(-3, -56), o + Vector2(-6, -61), 1.0, 0.5, &"bone", {"lo": 1, "z": 2})
		c.capsule(o + Vector2(3, -56), o + Vector2(6, -61), 1.0, 0.5, &"bone", {"lo": 1, "z": 2})

	# --- ruins ---------------------------------------------------------------------
	static func bone_heap(c, cloth, pal, o: Vector2) -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 3
		c.ellipse(o + Vector2(0, -4), 20, 6, &"ash", {"lo": 0, "hi": 1, "dither": true})
		for i in 9:
			var a = o + Vector2(rng.randf_range(-18, 14), rng.randf_range(-12, -2))
			c.capsule(a, a + Vector2(rng.randf_range(5, 10), rng.randf_range(-4, 4)), 1.6, 1.2, &"bone", {"lo": 1, "z": 1 + i * 0.01})
		c.ellipse(o + Vector2(4, -14), 5, 4.5, &"bone", {"lo": 1, "z": 2})  # A broken skull, eyeless.

	static func broken_wall(c, cloth, pal, o: Vector2) -> void:
		c.polygon(PackedVector2Array([o + Vector2(-31, 0), o + Vector2(-31, -38), o + Vector2(-20, -50), o + Vector2(-6, -44),
			o + Vector2(4, -52), o + Vector2(16, -34), o + Vector2(31, -30), o + Vector2(31, 0)]), &"ash", {"lo": 0, "hi": 2, "dither": true})
		for y in [-10, -22, -34]:
			c.stroke(o + Vector2(-30, y), o + Vector2(30, y + 1), pal.step(&"ash", 0))
		c.rect(Rect2(o + Vector2(-8, -30), Vector2(10, 12)), &"outline", {"z": 1, "flat": true})  # A window.
		c.capsule(o + Vector2(-26, -2), o + Vector2(-18, -6), 3.5, 2.5, &"ash", {"lo": 1, "z": 2})

	static func cold_hearth(c, cloth, pal, o: Vector2) -> void:
		for i in 7:
			c.circle(o + Vector2(-18 + i * 6, -2.5 - (1 if i % 2 else 0)), 3.2, &"ash", {"lo": 1, "z": i * 0.01})
		c.ellipse(o + Vector2(0, -3), 11, 2.5, &"outline", {"z": 1, "flat": true})
		for x in [-5, 0, 4]:
			c.circle(o + Vector2(x, -3), 1.0, &"glow_red", {"glow": true})

	static func rubble(c, cloth, pal, o: Vector2) -> void:
		var rng = RandomNumberGenerator.new()
		rng.seed = 7
		for i in 8:
			var at = o + Vector2(rng.randf_range(-25, 25), -rng.randf_range(2, 6))
			var r = rng.randf_range(2.5, 6.0)
			c.ellipse(at + Vector2(0, -r * 0.4), r * 1.2, r * 0.8, &"ash", {"lo": 0, "hi": 2, "z": i * 0.01})

	static func toppled_pillar(c, cloth, pal, o: Vector2) -> void:
		for i in 3:
			var x = -28.0 + i * 22.0
			c.capsule(o + Vector2(x, -6), o + Vector2(x + 17, -5 - (i % 2)), 6.0, 6.0, &"bone", {"lo": 0, "hi": 2, "z": i, "dither": true})
			c.stroke(o + Vector2(x + 17, -11), o + Vector2(x + 17, -1), pal.step(&"bone", 0))

	# --- the world -----------------------------------------------------------------
	static func glow_fungus(c, cloth, pal, o: Vector2) -> void:
		var spots = [[-6.0, 9.0, 4.5], [1.0, 16.0, 6.0], [8.0, 7.0, 3.5]]
		for i in spots.size():
			var s: Array = spots[i]
			c.capsule(o + Vector2(s[0], 0), o + Vector2(s[0], -s[1]), 1.2, 1.0, &"bone", {"lo": 1, "z": i})
			c.ellipse(o + Vector2(s[0], -s[1]), s[2], s[2] * 0.55, &"glow_fungus", {"glow": true})

	static func heart_root_visual(c, cloth, pal, o: Vector2) -> void:
		for side in [-1.0, 1.0]:  # Roots biting into the floor.
			for k in 2:
				c.capsule(o + Vector2(side * 4, -10), o + Vector2(side * (24 + k * 12), 0), 4.0 - k, 1.2, &"flesh", {"lo": 2, "z": k * 0.1})
		c.capsule(o + Vector2(0, 0), o + Vector2(2, -48), 9.0, 4.0, &"flesh", {"lo": 1, "dither": true, "z": 1})
		c.ellipse(o + Vector2(1, -30), 11, 13, &"flesh", {"lo": 2, "z": 1.5, "dither": true})
		for k in 4:  # Veins up the trunk.
			c.stroke(o + Vector2(-6 + k * 4, -4), o + Vector2(-2 + k * 2, -44), pal.step(&"blood", 1))
		c.ellipse(o + Vector2(1, -30), 6, 7, &"blood", {"glow": true})
		c.circle(o + Vector2(2, -52), 3, &"flesh", {"lo": 2, "z": 2})

	static func ichor_clot(c, cloth, pal, o: Vector2) -> void:
		c.ellipse(o + Vector2(0, -5), 11, 5.5, &"blood", {"lo": 0, "hi": 1, "dither": true})
		c.ellipse(o + Vector2(-2, -6), 5, 2.5, &"blood", {"glow": true})

	static func bile_glob(c, cloth, pal, o: Vector2) -> void:
		c.circle(o, 6.0, &"bile", {"glow": true})

	static func bile_puddle(c, cloth, pal, o: Vector2) -> void:
		c.ellipse(o + Vector2(0, 0), 20, 3.0, &"bile", {"glow": true})
		c.circle(o + Vector2(-8, -2), 2.5, &"bile", {"glow": true})
		c.circle(o + Vector2(9, -1.5), 1.8, &"bile", {"glow": true})

	static func shockwave(c, cloth, pal, o: Vector2) -> void:
		c.polygon(PackedVector2Array([o + Vector2(-14, 0), o + Vector2(-6, -12), o + Vector2(0, -16), o + Vector2(5, -10), o + Vector2(14, 0)]), &"blood", {"glow": true})

	static func acid_projectile(c, cloth, pal, o: Vector2) -> void:
		c.capsule(o + Vector2(-8, 0), o + Vector2(5, 0), 1.5, 4.5, &"bile", {"glow": true})

	static func placeholder_npc_visual(c, cloth, pal, o: Vector2) -> void:
		# A hunched hermit in rags, a bone mask over its face.
		c.capsule(o + Vector2(-4, -1), o + Vector2(-2, -10), 1.2, 1.0, &"skin", {"z": -1, "tone": -0.2})
		c.capsule(o + Vector2(3, -1), o + Vector2(2, -10), 1.2, 1.0, &"skin", {"z": -1})
		c.polygon(PackedVector2Array([o + Vector2(-10, -6), o + Vector2(-8, -22), o + Vector2(2, -27), o + Vector2(8, -18), o + Vector2(9, -6)]), &"rag", {"lo": 1, "dither": true})
		c.ellipse(o + Vector2(7, -24), 4.5, 6.5, &"bone", {"lo": 1, "z": 1, "rot": 0.4})
		c.stroke(o + Vector2(9, -29), o + Vector2(10, -20), pal.step(&"bone", 0))

	static func training_dummy_visual(c, cloth, pal, o: Vector2) -> void:
		c.capsule(o + Vector2(0, 0), o + Vector2(0, -56), 1.8, 1.6, &"wood", {"lo": 1})
		c.capsule(o + Vector2(-14, -40), o + Vector2(14, -40), 1.4, 1.4, &"wood", {"lo": 1, "z": 1})
		c.ellipse(o + Vector2(0, -32), 9, 13, &"hide", {"lo": 1, "dither": true, "z": 2})
		c.ellipse(o + Vector2(1, -51), 6, 7, &"hide", {"lo": 1, "z": 2})
		for y in [-36, -30, -24]:
			c.stroke(o + Vector2(-6, y), o + Vector2(6, y + 1), pal.step(&"hide", 0))
		c.stroke(o + Vector2(-2, -50), o + Vector2(4, -50), pal.step(&"hide", 0))  # A stitched slit, no eyes.

	static func carcass(c, cloth, pal, o: Vector2) -> void:
		c.ellipse(o + Vector2(0, -5), 15, 5, &"flesh", {"lo": 2, "dither": true})
		c.stroke(o + Vector2(-8, -7), o + Vector2(8, -8), pal.step(&"blood", 2))
		for i in 4:
			c.capsule(o + Vector2(-6 + i * 4, -8), o + Vector2(-6 + i * 4, -11), 0.9, 0.6, &"bone", {"z": 1})

	static func key_reliquary(c, cloth, pal, o: Vector2) -> void:
		for x in [-12, 12]:
			c.capsule(o + Vector2(x, 0), o + Vector2(x, -12), 1.6, 1.6, &"bone", {"lo": 1})
		c.rect(Rect2(o + Vector2(-15, -34), Vector2(30, 23)), &"gold", {"z": 1})
		c.rect(Rect2(o + Vector2(-11, -30), Vector2(22, 14)), &"outline", {"z": 2, "flat": true})

	static func key_nest(c, cloth, pal, o: Vector2) -> void:
		c.ellipse(o + Vector2(0, -5), 30, 6, &"hide", {"lo": 1, "dither": true})
		var rng = RandomNumberGenerator.new()
		rng.seed = 13
		for i in 8:
			var x = -24.0 + i * 7.0
			c.capsule(o + Vector2(x, -3), o + Vector2(x + rng.randf_range(-3, 3), -rng.randf_range(9, 15)), 1.6, 0.6, &"bone", {"lo": 1, "z": 1 + i * 0.01})
		c.ellipse(o + Vector2(0, -7), 11, 3, &"hide", {"lo": 0, "hi": 0, "z": 2, "flat": true})

	static func valve_key(c, cloth, pal, o: Vector2) -> void:
		var centre = o + Vector2(0, -7)
		c.circle(centre, 6.0, &"bone", {"lo": 1})
		c.circle(centre, 3.0, &"blood", {"lo": 0, "hi": 0, "z": 1, "flat": true})
		for a in [0.0, 1.6, 3.2, 4.7]:
			c.detail(Vector2i((centre + Vector2.from_angle(a) * 3.0).floor()), pal.step(&"bone", -1))

	static func brazier(c, cloth, pal, o: Vector2) -> void:
		c.ellipse(o + Vector2(0, -15), 10, 4, &"bone", {"lo": 1})
		c.ellipse(o + Vector2(0, -17), 7, 1.5, &"outline", {"z": 1, "flat": true})
		c.capsule(o + Vector2(0, -11), o + Vector2(0, -1), 2.0, 1.6, &"bone", {"lo": 1, "z": -1})
		c.ellipse(o + Vector2(0, -1), 5, 1.5, &"bone", {"lo": 1, "z": -0.5})

	static func latch(c, cloth, pal, o: Vector2) -> void:
		c.rect(Rect2(o + Vector2(-3, -6), Vector2(6, 6)), &"ash", {"lo": 1})
		c.capsule(o + Vector2(0, -5), o + Vector2(0, -21), 1.2, 1.0, &"bone", {"lo": 1, "z": 1})
		c.circle(o + Vector2(0, -22), 2.5, &"bone", {"lo": 1, "z": 2})

	static func grate(c, cloth, pal, o: Vector2) -> void:
		c.capsule(o + Vector2(-63, -2), o + Vector2(63, -2), 1.6, 1.6, &"bone", {"lo": 1})
		c.capsule(o + Vector2(-63, 4), o + Vector2(63, 4), 1.2, 1.2, &"bone", {"lo": 0, "hi": 2})
		for i in 16:
			var x = -60.0 + i * 8.0
			c.capsule(o + Vector2(x, -3), o + Vector2(x, 6), 1.8, 1.6, &"bone", {"lo": 1, "z": 1})
			c.detail(Vector2i((o + Vector2(x, 1)).floor()), pal.step(&"blood", 1))  # Sinew lashing.

	static func mural(c, cloth, pal, o: Vector2) -> void:
		c.rect(Rect2(o + Vector2(-30, -59), Vector2(60, 58)), &"ash", {"lo": 0, "hi": 2, "dither": true})
		c.rect(Rect2(o + Vector2(-30, -4), Vector2(60, 4)), &"ash", {"lo": 0, "hi": 0, "z": 1, "flat": true})
		for i in 4:  # Four panels, painted in their people's color.
			var r = Rect2(o + Vector2(-26 + (i % 2) * 27, -55 + (i / 2) * 25), Vector2(25, 23))
			cloth.rect(r, &"tint", {"lo": 0, "hi": 1, "dither": true})
			var mid = r.get_center()
			cloth.capsule(mid + Vector2(-4 + i, 6), mid + Vector2(-4 + i, -5), 2.0, 1.6, &"tint", {"lo": 3, "hi": 3, "z": 1})  # A figure.
			cloth.circle(mid + Vector2(-4 + i, -7), 2.4, &"tint", {"lo": 3, "hi": 3, "z": 1})
			cloth.capsule(mid + Vector2(2, 7), mid + Vector2(10, 5 - i * 2), 1.0, 1.0, &"tint", {"lo": 2, "hi": 2, "z": 1})

	static func tablet(c, cloth, pal, o: Vector2) -> void:
		c.polygon(PackedVector2Array([o + Vector2(-12, 0), o + Vector2(-10, -22), o + Vector2(-2, -29), o + Vector2(9, -25), o + Vector2(12, 0)]), &"bone", {"lo": 1, "dither": true})
		for i in 5:
			c.stroke(o + Vector2(-7, -20 + i * 4), o + Vector2(6 - (i % 2) * 3, -21 + i * 4), pal.step(&"bone", 0))
