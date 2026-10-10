extends "res://tests/test_case.gd"
## GIF capture (week 45): GifWriter's files decode back to the frames that
## went in (a small decoder below reads them the way any GIF viewer would).


func run() -> void:
	var writer: GDScript = load("res://src/debug/gif_writer.gd")

	# Few colors and transparency (art program previews): exact.
	var frames := []
	for f in 3:
		var img := Image.create(20, 12, false, Image.FORMAT_RGBA8)
		for y in 12:
			for x in 20:
				if (x + y + f) % 5 == 0:
					continue  # Transparent.
				img.set_pixel(x, y, [Color8(200, 40, 50), Color8(30, 160, 90), Color8(240, 230, 210)][(x * 3 + y + f) % 3])
		frames.append(img)
	var gif: Dictionary = _decode(writer.encode(frames, 0.1))
	check(gif.get("ok", false), "an art preview GIF decodes (%s)" % gif.get("error", "ok"))
	check(gif.get("frames", []).size() == 3 and gif.get("width") == 20 and gif.get("height") == 12, "three 20 x 12 frames")
	check(gif.get("delay") == 10 and gif.get("loops", false), "a tenth of a second each, looping")
	var exact := true
	for f in 3:
		for y in 12:
			for x in 20:
				var want: Color = frames[f].get_pixel(x, y)
				var got: Color = gif.frames[f][y * 20 + x]
				if (want.a < 0.5) != (got.a < 0.5) or (want.a >= 0.5 and not want.is_equal_approx(got)):
					exact = false
	check(exact, "every pixel comes back exactly, transparent ones too")

	# Many colors (a lit game frame: a dozen palette colors under light that
	# fades smoothly): median cut keeps them close.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var base := []
	for i in 12:
		base.append(Color(rng.randf(), rng.randf(), rng.randf()))
	var shot := Image.create(96, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 96:
			var light := clampf(1.0 - Vector2(x - 40, y - 30).length() / 70.0, 0.05, 1.0)
			var c: Color = base[(x / 8 + y / 8 * 3) % 12]
			shot.set_pixel(x, y, Color(c.r * light, c.g * light, c.b * light))
	gif = _decode(writer.encode([shot], 0.05))
	var worst := 0.0
	var total := 0.0
	for y in 64:
		for x in 96:
			var a := shot.get_pixel(x, y)
			var b: Color = gif.frames[0][y * 96 + x]
			var d := Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()
			worst = maxf(worst, d)
			total += d
	check(gif.get("ok", false) and gif.palette_size <= 256, "hundreds of lit colors squeeze into one 256-color palette")
	check(total / (96 * 64) < 0.015 and worst < 0.08, "and stay close (mean %.3f, worst %.3f)" % [total / (96 * 64), worst])

	# Long runs fill the LZW table: the encoder must clear and start over.
	var flat := Image.create(300, 300, false, Image.FORMAT_RGBA8)
	for y in 300:
		for x in 300:
			flat.set_pixel(x, y, Color8((x * 7 + y * 13) % 256, (x * 3) % 256, (y * 5) % 256))
	gif = _decode(writer.encode([flat], 0.05))
	check(gif.get("ok", false) and gif.frames[0].size() == 90000, "a 90000-pixel frame with a full code table decodes (%s)" % gif.get("error", "ok"))

	var path := "user://test_capture.gif"
	check(writer.save(frames, path, 0.1, 3) == OK and FileAccess.file_exists(path), "save() writes a file")
	check(_decode(FileAccess.get_file_as_bytes(path)).get("width") == 60, "scaled up three times")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## A plain GIF reader: global palette, frames as arrays of Colors.
func _decode(bytes: PackedByteArray) -> Dictionary:
	if bytes.slice(0, 6).get_string_from_ascii() != "GIF89a":
		return {"error": "no header"}
	var width := bytes[6] | (bytes[7] << 8)
	var height := bytes[8] | (bytes[9] << 8)
	var flags := bytes[10]
	var table_size := 2 << (flags & 7)
	var palette := []
	var at := 13
	for i in table_size:
		palette.append(Color8(bytes[at], bytes[at + 1], bytes[at + 2]))
		at += 3
	var out := {"width": width, "height": height, "frames": [], "palette_size": table_size, "loops": false}
	var transparent := -1
	while at < bytes.size():
		var block := bytes[at]
		if block == 0x3B:
			out.ok = true
			return out
		if block == 0x21:
			var label := bytes[at + 1]
			at += 2
			if label == 0xF9:
				out.delay = bytes[at + 2] | (bytes[at + 3] << 8)
				transparent = bytes[at + 4] if bytes[at + 1] & 1 else -1
			if label == 0xFF and bytes.slice(at + 1, at + 12).get_string_from_ascii() == "NETSCAPE2.0":
				out.loops = true
			while bytes[at] != 0:
				at += bytes[at] + 1
			at += 1
		elif block == 0x2C:
			at += 10
			var min_code := bytes[at]
			at += 1
			var data := PackedByteArray()
			while bytes[at] != 0:
				data.append_array(bytes.slice(at + 1, at + 1 + bytes[at]))
				at += bytes[at] + 1
			at += 1
			var indices := _unlzw(data, min_code)
			if indices.size() != width * height:
				return {"error": "frame has %d pixels" % indices.size()}
			var colors := []
			for i in indices:
				colors.append(Color(0, 0, 0, 0) if i == transparent else palette[i])
			out.frames.append(colors)
		else:
			return {"error": "unknown block %d" % block}
	return {"error": "no trailer"}


func _unlzw(data: PackedByteArray, min_code: int) -> Array:
	var clear := 1 << min_code
	var eoi := clear + 1
	var size := min_code + 1
	var table := []
	var out := []
	var prev := -1
	var bit := 0
	var total := data.size() * 8
	while bit + size <= total:
		var code := 0
		for i in size:
			if data[(bit + i) >> 3] & (1 << ((bit + i) & 7)):
				code |= 1 << i
		bit += size
		if code == clear:
			table.clear()
			for i in clear + 2:
				table.append([i])
			size = min_code + 1
			prev = -1
			continue
		if code == eoi:
			break
		var entry: Array
		if prev == -1:
			entry = table[code]
		elif code < table.size():
			entry = table[code]
			table.append(table[prev] + [entry[0]])
		else:
			entry = table[prev] + [table[prev][0]]
			table.append(entry)
		out.append_array(entry)
		if table.size() >= (1 << size) and size < 12:
			size += 1
		prev = code
	return out
