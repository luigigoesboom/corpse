-- Builds a starter .aseprite source file from a folder of PNG strips, so you
-- can draw over the placeholders with every animation already set up.
--
-- Run from the repo root (one line):
--   aseprite -b --script-param dir=assets/art/creatures/gut_leech
--     --script-param name=gut_leech --script tools/aseprite/make_source.lua
-- Optional: --script-param overlays=acid_gland,bone_spur,lung_sac (hosts only)
--
-- Result: assets/art/_source/<name>.aseprite with
--   * one tag per animation (frame counts and speeds as in the game),
--   * "placeholder": the old art, faint and locked, to trace over,
--   * "body": empty, draw here,
--   * "glow": the glow strips (things that shine in the dark), if any,
--   * "mut <id>": one hidden layer per mutation overlay, if any.
-- Export with tools/aseprite/export.lua. Never overwrites an existing file.

-- Same speeds as SpriteSheets.FPS in src/actors/components/sprite_sheets.gd.
local FPS = { idle = 5, run = 10, move = 8, jump = 8, fall = 8, cling = 6,
  windup = 8, attack = 16, hurt = 10, die = 8 }
local ORDER = { "idle", "run", "move", "jump", "fall", "cling", "windup", "attack", "hurt", "die" }

local fs = app.fs
local root = fs.currentPath
local dir = app.params.dir
local name = app.params.name
assert(dir and name, "needs --script-param dir=... and name=...")
local out = fs.joinPath(root, "assets/art/_source/" .. name .. ".aseprite")
if fs.isFile(out) then
  print("exists, not touching it: " .. out)
  return
end

local function strip_path(folder, prefix, anim)
  return fs.joinPath(root, folder .. "/" .. prefix .. "_" .. anim .. ".png")
end

-- Animations present, in a sensible order, with their frame counts.
local anims = {}
local size = nil
for _, anim in ipairs(ORDER) do
  local path = strip_path(dir, name, anim)
  if fs.isFile(path) then
    local img = Image{ fromFile = path }
    size = size or img.height
    table.insert(anims, { name = anim, frames = img.width // img.height })
  end
end
assert(#anims > 0, "no strips named " .. name .. "_<anim>.png in " .. dir)

local sprite = Sprite(size, size, ColorMode.RGB)
local placeholder = sprite.layers[1]
placeholder.name = "placeholder"
local body = sprite:newLayer()
body.name = "body"

-- All frames first, then tags: a frame added after a tag would stretch it.
local first = 1
for _, anim in ipairs(anims) do
  anim.first = first
  first = first + anim.frames
end
for _ = 2, first - 1 do
  sprite:newEmptyFrame()
end
for _, anim in ipairs(anims) do
  for f = anim.first, anim.first + anim.frames - 1 do
    sprite.frames[f].duration = 1 / (FPS[anim.name] or 8)
  end
  local tag = sprite:newTag(anim.first, anim.first + anim.frames - 1)
  tag.name = anim.name
end

-- Copies each frame of the strips in `folder` onto `layer`.
local function fill(layer, folder, prefix)
  local any = false
  for _, anim in ipairs(anims) do
    local path = strip_path(folder, prefix, anim.name)
    if fs.isFile(path) then
      local strip = Image{ fromFile = path }
      for f = 0, anim.frames - 1 do
        local frame = Image(size, size, ColorMode.RGB)
        frame:drawImage(strip, Point(-f * size, 0))
        if not frame:isEmpty() then
          sprite:newCel(layer, anim.first + f, frame, Point(0, 0))
          any = true
        end
      end
    end
  end
  return any
end

fill(placeholder, dir, name)
placeholder.opacity = 90
placeholder.isEditable = false

local glow = sprite:newLayer()
glow.name = "glow"
if not fill(glow, dir .. "/glow", name .. "_glow") then
  sprite:deleteLayer(glow)
end

if app.params.overlays then
  for id in string.gmatch(app.params.overlays, "[^,]+") do
    local layer = sprite:newLayer()
    layer.name = "mut " .. id
    fill(layer, "assets/art/mutations/" .. id, id)
    layer.isVisible = false
  end
end

local palette = fs.joinPath(root, "assets/art/_source/gut.gpl")
if fs.isFile(palette) then
  sprite:setPalette(Palette{ fromFile = palette })
end

-- Where export.lua writes the strips (relative to the repo root).
sprite.data = dir .. "|" .. name
app.activeLayer = body
fs.makeAllDirectories(fs.filePath(out))
sprite:saveAs(out)
print("made " .. out)
