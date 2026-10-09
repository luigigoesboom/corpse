class_name Hitbox
extends Area2D
## The dangerous part of an attack or body. Hurtboxes that overlap it take damage.
##
## Which side it hurts is decided by physics layers: put player attacks on the
## "player_attacks" layer and enemy attacks on "enemy_attacks"; each Hurtbox
## only looks at the other side's layer.

## Emitted when this hits a Hurtbox (e.g. so a projectile can vanish).
signal landed(hurtbox: Node)

@export var damage := 1
@export var knockback := 250.0
## Attacks: hit each target once per activate(). Leave off for contact damage
## (always on, e.g. touching an enemy); the target's invulnerability time then
## spaces the hits out.
@export var once_per_activation := true
@export var active := true

## A Hurtbox this never hits (e.g. the one who fired the projectile).
var exclude: Node
## Who deals this damage, as a kind (&"player", &"gut_leech"...). Filled in
## from the scene this hitbox belongs to; projectiles get their shooter's kind.
var source: StringName
var _already_hit: Array[int] = []


func _ready() -> void:
	monitoring = false  # Hurtboxes do the looking.
	if source == &"" and owner:
		source = CombatRules.kind_of(owner)


func activate() -> void:
	active = true
	_already_hit.clear()


func deactivate() -> void:
	active = false


## Asked by a Hurtbox. Returns true (and remembers it) if this may hit it now.
func try_hit(hurtbox: Node) -> bool:
	if not active or hurtbox == exclude:
		return false
	if once_per_activation:
		var id := hurtbox.get_instance_id()
		if id in _already_hit:
			return false
		_already_hit.append(id)
	landed.emit(hurtbox)
	return true
