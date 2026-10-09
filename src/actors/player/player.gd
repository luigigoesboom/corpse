class_name Player
extends CharacterBody2D
## The player's host: movement (run, jump, wall cling), melee attack, getting hurt.
##
## CharacterBody2D is Godot's node for things you move yourself in code.
## You set `velocity`, call move_and_slide(), and it handles sliding along
## walls and floors and tells you is_on_floor() / is_on_wall().
##
## Feel tricks used here (tune them live in the Inspector while the game runs):
## - Coyote time: you can still jump shortly after running off a ledge.
## - Jump buffer: a jump pressed shortly before landing still happens.
## - Variable height: letting go of jump early cuts the jump short.
## - Heavier gravity when falling, so jumps feel snappy instead of floaty.
## - Wall cling: push into a wall in the air to slide down slowly, jump to kick off.

@export_group("Run")
@export var run_speed := 240.0
@export var ground_accel := 2000.0
@export var ground_decel := 2600.0
@export var air_accel := 1300.0
@export var air_decel := 500.0

@export_group("Jump")
## Peak height of a full jump, in pixels. 32 px = one tile.
@export var jump_height := 120.0:
	set(value):
		jump_height = value
		_recalculate_jump()
## Seconds from takeoff to the top of a full jump.
@export var time_to_apex := 0.36:
	set(value):
		time_to_apex = value
		_recalculate_jump()
@export var fall_gravity_multiplier := 1.7
## How much upward speed is kept when jump is released early (0..1).
@export var jump_cut := 0.4
@export var max_fall_speed := 900.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Wall")
@export var wall_slide_speed := 80.0
## Sideways speed of a wall jump. Height is a fraction of a normal jump.
@export var wall_jump_push := 300.0
@export var wall_jump_height_ratio := 0.9
## Short time after a wall jump where input is ignored, so you do not
## immediately steer back into the same wall.
@export var wall_jump_lock_time := 0.14

## Which input uses the ability in each body slot.
const ABILITY_ACTIONS := {"mouth": &"ability_mouth", "arm": &"ability_arm", "back": &"jump"}

@export_group("Combat")
## How long the attack hitbox stays on, and the time between attacks.
@export var attack_active_time := 0.1
@export var attack_cooldown := 0.32
## Seconds of lost control after being hit (knockback plays out).
@export var hurt_stun := 0.25

var _gravity := 0.0
var _jump_velocity := 0.0
var _coyote_timer := 0.0
var _wall_coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _wall_lock_timer := 0.0
var _wall_normal_x := 0.0
var _clinging := false
var _attack_timer := 0.0
var _attack_cooldown_timer := 0.0
var _hurt_timer := 0.0
var _dead := false
var _facing := 1.0
var _was_on_floor := true
## Screen shake strength in pixels; fades out by itself.
var _shake := 0.0
var _look := Vector2.ZERO

@onready var health: Health = $Health
@onready var _visual: Node2D = $Visual
@onready var _reach: Area2D = $Reach
@onready var _attack_hitbox: Hitbox = $Visual/AttackHitbox
@onready var _slash: Node2D = $Visual/Slash
@onready var _mutations: MutationHost = $Mutations
@onready var _camera: Camera2D = $Camera2D
@onready var _dust: CPUParticles2D = $Dust
@onready var sprite: LayeredSprite = $Visual/Sprite


func _ready() -> void:
	_recalculate_jump()
	add_to_group("player")
	health.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	_attack_hitbox.deactivate()
	_slash.visible = false


func _physics_process(delta: float) -> void:
	var has_control := not _dead and _hurt_timer <= 0.0
	var input_dir := Input.get_axis("move_left", "move_right") if has_control else 0.0
	if _wall_lock_timer > 0.0:
		input_dir = 0.0

	_tick_timers(delta)
	_update_wall_state(input_dir)
	_apply_gravity(delta)
	_apply_run(input_dir, delta)
	if has_control:
		_apply_jump()
	_mutations.physics_tick(delta)

	var fall_speed := velocity.y
	move_and_slide()

	if not is_zero_approx(velocity.x) and not _clinging and has_control:
		_facing = signf(velocity.x)
	if is_on_floor() and not _was_on_floor and fall_speed > 300.0:
		_dust.restart()
		Sfx.play(&"land")
	_was_on_floor = is_on_floor()

	if has_control:
		_handle_attack()
		_handle_items()
	_visual.scale.x = _facing


func _process(delta: float) -> void:
	sprite.play(_pick_animation())
	# Flicker while invulnerable after a hit.
	_visual.visible = _dead or not health.is_invulnerable() or int(Time.get_ticks_msec() / 60) % 2 == 0
	# Look ahead: the camera leans the way you face, and down when falling fast.
	var look := Vector2(_facing * 40.0, clampf(velocity.y * 0.08, -12.0, 56.0))
	_look = _look.lerp(look, minf(1.0, delta * 2.5))
	# Shake: a random jolt each frame, whole pixels so pixel art stays crisp.
	var jolt := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
	_camera.offset = (_look + jolt).round()
	_shake = move_toward(_shake, 0.0, delta * 40.0)


func shake(strength: float) -> void:
	_shake = maxf(_shake, strength)


## Which animation fits what the host is doing right now. Order matters:
## the first match wins.
func _pick_animation() -> StringName:
	if _dead:
		return &"die"
	if _hurt_timer > 0.0:
		return &"hurt"
	if _attack_cooldown_timer > attack_cooldown - 0.18:
		return &"attack"
	if _clinging:
		return &"cling"
	if not is_on_floor():
		return &"jump" if velocity.y < 0.0 else &"fall"
	if absf(velocity.x) > 20.0:
		return &"run"
	return &"idle"


func is_dead() -> bool:
	return _dead


## True when the player is in control (alive, not reeling from a hit).
func can_act() -> bool:
	return not _dead and _hurt_timer <= 0.0


## Mutation host interface (see MutationAbility): the player's abilities follow input.
func ability_pressed(slot: String) -> bool:
	return ABILITY_ACTIONS.has(slot) and Input.is_action_just_pressed(ABILITY_ACTIONS[slot])


func ability_held(slot: String) -> bool:
	return ABILITY_ACTIONS.has(slot) and Input.is_action_pressed(ABILITY_ACTIONS[slot])


func attack_layer() -> int:
	return 16  # player_attacks


## Where mutations attach: "head", "mouth", "back", "arm", "belly".
func socket(slot: String) -> Node2D:
	return $Visual/Sockets.get_node("socket_" + slot)


## Brings the host back (placeholder until death and rebirth, roadmap week 21).
func respawn(at: Vector2) -> void:
	_dead = false
	_hurt_timer = 0.0
	global_position = at
	velocity = Vector2.ZERO
	health.heal_full()


func _handle_attack() -> void:
	if _attack_timer <= 0.0 and _attack_hitbox.active:
		_attack_hitbox.deactivate()
		_slash.visible = false
	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0 and not _clinging:
		_attack_hitbox.activate()
		_slash.visible = true
		_attack_timer = attack_active_time
		_attack_cooldown_timer = attack_cooldown
		Sfx.play(&"swing")


func _on_hurt(amount: int, from: Vector2, knockback: float) -> void:
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = -facing()
	velocity = Vector2(away * knockback, -knockback * 0.6)
	_hurt_timer = hurt_stun
	_attack_hitbox.deactivate()
	_slash.visible = false
	DamageNumber.spawn(get_parent(), global_position, amount, Color(1, 0.4, 0.4))


func _on_died() -> void:
	_dead = true
	Sfx.play(&"die")
	EventBus.player_died.emit()


func is_clinging() -> bool:
	return _clinging


## 1 = facing right, -1 = facing left.
func facing() -> float:
	return _facing


## The player only asks; ItemLayer decides and changes the world data.
## Dropping happens from the inventory screen.
func _handle_items() -> void:
	if Input.is_action_just_pressed("interact"):
		var nearest: Area2D = null
		for area in _reach.get_overlapping_areas():
			if area is WorldItem and (nearest == null
					or area.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position)):
				nearest = area
		if nearest:
			EventBus.pickup_requested.emit(nearest)


## From the classic formulas: g = 2h / t^2, v0 = 2h / t.
## Lets you tune the jump in pixels and seconds instead of raw gravity.
func _recalculate_jump() -> void:
	_gravity = 2.0 * jump_height / (time_to_apex * time_to_apex)
	_jump_velocity = -2.0 * jump_height / time_to_apex


func _tick_timers(delta: float) -> void:
	_coyote_timer = coyote_time if is_on_floor() else _coyote_timer - delta
	_wall_coyote_timer -= delta
	_jump_buffer_timer -= delta
	_wall_lock_timer -= delta
	_attack_timer -= delta
	_attack_cooldown_timer -= delta
	_hurt_timer -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time


func _update_wall_state(input_dir: float) -> void:
	# is_on_wall() reflects the last move_and_slide(), which is what we want.
	_clinging = false
	if is_on_floor() or not is_on_wall():
		return
	_wall_normal_x = get_wall_normal().x
	_wall_coyote_timer = coyote_time
	# Cling only while pushing into the wall and not rising.
	if input_dir != 0.0 and signf(input_dir) == -signf(_wall_normal_x) and velocity.y >= 0.0:
		_clinging = true
		_facing = signf(_wall_normal_x)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := _gravity if velocity.y < 0.0 else _gravity * fall_gravity_multiplier
	var max_speed := wall_slide_speed if _clinging else max_fall_speed
	velocity.y = minf(velocity.y + g * delta, max_speed)


func _apply_run(input_dir: float, delta: float) -> void:
	if _wall_lock_timer > 0.0 or _hurt_timer > 0.0:
		return  # Keep the wall jump or knockback momentum.
	var turning := input_dir != 0.0 and signf(input_dir) != signf(velocity.x)
	var rate: float
	if is_on_floor():
		rate = ground_decel if input_dir == 0.0 or turning else ground_accel
	else:
		rate = air_decel if input_dir == 0.0 else air_accel
	velocity.x = move_toward(velocity.x, input_dir * run_speed, rate * delta)


func _apply_jump() -> void:
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			velocity.y = _jump_velocity
			_dust.restart()
			Sfx.play(&"jump")
			_consume_jump()
		elif _wall_coyote_timer > 0.0:
			velocity = Vector2(_wall_normal_x * wall_jump_push, _jump_velocity * wall_jump_height_ratio)
			_wall_lock_timer = wall_jump_lock_time
			_facing = signf(_wall_normal_x)
			_consume_jump()

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut


func _consume_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_wall_coyote_timer = 0.0
