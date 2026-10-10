class_name Conversation
extends RefCounted
## Starts a conversation (week 30): a Talk for the speaker, shown in the
## DialogueBalloon with data/dialogue/resident.dialogue. The balloon pauses
## the game until the conversation ends.

const BALLOON := preload("res://src/dialogue/dialogue_balloon.tscn")
const RESIDENT := preload("res://data/dialogue/resident.dialogue")


## `speaker` is the node talking (for the scene tree). The balloon goes on
## the root, not Dialogue Manager's "current scene", so it works wherever
## the game runs.
static func start(speaker: Node, speaker_name: String, faction_id: StringName, rng_seed: int) -> Talk:
	var talk := Talk.new(WorldState.data, speaker_name, faction_id, rng_seed)
	talk.traded.connect(func():
		EventBus.inventory_changed.emit()
		Sfx.play(&"pickup")
		if talk.standing_message != "":
			EventBus.notify.emit(talk.standing_message))
	var balloon: DialogueBalloon = BALLOON.instantiate()
	speaker.get_tree().root.add_child(balloon)
	balloon.start(RESIDENT, "start", [talk])
	return talk
