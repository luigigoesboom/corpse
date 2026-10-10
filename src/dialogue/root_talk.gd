class_name RootTalk
extends RefCounted
## What a heart-root "says" (week 34, D-027), read by
## data/dialogue/heart_root.dialogue the same way resident.dialogue reads
## Talk. Plain: changes WorldData and emits signals, so it can be tested
## without the UI.

signal changed
signal poured(amount: int)
signal boon_bought(id: StringName)
signal standing_message_ready(text: String)

## Offering this much ichor at a tended root moves its keepers by 1.
const ICHOR_PER_STANDING := 5
## Most one offering can move them.
const MAX_STANDING_PER_OFFERING := 15

var root := "Heart-root"
var intro := ""
## The keepers will not let you near it.
var refused := false
var refusal := ""
var bank_text := ""
var bought_text := ""

var _data: WorldData
var _keeper: StringName


func _init(data: WorldData, keeper: StringName) -> void:
	_data = data
	_keeper = keeper
	if keeper != &"":
		var who := EventText._faction(data, keeper)
		root = "The %s altar" % who.trim_prefix("the ")
		intro = "A root of the god's flesh, ringed with candles. %s tend it. It is warm, and it drinks." % _capital(who)
		refused = Standing.tier(data.standing(keeper)) == Standing.HOSTILE
		refusal = "%s stand between you and the root. Not you. Not with that blood on you." % _capital(who)
	else:
		intro = "A root of the god's flesh breaks through the floor, still warm. It beats, slowly. It drinks."


var carried: int:
	get: return _data.ichor

var banked: int:
	get: return _data.ichor_banked

var status: String:
	get:
		var text := "You carry %d ichor. The fragment has banked %d." % [carried, banked]
		var owned := Boons.ORDER.filter(func(id): return _data.has_boon(id))
		if not owned.is_empty():
			text += " It already has: %s." % ", ".join(owned.map(func(id): return Boons.display_name(id).to_lower()))
		return text


## Pours everything carried into the bank.
func bank() -> void:
	var amount := _data.bank_ichor()
	if amount > 0:
		poured.emit(amount)
	bank_text = "The root drinks %d ichor. Something in you grows heavier, and stays." % amount if amount > 0 else "You have nothing to give it."
	if _keeper != &"" and amount > 0:
		var life := _data.current_life()
		if life:
			life.offerings[_keeper] = int(life.offerings.get(_keeper, 0)) + amount
		var changes := _data.record_deed(_keeper, mini(amount / ICHOR_PER_STANDING, MAX_STANDING_PER_OFFERING))
		for faction in changes:
			var message := Standing.change_message(EventText._faction(_data, faction), changes[faction])
			if message != "":
				standing_message_ready.emit(message)
	changed.emit()


func can_buy(id: String) -> bool:
	var boon := StringName(id)
	return not _data.has_boon(boon) and _data.ichor_banked >= Boons.cost(boon)


func offer(id: String) -> String:
	var boon := StringName(id)
	return "%s (%d): %s" % [Boons.display_name(boon), Boons.cost(boon), Boons.ALL[boon].text]


func buy(id: String) -> void:
	var boon := StringName(id)
	if _data.buy_boon(boon):
		bought_text = "The root gives back what you paid, changed. %s." % Boons.display_name(boon)
		boon_bought.emit(boon)
		changed.emit()
	else:
		bought_text = "The root does not answer."


static func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)
