class_name HeartRoot
extends Area2D
## A heart-root (week 34, D-027): a root of the god's still-warm flesh that
## drinks ichor. Pour in what the host carries to bank it for good, and buy
## Boons with what is banked. Put one under Entities in world.tscn, origin
## on the floor. `keeper` = the faction tending it (the Choir's altar): they
## will not let a host they are hostile to near it, and are pleased by every
## offering. Empty = a wild root anyone can use.

const DIALOGUE := preload("res://data/dialogue/heart_root.dialogue")

@export var keeper: StringName

var _time := 0.0


func _ready() -> void:
	$Prompt.visible = false
	body_entered.connect(func(body): if body is Player: _show_prompt(true))
	body_exited.connect(func(body): if body is Player: _show_prompt(false))


func _process(delta: float) -> void:
	_time += delta
	# A slow heartbeat: two quick swells, then a rest.
	var beat := fmod(_time, 1.6)
	var swell := exp(-pow((beat - 0.1) * 12.0, 2.0)) + 0.6 * exp(-pow((beat - 0.38) * 12.0, 2.0))
	$Visual.scale = Vector2.ONE * (1.0 + 0.05 * swell)
	$Light.energy = 0.8 + 0.6 * swell


func interact() -> void:
	var talk := RootTalk.new(WorldState.data, keeper)
	talk.changed.connect(func(): EventBus.ichor_changed.emit())
	talk.boon_bought.connect(func(id): EventBus.boon_bought.emit(id))
	talk.standing_message_ready.connect(func(text): EventBus.notify.emit(text))
	Conversation.open(self, DIALOGUE, talk)
	Sfx.play(&"eat")


func _show_prompt(on: bool) -> void:
	$Prompt.visible = on
	$Prompt.text = "E: the Choir's heart-root" if keeper != &"" else "E: a heart-root"
