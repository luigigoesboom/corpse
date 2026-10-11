extends MutationAbility
## Gust Bladder (head, week 51): a bladder of old breath in the throat.
## Press it and it all comes out at once: a gust in front of the host that
## throws creatures back (a light hit, so a Puffsac pops where it floats,
## far from you), and pushes the host the other way: in the air, a hop
## backward. A creature with one could blow you off a ledge.

const COOLDOWN := 0.8
const ACTIVE := 0.12
## How hard the gust throws what it hits, and pushes the host back.
const KNOCKBACK := 560.0
const RECOIL := 260.0

var _cooldown := 0.0
var _active := 0.0
var _hitbox: Hitbox


func _ready() -> void:
	_hitbox = Hitbox.new()
	_hitbox.collision_layer = host.attack_layer()
	_hitbox.source = CombatRules.kind_of(host)
	_hitbox.collision_mask = 0
	_hitbox.damage = 1
	_hitbox.knockback = KNOCKBACK
	_hitbox.position = Vector2(56, -8)
	if host.has_node("Hurtbox"):
		_hitbox.exclude = host.get_node("Hurtbox")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(96, 56)
	shape.shape = rect
	_hitbox.add_child(shape)
	host.get_node("Visual").add_child(_hitbox)
	_hitbox.deactivate()


func _exit_tree() -> void:
	if is_instance_valid(_hitbox):
		_hitbox.queue_free()


func physics_tick(delta: float) -> void:
	_cooldown -= delta
	if _active > 0.0:
		_active -= delta
		if _active <= 0.0:
			_hitbox.deactivate()
	if _cooldown > 0.0 or not host.can_act() or not host.ability_pressed(def.slot):
		return
	_cooldown = COOLDOWN
	_active = ACTIVE
	_hitbox.activate()
	var facing: float = host.facing()
	host.velocity.x -= facing * RECOIL
	if not host.is_on_floor():
		host.velocity.y = minf(host.velocity.y, -140.0)  # A hop back, in the air.
	Sfx.play(&"gust", host.global_position)
	var puff := GustPuff.new()
	puff.direction = Vector2(facing, 0)
	puff.position = host.global_position + Vector2(facing * 18, -10)
	host.get_parent().add_child(puff)
