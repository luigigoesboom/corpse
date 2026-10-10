class_name Talk
extends RefCounted
## One conversation with one NPC (week 30): what data/dialogue/resident.dialogue
## reads and calls. Dialogue Manager sees this object's properties and
## methods by name ({{greeting}}, {{rumor()}}, [if can_trade /], do trade()).
## The words that depend on the world are made here; the shape of the
## conversation is in the .dialogue file, so it can be rewritten freely.
##
## Plain object: it changes WorldData (barter) and says so through `traded`.

## Emitted after a barter changed the pockets.
signal traded

## Speaker's name, shown as the speaking character.
var npc := ""
## The speaker's people as they read mid-sentence ("the Flesh-Tenders"), or "".
var people := ""
var greeting := ""
var farewell := ""
var creed := ""
## How the speaker's people feel about this host, -100..100 (week 31).
var standing := 0
## Message for a standing tier change caused by this talk (a trade), or "".
var standing_message := ""
var hostile := false
## A fragment-sensing speaker knows you from an earlier body (week 32), and says so.
var recognized := false
var recognition := ""
var can_trade := false
var has_payment := false
var offer_text := ""
var trade_done_text := ""
## Bribes (week 36): the speaker guards a place you are kept out of (a guard
## post, or a settlement hostile to you), and would look away for ichor.
signal bribed
var offers_bribe := false
var bribe_cost := 0
var bribe_text := ""
## The heart-key (week 38): this speaker's people keep the Gut's key.
var key_here := false
var key_price := ValveKeys.CHOIR_PRICE
var key_text := ""
signal key_changed

var can_ask_key: bool:
	get: return key_here and Standing.tier(standing) == Standing.FRIENDLY

var can_buy_key: bool:
	get: return key_here and not hostile and _data.ichor >= key_price


## They trust you: they give it.
func ask_key() -> void:
	if not can_ask_key or not ValveKeys.take(_data, ValveKeys.GUT, ValveKeys.CHOIR_RELIQUARY):
		key_text = "Not now." if can_ask_key else "The key is not for you."
		return
	key_here = false
	key_text = "It has waited for you. Take it to the heart, and do not lose it again."
	_data.log_deed(&"key_given", [_faction, _host_name()], {"key": ValveKeys.GUT})
	key_changed.emit()


## They do not trust you, but ichor is the god's own blood.
func buy_key() -> void:
	if not can_buy_key or not ValveKeys.take(_data, ValveKeys.GUT, ValveKeys.CHOIR_RELIQUARY):
		key_text = "No."
		return
	_data.add_ichor(-key_price)
	key_here = false
	key_text = "The god's blood for the god's key. A fair price, they say. I am not sure."
	_data.log_deed(&"key_bought", [_faction, _host_name()], {"key": ValveKeys.GUT, "ichor": key_price})
	key_changed.emit()


func _host_name() -> String:
	var life := _data.current_life()
	return life.host_name if life else "a stranger"


var halt_text: String:
	get: return "You are not one of the faithful. You do not pass." if not hostile else "You should not be here. Give me a reason not to call the others."
## Key of the guarded place (a GuardPost's entity key, or a site id).
var place := ""

var _data: WorldData
var _faction: StringName
var _def: FactionDef
var _rng: RandomNumberGenerator
var _told: Array = []
var _give: StringName
var _take: Array[StringName] = []
## Items they ask per ware: 2 when wary.
var _price := 1


func _init(data: WorldData, speaker_name: String, faction_id: StringName, rng_seed: int) -> void:
	_data = data
	_faction = faction_id
	_def = FactionDb.get_def(faction_id) if faction_id != &"" else null
	_rng = RandomNumberGenerator.new()
	_rng.seed = rng_seed
	npc = speaker_name
	people = EventText._faction(data, faction_id) if faction_id != &"" else ""
	standing = data.standing(faction_id) if faction_id != &"" else 0
	hostile = Standing.tier(standing) == Standing.HOSTILE
	if _def and _def.senses_fragment >= 0.5:
		recognition = Legend.recognition(data, faction_id)
		recognized = recognition != ""
	greeting = _pick(_greetings(), "Hm.")
	farewell = _pick(_def.farewells if _def else [], "Go well.")
	creed = _creed()
	_set_up_barter()
	key_here = faction_id == &"choir_of_waking" and ValveKeys.lies_at(data, ValveKeys.GUT, ValveKeys.CHOIR_RELIQUARY)


## Sets up a bribe for the place this speaker guards (Conversation calls it).
## `cost` 0 = there is nothing to bribe for.
func offer_bribe(place_key: String, cost: int) -> void:
	place = place_key
	bribe_cost = cost
	offers_bribe = cost > 0 and place_key != "" and _data.current_life() != null and not _data.current_life().bribes.has(place_key)


var can_bribe: bool:
	get: return offers_bribe and _data.ichor >= bribe_cost


func bribe() -> void:
	if not can_bribe:
		bribe_text = "Not for that little."
		return
	_data.add_ichor(-bribe_cost)
	_data.current_life().bribes[place] = true
	offers_bribe = false
	bribe_text = _pick(["I see nothing. Go, and quickly.", "The ichor is the god's. You were never here.", "Fine. I was looking the other way anyway."], "Go.")
	bribed.emit()


## Something that happened, as this speaker would tell it. Never the same
## rumor twice in one conversation.
func rumor() -> String:
	var event := Rumors.pick(_data, _faction, _rng, _told)
	if event == null:
		return "Nothing worth repeating. It's quiet. Too quiet, maybe."
	_told.append(event.id)
	return Rumors.tell(event, _data, _faction, _def.senses_fragment if _def else 0.0)


## Swaps what they want from your pockets for one of their wares (two of
## your things when they are wary of you; friends throw in an extra ware).
## Trading warms them a little.
func trade() -> void:
	if not has_payment:
		return
	for item in _take:
		_data.inventory[_data.inventory.find(item)] = &""
	_data.add_to_inventory(_give)
	trade_done_text = "Done. %s, as promised." % ItemDb.display_name(_give)
	if Standing.tier(standing) == Standing.FRIENDLY and _data.add_to_inventory(_give) >= 0:
		trade_done_text = "Here, take two. For a friend."
	standing_message = Standing.change_message(people, _data.change_standing(_faction, 3))
	standing = _data.standing(_faction)
	_set_up_barter()
	traded.emit()


func told_events() -> Array:
	return _told.duplicate()


func _greetings() -> Array:
	if _def == null:
		return ["...Who's there? Oh. Another one walking.", "I don't belong to anyone. Neither do you, by the look of it."]
	var tier := "friendly"
	if standing < -30:
		tier = "hostile"
	elif standing < 0:
		tier = "wary"
	elif standing < 30:
		tier = "neutral"
	return _def.greetings.get(tier, ["..."])


func _creed() -> String:
	if _def == null:
		return "My people? Gone, or never were. I walk."
	var faction: FactionData = _data.factions.get(_faction)
	var how_many := " There are %d of us now." % faction.strength if faction and faction.is_alive() else ""
	return "%s%s" % [_def.creed, how_many]


## Their first ware for the first thing they want that you carry. Artifacts
## count when they want &"artifact".
func _set_up_barter() -> void:
	can_trade = _def != null and not hostile and not _def.wares.is_empty() and not _def.wants.is_empty()
	has_payment = false
	if not can_trade:
		return
	_give = _def.wares[0]
	_price = 2 if Standing.tier(standing) == Standing.WARY else 1
	_take.clear()
	var wanted := PackedStringArray()
	for want in _def.wants:
		wanted.append("an old relic" if want == &"artifact" else ItemDb.display_name(want))
	for item in _data.inventory:
		if _take.size() >= _price:
			break
		for want in _def.wants:
			if item != &"" and (item == want or (want == &"artifact" and String(item).begins_with("artifact_"))):
				_take.append(item)
				break
	has_payment = _take.size() >= _price
	var asking := " and ".join(_take.map(func(item): return ItemDb.display_name(item)))
	if has_payment and _price == 2:
		offer_text = "From you? Two things: your %s. For a %s." % [asking, ItemDb.display_name(_give)]
	elif has_payment:
		offer_text = "Your %s for a %s. Fair?" % [asking, ItemDb.display_name(_give)]
	elif _price == 2:
		offer_text = "We trade %s. From you it costs two of: %s." % [ItemDb.display_name(_give), ", ".join(wanted)]
	else:
		offer_text = "We trade %s. Bring us %s and we'll talk." % [ItemDb.display_name(_give), " or ".join(wanted)]


func _pick(options: Array, fallback: String) -> String:
	return options[_rng.randi() % options.size()] if not options.is_empty() else fallback
