extends RefCounted
## Bones for the art program (D-028): poses are written as where hands and
## feet should be; the knees and elbows are found by two-bone IK, so limbs
## keep their length in every frame and mutation parts can sit on the same
## joints the body uses.


## The middle joint of a two-bone limb from `root` toward `target` (bones
## `a` and `b` long). `bend` = +1 or -1 picks which way it bends (seen from
## the side, facing right: knees bend forward with +1, elbows back with -1).
## A target out of reach is pulled in along the line.
static func ik(root: Vector2, target: Vector2, a: float, b: float, bend: float) -> Vector2:
	var to := target - root
	var d := clampf(to.length(), absf(a - b) + 0.01, a + b - 0.01)
	var cos_angle := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var angle := acos(cos_angle)
	var base := to.angle() if to.length() > 0.001 else PI / 2.0
	return root + Vector2.from_angle(base - bend * angle) * a


## Where the end actually lands (the target, or as far as the limb reaches).
static func reach(root: Vector2, target: Vector2, a: float, b: float) -> Vector2:
	var to := target - root
	return root + to.limit_length(a + b - 0.01)


## Rotates a point around a pivot (whole-body turns: falling over, rolling).
static func turn(p: Vector2, pivot: Vector2, radians: float) -> Vector2:
	return pivot + (p - pivot).rotated(radians)
