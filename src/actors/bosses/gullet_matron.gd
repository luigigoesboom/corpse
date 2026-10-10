class_name GulletMatron
extends CharacterBody2D
## The Gullet Matron: a bloated bile-worm mother, the Gut's first boss
## (roadmap week 38, pulled forward).
##
## One state machine. Every attack goes WINDUP (a telegraph you can read: a
## pose, a flash, a sound; the slam marks where it will land) -> ACTIVE (the
## dangerous part) -> RECOVER (a window to punish her). Between attacks she
## STALKs and picks the next one by distance and phase, never the same one
## three times running.
##
##   DORMANT -> INTRO -> STALK <-> WINDUP -> ACTIVE -> RECOVER -> STALK
##   any fighting state -> STAGGER (enough hits, quickly) -> STALK
##   at half health, once -> PHASE_SHIFT (roars; faster, new attacks) -> STALK
##   -> DEAD
##
## Attacks (ATTACKS below): LUNGE (roll through her or get away), VOLLEY
## (bile globs that pool and burn), SLAM (leaps, crashes where marked, sends
## shockwaves you jump or roll), SWEEP (tail across the floor when you stand
## close: jump), BROOD (phase 2, spits out leeches; her own bile hurts them).
## Her body only hurts while she moves into you and when a slam lands: it is
## safe to stand next to her while she winds up, lunges past, or rests.

signal state_changed(state: State)

enum State { DORMANT, INTRO, STALK, WINDUP, ACTIVE, RECOVER, STAGGER, PHASE_SHIFT, DEAD }
enum Attack { NONE, LUNGE, VOLLEY, SLAM, SWEEP, BROOD }

## Per attack: seconds of windup / active / recover, distance band she uses
## it at, which phase unlocks it, and how often she picks it.
const ATTACKS := {
	Attack.LUNGE: {"windup": 0.7, "active": 0.42, "recover": 1.0, "min": 70.0, "max": 330.0, "phase": 1, "weight": 3.0, "anim": &"windup"},
	Attack.VOLLEY: {"windup": 0.6, "active": 0.35, "recover": 0.8, "min": 140.0, "max": 700.0, "phase": 1, "weight": 1.5, "anim": &"spit"},
	Attack.SLAM: {"windup": 0.55, "active": 2.0, "recover": 1.1, "min": 0.0, "max": 520.0, "phase": 1, "weight": 2.0, "anim": &"leap"},
	Attack.SWEEP: {"windup": 0.55, "active": 0.3, "recover": 0.7, "min": 0.0, "max": 130.0, "phase": 1, "weight": 3.0, "anim": &"sweep"},
	Attack.BROOD: {"windup": 0.9, "active": 0.3, "recover": 0.9, "min": 0.0, "max": 99999.0, "phase": 2, "weight": 1.2, "anim": &"roar"},
}
const GLOB := preload("res://src/actors/bosses/bile_glob.tscn")
const SHOCKWAVE := preload("res://src/actors/bosses/shockwave.tscn")
const LEECH := preload("res://src/actors/creatures/gut_leech.tscn")

@export var display_name := "The Gullet Matron"
## The fight starts when the player comes this close.
@export var wake_range := 420.0
@export var move_speed := 70.0
@export var lunge_speed := 640.0
@export var slam_jump_speed := 760.0
## Hits within the poise window that stagger her (more in phase 2).
@export var poise := 6
@export var stagger_time := 2.2
@export var brood_cooldown := 14.0

var state := State.DORMANT
var attack := Attack.NONE
var phase := 1
## Seconds spent in the current state.
var state_time := 0.0

var _gravity := 1500.0
var _facing := 1.0
var _player: Node2D
var _rng := RandomNumberGenerator.new()
var _history: Array = []  # Last attacks, newest last.
var _think := 1.0
var _poise_damage := 0.0
## No staggering again until then (and each stagger makes the next harder).
var _poise_immune_until := 0.0
var _staggers := 0
var _flash := 0.0
var _airborne := false
var _slam_target_x := 0.0
var _brood_ready_at := 0.0
var _clock := 0.0
var _brood: Array[Node] = []

@onready var health: Health = $Health
@onready var _visual: Node2D = $Visual
@onready var _sprite: LayeredSprite = $Visual/Sprite
@onready var _mouth: Hitbox = $Visual/MouthHitbox
@onready var _tail: Hitbox = $TailHitbox
@onready var _contact: Hitbox = $ContactHitbox
@onready var _marker: Node2D = $SlamMarker


func _ready() -> void:
	_rng.seed = hash(name)
	health.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	health.invulnerable = true  # Until she rises.
	for hitbox in [_mouth, _tail, _contact]:
		hitbox.collision_layer = CombatRules.enemy_attack_layer()
		hitbox.exclude = $Hurtbox
		hitbox.deactivate()
	_visual.visible = false
	_marker.top_level = true
	_marker.visible = false


func _physics_process(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node2D
	_clock += delta
	state_time += delta
	_poise_damage = maxf(0.0, _poise_damage - delta * 0.75)  # Staggers you have to keep up the pressure for.
	if not is_on_floor():
		velocity.y += _gravity * delta
	match state:
		State.DORMANT:
			if _player and global_position.distance_to(_player.global_position) < wake_range:
				_enter(State.INTRO)
		State.INTRO:
			_visual.position.y = lerpf(70.0, 0.0, clampf(state_time / 1.2, 0.0, 1.0))
			_play(&"roar" if state_time > 1.2 else &"idle")
			if state_time > 2.2:
				health.invulnerable = false
				_enter(State.STALK)
		State.STALK:
			_stalk(delta)
		State.WINDUP:
			_windup()
		State.ACTIVE:
			_active(delta)
		State.RECOVER:
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
			_play(&"stagger" if attack in [Attack.LUNGE, Attack.SLAM] else &"idle")
			if state_time > _time(&"recover"):
				_enter(State.STALK)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 1800.0 * delta)
			_play(&"stagger")
			if state_time > stagger_time:
				_enter(State.STALK)
		State.PHASE_SHIFT:
			velocity.x = 0.0
			_play(&"roar")
			if state_time > 1.8:
				health.invulnerable = false
				_enter(State.STALK)
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
	move_and_slide()
	_visual.scale.x = _facing
	_flash = maxf(0.0, _flash - delta)
	var tint := Color(1.25, 1.1, 0.7) if state == State.WINDUP and int(state_time * 12.0) % 2 == 0 else Color.WHITE
	if phase == 2:
		tint *= Color(1.1, 0.85, 0.85)
	_visual.modulate = Color(2, 2, 2) if _flash > 0.0 else tint


# --- States ------------------------------------------------------------------

func _stalk(delta: float) -> void:
	if _player == null:
		return
	var dx := _player.global_position.x - global_position.x
	_facing = signf(dx) if absf(dx) > 8.0 else _facing
	var speed := move_speed * (1.3 if phase == 2 else 1.0)
	var want := 160.0
	velocity.x = move_toward(velocity.x, _facing * speed if absf(dx) > want else -_facing * speed * 0.5, 600.0 * delta)
	_play(&"move" if absf(velocity.x) > 10.0 else &"idle")
	# Her bulk only hurts when it is moving into you.
	var pushing := velocity.x * signf(dx) > 30.0
	if pushing and not _contact.active:
		_contact.activate()
	elif not pushing and _contact.active:
		_contact.deactivate()
	_think -= delta
	if _think <= 0.0:
		var next := _choose_attack(absf(dx))
		if absf(dx) < 100.0 and next != Attack.SWEEP and _rng.randf() < 0.6 and _history.back() != Attack.SWEEP:
			next = Attack.SWEEP  # Standing on top of her is not safe.
		if next != Attack.NONE:
			attack = next
			_history.append(next)
			_enter(State.WINDUP)


func _windup() -> void:
	velocity.x = 0.0
	if attack == Attack.SLAM and _player and not _marker.visible:
		# Where she will land: where you stood when she crouched. Leave it.
		_slam_target_x = _player.global_position.x
		_show_marker(_slam_target_x)
	elif _player and attack != Attack.LUNGE and attack != Attack.SLAM:
		_facing = signf(_player.global_position.x - global_position.x) if _player.global_position.x != global_position.x else _facing
	_play(ATTACKS[attack].anim)
	if state_time > _time(&"windup"):
		_enter(State.ACTIVE)


func _active(delta: float) -> void:
	match attack:
		Attack.LUNGE:
			velocity.x = _facing * lunge_speed
			_play(&"lunge")
			if state_time > _time(&"active") or is_on_wall():
				_end_attack()
		Attack.VOLLEY:
			_play(&"spit")
			if state_time > _time(&"active"):
				_end_attack()
		Attack.SLAM:
			_play(&"leap" if velocity.y < 0.0 else &"slam")
			# Crushing only on the way down: rising past you does not hurt.
			if velocity.y > 0.0 and not _contact.active:
				_contact.activate()
			if _airborne and is_on_floor():
				_land()
			elif state_time > _time(&"active"):
				_land()
		Attack.SWEEP:
			_play(&"sweep")
			if state_time > _time(&"active"):
				_end_attack()
		Attack.BROOD:
			_play(&"roar")
			if state_time > _time(&"active"):
				_end_attack()


## Called when entering ACTIVE: the moment the attack goes off.
func _start_active() -> void:
	match attack:
		Attack.LUNGE:
			_mouth.activate()
			Sfx.play(&"dash", global_position)
		Attack.VOLLEY:
			_spit_volley()
		Attack.SLAM:
			var dx := _slam_target_x - global_position.x
			var air_time := 2.0 * slam_jump_speed / _gravity
			velocity = Vector2(clampf(dx / air_time, -520.0, 520.0), -slam_jump_speed)
			_facing = signf(dx) if dx != 0.0 else _facing
			_airborne = true
			Sfx.play(&"jump", global_position)
		Attack.SWEEP:
			_tail.activate()
			Sfx.play(&"swing", global_position)
		Attack.BROOD:
			_spawn_brood()


func _land() -> void:
	_airborne = false
	_marker.visible = false
	velocity.x = 0.0
	EventBus.shake_requested.emit(12.0)
	Sfx.play(&"enemy_die", global_position)
	for direction in [-1.0, 1.0]:
		var wave := SHOCKWAVE.instantiate()
		wave.direction = direction
		wave.maker_hurtbox = $Hurtbox
		wave.position = global_position + Vector2(direction * 40.0, 0)
		get_parent().add_child(wave)
	_end_attack()


func _end_attack() -> void:
	_mouth.deactivate()
	_tail.deactivate()
	_contact.deactivate()
	_enter(State.RECOVER)


func _spit_volley() -> void:
	if _player == null:
		return
	var count := 4 if phase == 2 else 3
	Sfx.play(&"spit", global_position)
	for i in count:
		var glob := GLOB.instantiate()
		glob.thrower_hurtbox = $Hurtbox
		glob.position = global_position + Vector2(_facing * 40.0, -60.0)
		# Aimed to land around the player: one on them, the rest spread out.
		var land_x: float = _player.global_position.x + (i - (count - 1) / 2.0) * 95.0
		var flight := 0.9 + 0.08 * i
		var dy: float = _player.global_position.y + 20.0 - glob.position.y
		glob.velocity = Vector2((land_x - glob.position.x) / flight, (dy - 0.5 * 650.0 * flight * flight) / flight)
		get_parent().add_child(glob)


func _spawn_brood() -> void:
	_brood_ready_at = _clock + brood_cooldown
	EventBus.shake_requested.emit(5.0)
	for side in [-1.0, 1.0]:
		var leech := LEECH.instantiate()
		leech.name = "MatronBrood%d" % _rng.randi()
		leech.position = global_position + Vector2(side * 70.0, -10.0)
		get_parent().add_child(leech)
		_brood.append(leech)


func _show_marker(x: float) -> void:
	var hit := get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(Vector2(x, global_position.y - 200.0), Vector2(x, global_position.y + 400.0), 1))
	_marker.global_position = hit.position if hit else Vector2(x, global_position.y)
	_marker.visible = true


# --- Choosing, timing --------------------------------------------------------

## Weighted pick among attacks unlocked in this phase whose distance band
## fits, never the same one three times running, brood only off cooldown and
## when few of her brood are left.
func _choose_attack(distance: float) -> Attack:
	_brood = _brood.filter(func(b): return is_instance_valid(b) and b.is_inside_tree())
	var options := []
	var total := 0.0
	for id in ATTACKS:
		var a: Dictionary = ATTACKS[id]
		if a.phase > phase or distance < a.min or distance > a.max:
			continue
		if _history.size() >= 2 and _history[-1] == id and _history[-2] == id:
			continue
		if id == Attack.BROOD and (_clock < _brood_ready_at or _brood.size() > 1):
			continue
		options.append(id)
		total += a.weight
	if options.is_empty():
		_think = 0.2
		return Attack.NONE
	var roll := _rng.randf() * total
	for id in options:
		roll -= ATTACKS[id].weight
		if roll <= 0.0:
			return id
	return options[-1]


## An attack's timing in the current phase: phase 2 telegraphs and rests 20% shorter.
func _time(part: StringName) -> float:
	var base: float = ATTACKS[attack][String(part)]
	return base * (0.8 if phase == 2 and part != &"active" else 1.0)


## Seconds left in the current windup (for players, bots and tests).
func telegraph_left() -> float:
	return maxf(0.0, _time(&"windup") - state_time) if state == State.WINDUP else 0.0


func _enter(next: State) -> void:
	state = next
	state_time = 0.0
	# Body contact hurts while she stalks into you (see _stalk) and while a
	# slam comes down on you (see _active), never otherwise.
	_contact.deactivate()
	match next:
		State.INTRO:
			_visual.visible = true
			_visual.position.y = 70.0
			Sfx.play(&"die", global_position)
			EventBus.boss_engaged.emit(self)
		State.STALK:
			attack = Attack.NONE
			_think = _rng.randf_range(0.4, 0.9) if phase == 2 else _rng.randf_range(0.6, 1.2)
			if _player and absf(_player.global_position.x - global_position.x) < 100.0:
				_think *= 0.4  # Someone is hugging her: she reacts fast.
		State.WINDUP:
			Sfx.play(&"hurt" if attack == Attack.BROOD else &"swing", global_position)
		State.ACTIVE:
			_start_active()
		State.STAGGER, State.PHASE_SHIFT:
			_mouth.deactivate()
			_tail.deactivate()
			_marker.visible = false
			_airborne = false
	state_changed.emit(next)


func _play(animation: StringName) -> void:
	_sprite.play(animation)


# --- Getting hurt --------------------------------------------------------------

func _on_hurt(amount: int, _from: Vector2, _knockback: float) -> void:
	_flash = 0.07
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -90), amount, Color(1, 0.85, 0.6))
	if phase == 1 and health.current <= health.max_health / 2:
		phase = 2
		health.invulnerable = true
		EventBus.shake_requested.emit(10.0)
		EventBus.notify.emit("%s howls. Something in her splits open." % display_name)
		_enter(State.PHASE_SHIFT)
		return
	if _clock < _poise_immune_until:
		return
	_poise_damage += amount
	var limit := poise + (2 if phase == 2 else 0) + 2 * _staggers
	# She cannot be staggered out of the air, and not again for a while.
	if _poise_damage >= limit and state in [State.STALK, State.WINDUP, State.RECOVER] and not _airborne:
		_poise_damage = 0.0
		_staggers += 1
		_poise_immune_until = _clock + stagger_time + 6.0
		_enter(State.STAGGER)


func _on_died() -> void:
	state = State.DEAD
	state_time = 0.0
	for hitbox in [_mouth, _tail, _contact]:
		hitbox.deactivate()
	_marker.visible = false
	$Hurtbox.set_deferred(&"monitoring", false)
	_play(&"die")
	EventBus.shake_requested.emit(14.0)
	EventBus.notify.emit("%s is dead." % display_name)
	for leech in _brood:
		if is_instance_valid(leech):
			leech.get_node("Health").take_damage(99, global_position)
	await get_tree().create_timer(1.6).timeout
	_drop_loot()
	EventBus.boss_defeated.emit(self)
	EventBus.entity_killed.emit(self)


func _drop_loot() -> void:
	for i in 3:
		EventBus.item_drop_requested.emit([&"bile_bulb", &"bone_shard", &"bile_bulb"][i], global_position + Vector2((i - 1) * 30.0, 0))
	var data := WorldState.data
	if data:
		var life := data.current_life()
		data.log_event(&"boss_slain", [life.host_name if life else "someone"], {"boss": display_name})
