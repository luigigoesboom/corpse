class_name ColonyNpc
extends Node2D
## A settlement resident (week 27). Idles, strolls, works at its settlement's
## work spots, chats with a neighbour, turns to look at the player when close,
## and says something now and then (its Settlement decides when).
##
## Walks along the floor without physics: settlements sit on flat ground, and
## residents are children of their Settlement, at y = 0 (the floor line).
##
## When its people are hostile to the host (week 31), guards come at the
## player with a telegraphed swing and the rest flee to the far end; hitting
## or killing a resident is a deed its Settlement reports.

enum State { IDLE, WALK, WORK, CHAT, FLEE, GUARD }

const WALK_SPEED := 36.0
## Closer than this, an idle resident turns to look at the player.
const LOOK_RANGE := 70.0
const BARK_SECONDS := 3.5
## Closer than this, its name tag offers a talk.
const TALK_RANGE := 50.0
const FLEE_SPEED := 70.0
const GUARD_SPEED := 75.0
## A guard swings when the player is this close...
const SWING_RANGE := 30.0
## ...after a wind-up you can see (and dodge), then rests.
const WINDUP := 0.4
const SWING_COOLDOWN := 1.1
## Guards do not chase further than this past the settlement's edge.
const GUARD_LEASH := 90.0
## Perception (week 36): how far it sees in front, how fast it notices
## someone fully visible (per second, scaled by Player.visibility()), how
## fast noise in earshot alerts it, and how long it remembers.
const SIGHT_RANGE := 220.0
const SIGHT_RATE := 1.8
const HEARING_RATE := 2.5
const TOUCH_RANGE := 26.0
const FORGET_SECONDS := 4.0

var npc_name := ""
var state := State.IDLE
var settlement: Settlement
## Guards fight when their people are hostile; the others flee.
var is_guard := false

var _timer := 0.0
var _target_x := 0.0
var _facing := 1.0
var _work_spot := -1
var _bark_timer := 0.0
var _rng := RandomNumberGenerator.new()
var _windup := 0.0
var _swing_cooldown := 0.0
var _flinch := 0.0
## Perception (week 36): 0..1, how sure it is someone is there. At 1 it has
## noticed the player; it stays noticed while the player is near or seen.
var awareness := 0.0
var noticed := false
## A guard post's sentry stands at `home_x` and looks one way, then the other.
var stationed := false
var home_x := 0.0
var _forget := 0.0
var _mark: Label

@onready var sprite: LayeredSprite = $Visual/Sprite
@onready var _visual: Node2D = $Visual
@onready var _name: Label = $Name
@onready var _bark: Label = $Bark
@onready var health: Health = $Health
@onready var _hitbox: Hitbox = $Visual/Hitbox


## Call before adding it to the tree.
func setup(home: Settlement, resident_name: String, frames_dir: String, rng_seed: int) -> void:
	settlement = home
	npc_name = resident_name
	$Visual/Sprite.body_frames_dir = frames_dir
	_rng.seed = rng_seed
	_facing = -1.0 if _rng.randf() < 0.5 else 1.0


func _ready() -> void:
	_name.text = npc_name
	_bark.visible = false
	_timer = _rng.randf_range(0.5, 3.0)  # Neighbours do not all start in step.
	_hitbox.deactivate()
	_mark = Label.new()
	_mark.material = _name.material
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.position = Vector2(-20, -96)
	_mark.size = Vector2(40, 20)
	_mark.add_theme_font_size_override(&"font_size", 32)
	_mark.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_mark.add_theme_constant_override(&"outline_size", 4)
	add_child(_mark)
	health.hurt.connect(_on_hurt)
	health.died.connect(_on_died)


func _process(delta: float) -> void:
	_timer -= delta
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var distance := player.global_position.distance_to(global_position) if player else INF
	var hostile := settlement != null and settlement.is_hostile() and player != null
	var watching := settlement != null and player != null and settlement.watches_player()
	_perceive(delta, player, watching)
	if _flinch > 0.0:
		_flinch -= delta
		_visual.modulate = Color(1, 0.5, 0.5) if _flinch > 0.0 else Color.WHITE
	elif hostile and noticed:
		if is_guard:
			_guard(delta, player)
		else:
			_flee(delta, player)
	elif watching and noticed and is_guard:
		_block(delta, player)  # A post warns before it fights.
	else:
		if state == State.FLEE or state == State.GUARD:
			_end_alarm()
		_daily(delta, player, distance)

	var named := settlement == null or settlement.nearest_to_player == self  # One name at a time.
	_name.modulate.a = clampf(1.0 - (distance - 60.0) / 60.0, 0.0, 1.0) if named else 0.0
	_name.text = ("E: talk to %s" % npc_name) if named and distance < TALK_RANGE and not hostile else npc_name
	_name.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if hostile else Color.WHITE)
	if _bark_timer > 0.0:
		_bark_timer -= delta
		_bark.visible = _bark_timer > 0.0

	_visual.scale.x = _facing
	match state:
		State.WALK:
			sprite.play(&"run")
			sprite.speed_scale = 0.5  # The run cycle, slowed to a stroll.
		State.FLEE:
			sprite.play(&"run")
			sprite.speed_scale = 1.0
		State.GUARD:
			sprite.play(&"work" if _windup > 0.0 or _hitbox.active else &"run")
			sprite.speed_scale = 1.6 if _windup > 0.0 else 0.9
		State.WORK:
			sprite.play(&"work")
			sprite.speed_scale = 1.0
		_:
			sprite.play(&"idle")
			sprite.speed_scale = 1.0


## Perception (week 36). While its people keep the player out (a hostile
## settlement, a guard post), it looks and listens: sight within a cone in
## front (sneaking and darkness help), noise all around (Player.noise_radius()).
## Hurting it, or anyone near, makes it notice at once.
func _perceive(delta: float, player: Node2D, watching: bool) -> void:
	if not watching:
		awareness = maxf(0.0, awareness - delta)
		noticed = false
		_mark.text = ""
		return
	var offset := player.global_position - global_position
	var distance := offset.length()
	var gain := 0.0
	var in_front := signf(offset.x) == _facing or absf(offset.x) < 4.0
	if distance < TOUCH_RANGE:
		gain += 1.0 if player.is_sneaking() else 3.0  # Brushing past: felt, light or dark.
	elif in_front and absf(offset.x) < SIGHT_RANGE and absf(offset.y) < 70.0:
		gain += SIGHT_RATE * player.visibility() * (1.2 - absf(offset.x) / SIGHT_RANGE)
	if distance < player.noise_radius():
		gain += HEARING_RATE
	if gain > 0.0:
		awareness = minf(1.0, awareness + gain * delta)
		_forget = FORGET_SECONDS
	else:
		awareness = maxf(0.0, awareness - delta * 0.35)
		if noticed:
			_forget -= delta
			if _forget <= 0.0 and distance > SIGHT_RANGE:
				noticed = false
	if awareness >= 1.0 and not noticed:
		noticed = true
		_facing = signf(offset.x) if offset.x != 0.0 else _facing
		Sfx.play(&"hit", global_position)
	_mark.text = "!" if noticed else ("?" if awareness > 0.15 else "")
	_mark.add_theme_color_override(&"font_color", Color(1, 0.35, 0.3) if noticed else Color(1, 0.9, 0.5))


## Notices the player at once (an alarm was raised).
func alert() -> void:
	awareness = 1.0
	noticed = true
	_forget = FORGET_SECONDS


## A post's sentry has seen you: step between you and what it guards, face
## you, and warn. The post decides when warning turns to fighting.
func _block(delta: float, player: Node2D) -> void:
	if state != State.IDLE:
		_release_work_spot()
		state = State.IDLE
	var local_player := settlement.to_local(player.global_position)
	var bounds := settlement.walk_bounds()
	var want := clampf(local_player.x + signf(position.x - local_player.x) * 26.0, bounds.x, bounds.y)
	position.x = move_toward(position.x, want, GUARD_SPEED * 0.6 * delta)
	_facing = signf(local_player.x - position.x) if local_player.x != position.x else _facing
	if _bark_timer <= 0.0:
		say(settlement.warning_line())


## Ordinary life: work, stroll, chat, look at whoever comes close.
func _daily(delta: float, player: Node2D, distance: float) -> void:
	if stationed:
		# Stand watch: back to the post, then look one way, then the other.
		position.x = move_toward(position.x, home_x, WALK_SPEED * delta)
		state = State.WALK if absf(position.x - home_x) > 1.0 else State.IDLE
		if _timer <= 0.0:
			_facing = -_facing
			_timer = _rng.randf_range(2.5, 4.5)
		return
	match state:
		State.WALK:
			var dx := _target_x - position.x
			if absf(dx) < 1.0:
				position.x = _target_x
				_arrive()
			else:
				_facing = signf(dx)
				position.x += _facing * minf(WALK_SPEED * delta, absf(dx))
		_:
			if _timer <= 0.0:
				_choose_next()
	if state == State.IDLE and distance < LOOK_RANGE:
		_facing = signf(player.global_position.x - global_position.x) if player.global_position.x != global_position.x else _facing


## Run to the end of the settlement away from the player.
func _flee(delta: float, player: Node2D) -> void:
	if state != State.FLEE:
		_release_work_spot()
		state = State.FLEE
	var away := -signf(player.global_position.x - global_position.x)
	if away == 0.0:
		away = 1.0
	var bounds := settlement.walk_bounds()
	var target := bounds.y if away > 0.0 else bounds.x
	_facing = away
	position.x = move_toward(position.x, target, FLEE_SPEED * delta)


## Close in, wind up, swing; never far from home.
func _guard(delta: float, player: Node2D) -> void:
	if state != State.GUARD:
		_release_work_spot()
		state = State.GUARD
	_swing_cooldown -= delta
	var local_player := settlement.to_local(player.global_position)
	var bounds := settlement.walk_bounds()
	var home_x := clampf(local_player.x, bounds.x - GUARD_LEASH, bounds.y + GUARD_LEASH)
	var dx := local_player.x - position.x
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_hitbox.activate()
			_swing_cooldown = SWING_COOLDOWN
			Sfx.play(&"swing", global_position)
		return
	if _hitbox.active and _swing_cooldown < SWING_COOLDOWN - 0.15:
		_hitbox.deactivate()
	_facing = signf(dx) if dx != 0.0 else _facing
	if absf(dx) < SWING_RANGE and absf(local_player.y) < 60.0:
		if _swing_cooldown <= 0.0:
			_windup = WINDUP
	else:
		position.x = move_toward(position.x, home_x, GUARD_SPEED * delta)


func _end_alarm() -> void:
	_hitbox.deactivate()
	_windup = 0.0
	state = State.IDLE
	_timer = _rng.randf_range(1.0, 3.0)


func _on_hurt(amount: int, from: Vector2, _knockback: float) -> void:
	_flinch = 0.25
	_windup = 0.0
	_hitbox.deactivate()
	position.x += signf(global_position.x - from.x) * 8.0
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -40), amount, Color(1, 0.8, 0.6))
	if settlement:
		settlement.resident_hurt(self)


func _on_died() -> void:
	if settlement:
		settlement.resident_died(self)
	queue_free()


## E on its TalkArea: stop, face the player, talk (week 30).
func talk() -> Talk:
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player:
		_facing = signf(player.global_position.x - global_position.x) if player.global_position.x != global_position.x else _facing
	_release_work_spot()
	state = State.IDLE
	_timer = 3.0
	var faction: StringName = settlement.site.faction if settlement and settlement.site else &""
	var bribe: Array = settlement.bribe_offer() if settlement and is_guard else ["", 0]
	return Conversation.start(self, npc_name, faction, _rng.randi(), bribe[0], bribe[1])


## Shows a line over its head for a few seconds.
func say(text: String) -> void:
	_bark.text = text
	_bark.visible = true
	_bark_timer = BARK_SECONDS


func chat_with(other: ColonyNpc, seconds: float) -> void:
	_release_work_spot()
	state = State.CHAT
	_timer = seconds
	_facing = signf(other.position.x - position.x) if other.position.x != position.x else _facing


func _choose_next() -> void:
	_release_work_spot()
	var roll := _rng.randf()
	if roll < 0.45:
		_work_spot = settlement.claim_work_spot(self)
		if _work_spot >= 0:
			_walk_to(settlement.work_x(_work_spot))
			return
	if roll < 0.6:
		var neighbour := settlement.idle_neighbour(self, 90.0)
		if neighbour:
			var seconds := _rng.randf_range(3.0, 6.0)
			chat_with(neighbour, seconds)
			neighbour.chat_with(self, seconds)
			return
	if roll < 0.85:
		var bounds := settlement.walk_bounds()
		_walk_to(_rng.randf_range(bounds.x, bounds.y))
		return
	state = State.IDLE
	_timer = _rng.randf_range(2.0, 5.0)


func _walk_to(x: float) -> void:
	state = State.WALK
	_target_x = x


func _arrive() -> void:
	if _work_spot >= 0:
		state = State.WORK
		_facing = settlement.work_facing(_work_spot)
		_timer = _rng.randf_range(5.0, 11.0)
	else:
		state = State.IDLE
		_timer = _rng.randf_range(1.5, 4.0)


func _release_work_spot() -> void:
	if _work_spot >= 0:
		settlement.release_work_spot(_work_spot)
		_work_spot = -1
