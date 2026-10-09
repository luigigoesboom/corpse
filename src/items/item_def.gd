class_name ItemDef
extends Resource
## One kind of item. Make a new .tres in data/items/ per kind (right-click the
## folder > Create New > Resource > ItemDef). Saves only store `id`; everything
## else is looked up here, so you can rename or rebalance items without
## breaking saves.

@export var id: StringName
@export var display_name := ""
@export_multiline var description := ""
## Placeholder look until item art exists.
@export var color := Color.WHITE
## Eating it grows this mutation (MutationDef id). Empty = not edible.
@export var grants_mutation: StringName
