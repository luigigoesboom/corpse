extends RefCounted
## Strips and previews for the art program (D-028).

## Frames side by side, left to right, as one strip image.
static func strip(frames: Array) -> Image:
	var w: int = frames[0].get_width()
	var h: int = frames[0].get_height()
	var out := Image.create(w * frames.size(), h, false, Image.FORMAT_RGBA8)
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i(i * w, 0))
	return out


static func is_empty(img: Image) -> bool:
	return img.get_used_rect().size == Vector2i.ZERO


## Saves an image, making the folder. `path` is res:// or user://.
static func save(img: Image, path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	img.save_png(ProjectSettings.globalize_path(path))


## A contact sheet: every image scaled up, glows laid over their bodies, on
## the Gut's dark background, wrapped into rows. For looking, not for the game.
static func preview(items: Array, scale := 3, width := 1600) -> Image:
	var sheet := Image.create(width, 64, false, Image.FORMAT_RGBA8)
	var rows: Array = []
	var x := 8
	var y := 8
	var row_h := 0
	var placed: Array = []
	for item in items:
		var body: Image = item.body
		var w := body.get_width() * scale
		var h := body.get_height() * scale
		if x + w > width - 8:
			x = 8
			y += row_h + 8
			row_h = 0
		placed.append([item, Vector2i(x, y)])
		x += w + 8
		row_h = maxi(row_h, h)
	sheet = Image.create(width, y + row_h + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(42, 18, 22))
	for p in placed:
		var item: Dictionary = p[0]
		for key in ["body", "glow"]:
			if not item.has(key) or item[key] == null:
				continue
			var img: Image = item[key].duplicate()
			img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
			sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), p[1])
	return sheet
