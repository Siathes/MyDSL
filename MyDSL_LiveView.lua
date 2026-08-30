
--[[=====================================================================
  MyDSL LiveView v1A15
  ----------------------------------------------------------------------
  Low-profile Room / Vitals window for MyDSL Alpha 1.

  Contract:
    - Display only.
    - Reads existing data sources:
        MyDSL.DB.live
        MyDSL.DB.score
        MyDSL.DB.xp
        MyDSL.DB.improve
        MyDSL.DB.time
        MyDSL.DB.timers
        MyDSL.Location.roomData()
        MyDSL.DB.room fallback
        gmcp room fallback
    - Does not parse score/improve/time itself.
    - Does not send game commands.
    - Uses Label-based bars, not Geyser.Gauge, to avoid GeyserColor issues.
    - Persists its own settings.
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.LiveView = MyDSL.LiveView or {}

local L = MyDSL.LiveView
L.version = "LiveView v1A15"
L.name = L.name or "MyDSL_Live"
L.title = L.title or "-= Live =-"

L.config = L.config or {}
L.config.shown = L.config.shown ~= false
L.config.font = tonumber(L.config.font or 10) or 10
L.config.titleFont = tonumber(L.config.titleFont or 12) or 12
L.config.barFont = tonumber(L.config.barFont or 9) or 9
-- Added 2026-07-11, per Steven ("let me be able to adjust the text size...
-- informational text, title text, terrain text, any others you have
-- separate"): infoFont covers the identity/info/attribute rows (was a
-- fixed font+3 offset with no independent setting); terrainFont covers
-- roomMeta specifically (was tied to the base font). titleFont/barFont
-- were already independently adjustable (mydsl live titlefont/barfont).
-- Default lowered 13 -> 9, 2026-08-29: baked in per Steven's live-test
-- request ("visual settings... that are set now, those need to be
-- defaults") -- 9 is what he actually set via `mydsl live infofont 9`
-- during the MyDSL Test session.
L.config.infoFont = tonumber(L.config.infoFont or 9) or 9
L.config.terrainFont = tonumber(L.config.terrainFont or 10) or 10
L.config.width = L.config.width or "34%"
L.config.height = L.config.height or "13%"
L.config.debug = L.config.debug == true

L.ui = L.ui or {}

local function ce(msg)
  cecho("\n<cyan>[MyDSL.Live]<reset> " .. tostring(msg) .. "\n")
end

local function trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function safeNum(v)
  v = tonumber(v)
  if v ~= nil then return v end
  return nil
end

local function pct(cur, max)
  cur, max = safeNum(cur), safeNum(max)
  if not cur or not max or max <= 0 then return 0 end
  local p = cur / max
  if p < 0 then p = 0 end
  if p > 1 then p = 1 end
  return p
end

local function percentNumber(s, fallback)
  local n = tostring(s or ""):match("([%d%.]+)%%")
  return tonumber(n) or fallback or 100
end


local function fmtNum(n)
  n = tonumber(n)
  if not n then return "--" end
  local s = tostring(math.floor(n))
  local left, num, right = string.match(s, "^([^%d]*%d)(%d*)(.-)$")
  if not left then return s end
  return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local function profileDir()
  local root = getMudletHomeDir and getMudletHomeDir() or "."
  return root .. "/MyDSL"
end

local function ensureDir(path)
  if lfs and lfs.mkdir then pcall(lfs.mkdir, path) end
  if os and os.execute then pcall(os.execute, "mkdir -p " .. string.format("%q", path)) end
end

function L.settingsFile()
  return profileDir() .. "/live_settings.lua"
end

function L.serializeSettings()
  local out = { "return {\n" }
  table.insert(out, string.format("  savedAt = %q,\n", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(out, string.format("  shown = %s,\n", L.config.shown and "true" or "false"))
  table.insert(out, string.format("  title = %q,\n", tostring(L.title or "-= Live =-")))
  table.insert(out, string.format("  font = %d,\n", tonumber(L.config.font) or 10))
  table.insert(out, string.format("  titleFont = %d,\n", tonumber(L.config.titleFont) or 12))
  table.insert(out, string.format("  barFont = %d,\n", math.max(8, tonumber(L.config.barFont) or 8)))
  table.insert(out, string.format("  infoFont = %d,\n", math.max(9, tonumber(L.config.infoFont) or 9)))
  table.insert(out, string.format("  terrainFont = %d,\n", math.max(8, tonumber(L.config.terrainFont) or 10)))
  table.insert(out, "}\n")
  return table.concat(out)
end

function L.saveSettings()
  ensureDir(profileDir())
  local file = L.settingsFile()
  local f = io.open(file, "w")
  if not f then ce("could not save settings: " .. tostring(file)); return false end
  f:write(L.serializeSettings())
  f:close()
  L.settingsLoaded = true
  L.settingsFilePath = file
  return true
end

function L.loadSettings()
  local file = L.settingsFile()
  local f = io.open(file, "r")
  if not f then L.settingsLoaded = false; L.settingsFilePath = file; return false end
  f:close()

  local ok, data = pcall(dofile, file)
  if not ok or type(data) ~= "table" then
    ce("could not load settings: " .. tostring(data))
    L.settingsLoaded = false
    L.settingsFilePath = file
    return false
  end

  if data.shown ~= nil then L.config.shown = data.shown == true end
  if data.title and tostring(data.title) ~= "" then L.title = tostring(data.title) end
  L.config.font = tonumber(data.font or L.config.font) or L.config.font
  L.config.titleFont = tonumber(data.titleFont or L.config.titleFont) or L.config.titleFont
  L.config.barFont = tonumber(data.barFont or L.config.barFont) or L.config.barFont
  L.config.infoFont = tonumber(data.infoFont or L.config.infoFont) or L.config.infoFont
  L.config.terrainFont = tonumber(data.terrainFont or L.config.terrainFont) or L.config.terrainFont
  L.settingsLoaded = true
  L.settingsFilePath = file
  return true
end

-- Migrated 2026-07-11 to pull from MyDSL.Theme instead of a hardcoded
-- literal -- was byte-for-byte duplicated in MyDSL_TickView.lua; both now
-- read the same ThemeEngine preset, so a theme switch reaches both.
-- Falls back to the original literal if ThemeEngine somehow isn't loaded
-- (load-order safety, matches this file's existing pcall-heavy style).
local function stylePanel()
  if MyDSL.Theme and MyDSL.Theme.panelCSS then
    return MyDSL.Theme.panelCSS(L.name)
  end
  return [[
    background-color: #0b1013;
    border: 1px solid #33434a;
    border-radius: 8px;
  ]]
end

local function styleText(size, color, weight, align)
  return string.format([[
    background-color: rgba(0,0,0,0);
    color: %s;
    border: 0px;
    font-family: "Noto Sans Mono", monospace;
    font-size: %dpt;
    font-weight: %s;
    qproperty-alignment: '%s';
  ]], color or "#dbe7ea", tonumber(size or L.config.font) or 9, weight or "normal", align or "AlignLeft")
end

local function styleDivider()
  local color = "#2b363b"
  if MyDSL.Theme then
    local ok, css = pcall(MyDSL.Theme.colorToCSS, MyDSL.Theme.get(L.name, "borderColor"))
    if ok and css then color = css end
  end
  return string.format([[
    background-color: %s;
    border: 0px;
  ]], color)
end

-- styleBarBack() -- theme-aware, added 2026-08-30 per Steven's tron_blue
-- follow-up ("maybe change the hp/mana/move bar to something similar but
-- more glassy looking"). The bar TRACK (housing), not the colored FILL,
-- now reads the active theme's own bgColor/borderColor -- HP/Mana/Move's
-- fill colors (L.colorSet()) stay hardcoded red/blue/green on purpose
-- (universal at-a-glance meaning, shouldn't shift with theme), but the
-- glass housing around them now matches whichever theme is active. This
-- is what actually delivers "glassy" for tron_blue specifically (a deep
-- near-black track with a glowing cyan edge) while also being a real
-- parity improvement for every other preset, not a tron-only special
-- case. Falls back to the original fixed slate colors if ThemeEngine
-- isn't loaded for any reason.
local function styleBarBack()
  local bg, border = "#10171b", "#43545c"
  if MyDSL.Theme and MyDSL.Theme.get and MyDSL.Theme.colorToCSS then
    local ok1, bgColor = pcall(MyDSL.Theme.get, L.name, "bgColor")
    local ok2, borderColor = pcall(MyDSL.Theme.get, L.name, "borderColor")
    if ok1 and bgColor then bg = MyDSL.Theme.colorToCSS(bgColor) end
    if ok2 and borderColor then border = MyDSL.Theme.colorToCSS(borderColor) end
  end
  return string.format([[
    background-color: %s;
    border: 1px solid %s;
    border-radius: 5px;
  ]], bg, border)
end

local function styleBarFill(c1, c2, c3)
  -- Reverted 2026-07-11, per Steven ("the bar style/look has changed from
  -- the previous, i prefer the previous style"): v1A15 briefly rounded
  -- only the left corners (5px 0 0 5px) for a "growing bar" look, but at
  -- 100% fill (the common case) the square right corners sat visibly
  -- mismatched against styleBarBack()'s fully-rounded track underneath.
  -- Back to matching, fully-rounded corners on both, as before.
  return string.format([[
    background-color: QLinearGradient(
      x1: 0, y1: 0, x2: 0, y2: 1,
      stop: 0 %s,
      stop: 0.48 %s,
      stop: 0.52 %s,
      stop: 1 %s
    );
    border: 1px solid #111111;
    border-radius: 5px;
  ]], c1, c2, c3, c2)
end

-- styleBarLabel()/styleBarNum() -- added 2026-07-11 for the v1A15 inline
-- bar layout (label, then track, then value, all in one row -- replaces
-- the old centered-text-on-the-fill look, which had nowhere to put a
-- label at all).
-- +1pt 2026-07-11, per Steven ("can the font be increased by 1 for the
-- information not the room info") -- these two plus the identity/info/
-- attribute rows below are "the information"; roomTitle/roomMeta/
-- exitsCon (the room name/terrain/exits) are deliberately left alone.

-- THEME_BAR_COLORS -- added 2026-08-30 for tron_blue specifically (per
-- Steven's direct follow-up, "id like to change the hp/mana/move into
-- tron colors appropriate or look, research tron themes"), renamed +
-- extended to every theme SAME DAY once he asked for a full "release
-- themes" pass ("now that you know all items... make it a whole teme
-- look... 2-3 randoms from previous themes that round it out"). Each
-- entry is a light/mid/dark triplet per bar for styleBarFill()'s
-- existing 3-stop gradient sheen -- HP/Mana/Move/Improve all get their
-- own palette now, not just tron_blue. Declared here, ahead of every
-- function that reads it (styleBarNumCentered() below, colorSet()
-- further down) -- Lua locals are only visible to code AFTER their own
-- declaration, so this must come first or those closures would silently
-- resolve THEME_BAR_COLORS as an undefined global instead.
--
-- tron_blue -- HP/Move from a documented Tron Legacy palette (huehive.co,
--   Neon Blue #00A3E0 / Neon Green #00FF00); Mana tuned by Steven
--   directly via the live interactive preview artifact (a yellow ->
--   orange -> red fire gradient, replacing the initial Electric Purple
--   research pick); Improve reuses that freed-up Electric Purple
--   (#A500FF, same researched palette).
-- muted_scroll_nature -- earthy/outdoors: terracotta HP, forest-teal
--   Mana, autumn-gold Move, mossy-sage Improve.
-- library -- indoors/bookish: wine-red HP, ink-blue Mana, brass-gold
--   Move, banker's-lamp-green Improve (matches the preset's own
--   goodColor choice for the same reason -- a real, recognizable
--   library object, not an arbitrary green).
-- pink_pastel -- soft accent family matching the preset's own dark-
--   plum-plus-pastel-accent design: dusty rose HP, lavender Mana, mint
--   Move, soft gold Improve.
-- obsidian_ember / arcane_midnight -- each theme's own accent hue
--   (ember orange-red / arcane violet) carried into HP, with the other
--   three bars picked for contrast against it, not copies of it.
local THEME_BAR_COLORS = {
  tron_blue = {
    hp      = { "#78d2f5", "#00a3e0", "#003c5a" },  -- Neon Blue
    mana    = { "#f6d32d", "#ff7800", "#e01b24" },  -- yellow -> orange -> red
    move    = { "#8cff8c", "#00ff00", "#005a00" },  -- Neon Green
    improve = { "#d9a3ff", "#a500ff", "#380066" },  -- Electric Purple
  },
  muted_scroll_nature = {
    hp      = { "#e08a6a", "#b8452a", "#4a1810" },  -- terracotta
    mana    = { "#8ac9b8", "#3f9478", "#1a3d30" },  -- forest teal
    move    = { "#c9a86a", "#8a6a2a", "#3d2e10" },  -- autumn gold-brown
    improve = { "#a8c98a", "#6a944a", "#2e4a1a" },  -- mossy sage
  },
  library = {
    hp      = { "#c96a6a", "#8a2a2a", "#3d1010" },  -- wine red
    mana    = { "#7a9ac9", "#2a4a8a", "#10203d" },  -- ink blue
    move    = { "#e0c07a", "#b8862a", "#4a3510" },  -- brass gold
    improve = { "#8ac98a", "#4a944a", "#1a4a1a" },  -- banker's-lamp green
  },
  pink_pastel = {
    hp      = { "#f5b8c8", "#e07a9a", "#8a3550" },  -- dusty rose
    mana    = { "#d0b8f5", "#a87ae0", "#5a3590" },  -- lavender
    move    = { "#b8f5d8", "#7ae0ab", "#359065" },  -- mint
    improve = { "#f5e0b8", "#e0b87a", "#906a35" },  -- soft gold
  },
  obsidian_ember = {
    hp      = { "#ff9a6a", "#e64a20", "#5a1a0a" },  -- ember orange-red
    mana    = { "#8a9ab8", "#3a4a68", "#151d2e" },  -- deep blue-grey
    move    = { "#e0c080", "#b88a30", "#4a3510" },  -- warm gold
    improve = { "#f0c080", "#d69440", "#5a3a10" },  -- amber (matches highlightColor)
  },
  arcane_midnight = {
    hp      = { "#e06a90", "#a82a5a", "#4a1030" },  -- crimson-violet
    mana    = { "#c090ff", "#8a3aff", "#3a1080" },  -- bright violet (matches theme)
    move    = { "#7ae0c0", "#2ab890", "#0f4a3a" },  -- teal (contrast)
    improve = { "#e0a0f0", "#b060d6", "#4a1a5a" },  -- violet-pink (matches highlightColor)
  },
}

local function styleBarLabel()
  return string.format([[
    background-color: rgba(0,0,0,0);
    color: #8b969b;
    border: 0px;
    font-family: "Noto Sans Mono", monospace;
    font-size: %dpt;
    font-weight: normal;
    qproperty-alignment: 'AlignLeft | AlignVCenter';
  ]], math.max(6, (tonumber(L.config.barFont) or 8) + 2))
end

local function styleBarNum()
  return string.format([[
    background-color: rgba(0,0,0,0);
    color: #cfd6d9;
    border: 0px;
    font-family: "Noto Sans Mono", monospace;
    font-size: %dpt;
    font-weight: bold;
    qproperty-alignment: 'AlignRight | AlignVCenter';
  ]], math.max(6, (tonumber(L.config.barFont) or 8) + 2))
end

-- styleBarNumCentered() -- Improve-bar-only, added 2026-07-12 per Steven
-- ("the improve bar need to be shrunk horizontally to allow the text to
-- display... or put the text on the improve bar (prefer text on the
-- improve bar, that was the old design)"). The Improve bar's num field
-- was the standard narrow right-of-track slot (7% wide) every other bar
-- uses, but Improve's text ("<skill> NN%") routinely runs longer than
-- HP/Mana/Move's plain percentages and was clipping past the window edge.
-- Rather than just widen that side slot, this restores the pre-v1A15
-- centered-text-on-the-fill look Steven asked for, Improve-only —
-- transparent background so the gradient fill shows through underneath.
-- Text color themed 2026-08-30 per Steven ("find a nice tron purple feel
-- for the improve bar and text"), generalized same day alongside every
-- other theme's own Improve palette (THEME_BAR_COLORS above) -- this
-- function is only ever used for the Improve bar (see the ternary at its
-- call site below), so reusing that same table here is unambiguous.
-- Reuses the bar's own "light" gradient stop as the text color -- already
-- a bright, legible tint in the bar's own hue family, so text and fill
-- always read as one cohesive accent instead of needing a second,
-- separately-tuned color table.
local function styleBarNumCentered()
  local color = "#f5f0ff"
  local active = MyDSL.Theme and MyDSL.Theme.active
  local themed = active and THEME_BAR_COLORS[active] and THEME_BAR_COLORS[active].improve
  if themed then color = themed[1] end
  return string.format([[
    background-color: rgba(0,0,0,0);
    color: %s;
    border: 0px;
    font-family: "Noto Sans Mono", monospace;
    font-size: %dpt;
    font-weight: bold;
    qproperty-alignment: 'AlignCenter';
  ]], color, math.max(6, (tonumber(L.config.barFont) or 8) + 2))
end

-- colorSet(kind) -- theme-conditional (see THEME_BAR_COLORS above):
-- a theme with no entry here keeps HP/Mana/Move's universal red/blue/
-- green (a real MUD-UI convention worth preserving as the default).
function L.colorSet(kind)
  local active = MyDSL.Theme and MyDSL.Theme.active
  local themed = active and THEME_BAR_COLORS[active]
  if themed and themed[kind] then
    local t = themed[kind]
    return t[1], t[2], t[3]
  end
  if kind == "hp" then return "#ff7777", "#cc2525", "#7d1010" end
  if kind == "mana" then return "#78baff", "#2a77d4", "#0d356d" end
  if kind == "move" then return "#83ff80", "#2baa39", "#0d5b18" end
  if kind == "improve" then return "#d7a7ff", "#8758c7", "#35204f" end
  if kind == "xp" then return "#d8b96a", "#a77426", "#4d3312" end
  return "#d0d0d0", "#808080", "#404040"
end

function L.roomData()
  if MyDSL and MyDSL.Location and MyDSL.Location.roomData then
    local ok, data = pcall(MyDSL.Location.roomData)
    if ok and type(data) == "table" then return data end
  end

  local candidates = {
    MyDSL and MyDSL.DB and MyDSL.DB.room,
    MyDSL and MyDSL.DB and MyDSL.DB.currentRoom,
    MyCore and MyCore.state and MyCore.state.gmcp and MyCore.state.gmcp.room_data,
    gmcp and gmcp.room_data,
    gmcp and gmcp.Room and gmcp.Room.Info,
  }

  for _, d in ipairs(candidates) do
    if type(d) == "table" then
      return {
        room = d.room or d.name or d.title,
        area = d.area or d.zone,
        terrain = d.terrain or d.sector,
        exits = d.exits,
        roomId = d.num or d.vnum or d.id,
        source = "fallback",
      }
    end
  end

  return {}
end

local function exitsText(exits)
  if type(exits) == "table" then
    local out = {}
    for k, v in pairs(exits) do
      if type(k) == "string" and v then table.insert(out, k)
      elseif type(v) == "string" then table.insert(out, v) end
    end
    table.sort(out)
    if #out > 0 then return table.concat(out, " ") end
  end
  return tostring(exits or "--")
end

-- improveLiveText() -- added 2026-07-11, per Steven: the "(<N> online
-- minutes to improvement)" value from `improve` (see DSL_Helpfiles/improve
-- improvement.txt + the confirmed real status line in DataLayer's
-- parseImproveStatusLine()) is a countdown to the NEXT percentage tick, not
-- a static label, but the bar just froze at whatever value was last read
-- from the server. "Online minutes" is real wall-clock time connected, NOT
-- a DSL server-tick interval (that conversion belongs to TickSource's
-- tick.average, a different quantity entirely) -- so this recomputes
-- directly from elapsed real seconds since imp.last_updated, no tick data
-- involved. Recomputed fresh on every call, so it only visibly counts down
-- because L.render() now gets a real once/sec heartbeat (MyDSL.Timers.Slow,
-- see installHandlers() below) to call it from.
local function improveLiveText(imp)
  if not imp or not imp.skill then return nil end
  local base = tostring(imp.skill) .. " " .. tostring(imp.percent or "?") .. "%"
  local remaining = tonumber(imp.remaining)
  if not remaining then return base end
  local elapsed = os.time() - (tonumber(imp.last_updated) or os.time())
  local secsLeft = math.max(0, remaining * 60 - elapsed)
  local mins = math.floor(secsLeft / 60)
  local secs = math.floor(secsLeft % 60)
  return base .. string.format(" (%dm%02ds)", mins, secs)
end

-- ageText(createdTs) -- added 2026-07-12, per Steven ("looks at score
-- creation date and uses in-game time to tell you when your ingame
-- birthday is and ingame age"). DSL's real-time-to-game-time ratio and
-- calendar shape aren't documented anywhere (checked DSL_Helpfiles and
-- docs/DSL_CommandRef.md) -- empirically derived instead, from the full
-- log/ archive: every month name that ever appears across the whole
-- corpus (Dragon/Sun/Heat/Battle/Nature/Futility/Dark Shades/Old Forces/
-- Grand Struggle/Spring -- exactly 10, confirmed via grep) gives 10
-- months/year; day numbers run 1-35 before rolling to the next month,
-- giving 35 days/month (350 days/year). The real-time-per-game-day rate
-- itself came from 64 clean single-in-game-day-step samples timestamped
-- against their source log files' real mtimes (trimmed mean of the
-- middle 70%, discarding outliers from AFK/offline gaps where the game
-- clock kept advancing but wasn't observed as often) -- ~35 real minutes
-- = 1 in-game day. Steven explicitly confirmed "approximate" is fine
-- (in-game day/month *names* aren't continuous across resets, so this
-- deliberately reports elapsed duration, not an absolute in-game date).
local REAL_MINUTES_PER_GAME_DAY = 35
local GAME_DAYS_PER_MONTH       = 35
local GAME_MONTHS_PER_YEAR      = 10
local GAME_DAYS_PER_YEAR        = GAME_DAYS_PER_MONTH * GAME_MONTHS_PER_YEAR

local function ageText(createdTs)
  createdTs = tonumber(createdTs)
  if not createdTs then return nil end
  local elapsedReal = os.time() - createdTs
  if elapsedReal < 0 then return nil end
  local gameDaysTotal = math.floor(elapsedReal / (REAL_MINUTES_PER_GAME_DAY * 60))
  local years  = math.floor(gameDaysTotal / GAME_DAYS_PER_YEAR)
  local rem    = gameDaysTotal % GAME_DAYS_PER_YEAR
  local months = math.floor(rem / GAME_DAYS_PER_MONTH)
  local days   = rem % GAME_DAYS_PER_MONTH
  if years > 0 then
    return string.format("%dy %dm", years, months)
  elseif months > 0 then
    return string.format("%dm %dd", months, days)
  else
    return string.format("%dd", days)
  end
end

function L.data()
  local db = MyDSL and MyDSL.DB or {}
  local live = db.live or {}
  local score = db.score or {}
  local timers = db.timers or {}
  local room = L.roomData() or {}
  local tm = timers.worldTime or db.time or {}
  local imp = timers.improve or db.improve or {}
  local xp = db.xp or {}
  local prompt = db.prompt or {}
  local pnpPrompt = _G.dslpnp and _G.dslpnp.prompt or nil

  local hp = live.hp or score.hp
  local maxhp = live.maxhp or score.maxhp
  local mana = live.mana or score.mana
  local maxmana = live.maxmana or score.maxmana
  local move = live.move or score.move
  local maxmove = live.maxmove or score.maxmove

  local xptotal = xp.total or score.xp or (pnpPrompt and tonumber(pnpPrompt.curxp))
  -- Real bug fixed 2026-07-11, found while testing the v1A15 TNL display:
  -- this never actually matched anything -- score.xpToLevel/xpToLevelText
  -- don't exist anywhere; the real bridged field (MyDSL_DataBridge.lua) is
  -- score.tnl. So TNL silently showed "--" in the old xpLine display too,
  -- not just newly broken here.
  local xpToLevel = xp.toLevel or score.tnl or prompt.xptnl or (pnpPrompt and tonumber(pnpPrompt.xptnl))
  local xppct = xp.percent or score.xpPercent
  if not xppct and score.level and tonumber(score.level) >= 51 then xppct = nil end

  local rawPromptExits = prompt.exits or (pnpPrompt and pnpPrompt.exits)

  return {
    roomName = trim(room.room or room.name or "Unknown Room"),
    area = trim(room.area or "--"),
    terrain = trim(room.terrain or "--"),
    exits = rawPromptExits or exitsText(room.exits),
    roomId = room.roomId or room.id or room.vnum,
    clock = tm.clock or (db.time and db.time.clock) or "--",
    day = tm.day or (db.time and db.time.day) or "",
    dayName = tm.dayName or (db.time and db.time.dayName) or "",
    ordinal = tm.ordinal or (db.time and db.time.ordinal) or "",
    month = tm.month or (db.time and db.time.month) or "",
    monthName = tm.monthName or (db.time and db.time.monthName) or "",
    hp = hp, maxhp = maxhp,
    mana = mana, maxmana = maxmana,
    move = move, maxmove = maxmove,
    xp = xptotal, xpPercent = xppct, xpToLevel = xpToLevel,
    improveText = improveLiveText(imp),
    improveSkill = imp.skill,
    improvePercent = imp.percent,
    improveRemaining = imp.remaining,
    combat = live.combat,
    stance = score.stance or live.stance,
    language = score.language or live.language,
    -- REAL BUG, found 2026-07-12 (Steven: "the ready flag does not
    -- update when fighting for example"): all 3 read from `live` (=
    -- MyDSL.DB.live), which only ever has hp/maxhp/mana/maxmana/move/
    -- maxmove/name/level (see MyDSL_DataBridge.lua's MyDSL.DB.live
    -- table) -- riding/flying/fighting only exist on `score` (=
    -- MyDSL.DB.score, correctly GMCP-sourced from char.is_riding/
    -- is_flying/is_fighting there). identityLine()'s READY/FIGHTING
    -- badge reads d.fighting directly, so this was permanently nil --
    -- the badge could never show FIGHTING, regardless of actual combat
    -- state. riding/flying aren't consumed by any renderer currently
    -- (confirmed via grep), so fixing them here is precautionary, not a
    -- second visible bug.
    riding = score.riding,
    flying = score.flying,
    fighting = score.fighting,
    vitality = score.vitality,
    chamber = score.chamber,

    -- Added 2026-07-11: the "populate Live with the score info" pass,
    -- per Steven's own hand-sketched layout (Downloads/"liveview layout").
    -- All of these read from MyDSL.DB.score, correct end-to-end since
    -- today's MyDSL_DataBridge.lua fix (hit/dam/armor were silently nil
    -- before that -- wrong key names -- see docs/CHANGELOG.md).
    name    = live.name,
    level   = live.level,
    race    = score.race,
    class_  = score.class_,
    align   = score.align,
    god     = score.religion,
    createdTs = score.createdTs,
    str = score.str, strBase = score.str_base,
    int_ = score.int, intBase = score.int_base,
    wis = score.wis, wisBase = score.wis_base,
    dex = score.dex, dexBase = score.dex_base,
    con = score.con, conBase = score.con_base,
    hitroll = score.hitroll, damroll = score.damroll,
    hitrollBase = score.hitrollBase, damrollBase = score.damrollBase,
    armorPierce = score.armorPierce, armorBash = score.armorBash,
    armorSlash = score.armorSlash, armorMagic = score.armorMagic,
    wimpy = score.wimpy,
    items = score.items, maxItems = score.max_items,
    weight = score.weight, maxWeight = score.maxWeight,
    gold = score.gold, silver = score.silver,
    bank = score.bank, qpoints = score.qpoints,
    posn = score.posn,
  }
end

-- v1A15 layout -- rebuilt 2026-07-11 per Steven's own hand-sketched design
-- (Downloads/"liveview layout"), refined through several Artifact passes.
-- Fits the window's CONFIRMED real pixel size (974x186 via "mydsl live
-- status") without resizing it -- this replaces v1A14's wide left/right
-- card split with a denser 2-column x 7-row grid:
--   room title (full width), terrain+exits (one line), a rule, then:
--   LEFT col:  HP/Mana/Move bars, gap, identity, pos'n/wimpy/items/weight,
--              bank/gold/silver/qpoints
--   RIGHT col: STR+Armor, INT+Hit/Dam, WIS+Stance, DEX+TNL, CON, gap,
--              Improve bar
-- No more compact/full mode -- per Steven, "i dont think we need a
-- compact ful anymore, this will be the standard layout for now."
local ROW_Y = { 33, 42, 51, 60, 69, 78, 87 }
-- 8 -> 8.7, 2026-07-11 per Steven ("size the text and spacing to make it
-- look more filled") -- row SLOTS (ROW_Y) are unchanged, each row just
-- uses more of its own 9%-wide slot instead of leaving a bigger gap.
local ROW_H = 8.7

function L.ensureUI()
  if L.ui.win and L.ui.panel then return true end

  local WinClass = Geyser and (Geyser.UserWindow or Geyser.Window)
  if not WinClass then ce("Geyser.UserWindow unavailable"); return false end

  L.ui.win = WinClass:new({
    name = L.name,
    x = "32%",
    y = "77%",
    width = L.config.width,
    height = L.config.height,
  })

  if L.ui.win.setTitle then pcall(function() L.ui.win:setTitle(L.title) end) end

  L.ui.panel = Geyser.Label:new({ name=L.name.."_Panel", x=0, y=0, width="100%", height="100%" }, L.ui.win)

  -- Header: room title, then terrain+exits on one line, then a rule.
  -- Widened 2026-07-12 from 80% to 96% (matching the row below's/hRule's
  -- own established 2%-margin convention in this same file), per Steven
  -- ("room title line wraps, it needs to not, and spread across the top
  -- row, that's why its so long") -- the title had 20% of the row sitting
  -- unused next to it the whole time, forcing splitRoomName() below to
  -- manually break long names onto a second line well before it needed to.
  L.ui.roomTitle = Geyser.Label:new({ name=L.name.."_RoomTitle", x="2%", y="2%",  width="96%", height="16%" }, L.ui.win)
  L.ui.roomMeta  = Geyser.Label:new({ name=L.name.."_RoomMeta",  x="2%", y="19%", width="12%", height="10%" }, L.ui.win)
  L.ui.exitsCon  = Geyser.MiniConsole:new({ name=L.name.."_ExitsCon", x="15%", y="19%", width="83%", height="10%" }, L.ui.win)
  L.ui.hRule     = Geyser.Label:new({ name=L.name.."_HRule", x="2%", y="30%", width="96%", height="1px" }, L.ui.win)

  -- Vertical divider between the two body columns, spanning row 1's top
  -- to row 7's bottom.
  L.ui.vDivider  = Geyser.Label:new({ name=L.name.."_Divider", x="59.5%", y=tostring(ROW_Y[1]).."%", width="1px",
                                       height=tostring(ROW_Y[7] + ROW_H - ROW_Y[1]).."%" }, L.ui.win)

  -- LEFT column: bars (rows 1-3), identity (row 5), info grids (rows 6-7).
  L.ui.bars = {}
  -- Track widened 2026-07-11 (28 -> 36), per Steven ("expand the health/
  -- mana/move bars horizontally to fill in more space between their name
  -- and numbers") -- label narrowed slightly (7 -> 5, "Mana" doesn't need
  -- 7%) and the small inter-element gaps removed (label/track/num now sit
  -- edge-to-edge), with the freed width going to the track.
  L.ui.bars.hp      = L.makeBar("hp",      "HP",      2, 7, 44,  5, 36, 14, ROW_Y[1], ROW_H)
  L.ui.bars.mana    = L.makeBar("mana",    "Mana",    2, 7, 44,  5, 36, 14, ROW_Y[2], ROW_H)
  L.ui.bars.move    = L.makeBar("move",    "Move",    2, 7, 44,  5, 36, 14, ROW_Y[3], ROW_H)
  -- row 4 (y=ROW_Y[4]) is left blank on this side, per the sketch.

  L.ui.identity  = Geyser.Label:new({ name=L.name.."_Identity", x="2%", y=tostring(ROW_Y[5]).."%", width="56%", height=tostring(ROW_H).."%" }, L.ui.win)
  L.ui.infoLine1 = Geyser.Label:new({ name=L.name.."_InfoLine1", x="2%", y=tostring(ROW_Y[6]).."%", width="56%", height=tostring(ROW_H).."%" }, L.ui.win)
  L.ui.infoLine2 = Geyser.Label:new({ name=L.name.."_InfoLine2", x="2%", y=tostring(ROW_Y[7]).."%", width="56%", height=tostring(ROW_H).."%" }, L.ui.win)

  -- RIGHT column: STR/INT/WIS/DEX/CON (rows 1-5), Improve bar (row 7).
  L.ui.attrStr = Geyser.Label:new({ name=L.name.."_AttrStr", x="61%", y=tostring(ROW_Y[1]).."%", width="37%", height=tostring(ROW_H).."%" }, L.ui.win)
  L.ui.attrInt = Geyser.Label:new({ name=L.name.."_AttrInt", x="61%", y=tostring(ROW_Y[2]).."%", width="37%", height=tostring(ROW_H).."%" }, L.ui.win)
  L.ui.attrWis = Geyser.Label:new({ name=L.name.."_AttrWis", x="61%", y=tostring(ROW_Y[3]).."%", width="37%", height=tostring(ROW_H).."%" }, L.ui.win)
  L.ui.attrDex = Geyser.Label:new({ name=L.name.."_AttrDex", x="61%", y=tostring(ROW_Y[4]).."%", width="37%", height=tostring(ROW_H).."%" }, L.ui.win)
  L.ui.attrCon = Geyser.Label:new({ name=L.name.."_AttrCon", x="61%", y=tostring(ROW_Y[5]).."%", width="37%", height=tostring(ROW_H).."%" }, L.ui.win)
  -- Row 6 on this side, previously left blank per the sketch, now used
  -- for dragon Vitality, added 2026-07-12 per Steven ("dragon vitality
  -- stat next for dragons/qinrathaz only... below con in the stats
  -- window"). Left blank (empty echo) for non-dragon characters, same
  -- as it always was -- see render() below.
  L.ui.attrVit = Geyser.Label:new({ name=L.name.."_AttrVit", x="61%", y=tostring(ROW_Y[6]).."%", width="37%", height=tostring(ROW_H).."%" }, L.ui.win)
  -- xNum/wNum match xTrack/wTrack (was 91/7, a separate slot past the
  -- track's right edge) so the text overlays the bar itself instead of
  -- sitting in a slot too narrow for "<skill> NN%" -- see
  -- styleBarNumCentered()'s comment above for the full reasoning. Track
  -- widened 2026-07-12 (18 -> 26) per Steven, now that the countdown text
  -- ("<skill> NN% (Mm SSs)") is longer and the overlay had room to grow --
  -- runs to 98%, matching the STR/INT/WIS/DEX/CON column's right edge
  -- (x=61%, width=37%) directly above it.
  L.ui.bars.improve = L.makeBar("improve", "Improve", 61, 72, 72, 10, 26, 26, ROW_Y[7], ROW_H)

  L.applyStyles()

  if L.config.shown then L.show(false) else L.hide(false) end
  return true
end

-- makeBar(key, labelText, xLabel, xTrack, xNum, wLabel, wTrack, wNum, y, h)
-- All x/y/w/h are plain numbers (percent of the window), not "N%" strings
-- -- kept as numbers so setBar()/setBarPercent() can compute the fill
-- width directly against bar.maxWidth (= wTrack) without re-parsing.
function L.makeBar(key, labelText, xLabel, xTrack, xNum, wLabel, wTrack, wNum, y, h)
  local bar = {}
  bar.maxWidth = wTrack
  bar.labelText = labelText
  local ys, hs = tostring(y) .. "%", tostring(h) .. "%"
  bar.label = Geyser.Label:new({ name=L.name.."_"..key.."_Label", x=tostring(xLabel).."%", y=ys, width=tostring(wLabel).."%", height=hs }, L.ui.win)
  bar.back  = Geyser.Label:new({ name=L.name.."_"..key.."_Back",  x=tostring(xTrack).."%", y=ys, width=tostring(wTrack).."%", height=hs }, L.ui.win)
  bar.fill  = Geyser.Label:new({ name=L.name.."_"..key.."_Fill",  x=tostring(xTrack).."%", y=ys, width="1%", height=hs }, L.ui.win)
  bar.num   = Geyser.Label:new({ name=L.name.."_"..key.."_Num",   x=tostring(xNum).."%", y=ys, width=tostring(wNum).."%", height=hs }, L.ui.win)
  pcall(function() bar.label:echo(labelText) end)
  return bar
end

-- titleColorCSS() -- theme's titleColor (matches the gold used elsewhere
-- in refined_convergence; switches per-theme, e.g. amber under
-- terminal_purist, violet under arcane_midnight).
local function titleColorCSS()
  if MyDSL.Theme then
    local ok, css = pcall(MyDSL.Theme.colorToCSS, MyDSL.Theme.get(L.name, "titleColor"))
    if ok and css then return css end
  end
  return "#ffd166"
end

function L.applyStyles()
  if not L.ui.panel then return end
  L.ui.panel:setStyleSheet(stylePanel())
  L.ui.roomTitle:setStyleSheet(styleText(L.config.titleFont, titleColorCSS(), "bold", "AlignLeft"))
  L.ui.roomMeta:setStyleSheet(styleText(math.max(8, L.config.terrainFont), "#8b969b", "normal", "AlignLeft"))
  if L.ui.exitsCon then
    pcall(function()
      L.ui.exitsCon:setFontSize(math.max(8, tonumber(L.config.font) or 10))
      local bg = MyDSL.Theme and MyDSL.Theme.get(L.name, "bgColor")
      if bg then
        L.ui.exitsCon:setColor(bg.r, bg.g, bg.b)
      else
        L.ui.exitsCon:setColor(11, 16, 19)
      end
      L.ui.exitsCon:setWrap(false)
    end)
  end
  if L.ui.hRule then L.ui.hRule:setStyleSheet(styleDivider()) end
  L.ui.vDivider:setStyleSheet(styleDivider())

  -- Rich-HTML rows (identity/info/attributes) -- their color comes from
  -- inline <span> markup written by render(), so the Label's own
  -- stylesheet only needs a transparent background and a base font/size.
  -- Independently adjustable 2026-07-11 via L.config.infoFont (was a
  -- fixed font+3 offset) -- "mydsl live infofont <n>".
  local rowFontSize = math.max(9, L.config.infoFont)
  for _, key in ipairs({ "identity", "infoLine1", "infoLine2", "attrStr", "attrInt", "attrWis", "attrDex", "attrCon", "attrVit" }) do
    if L.ui[key] then L.ui[key]:setStyleSheet(styleText(rowFontSize, "#e8e6e0", "normal", "AlignLeft")) end
  end

  for key, bar in pairs(L.ui.bars or {}) do
    bar.label:setStyleSheet(styleBarLabel())
    bar.back:setStyleSheet(styleBarBack())
    local c1, c2, c3 = L.colorSet(key)
    bar.fill:setStyleSheet(styleBarFill(c1, c2, c3))
    bar.num:setStyleSheet(key == "improve" and styleBarNumCentered() or styleBarNum())
  end
end

local function html(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return s
end

-- infoFont() is the only caller of infoStyle(), which only backs
-- terrainBadge() -- unified with L.config.terrainFont 2026-07-11 (was an
-- independent font+2 offset competing with roomMeta's own widget-level
-- stylesheet size, the same kind of redundant-inline-vs-stylesheet
-- mismatch that caused the room-title color bug fixed the same day).
local function infoFont()
  return math.max(8, tonumber(L.config.terrainFont) or 10)
end

local function infoStyle(color, weight)
  return "font-size:" .. tostring(infoFont()) .. "pt; color:" .. tostring(color or "#dbe7ea") ..
         "; font-weight:" .. tostring(weight or "bold") .. ";"
end


-- terrainColor(t) -- added 2026-07-11, per Steven ("have the terrain text
-- color adjust to terrain type (if we know them, if not something nice
-- other than what it is)"). Keyword-matched against real DSL terrain/
-- sector words; unrecognized terrain gets a fallback distinct from the
-- old flat cyan (#74d3e0) this used unconditionally before.
local TERRAIN_COLORS = {
  { "forest", "wood", "jungle",           "#7ac97a" },
  { "desert", "sand",                     "#d9c17a" },
  { "swamp", "marsh", "bog",              "#93a06e" },
  { "water", "ocean", "sea", "river", "lake", "coast", "beach", "shore", "#6fb8d9" },
  { "mountain", "hill", "rock", "cliff",  "#a8a49c" },
  { "cave", "underground", "dungeon", "tunnel", "#9b7fe0" },
  { "city", "town", "road", "street", "village", "#c9a86a" },
  { "snow", "ice", "arctic", "tundra", "glacier", "#bfe3ec" },
  { "plain", "grass", "field", "meadow",  "#9ed98a" },
  { "air", "sky", "cloud",                "#a6d8f0" },
  { "inside", "indoor", "building", "room", "#c2b8a3" },
}

local function terrainColor(t)
  t = tostring(t or ""):lower()
  for _, entry in ipairs(TERRAIN_COLORS) do
    for i = 1, #entry - 1 do
      if t:find(entry[i], 1, true) then return entry[#entry] end
    end
  end
  return "#c2b8a3" -- "something nice" fallback for unrecognized terrain
end

local function terrainBadge(t)
  t = trim(t or "--")
  if t == "" then t = "--" end
  return "<span style='" .. infoStyle(terrainColor(t), "bold") .. "'>" .. html(t) .. "</span>"
end


-- Threshold raised 2026-07-12 from 34 to 60 (roomTitle itself widened from
-- 80%->96% the same day -- see that widget's own comment) -- per Steven,
-- who wants real room names to just fit on one line, not deliberately
-- break onto a second line before they need to. Every real room name
-- observed live this session (e.g. "A Path To The Mystic Crystal Fields",
-- 36 chars) is comfortably under 60 -- this only kicks in now as a genuine
-- safety net for a name that's actually too long for the wider row, not
-- the normal case.
local function splitRoomName(s)
  s = tostring(s or "Unknown Room")
  if #s <= 60 then return html(s) end

  local target = math.floor(#s / 2)
  local best = nil
  for pos = 16, #s - 10 do
    if s:sub(pos, pos) == " " then
      if not best or math.abs(pos - target) < math.abs(best - target) then best = pos end
    end
  end

  if best and #s <= 100 then
    -- color fixed 2026-07-11 alongside the main room-title bug -- was a
    -- second hardcoded literal (#ffd98a) independent of the theme.
    return html(s:sub(1, best - 1)) ..
           "<br><span style='font-size:" .. tostring(math.max(10, L.config.titleFont - 2)) .. "pt; color:" .. titleColorCSS() .. ";'>" ..
           html(s:sub(best + 1)) .. "</span>"
  end

  return html(s:sub(1, 70)) .. "..."
end

-- setBar()/setBarPercent() -- updated 2026-07-11 for the v1A15 inline bar
-- layout: the value text now lives in a separate right-aligned bar.num
-- Label beside the track (see makeBar()), not centered on top of the fill
-- like before, since there's a dedicated bar.label to the left now too.
function L.setBar(key, cur, max, text)
  local bar = L.ui.bars and L.ui.bars[key]
  if not bar then return end
  local p = pct(cur, max)
  local width = math.floor((tonumber(bar.maxWidth) or 28) * p + 0.5)
  if width < 1 and p > 0 then width = 1 end
  pcall(function() bar.fill:resize(tostring(width).."%", nil) end)
  bar.num:echo(html(text or ""))
end

function L.setBarPercent(key, percent, text)
  local bar = L.ui.bars and L.ui.bars[key]
  if not bar then return end
  local p = tonumber(percent)
  if not p then p = 0 end
  if p > 1 then p = p / 100 end
  if p < 0 then p = 0 end
  if p > 1 then p = 1 end
  local width = math.floor((tonumber(bar.maxWidth) or 28) * p + 0.5)
  if width < 1 and p > 0 then width = 1 end
  pcall(function() bar.fill:resize(tostring(width).."%", nil) end)
  bar.num:echo(html(text or ""))
end

-- resizeExitsCon(charCount) -- added 2026-07-11, per Steven ("the exit bar
-- border removed or have it adapt to the size of the exit"). MiniConsole
-- has no setStyleSheet (confirmed earlier this session -- Geyser.Window
-- defines it, MiniConsole doesn't inherit or override it), so there's no
-- Lua-level way to strip whatever native Qt frame it draws -- this instead
-- shrinks/grows the whole widget to roughly match the exits text length,
-- so a short exit list ("[Exits: S ]") doesn't sit inside a wide box
-- mostly empty space. 7.5px/char is a rough monospace estimate at the
-- default ~10pt font; not exact, but close enough that the box tracks
-- content length instead of staying fixed-width regardless of it.
local function resizeExitsCon(charCount)
  if not (L.ui and L.ui.exitsCon) then return end
  local pxNeeded = (tonumber(charCount) or 20) * 7.5 + 16
  local windowPx = 974 -- confirmed real width via "mydsl live status"; an
                        -- approximation if the window's since been resized
  local percent = (pxNeeded / windowPx) * 100
  if percent < 15 then percent = 15 end
  if percent > 83 then percent = 83 end
  pcall(function() L.ui.exitsCon:resize(tostring(math.floor(percent)).."%", nil) end)
end

function L.setColoredExitsFromCurrentLine()
  if not L.ensureUI() then return false end

  local line = getCurrentLine and getCurrentLine() or ""
  if not tostring(line):match("^%s*%[Exits:%s*") then return false end

  MyDSL = MyDSL or {}
  MyDSL.DB = MyDSL.DB or {}
  MyDSL.DB.room = MyDSL.DB.room or {}
  MyDSL.DB.room.exitsColoredSource = "room-line"
  MyDSL.DB.room.exitsColoredUpdatedAt = os.time()
  MyDSL.DB.room.exitsLine = tostring(line)

  if L.ui and L.ui.exitsCon then
    resizeExitsCon(#tostring(line))
    pcall(function()
      clearWindow(L.name .. "_ExitsCon")
      selectCurrentLine()
      copy()
      appendBuffer(L.name .. "_ExitsCon")
      deselect()
    end)
  end

  return true
end

function L.setNeutralExitsLine(d)
  if not L.ui or not L.ui.exitsCon then return end
  local exitsStr = tostring(d.exits or "--")
  resizeExitsCon(#exitsStr + 9) -- +9 for "[Exits: " and " ]"
  pcall(function()
    clearWindow(L.name .. "_ExitsCon")
    cecho(L.name .. "_ExitsCon", "<grey>[Exits: <white>" .. exitsStr .. "<grey> ]")
  end)
end

------------------------------------------------------------------------
-- Row-building helpers for the v1A15 identity/info/attribute rows.
-- Added 2026-07-11. Each row is one Geyser.Label rendered with inline
-- <span> color markup (same technique terrainBadge() already uses)
-- rather than several separate small Labels per field --
-- keeps the widget count reasonable for ~8 new rows of data.
------------------------------------------------------------------------

-- infoFontPt() -- real bug fixed 2026-07-11, per Steven ("font didnt
-- change that i noticed"): kv()/identityLine()/attrLine() only ever set
-- color/font-weight inline and relied on the widget's own setStyleSheet()
-- for font SIZE -- but Qt's rich-text renderer (what :echo() with HTML
-- spans goes through) doesn't reliably inherit font-size from a QLabel's
-- widget-level stylesheet the way it does color/weight. roomTitle already
-- worked correctly because it has always set font-size inline explicitly;
-- terrainBadge() likewise already works via infoStyle()/infoFont(). Every
-- span below now sets font-size inline too, reading L.config.infoFont
-- live so "mydsl live infofont <n>" actually has a visible effect.
local function infoFontPt()
  return math.max(8, tonumber(L.config.infoFont) or 9)
end

-- kv(key, value, valueColor) -- "<dim>key</dim> <bold colored>value</bold>"
local function kv(key, value, valueColor)
  local sz = infoFontPt()
  return "<span style='font-size:" .. sz .. "pt; color:#8b969b;'>" .. html(key) .. "</span> " ..
         "<span style='font-size:" .. sz .. "pt; color:" .. (valueColor or "#e8e6e0") .. "; font-weight:bold;'>" .. html(value) .. "</span>"
end

-- SPACER -- widened 2026-07-11, per Steven ("size the text and spacing to
-- make it look more filled") -- was 3-4 &nbsp;s between fields, now 5, to
-- match the larger text without fields crowding each other.
local SPACER = "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"

-- fullnessColor(cur, max) -- added 2026-07-11, per Steven ("objects like
-- item weight need to go red when close to max"). Same 2-tier warning
-- shape AffectsView's colorForDuration() already uses elsewhere in this
-- codebase (amber approaching, red at/near the limit) -- applied here to
-- Items/Weight, which climb toward a hard cap rather than count down.
local function fullnessColor(cur, max)
  cur, max = tonumber(cur), tonumber(max)
  if not cur or not max or max <= 0 then return "#e8e6e0" end
  local ratio = cur / max
  if ratio >= 0.95 then return "#e2665f" end
  if ratio >= 0.8 then return "#e0b464" end
  return "#e8e6e0"
end

-- identityLine(d) -- level, name, READY/FIGHTING status, class, alignment
-- (colored good/evil/neutral), god. "*" in Steven's sketch = this status
-- marker (confirmed -- an earlier pass briefly misread it as character
-- flags before he corrected that).
local function identityLine(d)
  local sz = infoFontPt()
  local parts = {}
  table.insert(parts, "<span style='font-size:" .. sz .. "pt; color:#ffd166; font-weight:bold;'>" .. html(d.level or "--") .. "</span>")
  table.insert(parts, "<span style='font-size:" .. sz .. "pt; color:#e8e6e0; font-weight:bold;'>" .. html(d.name or "Unknown") .. "</span>")

  -- Pill stays a couple points smaller than the row for a "badge" look,
  -- but still scales with infoFont instead of a fixed 9pt.
  local pillSz = math.max(7, sz - 3)
  if d.fighting then
    table.insert(parts, "<span style='font-size:" .. pillSz .. "pt; color:#e2665f; font-weight:bold;'>FIGHTING</span>")
  else
    table.insert(parts, "<span style='font-size:" .. pillSz .. "pt; color:#8fd67a; font-weight:bold;'>READY</span>")
  end

  if d.class_ and d.class_ ~= "" then
    table.insert(parts, "<span style='font-size:" .. sz .. "pt; color:#9fd7ff;'>" .. html(d.class_) .. "</span>")
  end

  if d.align and d.align ~= "" then
    local ac, alow = "#c8c2b0", d.align:lower()
    if alow:find("evil") then ac = "#e2665f"
    elseif alow:find("good") then ac = "#8fd67a" end
    table.insert(parts, "<span style='font-size:" .. sz .. "pt; color:" .. ac .. ";'>" .. html(d.align) .. "</span>")
  end

  if d.god and d.god ~= "" then
    table.insert(parts, "<span style='font-size:" .. sz .. "pt; color:#d9a259;'>" .. html(d.god) .. "</span>")
  end

  -- Age, added 2026-07-12 per Steven -- fits in the row's freed space
  -- now that god only shows the name (see the Religion: parsing fix in
  -- MyDSL_DataLayer.lua), not the full "-=- the God of ..." title.
  -- Font size fixed same day (Steven: "the age text is too small and
  -- should match the rest of the font size for live info text") -- was
  -- pillSz (the smaller READY/FIGHTING badge size), now sz like every
  -- other field on this row (level/name/class/align/god).
  local age = ageText(d.createdTs)
  if age then
    table.insert(parts, "<span style='font-size:" .. sz .. "pt; color:#b8a4d4;'>" .. html(age) .. "</span>")
  end

  return table.concat(parts, SPACER)
end

-- posnColor(posn) -- a little more color variety per Steven ("color need
-- to increase"): Flying reads as an active/notable state, Sitting/
-- Resting/Sleeping as passive/vulnerable, Standing as the plain default.
local function posnColor(posn)
  posn = tostring(posn or ""):lower()
  if posn:find("fly") then return "#7fd6cc" end
  if posn:find("sleep") then return "#8b969b" end
  if posn:find("sit") or posn:find("rest") then return "#e0b464" end
  return "#e8e6e0"
end

local function infoLine1(d)
  local items = d.items and (fmtNum(d.items) .. "/" .. fmtNum(d.maxItems)) or "--"
  local weight = d.weight and (fmtNum(d.weight) .. "/" .. fmtNum(d.maxWeight)) or "--"
  return kv("Pos'n", d.posn or "--", posnColor(d.posn)) .. SPACER ..
         kv("Wimpy", d.wimpy or "--") .. SPACER ..
         kv("Items", items, fullnessColor(d.items, d.maxItems)) .. SPACER ..
         kv("Weight", weight, fullnessColor(d.weight, d.maxWeight))
end

local function infoLine2(d)
  return kv("Bank", d.bank and fmtNum(d.bank) or "--", "#8fd67a") .. SPACER ..
         kv("Gold", d.gold and fmtNum(d.gold) or "--", "#ffd166") .. SPACER ..
         kv("Silver", d.silver and fmtNum(d.silver) or "--", "#c9d3d8") .. SPACER ..
         kv("QPoints", d.qpoints and fmtNum(d.qpoints) or "--", "#c3a6e8")
end

-- attrValue(cur, base) -- "25 (25)" matching the real `score` command's
-- own "STR: 025(025)" current(base) format.
local function attrValue(cur, base)
  if not cur then return "--" end
  if base then return fmtNum(cur) .. " (" .. fmtNum(base) .. ")" end
  return fmtNum(cur)
end

-- attrLine(label, cur, base, extraHtml) -- "STR 25 (25)      <extra>"
-- extraHtml is whatever combat/status info is paired with that
-- particular attribute row per Steven's sketch (Armor on STR, Hit/Dam on
-- INT, Stance on WIS, TNL on DEX, nothing on CON).
local function attrLine(label, cur, base, extraHtml)
  local sz = infoFontPt()
  local left = "<span style='font-size:" .. sz .. "pt; color:#8b969b;'>" .. html(label) .. "</span> " ..
               "<span style='font-size:" .. sz .. "pt; color:#e8e6e0; font-weight:bold;'>" .. html(attrValue(cur, base)) .. "</span>"
  if extraHtml and extraHtml ~= "" then
    return left .. SPACER .. extraHtml
  end
  return left
end

-- stanceColor(stance) -- added 2026-07-11, per Steven ("color need to
-- increase"): Offensive/Defensive are the two real DSL stance values that
-- carry meaning at a glance; anything else stays neutral.
local function stanceColor(stance)
  stance = tostring(stance or ""):lower()
  if stance:find("offensive") then return "#e2665f" end
  if stance:find("defensive") then return "#78baff" end
  return "#e8e6e0"
end

-- signColor(n) -- green for a positive combat modifier, red for negative,
-- neutral for zero/unknown. Used for Hit/Dam.
local function signColor(n)
  n = tonumber(n)
  if not n then return "#e8e6e0" end
  if n > 0 then return "#8fd67a" end
  if n < 0 then return "#e2665f" end
  return "#e8e6e0"
end

-- hitDamValue(base, practiced) -- added 2026-07-11, per Steven ("hit and
-- dmage should have the B: P: when available"), matching the real `score`
-- command's own "HitRoll: B:27  P:37" labeling exactly. Falls back to just
-- the practiced value if base isn't known for some reason.
local function hitDamValue(base, practiced)
  if base ~= nil and practiced ~= nil then
    return "B:" .. tostring(base) .. " P:" .. tostring(practiced)
  end
  return tostring(practiced or base or "--")
end

function L.render(reason)
  if not L.ensureUI() then return end
  local d = L.data()

  -- Real bug fixed 2026-07-11, per Steven ("Room Name Changed to white"):
  -- this hardcoded color:#ffd166 inline, competing with applyStyles()'s
  -- titleColorCSS() already set on the widget itself -- the two disagreed
  -- and the room name rendered white instead of the theme's gold/amber/
  -- violet title color. Only font-size/weight are inline now; color comes
  -- from the widget's own stylesheet, so it also switches with the theme
  -- like every other title in the profile.
  L.ui.roomTitle:echo("<span style='font-size:" .. tostring(L.config.titleFont) .. "pt; font-weight:bold;'>" .. splitRoomName(d.roomName) .. "</span>")

  local metaBits = {}
  if d.terrain and d.terrain ~= "" and d.terrain ~= "--" then
    table.insert(metaBits, terrainBadge(d.terrain))
  end
  L.ui.roomMeta:echo(table.concat(metaBits, " "))
  if not (MyDSL and MyDSL.DB and MyDSL.DB.room and MyDSL.DB.room.exitsColoredSource == "room-line") then
    L.setNeutralExitsLine(d)
  end

  -- Vitals bars -- value text is now just the number (label is a separate
  -- widget to its left, see makeBar()), not "HP 20/20 (100%)" repeated.
  L.setBar("hp", d.hp, d.maxhp, fmtNum(d.hp) .. "/" .. fmtNum(d.maxhp) .. " (" .. tostring(math.floor(pct(d.hp,d.maxhp)*100+0.5)) .. "%)")
  L.setBar("mana", d.mana, d.maxmana, fmtNum(d.mana) .. "/" .. fmtNum(d.maxmana) .. " (" .. tostring(math.floor(pct(d.mana,d.maxmana)*100+0.5)) .. "%)")
  L.setBar("move", d.move, d.maxmove, fmtNum(d.move) .. "/" .. fmtNum(d.maxmove) .. " (" .. tostring(math.floor(pct(d.move,d.maxmove)*100+0.5)) .. "%)")

  -- Real bug fixed 2026-07-12, found live (Steven: "i dont see the
  -- countdown now, just skill and percent"): L.data() already computes
  -- the live-ticking "(Mm SSs)" countdown into d.improveText via
  -- improveLiveText() (see its own comment above, added 2026-07-11 for
  -- exactly this), but this rebuilt a bare "skill NN%" string from
  -- d.improveSkill/d.improvePercent instead of using it -- the countdown
  -- was computed every render and just never displayed.
  local impText = d.improveText or (d.improveSkill and (tostring(d.improveSkill) .. " " .. tostring(d.improvePercent or "?") .. "%")) or "--"
  L.setBarPercent("improve", tonumber(d.improvePercent) or 0, impText)

  -- Identity + personal-info rows (left column).
  if L.ui.identity then L.ui.identity:echo(identityLine(d)) end
  if L.ui.infoLine1 then L.ui.infoLine1:echo(infoLine1(d)) end
  if L.ui.infoLine2 then L.ui.infoLine2:echo(infoLine2(d)) end

  -- Attribute rows (right column), each paired with whatever combat/
  -- status info Steven's sketch put beside it.
  if L.ui.attrStr then
    local armorExtra = ""
    if d.armorPierce or d.armorBash or d.armorSlash or d.armorMagic then
      armorExtra = kv("Armor P/B/S/M", table.concat({
        tostring(d.armorPierce or "--"), tostring(d.armorBash or "--"),
        tostring(d.armorSlash or "--"), tostring(d.armorMagic or "--"),
      }, "/"), "#9fb8c9")
    end
    L.ui.attrStr:echo(attrLine("STR", d.str, d.strBase, armorExtra))
  end
  if L.ui.attrInt then
    local hitDamExtra = ""
    if d.hitroll or d.damroll then
      hitDamExtra = kv("Hit", hitDamValue(d.hitrollBase, d.hitroll), signColor(d.hitroll)) .. "&nbsp;&nbsp;" ..
                    kv("Dam", hitDamValue(d.damrollBase, d.damroll), signColor(d.damroll))
    end
    L.ui.attrInt:echo(attrLine("INT", d.int_, d.intBase, hitDamExtra))
  end
  if L.ui.attrWis then
    local stanceExtra = (d.stance and d.stance ~= "") and kv("Stance", d.stance, stanceColor(d.stance)) or ""
    L.ui.attrWis:echo(attrLine("WIS", d.wis, d.wisBase, stanceExtra))
  end
  if L.ui.attrDex then
    local tnlExtra = d.xpToLevel and kv("TNL", fmtNum(d.xpToLevel) .. " xp", "#d8b96a") or ""
    L.ui.attrDex:echo(attrLine("DEX", d.dex, d.dexBase, tnlExtra))
  end
  if L.ui.attrCon then L.ui.attrCon:echo(attrLine("CON", d.con, d.conBase, "")) end
  -- Dragon-only, added 2026-07-12 per Steven. No base/current split (real
  -- `stat` output is just "Vit: 20", not "Vit: 20(25)") -- attrValue()
  -- already handles a nil base by falling back to the bare number.
  -- Blank for every non-dragon character, same as this row always was,
  -- since d.vitality only ever gets set by actually seeing a real `stat`
  -- line with a Vit: field in it (dragons only -- confirmed via
  -- DSL_Helpfiles/dragons.txt, "Dragons will lose vitality with every
  -- death"). Chamber (breath-weapon charge, added same day) paired onto
  -- this row via the same extraHtml slot every other attr row already
  -- uses (STR/Armor, INT/Hit-Dam, WIS/Stance, DEX/TNL) -- row 6 was full
  -- after Vitality took it, so Chamber rides alongside rather than
  -- needing its own row.
  if L.ui.attrVit then
    local chamberExtra = d.chamber and kv("Chamber", d.chamber, "#7fd6cc") or ""
    L.ui.attrVit:echo(d.vitality and attrLine("VIT", d.vitality, nil, chamberExtra) or "")
  end

  L.lastReason = reason or "render"
end

function L.show(save)
  L.config.shown = true
  if L.ui and L.ui.win then pcall(function() L.ui.win:show() end) end
  L.render("show")
  if save ~= false then L.saveSettings() end
end

function L.hide(save)
  L.config.shown = false
  if L.ui and L.ui.win then pcall(function() L.ui.win:hide() end) end
  if save ~= false then L.saveSettings() end
end

-- Internal-only as of 2026-08-26 (command-parity sweep) -- the
-- standalone "mydsl live rebuild" alias was removed (no evidence it
-- was ever needed on its own), but "mydsl live reload settings" and
-- "mydsl live layout" genuinely need this to apply a freshly-loaded
-- font/layout change to the live UI, so the function itself stays.
function L.rebuild()
  if L.ui and L.ui.win then pcall(function() L.ui.win:hide() end) end
  L.ui = {}
  L.ensureUI()
  L.render("rebuild")
end

function L.setFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl live font <size>"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  L.config.font = size
  L.applyStyles()
  L.render("font")
  L.saveSettings()
  ce("font=" .. tostring(size))
end

function L.setTitleFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl live titlefont <size>"); return end
  if size < 8 then size = 8 end
  if size > 24 then size = 24 end
  L.config.titleFont = size
  L.applyStyles()
  L.render("titlefont")
  L.saveSettings()
  ce("titleFont=" .. tostring(size))
end

function L.setBarFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl live barfont <size>"); return end
  if size < 6 then size = 6 end
  if size > 14 then size = 14 end
  L.config.barFont = size
  L.applyStyles()
  L.render("barfont")
  L.saveSettings()
  ce("barFont=" .. tostring(size))
end

-- setInfoFont()/setTerrainFont() -- added 2026-07-11, per Steven ("let me
-- be able to adjust the text size... informational text... terrain text,
-- any others you have separate").
function L.setInfoFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl live infofont <size>"); return end
  if size < 8 then size = 8 end
  if size > 20 then size = 20 end
  L.config.infoFont = size
  L.applyStyles()
  L.render("infofont")
  L.saveSettings()
  ce("infoFont=" .. tostring(size))
end

function L.setTerrainFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl live terrainfont <size>"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  L.config.terrainFont = size
  L.applyStyles()
  L.render("terrainfont")
  L.saveSettings()
  ce("terrainFont=" .. tostring(size))
end

function L.setTitle(title, silent)
  title = trim(title or "")
  if title == "" then title = "-= Live =-" end
  L.title = title
  if L.ui and L.ui.win and L.ui.win.setTitle then pcall(function() L.ui.win:setTitle(title) end) end
  L.saveSettings()
  if not silent then ce("title=" .. title) end
end

function L.status()
  local d = L.data()
  -- Real pixel footprint, added 2026-07-11 (per Steven, "is there a
  -- command to get you the dimensions?") -- get_width()/get_height() are
  -- real Geyser.Window methods returning the CURRENT on-screen pixel size
  -- (not the "34%"/"13%" config strings, which are relative to whatever
  -- the main window's size happens to be).
  local pw, ph = "?", "?"
  if L.ui and L.ui.win then
    local ok1, w = pcall(function() return L.ui.win:get_width() end)
    local ok2, h = pcall(function() return L.ui.win:get_height() end)
    if ok1 and w then pw = w end
    if ok2 and h then ph = h end
  end
  ce("version=" .. L.version ..
     "; pixelSize=" .. tostring(pw) .. "x" .. tostring(ph) ..
     "; configSize=" .. tostring(L.config.width) .. "x" .. tostring(L.config.height) ..
     "; shown=" .. tostring(L.config.shown) ..
     "; room=" .. tostring(d.roomName) ..
     "; hp=" .. tostring(d.hp) .. "/" .. tostring(d.maxhp) ..
     "; mana=" .. tostring(d.mana) .. "/" .. tostring(d.maxmana) ..
     "; move=" .. tostring(d.move) .. "/" .. tostring(d.maxmove) ..
     "; time=" .. tostring(d.clock) ..
     "; xp=" .. tostring(d.xp) ..
     "; xptnl=" .. tostring(d.xpToLevel) ..
     "; exits=" .. tostring(d.exits) ..
     "; exitsColored=" .. tostring(MyDSL and MyDSL.DB and MyDSL.DB.room and MyDSL.DB.room.exitsColoredSource or "nil") ..
     "; improve=" .. tostring(d.improveText) ..
     "; settingsLoaded=" .. tostring(L.settingsLoaded) ..
     "; settingsFile=" .. tostring(L.settingsFilePath or L.settingsFile()) ..
     "; aliasVersion=" .. tostring(L.aliasVersion) ..
     "; reason=" .. tostring(L.lastReason))
end

function L.installHandlers()
  if L.handlersInstalled then return end
  L.handlersInstalled = true
  L.handlers = L.handlers or {}
  local events = {
    "MyDSL.Live.Updated",
    "MyDSL.Status.Updated",
    "MyDSL.Score.Updated",
    "MyDSL.Time.Updated",
    "MyDSL.Improve.Updated",
    -- Real event DataLayer actually raises (MyDSL.emit() lowercases the
    -- section name) -- added 2026-07-07 alongside the improve bar wiring.
    -- The capitalized "MyDSL.Improve.Updated" above has never matched
    -- anything DataLayer raises; kept rather than removed in case some
    -- other still-registered listener depends on it, but this is the one
    -- that actually fires.
    "MyDSL.improve.updated",
    "MyDSL.Progress.Updated",
    -- Switched from "MyDSL.Timers.Updated" (0.25s, TickView's own bar-
    -- animation cadence) to "MyDSL.Timers.Slow" (throttled to 1/sec in
    -- TickSource) 2026-07-11 -- render() rebuilds every bar/label on each
    -- call, and nothing this window shows changes faster than once/sec, so
    -- 4x/sec was wasted work. Also gives the Improve bar's live-computed
    -- countdown text (see L.data()) a real heartbeat to count down against.
    "MyDSL.Timers.Slow",
    "MyDSL.Room.Updated",
    "gmcp.room_data",
    "gmcp.Room.Info",
  }

  for _, ev in ipairs(events) do
    if registerAnonymousEventHandler then
      local ok, id = pcall(function()
        return registerAnonymousEventHandler(ev, function() if MyDSL and MyDSL.LiveView then MyDSL.LiveView.render(ev) end end)
      end)
      if ok and id then table.insert(L.handlers, id) end
    end
  end

  -- Re-apply panel/border/title colors when the active theme switches.
  -- Added 2026-07-11 alongside named ThemeEngine presets.
  if registerAnonymousEventHandler then
    local ok, id = pcall(function()
      return registerAnonymousEventHandler("MyDSL.theme.changed", function()
        if MyDSL and MyDSL.LiveView then MyDSL.LiveView.applyStyles() end
      end)
    end)
    if ok and id then table.insert(L.handlers, id) end
  end
end

function L.installAliases()
  -- Versioned temp aliases. Older LiveView revisions may leave
  -- L.aliasesInstalled=true in memory, so do not rely on that flag alone.
  if L.aliasVersion == L.version then return end
  L.aliasVersion = L.version

  tempAlias([[^mydsl live status$]], [[MyDSL.LiveView.status()]])
  tempAlias([[^mydsl live show$]], [[MyDSL.LiveView.show()]])
  tempAlias([[^mydsl live hide$]], [[MyDSL.LiveView.hide()]])
  tempAlias([[^mydsl live refresh$]], [[MyDSL.LiveView.render("manual")]])
  tempAlias([[^mydsl live save$]], [[MyDSL.LiveView.saveSettings(); MyDSL.LiveView.status()]])
  tempAlias([[^mydsl live reload settings$]], [[MyDSL.LiveView.loadSettings(); MyDSL.LiveView.rebuild(); MyDSL.LiveView.status()]])
  tempAlias([[^mydsl live font ([0-9]+)$]], [[MyDSL.LiveView.setFont(matches[2])]])
  tempAlias([[^mydsl live titlefont ([0-9]+)$]], [[MyDSL.LiveView.setTitleFont(matches[2])]])
  tempAlias([[^mydsl live barfont ([0-9]+)$]], [[MyDSL.LiveView.setBarFont(matches[2])]])
  tempAlias([[^mydsl live infofont ([0-9]+)$]], [[MyDSL.LiveView.setInfoFont(matches[2])]])
  tempAlias([[^mydsl live terrainfont ([0-9]+)$]], [[MyDSL.LiveView.setTerrainFont(matches[2])]])
  tempAlias([[^mydsl live title (.+)$]], [[MyDSL.LiveView.setTitle(matches[2])]])
  tempAlias([[^mydsl live layout$]], [[MyDSL.LiveView.rebuild(); MyDSL.LiveView.status()]])
  L.aliasesInstalled = true
end

function L.installExitsTrigger()
  if L.exitsTriggerInstalled and L.exitsTriggerVersion == L.version then return end
  if tempRegexTrigger then
    tempRegexTrigger([[^\s*\[Exits:\s*.*\]\s*$]], [[if MyDSL and MyDSL.LiveView and MyDSL.LiveView.setColoredExitsFromCurrentLine then MyDSL.LiveView.setColoredExitsFromCurrentLine() end]])
  elseif tempTrigger then
    tempTrigger("[Exits:", [[if MyDSL and MyDSL.LiveView and MyDSL.LiveView.setColoredExitsFromCurrentLine then MyDSL.LiveView.setColoredExitsFromCurrentLine() end]])
  end
  L.exitsTriggerInstalled = true
  L.exitsTriggerVersion = L.version
end

function L.boot()
  L.loadSettings()
  L.installAliases()
  L.installHandlers()
  L.installExitsTrigger()
  L.ensureUI()
  L.render("boot")
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. L.version) end
end

L.boot()
