extends Control
## Pause menu. The game scene connects save / load / leaving; GameUI
## connects resume. Settings and Controls open the settings screen (week 41).
## Leaving to the main menu or quitting saves first (`leaving`).

signal resume_pressed
signal save_pressed
signal load_pressed
## About to leave the game (main menu or quit): a last chance to save.
signal leaving

const MAIN_MENU := "res://scenes/main_menu.tscn"

var _settings: SettingsScreen


func _ready() -> void:
	UiSounds.wire(self)  # Hover and select sounds (week 40).
	process_mode = PROCESS_MODE_ALWAYS
	_settings = SettingsScreen.new()
	_settings.closed.connect(func(): %SettingsButton.grab_focus())
	add_child(_settings)
	%ResumeButton.pressed.connect(resume_pressed.emit)
	%SaveButton.pressed.connect(save_pressed.emit)
	%LoadButton.pressed.connect(load_pressed.emit)
	%SettingsButton.pressed.connect(_settings.open.bind(0))
	%ControlsButton.pressed.connect(_settings.open.bind(2))
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)


func open() -> void:
	%ResumeButton.grab_focus()


## True while the settings screen is up (Esc closes it, not the pause menu).
func is_busy() -> bool:
	return _settings.visible


func _on_main_menu_pressed() -> void:
	leaving.emit()
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)


func _on_quit_pressed() -> void:
	leaving.emit()
	get_tree().quit()
