extends SceneTree
## The game's own sounds (week 40), made by tools/sound/synth.gd:
##
##   Godot --headless --path . --script res://tools/sound/sounds.gd
##
## Writes assets/audio/generated/<id>.wav (committed: they are ours). Sfx
## and Ambience use them when the licensed pack's copy (assets/audio/sfx,
## assets/audio/ambience, from tools/copy_sfx.sh) is not there, and some
## (the body's heartbeat, squelches, bubbles) are always ours.

const Synth := preload("res://tools/sound/synth.gd")
const OUT := "res://assets/audio/generated/"
const LOOP := 12.0  # Seconds per ambience loop (before the crossfade).


func _initialize() -> void:
	var started := Time.get_ticks_msec()
	_one_shots()
	_ui()
	_loops()
	print("sounds written in %d ms" % (Time.get_ticks_msec() - started))
	quit()


func _done(s, id: String, loop := false, peak := 0.85) -> void:
	s.soften(9000.0)
	s.normalize(peak)
	s.save(OUT + id + ".wav", loop)


func _one_shots() -> void:
	var s
	# Creatures.
	s = Synth.new(0.3, 1); s.squelch(0.0, 0.28, 0.8, 1.2); _done(s, "leech_bite")
	s = Synth.new(0.6, 2); s.noise(0.0, 0.6, 0.6, 3000.0, 0.15, 1.2); s.tone(0.0, 0.6, 180, 240, 0.15, "saw", 0.2, 1.0); _done(s, "leech_hiss", false, 0.6)
	s = Synth.new(0.7, 3)
	for i in 9:
		s.bubble(i * 0.07, s.rng.randf_range(0.6, 1.4), 0.5)
	_done(s, "spitter_charge", false, 0.7)
	s = Synth.new(0.25, 4); s.squelch(0.0, 0.22, 0.8, 1.6); _done(s, "squelch")
	# The Matron.
	s = Synth.new(1.6, 5)
	s.tone(0.0, 1.6, 95, 60, 0.6, "saw", 0.15, 1.2)
	s.tone(0.0, 1.6, 97, 58, 0.5, "saw", 0.2, 1.2)
	s.noise(0.0, 1.6, 0.5, 700.0, 0.1, 1.5)
	_done(s, "matron_roar")
	s = Synth.new(1.2, 6); s.tone(0.0, 0.9, 70, 32, 0.9, "sine", 0.002, 2.0); s.noise(0.0, 1.0, 0.7, 500.0, 0.002, 3.0); _done(s, "matron_slam", false, 0.95)
	s = Synth.new(0.7, 7); s.noise(0.0, 0.7, 0.7, 1800.0, 0.05, 1.5); s.squelch(0.05, 0.5, 0.6, 0.7); _done(s, "matron_lunge")
	s = Synth.new(0.5, 8); s.tone(0.0, 0.5, 160, 90, 0.6, "saw", 0.01, 2.0); s.squelch(0.0, 0.4, 0.5, 0.8); _done(s, "matron_hurt")
	s = Synth.new(3.0, 9)
	s.tone(0.0, 3.0, 90, 25, 0.6, "saw", 0.05, 1.3)
	s.tone(0.1, 3.0, 93, 24, 0.5, "saw", 0.05, 1.3)
	s.noise(0.0, 3.0, 0.4, 500.0, 0.05, 1.0)
	for i in 4:
		s.squelch(0.6 + i * 0.5, 0.4, 0.4, 0.6)
	_done(s, "matron_die")
	s = Synth.new(2.2, 10)
	for k in 3:
		s.tone(0.0, 2.2, 70 + k * 31, 55 + k * 29, 0.35, "saw", 0.3, 1.0)
	s.noise(0.0, 2.2, 0.4, 900.0, 0.3, 1.2)
	_done(s, "matron_phase")
	# The world.
	s = Synth.new(0.3, 11); s.tone(0.0, 0.12, 520, 700, 0.5, "tri", 0.005, 2.0); s.tone(0.13, 0.28, 700, 980, 0.5, "tri", 0.005, 2.0); _done(s, "alert", false, 0.6)
	s = Synth.new(1.2, 12)
	for k in 3:
		s.tone(0.0, 1.2, 330 + k * 37, 320 + k * 37, 0.3, "square", 0.002, 2.5)
	s.noise(0.0, 0.3, 0.4, 3000.0, 0.002, 3.0)
	_done(s, "alarm", false, 0.75)
	s = Synth.new(0.9, 13)
	for i in 6:
		var t: float = i * 0.13 + s.rng.randf_range(0.0, 0.04)
		s.noise(t, t + 0.06, 0.6, 2500.0, 0.002, 3.0)
		s.tone(t, t + 0.08, 900, 700, 0.2, "square", 0.002, 3.0)
	_done(s, "grate")
	s = Synth.new(0.5, 14); s.noise(0.0, 0.05, 0.8, 4000.0, 0.001, 3.0); s.tone(0.05, 0.5, 300, 220, 0.25, "saw", 0.05, 1.5); _done(s, "latch", false, 0.7)
	s = Synth.new(0.25, 15); s.bubble(0.0, 0.7, 0.6); s.drip(0.05, 0.3, 0.8); _done(s, "ichor", false, 0.55)
	s = Synth.new(2.0, 16)
	for k in 4:
		s.tone(k * 0.25, 2.0, 220 * pow(1.26, k), 220 * pow(1.26, k), 0.25, "sine", 0.05, 1.5)
	s.heartbeat(0.0, 0.5)
	_done(s, "bank", false, 0.7)
	s = Synth.new(1.4, 17)
	for k in 3:
		s.tone(k * 0.15, 1.4, 330 * pow(1.5, k * 0.5), 330 * pow(1.5, k * 0.5), 0.3, "tri", 0.01, 1.8)
	_done(s, "boon", false, 0.7)
	s = Synth.new(1.6, 18); s.tone(0.0, 1.6, 110, 110, 0.5, "tri", 0.01, 1.5); s.tone(0.0, 1.6, 165, 165, 0.3, "sine", 0.01, 1.5); s.tone(0.2, 1.6, 220, 220, 0.25, "sine", 0.05, 1.5); _done(s, "key", false, 0.75)
	s = Synth.new(2.0, 19); s.tone(0.0, 2.0, 45, 60, 0.6, "sine", 0.6, 1.0); s.heartbeat(0.3, 0.6); s.heartbeat(1.1, 0.5); _done(s, "heart_root", false, 0.8)
	s = Synth.new(0.5, 20); s.noise(0.0, 0.5, 0.4, 2500.0, 0.05, 1.2); _done(s, "mural", false, 0.4)
	s = Synth.new(1.4, 21); s.tone(0.0, 1.4, 233, 220, 0.4, "saw", 0.01, 1.5); s.tone(0.0, 1.4, 247, 262, 0.4, "saw", 0.01, 1.5); _done(s, "theft", false, 0.7)
	s = Synth.new(3.5, 22)
	for k in 3:
		s.tone(k * 0.6, 3.5, 98 / pow(1.2, k), 90 / pow(1.2, k), 0.4, "tri", 0.05, 1.5)
	s.heartbeat(0.0, 0.6); s.heartbeat(1.1, 0.4); s.heartbeat(2.4, 0.2)
	_done(s, "death_sting", false, 0.8)
	s = Synth.new(3.0, 23)
	s.tone(0.0, 3.0, 55, 110, 0.5, "sine", 1.5, 0.6)
	s.tone(0.5, 3.0, 82, 165, 0.3, "tri", 1.2, 0.6)
	s.heartbeat(2.0, 0.6)
	_done(s, "rebirth", false, 0.8)
	s = Synth.new(4.0, 24); s.noise(0.0, 4.0, 0.5, 400.0, 1.5, 1.0); s.tone(0.0, 4.0, 41, 41, 0.4, "sine", 1.5, 1.0); _done(s, "years", false, 0.7)
	s = Synth.new(1.8, 25); s.tone(0.0, 0.8, 110, 110, 0.5, "saw", 0.08, 1.0); s.tone(0.7, 1.8, 147, 147, 0.5, "saw", 0.08, 1.2); s.soften(900.0); _done(s, "discover", false, 0.6)

	# The Lungs (week 45 on).
	s = Synth.new(0.9, 40)
	s.tone(0.0, 0.9, 120, 260, 0.35, "saw", 0.4, 0.4)  # Skin stretching.
	s.noise(0.0, 0.9, 0.3, 1200.0, 0.5, 0.6)
	for i in 4:
		s.squelch(0.15 + i * 0.18, 0.12, 0.25, 1.4 + i * 0.2)
	_done(s, "puffsac_swell", false, 0.6)
	s = Synth.new(0.9, 41)
	s.noise(0.0, 0.08, 1.0, 6000.0, 0.001, 4.0)  # The pop.
	s.tone(0.0, 0.15, 180, 60, 0.7, "sine", 0.001, 3.0)
	s.noise(0.05, 0.9, 0.45, 2600.0, 0.02, 1.4)  # Spores hissing out.
	_done(s, "puffsac_burst", false, 0.9)
	s = Synth.new(0.4, 42)
	s.tone(0.0, 0.35, 95, 60, 0.8, "sine", 0.002, 2.5)  # A drum of skin.
	s.squelch(0.0, 0.2, 0.35, 1.3)
	_done(s, "membrane", false, 0.75)
	s = Synth.new(0.6, 43)
	s.noise(0.0, 0.55, 0.4, 2200.0, 0.4, 0.5)  # Hairs bristling, drawing back.
	s.tone(0.0, 0.55, 300, 520, 0.12, "saw", 0.4, 0.6)
	_done(s, "lasher_draw", false, 0.55)
	s = Synth.new(0.35, 44)
	s.noise(0.0, 0.12, 0.9, 5000.0, 0.002, 3.0)  # A crack of the lash.
	s.squelch(0.03, 0.2, 0.4, 1.6)
	_done(s, "lasher_lash", false, 0.85)
	s = Synth.new(1.0, 45)
	s.tone(0.0, 0.9, 700, 420, 0.3, "sine", 0.05, 1.2)  # A long breathy cry.
	s.tone(0.0, 0.9, 1050, 640, 0.12, "tri", 0.05, 1.2)
	s.noise(0.0, 0.9, 0.3, 1800.0, 0.1, 1.0)
	_done(s, "ray_cry", false, 0.6)

func _ui() -> void:
	var s
	s = Synth.new(0.05, 30); s.tone(0.0, 0.05, 1200, 1300, 0.4, "tri", 0.002, 3.0); _done(s, "ui_hover", false, 0.35)
	s = Synth.new(0.1, 31); s.tone(0.0, 0.1, 700, 1100, 0.5, "tri", 0.002, 2.5); _done(s, "ui_select", false, 0.5)
	s = Synth.new(0.2, 32); s.squelch(0.0, 0.18, 0.5, 1.8); s.tone(0.0, 0.15, 400, 600, 0.3, "tri", 0.005, 2.0); _done(s, "ui_open", false, 0.5)
	s = Synth.new(0.2, 33); s.squelch(0.0, 0.18, 0.5, 1.4); s.tone(0.0, 0.15, 600, 380, 0.3, "tri", 0.005, 2.0); _done(s, "ui_close", false, 0.5)
	s = Synth.new(0.06, 34); s.noise(0.0, 0.05, 0.6, 4500.0, 0.001, 3.0); _done(s, "ui_tab", false, 0.4)


func _loops() -> void:
	var s
	# The body: a slow heartbeat over a low drone. Always there, ours.
	s = Synth.new(LOOP + 1.0, 40)
	s.tone(0.0, LOOP + 1.0, 41, 41, 0.25, "sine", 0.0, 0.0)
	s.tone(0.0, LOOP + 1.0, 41.6, 41.6, 0.2, "sine", 0.0, 0.0)
	s.noise(0.0, LOOP + 1.0, 0.15, 120.0, 0.0, 0.0)
	var beat := 0.0
	while beat < LOOP:
		s.heartbeat(beat, 0.7, 1.0)
		beat += 60.0 / 52.0
	s.make_loop(1.0)
	_done(s, "amb_body", true, 0.7)
	# Flesh: wet shifting, far squelches.
	s = Synth.new(LOOP + 1.0, 41)
	s.noise(0.0, LOOP + 1.0, 0.25, 250.0, 0.0, 0.0)
	for i in 22:
		s.squelch(s.rng.randf_range(0.0, LOOP), s.rng.randf_range(0.2, 0.6), s.rng.randf_range(0.15, 0.4), s.rng.randf_range(0.5, 1.1))
	s.make_loop(1.0)
	_done(s, "amb_flesh", true, 0.6)
	# Bile: bubbling.
	s = Synth.new(LOOP + 1.0, 42)
	s.noise(0.0, LOOP + 1.0, 0.15, 400.0, 0.0, 0.0)
	for i in 120:
		s.bubble(s.rng.randf_range(0.0, LOOP), s.rng.randf_range(0.4, 2.0), s.rng.randf_range(0.05, 0.25))
	s.make_loop(1.0)
	_done(s, "amb_bile", true, 0.6)
	# Bruise / the deep: a low moan of wind, swelling and falling.
	s = Synth.new(LOOP + 1.0, 43)
	for k in 6:
		var a: float = k * (LOOP / 6.0)
		s.noise(a, a + 4.0, 0.5, 220.0 + k * 30, 1.5, 1.0)
	s.tone(0.0, LOOP + 1.0, 55, 52, 0.15, "tri", 0.0, 0.0)
	s.make_loop(1.0)
	_done(s, "amb_bruise", true, 0.6)
	# Bone: thin wind and creaks.
	s = Synth.new(LOOP + 1.0, 44)
	for k in 5:
		var a: float = k * (LOOP / 5.0)
		s.noise(a, a + 4.0, 0.4, 900.0, 1.5, 1.0)
	for i in 6:
		var t: float = s.rng.randf_range(0.0, LOOP)
		s.tone(t, t + 0.5, 300, 260, 0.08, "saw", 0.1, 1.5)
	s.make_loop(1.0)
	_done(s, "amb_bone", true, 0.55)
	# Rot: drips in a damp hollow.
	s = Synth.new(LOOP + 1.0, 45)
	s.noise(0.0, LOOP + 1.0, 0.12, 300.0, 0.0, 0.0)
	for i in 40:
		s.drip(s.rng.randf_range(0.0, LOOP), s.rng.randf_range(0.1, 0.35), s.rng.randf_range(0.7, 1.3))
	s.make_loop(1.0)
	_done(s, "amb_rot", true, 0.55)
	# A settlement: people murmuring, a word now and then.
	s = Synth.new(LOOP + 1.0, 46)
	for i in 60:
		var t: float = s.rng.randf_range(0.0, LOOP)
		var f: float = s.rng.randf_range(110, 210)
		s.tone(t, t + s.rng.randf_range(0.15, 0.4), f, f * s.rng.randf_range(0.85, 1.15), 0.12, "tri", 0.03, 1.2)
	s.noise(0.0, LOOP + 1.0, 0.12, 600.0, 0.0, 0.0)
	s.soften(1200.0)
	s.make_loop(1.0)
	_done(s, "amb_settlement", true, 0.5)
	# The boss: a dissonant throb.
	s = Synth.new(LOOP + 1.0, 47)
	for k in 3:
		s.tone(0.0, LOOP + 1.0, 55 * pow(1.06, k), 55 * pow(1.06, k), 0.25, "saw", 0.0, 0.0)
	var pulse := 0.0
	while pulse < LOOP:
		s.heartbeat(pulse, 0.8, 1.3)
		pulse += 60.0 / 96.0
	s.soften(1500.0)
	s.make_loop(1.0)
	_done(s, "amb_boss", true, 0.7)
	# Alveolus (the Lungs, week 47): slow breaths through sponge, crackling.
	s = Synth.new(LOOP + 1.0, 48)
	for k in 3:
		var a: float = k * (LOOP / 3.0)
		s.noise(a, a + 2.0, 0.55, 700.0, 1.6, 0.4)  # In...
		s.noise(a + 2.0, a + 4.0, 0.4, 450.0, 0.3, 1.4)  # ...and out.
	for i in 50:
		s.bubble(s.rng.randf_range(0.0, LOOP), s.rng.randf_range(0.2, 0.5), s.rng.randf_range(0.03, 0.08))
	s.make_loop(1.0)
	_done(s, "amb_alveolus", true, 0.55)
	# Cartilage: wind whistling down ringed pipes.
	s = Synth.new(LOOP + 1.0, 49)
	s.noise(0.0, LOOP + 1.0, 0.2, 1500.0, 0.0, 0.0)
	for k in 4:
		var a: float = k * (LOOP / 4.0)
		var f: float = [330.0, 392.0, 294.0, 349.0][k]
		s.tone(a, a + 3.5, f, f * 0.97, 0.08, "sine", 1.2, 1.2)
		s.tone(a, a + 3.5, f * 2.01, f * 1.95, 0.03, "sine", 1.2, 1.2)
	s.make_loop(1.0)
	_done(s, "amb_cartilage", true, 0.5)
