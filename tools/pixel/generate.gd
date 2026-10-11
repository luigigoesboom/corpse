extends SceneTree
## Generated pictures turned into the game's pixel art (D-032). An image
## model draws a picture from a description; this tool cuts it out of its
## background, shrinks it to sprite size, snaps every pixel to the Gut
## palette (assets/art/_source/gut.gpl), cleans stray pixels and outlines it.
##
## What to make is listed in tools/pixel/generated.json:
##   "fungus_tree": {"prompt": "a tall pale fungus shaped like a tree",
##                   "size": 96, "ramps": ["rot", "bone"], "outline": true}
## (size = the longest side in px; ramps = which palette ramps it may use, all
## when left out; dither = true for ordered dither between steps.)
##
##   Godot --headless --path . --script res://tools/pixel/generate.gd -- <name> [<name>...]
##   Godot --headless --path . --script res://tools/pixel/generate.gd -- --all
##   Godot --headless --path . --script res://tools/pixel/generate.gd -- <name> --again   (ask for a new picture)
##
## A picture already asked for is kept in assets/art/_generated_raw/<name>.png
## (not in git, not imported by Godot) and only pixelated again; --again asks
## for a new one. Any picture can be dropped there by hand too (from any
## generator, a photo, a scan): name it after the entry and run the tool.
## Output: assets/art/generated/<name>.png, and a 4x preview next to the raw.
##
## Which image model: set CORPSE_IMAGE_BACKEND (environment variable):
##   "local"  (default) a Stable Diffusion WebUI (AUTOMATIC1111 or Forge)
##            running on this PC with --api: http://127.0.0.1:7860
##            (CORPSE_SD_URL to change it). Free, runs offline.
##   "openai" OpenAI's image API; needs OPENAI_API_KEY. Costs money per
##            picture, and the description is sent to OpenAI.

const LIST := "res://tools/pixel/generated.json"
const RAW := "res://assets/art/_generated_raw/"
const OUT := "res://assets/art/generated/"
const Palette := preload("res://tools/pixel/palette.gd")
## Added to every description: one thing, side view, on a plain background
## that is easy to cut away.
const STYLE := "single object, centered, side view, full body visible, flat plain light grey background, no text, no frame, grotesque organic dark fantasy, clear silhouette, game sprite concept art"
const NEGATIVE := "text, watermark, frame, border, multiple objects, cropped, scenery, landscape, shadow on ground"

var pal


func _initialize() -> void:
	_main.call_deferred()


func _main() -> void:
	pal = Palette.load_default()
	var args := OS.get_cmdline_user_args()
	var list: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIST)) if FileAccess.file_exists(LIST) else {}
	var names := Array(args).filter(func(a): return not a.begins_with("--"))
	if "--all" in args:
		names = list.keys()
	if names.is_empty():
		print("usage: generate.gd -- <name> [...] | --all [--again]; names in ", LIST, ": ", list.keys())
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(RAW))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var failed := 0
	for name in names:
		if not list.has(name):
			print("%s: not in %s" % [name, LIST])
			failed += 1
			continue
		var entry: Dictionary = list[name]
		var raw_path := ProjectSettings.globalize_path(RAW + name + ".png")
		if "--again" in args or not FileAccess.file_exists(raw_path):
			var picture: Image = await _ask(entry.prompt)
			if picture == null:
				failed += 1
				continue
			picture.save_png(raw_path)
		var raw := Image.load_from_file(raw_path)
		var sprite := pixelate(raw, entry)
		sprite.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
		var big: Image = sprite.duplicate()
		big.resize(sprite.get_width() * 4, sprite.get_height() * 4, Image.INTERPOLATE_NEAREST)
		big.save_png(raw_path.get_basename() + "_preview.png")
		print("%s: %d x %d -> %s" % [name, sprite.get_width(), sprite.get_height(), OUT + name + ".png"])
	quit(1 if failed else 0)


# --- Asking an image model --------------------------------------------------------

func _ask(prompt: String) -> Image:
	var backend := OS.get_environment("CORPSE_IMAGE_BACKEND")
	var full := "%s, %s" % [prompt, STYLE]
	if backend == "openai":
		return await _ask_openai(full)
	return await _ask_local(full)


## Stable Diffusion WebUI's API (start it with --api).
func _ask_local(prompt: String) -> Image:
	var url := OS.get_environment("CORPSE_SD_URL")
	if url == "":
		url = "http://127.0.0.1:7860"
	var body := JSON.stringify({"prompt": prompt, "negative_prompt": NEGATIVE, "width": 768, "height": 768, "steps": 28, "cfg_scale": 6.5})
	var reply: Dictionary = await _post(url + "/sdapi/v1/txt2img", ["Content-Type: application/json"], body)
	if reply.is_empty() or not reply.has("images"):
		print("no picture from %s (is the WebUI running with --api?)" % url)
		return null
	return _decode(reply.images[0])


func _ask_openai(prompt: String) -> Image:
	var key := OS.get_environment("OPENAI_API_KEY")
	if key == "":
		print("OPENAI_API_KEY is not set")
		return null
	var body := JSON.stringify({"model": "gpt-image-1", "prompt": prompt, "size": "1024x1024", "background": "opaque", "n": 1})
	var reply: Dictionary = await _post("https://api.openai.com/v1/images/generations", ["Content-Type: application/json", "Authorization: Bearer " + key], body)
	if reply.is_empty() or not reply.has("data"):
		print("no picture from OpenAI: ", reply.get("error", reply))
		return null
	return _decode(reply.data[0].b64_json)


func _post(url: String, headers: Array, body: String) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 300.0
	root.add_child(http)
	var err := http.request(url, PackedStringArray(headers), HTTPClient.METHOD_POST, body)
	if err != OK:
		print("could not reach %s (%s)" % [url, error_string(err)])
		http.queue_free()
		return {}
	var result: Array = await http.request_completed
	http.queue_free()
	if result[0] != HTTPRequest.RESULT_SUCCESS:
		print("could not reach %s (result %d)" % [url, result[0]])
		return {}
	var parsed = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	if result[1] != 200:
		print("%s answered %d" % [url, result[1]])
	return parsed if parsed is Dictionary else {}


func _decode(b64: String) -> Image:
	var img := Image.new()
	if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) != OK:
		return null
	return img


# --- Pixelating -------------------------------------------------------------------

## The whole pass: cut out, crop, shrink, snap to the palette, clean, outline.
func pixelate(src: Image, entry: Dictionary) -> Image:
	var img: Image = src.duplicate()
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() > 512:  # Work at a sane size: the result is tiny anyway.
		img.resize(512, int(512.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
	_cut_background(img)
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0:
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img = img.get_region(used)
	var size: int = int(entry.get("size", 64))
	var outline: bool = entry.get("outline", true)
	var inner := size - (2 if outline else 0)
	var scale := float(inner) / maxf(img.get_width(), img.get_height())
	var w := maxi(1, roundi(img.get_width() * scale))
	var h := maxi(1, roundi(img.get_height() * scale))
	var small := _shrink(img, w, h)
	var colors := _allowed(entry.get("ramps", []))
	var dither: bool = entry.get("dither", false)
	var pad := 1 if outline else 0
	var out := Image.create(w + pad * 2, h + pad * 2, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var c := small.get_pixel(x, y)
			if c.a < 0.5:
				continue
			out.set_pixel(x + pad, y + pad, Color(_nearest(c, colors, x, y, dither), 1.0))
	_clean(out)
	if outline:
		_outline(out)
	return out


## Makes the background clear: flood from the border through every pixel
## close to the border's typical colour (the plain background asked for).
func _cut_background(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var border: Array[Color] = []
	for x in range(0, w, 4):
		border.append(img.get_pixel(x, 0))
		border.append(img.get_pixel(x, h - 1))
	for y in range(0, h, 4):
		border.append(img.get_pixel(0, y))
		border.append(img.get_pixel(w - 1, y))
	var bg := _median(border)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[Vector2i] = []
	for x in w:
		stack.append(Vector2i(x, 0))
		stack.append(Vector2i(x, h - 1))
	for y in h:
		stack.append(Vector2i(0, y))
		stack.append(Vector2i(w - 1, y))
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or seen[p.y * w + p.x]:
			continue
		seen[p.y * w + p.x] = 1
		var c := img.get_pixelv(p)
		if c.a > 0.1 and _dist(c, bg) > 0.12:
			continue
		img.set_pixelv(p, Color(0, 0, 0, 0))
		stack.append_array([p + Vector2i.RIGHT, p + Vector2i.LEFT, p + Vector2i.DOWN, p + Vector2i.UP])


## Box-averaged shrink (alpha-weighted), sharper than filtering for big steps.
func _shrink(img: Image, w: int, h: int) -> Image:
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var sx := float(img.get_width()) / w
	var sy := float(img.get_height()) / h
	for y in h:
		for x in w:
			var acc := Vector4.ZERO
			var n := 0
			for yy in range(int(y * sy), maxi(int(y * sy) + 1, int((y + 1) * sy))):
				for xx in range(int(x * sx), maxi(int(x * sx) + 1, int((x + 1) * sx))):
					var c := img.get_pixel(mini(xx, img.get_width() - 1), mini(yy, img.get_height() - 1))
					acc += Vector4(c.r * c.a, c.g * c.a, c.b * c.a, c.a)
					n += 1
			var a := acc.w / n
			out.set_pixel(x, y, Color(acc.x / maxf(acc.w, 0.0001), acc.y / maxf(acc.w, 0.0001), acc.z / maxf(acc.w, 0.0001), a))
	return out


## The palette colours an entry may use: its ramps, or all of them.
func _allowed(ramps: Array) -> Array[Color]:
	var out: Array[Color] = []
	if ramps.is_empty():
		out.assign(pal.colors)
		return out
	for r in ramps:
		for c in pal.ramp(StringName(r)):
			out.append(c)
	out.append(pal.outline())
	return out


const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]


## Nearest colour by perceived difference (OKLab); with dither, picks the
## second nearest where a 4x4 Bayer pattern says so, by how close it is.
func _nearest(c: Color, colors: Array[Color], x: int, y: int, dither: bool) -> Color:
	var lab := _oklab(c)
	var best := colors[0]
	var second := colors[0]
	var d1 := INF
	var d2 := INF
	for p in colors:
		var d := lab.distance_squared_to(_oklab(p))
		if d < d1:
			d2 = d1
			second = best
			d1 = d
			best = p
		elif d < d2:
			d2 = d
			second = p
	if dither and d2 < INF:
		var t := sqrt(d1) / maxf(sqrt(d1) + sqrt(d2), 0.0001)  # 0 = right on best, 0.5 = halfway
		if t > 0.25 and t * 2.0 > (BAYER[(y % 4) * 4 + (x % 4)] + 0.5) / 16.0 + 0.5:
			return second
	return best


func _oklab(c: Color) -> Vector3:
	var r := c.srgb_to_linear()
	var l := 0.4122214708 * r.r + 0.5363325363 * r.g + 0.0514459929 * r.b
	var m := 0.2119034982 * r.r + 0.6806995451 * r.g + 0.1073969566 * r.b
	var s := 0.0883024619 * r.r + 0.2817188376 * r.g + 0.6299787005 * r.b
	l = pow(l, 1.0 / 3.0)
	m = pow(m, 1.0 / 3.0)
	s = pow(s, 1.0 / 3.0)
	return Vector3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)


## Stray pixels: an opaque pixel with at most one opaque neighbour goes; a
## clear pixel boxed in by opaque ones takes their most common colour.
func _clean(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			var around: Array[Color] = []
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixelv(q).a > 0.5:
					around.append(src.get_pixelv(q))
			var here: Color = src.get_pixel(x, y)
			if here.a > 0.5 and around.size() <= 1:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif here.a <= 0.5 and around.size() == 4:
				img.set_pixel(x, y, _mode(around))


## A one-pixel outline in the palette's outline colour around the shape.
func _outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + d
				if q.x >= 0 and q.y >= 0 and q.x < w and q.y < h and src.get_pixelv(q).a > 0.5:
					img.set_pixel(x, y, pal.outline())
					break


func _dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _median(colors: Array[Color]) -> Color:
	var r := colors.map(func(c): return c.r)
	var g := colors.map(func(c): return c.g)
	var b := colors.map(func(c): return c.b)
	r.sort()
	g.sort()
	b.sort()
	var i := colors.size() / 2
	return Color(r[i], g[i], b[i])


func _mode(colors: Array[Color]) -> Color:
	var counts := {}
	for c in colors:
		counts[c.to_html()] = counts.get(c.to_html(), 0) + 1
	var best := colors[0]
	var most := 0
	for c in colors:
		if counts[c.to_html()] > most:
			most = counts[c.to_html()]
			best = c
	return best
