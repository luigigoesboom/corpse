extends Node
## Placeholder sound effects, generated in code (no audio files yet).
##
##   Sfx.play(&"hit")                  plays everywhere
##   Sfx.play(&"hit", global_position) quieter the further it is from the camera
##
## Each sound is a short recipe below (a pitch sweep and/or noise). Replace a
## recipe with a real file later: put an AudioStream in _streams under the same
## name and nothing else changes.

const RATE := 22050
const VOICES := 8
## Sounds further than this from the screen center are not played.
const HEARING_RANGE := 900.0

## name: [seconds, start Hz, end Hz, noise amount 0..1, wave ("sine"/"square"), volume dB]
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
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	for id in RECIPES:
		_streams[id] = _make(RECIPES[id])
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_players.append(player)


func play(id: StringName, at := Vector2.INF) -> void:
	if not _streams.has(id):
		return
	var volume: float = RECIPES[id][5] if RECIPES.has(id) else 0.0
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
	player.pitch_scale = randf_range(0.93, 1.07)  # Cosmetic, so global randf is fine.
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
