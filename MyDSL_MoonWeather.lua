
--[[=====================================================================
  MyDSL_MoonWeather.lua — Layer 3 Phase B
  Moon phase, weather description, and game-time HUD widget.

  Passive display only. Never sends game commands.
  Reads: MyDSL.State.lunar, .weather, .tick, .time, .score

  Design principles:
  - Adjustable.Container with lockStyle="padding": invisible handles,
    user can drag/resize, position auto-saves and auto-loads.
  - ONE Geyser.Label at 100%×100% inside the container.
  - All content rendered via label:echo(html) as an HTML table:
      Row 1 (50%) — three moon circles (Unicode fallback or img tag)
      Row 2 (25%) — focal moon phase/position/bonus text (colspan=3)
      Row 3 (25%) — day/night indicator + clock + date (colspan=3)
  - PNG images via <img> tag; Unicode ● colored circle fallback.

  Aliases:  mydsl moon toggle/on/off/font <n>/gag/ungag
  Events:   MyDSL.lunar.updated, .weather.updated, .tick.updated,
            .time.updated, .login.updated  (all from DataLayer via raiseEvent)
  Gag triggers: moon description lines, bonus stat lines → deleteLine()
                (default OFF — enable with mydsl moon gag)
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.MoonWeather = MyDSL.MoonWeather or {}

local MW = MyDSL.MoonWeather

-- Config persists across reloads — only assign missing fields.
-- This means a user's font change survives a script reload.
MW.config = MW.config or {}
if MW.config.shown    == nil then MW.config.shown    = true                end
if MW.config.font     == nil then MW.config.font     = "DejaVu Sans Mono"  end
if MW.config.fontSize == nil then MW.config.fontSize = 9                   end
if MW.config.opacity  == nil then MW.config.opacity  = 210                 end
if MW.config.gagLunar == nil then MW.config.gagLunar = false               end

-- Storage tables for cleanup on reload. We store the numeric IDs returned
-- by registerAnonymousEventHandler, tempRegexTrigger, and tempAlias so we
-- can kill them before re-registering fresh ones.
MW._handlers = MW._handlers or {}
MW._triggers = MW._triggers or {}
MW._aliases  = MW._aliases  or {}

-- UI object references (Geyser objects persist across script reloads).
MW.ui = MW.ui or {}

-- Live DSL clock state — persists across reloads so the clock continues smoothly.
-- Seeded from MyDSL.State.time (time command) on every time/tick event and on init().
MW._clock = MW._clock or {
  anchor_game_min = nil,   -- total DSL minutes 0-1439 at last anchor
  anchor_real     = nil,   -- os.time() at last anchor
}

-- Live lunar phase countdown state — persists across reloads.
-- Seeded from State.lunar on every lunar update and on init().
MW._lunar = MW._lunar or {
  anchor_cycles = nil,   -- cycles_remaining at last lunar parse
  anchor_real   = nil,   -- os.time() at last lunar parse
}


------------------------------------------------------------------------
-- CONSTANTS
------------------------------------------------------------------------

-- Maps every known game phase string → the file key used in PNG filenames.
-- Both word orders handled ("half waxing" and "waxing half" both appear in DSL).
-- Keys are the lowercase phase string exactly as the game sends it.
local phaseToFile = {
  ["full"]                    = "full",
  ["waning three-quarters"]   = "three_quarter_waning",
  ["three-quarter waning"]    = "three_quarter_waning",
  ["waning three-quarter"]    = "three_quarter_waning",
  ["half waning"]             = "half_waning",
  ["waning half"]             = "half_waning",
  ["crescent waning"]         = "crescent_waning",
  ["waning crescent"]         = "crescent_waning",
  ["empty"]                   = "empty",
  ["crescent waxing"]         = "crescent_waxing",
  ["waxing crescent"]         = "crescent_waxing",
  ["half waxing"]             = "half_waxing",
  ["waxing half"]             = "half_waxing",
  ["waxing three-quarters"]   = "three_quarter_waxing",
  ["three-quarter waxing"]    = "three_quarter_waxing",
  ["waxing three-quarter"]    = "three_quarter_waxing",
}

-- Short display label for each phase, used in Section 2 text below focal moon.
local phaseAbbrev = {
  ["full"]                    = "Full",
  ["waning three-quarters"]   = "3/4 Waning",
  ["three-quarter waning"]    = "3/4 Waning",
  ["waning three-quarter"]    = "3/4 Waning",
  ["half waning"]             = "Half Waning",
  ["waning half"]             = "Half Waning",
  ["crescent waning"]         = "Cres Waning",
  ["waning crescent"]         = "Cres Waning",
  ["empty"]                   = "Empty",
  ["crescent waxing"]         = "Cres Waxing",
  ["waxing crescent"]         = "Cres Waxing",
  ["half waxing"]             = "Half Waxing",
  ["waxing half"]             = "Half Waxing",
  ["waxing three-quarters"]   = "3/4 Waxing",
  ["three-quarter waxing"]    = "3/4 Waxing",
  ["waxing three-quarter"]    = "3/4 Waxing",
}

-- Wiki-confirmed mana/saves/casting bonuses, keyed by phase FILE key.
-- Always derivable from phase alone (no bonus block needed).
-- Regen%, cycles, and hours require the actual bonus block from `lunar`.
local phaseBonus = {
  ["full"]                 = { mana = 15, saves = -3, casting = 3 },
  ["three_quarter_waning"] = { mana = 10, saves = -2, casting = 2 },
  ["half_waning"]          = { mana = 10, saves = -2, casting = 2 },
  ["crescent_waning"]      = { mana = 5,  saves = -1, casting = 1 },
  ["empty"]                = { mana = 0,  saves = 0,  casting = 0 },
  ["crescent_waxing"]      = { mana = 5,  saves = -1, casting = 1 },
  ["half_waxing"]          = { mana = 10, saves = -2, casting = 2 },
  ["three_quarter_waxing"] = { mana = 10, saves = -2, casting = 2 },
}

-- Unicode fallback circle color when no PNG image is available.
local moonFallback = {
  red   = "#cc4444",
  white = "#dddddd",
  black = "#444444",
}

-- HTML color for each moon position string in the Section 2 display.
local positionColor = {
  ["high sanction"] = "#ffdd00",
  ["rising"]        = "#aaaaaa",
  ["setting"]       = "#aaaaaa",
  ["not visible"]   = "#555555",
}

-- Which moons go in which display slots for each focal alignment.
-- focal=red: white left, red center, black right
-- focal=white: black left, white center, red right
-- focal=black: red left, black center, white right
local slotOrder = {
  red   = { left = "white", center = "red",   right = "black" },
  white = { left = "black", center = "white", right = "red"   },
  black = { left = "red",   center = "black", right = "white" },
}


------------------------------------------------------------------------
-- HELPERS
------------------------------------------------------------------------

-- Strips leading and trailing whitespace from a string.
local function trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Returns true if the file at path can be opened for reading.
-- Used to decide whether to show a PNG or the Unicode fallback.
local function fileExists(path)
  local f = io.open(path, "r")
  if f then f:close(); return true end
  return false
end

-- Returns the base directory where moon phase PNG images live.
local function imageBase()
  local home = getMudletHomeDir and getMudletHomeDir() or "."
  return home .. "/DSL2/moon_phases/"
end

-- Returns the English ordinal suffix for a day number (1→"st", 2→"nd", etc.).
-- Handles the 11/12/13 edge cases that always use "th".
local function ordinal(n)
  n = tonumber(n) or 0
  if n == 11 or n == 12 or n == 13 then return "th" end
  local r = n % 10
  if r == 1 then return "st"
  elseif r == 2 then return "nd"
  elseif r == 3 then return "rd"
  else return "th"
  end
end

-- Wraps text in an HTML color span for echo() output.
local function span(color, text)
  return string.format('<span style="color:%s;">%s</span>', color, tostring(text))
end


------------------------------------------------------------------------
-- LIVE CLOCK
------------------------------------------------------------------------
-- DSL time rate: each GMCP tick advances exactly 30 DSL minutes.
-- Rate = 30 / tick_avg DSL-min per real-sec, where tick_avg is the
-- smoothed real-time interval from TickSource (MyDSL.DB.tick.average).
-- MW.setClockAnchor() reads State.time and sets the reference point.
-- MW.clockStr() interpolates forward in real-time from the anchor.

function MW.setClockAnchor(tickStr)
  local str = tickStr
  if not str then
    local t = MyDSL.State and MyDSL.State.time
    if not (t and t.hour and t.ampm) then return end
    local min = t.minute or 0
    str = string.format("%d:%02d%s", t.hour, min, t.ampm)
  end
  local h, m, ap = str:match("(%d+):(%d+)([ap]m)")
  h = tonumber(h); m = tonumber(m)
  if not h then return end
  local h24 = (h % 12) + (ap == "pm" and 12 or 0)
  MW._clock.anchor_game_min = h24 * 60 + m
  MW._clock.anchor_real     = os.time()
end

function MW.clockStr()
  if not MW._clock.anchor_real then return "--:--" end
  local elapsed  = os.time() - MW._clock.anchor_real
  -- Each GMCP tick advances exactly 30 DSL minutes. Use the live smoothed
  -- tick interval from TickSource to eliminate systematic drift.
  -- Fallback to 40s before TickSource has accumulated enough data.
  local tick_avg = MyDSL.DB and MyDSL.DB.tick and MyDSL.DB.tick.average
  tick_avg = (tick_avg and tick_avg > 10) and tick_avg or 40
  local dsl_elapsed = elapsed * (30 / tick_avg)
  local total_min   = (MW._clock.anchor_game_min + dsl_elapsed) % (24 * 60)
  local h24  = math.floor(total_min / 60)
  local min  = math.floor(total_min % 60)
  local ap   = h24 >= 12 and "pm" or "am"
  local h12  = h24 % 12
  if h12 == 0 then h12 = 12 end
  return string.format("%d:%02d %s", h12, min, ap)
end


function MW.setLunarAnchor()
  local lunar = MyDSL.State and MyDSL.State.lunar
  if not lunar then return end
  -- Find whichever moon has the bonus block — that's the focal moon
  -- regardless of alignment (only the aligned moon gets bonuses from `lunar`).
  local moon = nil
  for _, color in ipairs({"red", "white", "black"}) do
    local m = lunar[color]
    if m and m.cycles_remaining then
      moon = m
      break
    end
  end
  if not moon then return end
  MW._lunar.anchor_cycles = moon.cycles_remaining
  MW._lunar.anchor_real   = (MyDSL.State.lunar and MyDSL.State.lunar.parsed_at) or os.time()
end

function MW.cyclesNow()
  if not MW._lunar.anchor_real then return nil end
  local tick_avg = MyDSL.DB and MyDSL.DB.tick and MyDSL.DB.tick.average
  tick_avg = (tick_avg and tick_avg > 10) and tick_avg or 40
  local elapsed_ticks = (os.time() - MW._lunar.anchor_real) / tick_avg
  return math.max(0, MW._lunar.anchor_cycles - elapsed_ticks)
end

function MW.countdownStr()
  local cycles = MW.cyclesNow()
  if not cycles then return nil end
  local cyc_int = math.floor(cycles)
  -- Derive hours from cyc_int (floored) so cycles and hours are consistent.
  -- Each 2 cycles = 1 game-hour. Odd remainder = 1/2 hour.
  local hours    = math.floor(cyc_int / 2)
  local has_half = (cyc_int % 2) == 1
  local hour_str = has_half and (hours .. " 1/2h") or (hours .. "h")
  return string.format("%dcy · %s", cyc_int, hour_str)
end


------------------------------------------------------------------------
-- PUBLIC: focalMoon()
------------------------------------------------------------------------
-- Returns "red", "white", or "black" based on character alignment.
--   red   = Neutral alignment (Kien's moon, the default)
--   white = Good alignment
--   black = Evil alignment
-- Uses case-insensitive string search so "True Neutral", "Chaotic Good",
-- "Lawful Evil" etc. all match without an exhaustive lookup table.
-- Defaults to "red" when alignment is not yet known (pre-score).

function MW.focalMoon()
  local align = (MyDSL.State and MyDSL.State.score and MyDSL.State.score.align) or nil
  if not align or align == "" then return "red" end
  local low = align:lower()
  if low:find("good") then return "white" end
  if low:find("evil") then return "black" end
  return "red"  -- neutral / unknown
end


------------------------------------------------------------------------
-- PUBLIC: phaseImage(color, phase)
------------------------------------------------------------------------
-- Constructs the full path to a moon phase PNG file.
-- Returns the path string, or nil if the phase string is not recognised.
-- Logs a warning via debugc() for unknown phases — these need adding to
-- the phaseToFile table when discovered in-game.
-- Does NOT check whether the file exists on disk — use fileExists() for that.

function MW.phaseImage(color, phase)
  if not phase or phase == "" then return nil end
  local key     = phase:lower()
  local fileKey = phaseToFile[key]
  if not fileKey then
    debugc("[MoonWeather] unknown phase string: " .. tostring(phase) ..
           " — add it to phaseToFile in MyDSL_MoonWeather.lua")
    return nil
  end
  return imageBase() .. "moon_" .. color .. "_" .. fileKey .. ".png"
end


------------------------------------------------------------------------
-- INTERNAL: moonSlotHtml(color, phase, isBlackHidden, isFocal)
------------------------------------------------------------------------
-- Returns an HTML string for one moon slot cell.
-- isFocal=true → larger circle (42pt) for the center slot.
-- isBlackHidden=true → permanent "not visible" dim display for the black
--   moon when the character is not evil (game mechanic, not a data gap).
-- PNG img tag used when the image file exists; Unicode ● fallback otherwise.

local function moonSlotHtml(color, phase, isBlackHidden, isFocal)
  if isBlackHidden then
    return '<span style="font-size:14pt; color:#1a1a1a;">&#x25CF;</span>' ..
           '<br><span style="font-size:5pt; color:#333333;">not visible</span>'
  end

  local path = phase and MW.phaseImage(color, phase)
  if path and fileExists(path) then
    local sz = isFocal and "32" or "20"
    return string.format(
      '<img src="file:///%s" width="%s" height="%s" style="vertical-align:middle;"/>',
      path, sz, sz)
  end

  -- Unicode fallback — size difference (32pt vs 18pt) creates the focal emphasis.
  local c  = moonFallback[color] or "#888888"
  local pt = isFocal and "32pt" or "18pt"
  return string.format('<span style="font-size:%s; color:%s;">&#x25CF;</span>', pt, c)
end


------------------------------------------------------------------------
-- INTERNAL: buildFocalText(focal, lunarData)
------------------------------------------------------------------------
-- Builds the HTML for Section 2: the text block below the focal moon slot.
--
-- Three possible states:
--   No data yet  — shows a dim "?" (player has not run `lunar` this session)
--   Phase known, has_bonuses=false — phase + position + wiki bonus line
--   Phase known, has_bonuses=true  — adds regen/cycles/hours from actual `lunar`

local function buildFocalText(focal, lunarData)
  if not lunarData then
    -- No lunar data at all this session.
    return span("#555555", "?")
  end

  local moon = lunarData[focal]
  if not moon or not moon.phase or moon.phase == "" then
    return span("#555555", "?")
  end

  local phaseKey = moon.phase:lower()
  local abbrev   = phaseAbbrev[phaseKey] or moon.phase
  local pos      = moon.position or "not visible"
  local posCol   = positionColor[pos:lower()] or "#aaaaaa"
  local sep      = span("#444444", " &middot; ")

  -- Line 1: "Half Waxing · not visible"
  local html = span("#cccccc", abbrev) .. sep .. span(posCol, pos)

  -- Line 2: wiki-derived "+10%M  -2Sv  +2Cs" (shown whenever phase is known).
  local fileKey = phaseToFile[phaseKey]
  local bonus   = fileKey and phaseBonus[fileKey]
  if bonus then
    local manaCol = bonus.mana    ~= 0 and "#ffcc44" or "#888888"
    local savCol  = bonus.saves   ~= 0 and "#ffcc44" or "#888888"
    local casCol  = bonus.casting ~= 0 and "#ffcc44" or "#888888"

    html = html .. "<br>" ..
      span(manaCol, string.format("%+d%%M",  bonus.mana))    .. "  " ..
      span(savCol,  string.format("%+dSv",   bonus.saves))   .. "  " ..
      span(casCol,  string.format("%+dCs",   bonus.casting))

    -- Line 3: regen + live countdown — only present when bonus block was parsed.
    -- Regen is gold when non-zero. Countdown ticks down live via the 1-second timer.
    if moon.cycles_remaining then
      local regenCol  = (moon.regen_pct ~= 0) and "#ffcc44" or "#888888"
      local countdown = MW.countdownStr()
      html = html .. span(regenCol, string.format("Regen%+d%%", moon.regen_pct or 0))
      if countdown then
        html = html .. span("#888888", "  " .. countdown)
      end
    end
  end

  return html
end


------------------------------------------------------------------------
-- INTERNAL: buildTimeRow()
------------------------------------------------------------------------
-- Builds the HTML for Section 3: two stacked lines of time information.
--
-- Line 1: clock + indicator + period  ("1:34 am  ✦  Night", "3:00 am  ☀  Dawn")
--   Clock: #cccccc.  Indicator + period: colored by period.
--   Period label is abbreviated ("Night Time"→"Night", "Day Time"→"Day").
--
-- Line 2: date ("27th · Day of the Sun · Futility")
--   Source: db.day_num, State.time.day_name (or db.day_name), db.month.
--   month: "the Great Evil" stripped to "Great Evil" (removes "the " prefix).

local function buildTimeRow()
  local db = (MyDSL.DB and MyDSL.DB.time) or {}

  -- Determine indicator, color, and short period label.
  local period = MyDSL.State.time and MyDSL.State.time.period
  local indicator, periodColor
  if period == "Night Time" then
    indicator = "&#x2736;"; periodColor = "#8888cc"
  elseif period == "Dusk" then
    indicator = "&#x2736;"; periodColor = "#dd8844"
  elseif period == "Dawn" then
    indicator = "&#x2600;"; periodColor = "#dd8844"
  elseif period then
    indicator = "&#x2600;"; periodColor = "#ffdd88"
  else
    indicator   = db.is_night and "&#x2736;" or "&#x2600;"
    periodColor = db.is_night and "#8888cc"  or "#ffdd88"
  end
  local periodLabel
  if period == "Night Time" then
    periodLabel = "Night"
  elseif period == "Day Time" then
    periodLabel = "Day"
  elseif period then
    periodLabel = period
  else
    periodLabel = db.is_night and "Night" or "Day"
  end

  -- Line 1: "1:34 am  ✦  Night"
  local clockStr = MW.clockStr()
  local line1 = span("#cccccc", clockStr ~= "--:--" and clockStr or "--") ..
                "  " .. span(periodColor, indicator .. "  " .. periodLabel)

  -- Line 2: "27th · Day of the Sun · Futility"
  local line2
  local dayName = (MyDSL.State.time and MyDSL.State.time.day_name) or db.day_name
  if db.day_num and dayName and db.month then
    local dayStr     = "Day of " .. trim(dayName)
    local monthShort = tostring(db.month)
                         :gsub("^[Tt]he%s+[Mm]onth%s+[Oo]f%s+", "")
                         :gsub("^[Tt]he%s+", "")
    line2 = span("#888888",
      db.day_num .. ordinal(db.day_num) ..
      " &middot; " .. dayStr ..
      " &middot; " .. monthShort)
  else
    line2 = span("#888888", "--")
  end

  return line1 .. "<br>" .. line2
end


------------------------------------------------------------------------
-- PUBLIC: render()
------------------------------------------------------------------------
-- Builds one HTML table and calls MW.ui.label:echo(html).
-- Safe to call at any time — reads full current State on every call.
-- Three-row table: (1) moon circles, (2) focal text, (3) time row.

function MW.render()
  if not MW.ui.label then return end

  local focal  = MW.focalMoon()
  local order  = slotOrder[focal]
  local lunar  = MyDSL.State and MyDSL.State.lunar
  local isEvil = (focal == "black")

  local lColor = order.left
  local rColor = order.right
  local lHide  = (lColor == "black") and not isEvil
  local rHide  = (rColor == "black") and not isEvil

  local lMoon = lunar and lunar[lColor]
  local cMoon = lunar and lunar[focal]
  local rMoon = lunar and lunar[rColor]

  local leftHtml   = moonSlotHtml(lColor, lMoon and lMoon.phase, lHide,  false)
  local centerHtml = moonSlotHtml(focal,  cMoon and cMoon.phase, false,  true)
  local rightHtml  = moonSlotHtml(rColor, rMoon and rMoon.phase, rHide,  false)

  local focalText = buildFocalText(focal, lunar)
  local timeRow   = buildTimeRow()

  local html = string.format(
    '<table width="100%%" height="100%%" cellpadding="0" cellspacing="0"' ..
    ' style="table-layout:fixed;">' ..
    '<tr style="height:50%%;">' ..
      '<td width="22%%" style="text-align:center; vertical-align:middle;">%s</td>' ..
      '<td width="56%%" style="text-align:center; vertical-align:middle;">%s</td>' ..
      '<td width="22%%" style="text-align:center; vertical-align:middle;">%s</td>' ..
    '</tr>' ..
    '<tr style="height:20%%;">' ..
      '<td colspan="3" style="text-align:center; vertical-align:top;' ..
      ' font-size:7pt; color:#cccccc;">%s</td>' ..
    '</tr>' ..
    '<tr style="height:30%%;">' ..
      '<td colspan="3" style="text-align:center; vertical-align:middle;' ..
      ' font-size:8pt; color:#888888;">%s</td>' ..
    '</tr>' ..
    '</table>',
    leftHtml, centerHtml, rightHtml, focalText, timeRow)

  MW.ui.label:echo(html)
end


------------------------------------------------------------------------
-- PUBLIC: show(), hide(), toggle()
------------------------------------------------------------------------

function MW.show()
  MW.config.shown = true
  if MW.ui.container then MW.ui.container:show() end
end

function MW.hide()
  MW.config.shown = false
  if MW.ui.container then MW.ui.container:hide() end
end

function MW.toggle()
  if MW.config.shown then MW.hide() else MW.show() end
end


-- Removed 2026-07-07 (full dead-code audit, per Steven): MW.onLunarUpdate/
-- onWeatherUpdate/onTickUpdate/onTimeUpdate/onLoginUpdate used to live here
-- as the public event handlers, but _registerHandlers() below was refactored
-- at some point to use inline anonymous closures instead (same logic,
-- duplicated inline) and these five named functions were never deleted or
-- called again from anywhere. Confirmed via a whole-codebase grep -- zero
-- references outside their own definitions.


------------------------------------------------------------------------
-- PUBLIC: _applyTextStyle()
------------------------------------------------------------------------
-- Applies the background color, font family, and font size stylesheet
-- to the text label. Public so the font alias can call it after changing
-- config.fontSize without re-running the full init().

function MW._applyTextStyle()
  if not MW.ui.label then return end
  MW.ui.label:setStyleSheet(string.format([[
    background-color: rgba(5, 8, 20, %d);
    border: none;
    border-radius: 0px;
    padding: 3px 6px;
    font-family: "%s";
    font-size: %dpt;
    color: #cccccc;
  ]], MW.config.opacity, MW.config.font, MW.config.fontSize))
end


------------------------------------------------------------------------
-- INTERNAL: _buildUI()
------------------------------------------------------------------------
-- Creates the Adjustable.Container and ONE Geyser.Label child (100%×100%).
-- Called only once — on first init(). Subsequent reloads skip this because
-- Geyser window objects survive Lua script reloads in Mudlet's process.
-- All content is rendered as an HTML table via label:echo(html) in render().

local function _buildUI()
  local layoutDef = MyDSL.Layout and MyDSL.Layout.get("MyDSL_MoonWeather")
  local defX = layoutDef and (math.floor(layoutDef.x * 100) .. "%") or "66%"
  local defY = layoutDef and (math.floor(layoutDef.y * 100) .. "%") or "0%"
  local defW = layoutDef and (math.floor(layoutDef.w * 100) .. "%") or "34%"
  local defH = layoutDef and (math.floor(layoutDef.h * 100) .. "%") or "10%"

  -- pcall guards against a name collision if WindowRegistry already created
  -- this container; fall back to fetching it from the registry.
  local ok, container = pcall(function()
    return Adjustable.Container:new({
      name          = "MyDSL_MoonWeather",
      x             = defX,
      y             = defY,
      width         = defW,
      height        = defH,
      lockStyle     = "padding",
      adjLabelstyle = "background-color: rgba(0,0,0,0); border: none; padding: 0px;",
    })
  end)

  if not ok or not container then
    debugc("[MoonWeather] Container:new() failed: " .. tostring(container) ..
           " — trying WindowRegistry fallback")
    container = MyDSL.Windows and MyDSL.Windows.get("MyDSL_MoonWeather")
    if not container then
      debugc("[MoonWeather] FATAL: cannot create or find container. init() aborted.")
      return
    end
  end

  MW.ui.container = container

  pcall(function() container:setTitle(" ") end)   -- minimize title bar chrome
  pcall(function() container:setAutoSave(true) end)
  pcall(function() container:setAutoLoad(true) end)

  -- Single label — all content is HTML echo(). No pixel math needed.
  MW.ui.label = Geyser.Label:new({
    name   = "MW_mainLabel",
    x      = "0%", y = "0%",
    width  = "100%", height = "100%",
  }, container)

  MW._applyTextStyle()
end


------------------------------------------------------------------------
-- INTERNAL: _registerHandlers()
------------------------------------------------------------------------
-- Registers anonymous event listeners for the four data sections.
-- DataLayer emits "MyDSL.<section>.updated" via raiseEvent() after every
-- update() call. We listen for the sections MoonWeather cares about.
-- IDs stored in MW._handlers for clean deregistration on reload.

local function _registerHandlers()
  local function reg(ev, fn)
    local ok, id = pcall(registerAnonymousEventHandler, ev, fn)
    if ok and id then
      MW._handlers[#MW._handlers + 1] = id
    else
      debugc("[MoonWeather] failed to register handler for " .. ev)
    end
  end

  reg("MyDSL.lunar.updated",   function()
    MW.setLunarAnchor()   -- anchor cycles_remaining when lunar data arrives
    MW.render()
  end)
  reg("MyDSL.weather.updated", function() MW.render() end)
  -- Tick handler always re-anchors with the exact gmcp.tick.time string (zero drift).
  -- Time handler only anchors when no tick anchor exists yet (first login seed).
  reg("MyDSL.tick.updated",    function()
    local tickStr = gmcp and gmcp.tick and gmcp.tick.time
    MW.setClockAnchor(tickStr)   -- reanchor every tick with exact DSL time
    MW.render()
  end)
  reg("MyDSL.time.updated",    function()
    if not MW._clock.anchor_real then MW.setClockAnchor(nil) end
    MW.render()
  end)
  reg("MyDSL.login.updated",   function() MW.render() end)
  -- Added 2026-07-11, per Steven's "can we pull all timers off one tick"
  -- question: this replaces MW.startClockTimer()'s own independent
  -- tempTimer(1, loop) self-reschedule chain -- the exact same once/sec
  -- cadence, just riding TickSource's shared MyDSL.Timers.Slow event
  -- instead of running a second, separate timer loop for it. Confirmed via
  -- audit this was the only other self-perpetuating timer loop anywhere in
  -- the profile besides TickSource's own; now there's just the one.
  reg("MyDSL.Timers.Slow", function() if MW.ui.label then MW.render() end end)
end


------------------------------------------------------------------------
-- INTERNAL: _registerTriggers()
------------------------------------------------------------------------
-- Registers gag triggers that suppress the `lunar` output from the main
-- console so it is captured silently into MyDSL.State.lunar without
-- appearing in game text.
--
-- Why DataLayer still gets the data:
--   DataLayer's lunarBegin trigger was registered at profile load time
--   (before MoonWeather). Mudlet fires triggers in registration order,
--   so DataLayer parses the line first. Then our deleteLine() fires.
--
-- Trigger patterns use PCRE (not Lua %patterns) because tempRegexTrigger
-- uses Mudlet's PCRE engine.

local function _registerTriggers()
  if not MW.config.gagLunar then return end

  -- Gag moon description lines: "The red moon is full and not visible."
  local id1 = tempRegexTrigger("^The (red|white|black) moon is",
    function() deleteLine() end)
  if id1 then MW._triggers[#MW._triggers + 1] = id1 end

  -- Gag bonus stat lines: "   [Mana   0%]  [Saves  0]  ..."
  -- PCRE \s+ matches one or more whitespace characters.
  local id2 = tempRegexTrigger([[^\s+\[Mana]],
    function() deleteLine() end)
  if id2 then MW._triggers[#MW._triggers + 1] = id2 end
end


------------------------------------------------------------------------
-- PUBLIC: setGag(enabled)
------------------------------------------------------------------------
-- Toggles suppression of `lunar` command output in the main console.
-- Default is OFF (gagLunar=false) — output remains visible.
-- Call MW.setGag(true) or alias "mydsl moon gag" to suppress output.

function MW.setGag(enabled)
  for _, id in ipairs(MW._triggers) do pcall(killTrigger, id) end
  MW._triggers = {}
  MW.config.gagLunar = enabled
  if enabled then _registerTriggers() end
  debugc("[MoonWeather] gag " .. (enabled and "ON" or "OFF"))
end


------------------------------------------------------------------------
-- INTERNAL: _registerAliases()
------------------------------------------------------------------------
-- Registers the player-facing control aliases for the widget.
-- Alias patterns use PCRE. Alias bodies are Lua code strings.

local function _registerAliases()
  local function reg(pat, body)
    local id = tempAlias(pat, body)
    if id then MW._aliases[#MW._aliases + 1] = id end
  end

  -- Visibility control
  reg([[^mydsl moon toggle$]], [[MyDSL.MoonWeather.toggle()]])
  reg([[^mydsl moon on$]],     [[MyDSL.MoonWeather.show()]])
  reg([[^mydsl moon off$]],    [[MyDSL.MoonWeather.hide()]])

  -- Font size: "mydsl moon font 11" → change fontSize, re-apply stylesheet, re-render.
  -- matches[2] is the captured digit group from the PCRE pattern.
  reg([[^mydsl moon font (\d+)$]], [[
    MyDSL.MoonWeather.config.fontSize = tonumber(matches[2]) or 9
    MyDSL.MoonWeather._applyTextStyle()
    MyDSL.MoonWeather.render()
  ]])

  -- Gag control — suppress or restore `lunar` output in the main console.
  reg([[^mydsl moon gag$]],   [[MyDSL.MoonWeather.setGag(true)]])
  reg([[^mydsl moon ungag$]], [[MyDSL.MoonWeather.setGag(false)]])
end


------------------------------------------------------------------------
-- PUBLIC: init()
------------------------------------------------------------------------
-- Main entry point. Creates the widget on first call; on subsequent calls
-- (script reload) it cleans up the previous listeners and re-registers
-- fresh ones without touching the Geyser objects.
--
-- Required order:
--   1. Kill previous _handlers, _triggers, _aliases
--   2. Create Adjustable.Container + single Geyser.Label (first call only)
--   3. Apply label stylesheet
--   4. Register event handlers → store IDs in _handlers
--   5. Register gag triggers   → store IDs in _triggers
--   6. Register aliases        → store IDs in _aliases
--   7. Call render() immediately + deferred 0.5s render in case Geyser
--      hasn't finished layout before the first paint

function MW.init()
  -- Step 1: Kill everything from the previous load to prevent duplicate listeners.
  for _, id in ipairs(MW._handlers) do pcall(killAnonymousEventHandler, id) end
  MW._handlers = {}
  for _, id in ipairs(MW._triggers) do pcall(killTrigger, id) end
  MW._triggers = {}
  for _, id in ipairs(MW._aliases) do pcall(killAlias, id) end
  MW._aliases = {}

  -- Step 2: Build the container and label only on first init.
  -- Both container and label survive Lua script reloads as Geyser objects.
  if not MW.ui.container then
    _buildUI()
  end

  -- Guard: if _buildUI() failed, bail out gracefully.
  if not MW.ui.container or not MW.ui.label then
    debugc("[MoonWeather] init() aborted — container or label unavailable.")
    return
  end

  -- Step 3: Re-apply label stylesheet (picks up any config changes between reloads).
  MW._applyTextStyle()

  -- Steps 4–6: Register fresh handlers, triggers, and aliases.
  _registerHandlers()
  _registerTriggers()
  _registerAliases()

  -- Step 7: Render now (placeholder state if no data yet), and again after
  -- 0.5s to catch the case where Geyser finishes layout after init() returns.
  MW.render()
  tempTimer(0.5, function() if MW.ui.label then MW.render() end end)

  -- Seed live clock from State.time (if already available at startup).
  -- The clock is kept moving forward in real-time by the MyDSL.Timers.Slow
  -- handler registered in _registerHandlers() above (shared 1/sec heartbeat
  -- from TickSource, not a separate timer loop -- see that handler's comment).
  local tickStr = gmcp and gmcp.tick and gmcp.tick.time
  MW.setClockAnchor(tickStr)   -- prefer gmcp at startup; falls back to State.time
  MW.setLunarAnchor()          -- seed countdown if lunar data already loaded

  -- Apply visibility from config (hide immediately if saved as hidden).
  if not MW.config.shown then
    MW.ui.container:hide()
  end

  debugc("[MyDSL] MoonWeather initialized. Focal moon: " .. MW.focalMoon())
end

-- Auto-boot when this file is loaded.
MW.init()
