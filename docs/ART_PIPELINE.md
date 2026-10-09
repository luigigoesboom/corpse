# Art pipeline

> **Pixel art (D-012).** The game is pixel art. Scale (D-014): tiles are 32 x 32 px, the game renders at 1280 x 720, the host is about 48 px tall. Draw at 1x (one canvas pixel = one game pixel), no anti-aliasing, export PNG; Godot already uses Nearest filtering. Sections below written for smooth hand-drawn art (canvas size, cutout rigs) get reworked when Q-007 (animation) is decided.

You are learning to draw while making this. That is fine. Plan for early art to be replaced, and keep the style simple enough that you can produce a lot of it.

## Style rules

1. **Silhouette first.** Every creature must be recognizable as a solid black shape. Draw the silhouette before any detail.
2. **Limited palette per region.** 6 to 10 colors per region plus one accent glow color. Gut: deep reds, bile yellow, sick green glow. Write each region's palette into this file when you make it.
3. **Bold, simple shapes.** Closer to Isaac than to Hollow Knight in detail. Thick outlines or no outlines, pick one in week 15 and stick to it.
4. **Lighting does the mood.** Draw flat, let Godot's 2D lights and darkness add atmosphere.
5. **Consistent scale.** Decide the host's height in pixels in week 16 and measure everything against it.

## Tools

- Krita (free) or whatever you already use with the tablet.
- One `.kra` (or equivalent) source file per creature, kept in `assets/art/_source/` (or outside the repo if files get big, see Git notes below).

## Canvas and export

- Draw at 2x the size it will appear in game, export at 1x. Downscaling hides wobbly lines.
- Export PNG with transparency.
- In Godot, for hand-drawn art keep texture filter on Linear (the project default). Only switch to Nearest if you go pixel art.

## Painting the world

The level is a PNG: `data/maps/world.png`, **one pixel = one tile** (32 x 32 px in game). See D-010.

| Paint | Means |
|---|---|
| Black / dark | Rock |
| White, light, or transparent | Open space |

**Krita setup (once):**
1. Open `data/maps/world.png` in Krita (or File > New, e.g. 1024 x 512 px for a 16 x 8 chunk world).
2. Pick a brush with **no anti-aliasing** for edges you want crisp: the "Pixel Art" brush presets, or Basic-1 with "Anti-aliasing" off. Soft brushes are OK too: grey pixels count as rock if darker than mid-grey.
3. View > Show Grid, grid spacing 64 px: each square is one chunk (2048 px in game).
4. Keep your working file as `data/maps/world.kra` (layers, sketches, notes); File > Export to `world.png` when you want to play it. Hide sketch layers before exporting.

**The loop:** paint, export, switch to the running game, press **F4**. The world rebuilds from the new PNG on the spot. Press **M** for a map view with your position. If you painted rock where the player stands, move or reload a save (F10).

**Placing things in Godot:** open `scenes/world.tscn`. The MapPreview node draws your painting at real size with a chunk grid (it refreshes a second after you export from Krita and click back into Godot). On top of it:
- Drag **PlayerSpawn** to where a fresh game starts. Put it just above a floor.
- Add NPCs, props and items as children of **Entities** (drag a `.tscn` from the FileSystem dock onto the viewport while Entities is selected) and position them on the map. They only exist in the running game while their chunk is loaded, so place as many as you like.

**Scale, to plan rooms:** the player is about 1.5 tiles tall. A full jump is about 4 tiles high, so ledges 3 tiles apart are comfortable. A shaft 4 tiles wide is a good wall-jump climb. A tunnel needs to be at least 2 tiles tall to walk through.

**Tips:** sketch the big shapes with a large brush first (chambers, main routes), then carve details. Rooms that need precise layout or many props (colonies, boss arenas) will be Godot scenes placed on the map (roadmap week 10); paint just their outline.

## Light and glow

The world is dark (CanvasModulate on `Darkness` in game.tscn) and lit by PointLight2D nodes using `assets/lights/light_banded.tres` (hard steps, pixel-art friendly). Tiles block light (occluders in gut_tileset.tres).
- Things that should glow in the dark (fungus caps, eyes, lamps, labels): set their material to `assets/materials/unshaded.tres`.
- A visible halo around a light: a Sprite2D with the banded light texture and `assets/materials/additive_glow.tres`, low alpha.
- Fonts: the default font is smooth. For crisp pixel text, drop a pixel font (.ttf, e.g. a free one from itch.io) into `assets/fonts/` and set it as the project's custom font (Project Settings > GUI > Theme > Custom Font).

## Terrain tiles

The game picks a tile for every rock cell from which of its 4 sides face open space (autotiling). That needs 16 tiles, in a 4 x 4 grid of 32 x 32 px tiles, in this order:

| Tile | Open sides | | Tile | Open sides |
|---|---|---|---|---|
| (0,0) | none (buried rock, no collision) | | (0,2) | left |
| (1,0) | up | | (1,2) | up + left |
| (2,0) | right | | (2,2) | right + left |
| (3,0) | up + right | | (3,2) | up + right + left |
| (0,1) | down | | (0,3) | down + left |
| (1,1) | up + down | | (1,3) | up + down + left |
| (2,1) | right + down | | (2,3) | right + down + left |
| (3,1) | up + right + down | | (3,3) | all four |

(Tile number = up 1 + right 2 + down 4 + left 8; column = number % 4, row = number / 4.)

Row 4 holds two extra tiles without collision: (0,4) rock 2 tiles from open space, (1,4) rock 3+ tiles deep. They let big rock masses fade to dark.

`assets/art/tiles/gut_placeholder.png` is a programmer-drawn version: flesh fill, light membrane rim on open sides, rounded corners where two open sides meet. To use real art, draw over it in Krita at 2x (256 x 256, then export at 128 x 128) keeping the same layout, and overwrite the PNG. Nothing else needs to change. Collision shapes live in `gut_tileset.tres` (squares, with corners cut where two open sides meet).

Rules so tiles join cleanly: the fill must reach the tile border on every closed side, and rims must sit only on open sides. Inside corners (rock on all 4 sides but open diagonally) are not handled by 16 tiles; if they look bad, we move to the 47-tile "blob" set later.

## Cutout rigs

Instead of drawing every animation frame, draw each body part once and animate the parts.

**Drawing a creature for rigging:**

1. Sketch the creature whole, in a neutral pose.
2. Split it into parts on separate layers: body, head, each limb segment, tail, fins, tentacles.
3. Where parts overlap at joints, draw a little extra under the overlap so no gaps show when it rotates.
4. Export each part as its own PNG into `assets/art/creatures/<creature_name>/`.

**Rigging in Godot:**

1. Create a scene with a `Skeleton2D`, add `Bone2D` nodes for each joint.
2. Add a `Sprite2D` (or `Polygon2D` if you want skinning) for each part, parented under its bone.
3. Animate bone rotations with `AnimationPlayer`. Minimum set: `idle`, `move`, `attack`, `hurt`, `die`.
4. Swimming, swaying and breathing loops are cheap and look great: a slow sine rotation on a chain of bones.

## Mutation sockets

Mutations attach to the host as extra parts, so every host rig needs named sockets.

- Add a `Marker2D` as a child of a bone and name it after the socket.
- Standard socket names (use exactly these so any mutation fits any host):

| Socket | Where |
|---|---|
| `socket_back` | Upper back, for sacs, spines, wings |
| `socket_arm` | Forearm, for spurs, claws (one arm slot for now) |
| `socket_head` | Top of head |
| `socket_mouth` | Mouth, for glands that spit |
| `socket_belly` | Torso front |
| `socket_tail` | Base of tail, if the host has one |

- A mutation part scene has its own small rig whose root lines up with the socket's origin. Draw it pointing right, the socket handles flipping.

## Naming

```
assets/art/creatures/gut_leech/
  gut_leech_body.png
  gut_leech_head.png
  gut_leech_tail_01.png
  gut_leech_tail_02.png
```

`<thing>_<part>[_<index>].png`, all lowercase.

## Practice plan

You do not need to study art separately. Each art week in the roadmap is the practice. If you want extra, 20 minutes a day of drawing creatures from life (insects, deep sea animals, anatomy diagrams) fits the game perfectly.

## Git notes

Large source files make the repo slow. If `_source` art files start passing ~50 MB each, consider Git LFS for `*.kra` and `*.psd`, or keep source files outside the repo and only commit exported PNGs.
