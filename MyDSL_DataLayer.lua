-- =============================================================================
-- MyDSL_DataLayer.lua  --  Layer 1: Data Collection
-- =============================================================================
-- Zero display logic. Never sends commands to the game.
-- All data lives under MyDSL.State[section] and MyDSL.Data[charName][section].
-- Other modules receive updates via raiseEvent("MyDSL.<section>.updated")
-- or by registering a Lua callback with MyDSL.on(section, fn).
-- =============================================================================


------------------------------------------------------------------------
-- SECTION 1: NAMESPACE GUARD
------------------------------------------------------------------------
-- 'MyDSL or {}' means: if the table already exists (e.g. script was just
-- resaved), keep it — don't wipe live listeners or in-flight data.
-- If it doesn't exist yet, create a fresh empty table.
MyDSL = MyDSL or {}


------------------------------------------------------------------------
-- SECTION 2: PRIVATE UTILITIES
------------------------------------------------------------------------
-- Declared local so they never escape into the global environment.

local function now()    return os.time() end
local function trim(s)  return s and s:match("^%s*(.-)%s*$") or "" end


------------------------------------------------------------------------
-- SECTION 3: STATE TABLE
------------------------------------------------------------------------
-- One sub-table per logical data domain.  Every section carries a
-- last_updated Unix timestamp so consumers can judge data freshness.
-- Use 'or {}' so a reload never resets live data that already arrived.

MyDSL.State = MyDSL.State or {}
MyDSL.State.char    = MyDSL.State.char    or { last_updated = 0 }  -- GMCP: vitals, stats, boolean flags
MyDSL.State.login   = MyDSL.State.login   or { last_updated = 0 }  -- GMCP: name, level, kingdom
MyDSL.State.room    = MyDSL.State.room    or { last_updated = 0 }  -- GMCP: room name, sector, exits
MyDSL.State.affects = MyDSL.State.affects or { last_updated = 0 }  -- GMCP: active spell/effect list
MyDSL.State.tick    = MyDSL.State.tick    or { last_updated = 0 }  -- GMCP: game time string
MyDSL.State.score   = MyDSL.State.score   or { last_updated = 0 }  -- text: full score block
MyDSL.State.lunar   = MyDSL.State.lunar   or { last_updated = 0 }  -- text: moon phases and bonuses
MyDSL.State.time    = MyDSL.State.time    or { last_updated = 0 }  -- text: game time/day/month
MyDSL.State.weather = MyDSL.State.weather or { last_updated = 0 }  -- text: weather description
MyDSL.State.who     = MyDSL.State.who     or { last_updated = 0 }  -- text: online player list
MyDSL.State.group   = MyDSL.State.group   or { last_updated = 0 }  -- text: party members
MyDSL.State.unread  = MyDSL.State.unread  or { last_updated = 0 }  -- text: unread message counts
MyDSL.State.inv     = MyDSL.State.inv     or { last_updated = 0 }  -- text: carried item list
MyDSL.State.map     = MyDSL.State.map     or { last_updated = 0 }  -- text: ASCII map lines
MyDSL.State.improve = MyDSL.State.improve or { last_updated = 0 }  -- text: skill improve events
MyDSL.State.flags   = MyDSL.State.flags   or { last_updated = 0 }  -- text: toggle flags from score

-- Per-character persistent storage.  Keyed by character name so Kien,
-- Vrokt, Olyndros etc each have completely separate saved state.
MyDSL.Data = MyDSL.Data or {}

-- Lua callback listeners registered by display modules via MyDSL.on().
MyDSL.listeners = MyDSL.listeners or {}

-- Numeric handler IDs from registerAnonymousEventHandler, kept so we
-- can kill them cleanly when the script reloads.
MyDSL._handlers = MyDSL._handlers or {}


------------------------------------------------------------------------
-- SECTION 4: CURRENT CHARACTER NAME
------------------------------------------------------------------------
-- Single authoritative accessor.  Name comes only from login_data;
-- char_data has no name field (documented bug in the old code).

function MyDSL.Char()
  local login = MyDSL.State and MyDSL.State.login
  return login and login.name or nil
end


------------------------------------------------------------------------
-- SECTION 5: EVENT BUS
------------------------------------------------------------------------
-- Display modules register with MyDSL.on(); the data layer calls
-- MyDSL.emit() internally.  We also raiseEvent() so Mudlet triggers
-- and other scripts can listen without needing a Lua reference here.

function MyDSL.on(section, callback)
  MyDSL.listeners[section] = MyDSL.listeners[section] or {}
  MyDSL.listeners[section][#MyDSL.listeners[section] + 1] = callback
end

function MyDSL.emit(section)
  -- Mudlet event — any trigger or script can hear "MyDSL.char.updated" etc.
  raiseEvent("MyDSL." .. section .. ".updated", MyDSL.State[section])
  -- Direct Lua callbacks registered via MyDSL.on()
  local cbs = MyDSL.listeners[section]
  if not cbs then return end
  for _, cb in ipairs(cbs) do
    local ok, err = pcall(cb, MyDSL.State[section])
    if not ok then
      debugc("[MyDSL] listener error (" .. section .. "): " .. tostring(err))
    end
  end
end


------------------------------------------------------------------------
-- SECTION 6: GET / SET API
------------------------------------------------------------------------
-- All external modules use these instead of reading State directly.
-- MyDSL.get("char", "hp")         -- returns hp value or nil
-- MyDSL.get("char")               -- returns the whole char section
-- MyDSL.set("char", "hp", 1500)   -- writes one field and emits

function MyDSL.get(section, field)
  local s = MyDSL.State[section]
  if not s then return nil end
  return field ~= nil and s[field] or s
end

function MyDSL.set(section, field, value)
  local s = MyDSL.State[section]
  if not s then return end
  s[field] = value
  s.last_updated = now()
  MyDSL.emit(section)
end

-- Internal bulk writer.  Merges a table of fields into a section,
-- stamps last_updated once, emits once, then mirrors into per-character
-- Data so the next save() captures it.  Never called from outside this file.
local function update(section, fields)
  local s = MyDSL.State[section]
  if not s then return end
  for k, v in pairs(fields) do s[k] = v end
  s.last_updated = now()
  MyDSL.emit(section)
  -- Mirror into per-character persistent store
  local charName = MyDSL.Char()
  if charName then
    MyDSL.Data[charName]          = MyDSL.Data[charName]          or {}
    MyDSL.Data[charName][section] = MyDSL.Data[charName][section] or {}
    local d = MyDSL.Data[charName][section]
    for k, v in pairs(fields) do d[k] = v end
    d.last_updated = now()
  end
end


------------------------------------------------------------------------
-- SECTION 7: GMCP HANDLERS
------------------------------------------------------------------------
-- Kill any handlers that survived from a previous script load so we
-- never accumulate duplicate listeners across reloads.

local function deregisterHandlers()
  for _, id in pairs(MyDSL._handlers) do
    pcall(killAnonymousEventHandler, id)
  end
  MyDSL._handlers = {}
end
deregisterHandlers()

-- ---- gmcp.char_data ------------------------------------------------
-- FIX: The old code tried to read a name field from char_data.
-- char_data has no name field — that dead code is removed entirely.
-- Name is sourced exclusively from login_data via MyDSL.Char().

MyDSL._handlers.char_data = registerAnonymousEventHandler(
  "gmcp.char_data",
  function()
    if type(gmcp) ~= "table" or type(gmcp.char_data) ~= "table" then return end
    local d = gmcp.char_data
    update("char", {
      hp               = tonumber(d.hp),
      max_hp           = tonumber(d.max_hp),
      mana             = tonumber(d.mana),
      max_mana         = tonumber(d.max_mana),
      move             = tonumber(d.move),
      max_move         = tonumber(d.max_move),
      str              = tonumber(d.str),
      max_str          = tonumber(d.max_str),
      int              = tonumber(d.int),
      max_int          = tonumber(d.max_int),
      wis              = tonumber(d.wis),
      max_wis          = tonumber(d.max_wis),
      dex              = tonumber(d.dex),
      max_dex          = tonumber(d.max_dex),
      con              = tonumber(d.con),
      max_con          = tonumber(d.max_con),
      gold             = tonumber(d.gold),
      silver           = tonumber(d.silver),
      tnl              = tonumber(d.tnl),
      wimpy            = tonumber(d.wimpy),
      carry_weight     = tonumber(d.carry_weight),
      can_carry_weight = tonumber(d.can_carry_weight),
      stance           = d.stance,
      language         = d.language,
      is_flying        = d.is_flying,
      is_riding        = d.is_riding,
      is_fighting      = d.is_fighting,
      is_afk           = d.is_afk,
      is_quiet         = d.is_quiet,
    })
  end
)

-- ---- gmcp.login_data -----------------------------------------------
-- Authoritative source of character name and kingdom.
-- Triggers restoreChar() so last-session data becomes available
-- before GMCP has had time to re-deliver everything.

MyDSL._handlers.login_data = registerAnonymousEventHandler(
  "gmcp.login_data",
  function()
    if type(gmcp) ~= "table" or type(gmcp.login_data) ~= "table" then return end
    local d    = gmcp.login_data
    local name = d.name
    update("login", {
      name       = name,
      level      = tonumber(d.level),
      kingdom    = d.kingdom,
      is_clan    = d.is_clan,
      is_kingdom = d.is_kingdom,
      time       = d.time,
    })
    if name and name ~= "" then
      MyDSL.Data[name] = MyDSL.Data[name] or {}
      MyDSL.restoreChar(name)
    end
  end
)

-- ---- gmcp.room_data ------------------------------------------------

MyDSL._handlers.room_data = registerAnonymousEventHandler(
  "gmcp.room_data",
  function()
    if type(gmcp) ~= "table" or type(gmcp.room_data) ~= "table" then return end
    local d     = gmcp.room_data
    local exits = {}
    if type(d.exits) == "table" then
      for _, v in ipairs(d.exits) do exits[#exits + 1] = tostring(v) end
    end
    update("room", { name = d.room, sector = d.sector, exits = exits })
  end
)

-- ---- gmcp.tick -----------------------------------------------------

MyDSL._handlers.tick = registerAnonymousEventHandler(
  "gmcp.tick",
  function()
    if type(gmcp) ~= "table" or type(gmcp.tick) ~= "table" then return end
    update("tick", { time = gmcp.tick.time })
  end
)

-- ---- Shared affect helper ------------------------------------------
-- Converts the array of affect entries from GMCP into a keyed table.
-- Keys are lowercase affect names so lookups are case-insensitive.

local function buildActiveAffects(list)
  local active = {}
  for _, entry in ipairs(list) do
    local name = entry.n or entry.name
    if name and name ~= "" then
      active[name:lower()] = {
        name     = name,
        duration = tonumber(entry.d),
        modifier = tonumber(entry.m),
        location = entry.lc,
        type_raw = entry.t,  -- always 0, unused, stored for completeness
      }
    end
  end
  return active
end

-- ---- gmcp.affect_data ----------------------------------------------
-- Full replace of the affect list.  Saved to disk so incremental
-- add/remove changes that follow will persist correctly.

MyDSL._handlers.affect_data = registerAnonymousEventHandler(
  "gmcp.affect_data",
  function()
    if type(gmcp) ~= "table" or type(gmcp.affect_data) ~= "table" then return end
    local list = gmcp.affect_data.affects
    if type(list) ~= "table" then return end
    update("affects", { active = buildActiveAffects(list) })
    MyDSL.save()
  end
)

-- ---- gmcp.add_affect -----------------------------------------------
-- FIX: Previously this handler ran but the result was never saved to
-- disk.  A reconnect before the next full affect_data packet would
-- lose any affects added since the last full sync.  Now we save().

MyDSL._handlers.add_affect = registerAnonymousEventHandler(
  "gmcp.add_affect",
  function()
    if type(gmcp) ~= "table" or type(gmcp.add_affect) ~= "table" then return end
    local entry = gmcp.add_affect
    local name  = entry.n or entry.name
    if not name or name == "" then return end
    -- Copy current active table so we don't modify State directly
    local active = {}
    if type(MyDSL.State.affects.active) == "table" then
      for k, v in pairs(MyDSL.State.affects.active) do active[k] = v end
    end
    active[name:lower()] = {
      name     = name,
      duration = tonumber(entry.d),
      modifier = tonumber(entry.m),
      location = entry.lc,
      type_raw = entry.t,
    }
    update("affects", { active = active })
    MyDSL.save()
  end
)

-- ---- gmcp.remove_affect --------------------------------------------
-- FIX: Same bug as add_affect — incremental removal was not persisted.

MyDSL._handlers.remove_affect = registerAnonymousEventHandler(
  "gmcp.remove_affect",
  function()
    if type(gmcp) ~= "table" or type(gmcp.remove_affect) ~= "table" then return end
    local name = gmcp.remove_affect.n or gmcp.remove_affect.name
    if not name or name == "" then return end
    local active = {}
    if type(MyDSL.State.affects.active) == "table" then
      for k, v in pairs(MyDSL.State.affects.active) do active[k] = v end
    end
    active[name:lower()] = nil  -- remove the entry
    update("affects", { active = active })
    MyDSL.save()
  end
)


------------------------------------------------------------------------
-- SECTION 8: PERSISTENCE
------------------------------------------------------------------------

local function saveFilePath()
  -- getMudletHomeDir() returns the profile directory, e.g.
  -- /home/owner/.config/mudlet/profiles/DSL1
  return getMudletHomeDir() .. "/MyDSL_state.lua"
end

function MyDSL.save()
  local charName = MyDSL.Char()
  if charName then
    -- Snapshot every live State section into the character's Data slot
    MyDSL.Data[charName] = MyDSL.Data[charName] or {}
    local sections = {
      "char","login","room","affects","tick","score",
      "lunar","time","weather","who","group","unread",
      "inv","map","improve","flags",
    }
    for _, sec in ipairs(sections) do
      MyDSL.Data[charName][sec] = MyDSL.State[sec]
    end
  end
  table.save(saveFilePath(), MyDSL.Data)
end

function MyDSL.load()
  local path   = saveFilePath()
  local loaded = {}
  local ok     = pcall(function() loaded = table.load(path) end)
  if not ok or type(loaded) ~= "table" then
    debugc("[MyDSL] No save file found — starting with empty Data.")
    return
  end
  MyDSL.Data = loaded
  debugc("[MyDSL] Save file loaded from " .. path)
end

-- Called from the login_data handler once we know the character name.
-- Restores sections that are expensive or slow to rebuild naturally
-- (score, flags, lunar) and shows last-known affects until GMCP
-- delivers a fresh affect_data packet.

function MyDSL.restoreChar(name)
  local saved = MyDSL.Data[name]
  if not saved then return end

  -- Restore sections that are worth pre-populating at login
  local restoreSections = { "score", "lunar", "flags", "improve" }
  for _, sec in ipairs(restoreSections) do
    if type(saved[sec]) == "table" then
      for k, v in pairs(saved[sec]) do
        MyDSL.State[sec][k] = v
      end
      -- Deliberately leave last_updated unchanged — restored data is old
    end
  end

  -- Affects: restore from disk only if GMCP hasn't already sent a packet.
  -- last_updated == 0 means no GMCP data has arrived this session yet.
  if MyDSL.State.affects.last_updated == 0 and type(saved.affects) == "table" then
    for k, v in pairs(saved.affects) do
      MyDSL.State.affects[k] = v
    end
    -- Leave last_updated = 0 so the first real gmcp.affect_data overwrites this.
    debugc("[MyDSL] Restored last-known affects for " .. name .. " (awaiting GMCP sync).")
  end

  debugc("[MyDSL] State restored for: " .. name)
end

-- Load the save file immediately when this script runs.
-- restoreChar() is called later by the login_data handler once the
-- character name is known.
MyDSL.load()


------------------------------------------------------------------------
-- SECTION 9: TRIGGER-CAPTURE PARSING FUNCTIONS
------------------------------------------------------------------------
-- Mudlet triggers watch for output patterns and call these functions.
-- This file defines only the parsing and storage logic.
-- None of these functions send any commands to the game.
--
-- Convention used throughout:
--   beginX()       called when a trigger sees the first line of a block
--   parseXLine(s)  called for every line in the block
--   endX()         called when the block ends; commits data to State
--
-- Single-line outputs skip begin/end and have just one parseX(line).

------------------------------------------------------------------------
-- 9a  SCORE
------------------------------------------------------------------------
-- Trigger wiring (write these in Mudlet separately):
--   "^Score for (%S+)"         → MyDSL.beginScore(matches[2])
--   any line while in block    → MyDSL.parseScoreLine(line)
--   blank line / known end     → MyDSL.endScore()

local scoreBlock = nil

function MyDSL.beginScore(charName)
  scoreBlock = { name = trim(charName), lines = {} }
end

function MyDSL.parseScoreLine(line)
  if not scoreBlock then return end
  scoreBlock.lines[#scoreBlock.lines + 1] = line

  local v  -- reused temp

  -- LEVEL: 051  Race: High Elf  Played: 1234
  local lv, race, played =
    line:match("LEVEL:%s*(%d+)%s+Race%s*:%s*(.-)%s+Played:%s*(%d+)")
  if lv then
    scoreBlock.level       = tonumber(lv)
    scoreBlock.race        = trim(race)
    scoreBlock.playedHours = tonumber(played)
    return
  end

  -- YEARS: 012  Class: Warrior  Log In: ...
  local yr, cl = line:match("YEARS:%s*(%d+)%s+Class%s*:%s*(.-)%s+Log In:")
  if yr then
    scoreBlock.years = tonumber(yr)
    scoreBlock.class = trim(cl)
    return
  end

  -- SEX: Male  Reclass@: 200
  local sx, rc = line:match("SEX%s*:%s*(%S+)%s+Reclass@:%s*(%S*)")
  if sx then
    scoreBlock.sex       = sx
    scoreBlock.reclassAt = rc ~= "" and rc or nil
    return
  end

  -- Stats: STR: 062(062)  INT: 060(060) ...
  scoreBlock.stats = scoreBlock.stats or {}
  for _, stat in ipairs({ "STR", "INT", "WIS", "DEX", "CON" }) do
    local cur, base = line:match(stat .. "%s*:%s*(%d+)%((%d+)%)")
    if cur then
      local k = stat:lower()
      scoreBlock.stats[k]           = tonumber(cur)
      scoreBlock.stats[k .. "Base"] = tonumber(base)
    end
  end

  -- HITROLL B: 14  P: 19   DAMROLL B: 14  P: 21
  local hB, hP = line:match("HITROLL%s+B:%s*([%+%-]?%d+)%s+P:%s*([%+%-]?%d+)")
  if hB then scoreBlock.hitrollBase = tonumber(hB); scoreBlock.hitroll = tonumber(hP) end
  local dB, dP = line:match("DAMROLL%s+B:%s*([%+%-]?%d+)%s+P:%s*([%+%-]?%d+)")
  if dB then scoreBlock.damrollBase = tonumber(dB); scoreBlock.damroll = tonumber(dP) end

  -- Armor: Pierce: -100  Bash: -80  Slash: -90  Magic: -70
  local ap, ab, as_, am =
    line:match("Pierce:%s*([%+%-]?%d+)%s+Bash:%s*([%+%-]?%d+)%s+Slash:%s*([%+%-]?%d+)%s+Magic:%s*([%+%-]?%d+)")
  if ap then
    scoreBlock.armorPierce = tonumber(ap)
    scoreBlock.armorBash   = tonumber(ab)
    scoreBlock.armorSlash  = tonumber(as_)
    scoreBlock.armorMagic  = tonumber(am)
  end

  -- Hitpoints / Mana / Move
  local hp, mhp = line:match("Hitpoints:%s*(%d+)%s+of%s+(%d+)")
  if hp then scoreBlock.hp = tonumber(hp); scoreBlock.max_hp = tonumber(mhp) end
  local mn, mmn = line:match("Mana:%s*(%d+)%s+of%s+(%d+)")
  if mn then scoreBlock.mana = tonumber(mn); scoreBlock.max_mana = tonumber(mmn) end
  local mv, mmv = line:match("Move:%s*(%d+)%s+of%s+(%d+)")
  if mv then scoreBlock.move = tonumber(mv); scoreBlock.max_move = tonumber(mmv) end

  -- Gold / Silver on same line
  local g, s = line:match("Gold:%s*(%d+)%s+Silver:%s*(%d+)")
  if g then scoreBlock.gold = tonumber(g); scoreBlock.silver = tonumber(s) end

  -- Bank / Quest points
  local bk, qp = line:match("Bank:%s*(%d+)%s+Qpoints:%s*(%d+)")
  if bk then scoreBlock.bank = tonumber(bk); scoreBlock.qpoints = tonumber(qp) end

  v = line:match("Practices:%s*(%d+)");   if v then scoreBlock.practices = tonumber(v) end
  v = line:match("Trains:%s*(%d+)");      if v then scoreBlock.trains    = tonumber(v) end
  v = line:match("XP%s*:%s*(%d+)");       if v then scoreBlock.xp       = tonumber(v) end
  v = line:match("TNL:%s*(%d+)");         if v then scoreBlock.tnl      = tonumber(v) end
  v = line:match("Alignment:%s*(.+)$");   if v then scoreBlock.align    = trim(v) end
  v = line:match("Wimpy:%s*(%d+)");       if v then scoreBlock.wimpy    = tonumber(v) end
  v = line:match("Position:%s*(.+)$");    if v then scoreBlock.position = trim(v) end
  v = line:match("Stance:%s*(.+)$");      if v then scoreBlock.stance   = trim(v) end
  v = line:match("Speaking:%s*(%S+)");    if v then scoreBlock.language = v end
  v = line:match("Religion:%s*(.+)$");    if v then scoreBlock.religion = trim(v) end
  v = line:match("PROFESSION:%s*(.+)$");  if v then scoreBlock.profession = trim(v) end

  -- Craft: Blacksmithing 45%
  local craft, pct = line:match("Craft:%s*(.-)%s+(%d+)%%")
  if craft then
    scoreBlock.crafts = scoreBlock.crafts or {}
    scoreBlock.crafts[trim(craft):lower()] = tonumber(pct)
  end

  -- PKill record: PKills: 5  PKilled: 2
  local pk, pkd = line:match("PKills:%s*(%d+)%s+PKilled:%s*(%d+)")
  if pk then scoreBlock.pkills = tonumber(pk); scoreBlock.pkilled = tonumber(pkd) end
end

function MyDSL.endScore()
  if not scoreBlock then return end
  local fields = { raw = scoreBlock.lines }
  for k, v in pairs(scoreBlock) do
    if k ~= "lines" then fields[k] = v end
  end
  update("score", fields)
  scoreBlock = nil
  MyDSL.save()
end

------------------------------------------------------------------------
-- 9b  FLAGS  (toggle section inside score output)
------------------------------------------------------------------------
-- Trigger wiring:
--   flags block header → MyDSL.beginFlags()
--   each flag line     → MyDSL.parseFlagsLine(line)
--   block end          → MyDSL.endFlags()

local KNOWN_FLAGS = {
  "NoFollow","AutoAssist","AutoExit","AutoGold","AutoLoot","AutoSac",
  "AutoSplit","NoBattle","NoPkLoot","NoTake","NoHeal","NoFly",
  "NoSummon","NoLink","NoCancel","Compact","Prompt","Combine",
  "AutoQuit","BeepTell","Ticks","TelnetGA","NoSurrender","NoToast",
}

-- Lowercase → canonical name lookup for fast word matching
local FLAG_SET = {}
for _, f in ipairs(KNOWN_FLAGS) do FLAG_SET[f:lower()] = f end

local flagsBlock = {}

function MyDSL.beginFlags()
  flagsBlock = {}
end

function MyDSL.parseFlagsLine(line)
  -- Flags appear as space-separated words; collect whichever are present
  for word in line:gmatch("%S+") do
    local canon = FLAG_SET[word:lower()]
    if canon then flagsBlock[canon] = true end
  end
end

function MyDSL.endFlags()
  -- Any known flag not seen during the block is explicitly OFF
  local fields = {}
  for _, canon in ipairs(KNOWN_FLAGS) do
    fields[canon] = flagsBlock[canon] == true
  end
  update("flags", fields)
  flagsBlock = {}
  MyDSL.save()
end

------------------------------------------------------------------------
-- 9c  LUNAR
------------------------------------------------------------------------
-- Trigger wiring:
--   lunar section header → MyDSL.beginLunar()
--   each moon line       → MyDSL.parseLunarLine(line)
--   blank line / end     → MyDSL.endLunar()
--
-- Example lines:
--   Red moon (Serin):  Full, high sanction. Mana bonus 20%, saves -8, casting +20. Regen 6%, 2 cycles, 8 hours remain.
--     Phase change from 'Full' to 'Waning three-quarters' in 2 cycles (8 hours), at 2:32pm Friday.

local lunarBlock = {}
local MOON_COLORS = { red = true, white = true, black = true }

function MyDSL.beginLunar()
  lunarBlock = { red = {}, white = {}, black = {}, _last = nil }
end

function MyDSL.parseLunarLine(line)
  local color = line:lower():match("^(%a+) moon")
  if color and MOON_COLORS[color] then
    local moon = lunarBlock[color]
    moon.moon_name        = line:match("%((.-)%)")
    moon.phase            = trim(line:match(":%s+([^,]+),") or "")
    moon.visibility       = trim(line:match(",[^%.]-%.%s+") or "")
    moon.mana_bonus       = tonumber(line:match("Mana bonus (%d+)%%"))
    moon.saves_modifier   = tonumber(line:match("saves ([%+%-]?%d+)"))
    moon.casting_modifier = tonumber(line:match("casting ([%+%-]?%d+)"))
    moon.regen_pct        = tonumber(line:match("Regen (%d+)%%"))
    moon.cycles_remaining = tonumber(line:match("(%d+) cycles?[,.]"))
    moon.hours_remaining  = tonumber(line:match("(%d+) hours? remain"))
    moon.no_bonuses       = line:find("No bonuses") ~= nil
    lunarBlock._last = color
  elseif line:find("Phase change") and lunarBlock._last then
    local moon = lunarBlock[lunarBlock._last]
    moon.next_phase        = line:match("to '([^']+)'")
    moon.next_phase_cycles = tonumber(line:match("in (%d+) cycles?"))
    moon.next_phase_hours  = tonumber(line:match("%((%d+) hours?%)"))
    moon.next_phase_at     = trim(line:match("at (.-)%.?$") or "")
  end
end

function MyDSL.endLunar()
  update("lunar", {
    red   = lunarBlock.red   or {},
    white = lunarBlock.white or {},
    black = lunarBlock.black or {},
  })
  lunarBlock = {}
  MyDSL.save()
end

------------------------------------------------------------------------
-- 9d  TIME
------------------------------------------------------------------------
-- Single-line.  Trigger matches "It is %d+ o'clock" and calls this.
-- Example: "It is 4 o'clock am, on the Day of Deception, the 10th of January."

function MyDSL.parseTimeLine(line)
  local hour, ampm, dayName, dayNum, month =
    line:match("It is (%d+) o'clock (%a+), on the Day of ([^,]+), the (%d+)[^ ]+ of ([^%.]+)")
  if hour then
    update("time", {
      hour     = tonumber(hour),
      ampm     = ampm,
      day_name = trim(dayName),
      day_num  = tonumber(dayNum),
      month    = trim(month),
    })
  end
end

------------------------------------------------------------------------
-- 9e  WEATHER
------------------------------------------------------------------------
-- Single-line.  Trigger matches a weather description line.
-- Example: "A light snow falls quietly from the sky."

function MyDSL.parseWeatherLine(line)
  local desc = trim(line)
  if desc ~= "" then
    update("weather", { description = desc })
  end
end

------------------------------------------------------------------------
-- 9f  WHO
------------------------------------------------------------------------
-- Trigger wiring:
--   who header line        → MyDSL.beginWho()
--   "[level class]" line   → MyDSL.parseWhoLine(line)
--   end of who block       → MyDSL.endWho()
--
-- Example: "[51 War] WANTED AFK  Althainia   [Crimson]  Bob  the warrior"
-- Note: kingdom parsing assumes single-word kingdoms (Althainia, etc.).
-- If DSL uses multi-word kingdoms, tune the column logic to your output.

local whoBlock = {}

function MyDSL.beginWho() whoBlock = {} end

function MyDSL.parseWhoLine(line)
  local level, class = line:match("%[(%d+)%s+(%a+)%]")
  if not level then return end

  local entry = {
    level  = tonumber(level),
    class  = trim(class),
    wanted = line:find("WANTED") ~= nil,
    afk    = line:find("%sAFK%s") ~= nil,
    quiet  = line:find("QUIET")  ~= nil,
  }

  -- Everything after the closing bracket
  local rest = line:match("%](.+)$") or ""

  -- Clan is the only part in its own [brackets]
  entry.clan = rest:match("%[([^%]]+)%]")
  rest = rest:gsub("%[[^%]]*%]", "")
    :gsub("WANTED", ""):gsub("%sAFK%s", " "):gsub("QUIET", "")

  -- Remaining words: kingdom  name  title...
  -- Split by any whitespace; kingdom and name are single words in DSL.
  local parts = {}
  for w in rest:gmatch("%S+") do parts[#parts + 1] = w end

  entry.kingdom = parts[1]
  entry.name    = parts[2]
  if #parts > 2 then
    local t = {}
    for i = 3, #parts do t[#t + 1] = parts[i] end
    entry.title = table.concat(t, " ")
  end

  if entry.name then whoBlock[#whoBlock + 1] = entry end
end

function MyDSL.endWho()
  update("who", { players = whoBlock, count = #whoBlock })
  whoBlock = {}
end

------------------------------------------------------------------------
-- 9g  WHOK  (kingdom roster)
------------------------------------------------------------------------

local whokBlock = {}

function MyDSL.beginWhok() whokBlock = {} end

function MyDSL.parseWhokLine(line)
  local level, class = line:match("%[(%d+)%s+(%a+)%]")
  if not level then return end
  local rest  = line:match("%]%s+(.+)$") or ""
  local parts = {}
  for w in rest:gmatch("%S+") do parts[#parts + 1] = w end
  whokBlock[#whokBlock + 1] = {
    level        = tonumber(level),
    class        = trim(class),
    kingdom      = parts[1],
    name         = parts[2],
    rank         = parts[3],
    is_leader    = line:find("[Ll]eader")    ~= nil,
    is_recruiter = line:find("[Rr]ecruiter") ~= nil,
  }
end

function MyDSL.endWhok()
  update("who", { kingdom_members = whokBlock })
  whokBlock = {}
end

------------------------------------------------------------------------
-- 9h  WHOC  (clan roster)
------------------------------------------------------------------------

local whocBlock = {}

function MyDSL.beginWhoc() whocBlock = {} end

function MyDSL.parseWhocLine(line)
  local level, class = line:match("%[(%d+)%s+(%a+)%]")
  if not level then return end
  local rest  = line:match("%]%s+(.+)$") or ""
  local parts = {}
  for w in rest:gmatch("%S+") do parts[#parts + 1] = w end
  whocBlock[#whocBlock + 1] = {
    level        = tonumber(level),
    class        = trim(class),
    clan         = parts[1],
    name         = parts[2],
    rank         = parts[3],
    is_leader    = line:find("[Ll]eader")    ~= nil,
    is_recruiter = line:find("[Rr]ecruiter") ~= nil,
  }
end

function MyDSL.endWhoc()
  update("who", { clan_members = whocBlock })
  whocBlock = {}
end

------------------------------------------------------------------------
-- 9i  GROUP
------------------------------------------------------------------------
-- Example: "[51 War] Olyndros                  100% hp 100% mana 100% mv"
--          "[30 Mob] A throughbred stallion    100% hp 100% mana 100% mv"

local groupBlock = {}

function MyDSL.beginGroup() groupBlock = {} end

function MyDSL.parseGroupLine(line)
  local level, class, name, hp, mana, mv =
    line:match("%[(%d+)%s+(%a+)%]%s+(.-)%s+(%d+)%%%s+hp%s+(%d+)%%%s+mana%s+(%d+)%%%s+mv")
  if not level then return end
  groupBlock[#groupBlock + 1] = {
    level    = tonumber(level),
    class    = trim(class),
    name     = trim(name),
    hp_pct   = tonumber(hp),
    mana_pct = tonumber(mana),
    mv_pct   = tonumber(mv),
    is_mob   = trim(class) == "Mob",
  }
end

function MyDSL.endGroup()
  update("group", { members = groupBlock, count = #groupBlock })
  groupBlock = {}
end

------------------------------------------------------------------------
-- 9j  UNREAD
------------------------------------------------------------------------
-- Single-line.  Game sends this naturally at login and on request.
-- Example: "You have 3 news, 1 note, 0 OOC notes unread."

function MyDSL.parseUnreadLine(line)
  local fields   = {}
  local matched  = false
  local function ex(pattern, key)
    local n = line:match(pattern)
    if n then fields[key] = tonumber(n); matched = true end
  end
  ex("(%d+) news",             "news")
  ex("(%d+) note[^s]",         "notes")
  ex("(%d+) notes[^,]",        "notes")
  ex("(%d+) [Oo][Oo][Cc]",    "ooc_notes")
  ex("(%d+) quest",            "quest_notes")
  ex("(%d+) stor",             "story_notes")
  ex("(%d+) bloodbath",        "bloodbath_notes")
  if matched then update("unread", fields) end
end

------------------------------------------------------------------------
-- 9k  INVENTORY
------------------------------------------------------------------------
-- Example lines: "a glowing sword (Glowing)(Humming)"
--                "3 silver coins"

local invBlock = {}

function MyDSL.beginInv() invBlock = {} end

function MyDSL.parseInvLine(line)
  local s = trim(line)
  if s == "" then return end
  local count, name = s:match("^(%d+)%s+(.+)$")
  if not count then count = 1; name = s end
  local flags = {}
  for flag in name:gmatch("%(([^%)]+)%)") do flags[#flags + 1] = flag end
  name = trim(name:gsub("%s*%([^%)]+%)", ""))
  if name == "" then return end
  invBlock[#invBlock + 1] = { name = name, count = tonumber(count), flags = flags }
end

function MyDSL.endInv()
  update("inv", { items = invBlock, count = #invBlock })
  invBlock = {}
end

------------------------------------------------------------------------
-- 9l  MAP
------------------------------------------------------------------------
-- ASCII map lines captured silently — gagged by triggers, not displayed.

local mapBlock = {}

function MyDSL.beginMap()  mapBlock = {} end
function MyDSL.parseMapLine(line) mapBlock[#mapBlock + 1] = line end

function MyDSL.endMap()
  update("map", { lines = mapBlock, row_count = #mapBlock })
  mapBlock = {}
end

------------------------------------------------------------------------
-- 9m  AFFECTS  (text fallback, used only when GMCP has not yet arrived)
------------------------------------------------------------------------
-- Example: "armor          affects armor class by  -20, for  6 cycles."
--          "You are not affected by any spells."

local affectsTextBlock = {}

function MyDSL.beginAffectsText() affectsTextBlock = {} end

function MyDSL.parseAffectsTextLine(line)
  if line:find("not affected by any") then
    affectsTextBlock = {}
    return
  end
  local name, loc, mod, cycles =
    line:match("^%s*(.-)%s+affects%s+(.-)%s+by%s+([%+%-]?%d+),%s+for%s+(%d+)%s+cycles?%.")
  if name and trim(name) ~= "" then
    local key = trim(name):lower()
    affectsTextBlock[key] = {
      name     = trim(name),
      location = trim(loc),
      modifier = tonumber(mod),
      duration = tonumber(cycles),
      source   = "text",
    }
  end
end

function MyDSL.endAffectsText()
  -- Only apply the text fallback if GMCP affect_data has never arrived.
  -- last_updated == 0 means no GMCP packet has been received this session.
  if MyDSL.State.affects.last_updated == 0 then
    update("affects", { active = affectsTextBlock })
  end
  affectsTextBlock = {}
end

------------------------------------------------------------------------
-- 9n  IMPROVE
------------------------------------------------------------------------
-- Single-line.  Fires naturally when a skill improves during combat.
-- Example: "Your knowledge of bash improves to 72%."

function MyDSL.parseImproveLine(line)
  local skill, pct = line:match("Your knowledge of (.+) improves to (%d+)%%")
  if not skill then
    skill, pct = line:match("You feel yourself getting better at (.+)%. %((%d+)%%%)")
  end
  if skill then
    update("improve", { skill = trim(skill), percent = tonumber(pct) })
  end
end


------------------------------------------------------------------------
-- READY
------------------------------------------------------------------------
debugc("[MyDSL] DataLayer v1.0 loaded. Character: "
  .. tostring(MyDSL.Char() or "(not yet known)"))
