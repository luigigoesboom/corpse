extends RefCounted
## The Gullet Matron (D-026, D-028): a bloated bile-worm mother. 128 x 128
## frames, facing right, lying on the frame's bottom edge. Seven segments
## from tail to head; each pose bends, stretches and squashes them.
## Writes assets/art/creatures/gullet_matron/gullet_matron_<anim>.png and
## the glowing parts (eyes, bile bladder) to glow/gullet_matron_glow_<anim>.png.

const Canvas := preload("res://tools/pixel/canvas.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")

const F := 128
const GROUND := 126.5


## lift: head raised (px), stretch / squash: body scale x / y, mouth: 0..1,
## tail: tail raised, sway: crawl phase 0..3, hurt: flash, dead: eyes shut
static func pose(lift: float, stretch: float, squash: float, mouth: float, tail: float, sway: int, hurt := false, dead := false) -> Dictionary:
	return {"lift": lift, "stretch": stretch, "squash": squash, "mouth": mouth, "tail": tail, "sway": sway, "hurt": hurt, "dead": dead}


static func anims() -> Dictionary:
	return {
		"idle": [pose(0, 1, 1, 0.1, 0, 0), pose(1, 1, 1.02, 0.1, 0, 1), pose(2, 1, 1.03, 0.15, 0, 2), pose(1, 1, 1.01, 0.1, 0, 3)],
		"move": [pose(0, 1.05, 0.97, 0.1, 0, 0), pose(2, 0.97, 1.03, 0.1, 0, 1), pose(0, 1.05, 0.97, 0.1, 0, 2), pose(2, 0.97, 1.03, 0.1, 0, 3)],
		"windup": [pose(10, 0.92, 1.05, 0.3, 0, 0), pose(22, 0.86, 1.08, 0.6, 0, 1), pose(28, 0.84, 1.1, 0.9, 0, 1)],
		"lunge": [pose(4, 1.28, 0.86, 1.0, 0, 0), pose(2, 1.32, 0.84, 1.0, 0, 1)],
		"spit": [pose(18, 0.95, 1.05, 0.5, 0, 0), pose(24, 0.95, 1.06, 1.0, 0, 1), pose(14, 1.0, 1.0, 0.7, 0, 2)],
		"leap": [pose(6, 0.9, 1.15, 0.4, 6, 0), pose(10, 0.92, 1.12, 0.6, 10, 1)],
		"slam": [pose(0, 1.25, 0.72, 0.8, 0, 0), pose(0, 1.15, 0.82, 0.5, 0, 1)],
		"sweep": [pose(4, 0.95, 1.0, 0.3, 22, 0), pose(2, 1.0, 0.95, 0.4, 12, 1), pose(2, 1.05, 0.92, 0.3, -4, 2)],
		"stagger": [pose(-4, 1.08, 0.86, 0.2, -2, 0, true), pose(-6, 1.1, 0.84, 0.3, -3, 1, true)],
		"roar": [pose(20, 0.9, 1.1, 0.8, 4, 0), pose(30, 0.86, 1.14, 1.0, 6, 1), pose(30, 0.86, 1.14, 1.0, 6, 2)],
		"hurt": [pose(-2, 1.04, 0.94, 0.4, 0, 0, true)],
		"die": [pose(10, 0.95, 1.0, 1.0, 0, 0, true), pose(0, 1.1, 0.8, 0.6, -2, 1, true), pose(-6, 1.2, 0.6, 0.3, -4, 2, true, true),
			pose(-8, 1.25, 0.45, 0.1, -4, 3, true, true)],
	}


static func make(pal, out: Array) -> void:
	var all = anims()
	for anim in all:
		var bodies = []
		var glows = []
		for p in all[anim]:
			var c = Canvas.new(F, F, pal)
			draw(c, pal, p)
			var img: Dictionary = c.render()
			bodies.append(img.body)
			glows.append(img.glow)
		var body = Sheet.strip(bodies)
		var glow = Sheet.strip(glows)
		Sheet.save(body, "res://assets/art/creatures/gullet_matron/gullet_matron_%s.png" % anim)
		Sheet.save(glow, "res://assets/art/creatures/gullet_matron/glow/gullet_matron_glow_%s.png" % anim)
		out.append({"name": "gullet_matron_%s" % anim, "body": body, "glow": glow})


static func draw(c, pal, p: Dictionary) -> void:
	var tone = 0.22 if p.hurt else 0.0
	var head = Vector2.ZERO
	var head_r = 0.0
	var back = Vector2.ZERO
	var belly: Array = []
	for seg in 7:
		var t = seg / 6.0
		var x = 62.0 + (-38.0 + t * 76.0) * p.stretch
		var r = (14.0 + sin(t * PI) * 13.0) * (0.85 + 0.15 * p.squash)
		var ry = r * p.squash
		var wave = sin(seg * 1.1 + p.sway * PI / 2.0) * 1.5
		var lift = p.lift * pow(t, 2.0) + p.tail * pow(1.0 - t, 2.5)
		var centre = Vector2(x, GROUND - ry - lift + wave)
		c.ellipse(centre, r + 2.0, ry, &"hide", {"z": seg, "tone": tone - 0.1, "lo": 1, "hi": 3, "dither": true, "seam": true})
		belly.append(centre + Vector2(1, ry * 0.5))
		if seg in [2, 3, 4]:  # Brood sacs hanging under the belly.
			c.ellipse(centre + Vector2(-3, ry * 0.55), 4.5, 3.5, &"lung", {"z": seg + 0.6, "tone": tone - 0.1})
		if seg == 3:
			back = centre + Vector2(0, -ry * 0.78)
		if seg == 6:
			head = centre
			head_r = r
	# The pale belly, one strip under the segments.
	for i in range(1, belly.size()):
		c.capsule(belly[i - 1], belly[i], 3.5 * p.squash + 1.0, 3.5 * p.squash + 1.0, &"hide", {"z": 6.5, "lo": 3, "hi": 3, "flat": true, "line": false, "tone": tone})
	# The bile bladder on her back: dark in the body, glowing on top.
	c.ellipse(back, 9.0, 6.0 * p.squash, &"bile", {"z": 6.8})
	c.ellipse(back + Vector2(-1, -1), 7.0, 4.5 * p.squash, &"bile", {"glow": true})
	# Ring mouth with teeth at the front of the head.
	var mouth_r = 4.0 + 7.0 * p.mouth
	var mouth = head + Vector2(head_r * 0.62, 2.0)
	c.ellipse(mouth, mouth_r * 0.7, mouth_r, &"hide", {"z": 8, "lo": 0, "hi": 0, "line": false})
	for k in 8:
		var a = TAU * k / 8.0
		c.detail(Vector2i((mouth + Vector2(cos(a) * mouth_r * 0.62, sin(a) * mouth_r * 0.9)).floor()), pal.step(&"bone", -1))
	# Four eyes on the brow, glowing; shut when she is dead.
	for e in [Vector2(-6, -9), Vector2(-1, -12), Vector2(4, -10), Vector2(-9, -4)]:
		var at = Vector2i((head + e).floor())
		if p.dead:
			c.detail(at, pal.step(&"hide", 0))
			c.detail(at + Vector2i(1, 0), pal.step(&"hide", 0))
		else:
			c.detail(at, pal.step(&"glow", 1), true)
			c.detail(at + Vector2i(1, 0), pal.step(&"glow", 1), true)
			c.detail(at + Vector2i(0, 1), pal.step(&"glow", 0), true)
