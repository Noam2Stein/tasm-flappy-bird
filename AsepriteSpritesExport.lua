local sprite = app.activeSprite

-- Check constraints
if sprite == nil then
  app.alert("No Sprite...")
  return
end

if sprite.colorMode ~= ColorMode.INDEXED then
  app.alert("Sprite needs to be in indexed mode.")
  return
end

-- Dimensions
local tileWidth = 16
local tileHeight = 16

local imageWidth = sprite.width
local imageHeight = sprite.height

if imageWidth % tileWidth ~= 0 or imageHeight % tileHeight ~= 0 then
  app.alert("Image dimensions must be a multiple of 16.")
  return
end

local tilesX = imageWidth // tileWidth
local tilesY = imageHeight // tileHeight
local totalTiles = tilesX * tilesY

-- Dialog
local dlg = Dialog("Export Sprite BIN")
dlg:file{ id="exportFile", label="BIN Output", title="Export as .bin", open=false, save=true, filetypes={"bin"} }
dlg:button{ id="ok", text="Export" }
dlg:button{ id="cancel", text="Cancel" }
dlg:show()

local data = dlg.data
if not data.ok then return end

-- Process
local outputFile = io.open(data.exportFile, "wb")
if not outputFile then
  app.alert("Failed to open file for writing!")
  return
end

-- Copy from sprite to image
local img = Image(sprite.spec)
img:drawSprite(sprite, app.activeFrame)

-- Export each tile
for tileY = 0, tilesY - 1 do
  for tileX = 0, tilesX - 1 do
    local baseX = tileX * tileWidth
    local baseY = tileY * tileHeight

    for y = 0, tileHeight - 1 do
      for x = 0, tileWidth - 1 do
        local color = img:getPixel(baseX + x, baseY + y)
        outputFile:write(string.char(color))
      end
    end
  end
end

outputFile:close()
app.alert("Exported " .. totalTiles .. " tiles (" .. totalTiles*256 .. " bytes).")