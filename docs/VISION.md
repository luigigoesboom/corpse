# Vision

## One sentence

A side-view exploration game inside a dead god's body, where every death moves history forward and the world remembers your past lives.

## Inspirations, and what we take from each

| Game | What we take |
|---|---|
| Dwarf Fortress | Generated history. Past adventurers becoming legends. A world that keeps simulating when you are not looking. |
| Caves of Qud | Weird, specific lore. Mutations as builds. Hand-made key places inside a generated world. Many ways past a problem besides fighting. |
| Subnautica | Depth as progression. Darkness and dread. Exploration as the main reward. |
| Hollow Knight | Strong silhouettes, mood from lighting and contrast, corpse retrieval. |
| The Binding of Isaac | Simple bold drawings that a solo artist can produce in volume. |
| Noita | Systems that interact in real time, side-view. |

## Pillars

Every feature should serve at least one of these. If it serves none, cut it.

1. **The world remembers.** Deeds, deaths and corpses persist across lives. Factions talk about you. Time passes when you die.
2. **Deeper is older and stranger.** Moving toward the vital organs means older civilizations, stranger creatures, and more of the god's lingering will.
3. **The body is alive enough to matter.** Blood still pumps, rot spreads, nerves spark, muscles spasm. The setting is a system, not a backdrop.
4. **Many answers to one problem.** Fight, sneak, talk, bribe, eat it, graft it onto yourself. Combat is one tool.

## The world

The god's body is the map. It is painted by hand as a set of PNG layers (see ARCHITECTURE.md) and filled in by generation.

Planned regions, roughly from outside in:

| Region | Feel | Signature hazard / system |
|---|---|---|
| The Wound | Entry point. Scar tissue, scavenger camps. | Tutorial space. Light still reaches here. |
| The Gut | Fermenting swamp, acid lakes, flesh farms. **Vertical slice region.** | Acid, digestion currents that move slowly through the tunnels. |
| The Lungs | Huge hollow chambers, winds from breaths still cycling. | Wind gusts that change traversal on a cycle. |
| The Bones | Mineral wasteland, bone-carver mines, ossified cities. | Collapsing marrow tunnels, mining. |
| The Nerves | Crackling corridors, the god's dying thoughts. | Hallucinations, ghosts, whispers. |
| The Heart | The center. Sealed by valves. Final boss. | Whatever the current history made of it. |

Blood vessels connect regions and act as fast travel and as hazards (currents).

## The player

The player is a fragment of the god's will. It cannot die, it can only lose its host.

On death:

1. The current life is recorded (where it died, what it did, what it carried).
2. Time passes. The history sim advances some years. Factions rise and fall, rot spreads.
3. The old corpse stays in the world, and something may happen to it: left alone, looted, eaten, enshrined, studied.
4. The player picks a new host from a few options, each in a different colony.

Host types include parasite-born colonists, pilgrims from the surface who came too close to a nerve, and things the corpse grew on its own (antibodies, fragments). Different host types start with different bodies and different standing.

## Core loop

Moment to moment: explore, survive, fight or avoid, scavenge, talk.

Per life: pick a goal (find my old body, get a valve key, help or wreck a faction, push deeper), pursue it, die or succeed.

Across lives: collect the valve keys, build a legend, shape which factions control what, eventually open the heart.

## Systems

**Mutations.** Eating or grafting god-matter gives abilities. Each mutation is a physical body part attached to the host's rig (an acid gland, a bone spur, a lung sac). Some carry over between lives in weakened form, most are lost with the body and can be recovered from the corpse.

**Reputation, two layers.**
- *Host standing*: what a faction thinks of the creature in front of them. Starts fresh each life, based on host origin.
- *Legend standing*: what a faction thinks of the fragment, built from deeds across all lives. Only factions that can sense the fragment (priests, nerve-dwellers, things near the heart) react to it directly. Everyone else hears rumors.
- Numbers are hidden, consequences are visible: prices, guards, dialogue, graffiti, bounties, shrines.

**Factions and history.** Worldgen simulates thousands of years of parasite civilizations. Between lives the sim runs again for a short span at higher detail. History produces ruins, artifacts, murals, legends and current conflicts.

**The heart.** Sealed behind valve keys found across the body, each held by a region or faction. Who controls the heart region when you arrive decides what the final fight is. Endings: kill the god for good, revive it, or take its place.

## Combat

Real-time, side-view. Readable enemies, a small moveset, mutations add the variety.

**Open question:** precision skill test (Hollow Knight) or forgiving and systemic (Noita, Qud)? Logged in DECISIONS.md. Decide by the end of week 20 after prototyping both feels.

## Tone

Grotesque but not gory. Sad, strange, a bit funny. The parasites are people with beliefs, not just monsters. The god is never fully explained.

## Not in this game

Saying no early saves months later.

- No 3D.
- No multiplayer.
- No full-reset roguelite. The world is never wiped.
- No large crafting trees. Mutations and trade replace crafting.
- No voice acting.
- No base building (maybe a shrine you can tend, nothing more).
