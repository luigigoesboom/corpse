extends SceneTree
## The art program's entry point (D-028). From the project folder:
##
##   Godot --headless --path . --script res://tools/pixel/run.gd -- <recipe> [<recipe> ...] [--preview]
##
## Each recipe is tools/pixel/recipes/<name>.gd with
##   static func make(pal, out: Array) -> void
## which writes its PNGs into the project and appends {"name", "body",
## "glow"} for the preview. "all" runs every recipe. --preview writes a
## contact sheet per recipe to tools/pixel/preview/<name>.png (gitignored; prints
## where that is) without needing the game.

const Palette := preload("res://tools/pixel/palette.gd")
const Sheet := preload("res://tools/pixel/sheet.gd")
const RECIPES := "res://tools/pixel/recipes/"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var preview := "--preview" in args
	var names := Array(args).filter(func(a): return not a.begins_with("--"))
	if names.is_empty() or "all" in names:
		names = Array(DirAccess.get_files_at(RECIPES)).filter(func(f): return f.ends_with(".gd")).map(func(f): return f.get_basename())
	var pal = Palette.load_default()
	for name in names:
		var recipe = load(RECIPES + name + ".gd")
		if recipe == null:
			push_error("no recipe %s" % name)
			continue
		var out := []
		var started := Time.get_ticks_msec()
		recipe.make(pal, out)
		print("%s: %d images in %d ms" % [name, out.size(), Time.get_ticks_msec() - started])
		if preview and not out.is_empty():
			var path := "res://tools/pixel/preview/%s.png" % name
			Sheet.save(Sheet.preview(out), path)
			print("  preview: ", ProjectSettings.globalize_path(path))
	quit()
