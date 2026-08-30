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
  - REDESIGNED 2026-08-30, same day, twice: first per Steven's own
    follow-up found in MyDSL Test's notes.json ("mydsl ambient will have
    to be much more subtle") -- strength values roughly halved. Then per
    his direct simplification request: "pick some subte but distinct
    colors for the weather, then have the time of day brighten or darken
    that color?" -- replaces the original four-keyframe two-color-per-
    weather gradient (a separate dawn/dusk hue AND a separate noon hue,
    with blend strength ALSO varying across the day) with a cleaner
    two-stage model: (1) each weather category has exactly ONE subtle,
    distinct base color -- no more separate dawn/dusk vs. noon hues;
    (2) a single smooth, continuous (cosine, not piecewise-linear)
    day/night curve adjusts that ONE color's lightness -- darkened
    toward black at midnight, full color at noon -- then that adjusted
    color blends against the real console background at one constant,
    already-subtle strength. "Time of day brightens/darkens THAT color"
    literally describes step 2; the earlier "yellow to red to black"
    phrasing (Clear's own dawn-to-noon-to-dusk hue shift) is superseded
    by this simpler, explicitly-requested model rather than kept
    alongside it.

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
-- Weather palette -- ONE subtle, distinct base color per weather category
-- (see the header comment's 2026-08-30 redesign note). Subjective color
-- choices, first pass -- adjustable later if Steven wants different
-- ones, but each is a deliberate, weather-appropriate choice, not a
-- placeholder.
------------------------------------------------------------------------
local WEATHER_PALETTE = {
  Clear  = { 200, 165, 70 },   -- warm gold
  Cloudy = { 130, 130, 145 },  -- neutral slate grey
  Rain   = { 75,  100, 140 },  -- steel blue
  Storm  = { 120, 55,  85 },   -- deep plum-red
  Snow   = { 175, 195, 220 },  -- pale icy blue
  Sleet  = { 125, 140, 160 },  -- cool grey-blue
}

-- The one constant "how much of this tint shows through at all" cap --
-- replaces the old midnight/dawn-dusk/noon strength split now that
-- time-of-day is handled entirely by darkening/brightening the weather
-- color itself (see dayLightness() below), not by varying how strongly
-- it's blended in.
local DSL_AMBIENT_STRENGTH = 0.20

local function lerp(a, b, t) return a + (b - a) * t end

local function lerpColor(c1, c2, t)
  return {
    math.floor(lerp(c1[1], c2[1], t) + 0.5),
    math.floor(lerp(c1[2], c2[2], t) + 0.5),
    math.floor(lerp(c1[3], c2[3], t) + 0.5),
  }
end

local function clamp255(n) return math.max(0, math.min(255, n)) end

-- dayLightness(totalMin) -- smooth, continuous (cosine, not piecewise-
-- linear keyframes) 0..1 curve: 0 at midnight, 1 at noon. A cosine curve
-- means the color never visibly "kinks" at a fixed hour the way the old
-- 4-keyframe version could -- brightening/darkening reads as one smooth
-- sweep across the whole day, matching "brighten or darken that color"
-- literally.
local function dayLightness(totalMin)
  local angle = (totalMin - 720) / 1440 * 2 * math.pi
  return (math.cos(angle) + 1) / 2
end

-- computeColor(totalMin, category, baseColor) -- pure function, no game
-- state read directly, so it's fully unit-testable. Two stages: (1) the
-- weather's own single color is darkened toward black / brightened
-- toward its full saturation by dayLightness(); (2) that adjusted color
-- blends against the player's real snapshotted console background at
-- the one constant subtlety cap.
function AB.computeColor(totalMin, category, baseColor)
  local weatherColor = WEATHER_PALETTE[category] or WEATHER_PALETTE.Clear
  local L = dayLightness(totalMin % 1440)
  local adjusted = lerpColor({ 0, 0, 0 }, weatherColor, L)
  local blended = lerpColor(baseColor, adjusted, DSL_AMBIENT_STRENGTH)
  return { clamp255(blended[1]), clamp255(blended[2]), clamp255(blended[3]) }
end

------------------------------------------------------------------------
-- Fade -- added 2026-08-30 per Steven ("it will also need to fade
-- between colors so its not jarring"). Every apply() picks a fresh
-- target and steps the real console color toward it over
-- DSL_AMBIENT_FADE_SECONDS rather than snapping instantly -- matters
-- most on a weather change (an otherwise-instant hue jump) but also
-- smooths the small step apply() takes every real DSL tick. A
-- generation counter (not killTimer -- tempTimer's real id isn't a
-- stable handle to cancel by, see other modules in this codebase using
-- the same pattern) lets a new target simply supersede an in-flight
-- fade instead of fighting it: each queued step checks it's still the
-- newest fade before doing anything.
local DSL_AMBIENT_FADE_SECONDS = 2.0
local DSL_AMBIENT_FADE_STEPS   = 10

function AB.fadeTo(target)
  if not AB._currentApplied then
    -- Nothing to fade from yet (first apply this session) -- snap once.
    AB._currentApplied = target
    pcall(setBackgroundColor, "main", target[1], target[2], target[3], 255)
    return
  end
  AB._fadeGen = (AB._fadeGen or 0) + 1
  local myGen = AB._fadeGen
  local from = AB._currentApplied
  local function step(i)
    if myGen ~= AB._fadeGen then return end  -- superseded by a newer fade
    local c = lerpColor(from, target, i / DSL_AMBIENT_FADE_STEPS)
    pcall(setBackgroundColor, "main", c[1], c[2], c[3], 255)
    AB._currentApplied = c
    if i < DSL_AMBIENT_FADE_STEPS then
      tempTimer(DSL_AMBIENT_FADE_SECONDS / DSL_AMBIENT_FADE_STEPS, function() step(i + 1) end)
    end
  end
  step(1)
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
  AB.fadeTo(c)
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

-- restoreBase() -- deliberately instant, not faded (a deliberate "turn
-- it off" action, not a moment-to-moment gradient step). Also cancels
-- any in-flight fade and resets the fade's own "last applied" tracking,
-- so the NEXT apply() (e.g. after a later re-enable) fades from the
-- real restored base rather than from a stale mid-fade color.
function AB.restoreBase()
  if not AB.config.baseColor then return end
  AB._fadeGen = (AB._fadeGen or 0) + 1
  local c = AB.config.baseColor
  pcall(setBackgroundColor, "main", c[1], c[2], c[3], 255)
  AB._currentApplied = { c[1], c[2], c[3] }
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
