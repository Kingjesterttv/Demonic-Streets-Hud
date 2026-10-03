-- NFS 2015 style HUD for Assetto Corsa (Custom Shaders Patch Lua app)
-- Install to: <Assetto Corsa>/apps/lua/NFS2015HUD/  (manifest.ini, NFS2015HUD.lua, icon.png)
-- The HUD draws straight onto the screen (no window). Click the "UI Settings" icon in the
-- app bar on the right edge of the screen to change units, size and colours.

-- ---------------- Fixed layout ----------------
local FONT = 'Bahnschrift;Weight=Bold;Style=Italic' -- falls back to a default font if missing
local SEGMENTS = 28
local REDLINE_START = 0.82   -- fraction of the bar where blocks change to the redline colour
local SKEW = 7               -- forward lean of the blocks
local MARGIN = 40            -- distance from the bottom-right screen corner

local W, H = 460, 190
local BAR_X, BAR_Y, BAR_W, BAR_H = 20, 142, 420, 16
local BOOST_Y, BOOST_H = 168, 4

-- ---------------- Saved settings (edited in the UI Settings window) ----------------
local settings = ac.storage({
  useMph = false,
  scale = 1.0,
  mainColor = rgbm(1, 1, 1, 1),
  redColor = rgbm(1.0, 0.36, 0.10, 1),
  boostColor = rgbm(0.25, 0.75, 1.0, 1),
})

-- ---------------- State ----------------
local SCALE = 1
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

local function paint(dt)
  local sim = ac.getSim()
  local car = ac.getCar(sim.focusedCar)
  if car == nil then return end

  local origin = ui.getCursor()

  -- Colours from settings (alpha is ignored so a stray alpha slider can't hide the HUD)
  local m, rc, bc = settings.mainColor, settings.redColor, settings.boostColor
  local WHITE = rgbm(m.r, m.g, m.b, 1)
  local DIM = rgbm(m.r, m.g, m.b, 0.16)
  local DIVIDER = rgbm(m.r, m.g, m.b, 0.35)
  local HOT = rgbm(rc.r, rc.g, rc.b, 1)
  local BLUE = rgbm(bc.r, bc.g, bc.b, 1)

  -- Redline: use the car's limiter if known, otherwise learn it
  local maxRpm = car.rpmLimiter
  if maxRpm == nil or maxRpm < 1000 then
    if car.rpm > learnedMaxRpm then learnedMaxRpm = car.rpm end
    maxRpm = learnedMaxRpm
  end
  local target = math.saturate(car.rpm / maxRpm)
  rpmSmooth = math.applyLag(rpmSmooth, target, 0.75, dt)

  local useMph = settings.useMph
  local speed = car.speedKmh
  if useMph then speed = speed * 0.621371 end
  local speedText = tostring(math.floor(math.max(0, speed) + 0.5))

  local gear = car.gear
  local gearText = gear < 0 and 'R' or (gear == 0 and 'N' or tostring(gear))
  local nearLimit = rpmSmooth > 0.93
  local flash = rpmSmooth > 0.975 and (math.floor(os.clock() * 10) % 2 == 0)

  ui.pushDWriteFont(FONT)
  textRight(origin, speedText, 92, 335, -6, WHITE)
  textRight(origin, useMph and 'MPH' or 'KM/H', 20, 335, 104, WHITE)
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

-- Called by CSP every frame (see [UI_CALLBACKS] in manifest.ini).
-- It doesn't run inside a window, so it opens its own transparent one,
-- which has no title bar and can't be closed or collapsed.
function script.drawHud(dt)
  dt = dt or ac.getSim().dt
  SCALE = settings.scale
  local screen = ui.windowSize()
  local size = vec2(W * SCALE, H * SCALE)
  local pos = vec2(screen.x - size.x - MARGIN, screen.y - size.y - MARGIN)
  ui.transparentWindow('nfs2015hud', pos, size, true, false, function()
    paint(dt)
  end)
end

-- The "UI Settings" window (opened from the app bar icon)
function script.windowSettings(dt)
  ui.header('Units')
  if ui.checkbox('Use MPH (instead of KM/H)', settings.useMph) then
    settings.useMph = not settings.useMph
  end

  ui.header('Size')
  local v = ui.slider('##hudsize', settings.scale, 0.5, 2.0, 'Size: %.2f x')
  settings.scale = v

  ui.header('Colours')
  ui.text('Main (speed, gear, RPM blocks)')
  ui.colorPicker('##maincolor', settings.mainColor)
  ui.text('Redline (RPM top end, gear at limiter)')
  ui.colorPicker('##redcolor', settings.redColor)
  ui.text('Turbo boost bar')
  ui.colorPicker('##boostcolor', settings.boostColor)

  ui.separator()
  if ui.button('Reset to defaults') then
    settings.useMph = false
    settings.scale = 1.0
    settings.mainColor = rgbm(1, 1, 1, 1)
    settings.redColor = rgbm(1.0, 0.36, 0.10, 1)
    settings.boostColor = rgbm(0.25, 0.75, 1.0, 1)
  end
end
