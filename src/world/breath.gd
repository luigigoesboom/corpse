class_name Breath
extends Node
## The god's breath (week 52, D-031): the Lungs still breathe, slowly. One
## breath is PERIOD seconds: an inhale, a hold, an exhale, a rest. While it
## breathes, air moves through the Lungs' WindZones: in on the inhale, out on
## the exhale (each zone says which way "in" is there). The wind pushes the
## host (more while gliding: an updraft can carry a Lung Sac up), floating
## creatures, wind bones and streaks of air; the Lungs' sounds and back wall
## swell with it.
##
## Game adds one; it counts `time` while the game runs (it pauses with the
## game). Everything else asks the static functions:
##   Breath.strength()      -1 (full exhale) .. 0 (still) .. 1 (full inhale)
##   Breath.phase()         &"inhale", &"hold", &"exhale", &"rest"
##   Breath.wind_at(point)  the wind there now, px/s^2
## Tests may set Breath.time.

signal phase_changed(phase: StringName)

const PERIOD := 20.0
const INHALE := 8.0
const HOLD := 2.0
const EXHALE := 8.0

## Seconds of breathing so far.
static var time := 0.0
## Zones, by the WindZones that join and leave (no tree lookups per call).
static var zones: Array = []

var _last_phase: StringName = &""


func _ready() -> void:
	time = 0.0


func _exit_tree() -> void:
	time = 0.0


func _physics_process(delta: float) -> void:
	time += delta
	var now := phase()
	if now != _last_phase:
		_last_phase = now
		phase_changed.emit(now)


## Where in the breath: -1 (full exhale) .. 1 (full inhale), easing in and out.
static func strength() -> float:
	var t := fmod(time, PERIOD)
	if t < INHALE:
		return sin(PI * t / INHALE)
	t -= INHALE + HOLD
	if t >= 0.0 and t < EXHALE:
		return -sin(PI * t / EXHALE)
	return 0.0


static func phase() -> StringName:
	var t := fmod(time, PERIOD)
	if t < INHALE:
		return &"inhale"
	if t < INHALE + HOLD:
		return &"hold"
	if t < INHALE + HOLD + EXHALE:
		return &"exhale"
	return &"rest"


## The wind at a point now (px/s^2): every zone it is in, its inhale wind
## scaled by the breath (reversed on the exhale).
static func wind_at(point: Vector2) -> Vector2:
	var s := strength()
	if is_zero_approx(s):
		return Vector2.ZERO
	var wind := Vector2.ZERO
	for zone in zones:
		if is_instance_valid(zone):
			wind += zone.wind_in(point)
	return wind * s
