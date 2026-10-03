-- NFS 2015 style HUD, delivered by the server as a CSP online script.
-- Host this file at a public raw URL (GitHub raw / Gist raw) and point the server's
-- cfg/csp_extra_options.ini at it:
--
--   [SCRIPT_1]
--   SCRIPT = "https://raw.githubusercontent.com/<you>/<repo>/main/NFS2015HUD_server.lua"

-- ---------------- Settings ----------------
local USE_MPH = false
local SCALE = 1.0            -- 1.0 = 460x190 px, raise for 1440p/4K
local MARGIN = 40            -- distance from the bottom-right screen corner
local FONT = 'Bahnschrift;Weight=Bold;Style=Italic' -- falls back to a default font if missing
local SEGMENTS = 28
local REDLINE_START = 0.82   -- fraction of the bar where blocks turn orange
local SKEW = 7               -- forward lean of the blocks

local W, H = 460, 190
local BAR_X, BAR_Y, BAR_W, BAR_H = 20, 142, 420, 16
local BOOST_Y, BOOST_H = 168, 4

local WHITE = rgbm(1, 1, 1, 1)
local DIM = rgbm(1, 1, 1, 0.16)
local HOT = rgbm(1.0, 0.36, 0.10, 1)
local BLUE = rgbm(0.25, 0.75, 1.0, 1)
local DIVIDER = rgbm(1, 1, 1, 0.35)

-- ---------------- State ----------------
local rpmSmooth = 0
local learnedMaxRpm = 7000

local function skewQuad(origin, x, y, w, h, skew, col)
  local k = SCALE
  ui.pathClear()
  ui.pathLineTo(origin + vec2((x + skew) * k, y * k))
  ui.pathLineTo(origin + vec2((x + skew + w) * k, y * k))
  ui.pathLineTo(origin + vec2((x + w) * k, (y + h) * k))
  ui.pathLineTo(origin + vec2(x * k, (y + h) * k))
  ui.pathFillConvex(col)
end

local function textRight(origin, text, size, rightX, y, col)
  local k = SCALE
  local w = ui.measureDWriteText(text, size * k).x
  ui.dwriteDrawText(text, size * k, origin + vec2(rightX * k - w, y * k), col)
end

local function drawHud(dt)
  local sim = ac.getSim()
  local car = ac.getCar(sim.focusedCar)
  if car == nil then return end

  local origin = ui.getCursor()

  -- Redline: use the car's limiter if known, otherwise learn it
  local maxRpm = car.rpmLimiter
  if maxRpm == nil or maxRpm < 1000 then
    if car.rpm > learnedMaxRpm then learnedMaxRpm = car.rpm end
    maxRpm = learnedMaxRpm
  end
  local target = math.saturate(car.rpm / maxRpm)
  rpmSmooth = math.applyLag(rpmSmooth, target, 0.75, dt)

  local speed = car.speedKmh
  if USE_MPH then speed = speed * 0.621371 end
  local speedText = tostring(math.floor(math.max(0, speed) + 0.5))

  local gear = car.gear
  local gearText = gear < 0 and 'R' or (gear == 0 and 'N' or tostring(gear))
  local nearLimit = rpmSmooth > 0.93
  local flash = rpmSmooth > 0.975 and (math.floor(os.clock() * 10) % 2 == 0)

  ui.pushDWriteFont(FONT)
  textRight(origin, speedText, 92, 335, -6, WHITE)
  textRight(origin, USE_MPH and 'MPH' or 'KM/H', 20, 335, 104, WHITE)
  skewQuad(origin, 352, 24, 3, 96, 8, DIVIDER)
  textRight(origin, gearText, 78, 435, 14, nearLimit and HOT or WHITE)
  ui.popDWriteFont()

  local step = BAR_W / SEGMENTS
  local segW = step - 3
  local lit = math.floor(rpmSmooth * SEGMENTS + 0.5)
  for i = 0, SEGMENTS - 1 do
    local inRed = (i / SEGMENTS) >= REDLINE_START
    local col = DIM
    if i < lit then col = (inRed or flash) and HOT or WHITE end
    skewQuad(origin, BAR_X + i * step, BAR_Y, segW, BAR_H, SKEW, col)
  end

  if car.turboBoost > 0.01 then
    skewQuad(origin, BAR_X, BOOST_Y, BAR_W, BOOST_H, SKEW, DIM)
    skewQuad(origin, BAR_X, BOOST_Y, BAR_W * math.saturate(car.turboBoost / 2), BOOST_H, SKEW, BLUE)
  end

  ui.dummy(vec2(W * SCALE, H * SCALE))
end

-- Online scripts have no app window, so the HUD makes its own transparent window,
-- anchored to the bottom-right corner of the screen.
function script.drawUI(dt)
  dt = dt or ac.getSim().dt
  local screen = ui.windowSize()
  local size = vec2(W * SCALE, H * SCALE)
  local pos = vec2(screen.x - size.x - MARGIN, screen.y - size.y - MARGIN)
  ui.transparentWindow('nfs2015hud', pos, size, true, false, function()
    drawHud(dt)
  end)
end
