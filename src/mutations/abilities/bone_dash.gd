extends MutationAbility
## Bone Spur (arm): a short dash that cuts through enemies. Invulnerable while dashing.

const COOLDOWN := 0.9
const DURATION := 0.18
const SPEED := 560.0

var _cooldown := 0.0
var _time_left := 0.0
var _dir := 1.0
var _hitbox: Hitbox


func _ready() -> void:
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = host.attack_layer()
	_hitbox.collision_mask = 0
	_hitbox.damage = 2
	_hitbox.knockback = 380.0
	_hitbox.position = Vector2(20, -2)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(44, 34)
	shape.shape = rect
	_hitbox.add_child(shape)
	host.get_node("Visual").add_child(_hitbox)
	_hitbox.deactivate()


func _exit_tree() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()
	host.health.invulnerable = false


func is_dashing() -> bool:
	return _time_left > 0.0


func physics_tick(delta: float) -> void:
	_cooldown -= delta
	if _time_left <= 0.0 and _cooldown <= 0.0 and host.can_act() and host.ability_pressed(def.slot):
		_dir = host.facing()
		_time_left = DURATION
		_cooldown = COOLDOWN
		_hitbox.activate()
		host.health.invulnerable = true
		Sfx.play(&"dash", host.global_position)
	if _time_left > 0.0:
		# Moves on the very frame it starts, so the dash feels instant.
		_time_left -= delta
		host.velocity = Vector2(_dir * SPEED, 0.0)
		if _time_left <= 0.0:
			_hitbox.deactivate()
			host.health.invulnerable = false
			host.velocity.x = _dir * host.run_speed
