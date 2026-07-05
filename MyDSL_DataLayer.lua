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
-- is_night updated by prompt parser (every server event) and sunrise/sunset triggers (secondary)
MyDSL.State.weather = MyDSL.State.weather or { last_updated = 0 }  -- text: weather description
MyDSL.State.who     = MyDSL.State.who     or { last_updated = 0 }  -- text: online player list
MyDSL.State.group   = MyDSL.State.group   or { last_updated = 0 }  -- text: party members
MyDSL.State.unread  = MyDSL.State.unread  or { last_updated = 0 }  -- text: unread message counts
MyDSL.State.inv     = MyDSL.State.inv     or { last_updated = 0 }  -- text: carried item list
MyDSL.State.map     = MyDSL.State.map     or { last_updated = 0 }  -- text: ASCII map lines
MyDSL.State.improve = MyDSL.State.improve or { last_updated = 0 }  -- text: skill improve events
MyDSL.State.flags        = MyDSL.State.flags        or { last_updated = 0 }  -- text: toggle flags from score
MyDSL.State.scan         = MyDSL.State.scan         or {  -- text: nearby entities from scan command
  mode=nil, direction=nil, rows={}, rightHere={}, byName={}, last_updated=0
}
MyDSL.State.creaturelore = MyDSL.State.creaturelore or { last_updated = 0 }  -- text: creature lore block
MyDSL.State.combat = MyDSL.State.combat or {
  active      = {},    -- keyed by target-key; each entry: {target_display, target_condition, by_attacker, started_at}
  history     = {},    -- array of snapshots (same shape), most recent first
  history_max = 5,
  round_data  = {},    -- per-(attacker→target→noun) accumulators, cleared each round
  rage        = { damage = 0, vamp = 0 },
  last_updated = 0,
}

-- Per-character persistent storage.  Keyed by character name so Kien,
-- Vrokt, Olyndros etc each have completely separate saved state.
MyDSL.Data = MyDSL.Data or {}

-- Lua callback listeners registered by display modules via MyDSL.on().
MyDSL.listeners = MyDSL.listeners or {}

-- Numeric handler IDs from registerAnonymousEventHandler, kept so we
-- can kill them cleanly when the script reloads.
MyDSL._handlers = MyDSL._handlers or {}

-- Trigger IDs from tempRegexTrigger, kept so we can kill them on reload.
MyDSL._triggers = MyDSL._triggers or {}


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

-- Kill any tempRegexTrigger triggers left from a previous script load.
for _, id in pairs(MyDSL._triggers) do pcall(killTrigger, id) end
MyDSL._triggers = {}

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
      hp_raw           = tostring(d.hp or ""),  -- rage mode: GMCP sends "???" → tonumber gives nil; hp_raw preserves it
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
-- Trigger wiring is done in code at the bottom of this file.
-- beginScore() is called by a permanent tempRegexTrigger on "^Score for ".
-- It installs a catch-all line trigger that feeds every subsequent line to
-- parseScoreLine(). The catch-all is killed by endScore() so it is only
-- active during the score block.
--
-- The score block has three "^---" separator lines:
--   Line 1: "Score for Kien -= Zandreya =- ..."  → beginScore()
--   Line 2: "---..."                              → first separator, skip
--   Lines 3-N: main stat body                    → parseScoreLine()
--   Line N+1: "---..."                            → middle separator, skip
--   Lines N+2-M: PROFESSION / Reclass section    → parseScoreLine()
--   Line M+1: "---..."                            → endScore() (only after _saw_profession)

local scoreBlock = nil

function MyDSL.beginScore(charName)
  scoreBlock = { name = trim(charName), lines = {}, _saw_sep = false, _saw_profession = false }
  -- Install a catch-all trigger to pipe subsequent lines to parseScoreLine.
  -- Killed by endScore() so it is never active outside a score block.
  if MyDSL._triggers.scoreParse then
    pcall(killTrigger, MyDSL._triggers.scoreParse)
  end
  MyDSL._triggers.scoreParse = tempRegexTrigger(
    ".*",
    [[if MyDSL and MyDSL.parseScoreLine then MyDSL.parseScoreLine(line) end]]
  )
end

function MyDSL.parseScoreLine(line)
  if not scoreBlock then return end
  -- Three "^---" separator lines in the block:
  -- First (after header): skip. Middle (before PROFESSION section): skip.
  -- Final (after PROFESSION section): commit — but only once _saw_profession is true.
  if line:match("^%-%-%-") then
    if not scoreBlock._saw_sep then
      scoreBlock._saw_sep = true   -- first separator, skip
      return
    elseif scoreBlock._saw_profession then
      MyDSL.endScore()             -- final separator, after PROFESSION — commit
      return
    else
      return                       -- middle separator, before PROFESSION — skip
    end
  end
  scoreBlock.lines[#scoreBlock.lines + 1] = line

  local v  -- reused temp

  -- LEVEL: 051  Race: High Elf  Played: 1234
  local lv, race, played =
    line:match("LEVEL:%s*(%d+)%s+Race%s*:%s*(.-)%s+Played:%s*(%d+)")
  if lv then
    scoreBlock.level        = tonumber(lv)
    scoreBlock.race         = trim(race)
    scoreBlock.played_hours = tonumber(played)
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
    scoreBlock.sex        = sx
    scoreBlock.reclass_at = rc ~= "" and rc or nil
    return
  end

  -- Stats: STR  : 051(050)  INT  : 064(064)  etc. — stored flat on scoreBlock
  for _, stat in ipairs({ "STR", "INT", "WIS", "DEX", "CON" }) do
    local cur, base = line:match(stat .. "%s*:%s*(%d+)%((%d+)%)")
    if cur then
      local k = stat:lower()
      scoreBlock[k]            = tonumber(cur)
      scoreBlock[k .. "_base"] = tonumber(base)
    end
  end

  -- HitRoll: B:21  P:31   (on STR line)
  local hB, hP = line:match("HitRoll:%s*B:([%+%-]?%d+)%s+P:([%+%-]?%d+)")
  if hB then scoreBlock.hit_roll_base = tonumber(hB); scoreBlock.hit_roll = tonumber(hP) end

  -- DamRoll: B:37  P:47   (on INT line)
  local dB, dP = line:match("DamRoll:%s*B:([%+%-]?%d+)%s+P:([%+%-]?%d+)")
  if dB then scoreBlock.dam_roll_base = tonumber(dB); scoreBlock.dam_roll = tonumber(dP) end

  -- Items: 133   (max 196  )   (on STR line)
  local items_cur, items_max = line:match("Items:%s*(%d+)%s+%(max%s+(%d+)%s*%)")
  if items_cur then
    scoreBlock.items     = tonumber(items_cur)
    scoreBlock.max_items = tonumber(items_max)
  end

  -- Weight: 592   (max 603   )   (on INT line — was missing entirely)
  local wt, mwt = line:match("Weight:%s*(%d+)%s+%(max%s+(%d+)%s*%)")
  if wt then
    scoreBlock.weight     = tonumber(wt)
    scoreBlock.max_weight = tonumber(mwt)
  end

  -- Armor: P:-160 B:-160 S:-160 M:-80   (on WIS line)
  local ap, ab, as_, am =
    line:match("Armor:%s*P:([%+%-]?%d+)%s+B:([%+%-]?%d+)%s+S:([%+%-]?%d+)%s+M:([%+%-]?%d+)")
  if ap then
    scoreBlock.armor_pierce = tonumber(ap)
    scoreBlock.armor_bash   = tonumber(ab)
    scoreBlock.armor_slash  = tonumber(as_)
    scoreBlock.armor_magic  = tonumber(am)
  end

  -- Hitpoints / Mana / Move
  local hp, mhp = line:match("Hitpoints:%s*(%d+)%s+of%s+(%d+)")
  if hp then scoreBlock.hp = tonumber(hp); scoreBlock.max_hp = tonumber(mhp) end
  local mn, mmn = line:match("Mana:%s*(%d+)%s+of%s+(%d+)")
  if mn then scoreBlock.mana = tonumber(mn); scoreBlock.max_mana = tonumber(mmn) end
  local mv, mmv = line:match("Move:%s*(%d+)%s+of%s+(%d+)")
  if mv then scoreBlock.move = tonumber(mv); scoreBlock.max_move = tonumber(mmv) end

  -- GOLD : 222  Silver: 187   (actual caps/spacing — old code used Gold: which never matched)
  local g, s = line:match("GOLD%s*:%s*(%d+)%s+Silver:%s*(%d+)")
  if g then scoreBlock.gold = tonumber(g); scoreBlock.silver = tonumber(s) end

  -- BANK : 60  QPoints: 1164   (old code: Bank:/Qpoints: — both wrong)
  local bk, qp = line:match("BANK%s*:%s*(%d+)%s+QPoints:%s*(%d+)")
  if bk then scoreBlock.bank = tonumber(bk); scoreBlock.qpoints = tonumber(qp) end

  v = line:match("PRACT:%s*(%d+)");       if v then scoreBlock.practices = tonumber(v) end
  v = line:match("TRAIN:%s*(%d+)");       if v then scoreBlock.trains    = tonumber(v) end
  v = line:match("XP%s*:%s*(%d+)");       if v then scoreBlock.xp       = tonumber(v) end
  v = line:match("TNL:%s*(%d+)");         if v then scoreBlock.tnl      = tonumber(v) end
  -- Align: stops at double-space so "Prestige hours: 460" on the same line is excluded
  v = line:match("Align:%s*(.-)%s%s");    if v then scoreBlock.align    = trim(v) end
  v = line:match("Wimpy:%s*(%d+)");       if v then scoreBlock.wimpy    = tonumber(v) end
  -- Pos'n: single-word value (Standing/Sleeping/etc.) followed by flag columns
  v = line:match("Pos'n:%s*(%S+)");       if v then scoreBlock.position = trim(v) end
  v = line:match("Stance:%s*(%S+)");       if v then scoreBlock.stance      = v end
  v = line:match("Speaking:%s*(%S+)");    if v then scoreBlock.language   = v end
  v = line:match("Religion:%s*(.+)$");    if v then scoreBlock.religion   = trim(v) end
  v = line:match("PROFESSION:%s*(.+)$")
  if v then scoreBlock.profession = trim(v); scoreBlock._saw_profession = true end

  -- Craftskill: 241  Craft Rank: Apprentice Hunter
  -- Old code looked for "Craft: name pct%" which is completely wrong format.
  -- Key is the craft type (last word of rank), value is 1-1000 skillpoints.
  local cs, cr = line:match("Craftskill:%s*(%d+)%s+Craft Rank:%s*(.+)$")
  if cs then
    scoreBlock.crafts = scoreBlock.crafts or {}
    local type_word = trim(cr):match("%S+$")
    if type_word then
      scoreBlock.crafts[type_word:lower()] = tonumber(cs)
    end
  end

  -- PKill: [ Win: 0  Giants: 0  BB Wins: 0 ]   (old code: PKills:/PKilled: — wrong format)
  local pk_win, pk_giants, pk_bb =
    line:match("PKill:.*Win:%s*(%d+).*Giants:%s*(%d+).*BB Wins:%s*(%d+)")
  if pk_win then
    scoreBlock.pkills        = tonumber(pk_win)
    scoreBlock.pkills_giants = tonumber(pk_giants)
    scoreBlock.pkills_bb     = tonumber(pk_bb)
  end
end

function MyDSL.endScore()
  -- Kill the catch-all line trigger before doing anything else.
  if MyDSL._triggers.scoreParse then
    pcall(killTrigger, MyDSL._triggers.scoreParse)
    MyDSL._triggers.scoreParse = nil
  end
  if not scoreBlock then return end
  local fields = { raw = scoreBlock.lines }
  for k, v in pairs(scoreBlock) do
    if k ~= "lines" and k ~= "_saw_sep" and k ~= "_saw_profession" then fields[k] = v end
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
  -- Detect "(X)" = ON and "( )" = OFF. Pattern handles both "Flag(X)" and "Flag (X)".
  -- Old code only checked word presence, never read the X/space state.
  for name, state in line:gmatch("(%w+)%s*%(([X ])%)") do
    local canon = FLAG_SET[name:lower()]
    if canon then flagsBlock[canon] = (state == "X") end
  end
end

function MyDSL.endFlags()
  -- parseFlagsLine writes true/false per flag. nil means the line was never seen
  -- (treat as OFF). "flag == true" collapses nil→false, false→false, true→true.
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
-- Actual 2-line-per-moon format (confirmed from in-game capture):
--   The red moon is full and not visible.
--      [Mana +15%]  [Saves -3]  [Casting +3]  [Regen   0%]  [Cycles remaining 45 (22 Hours)]
--   The white moon is crescent waning and not visible.
--      [Mana +5%]   [Saves -1]  [Casting +1]  [Regen   0%]  [Cycles remaining 12 (6 Hours)]
-- Old code expected a completely different single-line format — full rewrite.

local lunarBlock = {}
local MOON_COLORS = { red = true, white = true, black = true }

function MyDSL.beginLunar()
  -- Reset the in-progress block. Each moon sub-table pre-initialised with
  -- has_bonuses=false so the field always exists even when no bonus block arrives.
  lunarBlock = {
    red   = { has_bonuses = false },
    white = { has_bonuses = false },
    black = { has_bonuses = false },
    _last = nil,
  }
end

function MyDSL.parseLunarLine(line)
  -- Type 1 — Moon description line:
  --   "The red moon is empty and not visible."
  --   "The white moon is waxing three-quarters and in high sanction."
  -- Three-capture pattern splits color, phase, and raw position in one step.
  -- The optional %.? accepts lines with or without a trailing period.
  local color, phase, position = line:match("^The (%a+) moon is (.+) and (.-)%.?$")
  if color and MOON_COLORS[color] then
    -- Strip "in " prefix so "in high sanction" → "high sanction".
    position = (position or ""):gsub("^in ", "")
    local moon = lunarBlock[color]
    moon.phase       = trim(phase or "")
    moon.position    = trim(position)
    moon.has_bonuses = false  -- remains false unless a bonus line follows
    lunarBlock._last = color
    return
  end

  -- Type 2 — Bonus stat line (only for focal moon with high Astrology):
  --   "   [Mana   0%]  [Saves  0]  [Casting  0]  [Regen   0%]  [Cycles remaining 38 (19 1/2 Hours)]"
  -- %s+ handles multiple spaces between label and value (game output is ragged).
  if lunarBlock._last and line:find("%[Mana") then
    local moon = lunarBlock[lunarBlock._last]
    moon.mana_bonus       = tonumber(line:match("%[Mana%s+([%+%-]?%d+)%%%]"))
    moon.saves_modifier   = tonumber(line:match("%[Saves%s+([%+%-]?%d+)%]"))
    moon.casting_modifier = tonumber(line:match("%[Casting%s+([%+%-]?%d+)%]"))
    moon.regen_pct        = tonumber(line:match("%[Regen%s+([%+%-]?%d+)%%%]"))
    moon.cycles_remaining = tonumber(line:match("%[Cycles remaining (%d+)"))
    -- Capture integer hours from "(19 1/2 Hours)" or "(22 Hours)".
    -- [^%)]* eats the fractional part so the capture is always just the integer.
    moon.hours_remaining  = tonumber(line:match("%((%d+)[^%)]*%)"))
    moon.has_bonuses      = true
  end
end

function MyDSL.endLunar()
  update("lunar", {
    red       = lunarBlock.red   or {},
    white     = lunarBlock.white or {},
    black     = lunarBlock.black or {},
    parsed_at = os.time(),   -- timestamp for MoonWeather countdown anchor
  })
  lunarBlock = {}
  MyDSL.save()
end

------------------------------------------------------------------------
-- 9d  TIME
------------------------------------------------------------------------
-- Single-line.  Trigger matches "It is \d" and calls this.
-- Two confirmed real formats (both must match):
--   "It is 9:30 am, Day of the Great Gods, 26th the Month of the Great Evil."
--   "It is 10:00 o'clock am, Day of the Great Gods, 26th the Month of the Great Evil."
-- Old code only handled a single wrong variant ("on the Day of", no HH:MM).
-- New pattern: [^,]- lazily skips " o'clock" when present, absorbs nothing otherwise.

function MyDSL.parseTimeLine(line)
  local hour, min, ampm, day_name, day_num, month =
    line:match("It is (%d+):(%d+)[^,]-(%a+), Day of ([^,]+), (%d+)%a+ the Month of ([^%.]+)")
  if hour then
    update("time", {
      hour     = tonumber(hour),
      minute   = tonumber(min) or 0,
      ampm     = ampm,
      day_name = trim(day_name),
      day_num  = tonumber(day_num),
      month    = trim(month),
    })
  end
end

------------------------------------------------------------------------
-- 9d2  PROMPT LINE (day/night period)
------------------------------------------------------------------------
-- Fires on prompt line 2 (fires every server event — most reliable day/night source):
--   "==-Night Time - 5:00am :: [room] :: [exits]-=="
--   "==-Day Time - 10:30am :: ..."
--   "==-Dawn - 6:00am :: ..."
-- Period confirmed from live session (Steven, 2026-06-30): Night Time, Dawn, Day Time.

function MyDSL.parsePromptLine(line)
  local period = line:match("^==%-(%a[%a%s]+) %- %d+:%d+%a+ :: ")
  if not period then return end
  period = trim(period)
  if period == "" then return end
  MyDSL.State.time.period   = period
  MyDSL.State.time.is_night = (period == "Night Time")
  MyDSL.State.time.last_updated = now()
  MyDSL.emit("time")
end

------------------------------------------------------------------------
-- 9e  WEATHER
------------------------------------------------------------------------
-- Single-line.  Trigger matches a weather description line.
-- Example: "A light snow falls quietly from the sky."

-- Weather keyword guard: the trigger pattern is broad (any capitalised sentence)
-- so we filter here. Require at least one atmospheric/weather-indicative word.
-- Expand this list as more weather line formats are confirmed in CommandRef.
local _weatherWords = {
  "cloud", "breeze", "wind", "rain", "snow", "storm", "fog", "sky",
  "sun", "wave", "shore", "ocean", "drizzle", "mist", "hail",
  "thunder", "lightning", "overcast", "chilly", "sleet",
}

function MyDSL.parseWeatherLine(line)
  local desc = trim(line)
  if desc == "" then return end
  local lc = desc:lower()
  local found = false
  for _, w in ipairs(_weatherWords) do
    if lc:find(w, 1, true) then found = true; break end
  end
  if not found then return end
  update("weather", { description = desc })
end

------------------------------------------------------------------------
-- 9f  WHO
------------------------------------------------------------------------
-- Trigger wiring:
--   who header line        → MyDSL.beginWho()
--   "[level class]" line   → MyDSL.parseWhoLine(line)
--   end of who block       → MyDSL.endWho()
--
-- Format: "[level race class] (org) name title"
-- Bracket contains THREE tokens: level, race, class.
-- Races include hyphens (W-Elf, M-Dwf, D-Elf, H-Ogre) so %a+ was wrong.
-- Old code: "%[(%d+)%s+(%a+)%]" — only captured level + one word (was treating race as class).
-- New code: captures all three tokens from the bracket.

local whoBlock = {}

function MyDSL.beginWho() whoBlock = {} end

function MyDSL.parseWhoLine(line)
  local level, race, class = line:match("%[%s*(%d+)%s+([%w%-]+)%s+(%w+)%]")
  if not level then return end

  local entry = {
    level  = tonumber(level),
    race   = trim(race),
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
-- beginGroup() is called by a permanent trigger on "^.+'s group:$".
-- It installs a catch-all body trigger that feeds each line to
-- parseGroupLine() and kills itself on blank line (calling endGroup()).

local groupBlock = {}

function MyDSL.beginGroup()
  groupBlock = {}
  -- Kill any leftover catch-all from a previous group block that never ended.
  if MyDSL._triggers.groupBody then
    pcall(killTrigger, MyDSL._triggers.groupBody)
    MyDSL._triggers.groupBody = nil
  end
  MyDSL._triggers.groupBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    -- Blank line signals end of group block.
    if t == "" then MyDSL.endGroup(); return end
    if MyDSL.parseGroupLine then MyDSL.parseGroupLine(ln) end
    -- Body line gagging delegated here so GroupView doesn't need its own body trigger.
    if MyDSL.GroupView and MyDSL.GroupView.config and MyDSL.GroupView.config.gagGroup then
      deleteLine()
    end
  end)
end

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
  -- Kill the catch-all before updating State to avoid re-entry.
  if MyDSL._triggers.groupBody then
    pcall(killTrigger, MyDSL._triggers.groupBody)
    MyDSL._triggers.groupBody = nil
  end
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
-- Confirmed format (from in-game capture):
--   "Spell: detect hidden     : modifies none by 0 for 32 cycles, (16 hours)"
--   "Spell: detect invis      : modifies none by 0 for 32 cycles, (16 hours)"
-- Old code matched "name affects loc by mod, for N cycles." — completely wrong format.

local affectsTextBlock = {}

function MyDSL.beginAffectsText() affectsTextBlock = {} end

function MyDSL.parseAffectsTextLine(line)
  if line:find("not affected by any") then
    affectsTextBlock = {}
    return
  end
  -- "Spell: <name>  : modifies <loc> by <mod> for <cycles> cycles, (<hours> hours)"
  local name, loc, mod, cycles, hours =
    line:match("^Spell:%s*(.-)%s*:%s*modifies%s+(%S+)%s+by%s+([%+%-]?%d+)%s+for%s+(%d+)%s+cycles?,%s+%((%d+)%s+hours?%)")
  if name and trim(name) ~= "" then
    local key = trim(name):lower()
    affectsTextBlock[key] = {
      name     = trim(name),
      location = trim(loc),
      modifier = tonumber(mod),
      duration = tonumber(cycles),
      hours    = tonumber(hours),
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
-- 9o  SCAN
------------------------------------------------------------------------
-- Trigger wiring is in Section 10 below.
-- beginScan() is called by permanent triggers on "^Looking around you see:$"
-- and "^You peer intently (%a+)%.$". It resets State.scan and installs a
-- catch-all that feeds body lines to parseScanLine(). endScan() is called
-- by the catch-all on blank line, "Players near you:", or group header.

-- Article-detection helper — mobs always start with a/an/the, players don't.
local function isMobName(name)
  return name:match("^[Aa]n? ") ~= nil or name:match("^[Tt]he ") ~= nil
end

function MyDSL.beginScan(mode, direction)
  -- Fresh table replaces any stale scan state.
  MyDSL.State.scan = {
    mode         = mode,
    direction    = direction,
    rows         = {},
    rightHere    = {},
    byName       = {},
    last_updated = 0,
  }
  -- Clear Scan window for the incoming lines.
  if MyDSL.ScanView and MyDSL.ScanView.ui and MyDSL.ScanView.ui.scanConsole then
    MyDSL.ScanView.ui.scanConsole:clear()
  end
  -- Kill any leftover catch-all from a previous scan that never ended.
  if MyDSL._triggers.scanBody then
    pcall(killTrigger, MyDSL._triggers.scanBody)
    MyDSL._triggers.scanBody = nil
  end
  MyDSL._triggers.scanBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.scan) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    if t == "" then MyDSL.endScan(); return end
    if t == "Players near you:" then MyDSL.endScan(); return end
    if t:match("^.+%'s group:$") then MyDSL.endScan(); return end
    if t == "Looking around you see:" then return end  -- skip header if re-seen
    if MyDSL.parseScanLine then MyDSL.parseScanLine(ln) end
    selectCurrentLine()
    copy()
    if MyDSL.ScanView and MyDSL.ScanView.ui and MyDSL.ScanView.ui.scanConsole then
      MyDSL.ScanView.ui.scanConsole:appendBuffer()
    end
  end)
end

function MyDSL.parseScanLine(line)
  local scan = MyDSL.State.scan
  if not scan then return end
  local name, where
  name = line:match("^(.+),%s+right here%.?$")
  if name then where = "right here" end
  if not name then
    name, where = line:match("^(.+),%s+(nearby to .+)%.?$")
  end
  if not name then
    name, where = line:match("^(.+),%s+(not far .+)%.?$")
  end
  if not name then return end
  name         = trim(name)
  local key    = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  local is_mob = isMobName(name)
  local row = {
    raw     = line,
    name    = name,
    display = name,
    key     = key,
    where   = where,
    is_mob  = is_mob,
    count   = 1,
  }
  table.insert(scan.rows, row)
  if scan.byName[key] then
    scan.byName[key].count = scan.byName[key].count + 1
  else
    scan.byName[key] = {
      raw     = line,
      name    = name,
      display = name,
      key     = key,
      where   = where,
      is_mob  = is_mob,
      count   = 1,
    }
  end
  if where == "right here" then
    if scan.rightHere[key] then
      scan.rightHere[key].count = scan.rightHere[key].count + 1
    else
      scan.rightHere[key] = {
        raw     = line,
        name    = name,
        display = name,
        key     = key,
        where   = where,
        is_mob  = is_mob,
        count   = 1,
      }
    end
  end
  -- ScanView body-line gagging (header lines gagged by ScanView's own triggers).
  if MyDSL.ScanView and MyDSL.ScanView.config and MyDSL.ScanView.config.gagScan then
    deleteLine()
  end
end

function MyDSL.endScan()
  if MyDSL._triggers.scanBody then
    pcall(killTrigger, MyDSL._triggers.scanBody)
    MyDSL._triggers.scanBody = nil
  end
  MyDSL.State.scan.last_updated = os.time()
  MyDSL.emit("scan")
end

------------------------------------------------------------------------
-- 9p  CREATURELORE
------------------------------------------------------------------------
-- beginCreatureLore() fires on "^Creature:%s" and parses name+race from
-- the first line. A catch-all feeds body lines to parseCreatureLoreLine().
-- endCreatureLore() fires on blank line, commits to State, and optionally
-- merges into MyDSL_creaturelore.lua DB if that module is loaded.

function MyDSL.beginCreatureLore(line)
  local name, race = line:match("^Creature:%s*(.-)%s+Race:%s*(.+)$")
  name = trim(name or "")
  race = trim(race or "")
  local key = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  MyDSL.State.creaturelore = {
    name         = name,
    race         = race,
    key          = key,
    lines        = { line },
    last_updated = 0,
  }
  -- Kill leftover catch-all if a previous lore block never ended.
  if MyDSL._triggers.loreBody then
    pcall(killTrigger, MyDSL._triggers.loreBody)
    MyDSL._triggers.loreBody = nil
  end
  MyDSL._triggers.loreBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.creaturelore) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    if t == "" then MyDSL.endCreatureLore(); return end
    if MyDSL.parseCreatureLoreLine then MyDSL.parseCreatureLoreLine(ln) end
  end)
end

function MyDSL.parseCreatureLoreLine(line)
  local r = MyDSL.State.creaturelore
  if not r then return end
  table.insert(r.lines, line)
  -- Alignment: "They appear to be a good soul."
  local a = line:match("^.- appears to be (.+) soul%.")
  if a then r.alignmentText = trim(a) end
  -- Wealth: "Their wealth appears to be 5 gold and 10 silver."
  local g, s = line:match("Their wealth appears to be%s+(%d+)%s+gold and%s+(%d+)%s+silver")
  if g then r.gold = tonumber(g); r.silver = tonumber(s) end
  -- Sex: "They appear to be Undetermined sex." — skip if alignment already matched.
  -- The alignment line also matches "They appear to be ...", so guard with alignmentText.
  local x = line:match("^They appear to be%s+(.+)%.")
  if x and not r.alignmentText then r.sex = trim(x) end
  -- HP: "The base health of this creature is 1000."
  local h = line:match("^The base health of this creature is%s+(%d+)%.")
  if h then r.hp = tonumber(h) end
end

function MyDSL.endCreatureLore()
  if MyDSL._triggers.loreBody then
    pcall(killTrigger, MyDSL._triggers.loreBody)
    MyDSL._triggers.loreBody = nil
  end
  MyDSL.State.creaturelore.last_updated = os.time()
  -- Merge into persistent DB if MyDSL_creaturelore.lua is loaded.
  if MyDSL.CreatureLore and MyDSL.CreatureLore.merge then
    MyDSL.CreatureLore.merge(MyDSL.State.creaturelore)
  end
  MyDSL.emit("creaturelore")
end


------------------------------------------------------------------------
-- 9q  COMBAT
------------------------------------------------------------------------
-- Always-active triggers (no begin/end block — DSL emits combat lines
-- continuously with no header). Each trigger feeds a shared accumulator.
-- Round boundary: MyDSL.time.updated (prompt reprints every combat round).

-- ---- Severity ladder (PNP's exact tuned values) ---------------------
local SEVERITY_LADDER = {
  { score=0,   word="miss"          },
  { score=2.5, word="scratch"       },
  { score=6.5, word="graze"         },
  { score=10.5,word="hit"           },
  { score=14.5,word="injure"        },
  { score=18.5,word="wound"         },
  { score=22.5,word="maul"          },
  { score=26.5,word="decimate"      },
  { score=30.5,word="devastate"     },
  { score=34.5,word="maim"          },
  { score=38.5,word="MUTILATE"      },
  { score=42.5,word="DISEMBOWEL"    },
  { score=46.5,word="DISMEMBER"     },
  { score=50.5,word="MASSACRE"      },
  { score=54.5,word="MANGLE"        },
  { score=58.5,word="DEMOLISH"      },
  { score=68,  word="DEVASTATE"     },
  { score=88,  word="OBLITERATE"    },
  { score=113, word="ANNIHILATE"    },
  { score=138, word="ERADICATE"     },
  { score=163, word="GHASTLY"       },
  { score=188, word="HORRID"        },
  { score=213, word="DREADFUL"      },
  { score=238, word="HIDEOUS"       },
  { score=263, word="INDESCRIBABLE" },
  { score=276, word="UNSPEAKABLE"   },
}

local SEVERITY_SCORE = {}
for _, e in ipairs(SEVERITY_LADDER) do SEVERITY_SCORE[e.word] = e.score end

function MyDSL.derivedVerbForScore(score)
  local result = "miss"
  for _, e in ipairs(SEVERITY_LADDER) do
    if e.score <= score then result = e.word else break end
  end
  return result
end

-- ---- Condition ladder -----------------------------------------------
local CONDITION_PATTERNS = {
  { pat = " is in excellent condition",       label = "excellent"    },
  { pat = " has a few scratches",             label = "few scratches" },
  { pat = " has some small wounds",           label = "small wounds"  },
  { pat = " has some big nasty wounds",       label = "big wounds"    },
  { pat = " has quite a few wounds",          label = "quite a few"   },
  { pat = " looks pretty hurt",               label = "pretty hurt"   },
  { pat = " is in awful condition",           label = "awful"         },
}

-- ---- Scope + key helpers --------------------------------------------
local function normalizeKey(name)
  if not name then return "" end
  local s = trim(name:lower())
  s = s:gsub("^a%s+", ""):gsub("^an%s+", ""):gsub("^the%s+", "")
  return trim(s)
end

-- Named weapons are sometimes quoted in proc text (e.g. "Nadrik's Honor").
-- Strip the quote characters before normalizing so the key matches the
-- unquoted form used elsewhere.
local function stripQuotes(s)
  return (s or ""):gsub('"', "")
end

-- Weapon-flag proc lines often name the weapon wielding a flag, not the
-- wielder (e.g. "A grand arcanium hoopak draws life from Kien.") -- we
-- can't resolve an arbitrary weapon name back to its wielder from text
-- alone. Used to tell a real combatant key apart from a likely weapon name.
local function isKnownCombatant(key)
  if key == "you" then return true end
  local grp = MyDSL.State.group and MyDSL.State.group.members
  if not grp then return false end
  for _, m in ipairs(grp) do
    if normalizeKey(m.name) == key then return true end
  end
  return false
end

local function ensureActive(tKey, tDisplay)
  if not MyDSL.State.combat.active[tKey] then
    MyDSL.State.combat.active[tKey] = {
      target_display   = tDisplay or tKey,
      target_condition = "unknown",
      by_attacker      = {},
      started_at       = os.time(),
    }
  end
  return MyDSL.State.combat.active[tKey]
end

local function snapshotFight(tKey)
  local entry = MyDSL.State.combat.active[tKey]
  if not entry then return nil end
  local hist = MyDSL.State.combat.history
  table.insert(hist, 1, entry)
  while #hist > MyDSL.State.combat.history_max do table.remove(hist) end
  MyDSL.State.combat.active[tKey] = nil
  return entry
end

-- ---- parseCombatDamageLine ------------------------------------------
local FALSE_POSITIVE_GUARDS = {"You gain", "has big nasty", "Affects", "has some small", "Wimpy"}

function MyDSL.parseCombatDamageLine(attacker, noun, verb, target, punct)
  -- PNP's false-positive guard
  local combined = (attacker or "") .. " " .. (noun or "")
  for _, g in ipairs(FALSE_POSITIVE_GUARDS) do
    if combined:find(g, 1, true) then return end
  end

  attacker = trim(attacker or "")
  noun     = trim(noun     or "")
  verb     = trim(verb     or "")
  target   = trim(target   or "")
  if noun == "" then noun = "strike" end

  local aKey = (attacker == "You" or attacker:lower() == "you") and "you"
               or normalizeKey(attacker)
  local tKey = (target:lower() == "you") and "you" or normalizeKey(target)

  -- No relevance filter, matching PNP: it tracks every combat line it sees
  -- unfiltered, relying on DSL only ever showing you combat in your own
  -- vicinity (which naturally includes group members fighting nearby).
  -- Confirmed 2026-07-05 -- our own isRelevant() filter was an unnecessary
  -- restriction PNP never had.

  local score = SEVERITY_SCORE[verb] or 0
  local entry = ensureActive(tKey, target)
  local ba    = entry.by_attacker
  ba[aKey]       = ba[aKey]       or {}
  ba[aKey][noun] = ba[aKey][noun] or { swings=0, hits=0, misses=0, score_total=0, flags={} }
  local nd = ba[aKey][noun]
  nd.swings = nd.swings + 1
  if verb == "miss" then
    nd.misses = nd.misses + 1
  else
    nd.hits        = nd.hits + 1
    nd.score_total = nd.score_total + score
  end

  -- Compound-noun proc flags (e.g. "life drain" → vampiric H, "shocking bite" → lightning L)
  local NOUN_FLAG_MAP = { ["life drain"] = "H", ["shocking bite"] = "L" }
  local impliedFlag = NOUN_FLAG_MAP[noun:lower()]
  if impliedFlag and verb ~= "miss" then
    nd.flags[impliedFlag] = (nd.flags[impliedFlag] or 0) + 1
    if impliedFlag == "H" and aKey == "you" then
      MyDSL.State.combat.rage.vamp = MyDSL.State.combat.rage.vamp + 2.5
    end
  end

  -- Round accumulation
  local rd    = MyDSL.State.combat.round_data
  local rdKey = aKey .. "→" .. tKey .. "→" .. noun
  rd[rdKey] = rd[rdKey] or { attacker=aKey, target=tKey, noun=noun, score=0, swings=0, hits=0 }
  rd[rdKey].score  = rd[rdKey].score + score
  rd[rdKey].swings = rd[rdKey].swings + 1
  if verb ~= "miss" then rd[rdKey].hits = rd[rdKey].hits + 1 end

  -- Rage: accumulate damage taken by you
  if tKey == "you" then
    MyDSL.State.combat.rage.damage = MyDSL.State.combat.rage.damage + score
  end
end

-- ---- parseCombatAvoidLine -------------------------------------------
-- Two call shapes:
--   (evader, verb, attacker) -- dodge/parry/block triggers, PNP-derived PCRE
--     capture groups. attacker is the literal word "your" when you're the
--     one whose attack got avoided, otherwise a "Name's" possessive.
--   (line)                   -- sense triggers, still whole-line Lua-pattern
--     parsed (unchanged; not part of the PNP evasion-trigger port).
function MyDSL.parseCombatAvoidLine(evader, verb, attacker)
  if not attacker then
    local line = evader
    evader, attacker = line:match("^(.+) senses (.+)'s attack coming and avoids")
    if not evader then evader = line:match("^(.+) senses they'?re about to be hit") end
    if not evader then return end
  end

  evader = trim(evader)
  local eKey = normalizeKey(evader)
  local aKey
  if attacker and attacker:lower() == "your" then
    aKey = "you"
  elseif attacker then
    aKey = normalizeKey(trim(attacker):gsub("'s$", ""))
  else
    aKey = "unknown"
  end

  -- No relevance filter here either, same reasoning as parseCombatDamageLine.

  local entry = ensureActive(eKey, evader)
  entry.by_attacker[aKey] = entry.by_attacker[aKey] or {}
  entry.by_attacker[aKey]["(evade)"] = entry.by_attacker[aKey]["(evade)"]
    or { swings=0, hits=0, misses=0, score_total=0, flags={} }
  entry.by_attacker[aKey]["(evade)"].swings = entry.by_attacker[aKey]["(evade)"].swings + 1

  local rd    = MyDSL.State.combat.round_data
  local rdKey = aKey .. "→" .. eKey .. "→(evade)"
  rd[rdKey] = rd[rdKey] or { attacker=aKey, target=eKey, noun="(evade)", score=0, swings=0, hits=0 }
  rd[rdKey].swings = rd[rdKey].swings + 1
end

-- ---- parseCombatConditionLine ---------------------------------------
function MyDSL.parseCombatConditionLine(line)
  local name, label
  for _, c in ipairs(CONDITION_PATTERNS) do
    local idx = line:find(c.pat, 1, true)
    if idx and idx > 1 then
      name  = trim(line:sub(1, idx - 1))
      label = c.label
      break
    end
  end
  if not name or not label then return end

  local tKey = normalizeKey(name)
  local entry = MyDSL.State.combat.active[tKey]
  if not entry then return end  -- not tracking this target, skip
  entry.target_condition = label
end

-- ---- parseCombatDeathLine -------------------------------------------
function MyDSL.parseCombatDeathLine(line)
  -- Two confirmed death-message forms (DSL-Logs, 2026-07-05 audit):
  -- "<mob> is DEAD!!" (room/kill broadcast) and "<mob> hits the ground ...
  -- DEAD." (the killing-blow line, seen exclusively in some sessions with
  -- zero "is DEAD!!" anywhere). Both fire for the same kill in some logs,
  -- only one in others -- treat identically. snapshotFight() already
  -- returns nil and no-ops if the target was already cleared, so if both
  -- somehow fire for the same death this doesn't double-snapshot.
  local name = line:match("^(.+) is DEAD!!$")
  if not name then name = line:match("^(.+) hits the ground %.%.%. DEAD%.$") end
  if not name then return end
  local tKey   = normalizeKey(trim(name))
  local snap   = snapshotFight(tKey)
  if snap then raiseEvent("MyDSL.combat.ended", snap) end
end

-- ---- parseCombatEndLine ---------------------------------------------
function MyDSL.parseCombatEndLine(line)
  -- Escape fail: no state change
  if line:match("^You cannot escape from combat") then return end

  -- You flee
  if line:match("^You flee from combat!") then
    -- Clear the first active entry where you are attacker
    for tKey, entry in pairs(MyDSL.State.combat.active) do
      if entry.by_attacker and entry.by_attacker["you"] then
        local snap = snapshotFight(tKey)
        if snap then raiseEvent("MyDSL.combat.ended", snap) end
        return
      end
    end
    return
  end

  -- Rescued out: "<name> rescues you!"
  if line:match("rescues you!$") then
    for tKey, _ in pairs(MyDSL.State.combat.active) do
      local snap = snapshotFight(tKey)
      if snap then raiseEvent("MyDSL.combat.ended", snap) end
      return  -- clear only first (most recent) active fight
    end
    return
  end

  -- A mob or pet flees: "<name> has fled!"
  local fled = line:match("^(.+) has fled!$")
  if fled then
    local tKey = normalizeKey(trim(fled))
    local snap = snapshotFight(tKey)
    if snap then raiseEvent("MyDSL.combat.ended", snap) end
  end
end

-- ---- parseCombatProcLine --------------------------------------------
-- flagCode: C=Frost F=Flaming L=Shocking H=Vampiric S=Stunning M=ManaDrain O=Holy U=Unholy P=Poison
function MyDSL.parseCombatProcLine(flagCode, attackerKey, targetKey)
  -- Rage vamp tracking: your own vampiric procs landing
  if flagCode == "H" and attackerKey == "you" then
    MyDSL.State.combat.rage.vamp = MyDSL.State.combat.rage.vamp + 2.5
  end

  -- Determine the active entry to annotate
  local entry = targetKey and MyDSL.State.combat.active[targetKey]
  if not entry then
    -- Fallback: if exactly one active fight, use it
    local count, lastKey, lastEntry = 0, nil, nil
    for k, e in pairs(MyDSL.State.combat.active) do
      count = count + 1; lastKey, lastEntry = k, e
    end
    if count ~= 1 then return end
    entry, targetKey = lastEntry, lastKey
  end
  if not entry then return end

  attackerKey = attackerKey or "you"
  local ba = entry.by_attacker[attackerKey]

  -- Pragmatic fix, not full resolution (see Contract_CombatWindow.md): if
  -- attackerKey isn't a known combatant (you / group member), it's almost
  -- certainly a weapon name the proc line named instead of the wielder.
  -- Rather than dropping the proc, give the weapon its own pseudo-attacker
  -- row so it stays visible in the fight summary.
  if not ba and not isKnownCombatant(attackerKey) then
    entry.by_attacker[attackerKey] = entry.by_attacker[attackerKey] or {}
    ba = entry.by_attacker[attackerKey]
    ba["(proc)"] = ba["(proc)"] or { swings=0, hits=0, misses=0, score_total=0, flags={} }
  end
  if not ba then return end

  -- Add to the first non-evade noun found for this attacker
  for noun, ndata in pairs(ba) do
    if noun ~= "(evade)" then
      ndata.flags[flagCode] = (ndata.flags[flagCode] or 0) + 1
      return
    end
  end
end


------------------------------------------------------------------------
-- SECTION 10: TRIGGER REGISTRATION
------------------------------------------------------------------------
-- Score header: "Score for Kien -= Zandreya =- (Companion) *Observer*"
-- Pattern matches only the first 10 chars so the full decorated header line
-- fires beginScore(). charName is captured as the first word after "Score for ".
-- beginScore() then installs the catch-all trigger for the body lines.

MyDSL._triggers.scoreBegin = tempRegexTrigger(
  "^Score for ",
  [[if MyDSL and MyDSL.beginScore then MyDSL.beginScore(line:match("^Score for (%S+)")) end]]
)


------------------------------------------------------------------------
-- Lunar block trigger
------------------------------------------------------------------------
-- Mirrors the score trigger pattern exactly.
--
-- A permanent trigger fires on the first moon line ("The red moon is ...").
-- It calls beginLunar() once to reset state, immediately parses that first
-- line, then installs a catch-all trigger (".*") that feeds every subsequent
-- line to parseLunarLine(). The catch-all kills itself when it detects a
-- blank line, which marks the end of the lunar block, then calls endLunar()
-- to commit the parsed data.
--
-- Guard: if the catch-all is already running (because this session has a
-- second or third moon line in the block), the permanent trigger returns
-- without calling beginLunar() again. The catch-all handles the line.

MyDSL._triggers.lunarBegin = tempRegexTrigger(
  "^The (red|white|black) moon is",
  function()
    if not (MyDSL and MyDSL.beginLunar) then return end
    -- If the catch-all is already active this line is handled there — skip.
    if MyDSL._triggers.lunarParse then return end
    -- Start a fresh block and parse the triggering line immediately.
    MyDSL.beginLunar()
    MyDSL.parseLunarLine(getCurrentLine())
    -- Install catch-all for all remaining lines in the block.
    MyDSL._triggers.lunarParse = tempRegexTrigger(".*", function()
      if not MyDSL then return end
      local ln = getCurrentLine()
      if ln:match("^%s*$") then
        -- Blank line = end of lunar block. Commit data and remove catch-all.
        killTrigger(MyDSL._triggers.lunarParse)
        MyDSL._triggers.lunarParse = nil
        if MyDSL.endLunar then MyDSL.endLunar() end
      else
        if MyDSL.parseLunarLine then MyDSL.parseLunarLine(ln) end
      end
    end)
  end
)

------------------------------------------------------------------------
-- Time line trigger
------------------------------------------------------------------------
-- Fires on every game-time output line:
--   "It is 9:30 am, Day of the Great Gods, 26th the Month of the Great Evil."
--   "It is 10:00 o'clock am, ..."
-- Pattern "^It is " is a safe literal prefix — both variants start with it.

MyDSL._triggers.timeLine = tempRegexTrigger(
  "^It is ",
  function()
    if MyDSL and MyDSL.parseTimeLine then
      MyDSL.parseTimeLine(getCurrentLine())
    end
  end
)

------------------------------------------------------------------------
-- Prompt line trigger (day/night period)
------------------------------------------------------------------------
-- Fires on every prompt line 2 — far more frequent than sunrise/sunset triggers.
-- PCRE: "^==-[A-Z]" matches "==-Night...", "==-Day...", "==-Dawn..." etc.
-- Also matches "==-Kien" (name echo) but parsePromptLine() drops it (no " - HH:MM :: ").

MyDSL._triggers.promptLine = tempRegexTrigger(
  "^==-[A-Z]",
  function()
    if MyDSL and MyDSL.parsePromptLine then
      MyDSL.parsePromptLine(getCurrentLine())
    end
  end
)

------------------------------------------------------------------------
-- Sunrise / Sunset triggers
------------------------------------------------------------------------
-- Confirmed exact text from live session (Steven, 2026-06-30):
--   "The sun rises in the east."  — at ~6:30am game time
--   "The night has begun."        — night transition (plain text, triggerable)
-- Note: "* * * * * Night folds the land in shadow * * * * *" is a cecho line — NOT triggerable.
-- Sets State.time.is_night and re-emits "time" so DataBridge + MoonWeather update.

MyDSL._triggers.sunrise = tempRegexTrigger(
  "^The sun rises in the east\\.$",
  function()
    if MyDSL and MyDSL.State and MyDSL.State.time then
      MyDSL.State.time.is_night = false
      MyDSL.emit("time")
    end
  end
)

MyDSL._triggers.sunset = tempRegexTrigger(
  "^The night has begun\\.$",
  function()
    if MyDSL and MyDSL.State and MyDSL.State.time then
      MyDSL.State.time.is_night = true
      MyDSL.emit("time")
    end
  end
)

------------------------------------------------------------------------
-- Weather trigger
------------------------------------------------------------------------
-- Broad pattern: any line starting with a capital letter and ending with
-- a period. Fires on room descriptions too — parseWeatherLine() filters
-- internally using a weather keyword list.

MyDSL._triggers.weather = tempRegexTrigger(
  "^[A-Z][^.]+\\.$",
  function()
    local ln = getCurrentLine()
    if MyDSL and MyDSL.parseWeatherLine then
      MyDSL.parseWeatherLine(ln)
    end
  end
)


------------------------------------------------------------------------
-- Scan triggers
------------------------------------------------------------------------
-- Two permanent triggers: one for "scan" (all-directions), one for
-- "scan <dir>" (directional). Both call beginScan() which resets
-- State.scan and installs the body catch-all.

MyDSL._triggers.scanAround = tempRegexTrigger(
  "^Looking around you see:$",
  function()
    if MyDSL and MyDSL.beginScan then MyDSL.beginScan("around", nil) end
  end
)

MyDSL._triggers.scanDir = tempRegexTrigger(
  "^You peer intently ([a-zA-Z]+)\\.$",
  function()
    if not (MyDSL and MyDSL.beginScan) then return end
    local dir = getCurrentLine():match("^You peer intently (%a+)%.$")
    MyDSL.beginScan("direction", dir)
  end
)

------------------------------------------------------------------------
-- Group trigger
------------------------------------------------------------------------
-- Fires on "Kien's group:" (any character name followed by "'s group:").
-- Installs the body catch-all via beginGroup(); endGroup() kills it on
-- blank line and commits to State.group.

MyDSL._triggers.groupStart = tempRegexTrigger(
  "^.+'s group:$",
  function()
    if MyDSL and MyDSL.beginGroup then MyDSL.beginGroup() end
  end
)

------------------------------------------------------------------------
-- CreatureLore trigger
------------------------------------------------------------------------
-- Fires on "^Creature: <name>  Race: <race>" — the first line of any
-- creaturelore block. Body lines handled by catch-all installed inside
-- beginCreatureLore().

MyDSL._triggers.loreStart = tempRegexTrigger(
  "^Creature:\\s",
  function()
    if MyDSL and MyDSL.beginCreatureLore then
      MyDSL.beginCreatureLore(getCurrentLine())
    end
  end
)


------------------------------------------------------------------------
-- Combat triggers (always-active — no begin/end block)
------------------------------------------------------------------------

-- ---- Unified damage trigger (PNP-derived PCRE, one trigger for all damage types)
local DAMAGE_VERBS = "miss|scratch|graze|hit|injure|wound|maul|decimate|devastate|maim|MUTILATE|DISEMBOWEL|DISMEMBER|MASSACRE|MANGLE|DEMOLISH|DEVASTATE|OBLITERATE|ANNIHILATE|ERADICATE|GHASTLY|HORRID|DREADFUL|HIDEOUS|INDESCRIBABLE|UNSPEAKABLE"
MyDSL._triggers.combatDamage = tempRegexTrigger(
  "^(You|[\\w\\-\\s,']+?)(?:(?<=You)r|'s)?(?:\\s?((?<=Your )[\\w\\s]+?|(?<='s )[\\w\\s]+?|))(?: do[es]*| [\\>\\<\\=\\*]+|) ("
    .. DAMAGE_VERBS .. ")[esES]*(?: things to| [\\>\\<\\=\\*]+|) ([\\w\\-\\s,']+)([\\.\\.!]+)$",
  function()
    if MyDSL and MyDSL.parseCombatDamageLine then
      MyDSL.parseCombatDamageLine(matches[2], matches[3], matches[4], matches[5], matches[6])
    end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config
       and MyDSL.CombatView.config.gag_combat then
      deleteLine()
    end
  end
)

-- ---- Avoidance triggers
-- Dodge/parry/block patterns are a direct port of DSL_PNP_Battle.lua's
-- tested trigger text (make_triggers(), the {dodge/parry/block/sense}
-- table) -- PNP already solved the you-as-subject vs third-party grammar
-- split: the (your|[\w\-\,\s']+) alternation matches "your" as a literal
-- alternative, while the same char class lets the non-"your" branch swallow
-- a possessive like "a gnome greaser's" whole (the embedded "'" keeps the
-- trailing 's inside the captured name instead of breaking the match).
MyDSL._triggers.combatDodge = tempRegexTrigger(
  "(You|[\\w\\-\\,\\s']+) (dodge)s? (your|[\\w\\-\\,\\s']+) attack\\.$",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)
MyDSL._triggers.combatParry = tempRegexTrigger(
  "(You|[\\w\\-\\,\\s']+) (parry|parries) (your|[\\w\\-\\,\\s']+) attack\\.$",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)
MyDSL._triggers.combatBlock = tempRegexTrigger(
  "(You|[\\w\\-\\,\\s']+) (block)[s]? (your|[\\w\\-\\,\\s']+) attack .*\\.$",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)
MyDSL._triggers.combatSense1 = tempRegexTrigger(
  "^[\\w\\-\\s,']+ senses they.?re about to be hit and deflects the blow\\.",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)
MyDSL._triggers.combatSense2 = tempRegexTrigger(
  "^[\\w\\-\\s,']+ senses [\\w\\-\\s,']+'s attack coming and avoids its blow\\.",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)

-- ---- Condition trigger (excludes DEAD — handled by combatDead below)
MyDSL._triggers.combatCondition = tempRegexTrigger(
  "(?:is in excellent condition|has a few scratches|has some small wounds|has some big nasty wounds|has quite a few wounds|looks pretty hurt|is in awful condition)",
  function()
    if MyDSL and MyDSL.parseCombatConditionLine then MyDSL.parseCombatConditionLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)

-- ---- Death trigger
MyDSL._triggers.combatDead = tempRegexTrigger(
  " is DEAD!!$",
  function()
    if MyDSL and MyDSL.parseCombatDeathLine then MyDSL.parseCombatDeathLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)
MyDSL._triggers.combatDeadGroundHit = tempRegexTrigger(
  " hits the ground \\.\\.\\. DEAD\\.$",
  function()
    if MyDSL and MyDSL.parseCombatDeathLine then MyDSL.parseCombatDeathLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)

-- ---- Flee / rescue / escape-fail triggers
MyDSL._triggers.combatFlee = tempRegexTrigger(
  "^You flee from combat!$",
  function() if MyDSL and MyDSL.parseCombatEndLine then MyDSL.parseCombatEndLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)
MyDSL._triggers.combatEscapeFail = tempRegexTrigger(
  "^You cannot escape from combat!!!$",
  function() if MyDSL and MyDSL.parseCombatEndLine then MyDSL.parseCombatEndLine(getCurrentLine()) end end)
MyDSL._triggers.combatRescued = tempRegexTrigger(
  "rescues you!$",
  function() if MyDSL and MyDSL.parseCombatEndLine then MyDSL.parseCombatEndLine(getCurrentLine()) end end)
MyDSL._triggers.combatTargetFled = tempRegexTrigger(
  "^[\\w\\-\\s,']+ has fled!$",
  function() if MyDSL and MyDSL.parseCombatEndLine then MyDSL.parseCombatEndLine(getCurrentLine()) end end)

-- ---- Weapon-flag proc triggers
-- C: Frost
MyDSL._triggers.procFrostFreeze = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) freezes ([\\w\\-\\s,'\"]+)\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    local aKey = normalizeKey(matches[2] == "You" and "you" or stripQuotes(matches[2]))
    local tKey = normalizeKey(matches[3]:lower() == "you" and "you" or stripQuotes(matches[3]))
    MyDSL.parseCombatProcLine("C", aKey, tKey)
  end)
MyDSL._triggers.procFrostTouch = tempRegexTrigger(
  "^The cold touch of ([\\w\\-\\s,']+) surrounds you with ice",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("C", normalizeKey(matches[2]), "you")
  end)

-- F: Flaming
MyDSL._triggers.procFlameBurn = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is burned by ([\\w\\-\\s,']+)\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("F", normalizeKey(matches[3]), normalizeKey(matches[2]))
  end)
MyDSL._triggers.procFlameSear = tempRegexTrigger(
  "^([\\w\\-\\s,']+) sears your flesh",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("F", normalizeKey(matches[2]), "you")
  end)

-- L: Shocking
MyDSL._triggers.procShockLightning = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is struck by lightning from ([\\w\\-\\s,']+)\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("L", normalizeKey(matches[3]), normalizeKey(matches[2]))
  end)
MyDSL._triggers.procShockShocked = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is shocked by a",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("L", "unknown", normalizeKey(matches[2]))
  end)

-- H: Vampiric
MyDSL._triggers.procVampDraw = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) draws life from ([\\w\\-\\s,'\"]+)\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    local aKey = (matches[2] == "You" or matches[2]:lower() == "you") and "you" or normalizeKey(stripQuotes(matches[2]))
    local tKey = matches[3]:lower() == "you" and "you" or normalizeKey(stripQuotes(matches[3]))
    MyDSL.parseCombatProcLine("H", aKey, tKey)
  end)
MyDSL._triggers.procVampDrain = tempRegexTrigger(
  "^You feel ([\\w\\-\\s,']+) drawing your life away",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("H", normalizeKey(matches[2]), "you")
  end)

-- S: Stunning
MyDSL._triggers.procStun = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) is knocked to the ground by ([\\w\\-\\s,'\"]+)\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("S", normalizeKey(stripQuotes(matches[3])), normalizeKey(stripQuotes(matches[2])))
  end)

-- M: Mana drain
MyDSL._triggers.procManaSelf = tempRegexTrigger(
  "^You feel something drawing your energy away",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("M", "unknown", "you")
  end)
MyDSL._triggers.procManaDraw = tempRegexTrigger(
  "^([\\w\\-\\s,']+) draws energy from ([\\w\\-\\s,']+)\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    local aKey = (matches[2] == "You" or matches[2]:lower() == "you") and "you" or normalizeKey(matches[2])
    local tKey = matches[3]:lower() == "you" and "you" or normalizeKey(matches[3])
    MyDSL.parseCombatProcLine("M", aKey, tKey)
  end)

-- O: Holy
MyDSL._triggers.procHolyWrath = tempRegexTrigger(
  "^You feel a surge of ([\\w\\-\\s,']+)'s holy wrath race through your body",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("O", normalizeKey(matches[2]), "you")
  end)
MyDSL._triggers.procHolyFlash = tempRegexTrigger(
  "^A flash of holy power erupts from ([\\w\\-\\s,']+) and hits ([\\w\\-\\s,']+)!$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("O", normalizeKey(matches[2]), normalizeKey(matches[3]))
  end)

-- U: Unholy
MyDSL._triggers.procUnholy = tempRegexTrigger(
  "^You feel a surge of ([\\w\\-\\s,']+)'s unholy wrath race through your body",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    MyDSL.parseCombatProcLine("U", normalizeKey(matches[2]), "you")
  end)

-- Sharp: TODO — no confirmed trigger text observed in any log to date
-- Vorpal: confirmed non-functional (produces no echo) — deliberately omitted

-- P: Poison (our own confirmed addition; no PNP equivalent)
MyDSL._triggers.procPoisonSetup = tempRegexTrigger(
  "^([\\w\\-\\s,']+) coats ([\\w\\-\\s,']+) with deadly lifebane poison\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    -- attacker is matches[2], weapon is matches[3]; target tracked at onset
    -- just mark a P proc for whoever coated the weapon
    local aKey = (matches[2] == "You" or matches[2]:lower() == "you") and "you" or normalizeKey(matches[2])
    MyDSL.parseCombatProcLine("P", aKey, nil)
  end)
MyDSL._triggers.procPoisonOnset = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is poisoned by the venom on ([\\w\\-\\s,']+)\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    local tKey = matches[2]:lower() == "you" and "you" or normalizeKey(matches[2])
    MyDSL.parseCombatProcLine("P", "unknown", tKey)
  end)
MyDSL._triggers.procPoisonTick = tempRegexTrigger(
  "^([\\w\\-\\s,']+) shivers and suffers\\.$",
  function()
    if not (MyDSL and MyDSL.parseCombatProcLine) then return end
    local tKey = matches[2]:lower() == "you" and "you" or normalizeKey(matches[2])
    MyDSL.parseCombatProcLine("P", "unknown", tKey)
  end)

-- ---- Round-flush handler -------------------------------------------
-- Fires on every prompt reprint (which happens once per combat round).
-- Derives one condensed verb per (attacker,target,noun) combo from the
-- accumulated round scores, raises combat.updated, then clears round_data.
-- Rage: if GMCP reported hp_raw == "???" this round, re-fire combat_rage.

if MyDSL._handlers.combatRoundFlush then
  pcall(killAnonymousEventHandler, MyDSL._handlers.combatRoundFlush)
end
MyDSL._handlers.combatRoundFlush = registerAnonymousEventHandler(
  "MyDSL.time.updated",
  function()
    if not (MyDSL and MyDSL.State and MyDSL.State.combat) then return end
    -- Derive condensed round lines (stored on round_data entries for CombatView)
    local rd = MyDSL.State.combat.round_data
    for _, entry in pairs(rd) do
      entry.derived_verb = MyDSL.derivedVerbForScore(entry.score)
    end
    -- Raise combat.updated — CombatView.render() rebuilds the round log
    MyDSL.State.combat.last_updated = os.time()
    raiseEvent("MyDSL.combat.updated", rd)
    MyDSL.State.combat.round_data = {}
    -- Rage: check if HP is hidden this round
    local rage = MyDSL.State.combat.rage
    local char = MyDSL.State.char
    if char and char.hp_raw == "???" then
      raiseEvent("MyDSL.combat_rage", rage.damage, rage.vamp)
    else
      rage.damage = 0
      rage.vamp   = 0
    end
  end
)

------------------------------------------------------------------------
-- READY
------------------------------------------------------------------------
debugc("[MyDSL] DataLayer v1.0 loaded. Character: "
  .. tostring(MyDSL.Char() or "(not yet known)"))
