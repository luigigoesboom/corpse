# Art pipeline

> **Pixel art (D-012).** The game is pixel art. Scale (D-023): tiles are 32 x 32 px, the game renders at 640 x 360 (exactly 3x on 1080p, 4x on 1440p, 6x on 4K), hosts are drawn about 56 px tall in 64 x 64 frames. UI text is the m5x7 pixel font (assets/fonts, CC0) at 16 px, titles at 32 or 48; only use multiples of 16 or it blurs. Set in assets/ui/theme.tres; the font imports with anti-aliasing and hinting off. Draw at 1x (one canvas pixel = one game pixel), no anti-aliasing, export PNG; Godot already uses Nearest filtering. Animation is layered frames (D-017), see below.

You are learning to draw while making this. That is fine. Plan for early art to be replaced, and keep the style simple enough that you can produce a lot of it.

## Style rules

1. **Silhouette first.** Every creature must be recognizable as a solid black shape. Draw the silhouette before any detail.
2. **Limited palette per region.** 6 to 10 colors per region plus one accent glow color. Gut: deep reds, bile yellow, sick green glow. Write each region's palette into this file when you make it.
3. **Bold, simple shapes.** Closer to Isaac than to Hollow Knight in detail. Thick outlines or no outlines, pick one in week 15 and stick to it.
4. **Lighting does the mood.** Draw flat, let Godot's 2D lights and darkness add atmosphere.
5. **Consistent scale.** Decide the host's height in pixels in week 16 and measure everything against it.

## Tools

- **Aseprite** for sprites and animation. **Krita** for painting `world.png` and loose sketches.
- One `.aseprite` source file per character in `assets/art/_source/`. The game never reads these, only the PNG strips exported from them.
- Palette: `assets/art/_source/gut.gpl` (starter, the placeholder colors). In Aseprite it is also in the palette menu as "corpse_gut".
- Tablet or mouse, whichever is steadier. Turn on **Pixel-perfect** on the pencil. If the pen lags, switch the API in Edit > Preferences > Tablet.

## Sprites in Aseprite

**Starter files.** `tools/aseprite/make_source.lua` turns a folder of strips into a source file with every animation tagged (frame counts and speeds as in the game), the old art on a faint locked `placeholder` layer, an empty `body` layer to draw on, the `glow` strips, and for hosts one hidden `mut <id>` layer per mutation overlay. `gut_leech.aseprite` and `colonist.aseprite` are already made. For another character, from the repo root (one line):

```
aseprite -b --script-param dir=assets/art/creatures/rot_fly --script-param name=rot_fly --script tools/aseprite/make_source.lua
```

Add `--script-param overlays=acid_gland,bone_spur,lung_sac` for hosts. It never overwrites an existing file.

**Exporting.** File > Scripts > **corpse_export** saves the open file and writes one strip per tag:

| Layer | Goes to |
|---|---|
| `body` | `<folder>/<name>_<tag>.png` |
| `glow` | `<folder>/glow/<name>_glow_<tag>.png` |
| `mut <id>` | `assets/art/mutations/<id>/<id>_<tag>.png` |

Tags with nothing drawn on a layer are skipped, so the game keeps the placeholder for animations you have not drawn yet. Other layers (placeholder, sketches) are never exported. Switch to Godot and the new art is in. (If File > Scripts has no entry: put a file in Aseprite's scripts folder, File > Scripts > Open Scripts Folder, containing `dofile("<repo>/tools/aseprite/export.lua")`.)

**Rules.** Keep the frame size (64 x 64 for hosts, 48 x 48 for the current creatures) and the tags' names. You may add or remove frames inside a tag (right-click a frame > New Empty Frame), but for hosts the mutation layers then need art on the new frames too. Frame durations in Aseprite are only for previewing; in game the speed comes from `SpriteSheets.FPS`.

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
- Things that stand on a floor and do not fall by themselves (items, props, NPCs, set pieces) go **6 px below the tile's top edge** (`ChunkData.FLOOR_SINK`), e.g. y = 3206 on a floor whose tiles start at 3200, so they stand in the top face like the player. Creatures fall into place. `tests/test_floor.gd` checks every placed thing.
- Add NPCs, props and items as children of **Entities** (drag a `.tscn` from the FileSystem dock onto the viewport while Entities is selected) and position them on the map. They only exist in the running game while their chunk is loaded, so place as many as you like.

**Scale, to plan rooms:** the player is about 1.75 tiles tall (56 px drawn, 52 px collision). A full jump is about 4 tiles high, so ledges 3 tiles apart are comfortable. A shaft 4 tiles wide is a good wall-jump climb. A tunnel of 2 tiles is the tightest you can walk through (6 px to spare); 3 tiles feels like a corridor. The screen shows about 20 x 11 tiles, with the floor low on screen.

**Tips:** sketch the big shapes with a large brush first (chambers, main routes), then carve details. Rooms that need precise layout or many props (colonies, boss arenas) will be Godot scenes placed on the map (roadmap week 10); paint just their outline.

## Painting faction territory

`data/maps/territory.png` is the same size as world.png. In Krita, open world.png, add territory.png as a layer on top (File > Import as layer, or drag it in), lower its opacity, and paint each faction's land in its exact color (from its .tres in data/factions: Flesh-Tenders green 112 176 74, Choir of Waking gold 224 184 74). Leave unclaimed land transparent. Export that layer alone to territory.png. Territory is decided per chunk (64 x 64 tiles, the grid squares), so rough blobs are fine. It only applies to new worlds: history owns territory after that.

## Settlements

To add one: in scenes/world.tscn select Entities, add a Node2D, attach src/world/settlement.gd, place it on a **flat** floor (y = tile top + 6, like other floor things) and set `width`. The editor draws its extent. Set `preferred_faction` (a faction id) or leave it empty for whoever holds the chunk. Everything inside is built from the faction:
- **Props**: scenes in src/props/settlement with the SettlementProp script (origin on the floor, `width` = floor it takes, `work_spot` + `work_offset` = where a resident stands to work). List them in the faction's `settlement_props`. The current ones are programmer shapes; replace their Polygon2Ds with Sprite2Ds of your art and keep the script.
- **Residents**: strips in `npc_frames_dir` (assets/art/npcs/tender, chorister), 64 x 64 like hosts: `idle`, `run` (played slowed down as a walk), `work` (bent over a task, loops).
- **Lines**: the faction's `barks`.

## Ruins

Like settlements: add a Node2D under Entities in scenes/world.tscn, attach src/world/ruin_site.gd, put it on flat floor (tile top + 6) and set `width`. History decides which dead settlement it is and leaves that place's artifact in it. Ruin props are in src/props/ruin (SettlementProp script; a Polygon2D named `Cloth` gets the dead people's color).

## The art program (D-028)

The game's art is made by code: `tools/pixel`, run headless in Godot (no installs).

```
Godot --headless --path . --script res://tools/pixel/run.gd -- hosts --preview
```

Names after `--` are recipes (`tools/pixel/recipes/<name>.gd`, or `all`); `--preview` also writes a contact sheet to `tools/pixel/preview/<name>.png` (not in git) so you can look without starting the game. Recipes write straight into `assets/art`, so check the preview and `git diff` before committing.

| Part | Job |
|---|---|
| `palette.gd` | Reads `assets/art/_source/gut.gpl`. A `# ramp <name>` line starts a ramp (dark to light). `ramp()`, `step(name, i)` (negative counts from the light end), `shade(name, t)`, `snap()`. |
| `canvas.gd` | One frame. Record shapes (`ellipse`, `circle`, `capsule` = tapered tube, `polygon`, `rect`) with a ramp and options (`z`, `tone`, `dither`, `glow`, `flat`, `lo`/`hi` steps, `line`, `rot`, `alpha`, `seam`), and `detail()` / `stroke()` pixels; `render()` rasterizes in z order, shades every pixel from the shape's form (ellipse = dome, capsule = tube, polygon = bevelled slab) with light from the top left, prunes one-pixel nubs, draws dark lines where a shape lies behind another, and outlines: near-black, but the shape's own darkest color on the lit side. Glow shapes and details go to a second image. |
| `rig.gd` | `ik()` (two-bone: knees and elbows from where hands and feet go), `reach()`, `turn()`. |
| `sheet.gd` | `strip()`, `save()`, `preview()`. |
| `recipes/swatch.gd` | Test card: spheres, tubes, slabs in every ramp. |
| `recipes/creatures.gd` | Gut Leech (seamed segments, belly strip, ring mouth), Bile Spitter (stalk, dithered bulb, bile gland), Rot Fly (see-through wings). 48 px frames, glow strips in `glow/`. |
| `recipes/matron.gd` | The Gullet Matron, 128 px: seven seamed segments, brood sacs, belly, glowing bile bladder, ring of teeth, four eyes. |
| `recipes/hosts.gd` | One skeleton for every humanoid; looks (colonist, pilgrim, antibody, tender, chorister) dress it; poses are hand and foot targets; the mutation overlays (acid gland, bone spur, lung sac) are drawn on the same joints. |

Making a new thing: copy the nearest recipe, change the shapes and poses, run with `--preview`, look, repeat. `tests/test_art.gd` checks that everything the program makes stays in the palette.

## Kinds of rock and dressing (D-028)

**Painting kinds.** `data/maps/tiles.png` is a second painting, the same size as world.png. Where it is transparent the rock is flesh; elsewhere the nearest of these colors picks the kind (`WorldMap.KIND_PAINT`): bile (150, 180, 40), bruise (110, 60, 170), bone (210, 200, 170), rot (140, 85, 40). Only rock pixels matter, so paint broad areas; soft or noisy borders blend kinds tile by tile. F4 reloads it with the map. The starter painting: bruise in the deep, bile in the east cavern, bone in the upper tunnel, rot around the chamber ruin.

**Tiles.** `recipes/tiles.gd` draws the cobble rock and paved floors once per kind, each in its own 7-step ramp (`flesh`, `rock_bile`, `rock_bruise`, `rock_bone`, `rock_rot`), stacked as 4 x 5 blocks in `gut_tiles.png`, and copies the flesh tiles' collision and occluders to every kind's rows in `gut_tileset.tres`. A cell stores tile and kind in one byte (`ChunkData.cell_of()`, `tile_of()`, `kind_of()`).

**Dressing.** The stuff on the rock: `recipes/dressing.gd` draws, per kind, 6 floor things, 6 ceiling things, 6 wall things (and their mirror) and 6 inlays (buried in the rock, drawn dark) in `dressing.png`, plus 4 big floor and 4 big ceiling pieces (64 px) in `dressing_big.png`, each with a glow sheet. `ChunkDressing` (src/world/chunks) places them on every built chunk from a hash of each tile's position, so a place always looks the same: densities and offsets are constants at its top. Only a view, never saved.

## Props and items (week 39 art pass)

All props, items and world objects in the Gut are sprites in the Gut palette (`assets/art/_source/gut.gpl`, 48 colors in ramps: flesh, blood, rag, skin, leech, bile, bone, lung, bulb, wood, gold, ash, Matron hide, glows). In Aseprite: Palette > Load palette > gut.gpl, and paint only with it; `tests/test_art.gd` fails if a prop or item PNG uses any other color.

| Where | What |
|---|---|
| `assets/art/props/<prop>_body.png` | The prop, lit by the scene's lights. Outlined in near-black. |
| `assets/art/props/<prop>_glow.png` | Parts that shine (flames, eyes, relics), drawn unshaded on top. |
| `assets/art/props/<prop>_cloth.png` | Light greys tinted in game: banners in their people's color, mural panels. |
| `assets/art/items/<item id>.png` | 16 x 16 icon standing on the bottom edge. Artifacts share `artifact.png`; anything without an icon uses `unknown.png`. |

How they were made: `tools/art/make_props.gd` rasterized every old polygon placeholder (colors snapped to the palette, shaded below, lit along the top, outlined) and painted the code-drawn ones (carcass, reliquary, nest, valve key, brazier and its 4-frame flame, latch, grate, mural, tablet) and the item icons; `tools/art/swap_props.py` swapped the scenes' polygons for `Art` / `ArtGlow` / `Cloth` Sprite2D nodes. To redraw a prop, just paint over its PNG (same size keeps it in place; a different size: move the sprite's offset so the bottom stays on the floor line). The only polygons left are effects (the slash, the slam marker).

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

`assets/art/tiles/gut_tiles.png` is the sheet the game uses (it started as a copy of the programmer-drawn `gut_placeholder.png`: flesh fill, light membrane rim on open sides, rounded corners where two open sides meet). Collision shapes and light occluders live in `gut_tileset.tres`.

**Drawing tiles in Aseprite.** Open `assets/art/_source/gut_tiles.aseprite` (made by `tools/aseprite/make_tiles_source.lua`). The grid is 32 x 32 (View > Show > Grid). Draw on `body`; the `guide` layer shows each tile's open sides in cyan, a dotted line 6 px in (light reaches the rim up to there, deeper is in shadow), and an X on rock away from air. File > Scripts > corpse_export writes every tile you drew on into `gut_tiles.png`; tiles you have not touched keep the old art, and a tile you touched is replaced by exactly what `body` has there.

**Checking seams.** Open `scenes/tools/tile_preview.tscn` in Godot: a small room that uses all 18 tiles, rebuilt from the sheet whenever it is re-exported. Run it (F6) to see it in the game's darkness with a light that follows the mouse. Tip: Aseprite's View > Tiled Mode tiles the whole sheet, not one tile, so use the preview instead.

**Top faces (D-022, D-023, Blasphemous-style ground).** Every tile with air above (the odd-numbered ones: columns 1 and 3) has a **top face** in its top 12 px: the floor seen slightly from above, lighter than the side. In the placeholder: a darker back edge (row 0), two rows of paving stones (rows 1-10), a bright front lip (row 11), a dark line under the lip (row 12), then the side. Its outer corners are rounded a little where a wall side is open too. Walls and ceilings have no face, just a dark rim. The collision of these tiles starts 6 px below the top edge (`FLOOR_SINK`), so feet stand in the middle of the face; the light blocker starts 12 px down, so the whole face is lit. The guide layer's dotted line on top-open tiles marks the face's bottom (12 px).

**Ground mass.** All rock is filled with the same seamless cobble texture (it repeats every 32 px both ways, so tiles join without seams), getting darker away from air: buried rock a little, the 2-deep tile more, the 3+-deep tile most, but never black. The lower part of the screen is mostly ground, so it should read as stone, not as a hole.

Rules so tiles join cleanly: the fill must reach the tile border on every closed side, and rims must sit only on open sides. Inside corners (rock on all 4 sides but open diagonally) are not handled by 16 tiles; if they look bad, we move to the 47-tile "blob" set later.

## Animation: layered frames (D-017)

Characters and creatures are frame-by-frame pixel animations. Mutations are drawn as separate overlay sheets over the same frames, so a host can grow parts without the body being redrawn.

**One folder per character, one PNG strip per animation:**

```
assets/art/creatures/gut_leech/
  gut_leech_idle.png      2 frames
  gut_leech_move.png      4 frames
  gut_leech_windup.png    ...
  gut_leech_attack.png
  gut_leech_hurt.png
  gut_leech_die.png
  glow/gut_leech_glow_idle.png ...   optional: drawn unshaded (glowing eyes)
```

- File name ends in `_<animation>.png`. The game builds the animations from the folder by itself (`SpriteSheets`); no setup in Godot.
- Strips are horizontal, frames are **square**: height = frame size, width / height = frame count. Hosts use **64 x 64** (D-023), the current creatures **48 x 48**. Frame size is read from the strip, so a creature can move to 64 too; its scene's `frame_offset` then becomes (0, -32).
- The character stands on the bottom of the frame, centered, facing **right** (the game flips it).
- Animation names the code asks for:
  - Host: `idle`, `run`, `jump`, `fall`, `cling`, `dodge` (the roll, loops while rolling), `attack`, `hurt`, `die`. The run cycle's speed follows the host's actual speed.
  - Gut Leech: `idle`, `move`, `windup`, `attack`, `hurt`, `die`.
  - Missing ones fall back to `idle`. Speeds are in `SpriteSheets.FPS`; `windup`, `attack`, `hurt`, `die` play once.
- A `glow/` subfolder (set as the sprite's glow folder) is drawn on top, unshaded: eyes and glands that shine in the dark.

**Mutation overlays.** A mutation is a folder of strips with the **same animation names and frame counts as the host**, drawn on a transparent canvas the same size, with only the part on it, in the right place on every frame:

```
assets/art/mutations/acid_gland/acid_gland_idle.png   4 frames, matches colonist_idle.png
assets/art/mutations/acid_gland/acid_gland_run.png    6 frames, matches colonist_run.png
...
```

Easiest way: in `colonist.aseprite`, show the `mut <id>` layer, draw the part on every frame, and export (see "Sprites in Aseprite"). Set `part_behind` on the MutationDef for parts that sit behind the body (back sacs). Hosts: `assets/art/hosts/colonist/`, `pilgrim/`, `antibody/` (placeholders, generated by script; draw over them freely). They share the same poses and anchor points, so one set of mutation overlays fits all three. If a future host has a different body shape, its mutations need their own overlay folder.

**Sockets.** `Visual/Sockets/socket_<slot>` markers on the player still exist, but only as gameplay points (where acid spit starts). Move them if your drawing puts the mouth elsewhere.

## Ground shadows

Characters, creatures, NPCs and items have a `GroundShadow` (src/actors/components) as their first child: a soft dark oval on the floor under them, smaller and fainter the higher they are. It is drawn in code, so sprites need no shadow of their own. Tune `width`, `feet` (where the feet are relative to the node's origin) and `opacity` per scene; delete the node to drop the shadow.

## Practice plan

You do not need to study art separately. Each art week in the roadmap is the practice. If you want extra, 20 minutes a day of drawing creatures from life (insects, deep sea animals, anatomy diagrams) fits the game perfectly.

## Git notes

Large source files make the repo slow. If `_source` art files start passing ~50 MB each, consider Git LFS for `*.kra` and `*.psd`, or keep source files outside the repo and only commit exported PNGs.
