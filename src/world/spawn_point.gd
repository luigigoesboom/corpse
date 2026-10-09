@tool
class_name SpawnPoint
extends Marker2D
## A place a new host can wake (week 24). Put these under SpawnPoints in
## scenes/world.tscn, just above a floor. The rebirth screen offers a few of
## them, each with a host type from `host_types`.

@export var place_name := "Somewhere"
## HostDef ids that can wake here. Empty = any.
@export var host_types: Array[StringName] = []


func _ready() -> void:
	gizmo_extents = 24.0


func allows(host_type: StringName) -> bool:
	return host_types.is_empty() or host_type in host_types
