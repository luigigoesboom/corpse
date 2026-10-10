class_name GifWriter
extends RefCounted
## Writes animated GIFs (week 45): devlog clips from the game (GifRecorder,
## F12) and animation previews from the art program (run.gd --gif).
##
##   GifWriter.save(frames, "user://captures/clip.gif", 1.0 / 15.0)
##
## GIFs hold at most 256 colors. If the frames use fewer (pixel art straight
## from the art program), the palette is exact; otherwise it is chosen by
## median cut over a sample of the frames' pixels (lit game frames). Pixels
## with alpha below 0.5 become transparent. Plain GIF89a: one global color
## table, LZW-packed frames, looping forever.

const MAX_COLORS := 256
## Pixels sampled per frame to choose a palette (median cut).
const SAMPLES_PER_FRAME := 6000


## Encodes `frames` (Images of one size) with `delay` seconds per frame and
## writes them to `path` (res://, user:// or absolute). `scale` > 1 enlarges
## each frame (nearest neighbour), for small sprites.
static func save(frames: Array, path: String, delay := 0.05, scale := 1) -> Error:
	if frames.is_empty():
		return ERR_INVALID_PARAMETER
	var shown := frames
	if scale > 1:
		shown = []
		for frame: Image in frames:
			var big := frame.duplicate() as Image
			big.resize(frame.get_width() * scale, frame.get_height() * scale, Image.INTERPOLATE_NEAREST)
			shown.append(big)
	var bytes := encode(shown, delay)
	var full := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(full.get_base_dir())
	var file := FileAccess.open(full, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.close()
	return OK


## The whole GIF file as bytes.
static func encode(frames: Array, delay := 0.05) -> PackedByteArray:
	var width: int = frames[0].get_width()
	var height: int = frames[0].get_height()
	var data := []  # RGBA8 bytes per frame
	var transparent := false
	for frame: Image in frames:
		var img := frame
		if img.get_format() != Image.FORMAT_RGBA8:
			img = frame.duplicate() as Image
			img.convert(Image.FORMAT_RGBA8)
		var bytes := img.get_data()
		data.append(bytes)
		if not transparent:
			for i in range(3, bytes.size(), 4):
				if bytes[i] < 128:
					transparent = true
					break
	var palette := choose_palette(data, MAX_COLORS - (1 if transparent else 0))
	var clear_index := palette.size() if transparent else -1

	var out := StreamPeerBuffer.new()
	out.big_endian = false
	out.put_data("GIF89a".to_ascii_buffer())
	out.put_u16(width)
	out.put_u16(height)
	out.put_u8(0xF7)  # Global color table of 256 entries, 8 bits per channel.
	out.put_u8(0)  # Background color index.
	out.put_u8(0)  # Pixel aspect ratio: square.
	for i in MAX_COLORS:
		var rgb: int = palette[i] if i < palette.size() else 0
		out.put_u8((rgb >> 16) & 0xFF)
		out.put_u8((rgb >> 8) & 0xFF)
		out.put_u8(rgb & 0xFF)
	# Loop forever (the NETSCAPE2.0 application extension).
	out.put_data(PackedByteArray([0x21, 0xFF, 0x0B]))
	out.put_data("NETSCAPE2.0".to_ascii_buffer())
	out.put_data(PackedByteArray([0x03, 0x01, 0x00, 0x00, 0x00]))

	var lookup := Lookup.new(palette)
	var centiseconds := maxi(2, roundi(delay * 100.0))
	for bytes: PackedByteArray in data:
		# Graphic control: delay; with transparency, clear to background between frames.
		out.put_data(PackedByteArray([0x21, 0xF9, 0x04, (0x09 if transparent else 0x04)]))
		out.put_u16(centiseconds)
		out.put_u8(maxi(clear_index, 0))
		out.put_u8(0)
		out.put_u8(0x2C)  # Image descriptor: the whole screen, no local table.
		out.put_u16(0)
		out.put_u16(0)
		out.put_u16(width)
		out.put_u16(height)
		out.put_u8(0)
		var indices := PackedByteArray()
		indices.resize(width * height)
		for p in width * height:
			var o := p * 4
			if bytes[o + 3] < 128:
				indices[p] = clear_index
			else:
				indices[p] = lookup.index_of((bytes[o] << 16) | (bytes[o + 1] << 8) | bytes[o + 2])
		out.put_u8(8)  # LZW minimum code size.
		var packed := lzw(indices, 8)
		var at := 0
		while at < packed.size():
			var n := mini(255, packed.size() - at)
			out.put_u8(n)
			out.put_data(packed.slice(at, at + n))
			at += n
		out.put_u8(0)
	out.put_u8(0x3B)  # Trailer.
	return out.data_array


## Up to `max_colors` colors (0xRRGGBB ints) for the frames: every color if
## there are few enough, else median cut over a sample.
static func choose_palette(data: Array, max_colors: int) -> PackedInt32Array:
	var counts := {}  # 0xRRGGBB -> how often
	for bytes: PackedByteArray in data:
		var pixels := bytes.size() / 4
		var step := maxi(1, pixels / SAMPLES_PER_FRAME) if counts.size() > max_colors else 1
		for p in range(0, pixels, step):
			var o := p * 4
			if bytes[o + 3] >= 128:
				var rgb := (bytes[o] << 16) | (bytes[o + 1] << 8) | bytes[o + 2]
				counts[rgb] = counts.get(rgb, 0) + 1
	if counts.size() <= max_colors:
		var exact := PackedInt32Array(counts.keys())
		if exact.is_empty():
			exact.append(0)
		return exact
	return _median_cut(counts, max_colors)


## Splits the color cube until there are `max_colors` boxes, at the weighted
## median of the box whose widest channel spread times its pixel count is
## biggest; each box gives its weighted average.
static func _median_cut(counts: Dictionary, max_colors: int) -> PackedInt32Array:
	var boxes := [counts.keys()]
	var weights := [0]
	for rgb in counts:
		weights[0] += counts[rgb]
	while boxes.size() < max_colors:
		# The box to split: widest spread along a channel, times how many
		# pixels it covers (so common colors get more palette entries).
		var best := -1
		var best_score := 0.0
		var best_channel := 0
		for i in boxes.size():
			if boxes[i].size() < 2:
				continue
			for channel in 3:
				var shift := 16 - channel * 8
				var lo := 255
				var hi := 0
				for rgb: int in boxes[i]:
					var v := (rgb >> shift) & 0xFF
					lo = mini(lo, v)
					hi = maxi(hi, v)
				var score := float(hi - lo) * sqrt(float(weights[i]))
				if score > best_score:
					best_score = score
					best = i
					best_channel = channel
		if best < 0:
			break
		var shift := 16 - best_channel * 8
		var box: Array = boxes[best]
		box.sort_custom(func(a, b): return ((a >> shift) & 0xFF) < ((b >> shift) & 0xFF))
		var total := 0
		for rgb in box:
			total += counts[rgb]
		var half := 0
		var cut := 1
		for i in box.size() - 1:
			half += counts[box[i]]
			cut = i + 1
			if half * 2 >= total:
				break
		boxes[best] = box.slice(0, cut)
		boxes.append(box.slice(cut))
		weights[best] = half
		weights.append(total - half)
	var palette := PackedInt32Array()
	for box: Array in boxes:
		var sum := Vector3.ZERO
		var weight := 0
		for rgb: int in box:
			var n: int = counts[rgb]
			sum += Vector3((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF) * n
			weight += n
		var avg := sum / maxf(1.0, weight)
		palette.append((int(roundf(avg.x)) << 16) | (int(roundf(avg.y)) << 8) | int(roundf(avg.z)))
	return palette


## LZW as GIF wants it: codes of growing width (min_code + 1 up to 12 bits),
## packed least significant bit first; a clear code when the table is full.
static func lzw(indices: PackedByteArray, min_code: int) -> PackedByteArray:
	var clear := 1 << min_code
	var eoi := clear + 1
	var next := eoi + 1
	var size := min_code + 1
	var table := {}
	var out := PackedByteArray()
	var acc := 0
	var bits := 0
	# The clear code first.
	acc |= clear << bits
	bits += size
	if indices.is_empty():
		acc |= eoi << bits
		bits += size
	else:
		var prefix := int(indices[0])
		for i in range(1, indices.size()):
			var k := int(indices[i])
			var key := (prefix << 8) | k
			var found: Variant = table.get(key)
			if found != null:
				prefix = found
				continue
			acc |= prefix << bits
			bits += size
			while bits >= 8:
				out.append(acc & 0xFF)
				acc >>= 8
				bits -= 8
			if next == 4096:
				acc |= clear << bits
				bits += size
				while bits >= 8:
					out.append(acc & 0xFF)
					acc >>= 8
					bits -= 8
				table.clear()
				next = eoi + 1
				size = min_code + 1
			else:
				if next >= (1 << size):
					size += 1
				table[key] = next
				next += 1
			prefix = k
		acc |= prefix << bits
		bits += size
		while bits >= 8:
			out.append(acc & 0xFF)
			acc >>= 8
			bits -= 8
		acc |= eoi << bits
		bits += size
	while bits > 0:
		out.append(acc & 0xFF)
		acc >>= 8
		bits -= 8
	return out


## Nearest palette color for a pixel: exact colors straight away, others by
## search, remembered per 15-bit color.
class Lookup:
	var palette: PackedInt32Array
	var exact := {}
	var cache := PackedInt32Array()

	func _init(colors: PackedInt32Array) -> void:
		palette = colors
		for i in colors.size():
			exact[colors[i]] = i
		cache.resize(32768)
		cache.fill(-1)

	func index_of(rgb: int) -> int:
		var hit: Variant = exact.get(rgb)
		if hit != null:
			return hit
		var key := ((rgb >> 9) & 0x7C00) | ((rgb >> 6) & 0x3E0) | ((rgb >> 3) & 0x1F)
		if cache[key] >= 0:
			return cache[key]
		var r := (rgb >> 16) & 0xFF
		var g := (rgb >> 8) & 0xFF
		var b := rgb & 0xFF
		var best := 0
		var best_d := 1 << 30
		for i in palette.size():
			var c := palette[i]
			var dr := r - ((c >> 16) & 0xFF)
			var dg := g - ((c >> 8) & 0xFF)
			var db := b - (c & 0xFF)
			var d := 2 * dr * dr + 4 * dg * dg + 3 * db * db
			if d < best_d:
				best_d = d
				best = i
		cache[key] = best
		return best
