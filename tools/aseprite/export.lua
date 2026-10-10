-- Exports a source file made by make_source.lua into the strips the game reads.
--
-- In Aseprite: File > Scripts > corpse_export (exports the open file, saves it first).
-- Batch, from the repo root:
--   aseprite -b --script-param file=assets/art/_source/gut_leech.aseprite
--     --script tools/aseprite/export.lua
--
-- One PNG strip per tag:
--   "body"      -> <dir>/<name>_<tag>.png
--   "glow"      -> <dir>/glow/<name>_glow_<tag>.png
--   "mut <id>"  -> assets/art/mutations/<id>/<id>_<tag>.png
-- A layer with nothing drawn in a tag is skipped for that tag, so the game
-- keeps its placeholder there until you draw it. Other layers ("placeholder",
-- sketches) are never exported. Layer opacity is ignored: art is exported as drawn.

local fs = app.fs

local sprite
if app.params.file then
  local file = app.params.file
  if not (string.match(file, "^%a:") or string.match(file, "^[/\\]")) then
    file = fs.joinPath(fs.currentPath, file)  -- Relative to the repo root.
  end
  sprite = app.open(file)
else
  sprite = app.activeSprite
end
if not sprite then
  return app.alert("Open a source file first.")
end

-- The repo root is the folder above assets/art/_source/.
local path = string.gsub(sprite.filename, "\\", "/")
local root = string.match(path, "^(.*)/assets/art/")
if not root then
  return app.alert("Save the file under <repo>/assets/art/_source/ first.")
end
if not app.params.file and sprite.isModified then
  app.command.SaveFile()
end

-- Tile sheets (make_tiles_source.lua): the "body" layer is written into the
-- sheet one tile at a time. Tiles with nothing drawn keep what the sheet had.
local sheet, tile = string.match(sprite.data or "", "^tiles|(.-)|(%d+)$")
if sheet then
  tile = tonumber(tile)
  local body
  for _, layer in ipairs(sprite.layers) do
    if layer.name == "body" then body = layer end
  end
  local drawn = Image(sprite.width, sprite.height, ColorMode.RGB)
  local cel = body and body:cel(1)
  if cel then
    drawn:drawImage(cel.image, cel.position)
  end
  local file = fs.joinPath(root, sheet)
  local out = Image(sprite.width, sprite.height, ColorMode.RGB)
  if fs.isFile(file) then
    out:drawImage(Image{ fromFile = file }, Point(0, 0))
  end
  local clear = Image(tile, tile, ColorMode.RGB)
  local tiles = 0
  for ty = 0, sprite.height // tile - 1 do
    for tx = 0, sprite.width // tile - 1 do
      local piece = Image(drawn, Rectangle(tx * tile, ty * tile, tile, tile))
      if not piece:isEmpty() then
        out:drawImage(clear, Point(tx * tile, ty * tile), 255, BlendMode.SRC)
        out:drawImage(piece, Point(tx * tile, ty * tile))
        tiles = tiles + 1
      end
    end
  end
  if tiles == 0 then
    local msg = "Nothing exported: draw on the \"body\" layer first."
    if app.params.file then print(msg) else app.alert(msg) end
    return
  end
  out:saveAs(file)
  local msg = tiles .. " tiles exported to " .. sheet
  if app.params.file then print(msg) else app.alert(msg .. ". Switch to Godot to see them.") end
  return
end

local dir, name = string.match(sprite.data or "", "^(.-)|(.+)$")
if not dir then
  return app.alert("This file has no export target. Make it with tools/aseprite/make_source.lua.")
end

local size = sprite.height
local written = {}

local function export(layer, out)
  for _, tag in ipairs(sprite.tags) do
    local count = tag.toFrame.frameNumber - tag.fromFrame.frameNumber + 1
    local strip = Image(size * count, size, ColorMode.RGB)
    local any = false
    for i = 0, count - 1 do
      local cel = layer:cel(tag.fromFrame.frameNumber + i)
      if cel and not cel.image:isEmpty() then
        strip:drawImage(cel.image, Point(i * size + cel.position.x, cel.position.y))
        any = true
      end
    end
    if any then
      local file = fs.joinPath(root, out(tag.name))
      fs.makeAllDirectories(fs.filePath(file))
      strip:saveAs(file)
      table.insert(written, out(tag.name))
    end
  end
end

for _, layer in ipairs(sprite.layers) do
  if layer.name == "body" then
    export(layer, function(tag) return dir .. "/" .. name .. "_" .. tag .. ".png" end)
  elseif layer.name == "glow" then
    export(layer, function(tag) return dir .. "/glow/" .. name .. "_glow_" .. tag .. ".png" end)
  else
    local id = string.match(layer.name, "^mut (.+)$")
    if id then
      export(layer, function(tag) return "assets/art/mutations/" .. id .. "/" .. id .. "_" .. tag .. ".png" end)
    end
  end
end

local summary = #written .. " strips exported"
if app.params.file then
  print(summary)
  for _, file in ipairs(written) do print("  " .. file) end
elseif #written == 0 then
  app.alert("Nothing exported: draw on the \"body\" layer first.")
else
  app.alert(summary .. ". Switch to Godot to see them.")
end
