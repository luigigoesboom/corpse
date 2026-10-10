extends SceneTree
## Starts a new creature (week 45): its look, its scene and its AI, all
## working, so the afternoon goes into making it good instead of wiring.
##
##   Godot --headless --path . --script res://tools/creature/new_creature.gd -- <kind> <behaviour> [--size 48]
##
## <kind> is snake_case (puffsac, cilia_lasher). <behaviour> is one of
##   walker   walks the floor, chases, lunges        (like the Gut Leech)
##   flyer    hovers, stalks from above, dives      (like the Rot Fly)
##   floater  drifts slowly toward you, lashes out
##   rooted   stays put, strikes what comes in reach
## It writes, and never overwrites:
##   tools/pixel/recipes/creature_<kind>.gd   its look (a placeholder body from the kit)
##   src/actors/creatures/<kind>.gd           its AI (extends Creature; a full state machine to edit)
##   src/actors/creatures/<kind>.tscn         its scene (health, hurtbox, hitboxes, sprite, sight)
## then draws the placeholder frames. Afterwards: run `--import` once so
## Godot sees the new PNGs, and follow the checklist it prints.

const Palette := preload("res://tools/pixel/palette.gd")
const BEHAVIOURS := ["walker", "flyer", "floater", "rooted"]
const TEMPLATES := "res://tools/creature/templates/"


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var size := 48
	var at := args.find("--size")
	if at >= 0 and at + 1 < args.size():
		size = int(args[at + 1])
		args.remove_at(at + 1)
		args.remove_at(at)
	if args.size() < 2 or not args[1] in BEHAVIOURS or not _is_snake(args[0]):
		printerr("usage: -- <kind in snake_case> <%s> [--size 48]" % " | ".join(BEHAVIOURS))
		quit(1)
		return
	var err := make(args[0], args[1], size)
	quit(0 if err == OK else 1)


## Writes the three files and draws the frames. Also used by the tests
## (with a throwaway kind they remove afterwards).
static func make(kind: String, behaviour: String, size := 48) -> Error:
	var node_name := kind.to_pascal_case()
	var title := " ".join(Array(kind.split("_")).map(func(w): return w.capitalize()))
	var files := {
		"res://tools/pixel/recipes/creature_%s.gd" % kind: _fill(_read("recipe"), kind, title, size, behaviour),
		"res://src/actors/creatures/%s.gd" % kind: _fill(_read(behaviour), kind, title, size, behaviour),
		"res://src/actors/creatures/%s.tscn" % kind: scene_text(kind, node_name, behaviour, size),
	}
	for path in files:
		if FileAccess.file_exists(path):
			printerr("%s exists already; nothing written." % path)
			return ERR_ALREADY_EXISTS
	for path in files:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(files[path])
		file.close()
		print("wrote ", path)
	var recipe: GDScript = load("res://tools/pixel/recipes/creature_%s.gd" % kind)
	var out := []
	recipe.make(Palette.load_default(), out)
	print("drew %d animations into assets/art/creatures/%s" % [out.size(), kind])
	print("""
Next:
  1. Godot --headless --path . --import          (so the game sees the new frames)
  2. Draw it: tools/pixel/recipes/creature_%s.gd, then run.gd -- creature_%s --preview --gif
  3. Tune its AI: src/actors/creatures/%s.gd (speeds, ranges, health in the scene)
  4. Ichor for killing it: Ichor.CREATURE_VALUES[&"%s"]
  5. Place it under Entities in scenes/world.tscn (it returns between lives on its own)
  6. Sounds: Sfx.play(&"...") in its states, if the stock ones do not fit""" % [kind, kind, kind, kind])
	return OK


static func _is_snake(s: String) -> bool:
	return RegEx.create_from_string("^[a-z][a-z0-9_]*$").search(s) != null


static func _read(template: String) -> String:
	return FileAccess.get_file_as_string(TEMPLATES + template + ".txt")


static func _fill(text: String, kind: String, title: String, size: int, behaviour: String) -> String:
	var anchor := "centred on the frame" if behaviour in ["flyer", "floater"] else "standing on the bottom edge"
	return text.replace("{{kind}}", kind).replace("{{title}}", title).replace("{{size}}", str(size)).replace("{{anchor}}", anchor)


## The scene: a CharacterBody2D on the enemies layer with the nodes Creature
## expects. Walkers and rooted things stand on their origin; flyers and
## floaters are centred on it and do not fall.
static func scene_text(kind: String, name: String, behaviour: String, size: int) -> String:
	var flies := behaviour in ["flyer", "floater"]
	var half := size / 2
	var body_y := 0 if flies else -int(size * 0.22)
	var lines := PackedStringArray()
	lines.append("[gd_scene format=3]\n")
	lines.append('[ext_resource type="Script" path="res://src/actors/creatures/%s.gd" id="1_script"]' % kind)
	lines.append('[ext_resource type="Script" path="res://src/actors/components/health.gd" id="2_health"]')
	lines.append('[ext_resource type="Script" path="res://src/actors/components/hurtbox.gd" id="3_hurtbox"]')
	lines.append('[ext_resource type="Script" path="res://src/actors/components/hitbox.gd" id="4_hitbox"]')
	lines.append('[ext_resource type="Script" path="res://src/actors/components/layered_sprite.gd" id="5_sprite"]')
	lines.append('[ext_resource type="Script" path="res://src/actors/components/ground_shadow.gd" id="6_shadow"]\n')
	if flies:
		lines.append('[sub_resource type="CircleShape2D" id="body"]\nradius = %.1f\n' % (size * 0.2))
		lines.append('[sub_resource type="CircleShape2D" id="hurt"]\nradius = %.1f\n' % (size * 0.28))
		lines.append('[sub_resource type="CircleShape2D" id="contact"]\nradius = %.1f\n' % (size * 0.18))
		lines.append('[sub_resource type="CircleShape2D" id="attack"]\nradius = %.1f\n' % (size * 0.3))
	else:
		lines.append('[sub_resource type="RectangleShape2D" id="body"]\nsize = Vector2(%d, %d)\n' % [int(size * 0.6), int(size * 0.44)])
		lines.append('[sub_resource type="RectangleShape2D" id="hurt"]\nsize = Vector2(%d, %d)\n' % [int(size * 0.7), int(size * 0.55)])
		lines.append('[sub_resource type="RectangleShape2D" id="contact"]\nsize = Vector2(%d, %d)\n' % [int(size * 0.5), int(size * 0.3)])
		lines.append('[sub_resource type="RectangleShape2D" id="attack"]\nsize = Vector2(%d, %d)\n' % [int(size * 0.5), int(size * 0.4)])
	lines.append('[node name="%s" type="CharacterBody2D"]\ncollision_layer = 8\ncollision_mask = 1%s\nscript = ExtResource("1_script")%s\n' % [
		name, "\nmotion_mode = 1" if flies else "", "\ngravity = 0.0" if flies else ""])
	lines.append('[node name="Shadow" type="Node2D" parent="."]\nscript = ExtResource("6_shadow")\nwidth = %.1f\n' % (size * 0.6))
	lines.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="."]\nposition = Vector2(0, %d)\nshape = SubResource("body")\n' % body_y)
	lines.append('[node name="Visual" type="Node2D" parent="."]\n')
	lines.append('[node name="Sprite" type="Node2D" parent="Visual"]\nscript = ExtResource("5_sprite")\nbody_frames_dir = "res://assets/art/creatures/%s"\nglow_frames_dir = "res://assets/art/creatures/%s/glow"\nframe_offset = Vector2(0, %d)\n' % [kind, kind, 0 if flies else -half])
	lines.append('[node name="Attack" type="Area2D" parent="Visual"]\nposition = Vector2(%d, %d)\ncollision_layer = 32\ncollision_mask = 0\nscript = ExtResource("4_hitbox")\nknockback = 300.0\n' % [0 if behaviour == "floater" else int(size * 0.45), body_y])
	lines.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="Visual/Attack"]\nshape = SubResource("attack")\n')
	if behaviour == "walker":
		lines.append('[node name="LedgeCheck" type="RayCast2D" parent="Visual"]\nposition = Vector2(%d, -4)\ntarget_position = Vector2(0, 20)\n' % int(size * 0.4))
	lines.append('[node name="Sight" type="RayCast2D" parent="."]\nposition = Vector2(0, %d)\nenabled = false\ntarget_position = Vector2(100, 0)\n' % body_y)
	lines.append('[node name="Health" type="Node" parent="."]\nscript = ExtResource("2_health")\nmax_health = %d\ninvulnerable_time = 0.05\n' % (2 if flies else 3))
	lines.append('[node name="Hurtbox" type="Area2D" parent="." node_paths=PackedStringArray("health")]\ncollision_layer = 0\ncollision_mask = 16\nscript = ExtResource("3_hurtbox")\nhealth = NodePath("../Health")\n')
	lines.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="Hurtbox"]\nposition = Vector2(0, %d)\nshape = SubResource("hurt")\n' % body_y)
	lines.append('[node name="ContactHitbox" type="Area2D" parent="."]\ncollision_layer = 32\ncollision_mask = 0\nscript = ExtResource("4_hitbox")\nknockback = 240.0\nonce_per_activation = false\n')
	lines.append('[node name="CollisionShape2D" type="CollisionShape2D" parent="ContactHitbox"]\nposition = Vector2(0, %d)\nshape = SubResource("contact")' % body_y)
	return "\n".join(lines) + "\n"
