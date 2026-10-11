extends CanvasLayer
## Feeds the backdrop shader every frame: where the camera is, how big the
## view is, and a tint for the kind of rock around the camera (D-028), eased
## so walking from flesh into bile slowly turns the back wall green. The
## tints are in RockKinds.

## How fast the tint follows the camera (per second).
const EASE := 1.2

var _kinds: Image
var _tint := Color.WHITE
## 0 = the Gut's walls, 1 = the Lungs' (week 47), eased like the tint.
var lungs := 0.0


func _ready() -> void:
	if FileAccess.file_exists(WorldMap.KINDS_PATH) or ResourceLoader.exists(WorldMap.KINDS_PATH):
		_kinds = WorldMap.read_image(WorldMap.KINDS_PATH)


func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		return
	var centre := camera.get_screen_center_position()
	var material: ShaderMaterial = $Wall.material
	material.set_shader_parameter("camera_position", centre)
	material.set_shader_parameter("screen_size", get_viewport().get_visible_rect().size)
	_tint = _tint.lerp(_target_tint(centre), clampf(delta * EASE, 0.0, 1.0))
	material.set_shader_parameter("tint", Vector3(_tint.r, _tint.g, _tint.b))
	lungs = move_toward(lungs, WorldMap.region_share(centre, Regions.LUNGS), delta * EASE * 0.6)
	material.set_shader_parameter("lungs", lungs)
	material.set_shader_parameter("breath", Breath.strength() * lungs)



## The average tint of the kinds of rock painted around a point.
func _target_tint(at: Vector2) -> Color:
	var weights := WorldMap.kind_weights(_kinds, at)
	var sum := Color(0, 0, 0)
	for k in weights.size():
		sum += RockKinds.tint(ChunkData.KINDS[k]) * weights[k]
	return sum
