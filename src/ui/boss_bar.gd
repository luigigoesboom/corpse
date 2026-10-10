class_name BossBar
extends Control
## A boss's name and health at the top of the screen. Shows when a boss
## engages (EventBus.boss_engaged), fades when it dies. A notch marks half
## health, where bosses change phase.

const WIDTH := 300.0
const HEIGHT := 6.0

var _boss: Node
var _health: Health
var _shown := 0.0
var _name: Label
var _lag := 1.0  # The pale bar that trails the real one, so a big hit reads as big.


func _ready() -> void:
	# Centred at the top: anchors in the middle, offsets half the width out.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = 24.0
	offset_bottom = 54.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name = Label.new()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.size = Vector2(WIDTH, 16)
	_name.add_theme_color_override("font_color", Color(0.95, 0.85, 0.7))
	_name.add_theme_color_override("font_outline_color", Color.BLACK)
	_name.add_theme_constant_override("outline_size", 4)
	add_child(_name)
	modulate.a = 0.0
	EventBus.boss_engaged.connect(_on_engaged)
	EventBus.boss_defeated.connect(func(_boss): _boss = null)


func _on_engaged(boss: Node) -> void:
	_boss = boss
	_health = boss.get_node("Health")
	_name.text = boss.display_name
	_lag = 1.0


func _process(delta: float) -> void:
	_shown = move_toward(_shown, 1.0 if is_instance_valid(_boss) else 0.0, delta * 2.0)
	modulate.a = _shown
	if _health:
		var ratio := clampf(float(_health.current) / _health.max_health, 0.0, 1.0)
		_lag = move_toward(_lag, ratio, delta * 0.4) if _lag > ratio else ratio
	queue_redraw()


func shown_ratio() -> float:
	return float(_health.current) / _health.max_health if _health else 0.0


func _draw() -> void:
	if _health == null:
		return
	var top := 18.0
	var ratio := clampf(float(_health.current) / _health.max_health, 0.0, 1.0)
	draw_rect(Rect2(-1, top - 1, WIDTH + 2, HEIGHT + 2), Color(0.05, 0.02, 0.03))
	draw_rect(Rect2(0, top, WIDTH * _lag, HEIGHT), Color(0.9, 0.75, 0.6))
	draw_rect(Rect2(0, top, WIDTH * ratio, HEIGHT), Color(0.7, 0.12, 0.15))
	draw_rect(Rect2(WIDTH / 2.0 - 1, top - 2, 2, HEIGHT + 4), Color(0.95, 0.85, 0.7))
