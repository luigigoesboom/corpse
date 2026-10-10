extends RefCounted
## The Puffsac's look (D-028, week 45; started with tools/creature/
## new_creature.gd): a torn-off lobe of lung that still breathes, drifting
## on its own. A see-through sac with spores glowing inside, bronchiole
## tendrils trailing under it. It swells red when something comes close
## and bursts into a cloud of spores.
## Frames are 64 x 64, facing right, centred on the frame.

const Kit := preload("res://tools/pixel/kit.gd")

const F := 64
const C := Vector2(32, 30)


static func make(pal, out: Array) -> void:
	Kit.write(pal, out, "puffsac", anims(), Callable(Look, "draw"), F)


## t: breathing phase (0..1), swell (0..3), burst (0..1: bursting, then the
## cloud), hurt, sink (dead and sinking, 0..1).
static func anims() -> Dictionary:
	return {
		"idle": [{"t": 0.0}, {"t": 0.25}, {"t": 0.5}, {"t": 0.75}],
		"move": [{"t": 0.0}, {"t": 0.25}, {"t": 0.5}, {"t": 0.75}],
		"windup": [{"swell": 1.0, "t": 0.1}, {"swell": 2.0, "t": 0.6}, {"swell": 2.6, "t": 0.2}, {"swell": 3.0, "t": 0.7}],
		"attack": [{"burst": 0.15}, {"burst": 0.4}, {"burst": 0.7}, {"burst": 1.0}],
		"hurt": [{"t": 0.3, "hurt": true}],
		"die": [{"burst": 0.15}, {"burst": 0.4}, {"burst": 0.7}, {"burst": 1.0}],
	}


class Look:
	static func draw(c, pal, p: Dictionary) -> void:
		var burst: float = p.get("burst", 0.0)
		if burst > 0.3:
			_cloud(c, pal, burst)
			return
		var t: float = p.get("t", 0.0)
		var swell: float = p.get("swell", 0.0) + burst * 10.0
		var tone: float = 0.25 if p.get("hurt", false) else 0.0
		var breath := sin(t * TAU) * 1.0
		var rx := 11.0 + breath + swell * 1.6
		var ry := 10.0 + breath * 0.8 + swell * 1.5
		var centre := C + Vector2(0, -swell * 0.5)
		# Tendrils first (behind): bronchioles trailing down, swaying.
		for k in 3:
			var root := centre + Vector2(-6.0 + k * 6.0, ry - 2.0)
			var pts := Kit.wave(root, Vector2(0.15 * (k - 1), 1).normalized(), 14.0 + k * 3.0 - swell * 2.0, 4, 2.0, t + k * 0.3)
			Kit.chain(c, pts, 1.8, 0.7, &"lung", {"z": -2.0 + k * 0.1, "lo": 0, "hi": 2, "tone": tone})
		# The sac: see-through lung, veins darkening red as it swells.
		Kit.sac(c, pal, centre, rx, ry, &"lung", {"alpha": 0.82, "tone": tone - swell * 0.06, "vein": &"blood",
			"vein_step": clampi(int(swell * 0.7), 0, 2), "veins": 4})
		# Alveoli bumps on top, and a puckered vent at the bottom.
		for k in 4:
			var a := -2.6 + k * 0.55
			c.circle(centre + Vector2(cos(a) * rx * 0.85, sin(a) * ry * 0.85), 2.2 + swell * 0.2, &"lung", {"z": 0.5, "tone": tone + 0.05})
		c.detail(Vector2i((centre + Vector2(0, ry - 1)).floor()), pal.step(&"blood", 0))
		c.detail(Vector2i((centre + Vector2(1, ry - 1)).floor()), pal.step(&"blood", 0))
		# Spores glowing through the skin: dim when calm, bright when swollen.
		var glow_step := 0 if swell < 1.5 else 1
		var spots := [Vector2(-4, -2), Vector2(3, 1), Vector2(-1, 4), Vector2(5, -4), Vector2(-6, 3)]
		for i in mini(spots.size(), 3 + int(swell)):
			var at: Vector2 = centre + spots[i] * (1.0 + swell * 0.15) + Vector2(sin(t * TAU + i), 0)
			c.detail(Vector2i(at.floor()), pal.step(&"glow_fungus", glow_step), true)

	## The burst: shreds of membrane flying apart and a spreading cloud of spores.
	static func _cloud(c, pal, burst: float) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var spread := 8.0 + burst * 22.0
		for i in 26:
			var dir := Vector2.from_angle(rng.randf() * TAU)
			var at := C + dir * spread * rng.randf_range(0.4, 1.0)
			if burst < 0.95 or rng.randf() < 0.5:
				c.detail(Vector2i(at.floor()), pal.step(&"glow_fungus", 1 if rng.randf() < 0.5 else 0), true)
		if burst < 0.9:
			for i in 5:
				var dir := Vector2.from_angle(i * TAU / 5.0 + 0.4)
				var at := C + dir * spread * 0.8
				c.capsule(at, at + dir.rotated(0.8) * 3.0, 1.4, 0.8, &"lung", {"alpha": 0.8, "tone": -0.1})
