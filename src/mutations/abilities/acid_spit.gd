extends MutationAbility
## Acid Gland (mouth): spit a glob of acid that drops slowly.

const PROJECTILE := preload("res://src/mutations/acid_projectile.tscn")
const COOLDOWN := 0.7
## Mostly flat and a little downward: the host's mouth is about 49 px above
## its feet (64 px hosts, D-023), and the glob should drop onto small crawlers
## like the Gut Leech (21 px tall) instead of flying over them.
const SPEED := Vector2(420, 30)

var _cooldown := 0.0


func physics_tick(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0 or not host.can_act() or not host.ability_pressed(def.slot):
		return
	_cooldown = COOLDOWN
	var glob := PROJECTILE.instantiate()
	glob.position = host.socket(def.slot).global_position
	# Creatures may aim (spit_velocity); the player spits straight ahead.
	if host.has_method("spit_velocity"):
		glob.velocity = host.spit_velocity(glob.position)
	else:
		glob.velocity = Vector2(SPEED.x * host.facing(), SPEED.y)
	var hitbox: Hitbox = glob.get_node("Hitbox")
	hitbox.collision_layer = host.attack_layer()
	hitbox.exclude = host.get_node_or_null("Hurtbox")  # Never hit the spitter.
	hitbox.source = CombatRules.kind_of(host)
	host.get_parent().add_child(glob)
	Sfx.play(&"spit", host.global_position)
