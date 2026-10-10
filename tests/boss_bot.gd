extends RefCounted
## A bot that fights the Gullet Matron like a decent player would (used by
## test_boss.gd to check the fight is fair and winnable): it reads her
## telegraphs and the hazards on the floor, dodges or jumps through attacks,
## and hits her when she rests. `careless` = never dodges, just walks up and
## swings (should lose).

const LUNGE := 1
const VOLLEY := 2
const SLAM := 3
const SWEEP := 4
const WINDUP := 3
const ACTIVE := 4
const RECOVER := 5
const STAGGER := 6
const STALK := 2

var careless := false
var hits_dealt := 0
var _held := {}
## action -> frames left: a tap is held for two physics frames, like a
## finger, then rests a few frames before it can be pressed again.
var _taps := {}
var _rest := {}
var _volley_escape := 0.0
var _last_state := -1


func tick(boss: Node2D, player: Node2D, arena: Node) -> void:
	for action in _taps.keys():
		_taps[action] -= 1
		if _taps[action] <= 0:
			Input.action_release(action)
			_taps.erase(action)
			_rest[action] = 4
	for action in _rest.keys():
		_rest[action] -= 1
		if _rest[action] <= 0:
			_rest.erase(action)
	var want := 0.0  # -1 left, 1 right, 0 stay.
	var dx: float = boss.global_position.x - player.global_position.x
	var toward := signf(dx) if dx != 0.0 else 1.0
	var dist := absf(dx)
	var new_state: bool = boss.state != _last_state
	_last_state = boss.state

	if careless:
		want = toward if dist > 60.0 else 0.0
		if dist < 90.0:
			_face_and(player, toward, "attack")
		_move(want)
		return

	var hazards: Array = boss.get_parent().get_children()  # Her globs, puddles, ripples spawn beside her.
	# 1. Ripples on the floor: jump them.
	for node in hazards:
		if node.has_method("_physics_process") and "direction" in node and "maker_hurtbox" in node:
			var wdx: float = player.global_position.x - node.global_position.x
			if signf(wdx) == node.direction and absf(wdx) < 70.0 and player.is_on_floor():
				_tap("jump")
	# 2. Standing in burning bile: step out, away from her.
	var in_bile := false
	var bile_ahead := 0.0  # Direction of a puddle right in front of us.
	for node in hazards:
		if node.has_method("is_bile_puddle"):
			var pdx: float = node.global_position.x - player.global_position.x
			if absf(pdx) < 34.0:
				in_bile = true
			elif absf(pdx) < 70.0:
				bile_ahead = signf(pdx)

	match boss.state:
		WINDUP:
			match boss.attack:
				LUNGE:
					want = -toward if dist < 200.0 else 0.0
				SLAM:
					want = _away_from_marker(boss, player)
				SWEEP:
					want = -toward
					if boss.telegraph_left() < 0.2 and dist < 170.0 and player.is_on_floor():
						_tap("jump")
				VOLLEY:
					want = 0.0
				_:
					want = -toward if dist < 120.0 else 0.0
		ACTIVE:
			match boss.attack:
				LUNGE:
					if dist < 150.0 and signf(-dx) == signf(boss.velocity.x) and player.is_on_floor():
						want = toward  # Push towards her and roll: straight through her mouth.
						_face_and(player, toward, "dodge")
					else:
						want = -toward
				VOLLEY:
					if new_state:
						_volley_escape = 0.8
				SLAM:
					want = _away_from_marker(boss, player)
				SWEEP:
					want = -toward
				_:
					want = -toward if dist < 120.0 else 0.0
		RECOVER, STAGGER:
			want = toward if dist > 70.0 else 0.0
			if dist < 95.0:
				_face_and(player, toward, "attack")
		_:
			# Stalking: keep a little way off, spit acid now and then.
			want = -toward if dist < 140.0 else (toward if dist > 260.0 else 0.0)
			if dist < 400.0 and randf() < 0.05:
				_face_and(player, toward, "ability_mouth")
	if _volley_escape > 0.0:
		_volley_escape -= 1.0 / 60.0
		want = toward if dist > 70.0 else -toward  # Run under the arc, towards her.
	# Watch the bile: where globs will land and where puddles lie. If the
	# floor under us is (about to be) burning, go to the nearest safe spot.
	var danger: Array[float] = []
	var feet_y: float = player.global_position.y + 26.0
	for node in hazards:
		if node.has_method("is_bile_puddle"):
			danger.append(node.global_position.x)
		elif "thrower_hurtbox" in node:
			var t := _time_to_floor(node.global_position.y, node.velocity.y, feet_y)
			if t >= 0.0:
				danger.append(node.global_position.x + node.velocity.x * t)
	if _unsafe(player.global_position.x, danger) and not (boss.state == ACTIVE and boss.attack == LUNGE):
		var safe := _nearest_safe(player.global_position.x, danger)
		if absf(safe - player.global_position.x) > 4.0:
			want = signf(safe - player.global_position.x)
	if in_bile and want == 0.0:
		want = -toward
	# Do not walk into burning floor: hop over it, or wait.
	var here: float = player.global_position.x
	if want != 0.0 and not _unsafe(here, danger) and _unsafe(here + want * 28.0, danger):
		if player.is_on_floor() and not _unsafe(here + want * 150.0, danger):
			_tap("jump")
		else:
			want = 0.0
	# A slam coming down outranks everything: get out from under it.
	if boss.attack == SLAM and boss.state in [WINDUP, ACTIVE]:
		var escape := _away_from_marker(boss, player)
		if escape != 0.0:
			want = escape
	if bile_ahead != 0.0 and want == bile_ahead and player.is_on_floor():
		_tap("jump")  # Hop over the puddle instead of wading through it.
	# Leeches from her brood that get close: cut them down.
	for node in arena.get_node("Enemies").get_children():
		if node != boss and node.name.begins_with("MatronBrood") and is_instance_valid(node):
			var ldx: float = node.global_position.x - player.global_position.x
			if absf(ldx) < 70.0 and boss.state != ACTIVE:
				_face_and(player, signf(ldx), "attack")
	_move(want)


func release_all() -> void:
	for action in ["move_left", "move_right", "jump", "attack", "dodge", "ability_mouth"]:
		Input.action_release(action)


func _move(direction: float) -> void:
	_hold("move_right", direction > 0.0)
	_hold("move_left", direction < 0.0)


func _hold(action: String, on: bool) -> void:
	if on and not _held.get(action, false):
		Input.action_press(action)
	elif not on and _held.get(action, false):
		Input.action_release(action)
	_held[action] = on


func _tap(action: String) -> void:
	if _taps.has(action) or _rest.has(action):
		return
	Input.action_press(action)
	_taps[action] = 2


func _face_and(player: Node2D, direction: float, action: String) -> void:
	if _taps.has(action) or _rest.has(action):
		return
	player._facing = direction
	_tap(action)
	if action == "attack":
		hits_dealt += 1


## Seconds until something at `y` falling with `vy` (gravity 650) reaches `floor_y`.
func _time_to_floor(y: float, vy: float, floor_y: float) -> float:
	var a := 0.5 * 650.0
	var c := y - floor_y
	var disc := vy * vy - 4.0 * a * c
	if disc < 0.0:
		return -1.0
	return (-vy + sqrt(disc)) / (2.0 * a)


func _unsafe(x: float, danger: Array[float]) -> bool:
	for d in danger:
		if absf(d - x) < 40.0:
			return true
	return false


func _nearest_safe(x: float, danger: Array[float]) -> float:
	for step in range(0, 400, 8):
		for candidate in [x + step, x - step]:
			if candidate > 60.0 and candidate < 1150.0 and not _unsafe(candidate, danger):
				return candidate
	return x


## Off the slam marker, towards the side with more room (never into a wall).
func _away_from_marker(boss: Node2D, player: Node2D) -> float:
	var marker: Node2D = boss.get_node("SlamMarker")
	if not marker.visible:
		return 0.0
	var mdx: float = player.global_position.x - marker.global_position.x
	if absf(mdx) > 150.0:
		return 0.0
	var room_right: float = 1180.0 - marker.global_position.x
	var room_left: float = marker.global_position.x - 40.0
	return 1.0 if room_right > room_left else -1.0
