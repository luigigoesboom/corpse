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
## A task was taken or handed in (D-033): pockets and ichor changed.
signal quest_changed

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
## The heart-key (week 38): this speaker's people keep a key (the Choir
## the Gut's, the Bellows-Kin the Lungs', week 51).
var key_here := false
var key_price := ValveKeys.CHOIR_PRICE
var key_text := ""
## What they say about the key they keep.
var key_line := ""
var _key: StringName = &""
const KEY_LINES := {
	&"valve_key_gut": "The key of the Gut's valve. It sleeps in our reliquary until the heart calls for it.",
	&"valve_key_lungs": "The key of the Lungs. We fly it on a string at the top of the roost, where the breath can keep it cold.",
}
signal key_changed

var can_ask_key: bool:
	get: return key_here and Standing.tier(standing) == Standing.FRIENDLY

var can_buy_key: bool:
	get: return key_here and not hostile and _data.ichor >= key_price


## They trust you: they give it.
func ask_key() -> void:
	if not can_ask_key or not ValveKeys.take(_data, _key, ValveKeys.KEYS[_key].kept):
		key_text = "Not now." if can_ask_key else "The key is not for you."
		return
	key_here = false
	key_text = "It has waited for you. Take it to the heart, and do not lose it again."
	_data.log_deed(&"key_given", [_faction, _host_name()], {"key": _key})
	key_changed.emit()


## They do not trust you, but ichor is the god's own blood.
func buy_key() -> void:
	if not can_buy_key or not ValveKeys.take(_data, _key, ValveKeys.KEYS[_key].kept):
		key_text = "No."
		return
	_data.add_ichor(-key_price)
	key_here = false
	key_text = "The god's blood for the god's key. A fair price, they say. I am not sure."
	_data.log_deed(&"key_bought", [_faction, _host_name()], {"key": _key, "ichor": key_price})
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


## How a leader greets you, by their first trait (%s = their name).
const LEADER_GREETINGS := {&"cruel": "I am %s. You have one breath to say why you are here.", &"pious": "%s. The god sees you. So do I.",
	&"greedy": "%s. What have you brought me?", &"wise": "I am %s. Sit, if you like. Most things can wait.",
	&"ambitious": "%s. You look useful. Are you?", &"paranoid": "%s. Who sent you? Do not lie.",
	&"mad": "%s, that is me, and the walls agree. Do you hear them?", &"kind": "I am %s. Have you eaten? Sit.",
	&"brave": "%s. You have the look of someone who goes into the dark. Good.", &"craven": "%s. Keep your voice down. Please."}


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
	var leader := Figures.leader_of(data, faction_id) if faction_id != &"" else null
	if leader and leader.full_name() == speaker_name and not hostile:  # The leader themselves (D-033).
		greeting = LEADER_GREETINGS.get(leader.traits[0], "%s. Speak.") % leader.name
	farewell = _pick(_def.farewells if _def else [], "Go well.")
	creed = _creed()
	_set_up_barter()
	_key = ValveKeys.kept_by(data, faction_id) if faction_id != &"" else &""
	key_here = _key != &""
	key_price = ValveKeys.price_of(_key)
	key_line = KEY_LINES.get(_key, "")
	_set_up_work()


# --- Work (D-033) ---------------------------------------------------------------

## A task they would give, or the one you carry for them.
var has_work := false
var work_text := ""
var accept_text := ""
## Something to hand in here: their task done, or a gift you carry for them.
var can_turn_in := false
var turn_in_text := ""
## Whether the task they would give is already yours.
var work_taken := false
var _offer: QuestData
var _turn_in: QuestData


func _set_up_work() -> void:
	has_work = false
	can_turn_in = false
	work_taken = false
	if _faction == &"" or _def == null or hostile:
		return
	var open := Quests.open_from(_data, _faction)
	_turn_in = Quests.delivery_for(_data, _faction)
	if _turn_in == null and open and Quests.ready(_data, open):
		_turn_in = open
	can_turn_in = _turn_in != null
	_offer = Quests.offer(_data, _faction, _rng.randi())
	work_taken = _offer != null and _data.quests.has(_offer.id)
	has_work = _offer != null and not (work_taken and _turn_in == _offer)
	if _offer == null:
		work_text = ""
	elif work_taken:
		var summary := Quests.summary(_data, _offer)
		work_text = "You still have our task. " + summary
	else:
		work_text = Quests.ask_text(_data, _offer)


## Takes the task offered.
func accept_work() -> void:
	if _offer == null or _data.quests.has(_offer.id):
		accept_text = "Then go and do it."
		return
	if not Quests.accept(_data, _offer):
		accept_text = "You have no room to carry it. Come back with empty hands."
		return
	accept_text = _pick(["Good. Do not make us wait long.", "Go well. Come back to us.", "We will remember who helped."], "Good.")
	quest_changed.emit()
	_set_up_work()


## Hands in what is ready here.
func turn_in() -> void:
	if _turn_in == null:
		return
	var paid := Quests.turn_in(_data, _turn_in)
	if _turn_in.kind == &"deliver" and _turn_in.target == String(_faction):
		turn_in_text = "From %s? ...We understand. Tell them we accept. Take this for your trouble: %d ichor." % [EventText._faction(_data, _turn_in.giver), paid]
	else:
		turn_in_text = _pick(["It is done, then. Here: %d ichor, and our thanks." % paid, "You did what you said. %d ichor, as promised." % paid], "Thank you.")
	standing = _data.standing(_faction)
	quest_changed.emit()
	_set_up_work()


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
	var leader := Figures.leader_line(_data, _faction, _rng.randi())
	return "%s%s%s" % [_def.creed, how_many, (" " + leader) if leader != "" else ""]


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
