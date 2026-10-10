extends RefCounted
## Not game art: a test card for the renderer. Spheres, tubes and slabs in
## several ramps, plain and dithered, to judge the shading at a glance.

const Canvas := preload("res://tools/pixel/canvas.gd")


static func make(pal, out: Array) -> void:
	for ramp in [&"skin", &"bone", &"flesh", &"leech", &"gold", &"rag", &"hide", &"lung"]:
		for dither in [false, true]:
			var c := Canvas.new(48, 48, pal)
			c.circle(Vector2(16, 16), 11, ramp, {"dither": dither})
			c.capsule(Vector2(30, 8), Vector2(40, 38), 5, 3, ramp, {"dither": dither})
			c.rect(Rect2(4, 32, 18, 12), ramp, {"dither": dither})
			c.capsule(Vector2(10, 24), Vector2(24, 30), 3, 3, ramp, {"z": 1, "tone": -0.15})
			var img: Dictionary = c.render()
			out.append({"name": "%s%s" % [ramp, "_d" if dither else ""], "body": img.body, "glow": img.glow})
