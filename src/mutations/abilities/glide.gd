extends MutationAbility
## Lung Sac (back): hold the ability (jump, for the player) while falling to
## drift down slowly. In the Lungs' updrafts (week 52) the sac catches the
## breath and carries you up.

const GLIDE_FALL_SPEED := 70.0
## How much of an updraft the sac turns into lift.
const LIFT := 0.15


func physics_tick(_delta: float) -> void:
	if not host.can_act() or host.is_on_floor() or not host.ability_held(def.slot):
		return
	var lift := 0.0
	if host.has_method("wind"):
		lift = minf(0.0, host.wind().y) * LIFT * MutationStrains.info(strain).get("power", 1.0)  # Only up-winds lift.
	var cap := GLIDE_FALL_SPEED + lift
	if cap < 0.0:
		# Carried up: ease into the rise (gravity is added back every frame,
		# so this holds a steady climb a little slower than the cap).
		host.velocity.y = lerpf(host.velocity.y, cap, 0.25)
	elif host.velocity.y > cap:
		host.velocity.y = cap
