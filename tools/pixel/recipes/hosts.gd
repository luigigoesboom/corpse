extends RefCounted
## Hosts, settlement residents and the mutation overlays (D-028).
##
## One skeleton for every humanoid: hip, chest, head, two arms and two legs.
## A pose says where the feet and hands go; knees and elbows come from IK.
## Nobody shows a face: every look wears a big mask (a bone oval, a bone
## beak, a blank egg of a head, a stitched leather plate, a gold sun), and
## the bodies are wrong on purpose: spindly legs, a short hunched trunk,
## arms that hang past the knees, big hands, the head pushed forward.
## Looks (colonist, pilgrim, antibody, tender, chorister) dress the same
## skeleton, so every host shares poses and the mutation overlays, drawn on
## the same joints, fit all of them.
##
## Writes assets/art/hosts/<look>/<look>_<anim>.png, the residents'
## assets/art/npcs/<look>/<look>_<anim>.png, and the overlays
## assets/art/mutations/<part>/<part>_<anim>.png. 64 x 64 frames, facing
## right, feet on the bottom edge.

const Canvas := preload("res://tools/pixel/canvas.gd")
const Rig := preload("res://tools/pixel/rig.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")

const F := 64
const GROUND := 62.5
const THIGH := 10.0
const SHIN := 10.5
const TORSO := 11.0
const UPPER_ARM := 8.5
const FOREARM := 10.0
## Every body leans forward this much (degrees), the head even more.
const HUNCH := 9.0

const LOOKS := {
	"colonist": {"cloth": &"rag", "skin": &"skin", "mask": "bone"},
	"pilgrim": {"cloth": &"pilgrim", "skin": &"skin", "hood": true, "cloak": true, "mask": "beak"},
	"antibody": {"cloth": &"antibody", "skin": &"antibody", "round": true, "mask": "egg"},
	"tender": {"cloth": &"tender", "skin": &"skin", "apron": true, "mask": "stitched"},
	"chorister": {"cloth": &"gold", "skin": &"skin", "hood": true, "cloak": true, "mask": "halo"},
	"kin": {"cloth": &"kin", "skin": &"skin", "kite": true, "mask": "bellows"},
}
const HOSTS := ["colonist", "pilgrim", "antibody"]
const RESIDENTS := ["tender", "chorister", "kin"]
const PARTS := ["acid_gland", "bone_spur", "lung_sac", "gust_bladder", "bellows_heart"]


static func make(pal, out: Array) -> void:
	var anims = host_anims()
	for look in HOSTS:
		for anim in anims:
			var bodies = []
			var parts = {}
			for part in PARTS:
				parts[part] = []
			for p in anims[anim]:
				var bones = skeleton(p)
				bodies.append(_body(pal, LOOKS[look], bones, p))
				for part in PARTS:
					parts[part].append(_part(pal, part, bones))
			var strip = Sheet.strip(bodies)
			Sheet.save(strip, "res://assets/art/hosts/%s/%s_%s.png" % [look, look, anim])
			out.append({"name": "%s_%s" % [look, anim], "body": strip})
			if look == "colonist":
				for part in PARTS:
					Sheet.save(Sheet.strip(parts[part]), "res://assets/art/mutations/%s/%s_%s.png" % [part, part, anim])
				if anim in ["idle", "attack"]:
					var dressed = strip.duplicate()
					for part in PARTS:
						var layer = Sheet.strip(parts[part])
						dressed.blend_rect(layer, Rect2i(Vector2i.ZERO, layer.get_size()), Vector2i.ZERO)
					out.append({"name": "colonist_%s_mutated" % anim, "body": dressed})
	var resident_anims = {"idle": anims["idle"], "run": walk_cycle(), "work": work_cycle()}
	for look in RESIDENTS:
		for anim in resident_anims:
			var frames = []
			for p in resident_anims[anim]:
				frames.append(_body(pal, LOOKS[look], skeleton(p), p))
			var strip = Sheet.strip(frames)
			Sheet.save(strip, "res://assets/art/npcs/%s/%s_%s.png" % [look, look, anim])
			out.append({"name": "%s_%s" % [look, anim], "body": strip})


# --- Poses -------------------------------------------------------------------------
## A pose, with defaults for anything not given:
##   bob: hip height change (+ = lower), lean: torso tilt in degrees (+ = forward)
##   ff, fb: front / back foot, x from the hip, y up from the ground (- = lifted)
##   hf, hb: front / back hand, from the shoulder
##   tilt: head tilt, eye: "open" / "x" / "shut", turn: whole body, degrees,
##   around `pivot` (from the ground under the hip)

static func P(d := {}) -> Dictionary:
	var p = {"bob": 0.0, "lean": 0.0, "ff": Vector2(3, 0), "fb": Vector2(-3, 0), "hf": Vector2(3, 17), "hb": Vector2(0, 17),
		"tilt": 0.0, "eye": "open", "turn": 0.0, "pivot": Vector2(0, 0), "x": 0.0}
	p.merge(d, true)
	return p


static func host_anims() -> Dictionary:
	var a = {}
	a["idle"] = [P(), P({"bob": 0.5, "hf": Vector2(2, 12.5)}), P({"bob": 1.0, "hf": Vector2(2, 12), "hb": Vector2(-1, 12.5)}), P({"bob": 0.5})]
	a["run"] = run_cycle()
	a["jump"] = [P({"bob": -1, "lean": 6, "ff": Vector2(5, -6), "fb": Vector2(-3, -2), "hf": Vector2(6, -6), "hb": Vector2(-4, -5)}),
		P({"bob": -1, "lean": 4, "ff": Vector2(5, -7), "fb": Vector2(-2, -4), "hf": Vector2(5, -8), "hb": Vector2(-3, -7)})]
	a["fall"] = [P({"lean": -2, "ff": Vector2(5, -2), "fb": Vector2(-4, 0), "hf": Vector2(7, -4), "hb": Vector2(-7, -3)}),
		P({"lean": -3, "ff": Vector2(4, -1), "fb": Vector2(-5, -1), "hf": Vector2(8, -2), "hb": Vector2(-8, -1)})]
	a["cling"] = [P({"lean": -6, "ff": Vector2(-6, -5), "fb": Vector2(-3, -2), "hf": Vector2(-9, -8), "hb": Vector2(-8, -5)}),
		P({"bob": 0.8, "lean": -6, "ff": Vector2(-6, -4), "fb": Vector2(-3, -1), "hf": Vector2(-9, -7), "hb": Vector2(-8, -4)})]
	a["attack"] = [P({"lean": -4, "ff": Vector2(4, 0), "fb": Vector2(-5, 0), "hf": Vector2(-8, 2), "hb": Vector2(-6, 8)}),
		P({"bob": 1, "lean": 10, "ff": Vector2(7, 0), "fb": Vector2(-6, 0), "hf": Vector2(11, 3), "hb": Vector2(-4, 9)}),
		P({"bob": 1, "lean": 12, "ff": Vector2(7, 0), "fb": Vector2(-6, 0), "hf": Vector2(13, 6), "hb": Vector2(-5, 9)})]
	a["hurt"] = [P({"lean": -12, "tilt": -12, "ff": Vector2(5, 0), "fb": Vector2(-2, 0), "hf": Vector2(4, -6), "hb": Vector2(-6, 2), "eye": "x"}),
		P({"bob": 1, "lean": -8, "tilt": -6, "ff": Vector2(4, 0), "fb": Vector2(-3, 0), "hf": Vector2(-3, 6), "hb": Vector2(-6, 6), "eye": "x"})]
	a["dodge"] = []
	for i in 4:  # A forward roll (drawn as a ball by _roll()).
		a["dodge"].append(P({"roll": 90.0 * i}))
	a["die"] = [P({"lean": -10, "tilt": -10, "hf": Vector2(4, -6), "hb": Vector2(-6, 2), "eye": "x"}),
		P({"lean": -14, "eye": "x", "turn": -35, "pivot": Vector2(-3, 0), "hf": Vector2(-6, -4), "hb": Vector2(-8, 0)}),
		P({"eye": "x", "turn": -75, "pivot": Vector2(-3, 0), "hf": Vector2(-4, 8), "hb": Vector2(-6, 6), "ff": Vector2(4, -1)}),
		P({"eye": "x", "turn": -90, "pivot": Vector2(-3, 0), "hf": Vector2(-1, 11), "hb": Vector2(-4, 10), "ff": Vector2(5, -2)})]
	return a


static func run_cycle() -> Array:
	var frames = []
	for i in 6:
		var phase = TAU * i / 6.0
		frames.append(_stride(phase, 7.0, 4.5, 1.2, 6.0))
	return frames


## Residents stroll: shorter steps, less bounce.
static func walk_cycle() -> Array:
	var frames = []
	for i in 6:
		frames.append(_stride(TAU * i / 6.0, 4.5, 2.5, 0.6, 2.0))
	return frames


static func _stride(phase: float, step: float, lift: float, bounce: float, lean: float) -> Dictionary:
	var front = Vector2(cos(phase) * step, -maxf(0.0, sin(phase)) * lift)
	var back = Vector2(cos(phase + PI) * step, -maxf(0.0, sin(phase + PI)) * lift)
	return P({"bob": -absf(sin(phase)) * bounce + bounce * 0.5, "lean": lean, "ff": front, "fb": back,
		"hf": Vector2(-cos(phase) * 5.0 + 1.0, 11.0), "hb": Vector2(cos(phase) * 5.0 - 1.0, 11.0)})


static func work_cycle() -> Array:
	return [P({"bob": 2, "lean": 20, "hf": Vector2(9, 9), "hb": Vector2(6, 10), "tilt": 10}),
		P({"bob": 3, "lean": 26, "hf": Vector2(10, 13), "hb": Vector2(7, 13), "tilt": 14}),
		P({"bob": 2, "lean": 20, "hf": Vector2(9, 9), "hb": Vector2(6, 10), "tilt": 10}),
		P({"bob": 1, "lean": 14, "hf": Vector2(11, 5), "hb": Vector2(7, 8), "tilt": 6})]


# --- Skeleton -----------------------------------------------------------------------

## Joint positions for a pose, in frame pixels.
static func skeleton(p: Dictionary) -> Dictionary:
	if p.has("roll"):
		return _roll_bones(p.roll)
	var hip = Vector2(F / 2.0 - 1.0 + p.x, GROUND - THIGH - SHIN + 0.2 + p.bob)
	var up = Vector2.from_angle(deg_to_rad(-90.0 + p.lean + HUNCH))
	var chest = hip + up * TORSO
	var head_dir = Vector2.from_angle(deg_to_rad(-90.0 + p.lean + p.tilt + HUNCH * 2.5))
	var head = chest + head_dir * 9.5 + Vector2(2.0, 0)
	var shoulder = chest + Vector2(0.5, 1.5)
	var b = {"hip": hip, "chest": chest, "head": head, "shoulder": shoulder}
	for side in ["f", "b"]:
		var foot_target: Vector2 = Vector2(hip.x, GROUND - 1.0) + p["f" + side]
		var foot = Rig.reach(hip, foot_target, THIGH, SHIN)
		b["knee_" + side] = Rig.ik(hip, foot, THIGH, SHIN, 1.0)
		b["foot_" + side] = foot
		var hand = Rig.reach(shoulder, shoulder + p["h" + side], UPPER_ARM, FOREARM)
		b["elbow_" + side] = Rig.ik(shoulder, hand, UPPER_ARM, FOREARM, -1.0)
		b["hand_" + side] = hand
	b["up"] = up
	if p.turn != 0.0:
		var pivot = Vector2(hip.x, GROUND) + p.pivot
		for k in b.keys():
			if k == "up":
				b[k] = (b[k] as Vector2).rotated(deg_to_rad(p.turn))
			else:
				b[k] = Rig.turn(b[k], pivot, deg_to_rad(p.turn))
		# Keep the lowest part of the body on the ground.
		var bottom = -INF
		for k in ["hip", "chest", "head", "knee_f", "knee_b", "foot_f", "foot_b", "hand_f", "hand_b", "elbow_f", "elbow_b"]:
			bottom = maxf(bottom, b[k].y + (7.5 if k == "head" else 6.0 if k in ["hip", "chest"] else 2.5))
		var lift = GROUND - bottom
		for k in b.keys():
			if k != "up":
				b[k] += Vector2(0, lift)
	return b


## Joints for a rolling host, for the overlays: everything on the ball.
static func _roll_bones(angle: float) -> Dictionary:
	var centre = Vector2(F / 2.0, GROUND - 9.5)
	var a = deg_to_rad(angle)
	var head = centre + Vector2(5.0, -3.5).rotated(a)
	var b = {"hip": centre + Vector2(-2, 4).rotated(a), "chest": centre + Vector2(-2, -3).rotated(a), "head": head,
		"shoulder": centre + Vector2(1, -1).rotated(a), "up": Vector2(0, -1).rotated(a)}
	b["hand_f"] = centre + Vector2(6.0, 2.0).rotated(a)
	b["elbow_f"] = centre + Vector2(3.0, 0.5).rotated(a)
	for k in ["knee_f", "knee_b", "foot_f", "foot_b", "hand_b", "elbow_b"]:
		b[k] = centre
	return b


# --- Drawing ------------------------------------------------------------------------

static func _body(pal, look: Dictionary, b: Dictionary, p: Dictionary) -> Image:
	var c = Canvas.new(F, F, pal)
	var skin: StringName = look.skin
	var cloth: StringName = look.cloth
	if p.has("roll"):
		return _roll(c, pal, look, p.roll)
	if look.get("kite", false):  # The Bellows-Kin: a kite of lung folded on the back.
		_kite(c, pal, b)
	# Back limbs, in shadow.
	_arm(c, b, "b", skin, -3.0, -0.28)
	_leg(c, b, "b", skin, cloth, -2.0, -0.22)
	# Torso: a tunic (or robe, or cloak) from the shoulders to the hem, over
	# the thighs, so the clothes read as clothes and not as a cape.
	_leg(c, b, "f", skin, cloth, 1.0, 0.0)
	if look.get("round", false):
		c.ellipse(b.hip.lerp(b.chest, 0.4), 7.5, 9.5, cloth, {"z": 1.5, "rot": b.up.angle() + PI / 2.0})
	else:
		var down: Vector2 = -b.up
		var side: Vector2 = down.orthogonal()
		var long: bool = look.get("cloak", false)
		var hem: float = 9.0 if long else 5.5
		var flare: float = 8.5 if long else 7.0
		var top: Vector2 = b.chest + b.up * 1.5
		c.polygon(PackedVector2Array([top + side * 5.0, top - side * 5.5, b.hip - side * 6.5, b.hip + down * hem - side * flare,
			b.hip + down * (hem + 1.0), b.hip + down * hem + side * flare, b.hip + side * 6.0]), cloth, {"z": 1.5, "lo": 1})
		if look.get("apron", false):
			c.polygon(PackedVector2Array([b.chest + down * 3.0 - side * 3.5, b.chest + down * 3.0 - side * 0.5,
				b.hip + down * 5.0 - side * 1.0, b.hip + down * 5.0 - side * 5.0]), &"ash", {"z": 1.6, "flat": true})
		var belt_a: Vector2 = b.hip - b.up * -1.5 - side * 6.0
		var belt_b: Vector2 = b.hip - b.up * -1.5 + side * 6.0
		c.stroke(belt_a, belt_b, pal.step(cloth, 0))
	# Head, mostly hidden: a hood or a skull, and the mask over the face.
	if look.mask == "egg":
		_mask(c, pal, b, p, look)
	else:
		if look.get("hood", false):
			c.circle(b.head + Vector2(-1.5, -0.5), 8.0, cloth, {"z": 1.9, "lo": 1})
		else:
			c.circle(b.head, 6.5, skin, {"z": 2.0, "tone": -0.1})
		_mask(c, pal, b, p, look)
	_arm(c, b, "f", skin, 3.0, 0.0)
	for arm in ["b", "f"]:  # Sleeves.
		var elbow: Vector2 = b["elbow_" + arm]
		c.capsule(b.shoulder, b.shoulder.lerp(elbow, 0.6), 2.6, 2.2, cloth, {"z": 3.1 if arm == "f" else -2.9, "tone": 0.0 if arm == "f" else -0.25, "lo": 1})
	return c.render().body


## The Bellows-Kin's kite: two ribbed sheets of lung folded up behind the
## shoulders, their tips above the head.
static func _kite(c, pal, b: Dictionary) -> void:
	var behind: Vector2 = b.up.orthogonal()  # Facing right, "up" turned left: behind.
	var back: Vector2 = b.shoulder + behind * 2.0
	for k in 2:
		var tip: Vector2 = back + b.up * (15.0 + k * 3.0) + behind * (9.0 + k * 5.0)
		var foot: Vector2 = b.hip + b.up * 2.0 + behind * (5.0 + k * 2.0)
		for i in 6:
			var t := i / 5.0
			c.capsule(back.lerp(tip, t), foot.lerp(tip, t), 1.4, 1.2, &"lung", {"z": -4.0 - k * 0.1, "alpha": 0.8, "dither": true, "lo": 0, "hi": 2, "line": false})
		c.stroke(back, tip, pal.step(&"bone", 1))  # The spar.


## Tucked into a ball, turned `angle` degrees: cloth round the back, the
## head and knees tucked in front, a hand over the shins.
static func _roll(c, pal, look: Dictionary, angle: float) -> Image:
	var centre = Vector2(F / 2.0, GROUND - 9.5)
	var a = deg_to_rad(angle)
	var skin: StringName = look.skin
	var cloth: StringName = look.cloth
	c.circle(centre, 9.0, cloth, {"lo": 1})
	var head = centre + Vector2(5.0, -3.5).rotated(a)
	c.circle(head, 5.5, skin, {"z": 1})
	var knees = centre + Vector2(4.5, 4.5).rotated(a)
	c.capsule(centre + Vector2(-1, 5).rotated(a), knees, 2.6, 2.2, skin, {"z": 0.5, "tone": -0.1})
	c.capsule(knees, centre + Vector2(0.5, 8.0).rotated(a), 2.0, 1.8, skin, {"z": 0.6, "tone": -0.1})
	c.capsule(centre + Vector2(1, -1).rotated(a), centre + Vector2(6.0, 2.0).rotated(a), 1.7, 1.5, skin, {"z": 2})
	_mask(c, pal, {"head": head, "up": Vector2(0, -1).rotated(a)}, {"tilt": 0.0}, look)
	return c.render().body


static func _leg(c, b: Dictionary, side: String, skin: StringName, cloth: StringName, z: float, tone: float) -> void:
	var hip: Vector2 = b.hip + Vector2(-1.5 if side == "b" else 1.5, 1.0)
	c.capsule(hip, b["knee_" + side], 2.0, 1.5, skin, {"z": z, "tone": tone})
	c.circle(b["knee_" + side], 1.8, skin, {"z": z + 0.02, "tone": tone})  # Knobbly knees.
	c.capsule(b["knee_" + side], b["foot_" + side], 1.5, 1.1, skin, {"z": z, "tone": tone})
	var foot: Vector2 = b["foot_" + side]
	c.capsule(foot + Vector2(-1, -0.5), foot + Vector2(5, 0.5), 1.6, 0.8, skin, {"z": z + 0.1, "tone": tone - 0.08})


static func _arm(c, b: Dictionary, side: String, skin: StringName, z: float, tone: float) -> void:
	c.capsule(b.shoulder, b["elbow_" + side], 1.6, 1.3, skin, {"z": z, "tone": tone})
	c.capsule(b["elbow_" + side], b["hand_" + side], 1.3, 1.1, skin, {"z": z, "tone": tone})
	var hand: Vector2 = b["hand_" + side]
	var along: Vector2 = (hand - b["elbow_" + side]).normalized()
	c.circle(hand, 2.4, skin, {"z": z + 0.05, "tone": tone})  # Big hands, long fingers.
	c.capsule(hand, hand + along * 3.5 + along.orthogonal() * 1.0, 1.0, 0.6, skin, {"z": z + 0.06, "tone": tone - 0.05})


## The mask, in the head's own directions (fwd = where it faces, up = top
## of the head), so it tilts and falls with the body. No eyes anywhere.
## When hurt or dead (p.eye "x") the mask is cracked.
static func _mask(c, pal, b: Dictionary, p: Dictionary, look: Dictionary) -> void:
	var up: Vector2 = Vector2.from_angle(b.up.angle() + deg_to_rad(p.get("tilt", 0.0) + HUNCH * 1.5))
	var fwd: Vector2 = up.rotated(PI / 2.0)
	var head: Vector2 = b.head
	var rot: float = up.angle() + PI / 2.0
	var crack: bool = p.get("eye", "open") == "x"
	match look.mask:
		"bone":  # A tall oval of bone, a seam down the middle, three holes in a row.
			var centre = head + fwd * 3.0
			c.ellipse(centre, 5.0, 9.0, &"bone", {"z": 2.5, "rot": rot, "lo": 1})
			c.stroke(centre + fwd * 3.0 + up * 6.0, centre + fwd * 3.5 - up * 6.0, pal.step(&"bone", 0))
			for k in 3:
				c.detail(Vector2i((centre + fwd * 1.5 + up * (2.0 - k * 2.5)).floor()), pal.step(&"ash", 0))
		"beak":  # A long beak of bone, curving down.
			c.ellipse(head + fwd * 2.5, 4.0, 6.0, &"bone", {"z": 2.5, "rot": rot, "lo": 1})
			c.capsule(head + fwd * 4.0 + up * 1.0, head + fwd * 15.0 - up * 4.0, 3.2, 0.7, &"bone", {"z": 2.6, "lo": 1, "tone": -0.05})
			c.stroke(head + fwd * 5.0 - up * 0.5, head + fwd * 13.0 - up * 3.5, pal.step(&"bone", 0))
		"egg":  # No mask: the head itself is a blank, tall egg.
			c.ellipse(head + up * 2.5 + fwd * 1.0, 6.5, 10.5, look.skin, {"z": 2.0, "rot": rot, "dither": true})
			c.stroke(head + up * 11.0 + fwd * 1.0, head + up * 3.0 + fwd * 4.5, pal.step(look.skin, 0))
		"stitched":  # A flat leather plate, its mouth sewn shut.
			var plate = head + fwd * 3.5
			c.polygon(PackedVector2Array([plate + up * 8.0 - fwd * 1.0, plate + up * 7.0 + fwd * 3.5, plate - up * 7.0 + fwd * 3.5,
				plate - up * 9.0 - fwd * 1.5]), &"wood", {"z": 2.5, "lo": 1})
			for k in 4:  # Stitches across the mouth.
				var at: Vector2 = plate + fwd * 2.0 - up * (2.0 + k * 1.5)
				c.stroke(at - fwd * 1.0, at + fwd * 1.0, pal.step(&"ash", -1))
			c.stroke(plate + fwd * 1.0 + up * 5.0, plate + fwd * 3.0 + up * 5.0, pal.step(&"wood", 0))
		"bellows":  # A bladder of lung strapped over the face, ribbed, breathing
			# through a tube that hangs to the chest.
			var sac = head + fwd * 3.5 + up * 1.0
			c.ellipse(sac, 7.0, 8.5, &"lung", {"z": 2.5, "rot": rot, "dither": true, "lo": 1})
			for k in 3:  # Ribs around it.
				var at: Vector2 = sac + up * (4.0 - k * 4.0)
				c.stroke(at - fwd * 5.0, at + fwd * 5.5, pal.step(&"rock_alveolus", 2))
			var tube_end: Vector2 = head + fwd * 4.0 - up * 13.0
			c.capsule(sac + fwd * 4.0 - up * 5.0, tube_end, 1.6, 1.3, &"rock_cartilage", {"z": 2.6, "lo": 2})
			c.circle(tube_end, 1.8, &"rock_cartilage", {"z": 2.7, "lo": 1})
		"halo":  # A big gold sun held over the face, rays scratched in.
			var sun = head + fwd * 4.0
			c.circle(sun, 9.0, &"gold", {"z": 2.5, "lo": 1})
			for k in 8:
				var a = TAU * k / 8.0
				c.stroke(sun + Vector2.from_angle(a) * 3.5, sun + Vector2.from_angle(a) * 7.5, pal.step(&"gold", 1))
			c.circle(sun, 2.5, &"gold", {"z": 2.6, "lo": 2})
	if crack:
		c.stroke(head + fwd * 2.0 + up * 6.0, head + fwd * 4.0 - up * 1.0, pal.step(&"outline", 0))
		c.stroke(head + fwd * 4.0 - up * 1.0, head + fwd * 3.0 - up * 5.0, pal.step(&"outline", 0))


# --- Mutation overlays ------------------------------------------------------------------

static func _part(pal, part: String, b: Dictionary) -> Image:
	var c = Canvas.new(F, F, pal)
	match part:
		"acid_gland":  # A bile sac swelling under the jaw.
			var at: Vector2 = b.head + Vector2(2.0, 6.0)
			c.ellipse(at, 3.6, 3.0, &"bile")
			c.detail(Vector2i(at + Vector2(-1, -1)), pal.step(&"bile", -1))
		"bone_spur":  # A spike of bone grown out of the forearm.
			var dir: Vector2 = (b.hand_f - b.elbow_f).normalized()
			c.capsule(b.hand_f - dir * 2.0, b.hand_f + dir * 9.0, 2.0, 0.6, &"bone")
		"gust_bladder":  # A taut bladder of breath at the throat, ringed with cartilage.
			var throat: Vector2 = b.head - b.up * 7.0 + b.up.orthogonal() * -2.0
			c.ellipse(throat, 4.2, 3.6, &"lung", {"dither": true})
			c.stroke(throat + Vector2(-3, -1), throat + Vector2(3, -2), pal.step(&"rock_cartilage", 3))
			c.detail(Vector2i(throat + Vector2(-1, -2)), pal.step(&"lung", -1))
		"bellows_heart":  # A ribbed organ pumping in the belly, showing through.
			var belly: Vector2 = b.chest.lerp(b.hip, 0.55) + b.up.orthogonal() * -2.5
			c.ellipse(belly, 3.6, 4.6, &"lung", {"rot": b.up.angle() + PI / 2.0})
			for k in 3:
				var at: Vector2 = belly - b.up * (k - 1) * 2.4
				c.stroke(at - Vector2(3, 0), at + Vector2(3, 0), pal.step(&"rock_alveolus", 2))
		"lung_sac":  # A breathing bladder on the back.
			var back: Vector2 = b.chest.lerp(b.hip, 0.35) - b.up.orthogonal() * -7.0
			c.ellipse(back, 4.5, 5.5, &"lung", {"rot": b.up.angle() + PI / 2.0})
			c.detail(Vector2i(back + Vector2(-2, -3)), pal.step(&"lung", -1))
	return c.render().body
