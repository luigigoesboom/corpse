class_name CombatFeel
extends Node
## Makes hits feel like hits: a sound, screen shake, and hitstop (the world
## freezes for a few hundredths of a second when a blow lands).
## Put one in any scene with combat and point it at the player.

@export var player: Node2D
## Tests turn this off: the freeze slows the frames they count.
@export var hitstop_enabled := true
@export var hitstop_on_enemy := 0.045
@export var hitstop_on_player := 0.08
@export var shake_on_enemy := 3.0
@export var shake_on_player := 7.0

var _hitstop_until := 0


func _ready() -> void:
	EventBus.hit_landed.connect(_on_hit_landed)


func _exit_tree() -> void:
	Engine.time_scale = 1.0  # Never leave the game frozen after a scene change.


func _on_hit_landed(target: Node, _amount: int) -> void:
	var on_player := target == player
	Sfx.play(&"hurt" if on_player else &"hit", target.global_position)
	if player:
		player.shake(shake_on_player if on_player else shake_on_enemy)
	if hitstop_enabled:
		_hitstop(hitstop_on_player if on_player else hitstop_on_enemy)


func _hitstop(seconds: float) -> void:
	# Engine.time_scale slows everything that uses delta. The timer below
	# ignores time scale (last argument), so it ends on real time.
	Engine.time_scale = 0.02
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(seconds * 1000.0))
	await get_tree().create_timer(seconds, true, false, true).timeout
	if Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0
