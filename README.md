# CORPSE (working title)

A 2D side-view exploration game set inside the body of a dead god.

Ages ago a god fell from the sky and died. Its body is now a continent of flesh, bone and rot, and parasite civilizations have lived, warred and died inside it for thousands of years. You are a fragment of the god's will. Each time you die, you wake in a new host somewhere else in the body, years later. The world remembers what you did. Your old corpse is still out there, unless someone has looted it, eaten it or built a shrine around it.

Somewhere at the center is the heart.

## Status

Early prototype. A placeholder character runs, jumps and wall-clings through a generated cave world that streams in chunks. See [docs/ROADMAP.md](docs/ROADMAP.md) for where things stand.

## Tech

- Engine: Godot 4.x (latest stable), GDScript
- Art: hand-drawn on a tablet, animated as cutout rigs (Skeleton2D / AnimationPlayer)
- World: painted macro maps (PNG) drive procedural generation of chunks

## Running the project

1. Install Godot 4.x (standard build, not .NET).
2. Open Godot, choose Import, and select `project.godot` in this folder.
3. Press F5.

Controls: A/D or arrows to run, Space/W/Up to jump (hold for higher), push into a wall in the air to cling. Gamepad works too. F3 toggles the debug overlay.

`scenes/test_room.tscn` is a small hand-made room for tuning movement (open it and press F6).

## Docs

| File | What it is for |
|---|---|
| [docs/VISION.md](docs/VISION.md) | What the game is, the pillars, what it is not. Read this when you are unsure whether a feature belongs. |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Week by week plan from empty project to release. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Folder layout, data model, how the sim, world and rendering layers talk to each other. |
| [docs/ART_PIPELINE.md](docs/ART_PIPELINE.md) | How to draw, split and rig sprites so they work with the mutation system. |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Log of design and tech decisions, with reasons. Add to it, never silently change direction. |
| [docs/DEVLOG.md](docs/DEVLOG.md) | Short weekly notes. What got done, what didn't, what's next. |
