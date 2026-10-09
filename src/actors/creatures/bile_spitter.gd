extends CharacterBody2D
## Bile Spitter (roadmap week 18): a rooted bulb that spits acid at you with
## the same Acid Gland the player can grow. Kill it and it drops a Bile Bulb,
## so you can eat its gland.
##
## It is a mutation host (see MutationAbility): its MutationHost has the gland
## as `innate`, and its AI "presses" the ability by setting _fire.
##
##   IDLE    sway, look for the player
##   WINDUP  saw the player: turn, swell up (the tell)
##   SPIT    fire once
##   REST    cooldown before the next windup
##   DEAD    wilt, drop the bulb, gone for good

enum State { IDLE, WINDUP, SPIT, REST, DEAD }

@export var sight_range := 380.0
@export var windup_time := 0.6
@export var rest_time := 1.4
## Item dropped on death (an ItemDef id). Empty = nothing.
@export var drop_item: StringName = &"bile_bulb"

var state := State.IDLE
var run_speed := 0.0  # Host interface; it does not walk.
var _state_time := 0.0
var _dir := -1.0
var _fire := false
var _hurt_time := 0.0
var _player: Player

@onready var health: Health = $Health
@onready var _visual: Node2D = $Visual
@onready var _sprite: LayeredSprite = $Visual/Sprite
@onready var _sight: RayCast2D = $Sight
@onready var _mutations: MutationHost = $Mutations


func _ready() -> void:
	health.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	_visual.scale.x = _dir


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	_state_time += delta
	_hurt_time -= delta
	if not is_on_floor():
		velocity.y += 1400.0 * delta
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)

	match state:
		State.IDLE:
			if _sees_player():
				_face(_player.global_position.x - global_position.x)
				_enter(State.WINDUP)
		State.WINDUP:
			if _player and not _player.is_dead():
				_face(_player.global_position.x - global_position.x)
			if _state_time > windup_time:
				_fire = true
				_enter(State.SPIT)
		State.SPIT:
			if _state_time > 0.25:
				_enter(State.REST)
		State.REST:
			if _state_time > rest_time:
				_enter(State.IDLE)

	_mutations.physics_tick(delta)
	_fire = false
	move_and_slide()


func _process(_delta: float) -> void:
	_sprite.play(_pick_animation())


func _pick_animation() -> StringName:
	if state == State.DEAD:
		return &"die"
	if _hurt_time > 0.0:
		return &"hurt"
	match state:
		State.WINDUP:
			return &"windup"
		State.SPIT:
			return &"attack"
	return &"idle"


# --- Mutation host interface (see MutationAbility) ---

func facing() -> float:
	return _dir


func can_act() -> bool:
	return state != State.DEAD


func socket(_slot: String) -> Node2D:
	return $Visual/Mouth


func ability_pressed(_slot: String) -> bool:
	return _fire


func ability_held(_slot: String) -> bool:
	return false


func attack_layer() -> int:
	return CombatRules.enemy_attack_layer()


## Aims a lob at the player: fixed sideways speed, upward speed chosen so
## the glob's arc (under the projectile's gravity) passes through the player.
func spit_velocity(from: Vector2) -> Vector2:
	const SIDE_SPEED := 300.0
	var gravity: float = preload("res://src/mutations/acid_projectile.gd").GRAVITY
	var target := _player.global_position if _player else from + Vector2(_dir * 200.0, 0.0)
	var dx := target.x - from.x
	var t := maxf(absf(dx) / SIDE_SPEED, 0.15)
	return Vector2(signf(dx) * SIDE_SPEED if dx != 0.0 else _dir * SIDE_SPEED, (target.y - from.y - 0.5 * gravity * t * t) / t)

# ---


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _face(dx: float) -> void:
	if absf(dx) > 8.0:  # Do not flip back and forth when the player is right above.
		_dir = signf(dx)
		_visual.scale.x = _dir


func _sees_player() -> bool:
	if _player == null or _player.is_dead():
		return false
	var to_player := _player.global_position - global_position
	if to_player.length() > sight_range or absf(to_player.y) > 120.0:
		return false
	_sight.target_position = to_player
	_sight.force_raycast_update()
	return not _sight.is_colliding()


func _on_hurt(amount: int, _from: Vector2, _knockback: float) -> void:
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -30), amount)
	_hurt_time = 0.2


func _on_died() -> void:
	_enter(State.DEAD)
	Sfx.play(&"enemy_die", global_position)
	if drop_item != &"":
		EventBus.item_drop_requested.emit(drop_item, global_position)
	var tween := create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(EventBus.entity_killed.emit.bind(self))
