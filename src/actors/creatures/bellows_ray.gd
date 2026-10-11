extends Creature
## Bellows Ray (week 49, the Lungs): a flat glider of lung tissue that
## rides the air of the Bellows. It circles above whatever moves, then
## swoops: down at you in a curve and up again, the way a hawk takes a
## mouse. Between swoops it is slow and open. Its breath sac (drop_item)
## can be eaten: the Lung Sac, a glide. Made with tools/creature/
## new_creature.gd as a flyer; its look is tools/pixel/recipes/
## creature_bellows_ray.gd.
##
##   HOVER    drift around its home, look for the player
##   STALK    glide to a point high above and to one side of the player
##   WINDUP   wings up, it tips over (the tell)
##   SWOOP    down at where the player was, then curving up and away
##   RECOVER  climb back up

enum State { HOVER, STALK, WINDUP, SWOOP, RECOVER }

@export var speed := 110.0
@export var swoop_speed := 380.0
@export var windup_time := 0.55
## How quickly the swoop bends back up (a blend rate, per second).
@export var pull_up := 3.2

var _home := Vector2.ZERO
## The height it dives to: where the player was when it swooped.
var _floor_y := 0.0


func setup() -> void:
	_home = position


func think(delta: float) -> void:
	var want := Vector2.ZERO
	match state:
		State.HOVER:
			want = (_home + Vector2(sin(state_time * 0.6) * 70.0, sin(state_time * 1.2) * 20.0) - position) * 1.5
			face(want.x)
			if sees_player():
				enter(State.STALK)
		State.STALK:
			if not player_alive() or to_player().length() > lose_range:
				enter(State.HOVER)
				return
			var side := -signf(to_player().x) if to_player().x != 0.0 else 1.0
			var perch := player.global_position + Vector2(side * 150.0, -140.0)
			want = (perch - global_position).limit_length(speed)
			face(to_player().x)
			if global_position.distance_to(perch) < 40.0 or state_time > 3.5:
				Sfx.play(&"ray_cry", global_position)
				enter(State.WINDUP)
		State.WINDUP:
			want = Vector2(0, -30)  # A little rise before the drop.
			if state_time > windup_time:
				velocity = (to_player() if player_alive() else Vector2(dir, 1)).normalized() * swoop_speed
				_floor_y = player.global_position.y if player_alive() else global_position.y + 150.0
				strike(0.9)
				enter(State.SWOOP)
		State.SWOOP:
			# Down at the player's height (or after a while) it bends back
			# up, toward where it faces.
			if global_position.y >= _floor_y - 8.0 or state_time > 0.7:
				var up := Vector2(dir, -1.0).normalized() * swoop_speed
				velocity = velocity.lerp(up, minf(1.0, delta * pull_up))
			if state_time > 1.0 or (get_slide_collision_count() > 0 and state_time > 0.1):
				attack_box.deactivate()
				enter(State.RECOVER)
			return
		State.RECOVER:
			want = Vector2(-dir * 40.0, -speed)
			if state_time > 0.8:
				enter(State.STALK)
	velocity = velocity.lerp(want, minf(1.0, delta * 4.0))


func animation() -> StringName:
	if is_dead():
		return &"die"
	if hurt_time > 0.0:
		return &"hurt"
	match state:
		State.WINDUP:
			return &"windup"
		State.SWOOP:
			return &"attack"
	return &"move"


func hurt(_amount: int, from: Vector2, knockback: float) -> void:
	velocity = (global_position - from).normalized() * knockback
	if state in [State.HOVER, State.WINDUP]:
		enter(State.RECOVER)
