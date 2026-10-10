extends RefCounted
## The Gut palette as named ramps (D-028), read from assets/art/_source/gut.gpl:
## a "# ramp <name>" line starts a ramp; its colors follow, dark to light.
##
##   var pal := Palette.load_default()
##   pal.ramp(&"bone")        -> [darkest .. lightest]
##   pal.shade(&"bone", 0.7)  -> the color 70% of the way up the ramp
##   pal.snap(color)          -> nearest palette color

const PATH := "res://assets/art/_source/gut.gpl"

var ramps := {}  # StringName -> Array[Color]
var colors: Array[Color] = []


static func load_default() -> RefCounted:
	var pal = load("res://tools/pixel/palette.gd").new()
	pal.read(PATH)
	return pal


func read(path: String) -> void:
	var current := &""
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw.strip_edges()
		if line.begins_with("# ramp "):
			current = StringName(line.substr(7).strip_edges())
			ramps[current] = []
			continue
		var bits := line.replace("\t", " ").split(" ", false)
		if bits.size() >= 3 and bits[0].is_valid_int():
			var c := Color8(int(bits[0]), int(bits[1]), int(bits[2]))
			colors.append(c)
			if current != &"":
				ramps[current].append(c)


func ramp(name: StringName) -> Array:
	assert(ramps.has(name), "no ramp %s in the palette" % name)
	return ramps[name]


## A step of a ramp by position 0..1 (0 = darkest). Clamped.
func shade(name: StringName, t: float) -> Color:
	var r: Array = ramp(name)
	return r[clampi(roundi(t * (r.size() - 1)), 0, r.size() - 1)]


## A step by index, counted from the dark end (negative = from the light end).
func step(name: StringName, i: int) -> Color:
	var r: Array = ramp(name)
	return r[clampi(i if i >= 0 else r.size() + i, 0, r.size() - 1)]


func outline() -> Color:
	return ramps[&"outline"][0]


func has(c: Color) -> bool:
	for p in colors:
		if p.is_equal_approx(Color(c, 1.0)):
			return true
	return false


## The nearest palette color ("redmean" distance), keeping c's alpha.
func snap(c: Color) -> Color:
	var best := colors[0]
	var best_d := INF
	for p in colors:
		var rm := (c.r + p.r) * 0.5
		var dr := c.r - p.r
		var dg := c.g - p.g
		var db := c.b - p.b
		var d := (2.0 + rm) * dr * dr + 4.0 * dg * dg + (3.0 - rm) * db * db
		if d < best_d:
			best_d = d
			best = p
	return Color(best, c.a)
