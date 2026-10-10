class_name ColonyNpc
extends Node2D
## A settlement resident (week 27). Idles, strolls, works at its settlement's
## work spots, chats with a neighbour, turns to look at the player when close,
## and says something now and then (its Settlement decides when).
##
## Walks along the floor without physics: settlements sit on flat ground, and
## residents are children of their Settlement, at y = 0 (the floor line).

enum State { IDLE, WALK, WORK, CHAT }

const WALK_SPEED := 36.0
## Closer than this, an idle resident turns to look at the player.
const LOOK_RANGE := 70.0
const BARK_SECONDS := 3.5

var npc_name := ""
var state := State.IDLE
var settlement: Settlement

var _timer := 0.0
var _target_x := 0.0
var _facing := 1.0
var _work_spot := -1
var _bark_timer := 0.0
var _rng := RandomNumberGenerator.new()

@onready var sprite: LayeredSprite = $Visual/Sprite
@onready var _visual: Node2D = $Visual
@onready var _name: Label = $Name
@onready var _bark: Label = $Bark


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


func _process(delta: float) -> void:
	_timer -= delta
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

	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var distance := player.global_position.distance_to(global_position) if player else INF
	if state == State.IDLE and distance < LOOK_RANGE:
		_facing = signf(player.global_position.x - global_position.x) if player.global_position.x != global_position.x else _facing
	var named := settlement == null or settlement.nearest_to_player == self  # One name at a time.
	_name.modulate.a = clampf(1.0 - (distance - 60.0) / 60.0, 0.0, 1.0) if named else 0.0
	if _bark_timer > 0.0:
		_bark_timer -= delta
		_bark.visible = _bark_timer > 0.0

	_visual.scale.x = _facing
	match state:
		State.WALK:
			sprite.play(&"run")
			sprite.speed_scale = 0.5  # The run cycle, slowed to a stroll.
		State.WORK:
			sprite.play(&"work")
			sprite.speed_scale = 1.0
		_:
			sprite.play(&"idle")
			sprite.speed_scale = 1.0


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
