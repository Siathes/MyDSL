--[[=====================================================================
  MyDSL_AmbientBackground.lua
  Subtle main-console background tint that gradients with DSL's own
  in-game clock and current weather.

  Built 2026-08-30 per Steven's direct ask: "is there a way to set the
  background color of the main screen during day and night? or even a
  very subtle image for the background of day and night to track
  visually?" -- followed by the concrete spec: "something that get full
  black at midnight, and a subtle but noticeable at its brightest color
  for noon. this should progress with the day time in moon weather so it
  syncs and colors like a gradient. yellow to red to black or some kind
  of combination that MATCHES THE WEATHER."

  Design choices, each traceable to that spec:
  - Color tint, not a background IMAGE -- MyDSL_LocationView.lua already
    found setBackgroundImage() unreliable in Mudlet 4.20.1, and an image
    risks fighting text readability on the console this whole project
    treats as sacred (never break/hide it, per CLAUDE.md's philosophy).
  - Reuses MyDSL_MoonWeather's own already-tested live DSL clock
    (MW.currentGameMinutes(), extracted from its clockStr() interpolation
    math) rather than re-deriving time-of-day, and its already-tested
    real weather taxonomy (MW.weatherCategory(), extracted from
    buildWeatherText()'s WEATHER_KEYWORDS) rather than re-parsing
    MyDSL.State.weather.description with a second keyword list -- "syncs
    with moon weather" per Steven's own words, not a coincidence.
  - Confirmed real Mudlet API before writing anything: setBackgroundColor
    (windowName, r, g, b, [alpha]) and getBackgroundColor([windowName])
    both exist (TLuaInterpreterUI.cpp, fetched directly from Mudlet's own
    GitHub source, not assumed) -- resetBackgroundColor does NOT exist
    anywhere in Mudlet's source (confirmed via a real code search, zero
    hits), so "turn it off" works by restoring a snapshot of the
    player's own real background color, taken once, ever, and persisted
    -- never by calling a function that doesn't exist.
  - The blend is computed in Lua as a plain RGB weighted average against
    that snapshotted real base color, then applied via setBackgroundColor
    at full alpha (255) -- sidesteps relying on the console's own alpha-
    compositing behavior (same class of "unreliable, don't lean on it"
    caution as the background-image note above), and keeps the result
    fully deterministic/testable.
  - "Full black at midnight" vs "subtle but noticeable... noon" isn't one
    constant blend strength -- a DSL console's real background is already
    close to black, so a fixed 20-30% blend toward pure black would be
    nearly invisible at midnight. Strength itself progresses across the
    day: strong (~90% toward black) at midnight for a real, visible
    darkening, weak (~15% toward the weather's peak color) at noon to
    stay subtle, ~45% at dawn/dusk in between.
  - "Yellow to red to black" -- four keyframes across 24h (midnight/
    dawn/noon/dusk/midnight), piecewise-linear interpolated: black at
    00:00, each weather's own dawn/dusk color at 06:00 and 18:00, each
    weather's own peak color at 12:00. For Clear weather specifically
    this literally produces black -> red-orange -> gold -> red-orange ->
    black across the day, matching Steven's own example almost exactly;
    other weather categories (Storm/Rain/Snow/Sleet/Cloudy) get their own
    palette so the effect visibly "matches the weather" as asked.

  Passive display only. Never sends game commands.
  Aliases: mydsl ambient on/off/toggle/status
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.Ambient = MyDSL.Ambient or {}

local AB = MyDSL.Ambient

AB.config = AB.config or {}
if AB.config.enabled == nil then AB.config.enabled = true end
-- baseColor -- the player's own real "main" console background, captured
-- ONCE ever (never re-captured while a tint may already be applied, or
-- the snapshot would drift toward whatever tint happened to be live at
-- that moment). Persisted so a script reload mid-session doesn't lose it.
AB.config.baseColor = AB.config.baseColor or nil

AB._handlers = AB._handlers or {}
AB._aliases  = AB._aliases  or {}

------------------------------------------------------------------------
-- Settings persistence -- shared across characters (a cosmetic display
-- preference, same "not character-bound, intentionally" precedent as
-- ThemeEngine, not per-character game state).
------------------------------------------------------------------------
local function SETTINGS_FILE()
  return getMudletHomeDir() .. "/MyDSL_ambient_settings.lua"
end

function AB.saveSettings()
  local data = { enabled = AB.config.enabled, baseColor = AB.config.baseColor }
  local ok = pcall(table.save, SETTINGS_FILE(), data)
  return ok == true
end

function AB.loadSettings()
  local f = io.open(SETTINGS_FILE(), "r")
  if not f then return false end
  f:close()
  local loaded = {}
  local ok = pcall(table.load, SETTINGS_FILE(), loaded)
  if not ok or not next(loaded) then return false end
  if loaded.enabled ~= nil then AB.config.enabled = loaded.enabled == true end
  if type(loaded.baseColor) == "table" then AB.config.baseColor = loaded.baseColor end
  return true
end

------------------------------------------------------------------------
-- Weather palettes -- {dawn/dusk = {r,g,b}, noon = {r,g,b}}. Subjective
-- color choices, first pass -- adjustable later if Steven wants a
-- different palette per weather type, but each one is a deliberate,
-- weather-appropriate choice, not a placeholder.
------------------------------------------------------------------------
local WEATHER_PALETTE = {
  Clear  = { dawn = { 200, 80,  30 },  noon = { 255, 200, 60 } },   -- red-orange -> gold
  Cloudy = { dawn = { 110, 95, 100 },  noon = { 150, 150, 160 } },  -- muted mauve-grey -> pale grey
  Rain   = { dawn = { 55,  65,  85 },  noon = { 85,  105, 135 } },  -- deep blue-grey -> steel blue
  Storm  = { dawn = { 85,  35,  55 },  noon = { 100, 55,  85 } },   -- dark red-violet -> muted violet-red
  Snow   = { dawn = { 130, 140, 165 }, noon = { 200, 210, 230 } },  -- cool pale blue-grey -> icy white-blue
  Sleet  = { dawn = { 100, 110, 125 }, noon = { 150, 160, 180 } },  -- darker grey-blue -> muted blue-grey
}

local function lerp(a, b, t) return a + (b - a) * t end

local function lerpColor(c1, c2, t)
  return {
    math.floor(lerp(c1[1], c2[1], t) + 0.5),
    math.floor(lerp(c1[2], c2[2], t) + 0.5),
    math.floor(lerp(c1[3], c2[3], t) + 0.5),
  }
end

local function clamp255(n) return math.max(0, math.min(255, n)) end

-- gradientAt(totalMin, palette) -- four keyframes across 24h (see header
-- comment for the reasoning): 00:00 black/strong, 06:00 dawn/mid,
-- 12:00 noon/weak, 18:00 dusk (same as dawn)/mid, 24:00 black/strong
-- again. Returns {color={r,g,b}, strength=0..1}.
local function gradientAt(totalMin, palette)
  local BLACK = { 0, 0, 0 }
  local keyframes = {
    { min = 0,    color = BLACK,        strength = 0.90 },
    { min = 360,  color = palette.dawn, strength = 0.45 },
    { min = 720,  color = palette.noon, strength = 0.15 },
    { min = 1080, color = palette.dawn, strength = 0.45 },
    { min = 1440, color = BLACK,        strength = 0.90 },
  }
  for i = 1, #keyframes - 1 do
    local k1, k2 = keyframes[i], keyframes[i + 1]
    if totalMin >= k1.min and totalMin <= k2.min then
      local t = (k2.min == k1.min) and 0 or (totalMin - k1.min) / (k2.min - k1.min)
      return {
        color = lerpColor(k1.color, k2.color, t),
        strength = lerp(k1.strength, k2.strength, t),
      }
    end
  end
  return { color = BLACK, strength = 0.90 }
end

-- computeColor(totalMin, category, baseColor) -- pure function, no game
-- state read directly, so it's fully unit-testable. baseColor is the
-- player's real snapshotted console background; the result blends toward
-- the gradient's color at the gradient's own strength for this moment.
function AB.computeColor(totalMin, category, baseColor)
  local palette = WEATHER_PALETTE[category] or WEATHER_PALETTE.Clear
  local g = gradientAt(totalMin % 1440, palette)
  local blended = lerpColor(baseColor, g.color, g.strength)
  return { clamp255(blended[1]), clamp255(blended[2]), clamp255(blended[3]) }
end

------------------------------------------------------------------------
-- apply() -- recomputes and repaints, or no-ops cleanly when data isn't
-- ready yet / the feature is off. Never guesses a color when the real
-- DSL clock hasn't anchored yet (MoonWeather itself isn't ready) --
-- silently skips rather than flashing an arbitrary color.
------------------------------------------------------------------------
function AB.apply()
  if not AB.config.enabled then return end
  if not (MyDSL.MoonWeather and MyDSL.MoonWeather.currentGameMinutes) then return end
  local totalMin = MyDSL.MoonWeather.currentGameMinutes()
  if not totalMin then return end
  if not AB.config.baseColor then AB.captureBase() end
  if not AB.config.baseColor then return end

  local category = (MyDSL.MoonWeather.weatherCategory and MyDSL.MoonWeather.weatherCategory()) or "Clear"
  local c = AB.computeColor(totalMin, category, AB.config.baseColor)
  pcall(setBackgroundColor, "main", c[1], c[2], c[3], 255)
end

-- captureBase() -- snapshots the player's real "main" background exactly
-- once, ever. Guarded so a later call (e.g. a stray re-init) can never
-- overwrite a real snapshot with an already-tinted color.
function AB.captureBase()
  if AB.config.baseColor then return end
  local ok, r, g, b = pcall(getBackgroundColor, "main")
  if ok and type(r) == "number" then
    AB.config.baseColor = { r, g, b }
    AB.saveSettings()
  end
end

function AB.restoreBase()
  if not AB.config.baseColor then return end
  local c = AB.config.baseColor
  pcall(setBackgroundColor, "main", c[1], c[2], c[3], 255)
end

function AB.enable()
  AB.config.enabled = true
  AB.saveSettings()
  AB.apply()
  cecho("<grey>[MyDSL] Ambient background: <white>on\n")
end

function AB.disable()
  AB.config.enabled = false
  AB.saveSettings()
  AB.restoreBase()
  cecho("<grey>[MyDSL] Ambient background: <white>off\n")
end

function AB.toggle()
  if AB.config.enabled then AB.disable() else AB.enable() end
end

function AB.status()
  local totalMin = MyDSL.MoonWeather and MyDSL.MoonWeather.currentGameMinutes and MyDSL.MoonWeather.currentGameMinutes()
  local category = MyDSL.MoonWeather and MyDSL.MoonWeather.weatherCategory and MyDSL.MoonWeather.weatherCategory()
  cecho(string.format(
    "<grey>[MyDSL] Ambient background: <white>%s <grey>| weather: <white>%s <grey>| base: <white>%s\n",
    tostring(AB.config.enabled),
    tostring(category or "unknown"),
    AB.config.baseColor and string.format("%d,%d,%d", AB.config.baseColor[1], AB.config.baseColor[2], AB.config.baseColor[3]) or "not captured yet"
  ))
end

------------------------------------------------------------------------
-- Handlers + aliases
------------------------------------------------------------------------
local function _registerHandlers()
  local function reg(ev, fn)
    local ok, id = pcall(registerAnonymousEventHandler, ev, fn)
    if ok and id then AB._handlers[#AB._handlers + 1] = id end
  end
  -- Same two events MyDSL_MoonWeather itself re-renders on -- tick fires
  -- roughly every real 40s (30 DSL minutes), plenty smooth for a slow
  -- ambient gradient; weather fires whenever DSL's own weather changes.
  -- "Stale data beats spam" -- no separate polling timer added.
  reg("MyDSL.tick.updated",    function() AB.apply() end)
  reg("MyDSL.weather.updated", function() AB.apply() end)
end

local function _registerAliases()
  local function reg(pat, body)
    local id = tempAlias(pat, body)
    if id then AB._aliases[#AB._aliases + 1] = id end
  end
  reg([[^mydsl ambient on$]],     [[MyDSL.Ambient.enable()]])
  reg([[^mydsl ambient off$]],    [[MyDSL.Ambient.disable()]])
  reg([[^mydsl ambient toggle$]], [[MyDSL.Ambient.toggle()]])
  reg([[^mydsl ambient status$]], [[MyDSL.Ambient.status()]])
end

function AB.init()
  for _, id in ipairs(AB._handlers) do pcall(killAnonymousEventHandler, id) end
  for _, id in ipairs(AB._aliases)  do pcall(killAlias, id) end
  AB._handlers = {}
  AB._aliases  = {}

  AB.loadSettings()
  _registerHandlers()
  _registerAliases()
  AB.captureBase()
  if AB.config.enabled then AB.apply() end
end

AB.init()
