extends "res://tests/test_case.gd"
## tools/pixel/generate.gd (D-032): a picture becomes a sprite in the Gut
## palette. No image model needed: the test draws its own picture, a shaded
## ball on a plain grey background, the way the tool asks models to draw.


func run() -> void:
	var tool = load("res://tools/pixel/generate.gd").new()
	tool.pal = load("res://tools/pixel/palette.gd").load_default()
	var picture := Image.create(600, 400, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0.8, 0.8, 0.78))
	for y in 400:
		for x in 600:
			var p := Vector2(x - 300, y - 200)
			if p.length() < 150:
				picture.set_pixel(x, y, Color(0.7, 0.3, 0.3).darkened(clampf(p.x / 300.0 + 0.3, 0.0, 0.8)))
	var sprite: Image = tool.pixelate(picture, {"size": 32, "ramps": ["flesh"], "outline": true})
	check(maxi(sprite.get_width(), sprite.get_height()) == 32, "the longest side is the size asked for (%s)" % sprite.get_size())
	check(sprite.get_pixel(0, 0).a == 0.0, "the background is cut away")
	var allowed: Array = tool.pal.ramp(&"flesh") + [tool.pal.outline()]
	var stray := 0
	var opaque := 0
	for y in sprite.get_height():
		for x in sprite.get_width():
			var c := sprite.get_pixel(x, y)
			if c.a > 0.0:
				opaque += 1
				if not allowed.any(func(a): return a.is_equal_approx(Color(c, 1.0))):
					stray += 1
	check(opaque > 500 and stray == 0, "every pixel is from the flesh ramp or the outline (%d pixels, %d off)" % [opaque, stray])
	var middle_row := sprite.get_height() / 2
	var first := 0
	while sprite.get_pixel(first, middle_row).a == 0.0:
		first += 1
	check(sprite.get_pixel(first, middle_row).is_equal_approx(tool.pal.outline()), "the shape is outlined")
	tool.free()
