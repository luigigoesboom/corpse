extends Creature
## Puffsac (week 45, the Lungs): a torn-off lobe of lung that still breathes
## and drifts on its own, full of spores. It floats toward whatever moves,
## swells red when it is close, and bursts: everything near it is hurt,
## other creatures too (friendly fire). One hit pops it, but popped close
## up it still bursts after a short fuse, so pop it from afar (spit, a
## thrown thing, another creature) or roll away. Made with
## tools/creature/new_creature.gd as a floater; its look is
## tools/pixel/recipes/creature_puffsac.gd.
##
##   DRIFT    bob around its home, look for movement
##   FOLLOW   saw the player: drift toward it
##   SWELL    close: stop and swell (the tell)
##   BURST    the spores go everywhere; it is gone

enum State { DRIFT, FOLLOW, SWELL, BURST }

@export var speed := 42.0
## Starts swelling this close to the player (px).
@export var trigger_range := 60.0
@export var swell_time := 0.8
## Popped by a hit, it still bursts after this long.
@export var fuse_time := 0.35

var _home := Vector2.ZERO
var _burst := false


func setup() -> void:
	_home = position


func think(delta: float) -> void:
	var want := Vector2.ZERO
	match state:
		State.DRIFT:
			want = (_home + Vector2(sin(state_time * 0.7) * 24.0, sin(state_time * 1.1) * 10.0) - position) * 1.2
			if sees_player():
				enter(State.FOLLOW)
		State.FOLLOW:
			if not player_alive() or to_player().length() > lose_range:
				_home = position  # Settles where it lost you.
				enter(State.DRIFT)
				return
			face(to_player().x)
			want = (to_player() + Vector2(0, -20)).limit_length(speed)  # Toward the chest, not the feet.
			if to_player().length() < trigger_range:
				Sfx.play(&"puffsac_swell", global_position)
				enter(State.SWELL)
		State.SWELL:
			visual.position = Vector2(sin(state_time * 50.0), 0) * minf(state_time * 3.0, 1.5)
			if state_time > swell_time:
				burst()
				return
	velocity = velocity.lerp(want, minf(1.0, delta * 3.0))


func animation() -> StringName:
	if _burst:
		return &"attack"
	if hurt_time > 0.0 and not is_dead():
		return &"hurt"
	if state == State.SWELL or is_dead():
		return &"windup"
	return &"idle"


## Pops: the Attack hitbox (a ring around it) hurts everything for a moment.
## Kills itself if it is not dead yet (the kill is not the player's).
func burst() -> void:
	if _burst:
		return
	_burst = true
	enter(State.BURST)
	visual.position = Vector2.ZERO
	velocity = Vector2.ZERO
	if not is_dead():
		# Dying switches the hitboxes off, so die first, then strike. No
		# damage number: nothing hit it.
		health.last_hit_source = &"puffsac"
		health.set_current(0)
		health.died.emit()
	strike(0.12)
	var cloud := SporeCloud.new()
	cloud.radius = ($Visual/Attack/CollisionShape2D.shape as CircleShape2D).radius
	cloud.position = position
	get_parent().add_child(cloud)
	Sfx.play(&"puffsac_burst", global_position)
	EventBus.shake_requested.emit(0.4)


func hurt(_amount: int, from: Vector2, knockback: float) -> void:
	velocity = (global_position - from).normalized() * knockback * 0.6


func died() -> void:
	if not _burst:
		get_tree().create_timer(fuse_time, false).timeout.connect(burst)
