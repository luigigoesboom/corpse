extends RefCounted
## Parts for creature recipes (week 45, D-028): the pieces most creatures
## are made of, so a new one is a recipe of a few calls instead of a page of
## shapes. Everything draws onto a Canvas (tools/pixel/canvas.gd) with the
## usual shape options (z, tone, lo, hi, dither, alpha...).
##
##   const Kit := preload("res://tools/pixel/kit.gd")
##   Kit.write(pal, out, "puffsac", anims(), Callable(Puffsac, "draw"))
##
## A creature recipe is a dictionary of animations (name -> list of poses,
## each pose a dictionary the draw function reads) and a draw function
## `draw(c, pal, pose)`. write() renders every pose and saves the strips the
## game reads: assets/art/creatures/<kind>/<kind>_<anim>.png and the glowing
## parts to <kind>/glow/<kind>_glow_<anim>.png. The usual animations:
## idle, move, windup, attack, hurt, die (a creature script picks by name).

const Canvas := preload("res://tools/pixel/canvas.gd")
const Rig := preload("res://tools/pixel/rig.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")

const DIR := "res://assets/art/creatures/"


## Renders every pose of every animation and saves the strips. Appends one
## preview item per animation to `out`, with its frames for --gif.
static func write(pal, out: Array, kind: String, anims: Dictionary, draw: Callable, size := 48) -> void:
	for anim in anims:
		var bodies := []
		var glows := []
		for pose in anims[anim]:
			var c = Canvas.new(size, size, pal)
			draw.call(c, pal, pose)
			var img: Dictionary = c.render()
			bodies.append(img.body)
			glows.append(img.glow)
		var body := Sheet.strip(bodies)
		var glow := Sheet.strip(glows)
		Sheet.save(body, DIR + "%s/%s_%s.png" % [kind, kind, anim])
		Sheet.save(glow, DIR + "%s/glow/%s_glow_%s.png" % [kind, kind, anim])
		var frames := []
		for i in bodies.size():
			var shown: Image = bodies[i].duplicate()
			shown.blend_rect(glows[i], Rect2i(Vector2i.ZERO, glows[i].get_size()), Vector2i.ZERO)
			frames.append(shown)
		out.append({"name": "%s_%s" % [kind, anim], "body": body, "glow": glow, "frames": frames})


# --- Bodies -------------------------------------------------------------------------

## A soft sac (bladders, puffballs, lung lobes): a dithered dome, see-through
## if `alpha` < 1, with a few veins over it and a wet highlight.
static func sac(c, pal, centre: Vector2, rx: float, ry: float, ramp: StringName, opts := {}) -> void:
	c.ellipse(centre, rx, ry, ramp, {"dither": true}.merged(opts))
	var vein: Color = pal.step(opts.get("vein", &"blood"), opts.get("vein_step", 1))
	var veins: int = opts.get("veins", 3)
	for i in veins:
		# Each vein bends once, like something grown rather than cracked.
		var a := -2.4 + i * 1.3
		var start := centre + Vector2(cos(a) * rx * 0.25, sin(a) * ry * 0.25)
		var bend := centre + Vector2(cos(a + 0.35) * rx * 0.55, sin(a + 0.35) * ry * 0.55)
		var end := centre + Vector2(cos(a + 0.1) * rx * 0.85, sin(a + 0.1) * ry * 0.85)
		c.stroke(start, bend, vein)
		c.stroke(bend, end, vein)
	if not opts.get("glow", false):
		c.detail(Vector2i((centre + Vector2(-rx * 0.4, -ry * 0.5)).floor()), pal.step(ramp, -1))
		c.detail(Vector2i((centre + Vector2(-rx * 0.4 + 1, -ry * 0.5)).floor()), pal.step(ramp, -1))


## A chain of segments along `points` (tails, necks, worms, tentacles):
## a capsule between each pair, radius from `r0` at the first point to `r1`
## at the last. `seam` draws a dark ring between segments.
static func chain(c, points: Array, r0: float, r1: float, ramp: StringName, opts := {}) -> void:
	var n := points.size() - 1
	var z: float = opts.get("z", 0.0)
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		c.capsule(points[i], points[i + 1], lerpf(r0, r1, t0), lerpf(r0, r1, t1), ramp, opts.merged({"z": z + i * 0.01}))


## Points of a wavy line from `from` along `dir` (unit), `length` long, in
## `segs` steps; a sine wave of `amp` px travels along it with `phase` (0..1).
static func wave(from: Vector2, dir: Vector2, length: float, segs: int, amp: float, phase: float, waves := 1.0) -> Array:
	var side := dir.orthogonal()
	var out := []
	for i in segs + 1:
		var t := float(i) / segs
		out.append(from + dir * length * t + side * sin((t * waves - phase) * TAU) * amp * t)
	return out


## Jointed legs by IK (Rig.ik): one per hip/foot pair, bending `bend`
## (+1 forward, -1 back). Bones `a` and `b` long, `r` thick.
static func legs(c, hips: Array, feet: Array, a: float, b: float, r: float, ramp: StringName, opts := {}, bend := 1.0) -> void:
	for i in hips.size():
		var knee: Vector2 = Rig.ik(hips[i], feet[i], a, b, bend)
		var foot: Vector2 = Rig.reach(knee, feet[i], b, 0.01)
		var z: float = opts.get("z", 0.0) + i * 0.01
		c.capsule(hips[i], knee, r, r * 0.85, ramp, opts.merged({"z": z}))
		c.capsule(knee, foot, r * 0.85, r * 0.55, ramp, opts.merged({"z": z + 0.005}))


## A membrane wing or fin from `root`, pointing at `angle` (radians, 0 =
## right), `length` long and `width` wide: a see-through ellipse with ribs.
static func wing(c, pal, root: Vector2, angle: float, length: float, width: float, ramp: StringName, opts := {}) -> void:
	var tip := root + Vector2.from_angle(angle) * length
	var mid := root.lerp(tip, 0.5)
	c.ellipse(mid, length * 0.5, width * 0.5, ramp, {"alpha": 0.7, "flat": true, "line": false, "rot": angle}.merged(opts))
	var rib: Color = pal.step(ramp, 0)
	var ribs: int = opts.get("ribs", 3)
	for k in ribs:
		var spread := (k - (ribs - 1) * 0.5) * 0.35
		c.stroke(root, root + Vector2.from_angle(angle + spread) * length * 0.9, rib)


## Hair-like cilia standing out of a surface: from each base point along
## `normal`, `length` long, swaying by `phase` (0..1).
static func cilia(c, pal, bases: Array, normal: Vector2, length: float, phase: float, ramp: StringName, step := 2) -> void:
	for i in bases.size():
		var sway := sin((phase + i * 0.13) * TAU) * 0.5
		var dir := normal.rotated(sway).normalized()
		var tip: Vector2 = bases[i] + dir * length
		var mid: Vector2 = (bases[i] + tip) * 0.5 + dir.orthogonal() * sway * 1.5
		c.stroke(bases[i], mid, pal.step(ramp, step))
		c.stroke(mid, tip, pal.step(ramp, step + 1))


# --- Faces ---------------------------------------------------------------------------

## Glowing eyes: `n` pixels in a cluster around `at` (they read in the dark).
static func eyes(c, pal, at: Vector2, n := 2, ramp: StringName = &"glow", step := 1, spread := 2) -> void:
	var spots := [Vector2i(0, 0), Vector2i(-spread, 0), Vector2i(-1, -spread), Vector2i(spread - 1, -spread + 1), Vector2i(-spread, spread - 1)]
	for i in mini(n, spots.size()):
		c.detail(Vector2i(at.floor()) + spots[i], pal.step(ramp, step), true)


## A mouth on the front of a body: closed is a dark slit, open (0..1) a dark
## hole ringed with pale teeth.
static func mouth(c, pal, at: Vector2, open: float, facing := 1.0) -> void:
	var p := Vector2i(at.floor())
	if open <= 0.1:
		c.detail(p, pal.step(&"hide", 0))
		c.detail(p + Vector2i(-int(facing), 0), pal.step(&"hide", 0))
		return
	var h := 1 + int(open * 3.0)
	for y in range(-h, h + 1):
		for x in range(-1, 2):
			c.detail(p + Vector2i(x, y), pal.step(&"hide", 0))
	for y in [-h, h]:
		c.detail(p + Vector2i(int(facing), y), pal.step(&"bone", -1))
		c.detail(p + Vector2i(-int(facing), y), pal.step(&"bone", -1))


# --- Placeholder ---------------------------------------------------------------------

## The look tools/new_creature.gd starts a creature with: a lumpy body with
## eyes and a mouth, enough to see each animation work in game. Pose keys:
## t (0..1 loop), swell, push, open, hurt, fall (0 = alive, 1 = gone).
static func placeholder(c, pal, p: Dictionary, size := 48, ramp: StringName = &"fly") -> void:
	var fall: float = p.get("fall", 0.0)
	var t: float = p.get("t", 0.0)
	var swell: float = p.get("swell", 0.0)
	var tone: float = 0.25 if p.get("hurt", false) else 0.0
	var ground := size - 1.5
	var r := (size * 0.22 + swell * 2.0) * (1.0 - fall * 0.5)
	var centre := Vector2(size * 0.5 + p.get("push", 0.0), ground - r * (1.0 - fall * 0.6) - sin(t * TAU) * 1.0)
	c.ellipse(centre, r * 1.15, r * (1.0 - fall * 0.4), ramp, {"dither": true, "tone": tone})
	c.ellipse(centre + Vector2(-r * 0.6, r * 0.3), r * 0.5, r * 0.45, ramp, {"z": -1, "tone": tone - 0.1})
	if fall < 0.5:
		eyes(c, pal, centre + Vector2(r * 0.45, -r * 0.4), 2)
	mouth(c, pal, centre + Vector2(r * 0.95, r * 0.2), p.get("open", 0.0))
