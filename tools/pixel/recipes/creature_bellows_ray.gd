extends RefCounted
## The Bellows Ray's look (D-028, week 49; started with tools/creature/
## new_creature.gd): a flat glider of lung tissue that rides the Lungs'
## air, wide see-through wings ribbed like a hand, a whip of a tail, no eyes:
## a slit underneath that glows. Frames are 64 x 64, facing right, centred.

const Kit := preload("res://tools/pixel/kit.gd")

const F := 64
const C := Vector2(32, 32)


static func make(pal, out: Array) -> void:
	Kit.write(pal, out, "bellows_ray", anims(), Callable(Look, "draw"), F)


## flap: wingtip height (-1 up .. 1 down); tilt: nose down (swooping, 0..1);
## sweep: wings swept back (0..1); hurt; fall (dying, 0..1).
static func anims() -> Dictionary:
	return {
		"idle": [{"flap": -0.6}, {"flap": 0.0}, {"flap": 0.7}, {"flap": 0.0}],
		"move": [{"flap": -0.6}, {"flap": 0.0}, {"flap": 0.7}, {"flap": 0.0}],
		"windup": [{"flap": -0.9, "tilt": 0.2}, {"flap": -1.0, "tilt": 0.35}],
		"attack": [{"flap": 0.2, "tilt": 0.8, "sweep": 0.8}, {"flap": 0.3, "tilt": 0.9, "sweep": 1.0}],
		"hurt": [{"flap": 0.5, "hurt": true}],
		"die": [{"flap": 0.9, "fall": 0.4}, {"flap": 1.0, "fall": 0.8}],
	}


class Look:
	static func draw(c, pal, p: Dictionary) -> void:
		var flap: float = p.get("flap", 0.0)
		var tilt: float = p.get("tilt", 0.0)
		var sweep: float = p.get("sweep", 0.0)
		var fall: float = p.get("fall", 0.0)
		var tone: float = 0.25 if p.get("hurt", false) else 0.0
		var body := C + Vector2(0, fall * 6.0)
		var nose := body + Vector2(12, 2.0 + tilt * 6.0)
		var tail := body + Vector2(-12, -1.0 - tilt * 4.0)
		# The far wing: a curved sheet from the shoulder to its tip, which
		# rises and falls with the flap. Filled between a thick leading edge
		# and a scalloped trailing edge; ribs fan out from the shoulder.
		var shoulder := body + Vector2(4, -1)
		var tip := body + Vector2(-8.0 - sweep * 10.0, -14.0 + flap * 26.0 + fall * 8.0)
		_wing(c, pal, shoulder, tip, tail + Vector2(4, 0), flap, -1.0, tone, 0.75)
		# The body: a long flat lump, thicker at the head.
		var spine := Kit.wave(tail, (nose - tail).normalized(), tail.distance_to(nose), 5, 1.0, flap * 0.2, 0.5)
		Kit.chain(c, spine, 3.0, 5.5, &"lung", {"lo": 1, "hi": 3, "dither": true, "z": 1, "tone": tone})
		# The tail: a whip trailing behind and curling.
		var whip := Kit.wave(tail, (tail - nose).normalized().rotated(0.25 + fall * 0.5), 20.0, 6, 3.0, flap * 0.3 + 0.2, 1.2)
		Kit.chain(c, whip, 1.8, 0.5, &"rock_alveolus", {"lo": 2, "hi": 4, "z": 0.5, "tone": tone})
		# The near wing, in front of the body, smaller (it is foreshortened).
		var near_tip := body + Vector2(-4.0 - sweep * 8.0, 8.0 - flap * 9.0)
		_wing(c, pal, shoulder + Vector2(-1, 2), near_tip, tail + Vector2(6, 2), -flap, 2.0, tone, 0.85)
		# No eyes: a slit under the head that glows when it is alive.
		if fall < 0.5:
			c.stroke(nose + Vector2(-5, 3), nose + Vector2(-1, 3), pal.step(&"glow_fungus", 0), true)

	## A wing as a filled curved sheet: for each step along it, a strip from
	## the leading edge (shoulder -> tip, bowed forward) to the trailing edge
	## (back of the body -> tip, scalloped).
	static func _wing(c, pal, shoulder: Vector2, tip: Vector2, back: Vector2, flap: float, z: float, tone: float, alpha: float) -> void:
		var bow := (tip - shoulder).orthogonal().normalized() * (4.0 + flap * 2.0)
		if bow.x < 0.0:
			bow = -bow  # Bow toward the front.
		var steps := 10
		for i in steps + 1:
			var t := float(i) / steps
			var lead := shoulder.lerp(tip, t) + bow * sin(t * PI)
			var trail := back.lerp(tip, t) + Vector2(0, sin(t * PI * 3.0) * 1.5)  # Scallops.
			c.capsule(lead, trail, 1.6, 1.4, &"lung", {"alpha": alpha, "dither": true, "lo": 0, "hi": 2, "z": z + i * 0.001, "tone": tone - 0.08, "line": false})
			if i > 0:
				var prev_lead := shoulder.lerp(tip, float(i - 1) / steps) + bow * sin(float(i - 1) / steps * PI)
				c.capsule(prev_lead, lead, 1.5, 1.3, &"lung", {"lo": 1, "hi": 3, "z": z + 0.05, "tone": tone})  # The leading edge.
		for k in 4:  # Ribs fanning from the shoulder.
			var t := 0.35 + k * 0.2
			c.stroke(shoulder, back.lerp(tip, t), pal.step(&"rock_alveolus", 2))
