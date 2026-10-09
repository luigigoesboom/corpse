class_name Corpse
extends Area2D
## A dead host's body lying in the world. Only a view of a LifeRecord
## (WorldData.lives[life_index]): drawn in its death pose with the mutations
## still on it. Press E near it to search it (CorpseLayer does the taking).

var life_index := -1
var _layer_ids: Array[StringName] = []

@onready var _sprite: LayeredSprite = $Visual/Sprite
@onready var _prompt: Label = $Prompt


func _ready() -> void:
	_prompt.visible = false
	body_entered.connect(func(body): if body is Player: _prompt.visible = true)
	body_exited.connect(func(body): if body is Player: _prompt.visible = false)


## Called by CorpseLayer before adding it to the tree.
func setup(index: int, life: LifeRecord) -> void:
	life_index = index
	position = life.corpse_position
	$Visual/Sprite.body_frames_dir = "res://assets/art/hosts/%s" % life.host_type


## Shows what is still on the body. Call after it is in the tree.
func refresh(life: LifeRecord) -> void:
	for id in _layer_ids:
		_sprite.remove_layer(id)
	_layer_ids.clear()
	for slot in life.corpse_mutations:
		var def := MutationDb.get_def(life.corpse_mutations[slot])
		if def and def.part_frames_dir != "":
			_sprite.add_layer(def.id, SpriteSheets.load_dir(def.part_frames_dir), def.part_behind)
			_layer_ids.append(def.id)
	_sprite.hold_last_frame(&"die")
	if life.has_corpse_loot():
		_prompt.text = "E: search the body of %s" % life.host_name
	else:
		_prompt.text = "The empty body of %s" % life.host_name


func interact() -> void:
	EventBus.corpse_search_requested.emit(life_index)
