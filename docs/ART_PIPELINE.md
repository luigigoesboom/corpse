# Art pipeline

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
| `socket_arm_l` / `socket_arm_r` | Forearm, for spurs, claws |
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
