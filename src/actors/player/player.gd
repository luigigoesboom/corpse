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
## - Dodge: a quick roll along the ground; hits are ignored for most of it.
##
## The camera is not part of the player: a GameCamera in the scene follows it.

## Emitted by teleport(): the camera should jump here instead of panning.
signal teleported

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

@export_group("Dodge")
## Start speed of the roll; it eases out towards the end.
@export var dodge_speed := 400.0
@export var dodge_time := 0.32
## Hits are ignored for this long from the start of the roll.
@export var dodge_invulnerable_time := 0.26
## Wait after a roll before the next one.
@export var dodge_cooldown := 0.45

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
var _dodge_timer := 0.0
var _dodge_cooldown_timer := 0.0
var _dodge_dir := 1.0
var _was_on_floor := true
## Stealth (week 36): seconds left of a loud moment (a swing, a roll, a hard
## landing, a jump) that guards can hear from further away.
var _loud := 0.0
var _base_light_energy := 1.0
## Set when a conversation or menu closes: the click that closed it must not
## also swing the sword (it could hit the person you were talking to). The
## attack stays locked until the button is let go.
static var attack_locked := false


## Call when a conversation or menu closes on a click.
static func swallow_attack() -> void:
	attack_locked = true
## Hides the host while it lies dead (its Corpse is drawn instead).
var body_hidden := false

@onready var health: Health = $Health
@onready var _visual: Node2D = $Visual
@onready var _reach: Area2D = $Reach
@onready var _attack_hitbox: Hitbox = $Visual/AttackHitbox
@onready var _slash: Node2D = $Visual/Slash
@onready var _mutations: MutationHost = $Mutations
@onready var _dust: CPUParticles2D = $Dust
@onready var sprite: LayeredSprite = $Visual/Sprite


## Stealth (week 36).
## Membranes (week 47): springy one-way sheets of lung on physics layer 7
## (MEMBRANE_LAYER). Landing on one faster than MEMBRANE_MIN_BOUNCE throws
## you back up with MEMBRANE_BOUNCE of the speed (more if jump is held);
## jumping off one goes MEMBRANE_JUMP times as high; down + jump drops
## through it.
const MEMBRANE_LAYER := 64
const MEMBRANE_MIN_BOUNCE := 300.0
const MEMBRANE_BOUNCE := 0.6
const MEMBRANE_BOUNCE_HELD := 0.85
const MEMBRANE_JUMP := 1.25
const DROP_TIME := 0.25

var _on_membrane := false
var _drop_timer := 0.0

const SNEAK_SPEED_SCALE := 0.4
const SNEAK_VISIBILITY := 0.3
const WATCH_LIGHT_BOOST := 2.5
const STEP_NOISE := 110.0
const LOUD_NOISE := 220.0

var _base_run_speed := 0.0


func _ready() -> void:
	_base_run_speed = run_speed
	_base_light_energy = $Light.energy
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
	if has_control:
		_try_dodge(input_dir)
	if is_dodging():
		_apply_dodge()
		# Jumping out of a roll keeps its speed: a long, low jump.
		if has_control and _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
			_dodge_timer = 0.0
			_apply_jump()
	else:
		_apply_run(input_dir, delta)
		if has_control:
			_try_drop()
			_apply_jump()
	_mutations.physics_tick(delta)

	var fall_speed := velocity.y
	move_and_slide()
	_on_membrane = is_on_floor() and _floor_is_membrane()
	if _on_membrane and not _was_on_floor and fall_speed > MEMBRANE_MIN_BOUNCE and not _dead:
		var keep := MEMBRANE_BOUNCE_HELD if Input.is_action_pressed("jump") else MEMBRANE_BOUNCE
		velocity.y = -fall_speed * keep
		_on_membrane = false
		Sfx.play(&"membrane", global_position)

	if not is_zero_approx(velocity.x) and not _clinging and has_control:
		_facing = signf(velocity.x)
	if is_on_floor() and not _was_on_floor and fall_speed > 300.0:
		_dust.restart()
		Sfx.play(&"land")
		_loud = 0.5
	_was_on_floor = is_on_floor()

	if has_control:
		_handle_attack()
		_handle_items()
	_visual.scale.x = _facing
	# Sneaking: a lower, dimmer body (week 36).
	_loud = maxf(0.0, _loud - delta)
	var sneaking := is_sneaking()
	_visual.scale.y = move_toward(_visual.scale.y, 0.88 if sneaking else 1.0, delta * 2.0)
	$Light.energy = move_toward($Light.energy, _base_light_energy * (0.3 if sneaking else 1.0), delta * 3.0)


func _process(delta: float) -> void:
	var animation := _pick_animation()
	sprite.play(animation)
	# The run cycle follows the actual speed, so feet do not slide while
	# speeding up or skidding to a stop.
	sprite.speed_scale = clampf(absf(velocity.x) / run_speed, 0.5, 1.25) if animation == &"run" else 1.0
	# Flicker while invulnerable after a hit (not during a dodge).
	var flicker := health.is_invulnerable() and not is_dodging()
	_visual.visible = not body_hidden and (_dead or not flicker or int(Time.get_ticks_msec() / 60) % 2 == 0)


## Which animation fits what the host is doing right now. Order matters:
## the first match wins.
func _pick_animation() -> StringName:
	if _dead:
		return &"die"
	if _hurt_timer > 0.0:
		return &"hurt"
	if is_dodging():
		return &"dodge"
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


## True when the player is in control (alive, not reeling from a hit, not rolling).
func can_act() -> bool:
	return not _dead and _hurt_timer <= 0.0 and not is_dodging()


func is_dodging() -> bool:
	return _dodge_timer > 0.0


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
## Becomes a body of this host type: health, speed, look. Does not hand out
## the type's starting kit; that only happens when a new life starts.
func apply_host(def: HostDef) -> void:
	if def == null:
		return
	health.max_health = def.max_health
	run_speed = _base_run_speed * def.run_speed_scale
	sprite.set_body_frames(def.frames_dir)


## The dead host gives way to its Corpse. Hides right away: the death screen
## pauses the game, so _process() would not get to it.
func hide_body() -> void:
	body_hidden = true
	_visual.visible = false


func respawn(at: Vector2) -> void:
	_dead = false
	body_hidden = false
	_hurt_timer = 0.0
	teleport(at)
	health.heal_full()


## Moves instantly. Physics interpolation (project setting) draws movement
## smoothly between physics steps; after a jump across the map it must be
## told not to slide there. The GameCamera listens to `teleported` and jumps too.
func teleport(at: Vector2) -> void:
	global_position = at
	velocity = Vector2.ZERO
	reset_physics_interpolation()
	teleported.emit()


func _handle_attack() -> void:
	if attack_locked:
		if not Input.is_action_pressed("attack"):
			attack_locked = false
		return
	if _attack_timer <= 0.0 and _attack_hitbox.active:
		_attack_hitbox.deactivate()
		_slash.visible = false
	if Input.is_action_just_pressed("attack") and _attack_cooldown_timer <= 0.0 and not _clinging and not is_dodging():
		_attack_hitbox.activate()
		_slash.visible = true
		_attack_timer = attack_active_time
		_attack_cooldown_timer = attack_cooldown
		Sfx.play(&"swing")
		_loud = 0.5


func _on_hurt(amount: int, from: Vector2, knockback: float) -> void:
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = -facing()
	velocity = Vector2(away * knockback, -knockback * 0.6)
	_hurt_timer = hurt_stun
	_dodge_timer = 0.0
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
## Stealth (week 36): holding sneak on the ground, not rolling.
func is_sneaking() -> bool:
	return not _dead and is_on_floor() and not is_dodging() and Input.is_action_pressed("sneak")


## How far away guards hear the host right now, in px (0 = silent).
func noise_radius() -> float:
	if _dead:
		return 0.0
	if _loud > 0.0:
		return LOUD_NOISE
	if is_sneaking() or not is_on_floor() or absf(velocity.x) < 30.0:
		return 0.0
	return STEP_NOISE


## How easy the host is to see: dim when sneaking, bright in a watch light.
func visibility() -> float:
	var seen := SNEAK_VISIBILITY if is_sneaking() else 1.0
	for light in get_tree().get_nodes_in_group(&"watch_lights"):
		if light.global_position.distance_to(global_position) < light.radius:
			return seen * WATCH_LIGHT_BOOST
	return seen


func facing() -> float:
	return _facing


## The player only asks; ItemLayer decides and changes the world data.
## Dropping happens from the inventory screen.
func _handle_items() -> void:
	if Input.is_action_just_pressed("interact"):
		# The nearest thing in reach: an item to pick up, or anything with interact().
		var nearest: Area2D = null
		for area in _reach.get_overlapping_areas():
			if (area is WorldItem or area.has_method("interact")) and (nearest == null
					or area.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position)):
				nearest = area
		if nearest is WorldItem:
			EventBus.pickup_requested.emit(nearest)
		elif nearest:
			nearest.interact()


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
	_dodge_timer -= delta
	_dodge_cooldown_timer -= delta
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(7, true)  # Membranes hold again.
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


## Starts a roll on the ground: the way you push, or the way you face.
func _try_dodge(input_dir: float) -> void:
	if not Input.is_action_just_pressed("dodge") or _dodge_cooldown_timer > 0.0:
		return
	if not is_on_floor() or _clinging:
		return
	_dodge_dir = signf(input_dir) if input_dir != 0.0 else _facing
	_facing = _dodge_dir
	_dodge_timer = dodge_time
	_dodge_cooldown_timer = dodge_time + dodge_cooldown
	health.grant_invulnerability(dodge_invulnerable_time)
	_loud = 0.5
	_attack_hitbox.deactivate()
	_slash.visible = false
	_dust.restart()
	Sfx.play(&"dodge")


func _apply_dodge() -> void:
	var t := 1.0 - _dodge_timer / dodge_time  # 0 at the start, 1 at the end.
	velocity.x = _dodge_dir * dodge_speed * (1.0 - 0.6 * t * t)


func _apply_run(input_dir: float, delta: float) -> void:
	if _wall_lock_timer > 0.0 or _hurt_timer > 0.0:
		return  # Keep the wall jump or knockback momentum.
	var turning := input_dir != 0.0 and signf(input_dir) != signf(velocity.x)
	var rate: float
	if is_on_floor():
		rate = ground_decel if input_dir == 0.0 or turning else ground_accel
	else:
		rate = air_decel if input_dir == 0.0 else air_accel
	var top := run_speed * (SNEAK_SPEED_SCALE if is_sneaking() else 1.0)
	velocity.x = move_toward(velocity.x, input_dir * top, rate * delta)


## Down + jump on a membrane: through it.
func _try_drop() -> void:
	if not _on_membrane or _jump_buffer_timer <= 0.0 or not Input.is_action_pressed("move_down"):
		return
	set_collision_mask_value(7, false)
	_drop_timer = DROP_TIME
	velocity.y = 80.0
	_on_membrane = false
	_consume_jump()


## Whether what the host stands on is a membrane (its body is on the
## membrane physics layer). A test move down, as standing still slides
## into nothing.
func _floor_is_membrane() -> bool:
	var hit := KinematicCollision2D.new()
	if not test_move(global_transform, Vector2(0, 2), hit):
		return false
	return hit.get_normal().y < -0.7 and PhysicsServer2D.body_get_collision_layer(hit.get_collider_rid()) & MEMBRANE_LAYER != 0


func is_on_membrane() -> bool:
	return _on_membrane


func _apply_jump() -> void:
	if _jump_buffer_timer > 0.0:
		if _coyote_timer > 0.0:
			velocity.y = _jump_velocity * (MEMBRANE_JUMP if _on_membrane else 1.0)
			_dust.restart()
			Sfx.play(&"jump")
			_loud = 0.3
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
