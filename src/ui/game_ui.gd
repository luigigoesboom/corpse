extends CanvasLayer
## Decides which in-game screen is open (none, inventory, pause) and pauses
## the game while one is.
##
## get_tree().paused = true stops every node whose process_mode is "Inherit"
## or "Pausable". This node and the screens are "Always", so menus keep
## working while the world is frozen.

@onready var _inventory: Control = $InventoryScreen
@onready var _pause: Control = $PauseMenu
@onready var death_screen: Control = $DeathScreen


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	_inventory.visible = false
	_pause.visible = false
	death_screen.visible = false
	_pause.resume_pressed.connect(close_all)


func _unhandled_input(event: InputEvent) -> void:
	if death_screen.visible:
		return  # Only its own button moves on.
	if _pause.visible and _pause.is_busy():
		return  # The settings screen handles its own keys.
	if event.is_action_pressed("pause"):
		# Escape closes whatever is open first, and only pauses from gameplay.
		if _inventory.visible or _pause.visible:
			close_all()
		else:
			_open(_pause)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory"):
		if _inventory.visible:
			close_all()
		elif not _pause.visible:
			_open(_inventory)
		get_viewport().set_input_as_handled()


func close_all() -> void:
	Player.swallow_attack()  # A click that closed a menu is not a swing.
	if _inventory.visible or _pause.visible:
		Sfx.play(&"ui_close")
	_inventory.visible = false
	_pause.visible = false
	death_screen.visible = false
	get_tree().paused = false


func show_death(life: LifeRecord, life_number: int) -> void:
	close_all()
	death_screen.visible = true
	death_screen.show_life(life, life_number)
	get_tree().paused = true


func _open(screen: Control) -> void:
	Sfx.play(&"ui_open")
	screen.visible = true
	screen.open()
	get_tree().paused = true
