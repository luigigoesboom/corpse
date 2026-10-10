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
## `place` and `bribe_cost`: the speaker guards a place and takes bribes (week 36).
static func start(speaker: Node, speaker_name: String, faction_id: StringName, rng_seed: int, place := "", bribe_cost := 0) -> Talk:
	var talk := Talk.new(WorldState.data, speaker_name, faction_id, rng_seed)
	talk.offer_bribe(place, bribe_cost)
	talk.bribed.connect(func():
		EventBus.ichor_changed.emit()
		Sfx.play(&"pickup"))
	talk.traded.connect(func():
		EventBus.inventory_changed.emit()
		Sfx.play(&"pickup")
		if talk.standing_message != "":
			EventBus.notify.emit(talk.standing_message))
	open(speaker, RESIDENT, talk)
	return talk


## Opens any .dialogue with `state` as the object it reads names from
## (heart-roots use RootTalk, week 34).
static func open(speaker: Node, dialogue: Resource, state: Object) -> void:
	var balloon: DialogueBalloon = BALLOON.instantiate()
	speaker.get_tree().root.add_child(balloon)
	balloon.start(dialogue, "start", [state])
