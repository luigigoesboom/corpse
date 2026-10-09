class_name MutationDef
extends Resource
## One mutation: a body part that grows into a slot on the host, plus an
## ability. Make one .tres per mutation in data/mutations/. Saves store only
## `id`; an item grants a mutation through ItemDef.grants_mutation.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Body slot it grows into. One mutation per slot; a new one replaces the old.
@export_enum("head", "mouth", "back", "arm", "belly") var slot: String = "mouth"
## A script extending MutationAbility, or empty for a purely cosmetic part.
@export var ability: Script
## How to use it, shown on the HUD (e.g. "K").
@export var control_hint := ""

@export_group("Placeholder look")
## Until mutation art exists: a polygon drawn at the slot's socket, pointing right.
@export var part_color := Color.WHITE
@export var part_polygon := PackedVector2Array()
