class_name UiSounds
extends RefCounted
## Menu sounds (week 40): every button under a node gets a hover sound
## (mouse over or keyboard focus) and a select sound (pressed). Buttons
## added later (dialogue responses, save slots) are wired as they appear.
##
##   UiSounds.wire(self)

const HOVER_GAP_MS := 60  # Sweeping the mouse over a list should not rattle.

static var _last_hover := 0


static func wire(root: Node) -> void:
	_wire_node(root)
	if not root.child_entered_tree.is_connected(_on_child_added):
		root.child_entered_tree.connect(_on_child_added)


static func _on_child_added(node: Node) -> void:
	_wire_node(node)
	if not node.child_entered_tree.is_connected(_on_child_added):
		node.child_entered_tree.connect(_on_child_added)


static func _wire_node(node: Node) -> void:
	if node is BaseButton and not node.has_meta(&"ui_sounds"):
		node.set_meta(&"ui_sounds", true)
		node.mouse_entered.connect(_hover)
		node.focus_entered.connect(_hover)
		node.pressed.connect(func(): Sfx.play(&"ui_select"))
	for child in node.get_children():
		_wire_node(child)


static func _hover() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_hover > HOVER_GAP_MS:
		_last_hover = now
		Sfx.play(&"ui_hover")
