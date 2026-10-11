extends Creature
## Cilia Lasher (week 49, the Lungs): a mound of lung grown on the floor,
## combing the air with cilia; one thick cilium is a lash. Whatever comes
## within its reach gets whipped: it draws the lash back (the tell), then
## throws it out flat along the floor ahead. It cannot move. Jump over the
## lash or roll through it, then hit it while it draws back in; or take it
## from above or from afar. Made with tools/creature/new_creature.gd as a
## rooted thing; its look is tools/pixel/recipes/creature_cilia_lasher.gd.
##
##   IDLE     sway, wait for the player to come into reach
##   WINDUP   turn and draw the lash back (the tell)
##   ATTACK   the lash, the Attack hitbox on
##   REST     the lash coils back in: a moment to punish it

enum State { IDLE, WINDUP, ATTACK, REST }

@export var reach := 84.0
@export var windup_time := 0.5
@export var rest_time := 0.9


func think(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	match state:
		State.IDLE:
			if sees_player(reach, 70.0):
				face(to_player().x)
				Sfx.play(&"lasher_draw", global_position)
				enter(State.WINDUP)
		State.WINDUP:
			if state_time > windup_time:
				strike(0.18)
				Sfx.play(&"lasher_lash", global_position)
				enter(State.ATTACK)
		State.ATTACK:
			if state_time > 0.3:
				enter(State.REST)
		State.REST:
			if state_time > rest_time:
				enter(State.IDLE)


func animation() -> StringName:
	if is_dead():
		return &"die"
	if hurt_time > 0.0:
		return &"hurt"
	match state:
		State.WINDUP:
			return &"windup"
		State.ATTACK:
			return &"attack"
	return &"idle"
