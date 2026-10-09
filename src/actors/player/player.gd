class_name Player
extends CharacterBody2D
## Player movement: run, jump, wall cling.
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

var _gravity := 0.0
var _jump_velocity := 0.0
var _coyote_timer := 0.0
var _wall_coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _wall_lock_timer := 0.0
var _wall_normal_x := 0.0
var _clinging := false

@onready var _visual: Node2D = $Visual
@onready var _reach: Area2D = $Reach


func _ready() -> void:
	_recalculate_jump()


func _physics_process(delta: float) -> void:
	var input_dir := Input.get_axis("move_left", "move_right")
	if _wall_lock_timer > 0.0:
		input_dir = 0.0

	_tick_timers(delta)
	_update_wall_state(input_dir)
	_apply_gravity(delta)
	_apply_run(input_dir, delta)
	_apply_jump()

	move_and_slide()

	if not is_zero_approx(velocity.x) and not _clinging:
		_visual.scale.x = signf(velocity.x)

	_handle_items()


func is_clinging() -> bool:
	return _clinging


## The player only asks; ItemLayer decides and changes the world data.
func _handle_items() -> void:
	if Input.is_action_just_pressed("interact"):
		var nearest: Area2D = null
		for area in _reach.get_overlapping_areas():
			if area is WorldItem and (nearest == null
					or area.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position)):
				nearest = area
		if nearest:
			EventBus.pickup_requested.emit(nearest)
	if Input.is_action_just_pressed("drop") and is_on_floor():
		# Drop at the feet, a little in front.
		EventBus.drop_requested.emit(global_position + Vector2(_visual.scale.x * 24.0, 22.0))


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
		_visual.scale.x = signf(_wall_normal_x)


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var g := _gravity if velocity.y < 0.0 else _gravity * fall_gravity_multiplier
	var max_speed := wall_slide_speed if _clinging else max_fall_speed
	velocity.y = minf(velocity.y + g * delta, max_speed)


func _apply_run(input_dir: float, delta: float) -> void:
	if _wall_lock_timer > 0.0:
		return
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
			_consume_jump()
		elif _wall_coyote_timer > 0.0:
			velocity = Vector2(_wall_normal_x * wall_jump_push, _jump_velocity * wall_jump_height_ratio)
			_wall_lock_timer = wall_jump_lock_time
			_visual.scale.x = signf(_wall_normal_x)
			_consume_jump()

	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut


func _consume_jump() -> void:
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0
	_wall_coyote_timer = 0.0
