extends Control
## Title screen: new game, continue from slot 0, the two combat test arenas, quit.

const GAME := "res://game.tscn"


func _ready() -> void:
	UiSounds.wire(self)  # Hover and select sounds (week 40).
	%NewButton.pressed.connect(_on_new_pressed)
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%QuitButton.pressed.connect(get_tree().quit)
	%ArenaTightButton.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/arenas/arena_tight.tscn"))
	%ArenaLooseButton.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/arenas/arena_loose.tscn"))
	%BossButton.pressed.connect(get_tree().change_scene_to_file.bind("res://scenes/arenas/boss_arena.tscn"))
	%ContinueButton.disabled = not SaveSystem.has_save(0)
	if %ContinueButton.disabled:
		%NewButton.grab_focus()
	else:
		%ContinueButton.grab_focus()


func _on_new_pressed() -> void:
	# Game starts a fresh world when there is none.
	WorldState.clear()
	get_tree().change_scene_to_file(GAME)


func _on_continue_pressed() -> void:
	var err := SaveSystem.load_game(0)
	if err != OK:
		%Status.text = "Could not load the save: %s" % error_string(err)
		return
	get_tree().change_scene_to_file(GAME)
