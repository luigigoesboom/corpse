class_name Atmosphere
extends Node
## The air of the body (atmosphere pass, after week 52), all of it a view:
##   - the picture's look (assets/shaders/atmosphere.gdshader on the
##     Vignette layer): grading per region, a deep beating vignette, grain,
##     the dark closing in red when the host is nearly dead;
##   - fog banks drifting behind the playfield, and a thin mist low in
##     front of it (assets/shaders/fog.gdshader);
##   - motes and spores floating in the air around the camera, carried by
##     the breath (Motes).
## Region looks ease into each other as the camera crosses. The Atmosphere
## setting (Settings.atmosphere, 0..1) scales all of it; 0 turns it off.
## Game adds one and gives it the Vignette's shade and the player.

## Per region: grading, vignette and fog colours, how foggy, mote colours.
const LOOKS := {
	&"gut": {
		"lift": Color(0.05, 0.0, 0.02), "gain": Color(1.06, 0.95, 0.9), "saturation": 0.88,
		"vignette": Color(0.04, 0.0, 0.02), "fog": Color(0.45, 0.16, 0.2), "fog_density": 0.42,
		"mist": Color(0.55, 0.3, 0.3), "motes": [Color8(227, 154, 168), Color8(184, 212, 58), Color8(246, 200, 208)],
	},
	&"lungs": {
		"lift": Color(0.0, 0.02, 0.05), "gain": Color(0.95, 0.99, 1.07), "saturation": 0.78,
		"vignette": Color(0.02, 0.02, 0.05), "fog": Color(0.55, 0.6, 0.72), "fog_density": 0.46,
		"mist": Color(0.75, 0.78, 0.86), "motes": [Color8(214, 220, 232), Color8(140, 255, 204), Color8(246, 200, 208)],
	},
	# Heavy rot (D-033), mixed in by how rotten the air is where the camera is.
	&"rot": {
		"lift": Color(0.03, 0.04, 0.0), "gain": Color(1.0, 1.02, 0.82), "saturation": 0.7,
		"vignette": Color(0.03, 0.03, 0.0), "fog": Color(0.42, 0.42, 0.2), "fog_density": 0.6,
		"mist": Color(0.55, 0.55, 0.3), "motes": [Color8(170, 160, 90), Color8(120, 110, 60), Color8(200, 190, 120)],
	},
}
## The god's heart, as the ambience plays it (beats per minute).
const HEART_BPM := 52.0
## How quickly a region's look gives way to the next (per second).
const EASE := 0.6

var shade: CanvasItem  # The full-screen ColorRect with the atmosphere shader.
var player: Node2D

var _time := 0.0
var _look := {}  # The current, eased look.
var _fog: ShaderMaterial
var _mist: ShaderMaterial
var _motes: Motes


func _ready() -> void:
	_look = _copy(LOOKS[&"gut"])
	_fog = _layer("Fog", -5, 0.55, 0.0)
	_mist = _layer("Mist", 2, 1.15, 0.9)
	_motes = Motes.new()
	_motes.name = "Motes"
	get_parent().add_child.call_deferred(_motes)


## A full-screen fog layer: `scroll` = parallax, `low` = how much it hugs the floor.
func _layer(layer_name: String, layer: int, scroll: float, low: float) -> ShaderMaterial:
	var canvas := CanvasLayer.new()
	canvas.name = layer_name
	canvas.layer = layer
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/fog.gdshader")
	material.set_shader_parameter("scroll", scroll)
	material.set_shader_parameter("low", low)
	rect.material = material
	canvas.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_parent().add_child.call_deferred(canvas)
	return material


func _process(delta: float) -> void:
	_time += delta
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var at := camera.get_screen_center_position()
	var amount := Settings.atmosphere if Settings else 1.0
	# Blend the looks by how much of the view is in each region.
	var lungs := WorldMap.region_share(at, Regions.LUNGS)
	var target := _mix(LOOKS[&"gut"], LOOKS[&"lungs"], lungs)
	var rot := smoothstep(0.3, 0.8, Rot.at_point(WorldState.data, at)) if WorldState.data else 0.0
	if rot > 0.0:
		target = _mix(target, LOOKS[&"rot"], rot)
	for key in _look:
		if _look[key] is Color:
			_look[key] = (_look[key] as Color).lerp(target[key], clampf(delta * EASE, 0.0, 1.0))
		elif _look[key] is float:
			_look[key] = lerpf(_look[key], target[key], clampf(delta * EASE, 0.0, 1.0))
	_look.motes = target.motes
	var screen := get_viewport().get_visible_rect().size
	var beat := heartbeat(_time)
	if shade and shade.material is ShaderMaterial:
		var m: ShaderMaterial = shade.material
		m.set_shader_parameter("amount", amount)
		m.set_shader_parameter("time_s", _time)
		m.set_shader_parameter("heartbeat", beat)
		m.set_shader_parameter("breath", Breath.strength() * lungs)
		m.set_shader_parameter("hurt", _hurt())
		m.set_shader_parameter("lift", _vec(_look.lift))
		m.set_shader_parameter("gain", _vec(_look.gain))
		m.set_shader_parameter("saturation", _look.saturation)
		m.set_shader_parameter("vignette_tint", _look.vignette)
		m.set_shader_parameter("grain", 0.045 if Settings == null or Settings.film_grain else 0.0)
		m.set_shader_parameter("pixels", screen)
	for m in [_fog, _mist]:
		m.set_shader_parameter("camera_position", at)
		m.set_shader_parameter("screen_size", screen)
		m.set_shader_parameter("time_s", _time)
	_fog.set_shader_parameter("tint", _look.fog)
	_fog.set_shader_parameter("density", _look.fog_density * amount * (1.0 + Breath.strength() * lungs * 0.25))
	_mist.set_shader_parameter("tint", _look.mist)
	_mist.set_shader_parameter("density", 0.2 * amount)
	_mist.set_shader_parameter("drift", 10.0 + Breath.wind_at(at).x * 0.02)
	if _motes:
		_motes.colors = _look.motes
		_motes.amount = amount


## The heart's double thump (0..1): lub, then a softer dub.
static func heartbeat(t: float) -> float:
	var period := 60.0 / HEART_BPM
	var p := fmod(t, period)
	return exp(-p * 18.0) + 0.6 * exp(-maxf(0.0, p - 0.28) * 18.0) * (1.0 if p > 0.28 else 0.0)


## 0 when the host is fine, 0.5 with two hearts left, 1 with one.
func _hurt() -> float:
	if player == null or not "health" in player:
		return 0.0
	var h: Health = player.health
	if h.is_dead():
		return 1.0
	return 1.0 if h.current <= 1 else (0.5 if h.current == 2 else 0.0)


static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var out := {}
	for key in a:
		if a[key] is Color:
			out[key] = (a[key] as Color).lerp(b[key], t)
		elif a[key] is float:
			out[key] = lerpf(a[key], b[key], t)
		else:
			out[key] = b[key] if t > 0.5 else a[key]
	return out


static func _copy(d: Dictionary) -> Dictionary:
	return d.duplicate(true)


static func _vec(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
