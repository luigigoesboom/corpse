extends Node2D
## A ripple of flesh running along the floor from the Matron's slam. Low:
## jump over it or roll through it.

const SPEED := 300.0
const LIFETIME := 1.3

var direction := 1.0
## Who made it: it does not hurt them.
var maker_hurtbox: Node
var _age := 0.0


func _ready() -> void:
	$Hitbox.collision_layer = CombatRules.enemy_attack_layer()
	$Hitbox.exclude = maker_hurtbox
	scale.x = direction


func _physics_process(delta: float) -> void:
	_age += delta
	var step := Vector2(direction * SPEED * delta, 0)
	if get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -8), global_position + Vector2(0, -8) + step * 2.0, 1)):
		queue_free()  # Breaks on a wall.
		return
	position += step
	modulate.a = clampf((LIFETIME - _age) / 0.3, 0.0, 1.0)
	if _age > LIFETIME:
		queue_free()
