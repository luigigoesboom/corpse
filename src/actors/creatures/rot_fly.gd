extends CharacterBody2D
## Rot Fly (roadmap week 18): a flyer that hovers above you and dives.
## No gravity; it collides with walls like everything else.
##
##   HOVER    drift around its home spot, look for the player
##   STALK    fly to a point above and beside the player
##   WINDUP   stop and buzz (the tell)
##   DIVE     dash at where the player was
##   RECOVER  climb back up
##   DEAD     drop, fade, gone for good

enum State { HOVER, STALK, WINDUP, DIVE, RECOVER, DEAD }

@export var speed := 130.0
@export var dive_speed := 420.0
@export var sight_range := 360.0
@export var lose_range := 520.0

var state := State.HOVER
var _state_time := 0.0
var _home := Vector2.ZERO
var _dive_dir := Vector2.ZERO
var _hurt_time := 0.0
var _player: Player

@onready var _health: Health = $Health
@onready var _visual: Node2D = $Visual
@onready var _sprite: LayeredSprite = $Visual/Sprite
@onready var _sight: RayCast2D = $Sight
@onready var _contact: Hitbox = $ContactHitbox


func _ready() -> void:
	_home = position
	_health.hurt.connect(_on_hurt)
	_health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Player
	_state_time += delta
	_hurt_time -= delta
	var target_velocity := Vector2.ZERO

	match state:
		State.HOVER:
			var bob := Vector2(sin(_state_time * 1.3) * 40.0, sin(_state_time * 2.1) * 16.0)
			target_velocity = (_home + bob - position) * 2.0
			if _sees_player():
				_enter(State.STALK)
		State.STALK:
			if _player == null or _player.is_dead() or global_position.distance_to(_player.global_position) > lose_range:
				_enter(State.HOVER)
			else:
				var side := signf(global_position.x - _player.global_position.x)
				var perch := _player.global_position + Vector2((side if side != 0.0 else 1.0) * 90.0, -100.0)
				target_velocity = (perch - global_position).limit_length(speed)
				if global_position.distance_to(perch) < 30.0 or _state_time > 3.0:
					_enter(State.WINDUP)
		State.WINDUP:
			_visual.position.x = sin(_state_time * 80.0) * 1.0  # Buzzing jitter.
			if _state_time > 0.45:
				_visual.position.x = 0.0
				_dive_dir = (_player.global_position - global_position).normalized() if _player else Vector2.DOWN
				Sfx.play(&"buzz", global_position)
				_enter(State.DIVE)
		State.DIVE:
			target_velocity = _dive_dir * dive_speed
			if _state_time > 0.6 or get_slide_collision_count() > 0:
				_enter(State.RECOVER)
		State.RECOVER:
			target_velocity = Vector2(0, -speed)
			if _state_time > 0.7:
				_enter(State.STALK)
		State.DEAD:
			velocity.y += 900.0 * delta

	if state != State.DEAD:
		velocity = velocity.lerp(target_velocity, minf(1.0, delta * 8.0)) if state != State.DIVE else target_velocity
		if absf(velocity.x) > 5.0:
			_visual.scale.x = signf(velocity.x)
	move_and_slide()


func _process(_delta: float) -> void:
	if state == State.DEAD:
		_sprite.play(&"die")
	elif _hurt_time > 0.0:
		_sprite.play(&"hurt")
	elif state in [State.WINDUP, State.DIVE]:
		_sprite.play(&"attack")
	else:
		_sprite.play(&"move")


func _enter(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _sees_player() -> bool:
	if _player == null or _player.is_dead():
		return false
	var to_player := _player.global_position - global_position
	if to_player.length() > sight_range:
		return false
	_sight.target_position = to_player
	_sight.force_raycast_update()
	return not _sight.is_colliding()


func _on_hurt(amount: int, from: Vector2, knockback: float) -> void:
	DamageNumber.spawn(get_parent(), global_position, amount)
	velocity = (global_position - from).normalized() * knockback
	_hurt_time = 0.2
	if state in [State.HOVER, State.WINDUP]:
		_enter(State.RECOVER)


func _on_died() -> void:
	_enter(State.DEAD)
	_contact.deactivate()
	Sfx.play(&"enemy_die", global_position)
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(EventBus.entity_killed.emit.bind(self))
