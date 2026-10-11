class_name BodyMoods
extends Node
## The god's body has moods while you live in it (D-033). Every few minutes
## of play it falls into one for a while, announced across the screen:
##   spasm  the body convulses: the camera shakes, debris falls from the
##          ceilings around the host (FallingDebris, it hurts)
##   fever  the air burns (Atmosphere), the host runs faster, rot thickens
##          where the host walks
##   surge  the heart pounds: kills give twice the ichor
##   hush   the body holds its breath: the Lungs' wind stops, the host's
##          steps are half as loud
##   dream  the god dreams aloud: whispers of things that happened in this
##          world (the event log)
## Spasms and fevers are written into the log. Not saved: a mood ends with
## the scene. Random on purpose (not seeded): the body is not predictable.
## Game adds one.

const MOODS := [&"spasm", &"fever", &"surge", &"hush", &"dream"]
const TITLES := {
	&"spasm": ["The body spasms", "Hold on to something.", "The walls convulse", "Something deep in the god clenches."],
	&"fever": ["Fever", "The god burns. The air shimmers.", "The body runs hot", "Its blood boils somewhere near."],
	&"surge": ["The heart surges", "Ichor runs thick in every wound.", "A great beat", "The heart remembers it is a heart."],
	&"hush": ["The body holds its breath", "Everything listens.", "A hush", "Even the walls are quiet."],
	&"dream": ["The god dreams", "It dreams of what happened here.", "The god talks in its sleep", "Listen."],
}
## Seconds between moods, and how long one lasts.
const GAP := Vector2(150.0, 300.0)
const LENGTH := Vector2(40.0, 80.0)

## Whether moods come by themselves (tests turn it off: random shakes and
## falling rocks would make them flaky; begin() still works).
static var enabled := true
## What the rest of the game reads.
static var mood: StringName = &""
static var ichor_scale := 1.0
static var noise_scale := 1.0
static var speed_scale := 1.0

var player: Node2D
var time_left := 0.0
var until_next := 0.0
var _rng := RandomNumberGenerator.new()
var _tick := 0.0


func _ready() -> void:
	_rng.randomize()
	until_next = _rng.randf_range(GAP.x * 0.6, GAP.y * 0.6)
	_reset()


func _exit_tree() -> void:
	_reset()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if mood == &"":
		if not enabled:
			return
		until_next -= delta
		if until_next <= 0.0:
			begin(MOODS[_rng.randi() % MOODS.size()])
		return
	time_left -= delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = _pulse()
	if time_left <= 0.0:
		end()


## Starts a mood now (tests call this too).
func begin(which: StringName, seconds := -1.0) -> void:
	end()
	mood = which
	time_left = seconds if seconds > 0.0 else _rng.randf_range(LENGTH.x, LENGTH.y)
	_tick = 0.5
	var words: Array = TITLES[which]
	var pick := (_rng.randi() % (words.size() / 2)) * 2
	EventBus.place_entered.emit(words[pick], words[pick + 1], false)
	match which:
		&"surge":
			ichor_scale = 2.0
		&"hush":
			noise_scale = 0.5
			Breath.held = true
		&"fever":
			speed_scale = 1.15
	if which in [&"spasm", &"fever"] and WorldState.data:
		var place := WorldMap.region_of(player.global_position) if player else Regions.GUT
		WorldState.data.log_event(&"body_mood", [], {"mood": which, "region": place})


func end() -> void:
	if mood != &"":
		until_next = _rng.randf_range(GAP.x, GAP.y)
	_reset()


func _reset() -> void:
	mood = &""
	ichor_scale = 1.0
	noise_scale = 1.0
	speed_scale = 1.0
	Breath.held = false


## What the mood does now and then. Returns seconds until the next pulse.
func _pulse() -> float:
	match mood:
		&"spasm":
			EventBus.shake_requested.emit(_rng.randf_range(4.0, 9.0))
			Sfx.play(&"matron_slam", player.global_position if player else Vector2.ZERO)
			for i in _rng.randi_range(1, 3):
				_drop_debris()
			return _rng.randf_range(2.5, 5.0)
		&"fever":
			if player and WorldState.data and WorldState.data.rot_width > 0:
				var cell := Vector2i((player.global_position / 32.0 / Rot.CELL).floor())
				var i := cell.y * WorldState.data.rot_width + cell.x
				if i >= 0 and i < WorldState.data.rot.size():
					WorldState.data.rot[i] = mini(255, WorldState.data.rot[i] + 3)
			return 1.0
		&"dream":
			_whisper()
			return _rng.randf_range(7.0, 12.0)
	return 1.0


## A rock of flesh falls from the ceiling somewhere near the host.
func _drop_debris() -> void:
	if player == null or not is_instance_valid(player):
		return
	var tile := Vector2i(((player.global_position + Vector2(_rng.randf_range(-280, 280), -40)) / 32.0).floor())
	var chunks := get_parent().get_node_or_null("ChunkManager")
	if chunks == null or chunks.map == null:
		return
	var map: WorldMap = chunks.map
	for up in 14:
		var t := tile - Vector2i(0, up)
		if map.is_solid(t) and not map.is_solid(t + Vector2i.DOWN):
			var debris := FallingDebris.new()
			debris.position = Vector2(t.x * 32 + 16, (t.y + 1) * 32 + 4)
			get_parent().add_child(debris)
			return


## The god murmurs something that happened, in its own words.
func _whisper() -> void:
	var data := WorldState.data
	if data == null or data.events.is_empty():
		return
	var event: EventRecord = data.events[_rng.randi() % data.events.size()]
	var said := EventText.describe(event, data)
	var frames := ["...%s..." , "...I remember. %s", "...%s ...was that me?", "...in my sleep... %s", "...%s I felt that."]
	EventBus.notify.emit(frames[_rng.randi() % frames.size()] % said.trim_suffix("."))
