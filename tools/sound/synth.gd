extends RefCounted
## A tiny synthesizer for the game's own sounds (week 40): mono float
## buffers you add tones, noise and envelopes into, simple filters, and a
## WAV writer. Used by tools/sound/sounds.gd. Everything is seeded, so the
## same recipe always makes the same file.

const RATE := 22050

var data := PackedFloat32Array()
var rng := RandomNumberGenerator.new()


func _init(seconds: float, seed_value := 1) -> void:
	data.resize(int(seconds * RATE))
	rng.seed = seed_value


func length() -> int:
	return data.size()


## A tone from `start` to `end` seconds, frequency sliding f0 -> f1, with an
## attack / decay envelope. wave: "sine", "tri", "saw", "square".
func tone(start: float, end: float, f0: float, f1: float, amp: float, wave := "sine", attack := 0.01, decay := 1.0) -> void:
	var a = int(start * RATE)
	var b = mini(int(end * RATE), data.size())
	var phase = 0.0
	for i in range(a, b):
		var t = float(i - a) / maxf(1.0, b - a)
		phase += lerpf(f0, f1, t) / RATE
		var x = fmod(phase, 1.0)
		var s = 0.0
		match wave:
			"sine": s = sin(phase * TAU)
			"tri": s = 1.0 - 4.0 * absf(x - 0.5)
			"saw": s = 2.0 * x - 1.0
			"square": s = 1.0 if x < 0.5 else -1.0
		data[i] += s * amp * _env(t, (b - a) / float(RATE), attack, decay)


## Noise from `start` to `end`, low-passed at `cutoff` Hz (0 = white).
func noise(start: float, end: float, amp: float, cutoff := 0.0, attack := 0.01, decay := 1.0) -> void:
	var a = int(start * RATE)
	var b = mini(int(end * RATE), data.size())
	var k = _lowpass_k(cutoff)
	var y = 0.0
	for i in range(a, b):
		var t = float(i - a) / maxf(1.0, b - a)
		var w = rng.randf_range(-1.0, 1.0)
		y = w if cutoff <= 0.0 else y + k * (w - y)
		data[i] += y * amp * (1.0 if cutoff <= 0.0 else 3.0) * _env(t, (b - a) / float(RATE), attack, decay)


## A wet "squelch": low-passed noise whose cutoff sweeps down, plus a
## falling thump.
func squelch(at: float, length_s: float, amp: float, pitch := 1.0) -> void:
	var a = int(at * RATE)
	var b = mini(a + int(length_s * RATE), data.size())
	var y = 0.0
	var y2 = 0.0
	for i in range(a, b):
		var t = float(i - a) / maxf(1.0, b - a)
		var k = _lowpass_k(lerpf(2600.0, 300.0, t) * pitch)
		y += k * (rng.randf_range(-1.0, 1.0) - y)
		y2 += k * (y - y2)
		data[i] += y2 * amp * 4.0 * pow(1.0 - t, 1.5) * minf(1.0, t * 30.0)
	tone(at, at + length_s * 0.7, 140.0 * pitch, 55.0 * pitch, amp * 0.6, "sine", 0.005, 2.0)


## A bubble: a short sine whose pitch rises fast (that is what bubbles do).
func bubble(at: float, size: float, amp: float) -> void:
	var f = 1600.0 / maxf(size, 0.2)
	tone(at, at + 0.06 + size * 0.04, f, f * 1.8, amp, "sine", 0.002, 3.0)


## A drip: a tiny plink and its echo.
func drip(at: float, amp: float, pitch := 1.0) -> void:
	tone(at, at + 0.09, 1400.0 * pitch, 2400.0 * pitch, amp, "sine", 0.002, 4.0)
	tone(at + 0.11, at + 0.2, 1400.0 * pitch, 2400.0 * pitch, amp * 0.25, "sine", 0.002, 4.0)


## A heartbeat: two soft low thumps ("lub-dub").
func heartbeat(at: float, amp: float, pitch := 1.0) -> void:
	for k in 2:
		var t = at + k * 0.28
		var f = (62.0 if k == 0 else 52.0) * pitch
		tone(t, t + 0.22, f * 1.6, f, amp * (1.0 if k == 0 else 0.7), "sine", 0.004, 2.5)
		noise(t, t + 0.08, amp * 0.25, 180.0, 0.003, 3.0)


## Gentle low-pass over the whole buffer (smooths harsh edges).
func soften(cutoff: float) -> void:
	var k = _lowpass_k(cutoff)
	var y = 0.0
	for i in data.size():
		y += k * (data[i] - y)
		data[i] = y


## Makes the end flow into the start: the last `seconds` crossfade into
## the first, then are cut, so the buffer loops without a click.
func make_loop(seconds: float) -> void:
	var n = int(seconds * RATE)
	var size = data.size()
	for i in n:
		var t = float(i) / n
		data[i] = data[i] * t + data[size - n + i] * (1.0 - t)
	data.resize(size - n)


func normalize(peak := 0.9) -> void:
	var m = 0.0
	for s in data:
		m = maxf(m, absf(s))
	if m > 0.0:
		for i in data.size():
			data[i] *= peak / m


func save(path: String, loop := false) -> void:
	var bytes = PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = data.size()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	stream.save_to_wav(ProjectSettings.globalize_path(path))


func _env(t: float, seconds: float, attack: float, decay: float) -> float:
	var rise = minf(1.0, t * seconds / maxf(attack, 0.0005))
	return rise * pow(1.0 - t, decay)


static func _lowpass_k(cutoff: float) -> float:
	if cutoff <= 0.0:
		return 1.0
	return 1.0 - exp(-TAU * cutoff / RATE)
