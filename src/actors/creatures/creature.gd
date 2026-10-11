class_name Creature
extends CharacterBody2D
## The shared body of creatures made from week 45 on (tools/new_creature.gd
## makes a scene and a script that extends this). A creature script keeps
## its own `State` enum in `state` and fills in:
##   think(delta)   one physics frame of its AI (set velocity, switch states)
##   animation()    which strip to show now (idle, move, windup, attack...)
## and, if it needs them, setup(), hurt() and died(). The base does the rest:
## finds the player, falls (unless `gravity` is 0), flashes when hurt, and on
## death stops its hitboxes, drops `drop_item`, fades out and reports
## entity_killed (so it counts as a kill, gives ichor and stays dead).
##
## Nodes the scene needs: Health, Hurtbox, Visual/Sprite (LayeredSprite),
## Sight (RayCast2D). Optional: ContactHitbox (hurts on touch), and a melee
## Hitbox at Visual/Attack (switched off at start; strike() switches it on).
##
## The Gut's first creatures (Gut Leech, Bile Spitter, Rot Fly) were written
## before this and do not use it.

@export var sight_range := 320.0
## Gives up on the player beyond this distance.
@export var lose_range := 480.0
## Falls at this many px/s^2; 0 for things that fly or float.
@export var gravity := 1400.0
## Item dropped on death (an ItemDef id), or empty.
@export var drop_item: StringName = &""
## How much the god's breath pushes it (week 52): 0 = not at all, 1 = like
## a loose thing. Floaters and gliders feel it; walkers do not.
@export var wind_weight := 0.0

## The creature's own State enum value.
var state := 0
## Seconds since the last enter().
var state_time := 0.0
## Facing: 1 = right, -1 = left. face() also flips Visual.
var dir := 1.0
var player: Player
## Above zero while the hurt flash shows.
var hurt_time := 0.0

@onready var health: Health = $Health
@onready var visual: Node2D = $Visual
@onready var sprite: LayeredSprite = $Visual/Sprite
@onready var sight: RayCast2D = $Sight
@onready var attack_box: Hitbox = get_node_or_null("Visual/Attack") as Hitbox
@onready var contact_box: Hitbox = get_node_or_null("ContactHitbox") as Hitbox

var _strike_left := 0.0


func _ready() -> void:
	health.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	if attack_box:
		attack_box.deactivate()
		attack_box.collision_layer = CombatRules.enemy_attack_layer()
		attack_box.exclude = $Hurtbox  # With friendly fire on, never hit itself.
		attack_box.source = CombatRules.kind_of(self)
	if contact_box:
		contact_box.source = CombatRules.kind_of(self)
	visual.scale.x = dir
	setup()


func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as Player
	state_time += delta
	hurt_time -= delta
	if _strike_left > 0.0:
		_strike_left -= delta
		if _strike_left <= 0.0 and attack_box:
			attack_box.deactivate()
	if gravity > 0.0 and not is_on_floor():
		velocity.y += gravity * delta
	if wind_weight > 0.0:
		velocity += Breath.wind_at(global_position) * wind_weight * delta
	if is_dead():
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if gravity <= 0.0:
			velocity.y = move_toward(velocity.y, 120.0, 400.0 * delta)  # Sinks when dead.
	else:
		think(delta)
	move_and_slide()


func _process(_delta: float) -> void:
	sprite.play(animation())


# --- To fill in ----------------------------------------------------------------------

func setup() -> void:
	pass


func think(_delta: float) -> void:
	pass


func animation() -> StringName:
	if is_dead():
		return &"die"
	if hurt_time > 0.0:
		return &"hurt"
	return &"idle"


## Extra reaction to a hit (the flash and damage number are done already).
func hurt(_amount: int, _from: Vector2, _knockback: float) -> void:
	pass


## Extra things to do on death, before it fades out.
func died() -> void:
	pass


# --- Helpers -------------------------------------------------------------------------

func enter(new_state: int) -> void:
	state = new_state
	state_time = 0.0


func is_dead() -> bool:
	return health.is_dead()


func player_alive() -> bool:
	return player != null and not player.is_dead()


func to_player() -> Vector2:
	return player.global_position - global_position if player else Vector2.INF


## Whether it can see the player: alive, within `within` px (default
## sight_range) and at most `max_dy` above or below, with no rock between.
func sees_player(within := -1.0, max_dy := INF) -> bool:
	if not player_alive():
		return false
	var to := to_player()
	if to.length() > (sight_range if within < 0.0 else within) or absf(to.y) > max_dy:
		return false
	sight.target_position = to
	sight.force_raycast_update()
	return not sight.is_colliding()


## Turns toward dx (ignores tiny differences so it does not flicker).
func face(dx: float) -> void:
	if absf(dx) > 6.0:
		dir = signf(dx)
		visual.scale.x = dir


## Turns around.
func turn() -> void:
	dir = -dir
	visual.scale.x = dir


## Switches the melee Hitbox (Visual/Attack) on for `seconds`.
func strike(seconds := 0.15) -> void:
	if attack_box:
		attack_box.activate()
		_strike_left = seconds


func _on_hurt(amount: int, from: Vector2, knockback: float) -> void:
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -24), amount)
	hurt_time = 0.2
	hurt(amount, from, knockback)


func _on_died() -> void:
	if attack_box:
		attack_box.deactivate()
	if contact_box:
		contact_box.deactivate()
	Sfx.play(&"enemy_die", global_position)
	if drop_item != &"":
		EventBus.item_drop_requested.emit(drop_item, global_position)
	died()
	var tween := create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(EventBus.entity_killed.emit.bind(self))
