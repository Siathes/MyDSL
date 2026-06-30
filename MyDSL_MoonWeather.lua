
--[[=====================================================================
  MyDSL_MoonWeather.lua — Layer 3 Phase B
  Moon phase, weather description, and game-time HUD widget.

  Passive display only. Never sends game commands.
  Reads: MyDSL.State.lunar, .weather, .tick, .time, .score

  Design principles:
  - Adjustable.Container with lockStyle="padding": invisible handles,
    user can drag/resize, position auto-saves and auto-loads.
  - Three image labels for moon slots (top 55%):
      left slot    — non-focal side moon (small)
      center slot  — focal moon (wider, aligned to player)
      right slot   — other non-focal side moon (small)
  - One text label for Sections 2+3 (bottom 45%):
      Section 2 — phase/position/bonus text below focal moon only
      Section 3 — day/night indicator + clock + date row
  - PNG images via setStyleSheet background-image; Unicode ● fallback.

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
-- INTERNAL: applyMoonSlot(label, color, phase, isBlackHidden)
------------------------------------------------------------------------
-- Updates one image label to display the moon phase.
--
-- isBlackHidden: true for the black moon slot when the character is not
-- evil. The black moon is permanently invisible to neutral/good characters
-- (game lore). We show a very dark dim circle instead of a fallback.
--
-- When a valid PNG exists the label uses CSS background-image.
-- When no PNG is found or the phase is unknown, we echo a large Unicode
-- filled circle (&#x25CF; = ●) in the moon's canonical color.

local function applyMoonSlot(label, color, phase, isBlackHidden)
  if not label then return end

  -- Black moon hidden from non-evil characters: permanent game mechanic.
  if isBlackHidden then
    label:setStyleSheet("background-color: rgba(0,0,0,0); background-image: none;")
    label:echo('<center><span style="color:#222222; font-size:18pt; line-height:120%;">&#x25CF;</span><br>' ..
               '<span style="color:#333333; font-size:6pt;">not visible</span></center>')
    return
  end

  local path = MW.phaseImage(color, phase)
  if path and fileExists(path) then
    -- PNG found — display via CSS background-image on the label.
    label:setStyleSheet(string.format(
      "background-color: rgba(0,0,0,0);" ..
      "background-image: url('%s');" ..
      "background-repeat: no-repeat;" ..
      "background-position: center;" ..
      "background-size: contain;",
      path
    ))
    label:echo("")  -- clear any previous fallback text
  else
    -- No image — show a colored Unicode circle in this moon's color.
    local c = moonFallback[color] or "#888888"
    label:setStyleSheet("background-color: rgba(0,0,0,0); background-image: none;")
    label:echo(string.format(
      '<center><span style="color:%s; font-size:36pt; line-height:100%%;">&#x25CF;</span></center>',
      c
    ))
  end
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
    -- Positive mana/casting = green (good). Negative saves = green (lower save = better).
    local manaCol = bonus.mana    > 0 and "#44cc44" or (bonus.mana    < 0 and "#cc4444" or "#888888")
    local savCol  = bonus.saves   < 0 and "#44cc44" or (bonus.saves   > 0 and "#cc4444" or "#888888")
    local casCol  = bonus.casting > 0 and "#44cc44" or (bonus.casting < 0 and "#cc4444" or "#888888")

    html = html .. "<br>" ..
      span(manaCol, string.format("%+d%%M",  bonus.mana))    .. "  " ..
      span(savCol,  string.format("%+dSv",   bonus.saves))   .. "  " ..
      span(casCol,  string.format("%+dCs",   bonus.casting))

    -- Line 3: regen/cycles/hours — only present when bonus block was parsed.
    -- These values require the actual `lunar` command output, not the wiki table.
    if moon.has_bonuses and moon.regen_pct ~= nil then
      html = html .. span("#888888", string.format(
        "  Regen%+d%%  %dcy %dh",
        moon.regen_pct        or 0,
        moon.cycles_remaining or 0,
        moon.hours_remaining  or 0
      ))
    end
  end

  return html
end


------------------------------------------------------------------------
-- INTERNAL: buildTimeRow()
------------------------------------------------------------------------
-- Builds the HTML for Section 3: the single time row at the bottom.
-- Layout: [day/night icon]  Clock · Day of Name · Date
--
-- Data sources:
--   Day/night indicator: MyDSL.State.tick.time ("Day Time", "Night Time", etc.)
--   Clock:               MyDSL.State.time.hour + .ampm
--   Day name:            MyDSL.State.time.day_name
--   Date:                MyDSL.State.time.day_num + .month

local function buildTimeRow()
  local tod      = (MyDSL.State and MyDSL.State.tick and MyDSL.State.tick.time) or nil
  local timeData = (MyDSL.State and MyDSL.State.time) or nil

  -- Determine day vs night for the indicator icon and text color.
  -- Dawn and Dusk count as day-side for indicator purposes.
  local isDay = tod and (tod:find("Day") or tod:find("Dawn") or tod:find("Dusk"))

  -- Day/night indicator — Unicode icon since images cannot go inside echo() HTML.
  -- PNGs (sun_small.png, night_sky.png) exist in moon_phases/ but Geyser labels
  -- can only show them via background-image CSS, not inline in HTML text.
  local indicator
  if isDay then
    indicator = span("#ffdd44", "&#x2600;")   -- ☀ SUN symbol
  else
    indicator = span("#8888cc", "&#x2736;")   -- ✦ STAR/SPARKLE symbol
  end

  -- Time-of-day text color (matches the time-of-day state name).
  local todColor = "#cccccc"
  if tod then
    if     tod:find("Night") then todColor = "#8888cc"
    elseif tod:find("Dawn")  then todColor = "#dd8844"
    elseif tod:find("Dusk")  then todColor = "#dd8844"
    elseif tod:find("Day")   then todColor = "#ffdd88"
    end
  end

  local sep = span("#444444", " &middot; ")

  -- Clock: "10:00 am" — DataLayer stores just the hour integer (minutes discarded
  -- by the capture pattern); DSL game time is conventionally shown on the hour.
  local clockText = "--"
  if timeData and timeData.hour and timeData.ampm then
    clockText = string.format("%d:00 %s", timeData.hour, timeData.ampm)
  end

  -- Day name: DataLayer stores "the Great Gods" (after "Day of "), so we
  -- prepend "Day of " to reconstruct "Day of the Great Gods".
  local dayText = "--"
  if timeData and timeData.day_name and trim(timeData.day_name) ~= "" then
    dayText = "Day of " .. timeData.day_name
  end

  -- Date: "26th the Month of the Great Evil"
  -- month field from DataLayer is "the Great Evil" (with "the" already included).
  local dateText = "--"
  if timeData and timeData.day_num and timeData.month and trim(timeData.month) ~= "" then
    dateText = string.format("%d%s the Month of %s",
      timeData.day_num, ordinal(timeData.day_num), timeData.month)
  end

  return indicator .. "  " ..
    span(todColor, clockText) ..
    sep ..
    span("#aaaaaa", dayText) ..
    sep ..
    span("#999999", dateText)
end


------------------------------------------------------------------------
-- PUBLIC: render()
------------------------------------------------------------------------
-- Rebuilds all visual content and pushes it to the widget labels.
-- Safe to call at any time — reads current State and re-renders from scratch.
-- All four event handlers and init() call this.

function MW.render()
  if not MW.ui.container then return end  -- UI not built yet

  local focal  = MW.focalMoon()
  local order  = slotOrder[focal]
  local lunar  = MyDSL.State and MyDSL.State.lunar
  local isEvil = (focal == "black")

  -- Section 1: Update the three moon image slots.

  -- Left slot — non-focal side moon.
  if MW.ui.leftImg then
    local lColor = order.left
    local lMoon  = lunar and lunar[lColor]
    local lPhase = lMoon and lMoon.phase
    -- Black moon is hidden (permanent) for neutral/good characters.
    local lHide  = (lColor == "black") and not isEvil
    applyMoonSlot(MW.ui.leftImg, lColor, lPhase, lHide)
  end

  -- Center slot — focal moon (receives Section 2 text underneath).
  if MW.ui.centerImg then
    local cMoon  = lunar and lunar[focal]
    local cPhase = cMoon and cMoon.phase
    applyMoonSlot(MW.ui.centerImg, focal, cPhase, false)
  end

  -- Right slot — other non-focal side moon.
  if MW.ui.rightImg then
    local rColor = order.right
    local rMoon  = lunar and lunar[rColor]
    local rPhase = rMoon and rMoon.phase
    local rHide  = (rColor == "black") and not isEvil
    applyMoonSlot(MW.ui.rightImg, rColor, rPhase, rHide)
  end

  -- Sections 2+3: Assemble combined HTML for the text label.
  if MW.ui.text then
    local focalText = buildFocalText(focal, lunar)
    local timeRow   = buildTimeRow()
    MW.ui.text:echo(focalText .. "<br>" .. timeRow)
  end
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


------------------------------------------------------------------------
-- PUBLIC EVENT HANDLERS
------------------------------------------------------------------------
-- One handler per data section. All four just call render() because
-- render() reads the full current State each time — no partial updates.

function MW.onLunarUpdate()   MW.render() end
function MW.onWeatherUpdate() MW.render() end
function MW.onTickUpdate()    MW.render() end
function MW.onTimeUpdate()    MW.render() end
function MW.onLoginUpdate()   MW.render() end


------------------------------------------------------------------------
-- PUBLIC: _applyTextStyle()
------------------------------------------------------------------------
-- Applies the background color, font family, and font size stylesheet
-- to the text label. Public so the font alias can call it after changing
-- config.fontSize without re-running the full init().

function MW._applyTextStyle()
  if not MW.ui.text then return end
  MW.ui.text:setStyleSheet(string.format([[
    background-color: rgba(5, 8, 20, %d);
    border: none;
    border-radius: 4px;
    padding: 3px 6px;
    font-family: "%s";
    font-size: %dpt;
    color: #cccccc;
  ]], MW.config.opacity, MW.config.font, MW.config.fontSize))
end


------------------------------------------------------------------------
-- INTERNAL: _buildUI()
------------------------------------------------------------------------
-- Creates the Adjustable.Container and the four Geyser.Label children.
-- Called only once — on first init(). Subsequent reloads skip this because
-- Geyser window objects survive Lua script reloads in Mudlet's process.
--
-- Child labels use pixel sizes derived from container:get_width/height()
-- because percentage sizing is unreliable inside Adjustable.Container.
-- Layout proportions:
--   leftImg:   x=0         y=0      w=sideW   h=imgH   (side moon, small)
--   centerImg: x=sideW     y=0      w=centerW h=imgH   (focal moon, wider)
--   rightImg:  x=sideW+cW  y=0      w=sideW   h=imgH   (side moon, small)
--   text:      x=0         y=imgH   w=cw      h=textH  (Sections 2+3)

local function _buildUI()
  -- Get the fractional default position from LayoutEngine.
  -- LayoutEngine stores fractions (0.0–1.0); Geyser accepts "N%" strings.
  local layoutDef = MyDSL.Layout and MyDSL.Layout.get("MyDSL_MoonWeather")
  local defX = layoutDef and (math.floor(layoutDef.x * 100) .. "%") or "66%"
  local defY = layoutDef and (math.floor(layoutDef.y * 100) .. "%") or "0%"
  local defW = layoutDef and (math.floor(layoutDef.w * 100) .. "%") or "34%"
  local defH = layoutDef and (math.floor(layoutDef.h * 100) .. "%") or "10%"

  -- Create the Adjustable.Container. lockStyle="padding" makes the resize
  -- handles invisible — clean HUD look with no visible border or edge line.
  -- pcall guards against a name collision if WindowRegistry already created
  -- a container with this name; in that case we fall back to the registry.
  local ok, container = pcall(function()
    return Adjustable.Container:new({
      name      = "MyDSL_MoonWeather",
      x         = defX,
      y         = defY,
      width     = defW,
      height    = defH,
      lockStyle = "padding",
    })
  end)

  if not ok or not container then
    -- Creation failed (likely duplicate name — WindowRegistry got there first).
    -- Try to grab the existing container from the registry instead.
    debugc("[MoonWeather] Container:new() failed: " .. tostring(container) ..
           " — trying WindowRegistry fallback")
    container = MyDSL.Windows and MyDSL.Windows.get("MyDSL_MoonWeather")
    if not container then
      debugc("[MoonWeather] FATAL: cannot create or find container. init() aborted.")
      return
    end
  end

  MW.ui.container = container

  -- AutoSave writes position to disk when the user moves the widget.
  -- AutoLoad restores saved position from AdjustableContainer/<name>.lua at startup.
  pcall(function() container:setAutoSave(true) end)
  pcall(function() container:setAutoLoad(true) end)

  -- Compute pixel dimensions for child labels.
  -- Percentage positioning is unreliable inside Adjustable.Container, so we
  -- measure the container after creation and position children in pixels.
  local cw = container:get_width()
  local ch = container:get_height()
  -- Side slots are 20% of container width each; center gets the remainder.
  local sideW   = math.floor(cw * 0.20)
  local centerW = cw - (sideW * 2)
  local imgH    = math.floor(ch * 0.55)
  local textH   = ch - imgH

  -- Three image labels — top 55% of the container, side-by-side.
  MW.ui.leftImg = Geyser.Label:new({
    name   = "MW_leftImg",
    x      = 0, y = 0,
    width  = sideW, height = imgH,
  }, container)

  -- Center slot is wider (~3x) than the side slots to emphasise the focal moon.
  MW.ui.centerImg = Geyser.Label:new({
    name   = "MW_centerImg",
    x      = sideW, y = 0,
    width  = centerW, height = imgH,
  }, container)

  MW.ui.rightImg = Geyser.Label:new({
    name   = "MW_rightImg",
    x      = sideW + centerW, y = 0,
    width  = sideW, height = imgH,
  }, container)

  -- Text label — bottom 45%, full width.
  -- This label holds Sections 2 and 3 as HTML via echo().
  MW.ui.text = Geyser.Label:new({
    name   = "MW_text",
    x      = 0, y = imgH,
    width  = cw, height = textH,
  }, container)

  -- Apply dark background and font styling to the text label.
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
  local events = {
    "MyDSL.lunar.updated",
    "MyDSL.weather.updated",
    "MyDSL.tick.updated",
    "MyDSL.time.updated",
    "MyDSL.login.updated",
  }
  for _, ev in ipairs(events) do
    local ok, id = pcall(registerAnonymousEventHandler, ev,
      function() MW.render() end)
    if ok and id then
      MW._handlers[#MW._handlers + 1] = id
    else
      debugc("[MoonWeather] failed to register handler for " .. ev)
    end
  end
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
-- Required order (from Contract_MoonWeather.md):
--   1. Kill previous _handlers, _triggers, _aliases
--   2. Create Adjustable.Container (first call only)
--   3. Create four child Geyser.Labels (first call only)
--   4. Apply text label stylesheet
--   5. Register event handlers → store IDs in _handlers
--   6. Register gag triggers   → store IDs in _triggers
--   7. Register aliases        → store IDs in _aliases
--   8. Call render()

function MW.init()
  -- Step 1: Kill everything from the previous load to prevent duplicate listeners.
  for _, id in ipairs(MW._handlers) do pcall(killAnonymousEventHandler, id) end
  MW._handlers = {}
  for _, id in ipairs(MW._triggers) do pcall(killTrigger, id) end
  MW._triggers = {}
  for _, id in ipairs(MW._aliases) do pcall(killAlias, id) end
  MW._aliases = {}

  -- Steps 2–3: Build the container and child labels only on first init.
  -- MW.ui.container will be nil on the very first load of this script.
  if not MW.ui.container then
    _buildUI()
  end

  -- Guard: if _buildUI() failed, bail out gracefully.
  if not MW.ui.container then
    debugc("[MoonWeather] init() aborted — container unavailable.")
    return
  end

  -- Step 4: Re-apply text stylesheet (covers the case where config changed
  -- between reloads, e.g. via the font alias on the previous session).
  MW._applyTextStyle()

  -- Steps 5–7: Register fresh handlers, triggers, and aliases.
  _registerHandlers()
  _registerTriggers()
  _registerAliases()

  -- Step 8: Render with current state. Shows "?" placeholders until `lunar` is run.
  MW.render()

  -- Apply visibility from config (hide immediately if saved as hidden).
  if not MW.config.shown then
    MW.ui.container:hide()
  end

  debugc("[MyDSL] MoonWeather initialized. Focal moon: " .. MW.focalMoon())
end

-- Auto-boot when this file is loaded.
MW.init()
