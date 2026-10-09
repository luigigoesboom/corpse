extends MutationAbility
## Lung Sac (back): hold jump while falling to drift down slowly.

const GLIDE_FALL_SPEED := 70.0


func physics_tick(_delta: float) -> void:
	if player.can_act() and not player.is_on_floor() and Input.is_action_pressed("jump") \
			and player.velocity.y > GLIDE_FALL_SPEED:
		player.velocity.y = GLIDE_FALL_SPEED
