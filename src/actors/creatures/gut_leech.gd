extends CharacterBody2D
## Gut Leech: first grey-box enemy (roadmap week 14).
##
## A small state machine. Each state is one branch in _physics_process; the
## enemy is always in exactly one state, and states switch with _enter().
##   IDLE    stand still a moment
##   WANDER  crawl one way, turn at walls and ledges
##   NOTICE  saw the player: stop and rear up briefly
##   CHASE   crawl toward the player
##   ATTACK  wind up, lunge with a bite, recover
##   FLEE    badly hurt: crawl away for a while
##   DEAD    fade out, then gone for good

enum State { IDLE, WANDER, NOTICE, CHASE, ATTACK, FLEE, DEAD }

@export var wander_speed := 50.0
@export var chase_speed := 110.0
@export var flee_speed := 140.0
@export var sight_range := 280.0
## Gives up the chase beyond this distance.
@export var lose_range := 450.0
@export var attack_range := 64.0
@export var lunge_speed := 380.0
## Flees when health drops to this or below.
@export var flee_health := 1

var state := State.IDLE
var _state_time := 0.0
var _dir := 1.0
var _gravity := 1400.0
var _rng := RandomNumberGenerator.new()
var _player: Player
var _hurt_time := 0.0

@onready var _health: Health = $Health
@onready var _visual: Node2D = $Visual
@onready var _sprite: LayeredSprite = $Visual/Sprite
@onready var _bite: Hitbox = $Visual/BiteHitbox
@onready var _contact: Hitbox = $ContactHitbox
@onready var _ledge_check: RayCast2D = $Visual/LedgeCheck
@onready var _sight: RayCast2D = $Sight


func _ready() -> void:
	_rng.seed = hash(EntityLayer.key_of(self))
	_health.hurt.connect(_on_hurt)
	_health.died.connect(_on_died)
	_bite.deactivate()
	_bite.collision_layer = CombatRules.enemy_attack_layer()
	_enter(State.IDLE)


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	if (_player == null or _player.is_dead()) and state in [State.NOTICE, State.CHASE, State.ATTACK, State.FLEE]:
		_enter(State.WANDER)
	_state_time += delta
	_hurt_time -= delta
	if not is_on_floor():
		velocity.y += _gravity * delta

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _sees_player():
				_enter(State.NOTICE)
			elif _state_time > 1.5:
				_dir = -_dir if _rng.randf() < 0.5 else _dir
				_enter(State.WANDER)
		State.WANDER:
			if _blocked():
				_dir = -_dir
			velocity.x = _dir * wander_speed
			if _sees_player():
				_enter(State.NOTICE)
			elif _state_time > _rng.randf_range(2.0, 4.0):
				_enter(State.IDLE)
		State.NOTICE:
			velocity.x = 0.0
			_face(_player.global_position.x - global_position.x)
			if _state_time > 0.4:
				_enter(State.CHASE)
		State.CHASE:
			var dx := _player.global_position.x - global_position.x
			_face(dx)
			velocity.x = 0.0 if _blocked() else _dir * chase_speed
			if absf(dx) < attack_range and absf(_player.global_position.y - global_position.y) < 48.0:
				_enter(State.ATTACK)
			elif global_position.distance_to(_player.global_position) > lose_range:
				_enter(State.WANDER)
		State.ATTACK:
			_update_attack()
		State.FLEE:
			var away := signf(global_position.x - _player.global_position.x)
			_face(away if away != 0.0 else -_dir)
			velocity.x = 0.0 if _blocked() else _dir * flee_speed
			if _state_time > 2.5:
				_enter(State.WANDER)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)

	move_and_slide()


func _update_attack() -> void:
	# 0.35 s wind-up, 0.25 s lunge with the bite on, 0.4 s recovery.
	if _state_time < 0.35:
		velocity.x = 0.0
	elif _state_time < 0.6:
		if not _bite.active:
			_bite.activate()
			velocity.x = _dir * lunge_speed
	elif _state_time < 1.0:
		_bite.deactivate()
		velocity.x = move_toward(velocity.x, 0.0, 40.0)
	else:
		_enter(State.CHASE)


func _process(_delta: float) -> void:
	_sprite.play(_pick_animation())


func _pick_animation() -> StringName:
	if state == State.DEAD:
		return &"die"
	if _hurt_time > 0.0:
		return &"hurt"
	if state == State.ATTACK:
		if _state_time < 0.35:
			return &"windup"
		return &"attack" if _state_time < 0.6 else &"idle"
	if state in [State.IDLE, State.NOTICE] or absf(velocity.x) < 5.0:
		return &"idle"
	return &"move"


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0
	_bite.deactivate()
	_visual.scale = Vector2(_dir, 1.0)


func _face(dx: float) -> void:
	if dx != 0.0:
		_dir = signf(dx)
		_visual.scale.x = _dir


## Wall ahead, or a drop ahead (does not walk off ledges).
func _blocked() -> bool:
	return is_on_wall() and signf(get_wall_normal().x) == -_dir or (is_on_floor() and not _ledge_check.is_colliding())


func _sees_player() -> bool:
	if _player == null or _player.is_dead():
		return false
	var to_player := _player.global_position - global_position
	if to_player.length() > sight_range:
		return false
	_sight.target_position = to_player
	_sight.force_raycast_update()
	return not _sight.is_colliding()  # Nothing but air between us.


func _on_hurt(amount: int, from: Vector2, knockback: float) -> void:
	DamageNumber.spawn(get_parent(), global_position, amount)
	velocity = Vector2(signf(global_position.x - from.x) * knockback, -knockback * 0.4)
	_hurt_time = 0.2
	if _health.current <= flee_health and not _health.is_dead():
		_enter(State.FLEE)
	elif state in [State.IDLE, State.WANDER]:
		_enter(State.NOTICE)


func _on_died() -> void:
	_enter(State.DEAD)
	Sfx.play(&"enemy_die", global_position)
	_contact.deactivate()
	var tween := create_tween()
	tween.tween_interval(0.45)  # Let the death frames play.
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(EventBus.entity_killed.emit.bind(self))
