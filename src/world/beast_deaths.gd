class_name BeastDeaths
extends RefCounted
## A legendary beast's creature died in play (D-033; Game calls died()).
## By the host's hand it is a famous deed (Legend.FAMOUS): logged, the
## peoples it raided are grateful, and it leaves a trophy, an artifact whose
## description tells its story (ArtifactText). Anything else that kills it
## (friendly fire, a fall) is only noted.


static func died(data: WorldData, entity: Node, by_player: bool) -> void:
	var beast: BeastData = data.beasts.get(entity.get_meta(&"beast_id"))
	if beast == null or not beast.is_alive():
		return
	if not by_player:
		beast.died_year = data.year
		beast.slain_by = "the body"
		data.log_event(&"beast_died", [], {"beast": beast.id})
		return
	var life := data.current_life()
	var event := Beasts.slain_by_host(data, beast, life.host_name if life else "a host")
	var trophy := Beasts.trophy(data, beast, event)
	Quests.on_beast_slain(data, beast.id)
	ItemDb.refresh_generated(data)
	EventBus.item_drop_requested.emit(StringName(trophy.id), (entity as Node2D).global_position)
	Sfx.play(&"matron_die", (entity as Node2D).global_position)
	EventBus.notify.emit("%s is dead. The body will remember who did it." % beast.full_name())
	for faction in Beasts.raided(data, beast):
		var message := Standing.change_message(EventText._faction(data, faction), data.change_standing(faction, 15))
		if message != "":
			EventBus.notify.emit(message)
