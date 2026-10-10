extends RefCounted
## Menus (week 41, D-028): a panel, buttons, a slider and a check box in the
## Gut's bone-and-flesh look, the title logo, and the UI theme that uses
## them (assets/ui/theme.tres: the m5x7 font, these as nine-slice boxes).
## Writes assets/ui/*.png and rewrites the theme.

const Canvas := preload("res://tools/pixel/canvas.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")
const DIR := "res://assets/ui/"
const THEME := "res://assets/ui/theme.tres"
const FONT := "res://assets/fonts/m5x7.ttf"
## Strokes of the title's letters on a 4 x 6 grid (C O R P S E).
const LETTERS := {
	"C": [[Vector2(4, 1), Vector2(3, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, 5), Vector2(1, 6), Vector2(3, 6), Vector2(4, 5)]],
	"O": [[Vector2(1, 0), Vector2(3, 0), Vector2(4, 1), Vector2(4, 5), Vector2(3, 6), Vector2(1, 6), Vector2(0, 5), Vector2(0, 1), Vector2(1, 0)]],
	"R": [[Vector2(0, 6), Vector2(0, 0), Vector2(3, 0), Vector2(4, 1), Vector2(4, 2), Vector2(3, 3), Vector2(0, 3)], [Vector2(2, 3), Vector2(4, 6)]],
	"P": [[Vector2(0, 6), Vector2(0, 0), Vector2(3, 0), Vector2(4, 1), Vector2(4, 2), Vector2(3, 3), Vector2(0, 3)]],
	"S": [[Vector2(4, 1), Vector2(3, 0), Vector2(1, 0), Vector2(0, 1), Vector2(0, 2), Vector2(1, 3), Vector2(3, 3), Vector2(4, 4), Vector2(4, 5), Vector2(3, 6), Vector2(1, 6), Vector2(0, 5)]],
	"E": [[Vector2(4, 0), Vector2(0, 0), Vector2(0, 6), Vector2(4, 6)], [Vector2(0, 3), Vector2(3, 3)]],
}


static func make(pal, out: Array) -> void:
	var images = {
		"panel": _panel(pal),
		"button_normal": _button(pal, &"rag", 0.0, false),
		"button_hover": _button(pal, &"blood", -0.3, false),
		"button_pressed": _button(pal, &"blood", -0.5, true),
		"button_disabled": _button(pal, &"ash", -0.3, false),
		"slider_track": _track(pal),
		"slider_grabber": _grabber(pal, false),
		"slider_grabber_hover": _grabber(pal, true),
		"check_on": _check(pal, true),
		"check_off": _check(pal, false),
		"title": _title(pal),
	}
	for name in images:
		Sheet.save(images[name], DIR + name + ".png")
		out.append({"name": name, "body": images[name]})
	_write_theme()


static func _panel(pal) -> Image:
	var c = Canvas.new(32, 32, pal)
	c.rect(Rect2(2, 2, 28, 28), &"flesh", {"lo": 0, "hi": 1, "dither": true, "flat": true})
	c.rect(Rect2(1, 1, 30, 2), &"bone", {"lo": 1, "hi": 2, "flat": true, "z": 1})
	c.rect(Rect2(1, 29, 30, 2), &"bone", {"lo": 0, "hi": 1, "flat": true, "z": 1})
	c.rect(Rect2(1, 1, 2, 30), &"bone", {"lo": 1, "hi": 2, "flat": true, "z": 1})
	c.rect(Rect2(29, 1, 2, 30), &"bone", {"lo": 0, "hi": 1, "flat": true, "z": 1})
	for p in [Vector2(3, 3), Vector2(29, 3), Vector2(3, 29), Vector2(29, 29)]:
		c.circle(p, 2.5, &"bone", {"z": 2})  # Knuckles at the corners.
	return c.render().body


static func _button(pal, ramp: StringName, tone: float, pressed: bool) -> Image:
	var c = Canvas.new(24, 16, pal)
	var top = 2.0 if pressed else 1.0
	c.rect(Rect2(1, top, 22, 14 - top + 1), ramp, {"lo": 0, "hi": 2, "tone": tone, "dither": true, "flat": true})
	c.rect(Rect2(1, 14, 22, 1), ramp, {"lo": 0, "hi": 0, "flat": true, "z": 1})
	c.detail(Vector2i(2, int(top) + 1), pal.step(&"bone", 1))
	c.detail(Vector2i(21, int(top) + 1), pal.step(&"bone", 1))
	return c.render().body


static func _track(pal) -> Image:
	var c = Canvas.new(12, 6, pal)
	c.rect(Rect2(1, 1, 10, 4), &"flesh", {"lo": 2, "hi": 3, "flat": true})
	c.rect(Rect2(1, 2, 10, 2), &"flesh", {"lo": 0, "hi": 0, "flat": true, "z": 1})
	return c.render().body


static func _grabber(pal, hover: bool) -> Image:
	var c = Canvas.new(10, 14, pal)
	c.ellipse(Vector2(5, 7), 3.5, 5.5, &"blood" if hover else &"bone", {"lo": 1})
	return c.render().body


static func _check(pal, on: bool) -> Image:
	var c = Canvas.new(12, 12, pal)
	c.rect(Rect2(1, 1, 10, 10), &"flesh", {"lo": 0, "hi": 1, "flat": true})
	if on:
		c.circle(Vector2(6, 6), 3.0, &"blood", {"z": 1, "lo": 2})
	return c.render().body


## CORPSE in fleshy tubes, bone knuckles at the joints, a drip or two.
static func _title(pal) -> Image:
	var scale = 9.0
	var letter_w = 4.0 * scale
	var gap = 12.0
	var word = "CORPSE"
	var w = int(word.length() * (letter_w + gap) + 20)
	var h = int(6 * scale + 40)
	var c = Canvas.new(w, h, pal)
	var rng = RandomNumberGenerator.new()
	rng.seed = 66
	for i in word.length():
		var origin = Vector2(12 + i * (letter_w + gap), 10)
		for stroke in LETTERS[word[i]]:
			for k in range(1, stroke.size()):
				var a: Vector2 = origin + stroke[k - 1] * scale
				var b: Vector2 = origin + stroke[k] * scale
				c.capsule(a, b, 4.2, 4.2, &"flesh", {"lo": 2, "dither": true, "z": i + k * 0.01})
			for p in stroke:
				c.circle(origin + p * scale, 3.0, &"bone", {"lo": 1, "z": 10 + i})
		if rng.randf() < 0.6:  # A drip hanging off the bottom.
			var x = origin.x + rng.randf_range(0, letter_w)
			c.capsule(Vector2(x, 10 + 6 * scale + 3), Vector2(x, 10 + 6 * scale + rng.randf_range(10, 22)), 2.0, 1.2, &"blood", {"lo": 1, "z": 20})
	return c.render().body


## Needs the PNGs imported first: on a first run (new images) it says so;
## run the recipe again after Godot has imported them (or --import).
static func _write_theme() -> void:
	if not ResourceLoader.exists(DIR + "check_off.png"):
		print("  ui: images written; import them (open the editor or run --import), then run ui again for the theme")
		return
	var theme = Theme.new()
	theme.default_font = load(FONT)
	theme.default_font_size = 16
	var normal = _box("button_normal", 4)
	var hover = _box("button_hover", 4)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("pressed", "Button", _box("button_pressed", 4))
	theme.set_stylebox("disabled", "Button", _box("button_disabled", 4))
	theme.set_stylebox("focus", "Button", _focus())
	theme.set_stylebox("hover_pressed", "Button", hover)
	for type in ["Button", "CheckBox", "CheckButton"]:
		theme.set_color("font_color", type, Color8(238, 228, 200))
		theme.set_color("font_hover_color", type, Color8(255, 242, 192))
		theme.set_color("font_pressed_color", type, Color8(255, 224, 102))
		theme.set_color("font_focus_color", type, Color8(255, 242, 192))
		theme.set_color("font_disabled_color", type, Color8(122, 106, 96))
	var panel = _box("panel", 8)
	panel.content_margin_left = 12
	panel.content_margin_right = 12
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("slider", "HSlider", _box("slider_track", 2))
	theme.set_stylebox("grabber_area", "HSlider", _box("slider_track", 2))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _box("slider_track", 2))
	theme.set_icon("grabber", "HSlider", load(DIR + "slider_grabber.png"))
	theme.set_icon("grabber_highlight", "HSlider", load(DIR + "slider_grabber_hover.png"))
	theme.set_icon("checked", "CheckBox", load(DIR + "check_on.png"))
	theme.set_icon("unchecked", "CheckBox", load(DIR + "check_off.png"))
	theme.set_stylebox("normal", "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("hover", "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("pressed", "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("focus", "CheckBox", _focus())
	theme.set_color("font_color", "Label", Color8(238, 228, 200))
	ResourceSaver.save(theme, THEME)


static func _box(name: String, margin: int) -> StyleBoxTexture:
	var box = StyleBoxTexture.new()
	box.texture = load(DIR + name + ".png")
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		box.set_texture_margin(side, margin)
		box.set_content_margin(side, margin + 2 if margin > 4 else 3)
	box.set_content_margin(SIDE_TOP, 1 if margin <= 4 else margin)
	box.set_content_margin(SIDE_BOTTOM, 1 if margin <= 4 else margin)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box


## A thin blood-red frame drawn over the focused button (keyboard and pad).
static func _focus() -> StyleBoxFlat:
	var box = StyleBoxFlat.new()
	box.draw_center = false
	box.border_color = Color8(220, 52, 62)
	box.set_border_width_all(1)
	return box
