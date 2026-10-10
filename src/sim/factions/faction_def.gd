class_name FactionDef
extends Resource
## What a faction IS, written by hand: one .tres per faction in data/factions.
## What it currently has and thinks (strength, territory, relations) is
## FactionData in WorldData, which history changes over time.

@export var id: StringName
@export var display_name := ""
## One member: "a Flesh-Tender".
@export var member_name := ""
@export_multiline var description := ""
## What they believe, in their own words. Shown in dialogue and murals later.
@export_multiline var creed := ""
## Map color: the territory paint in data/maps/territory.png and the debug map.
@export var color := Color.WHITE
## Belief tags the history sim and dialogue react to (deeds they like or hate).
@export var values: Array[StringName] = []

@export_group("Temperament", "")
## 0..1, how readily they fight over land and slights.
@export_range(0.0, 1.0) var aggression := 0.5
## 0..1, how hungry they are for more territory.
@export_range(0.0, 1.0) var expansion := 0.5
## 0..1, how much the god (and the fragment) matters to them.
@export_range(0.0, 1.0) var piety := 0.5
## 0..1, how willing they are to trade and talk.
@export_range(0.0, 1.0) var trade := 0.5
## 0..1, how directly they sense the fragment across hosts (legend standing,
## VISION.md): priests near 1, farmers near 0.
@export_range(0.0, 1.0) var senses_fragment := 0.0

## What they do with a dead host's body they find (week 33, CorpseFate):
## fate (enshrined, studied, eaten, looted) -> weight.
@export var corpse_fates: Dictionary = {}

@export_group("Settlements", "")
## Strips for the residents of its settlements (idle, run, work).
@export_dir var npc_frames_dir: String
## What a settlement of theirs is built from (SettlementProp scenes). Laid
## out along the floor in a repeatable order per site; props marked as work
## spots are where residents go to work.
@export var settlement_props: Array[PackedScene] = []
## Things residents say when you come close.
@export var barks: Array[String] = []

@export_group("Talk", "")
## Greetings by how they feel about you: keys "hostile" (< -30), "wary"
## (< 0), "neutral" (< 30), "friendly". Each a list; one is picked.
@export var greetings: Dictionary = {}
## Goodbyes, one picked.
@export var farewells: Array[String] = []
## What they trade away (item ids), and what they want for it. A want of
## &"artifact" means any artifact.
@export var wares: Array[StringName] = []
@export var wants: Array[StringName] = []

@export_group("Starting attitudes", "")
## Starting strength (members, roughly).
@export var strength := 100
## Faction id -> -100 (war) .. 100 (kin), at world start.
@export var relations: Dictionary = {}
## Host type id -> -100 .. 100: how they treat a new host of that type.
@export var host_attitudes: Dictionary = {}
