extends Node2D
## A glob of the Matron's bile (boss volley): flies in an arc, hurts what it
## hits, and leaves a burning puddle where it lands.

const GRAVITY := 650.0
const PUDDLE := preload("res://src/actors/bosses/bile_puddle.tscn")

var velocity := Vector2.ZERO
## The thrower's Hurtbox: neither the glob nor its puddle hurts her.
var thrower_hurtbox: Node
var _age := 0.0


func _ready() -> void:
	$Hitbox.collision_layer = CombatRules.enemy_attack_layer()
	$Hitbox.exclude = thrower_hurtbox
	$Hitbox.landed.connect(func(_hurtbox): queue_free())


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y += GRAVITY * delta
	var step := velocity * delta
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, global_position + step, 1))
	if hit:
		if hit.normal.y < -0.5:  # The floor: it pools.
			var puddle := PUDDLE.instantiate()
			puddle.position = hit.position
			puddle.get_node("Hitbox").exclude = thrower_hurtbox
			get_parent().add_child(puddle)
		queue_free()
		return
	if _age > 4.0:
		queue_free()
		return
	position += step
