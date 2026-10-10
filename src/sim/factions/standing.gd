class_name Standing
extends RefCounted
## Standing tiers and what people say when one changes (week 31). Numbers
## stay hidden (VISION.md); the player sees the consequences and a line
## like "The Flesh-Tenders will remember that."

const HOSTILE := &"hostile"
const WARY := &"wary"
const NEUTRAL := &"neutral"
const FRIENDLY := &"friendly"
const ORDER := [HOSTILE, WARY, NEUTRAL, FRIENDLY]


## hostile (< -30): guards attack, no talk; wary (< 0): trades cost double;
## neutral (< 30); friendly: a little extra in trades.
static func tier(value: int) -> StringName:
	if value < -30:
		return HOSTILE
	if value < 0:
		return WARY
	if value < 30:
		return NEUTRAL
	return FRIENDLY


## A message for a tier change, or "" if the tier did not change.
## `people` reads mid-sentence: "the Flesh-Tenders".
static func change_message(people: String, change: Array) -> String:
	if change.size() < 2 or change[0] == change[1] or change[1] == &"":
		return ""
	var up: bool = ORDER.find(change[1]) > ORDER.find(change[0])
	var who := people.substr(0, 1).to_upper() + people.substr(1)
	match change[1]:
		HOSTILE:
			return "%s will remember that." % who
		WARY:
			return ("%s have calmed down, a little." if up else "%s watch you more closely now.") % who
		NEUTRAL:
			return ("%s seem to warm to you." if up else "%s are cooler towards you.") % who
		FRIENDLY:
			return "%s count you as a friend." % who
	return ""
