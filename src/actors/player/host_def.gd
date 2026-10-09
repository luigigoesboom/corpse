class_name HostDef
extends Resource
## One kind of body the player can wake in. One .tres per type in data/hosts/.
## Saves store only `id` (LifeRecord.host_type).

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Folder of the body's frame strips (see SpriteSheets). Hosts that share the
## colonist's poses can use the same mutation overlays.
@export_dir var frames_dir: String
@export var max_health := 5
## Multiplies the player's run speed (1.0 = colonist).
@export var run_speed_scale := 1.0
## What a fresh host of this type starts with (not inherited: D-020).
@export var start_items: Array[StringName] = []
## Body slot -> mutation id, for hosts born with a part.
@export var start_mutations: Dictionary = {}
