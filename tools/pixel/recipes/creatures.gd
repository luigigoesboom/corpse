extends RefCounted
## The Gut's creatures (D-028): Gut Leech, Bile Spitter, Rot Fly. 48 x 48
## frames, facing right, standing on the frame's bottom edge (flyers centred).
## Writes assets/art/creatures/<kind>/<kind>_<anim>.png and the glowing parts
## (eyes, glands) to <kind>/glow/<kind>_glow_<anim>.png.

const Kit := preload("res://tools/pixel/kit.gd")

const F := 48
const GROUND := 46.5


static func make(pal, out: Array) -> void:
	_write(pal, out, "gut_leech", leech_anims(), Callable(RecipeLeech, "draw"))
	_write(pal, out, "bile_spitter", spitter_anims(), Callable(RecipeSpitter, "draw"))
	_write(pal, out, "rot_fly", fly_anims(), Callable(RecipeFly, "draw"))


static func _write(pal, out: Array, kind: String, anims: Dictionary, draw: Callable) -> void:
	Kit.write(pal, out, kind, anims, draw, F)


# --- Gut Leech ----------------------------------------------------------------------
## w: wave phase (crawling), s: stretch, lift: head raised, mouth: open,
## hurt: flash, flat: dying (1 = alive, 0 = a puddle)

static func leech_anims() -> Dictionary:
	return {
		"idle": [{"w": 0.0}, {"w": 0.5}],
		"move": [{"w": 0.0, "crawl": true}, {"w": 0.25, "crawl": true}, {"w": 0.5, "crawl": true}, {"w": 0.75, "crawl": true}],
		"windup": [{"s": 0.88, "lift": 4.0}, {"s": 0.78, "lift": 8.0}],
		"attack": [{"s": 1.12, "lift": 2.0, "mouth": true}, {"s": 1.18, "lift": 0.0, "mouth": true}],
		"hurt": [{"s": 0.95, "hurt": true, "w": 0.3}],
		"die": [{"flat": 0.8}, {"flat": 0.55, "s": 1.05}, {"flat": 0.35, "s": 1.1}],
	}


class RecipeLeech:
	static func draw(c, pal, p: Dictionary) -> void:
		var s: float = p.get("s", 1.0)
		var flat: float = p.get("flat", 1.0)
		var tone: float = 0.25 if p.get("hurt", false) else 0.0
		var head = Vector2.ZERO
		var head_r = 0.0
		var belly: Array = []
		for seg in 7:
			var t = seg / 6.0
			var x = 24.0 + (-16.0 + t * 31.0) * s
			var wave = 0.0
			if p.get("crawl", false):
				wave = maxf(0.0, sin((t - p.w) * TAU)) * 3.5  # A hump travels head to tail.
			else:
				wave = sin(t * 4.0 + p.get("w", 0.0) * TAU) * 0.8
			var r = (3.5 + sin(t * PI * 0.9) * 3.5) * flat + 1.0
			var lift: float = p.get("lift", 0.0) * pow(t, 2.0)
			var centre = Vector2(x, GROUND - r - wave - lift)
			c.ellipse(centre, r + 1.2, r, &"leech", {"z": seg, "tone": tone, "lo": 0, "hi": 2, "seam": true})
			belly.append(centre + Vector2(0, r - 1.2))
			if seg == 6:
				head = centre
				head_r = r
		# The pale belly underneath, one smooth strip.
		for i in range(1, belly.size()):
			c.capsule(belly[i - 1], belly[i], 1.4 * flat + 0.4, 1.4 * flat + 0.4, &"leech", {"z": 7.5, "flat": true, "lo": 3, "hi": 3, "line": false, "tone": tone})
		# Mouth: a ring of teeth at the front.
		var mouth = head + Vector2(head_r + 0.5, 0.5)
		if p.get("mouth", false):
			c.ellipse(mouth, 2.5, 3.2, &"hide", {"z": 8, "lo": 0, "hi": 0, "line": false})
			for d in [Vector2i(0, -3), Vector2i(1, -1), Vector2i(1, 1), Vector2i(0, 3)]:
				c.detail(Vector2i(mouth.floor()) + d, pal.step(&"bone", -1))
		else:
			c.detail(Vector2i(mouth.floor()) + Vector2i(-1, 0), pal.step(&"hide", 0))
			c.detail(Vector2i(mouth.floor()) + Vector2i(-1, 1), pal.step(&"hide", 0))
		if flat >= 0.5:  # Two yellow eyes, glowing.
			var eye = Vector2i((head + Vector2(head_r * 0.2, -head_r * 0.55)).floor())
			c.detail(eye, pal.step(&"glow", 1), true)
			c.detail(eye + Vector2i(-2, 0), pal.step(&"glow", 1), true)


# --- Bile Spitter ---------------------------------------------------------------------
## sway, swell (charging), push (spitting), open (mouth), blob (spit leaving),
## hurt, droop (dying)

static func spitter_anims() -> Dictionary:
	return {
		"idle": [{"sway": 0.0}, {"sway": 1.0}],
		"windup": [{"swell": 1.0, "sway": -1.0}, {"swell": 2.0, "sway": -2.0}],
		"attack": [{"push": 3.0, "open": true, "blob": true}, {"push": 1.5, "open": true}],
		"hurt": [{"hurt": true, "sway": -2.0}],
		"die": [{"droop": 5.0}, {"droop": 10.0}, {"droop": 15.0}],
	}


class RecipeSpitter:
	static func draw(c, pal, p: Dictionary) -> void:
		var droop: float = p.get("droop", 0.0)
		var swell: float = p.get("swell", 0.0)
		var tone: float = 0.25 if p.get("hurt", false) else 0.0
		var bulb = Vector2(26.0 + p.get("sway", 0.0) + p.get("push", 0.0), 21.0 + droop)
		var r = 9.0 + swell - droop * 0.15
		# Roots and a bent stalk.
		c.ellipse(Vector2(23, GROUND - 1.0), 7.0, 2.2, &"fly", {"lo": 1, "hi": 2, "z": -1})
		var knee = Vector2(21.0 + p.get("sway", 0.0) * 0.5, 34.0 + droop * 0.4)
		c.capsule(Vector2(23, GROUND - 2.0), knee, 3.0, 2.4, &"fly", {"lo": 1, "z": -0.5, "tone": tone})
		c.capsule(knee, bulb + Vector2(-3, r - 3), 2.4, 2.8, &"fly", {"lo": 1, "z": -0.4, "tone": tone})
		# The bulb, and the bile gland swelling on its front.
		c.ellipse(bulb, r, r - 1.0, &"bulb", {"dither": true, "tone": tone})
		var gland = bulb + Vector2(r * 0.5, r * 0.45)
		c.ellipse(gland, 3.5 + swell * 0.6, 3.0 + swell * 0.4, &"bile", {"z": 1, "tone": tone})
		var mouth = Vector2i((bulb + Vector2(r - 1.5, -1.5)).floor())
		if p.get("open", false):
			for y in range(-2, 3):
				for x in range(-1, 2):
					c.detail(mouth + Vector2i(x, y), pal.step(&"hide", 0))
		else:
			c.detail(mouth, pal.step(&"hide", 0))
			c.detail(mouth + Vector2i(-1, 0), pal.step(&"hide", 0))
		if p.get("blob", false):
			c.circle(Vector2(mouth) + Vector2(6, 0.5), 2.6, &"bile", {"z": 2})
		if droop < 10.0:
			c.detail(Vector2i(gland.floor()) + Vector2i(-1, -1), pal.step(&"bile", -1), true)
			c.detail(Vector2i(gland.floor()) + Vector2i(0, -1), pal.step(&"bile", -1), true)


# --- Rot Fly ------------------------------------------------------------------------
## wing: up / down / back / limp, tilt (diving), hurt, fall (dying)

static func fly_anims() -> Dictionary:
	return {
		"move": [{"wing": "up"}, {"wing": "down"}],
		"attack": [{"wing": "back", "tilt": 2.0}, {"wing": "back", "tilt": 3.5}],
		"hurt": [{"wing": "down", "hurt": true}],
		"die": [{"wing": "limp", "fall": 3.0}, {"wing": "limp", "fall": 6.0}],
	}


class RecipeFly:
	static func draw(c, pal, p: Dictionary) -> void:
		var tilt: float = p.get("tilt", 0.0)
		var fall: float = p.get("fall", 0.0)
		var tone: float = 0.25 if p.get("hurt", false) else 0.0
		var body = Vector2(23, 24 + fall)
		var wing_opts = {"alpha": 0.75, "flat": true, "line": false}
		match p.wing:
			"up":
				c.ellipse(body + Vector2(-3, -8), 7.0, 3.2, &"wing", wing_opts.merged({"z": -1, "rot": -0.5}))
			"down":
				c.ellipse(body + Vector2(-3, 5), 7.0, 3.0, &"wing", wing_opts.merged({"z": 2, "rot": 0.4}))
			"back":
				c.ellipse(body + Vector2(-10, -2), 7.0, 2.4, &"wing", wing_opts.merged({"z": -1, "rot": -0.15}))
			"limp":
				c.ellipse(body + Vector2(-7, 3), 6.0, 2.2, &"wing", wing_opts.merged({"z": 2, "rot": 0.5, "alpha": 0.5}))
		# Abdomen, thorax, head.
		c.ellipse(body + Vector2(-5, 1 + tilt * 0.3), 6.0, 4.5, &"fly", {"z": 0, "tone": tone, "dither": true})
		c.ellipse(body + Vector2(2, tilt * 0.5), 5.0, 4.5, &"fly", {"z": 1, "tone": tone})
		var head = body + Vector2(8, tilt)
		c.circle(head, 3.6, &"fly", {"z": 1.5, "tone": tone})
		# Stripes on the abdomen, a proboscis, legs.
		for i in 2:
			c.stroke(body + Vector2(-7 + i * 3, -2 + tilt * 0.3), body + Vector2(-7 + i * 3, 4 + tilt * 0.3), pal.step(&"fly", 0))
		c.stroke(head + Vector2(2, 2), head + Vector2(5, 6), pal.step(&"fly", 0))
		for i in 2:
			c.stroke(body + Vector2(1 + i * 3, 4 + tilt * 0.5), body + Vector2(i * 3, 8 + tilt * 0.5), pal.step(&"fly", 1))
		if fall == 0.0:
			c.detail(Vector2i((head + Vector2(1, -1)).floor()), pal.step(&"glow_red", 0), true)
			c.detail(Vector2i((head + Vector2(2, -1)).floor()), pal.step(&"glow_red", 0), true)
