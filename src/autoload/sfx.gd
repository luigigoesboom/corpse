extends Node
## Sound effects (week 40).
##
##   Sfx.play(&"hit")                  plays everywhere
##   Sfx.play(&"hit", global_position) quieter the further it is from the camera
##
## Where a sound comes from, first found wins:
##   1. assets/audio/sfx/<id>.wav: copied from the licensed pack by
##      tools/copy_sfx.sh (not in git: the license forbids sharing them)
##   2. assets/audio/generated/<id>.wav: our own, made by tools/sound/sounds.gd
##   3. a tiny inline recipe below (the oldest placeholders)
## SOUNDS sets each one's volume (dB), pitch and bus (SFX unless said).

const RATE := 22050
const VOICES := 12
## Sounds further than this from the screen center are not played.
const HEARING_RANGE := 900.0
const PACK_DIR := "res://assets/audio/sfx/"
const OWN_DIR := "res://assets/audio/generated/"

## id: [volume dB, pitch, bus]. Volumes are for the pack's copies; our own
## files and recipes are mixed to sit at about the same level.
const SOUNDS := {
	&"jump": [-18.0, 1.0, &"SFX"], &"land": [-16.0, 1.0, &"SFX"], &"swing": [-10.0, 1.0, &"SFX"],
	&"hit": [-6.0, 1.0, &"SFX"], &"hurt": [-6.0, 1.0, &"SFX"], &"die": [-6.0, 1.0, &"SFX"],
	&"pickup": [-8.0, 1.0, &"SFX"], &"eat": [-8.0, 1.0, &"SFX"], &"spit": [-8.0, 1.0, &"SFX"],
	&"dash": [-10.0, 1.0, &"SFX"], &"enemy_die": [-6.0, 1.0, &"SFX"], &"buzz": [-24.0, 1.0, &"SFX"],
	&"dodge": [-16.0, 1.0, &"SFX"],
	# Creatures.
	&"leech_bite": [-8.0, 1.0, &"SFX"], &"leech_hiss": [-14.0, 1.0, &"SFX"], &"spitter_charge": [-12.0, 1.0, &"SFX"],
	&"squelch": [-12.0, 1.0, &"SFX"],
	&"matron_roar": [-2.0, 0.55, &"SFX"], &"matron_slam": [-4.0, 0.8, &"SFX"], &"matron_lunge": [-6.0, 0.9, &"SFX"],
	&"matron_hurt": [-8.0, 0.75, &"SFX"], &"matron_die": [-2.0, 0.8, &"SFX"], &"matron_phase": [-4.0, 0.8, &"SFX"],
	# The world.
	&"alert": [-12.0, 1.0, &"SFX"], &"alarm": [-8.0, 0.8, &"SFX"], &"grate": [-8.0, 0.8, &"SFX"],
	&"latch": [-10.0, 1.0, &"SFX"], &"ichor": [-12.0, 0.7, &"SFX"], &"bank": [-6.0, 0.85, &"UI"],
	&"boon": [-6.0, 0.9, &"UI"], &"key": [-6.0, 0.8, &"UI"], &"heart_root": [-8.0, 0.8, &"SFX"],
	&"mural": [-10.0, 1.0, &"UI"], &"theft": [-8.0, 0.9, &"UI"], &"death_sting": [-6.0, 0.9, &"UI"],
	&"rebirth": [-6.0, 0.85, &"UI"], &"years": [-8.0, 1.0, &"UI"], &"discover": [-10.0, 0.85, &"UI"],
	# Menus.
	&"ui_hover": [-18.0, 1.0, &"UI"], &"ui_select": [-12.0, 1.0, &"UI"], &"ui_open": [-12.0, 1.0, &"UI"],
	&"ui_close": [-12.0, 1.0, &"UI"], &"ui_tab": [-14.0, 1.0, &"UI"],
}
## Inline placeholders: [seconds, start Hz, end Hz, noise 0..1, "sine"/"square", volume dB].
const RECIPES := {
	&"jump": [0.10, 260.0, 520.0, 0.0, "square", -18.0],
	&"land": [0.07, 90.0, 50.0, 0.6, "sine", -16.0],
	&"swing": [0.09, 900.0, 300.0, 0.8, "sine", -20.0],
	&"hit": [0.10, 160.0, 70.0, 0.7, "square", -12.0],
	&"hurt": [0.22, 420.0, 140.0, 0.25, "square", -12.0],
	&"die": [0.55, 300.0, 60.0, 0.3, "square", -10.0],
	&"pickup": [0.12, 520.0, 1040.0, 0.0, "sine", -14.0],
	&"eat": [0.30, 140.0, 90.0, 0.5, "sine", -10.0],
	&"spit": [0.14, 700.0, 220.0, 0.5, "sine", -14.0],
	&"dash": [0.16, 400.0, 900.0, 0.9, "sine", -18.0],
	&"enemy_die": [0.35, 220.0, 50.0, 0.7, "square", -12.0],
	&"buzz": [0.20, 180.0, 200.0, 0.2, "square", -24.0],
	&"dodge": [0.18, 320.0, 120.0, 0.9, "sine", -16.0],
}

var _streams := {}
var _volumes := {}
var _pitches := {}
var _buses := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for id in SOUNDS:
		var info: Array = SOUNDS[id]
		_buses[id] = info[2]
		var pack := PACK_DIR + String(id) + ".wav"
		var own := OWN_DIR + String(id) + ".wav"
		if ResourceLoader.exists(pack):
			_streams[id] = load(pack)
			_volumes[id] = info[0]
			_pitches[id] = info[1]
		elif ResourceLoader.exists(own):
			_streams[id] = load(own)
			_volumes[id] = info[0] - 2.0
			_pitches[id] = 1.0
		elif RECIPES.has(id):
			_streams[id] = _make(RECIPES[id])
			_volumes[id] = RECIPES[id][5]
			_pitches[id] = 1.0
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func has_sound(id: StringName) -> bool:
	return _streams.has(id)


func play(id: StringName, at := Vector2.INF) -> void:
	if not _streams.has(id):
		return
	var volume: float = _volumes[id]
	if at != Vector2.INF:
		var camera := get_viewport().get_camera_2d()
		if camera:
			var distance := camera.get_screen_center_position().distance_to(at)
			if distance > HEARING_RANGE:
				return
			volume -= distance / HEARING_RANGE * 18.0
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = _streams[id]
	player.volume_db = volume
	player.bus = _buses.get(id, &"SFX")
	player.pitch_scale = _pitches[id] * randf_range(0.93, 1.07)  # Cosmetic, so global randf is fine.
	player.play()


func _make(recipe: Array) -> AudioStreamWAV:
	var seconds: float = recipe[0]
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(recipe)
	var noise_value := 0.0
	for i in count:
		var t := float(i) / count
		var freq: float = lerpf(recipe[1], recipe[2], t)
		phase += freq / RATE
		var tone := sin(phase * TAU) if recipe[4] == "sine" else (1.0 if fmod(phase, 1.0) < 0.5 else -1.0)
		if i % 3 == 0:
			noise_value = rng.randf_range(-1.0, 1.0)  # Held a few samples: crunchier.
		var sample := lerpf(tone, noise_value, recipe[3])
		var envelope := minf(1.0, t * 40.0) * (1.0 - t) * (1.0 - t)
		data.encode_s16(i * 2, int(clampf(sample * envelope, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
