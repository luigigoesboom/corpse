-- Builds a starter .aseprite source file for a terrain tile sheet (the 18-tile
-- autotile layout in docs/ART_PIPELINE.md, "Terrain tiles").
--
-- Run from the repo root (one line):
--   aseprite -b --script-param sheet=assets/art/tiles/gut_tiles.png
--     --script-param name=gut_tiles --script tools/aseprite/make_tiles_source.lua
--
-- Result: assets/art/_source/<name>.aseprite with a 32 x 32 grid and
--   * "placeholder": the current sheet, faint and locked,
--   * "body": empty, draw here,
--   * "guide": not exported. Cyan edges = open sides (air), dotted line = how
--     far in light reaches: 6 px on walls and ceilings, 12 px on floors, which
--     is the floor's top face (D-023). Grey X = rock
--     away from air (buried, 2 deep, 3+ deep). The last two cells are unused.
-- Export with tools/aseprite/export.lua. Never overwrites an existing file.

local TILE = 32
local INSET = 6   -- Light reaches this far into walls and ceilings...
local FACE = 12   -- ...and this far into floors: their top face (D-023).
local OPEN_UP, OPEN_RIGHT, OPEN_DOWN, OPEN_LEFT = 1, 2, 4, 8

local fs = app.fs
local root = fs.currentPath
local sheet = app.params.sheet
local name = app.params.name
assert(sheet and name, "needs --script-param sheet=... and name=...")
local out = fs.joinPath(root, "assets/art/_source/" .. name .. ".aseprite")
if fs.isFile(out) then
  print("exists, not touching it: " .. out)
  return
end

local current = Image{ fromFile = fs.joinPath(root, sheet) }
local sprite = Sprite(current.width, current.height, ColorMode.RGB)
sprite.gridBounds = Rectangle(0, 0, TILE, TILE)

local placeholder = sprite.layers[1]
placeholder.name = "placeholder"
sprite:newCel(placeholder, 1, current, Point(0, 0))
placeholder.opacity = 110
placeholder.isEditable = false

local body = sprite:newLayer()
body.name = "body"

local guide = sprite:newLayer()
guide.name = "guide"
local g = Image(sprite.width, sprite.height, ColorMode.RGB)
local edge = app.pixelColor.rgba(0, 230, 255, 255)
local light = app.pixelColor.rgba(0, 230, 255, 120)
local grey = app.pixelColor.rgba(160, 160, 160, 140)

local function px(x, y, c) g:drawPixel(x, y, c) end

local columns = current.width // TILE
local count = columns * (current.height // TILE)
for index = 0, count - 1 do
  local ox, oy = (index % columns) * TILE, (index // columns) * TILE
  if index <= 15 then
    local open = index  -- Tile index = open-sides mask (ChunkData).
    for i = 0, TILE - 1 do
      local dotted = i % 2 == 0
      if open & OPEN_UP ~= 0 then
        px(ox + i, oy, edge)
        if dotted then px(ox + i, oy + FACE, light) end
      end
      if open & OPEN_DOWN ~= 0 then
        px(ox + i, oy + TILE - 1, edge)
        if dotted then px(ox + i, oy + TILE - 1 - INSET, light) end
      end
      if open & OPEN_LEFT ~= 0 then
        px(ox, oy + i, edge)
        if dotted then px(ox + INSET, oy + i, light) end
      end
      if open & OPEN_RIGHT ~= 0 then
        px(ox + TILE - 1, oy + i, edge)
        if dotted then px(ox + TILE - 1 - INSET, oy + i, light) end
      end
    end
    if open == 0 then  -- Buried rock: never next to air.
      for i = 12, 19 do px(ox + i, oy + i, grey); px(ox + TILE - 1 - i, oy + i, grey) end
    end
  elseif index <= 17 then  -- NEAR / DEEP: further from air, fade toward dark.
    for i = 12, 19 do px(ox + i, oy + i, grey); px(ox + TILE - 1 - i, oy + i, grey) end
  end
end
sprite:newCel(guide, 1, g, Point(0, 0))

local palette = fs.joinPath(root, "assets/art/_source/gut.gpl")
if fs.isFile(palette) then
  sprite:setPalette(Palette{ fromFile = palette })
end

-- Tells export.lua this is a tile sheet and where it goes.
sprite.data = "tiles|" .. sheet .. "|" .. TILE
app.activeLayer = body
fs.makeAllDirectories(fs.filePath(out))
sprite:saveAs(out)
print("made " .. out)
