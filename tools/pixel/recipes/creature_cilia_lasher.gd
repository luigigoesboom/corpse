extends RefCounted
## The Cilia Lasher's look (D-028, week 49; started with tools/creature/
## new_creature.gd): a mound of lung grown on the floor, sprouting long
## cilia that comb the air, and one thick lash that whips whatever comes
## close. Frames are 64 x 64, facing right, standing on the bottom edge.

const Kit := preload("res://tools/pixel/kit.gd")

const F := 64
const GROUND := 62.5


static func make(pal, out: Array) -> void:
	Kit.write(pal, out, "cilia_lasher", anims(), Callable(Look, "draw"), F)


## t: sway phase (0..1); back (0..1, the lash drawn back); lash (0..1, the
## lash thrown forward); flat (cilia pressed down: hurt); wilt (0..1, dying).
static func anims() -> Dictionary:
	return {
		"idle": [{"t": 0.0}, {"t": 0.25}, {"t": 0.5}, {"t": 0.75}],
		"move": [{"t": 0.0}, {"t": 0.25}, {"t": 0.5}, {"t": 0.75}],
		"windup": [{"t": 0.1, "back": 0.5}, {"t": 0.15, "back": 1.0}],
		"attack": [{"t": 0.2, "lash": 0.6}, {"t": 0.25, "lash": 1.0}, {"t": 0.3, "lash": 0.5}],
		"hurt": [{"t": 0.4, "flat": 1.0, "hurt": true}],
		"die": [{"wilt": 0.35}, {"wilt": 0.7}, {"wilt": 1.0}],
	}


class Look:
	static func draw(c, pal, p: Dictionary) -> void:
		var t: float = p.get("t", 0.0)
		var wilt: float = p.get("wilt", 0.0)
		var back: float = p.get("back", 0.0)
		var lash: float = p.get("lash", 0.0)
		var flat: float = p.get("flat", 0.0)
		var tone: float = 0.25 if p.get("hurt", false) else 0.0
		var rng := RandomNumberGenerator.new()
		rng.seed = 11
		# The mound: lumps of lung piled on the floor.
		var mound := [Vector2(26, 55), Vector2(34, 53), Vector2(30, 57), Vector2(20, 58), Vector2(40, 58)]
		for i in mound.size():
			var r := rng.randf_range(6.0, 9.0) * (1.0 - wilt * 0.25)
			c.ellipse(mound[i] + Vector2(0, wilt * 3.0), r * 1.2, r * 0.8, &"rock_alveolus", {"lo": 1, "hi": 5, "dither": true, "z": i * 0.01, "tone": tone})
		# Cilia: long thin hairs rising and swaying.
		for k in 7:
			var root := Vector2(16.0 + k * 5.0, 52.0 + absf(k - 3) * 0.8)
			var up := Vector2(rng.randf_range(-0.25, 0.25), -1.0).normalized()
			var droop := wilt * 1.4 + flat * 0.9
			var dir := up.rotated((k - 3) * 0.12 + droop * signf(k - 3 + 0.1)).normalized()
			var length := rng.randf_range(20.0, 30.0) * (1.0 - wilt * 0.5) * (1.0 - flat * 0.35)
			var pts := Kit.wave(root, dir, length, 5, 2.5 + back * 1.5, t + k * 0.17, 0.8)
			Kit.chain(c, pts, 1.3, 0.5, &"rock_alveolus", {"lo": 3, "hi": 6, "z": 1 + k * 0.01, "tone": tone, "line": false})
			if wilt < 0.5:
				c.detail(Vector2i(pts[-1].floor()), pal.step(&"glow_fungus", 0), true)
		# The lash: one thick cilium. Drawn back, it coils up behind; thrown,
		# it lies out flat along the floor ahead.
		var base := Vector2(34, 50)
		var reach: float
		var angle: float
		if lash > 0.0:
			angle = lerpf(-1.1, 0.15, lash)
			reach = lerpf(26.0, 34.0, lash)
		else:
			angle = lerpf(-1.25, -2.4, back) + sin(t * TAU) * 0.08
			reach = 24.0 - back * 4.0
		if wilt > 0.0:
			angle = lerpf(-1.25, 0.6, wilt)
			reach *= 1.0 - wilt * 0.3
		var lash_pts := Kit.wave(base, Vector2.from_angle(angle), reach, 6, 2.0 + back * 2.0, t, 0.6)
		Kit.chain(c, lash_pts, 3.2, 1.2, &"lung", {"lo": 1, "hi": 3, "dither": true, "z": 3, "tone": tone})
		if wilt < 0.5:
			var tip: Vector2 = lash_pts[-1]
			c.circle(tip, 1.6 + lash, &"glow_fungus", {"glow": true})
