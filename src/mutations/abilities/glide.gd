extends MutationAbility
## Lung Sac (back): hold the ability (jump, for the player) while falling to drift down slowly.

const GLIDE_FALL_SPEED := 70.0


func physics_tick(_delta: float) -> void:
	if host.can_act() and not host.is_on_floor() and host.ability_held(def.slot) \
			and host.velocity.y > GLIDE_FALL_SPEED:
		host.velocity.y = GLIDE_FALL_SPEED
