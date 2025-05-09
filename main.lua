local dpi      = love.graphics.getDPIScale()
local WCANVAS  = 512
local HCANVAS  = 512
local WG_SIZE  = 16           -- local_size in hash.comp

-- GPU resources
local canvas = love.graphics.newCanvas(WCANVAS, HCANVAS, {
  format       = "rgba32f",
  computewrite = true
})
local cs   = love.graphics.newComputeShader("hash.comp")
local buf  = love.graphics.newBuffer("uint32", 4, { shaderstorage = true })

-- Demo scene state
local time      = 0
local animate   = true
local prevHash  = ""
local effectRan = false

-- Draw something (white rotating square + red circle) onto the texture
local function drawScene()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 0)

  -- rotating square
  love.graphics.push()
  love.graphics.translate(WCANVAS / 2, HCANVAS / 2)
  love.graphics.rotate(time)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", -64, -64, 128, 128)
  love.graphics.pop()

  -- orbiting circle
  love.graphics.setColor(1, 0, 0, 0.8)
  love.graphics.circle(
    "fill",
    WCANVAS / 2 + math.cos(time * 2) * 150,
    HCANVAS / 2 + math.sin(time * 2) * 150,
    40
  )

  love.graphics.setCanvas()
end

-- calculate pixel-space bounds & hash within them
local function hashCanvas(canvas, rectPx)   
  -- rectPx = {x, y, w, h} in *logical* px
  local Wpix, Hpix = canvas:getPixelDimensions()
  local dpi        = love.graphics.getDPIScale()

  -- convert logical → physical; build (minX,minY,maxX,maxY)
  local bx, by, bx2, by2
  if rectPx then
    bx  = math.max(0,      math.floor(rectPx.x * dpi))
    by  = math.max(0,      math.floor(rectPx.y * dpi))
    bx2 = math.min(Wpix-1, math.floor((rectPx.x+rectPx.w-1) * dpi))
    by2 = math.min(Hpix-1, math.floor((rectPx.y+rectPx.h-1) * dpi))
  else
    bx, by, bx2, by2 = 0, 0, -1, -1        -- “disabled” sentinel
  end

  -- zero output & send uniforms
  buf:setArrayData({0,0,0,0})
  cs:send("Src",    canvas)
  cs:send("Hash",   buf)
  cs:send("Bounds", {bx, by, bx2, by2})
  
  love.graphics.dispatchThreadgroups(
    cs,
    math.ceil(Wpix / WG_SIZE),
    math.ceil(Hpix / WG_SIZE), 
    1
  )

  -- read back 128-bit result
  local raw   = love.graphics.readbackBuffer(buf)
  local bstr  = raw:getString()
  local h0,h1,h2,h3 = love.data.unpack("I4I4I4I4", bstr)
  return string.format("%08x%08x%08x%08x", h0,h1,h2,h3)
end


function love.update(dt)
  if animate then time = time + dt end
end

function love.keypressed(k)
  if k == "space" then animate = not animate end
end

-- Draw to screen & demonstrate the hash workflow
function love.draw()
  drawScene()

  local hash = hashCanvas(canvas)
  effectRan  = (hash ~= prevHash)
  prevHash   = hash

  -- Present result
  love.graphics.clear(0.15, 0.15, 0.15)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, 32, 32, 0, 1 / dpi, 1 / dpi)

  local yText = 32 + HCANVAS / dpi + 8
  love.graphics.setColor(1, 1, 0, 1)
  love.graphics.print("128-bit hash:  " .. hash, 32, yText)

  love.graphics.setColor(effectRan and {0, 1, 0, 1} or {1, 0, 0, 1})
  love.graphics.print(effectRan and "-> content changed – ran expensive effect"
                                  or "-> identical – skipped effect",
                      32, yText + 16)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print("Press <space> to toggle animation", 32, yText + 32)
  local ffps = love.timer.getFPS()
  love.graphics.print("Current FPS: " .. ffps, 32, yText + 32 * 2)
end
