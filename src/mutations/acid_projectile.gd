extends Node2D
## A glob of acid: flies in an arc, hurts the first enemy it touches, splats on walls.

const GRAVITY := 500.0
const LIFETIME := 2.0

var velocity := Vector2.ZERO
var _age := 0.0


func _ready() -> void:
	$Hitbox.landed.connect(func(_hurtbox): queue_free())


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y += GRAVITY * delta
	var step := velocity * delta
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1)
	if _age > LIFETIME or get_world_2d().direct_space_state.intersect_ray(query):
		queue_free()
		return
	position += step
	rotation = velocity.angle()
