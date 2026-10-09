extends MutationAbility
## Acid Gland (mouth): spit a glob of acid that drops slowly.

const PROJECTILE := preload("res://src/mutations/acid_projectile.tscn")
const COOLDOWN := 0.7
## Mostly flat, so it hits small crawlers instead of arcing over them.
const SPEED := Vector2(420, -40)

var _cooldown := 0.0


func physics_tick(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0 or not player.can_act() or not Input.is_action_just_pressed("ability_mouth"):
		return
	_cooldown = COOLDOWN
	var glob := PROJECTILE.instantiate()
	glob.position = player.socket(def.slot).global_position
	glob.velocity = Vector2(SPEED.x * player.facing(), SPEED.y)
	player.get_parent().add_child(glob)
