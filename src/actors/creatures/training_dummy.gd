extends Node2D
## Training dummy: takes hits, shows numbers, never dies. For testing attacks.

@onready var _health: Health = $Health
@onready var _visual: Node2D = $Visual


func _ready() -> void:
	_health.hurt.connect(_on_hurt)
	_health.died.connect(_health.heal_full)


func _on_hurt(amount: int, from: Vector2, _knockback: float) -> void:
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -24), amount)
	var lean := 0.25 * signf(global_position.x - from.x)
	var tween := create_tween()
	tween.tween_property(_visual, "rotation", lean, 0.05)
	tween.tween_property(_visual, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC)
