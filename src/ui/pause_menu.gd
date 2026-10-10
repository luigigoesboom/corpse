extends Control
## Pause menu. The game scene connects save/load; GameUI connects resume.

signal resume_pressed
signal save_pressed
signal load_pressed

const MAIN_MENU := "res://scenes/main_menu.tscn"


func _ready() -> void:
	UiSounds.wire(self)  # Hover and select sounds (week 40).
	process_mode = PROCESS_MODE_ALWAYS
	%ResumeButton.pressed.connect(resume_pressed.emit)
	%SaveButton.pressed.connect(save_pressed.emit)
	%LoadButton.pressed.connect(load_pressed.emit)
	%MainMenuButton.pressed.connect(_on_main_menu_pressed)
	%QuitButton.pressed.connect(get_tree().quit)


func open() -> void:
	%ResumeButton.grab_focus()


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
