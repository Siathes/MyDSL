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

-- Moved here 2026-07-06 (was Section 3, line ~205): _aliases was used at
-- the log-toggle/help aliases below (originally added 2026-07-05/07-06)
-- BEFORE it was ever initialized as a table. Confirmed as a real crash,
-- not theoretical -- caught by loading this file into a genuinely fresh
-- Lua state (no prior MyDSL global at all, i.e. Mudlet's very first
-- dofile() of this file in a new session) via a Mudlet-API mock harness:
-- "attempt to index field '_aliases' (a nil value)" at the first
-- MyDSL._aliases.logToggle reference, which would have silently aborted
-- the rest of this file's load -- every trigger registered after that
-- point (all of combat, weather, chat, everything) would never exist.
-- Only masked in practice because Mudlet's Lua state persists across a
-- same-session "reload this script" (MyDSL._aliases already existed from
-- the previous successful load), so it never surfaced on an in-session
-- edit -- only on a genuinely fresh Mudlet start. _triggers moved
-- alongside it for the same reason, even though its first use (further
-- down) happened to already be safe.
MyDSL._triggers = MyDSL._triggers or {}
MyDSL._aliases = MyDSL._aliases or {}


------------------------------------------------------------------------
-- SECTION 2: PRIVATE UTILITIES
------------------------------------------------------------------------
-- Declared local so they never escape into the global environment.

local function now()    return os.time() end
local function trim(s)  return s and s:match("^%s*(.-)%s*$") or "" end

-- Strips decho/cecho inline color tags ("<r,g,b>"/"<r>") for a clean
-- plain-text log line.
local function stripColorTags(s)
  return (s or ""):gsub("<%d+,%d+,%d+>", ""):gsub("<r>", "")
end

-- Same sanitizer as MyDSL_AffectsView.lua's safeFileName() -- keeps
-- character-bound filenames/dirnames consistent across the project.
local function safeFileName(s)
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

-- Master + per-category toggle for MyDSL.logWindow(), added 2026-07-05 per
-- Steven ("i dont think we need to log players near you, can you make
-- logging toggleable?"). Toggle via aliases: "mydsl log on"/"mydsl log off"
-- (master), "mydsl log <category> on"/"mydsl log <category> off"
-- (per-category) -- see Section 10.
--
-- Defaults reworked 2026-07-07 per Steven: combat/chat/history are useful
-- to actually review later, so those stay on. Every other per-window log
-- (group/righthere/target/scan/playersnear/bloodbath) is debug-only --
-- off by default, opt-in when actually debugging that specific window,
-- not something worth the disk churn during normal play. All of them
-- remain individually toggleable regardless of default.
MyDSL.LogConfig = MyDSL.LogConfig or {
  enabled = true,
  disabled_categories = {
    playersnear = true,
    group       = true,
    righthere   = true,
    target      = true,
    scan        = true,
    bloodbath   = true,
  },
}

-- Per-window plain-text logging. Confirmed 2026-07-05 (see
-- MyDSL_MudletAPIReference.md): Mudlet's startLogging() only ever captures
-- the main console -- there is no built-in way to log a MiniConsole/
-- UserWindow's content. This mirrors whatever a module writes to its own
-- window into a same-day file under MyDSL/logs/<category>/<CharName>/
-- (already gitignored -- runtime data, not source, and git doesn't track
-- empty dirs so a fresh checkout won't have these -- lfs.mkdir()/mkdir -p
-- below handles that, same pattern as MyDSL_AffectsView.lua/
-- MyDSL_ChatWrapper.lua). Character-bound as of 2026-07-05 (per Steven --
-- a shared file across characters got confusing once more than one
-- character is tested in the same day, which already happened). One file
-- per character per day, so it rotates naturally instead of growing forever.
-- Fixed 2026-07-07: found via live testing that GroupView/TargetView's logs
-- came out fragmented -- one word/segment per line ("[Mob]", then
-- "A throughbred stalli" on its own line, then " 100%hp" on another, etc.)
-- instead of one coherent row. Root cause: those two views build a single
-- visual row from several separate decho/dechoLink calls (class tag, name,
-- hp%, mana%, mv%, action buttons, then a final lone "\n" call to end the
-- row) -- decho doesn't force a line break, so Mudlet's own console shows
-- them joined on one line, but this function used to write one full log
-- line per CALL regardless, unconditionally appending "\n" to whatever text
-- it was given. Combat/RightHere/History never hit this because those
-- modules already pass one complete line per call. Fixed generally instead
-- of patching each view: buffer per category, only flush a real log line
-- when a "\n" actually shows up in the accumulated text (wherever it comes
-- from), so multi-call rows reconstruct as one line with one timestamp,
-- and single-call callers behave exactly as before (buffer fills then
-- immediately empties on the same call).
MyDSL._logBuffers = MyDSL._logBuffers or {}

function MyDSL.logWindow(category, text)
  if not category or not text or text == "" then return end
  if not MyDSL.LogConfig.enabled then return end
  if MyDSL.LogConfig.disabled_categories[category] then return end

  local buf = (MyDSL._logBuffers[category] or "") .. text
  local nl = buf:find("\n", 1, true)
  if not nl then
    -- No complete line yet -- keep buffering, nothing to write.
    MyDSL._logBuffers[category] = buf
    return
  end

  local char = safeFileName(MyDSL.Char and MyDSL.Char() or "Unknown")
  local dir  = getMudletHomeDir() .. "/MyDSL/logs/" .. category .. "/" .. char
  -- mkdir -p equivalent: lfs.mkdir only makes one level, so try os.execute
  -- too for the full path in case MyDSL/logs/ itself doesn't exist yet
  -- (fresh checkout -- git doesn't track empty dirs). Same dual approach as
  -- MyDSL_ChatWrapper.lua's ensureDir().
  if lfs and lfs.mkdir then pcall(lfs.mkdir, dir) end
  if os and os.execute then pcall(os.execute, "mkdir -p " .. string.format("%q", dir)) end
  local path = dir .. "/" .. os.date("%Y-%m-%d") .. ".log"

  local f = io.open(path, "a")
  while nl do
    local line = buf:sub(1, nl - 1)
    buf = buf:sub(nl + 1)
    if f and line ~= "" then
      f:write(os.date("%H:%M:%S") .. "  " .. stripColorTags(line) .. "\n")
    end
    nl = buf:find("\n", 1, true)
  end
  if f then f:close() end
  MyDSL._logBuffers[category] = buf
end

-- "mydsl log on/off" (master) and "mydsl log <category> on/off" (per-
-- category, e.g. "mydsl log playersnear on" to re-enable it).
if MyDSL._aliases.logToggle then pcall(killAlias, MyDSL._aliases.logToggle) end
MyDSL._aliases.logToggle = tempAlias(
  "^mydsl log (on|off)$",
  [[MyDSL.LogConfig.enabled = (matches[2] == "on")
    echo("Window logging " .. matches[2] .. ".\n")]]
)
-- "chat" is special-cased below (added 2026-07-07): it doesn't go through
-- MyDSL.logWindow() at all -- EMCO has its own real per-tab logging
-- (enableAllLogging()/disableAllLogging(), writing to
-- log/MyDSL_EMCO_Chat/YYYY/MM/DD/<Tab>.html, already on by default). Reuse
-- that directly instead of duplicating chat content into a second file in
-- a different format, while keeping the same "mydsl log <category>
-- on/off" command shape as every other category for consistency.
if MyDSL._aliases.logCategoryToggle then pcall(killAlias, MyDSL._aliases.logCategoryToggle) end
MyDSL._aliases.logCategoryToggle = tempAlias(
  "^mydsl log (\\S+) (on|off)$",
  [[local cat = matches[2]
    if cat == "chat" then
      local ch = MyDSL and MyDSL.Chat and MyDSL.Chat.emco
      if ch then
        if matches[3] == "off" then ch:disableAllLogging() else ch:enableAllLogging() end
        echo("Chat logging " .. matches[3] .. ".\n")
      else
        echo("Chat window not ready yet -- try again in a moment.\n")
      end
    else
      if matches[3] == "off" then
        MyDSL.LogConfig.disabled_categories[cat] = true
      else
        MyDSL.LogConfig.disabled_categories[cat] = nil
      end
      echo("Window logging for '" .. cat .. "' " .. matches[3] .. ".\n")
    end]]
)

-- "mydsl help" -- moved to MyDSL_Help.lua 2026-07-15 (a full 3-level
-- clickable help system, replacing this flat hand-maintained dump).
-- MyDSL.help() and its alias are now defined there, not here.

-- MyDSL.who(name) + "mydsl who <name>" -- added 2026-07-07 (Phase F
-- follow-up). DslColors_Core_v1_0's `dslcolor show <name>` is real, live,
-- and already the authoritative "known person" lookup (see Phase F entry
-- in docs/TODO.md) -- this just gives it a "mydsl"-prefixed entry point
-- for command-surface consistency with the rest of MyDSL, calling the
-- exact same underlying dispatcher rather than a parallel implementation.
-- dslColorCommand is a global owned by that separate native script, not
-- ours -- pcall-guarded so this can't error if DslColors isn't loaded.
function MyDSL.who(name)
  name = tostring(name or ""):match("^%s*(.-)%s*$")
  if name == "" then echo("usage: mydsl who <name>\n"); return end
  local ok = pcall(function() dslColorCommand("show " .. name) end)
  if not ok then echo("DslColors not loaded -- can't look up '" .. name .. "'.\n") end
end

if MyDSL._aliases.who then pcall(killAlias, MyDSL._aliases.who) end
MyDSL._aliases.who = tempAlias(
  "^mydsl who (.+)$",
  [[MyDSL.who(matches[2])]]
)


------------------------------------------------------------------------
-- MyDSL.test() + "mydsl test" -- smoke-test alias, added 2026-07-07
------------------------------------------------------------------------
-- CLAUDE.md's own workflow section has always referenced "mydsl test (if
-- it exists), otherwise manually verify" as the pre-done-check -- it
-- never existed. Fast in-game sanity check: confirms every real module
-- namespace loaded, reports window-registry and character-binding
-- status. Not a full test suite -- that's test/mudlet_mock.lua, for
-- offline real-code testing outside Mudlet entirely.

local TEST_MODULES = {
  { "ChatWrapper",       "Chat" },
  { "ChatTriggers",      "ChatTriggers" },
  { "CombatView",        "CombatView" },
  { "TargetView",        "TargetView" },
  { "GroupView",         "GroupView" },
  { "ScanView",          "ScanView" },
  { "AffectsView",       "Affects" },
  { "MoonWeather",       "MoonWeather" },
  { "TickSource",        "TickSource" },
  { "TickView",          "TickView" },
  { "LayoutEngine",      "Layout" },
  { "WindowRegistry",    "Windows" },
  { "ThemeEngine",       "Theme" },
  { "CharacterAssist",   "CharacterAssist" },
  { "Roller",            "Roller" },
  { "RouteHelper",       "Route" },
  { "CreatureReference", "CreatureReference" },
  { "PromptView",        "Prompt" },
  { "PortraitView",      "Portrait" },
  { "LocationView",      "Location" },
  { "LiveView",          "LiveView" },
  { "DataBridge",        "DB" },
  { "RawCapture",        "RawCapture" },
}

function MyDSL.test()
  echo("\n=== MyDSL smoke test ===\n")

  -- Module load check.
  local missing = {}
  for _, mod in ipairs(TEST_MODULES) do
    local label, key = mod[1], mod[2]
    if type(MyDSL[key]) ~= "table" then
      missing[#missing + 1] = label
    end
  end
  if #missing == 0 then
    echo("Modules: all " .. #TEST_MODULES .. " loaded OK\n")
  else
    cecho("<red>Modules: " .. #missing .. " MISSING -- " .. table.concat(missing, ", ") .. "<reset>\n")
  end

  -- Character binding.
  local charName = "Unknown"
  if gmcp and gmcp.login_data and gmcp.login_data.name and gmcp.login_data.name ~= "" then
    charName = tostring(gmcp.login_data.name)
  end
  if charName == "Unknown" then
    cecho("<yellow>Character: not yet identified by GMCP (expected before login)<reset>\n")
  else
    echo("Character: " .. charName .. "\n")
  end

  -- Window registry.
  if MyDSL.Windows and MyDSL.Windows.registry then
    local total, visible = 0, 0
    for _, entry in pairs(MyDSL.Windows.registry) do
      total = total + 1
      if entry.visible then visible = visible + 1 end
    end
    echo("Windows: " .. total .. " registered, " .. visible .. " visible\n")
  else
    cecho("<red>Windows: WindowRegistry not loaded<reset>\n")
  end

  -- Core state sanity.
  if type(MyDSL.State) == "table" then
    echo("State: MyDSL.State present\n")
  else
    cecho("<red>State: MyDSL.State MISSING -- DataLayer did not initialize correctly<reset>\n")
  end
  if type(MyDSL.Data) == "table" then
    echo("Data: MyDSL.Data present\n")
  else
    cecho("<red>Data: MyDSL.Data MISSING<reset>\n")
  end

  echo("=== end smoke test ===\n")
end

if MyDSL._aliases.test then pcall(killAlias, MyDSL._aliases.test) end
MyDSL._aliases.test = tempAlias(
  "^mydsl test$",
  [[MyDSL.test()]]
)


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
MyDSL.State.improve = MyDSL.State.improve or { last_updated = 0 }  -- text: skill improve events
MyDSL.State.flags        = MyDSL.State.flags        or { last_updated = 0 }  -- text: toggle flags from score
MyDSL.State.scan         = MyDSL.State.scan         or {  -- text: nearby entities from scan command
  mode=nil, direction=nil, rows={}, rightHere={}, byName={}, groundItems={}, last_updated=0
}
MyDSL.State.creaturelore = MyDSL.State.creaturelore or { last_updated = 0 }  -- text: creature lore block
-- (2026-07-11: the session-only MyDSL.State.creatureLoreCache this comment
-- used to describe has been superseded by the real, persistent, disk-backed
-- MyDSL.CreatureLore DB -- see MyDSL_CreatureLore.lua -- per Steven's
-- follow-up the same day: "creaturelore should be persistent and tabled...
-- so we can recall creatures for information... over any session," not
-- just the current one.)
MyDSL.State.equipment    = MyDSL.State.equipment    or { last_updated = 0 }  -- text: worn/wielded equipment by slot
MyDSL.State.inventory    = MyDSL.State.inventory    or { last_updated = 0, items = {} }  -- text: carried items ("i"/"inv")
-- Manual ground-item-to-inventory/equipment overrides, keyed by ground
-- item key -- per Steven ("best effort mapping is fine, maybe a manual
-- map option"). Deliberately NOT part of MyDSL.State.scan (which resets
-- on every beginLook()/beginScan()) -- a manual correction should survive
-- room changes and re-looks, not just the one room it was set in.
-- In-memory only for now (resets on profile reload); not persisted to
-- disk yet.
MyDSL.State.groundItemOverrides = MyDSL.State.groundItemOverrides or {}
MyDSL.State.combat = MyDSL.State.combat or {
  active      = {},    -- keyed by target-key; each entry: {target_display, target_condition, by_attacker, started_at}
  history     = {},    -- array of snapshots (same shape), most recent first
  history_max = 5,
  round_data  = {},    -- per-(attacker→target→noun) accumulators, cleared each round -- PNP's battle_data equivalent
  rage        = { damage = 0, vamp = 0 },
  -- PNP's last_attacker/last_target/last_noun globals (DSL_PNP_Battle.lua) --
  -- weapon-flag procs attach to whichever combatant/noun the most recent
  -- damage line involved, rather than trying to resolve identity from the
  -- proc line's own text (which is often a weapon name, not a person).
  last_attacker = nil,
  last_target   = nil,
  last_noun     = nil,
  -- PNP's battle_data.screen_condition/window_condition equivalent -- a
  -- single pending condition note, flushed to main/window on the next round
  -- boundary alongside the round summary.
  pending_condition = nil,
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

-- _triggers/_aliases initialization moved to Section 1 (2026-07-06) --
-- see the comment there for why.


------------------------------------------------------------------------
-- SECTION 4: CURRENT CHARACTER NAME
------------------------------------------------------------------------
-- Single authoritative accessor.  Name comes only from login_data;
-- char_data has no name field (documented bug in the old code).

function MyDSL.Char()
  local login = MyDSL.State and MyDSL.State.login
  return login and login.name or nil
end

-- MyDSL.charName()/MyDSL.safeFileName() -- added 2026-07-11, code-review
-- reuse finding: this exact fallback chain (gmcp.login_data.name ->
-- MyCore.getChar() -> "Unknown") existed as an independent copy-pasted
-- local function in MyDSL_CombatView.lua, MyDSL_ChatWrapper.lua,
-- MyDSL_TargetView.lua, and (added this session) MyDSL_GroupView.lua --
-- 4 identical copies. NOT the same thing as MyDSL.Char() above: that one
-- only reads DataLayer's own parsed State.login (nil until GMCP login_data
-- has actually arrived and been captured), with no MyCore fallback and no
-- "Unknown" default -- callers that need a guaranteed-non-nil name safe to
-- use in a filename (every per-character config-persistence path in this
-- profile) need this different, more defensive version, so it's kept
-- separate rather than changing MyDSL.Char()'s own behavior. Consolidated
-- the modules touched by this session's diff (CombatView/TargetView/
-- GroupView) to call this shared version instead of their own copies;
-- MyDSL_ChatWrapper.lua's pre-existing copy is untouched (out of this
-- session's diff, lower priority to touch unprompted).
function MyDSL.charName()
  if gmcp and gmcp.login_data and gmcp.login_data.name and gmcp.login_data.name ~= "" then
    return tostring(gmcp.login_data.name)
  end
  if MyCore and MyCore.getChar then
    local ok, name = pcall(MyCore.getChar)
    if ok and name and name ~= "" then return tostring(name) end
  end
  return "Unknown"
end

function MyDSL.safeFileName(s)
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

-- MyDSL.copyArray() -- added 2026-07-11, code-review reuse finding:
-- MyDSL_TargetView.lua's TV.resetButtons() and MyDSL_GroupView.lua's
-- GV.resetQuickActions() both independently implemented "shallow-copy an
-- array's values (not the reference) via unpack" for their own
-- reset-to-defaults commands. Shared here so a future 3rd reset command
-- doesn't add a 3rd copy.
function MyDSL.copyArray(t)
  return { unpack(t) }
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
    -- Real-time "Flying" for the Pos'n field -- see the posn trigger
    -- block below (Section 10) for the rest of this feature. GMCP's
    -- is_flying is already confirmed reliable (used by CharacterAssist's
    -- vision check) and updates the instant flight starts/stops, unlike
    -- score's own Pos'n field which only refreshes when `score` is
    -- actually run. Only sets Flying when true -- landing is handled by
    -- its own dedicated text trigger below, not by is_flying going false
    -- here, since GMCP flips false slightly before the "float gently to
    -- the ground" line actually prints.
    if d.is_flying then
      update("char", { posn = "Flying" })
    end
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
      -- Fixed 2026-07-07, per Steven: every character-bound settings file
      -- (chat_settings/MyDSL_layout/MyDSL_windowstate/TargetView/
      -- AffectsView/CombatView/History font configs) resolves its path
      -- via a charName() that falls back to "Unknown" until GMCP
      -- identifies the character -- and on a genuinely fresh Mudlet
      -- start, each module's own initial load() runs at script-boot time,
      -- before login, so they'd load "Unknown"'s settings (or bare
      -- defaults) and never pick up the real character's saved settings
      -- once login completes -- restoreChar() above only restores
      -- State.score/lunar/flags/improve/affects, nothing per-window.
      -- Raising this lets every character-bound module re-run its own
      -- load+apply once the real name is known, closing that gap in one
      -- place instead of per-module timing hacks.
      raiseEvent("MyDSL.character.identified", name)
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

-- REAL BUG, found live 2026-07-11 (Steven: "are the settings loading at
-- creating from save files or they saving and never reading/updating?"):
-- Mudlet's real table.load(file, target) does NOT return the loaded
-- table -- confirmed directly in Mudlet's own bundled source
-- (mudlet-lua/lua/Other.lua): it has no return statement at all, and
-- unpickles the saved data INTO an explicit second-argument table (or
-- into _G if no second argument is given). Every call site across this
-- whole codebase that did "local loaded = table.load(path)" (no second
-- argument) was getting `loaded = nil` every single time, silently --
-- confirmed by PNP's own real source (PNP files/DSL_PNP_Data.lua) and
-- EMCO's own vendored source (EMCOChat/emco.lua) both ALWAYS calling it
-- with an explicit destination table, which we'd copied the shape of
-- without the second argument that makes it actually work. This one
-- (MyDSL.load(), the character-data restore path) is the most
-- foundational of the ~10 call sites this bug was found in across the
-- project -- see the same-day fixes to MyDSL_ThemeEngine.lua/
-- MyDSL_WindowRegistry.lua/MyDSL_CreatureLore.lua/MyDSL_TargetView.lua/
-- MyDSL_GroupView.lua/MyDSL_CombatView.lua/MyDSL_LayoutEngine.lua/
-- MyDSL_PromptView.lua for the rest.
function MyDSL.load()
  local path   = saveFilePath()
  local loaded = {}
  local ok = pcall(table.load, path, loaded)
  if not ok or not next(loaded) then
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

  -- Created: <weekday> <month> <day> <hh:mm:ss> <year>  -- added
  -- 2026-07-12 for LiveView's in-game age display, per Steven. Real
  -- current format confirmed in docs/DSL_CommandRef.md and live corpus
  -- (e.g. "Created: Wed May 21 15:20:26 2025", Kien's own real score
  -- output). A bare numeric fallback ("Created:  07.28.2024", no
  -- time-of-day) also seen in older captures -- handled too, in case any
  -- character still shows it. Stores a real Lua timestamp
  -- (created_ts), not the raw string -- age is computed live from this
  -- in MyDSL_LiveView.lua, same "store the anchor, compute fresh on
  -- render" pattern as improveLiveText().
  do
    local MONTH_NUM = {
      Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6,
      Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12,
    }
    local _, cmonth, cday, chh, cmin, csec, cyear =
      line:match("^Created:%s*(%a+)%s+(%a+)%s+(%d+)%s+(%d+):(%d+):(%d+)%s+(%d+)")
    if cmonth and MONTH_NUM[cmonth] then
      local ok, ts = pcall(os.time, {
        year = tonumber(cyear), month = MONTH_NUM[cmonth], day = tonumber(cday),
        hour = tonumber(chh), min = tonumber(cmin), sec = tonumber(csec),
      })
      if ok and ts then scoreBlock.created_ts = ts end
    else
      local nmonth, nday, nyear = line:match("^Created:%s*(%d+)%.(%d+)%.(%d+)")
      if nmonth then
        local ok, ts = pcall(os.time, {
          year = tonumber(nyear), month = tonumber(nmonth), day = tonumber(nday),
          hour = 0, min = 0, sec = 0,
        })
        if ok and ts then scoreBlock.created_ts = ts end
      end
    end
  end

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
  -- Dragon-only, added 2026-07-12 per Steven ("for dragons/Qin only, we
  -- need the chamber stat for breath weapon shown in score as
  -- Chamber:"). Real format confirmed via corpus grep: same DEX/Align
  -- row, dragon-only variant that replaces the non-dragon "Prestige
  -- hours:" field -- "DEX  : 060(060)    Align: True Neutral
  -- Chamber: 100". DSL_Helpfiles/dragons.txt: dragons "chamber their
  -- breath until such a time that they wish to unleash it" -- this is
  -- that charge level. Only ever present for dragons, so no race check
  -- needed here either, same as Vitality above.
  v = line:match("Chamber:%s*(%d+)");     if v then scoreBlock.chamber  = tonumber(v) end
  v = line:match("Wimpy:%s*(%d+)");       if v then scoreBlock.wimpy    = tonumber(v) end
  -- Pos'n: single-word value (Standing/Sleeping/etc.) followed by flag columns
  v = line:match("Pos'n:%s*(%S+)");       if v then scoreBlock.position = trim(v) end
  v = line:match("Stance:%s*(%S+)");       if v then scoreBlock.stance      = v end
  v = line:match("Speaking:%s*(%S+)");    if v then scoreBlock.language   = v end
  -- Fixed 2026-07-12, per Steven (LiveView identity row overflowing):
  -- real format is "Religion: Cliath -=- the God of Creation -=-"
  -- (confirmed via corpus grep across every god name seen: Cliath/
  -- Devion/Dragoth/Drakkara/Fatale/Kwainin/Nadrik/Raije/Zandrey/
  -- Zandreya) -- capturing "(.+)$" grabbed the whole trailing title
  -- along with the name. Every real god name is a single word (cross-
  -- checked against DSL_Helpfiles' own god files), so just the first
  -- token is the name.
  v = line:match("Religion:%s*(%S+)");    if v then scoreBlock.religion   = v end
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

-- extractWindClause(text) -- added 2026-07-12, per Steven ("wind should
-- be captured. clouds, clear, rain, gold [cold] breeze, temperate wind,
-- etc"). Pulls just the wind portion out of a weather sentence, if
-- present. Real corpus-confirmed shape (96 samples across the full
-- log/ archive, 193 files): "a <cold|temperate|warm>
-- <gentle|moderate> breeze/wind blows in from the
-- <north|south|east|west>", or the calm form "the wind is calm" --
-- no other temperature/strength/direction words found anywhere in the
-- corpus, so this is a complete, not partial, taxonomy. Returns the
-- matched fragment (capitalized) or nil if the text has no wind clause.
function MyDSL.extractWindClause(text)
  if not text then return nil end
  local s, e = text:find("a %a+ %a+ %a+ blows in from the %a+")
  if s then
    local clause = text:sub(s, e)
    return clause:sub(1, 1):upper() .. clause:sub(2)
  end
  if text:find("[Tt]he wind is calm") then return "The wind is calm" end
  return nil
end

function MyDSL.parseWeatherLine(line)
  local desc = trim(line)
  if desc == "" then return end
  local lc = desc:lower()
  local found = false
  for _, w in ipairs(_weatherWords) do
    -- Word-boundary match, not plain substring (fixed 2026-07-06). The
    -- trigger itself is intentionally broad (any capitalized sentence,
    -- matches ~13% of all lines) and this filter is the real safety net --
    -- but a plain substring check meant "sun" matched inside "Sunday",
    -- confirmed live-corrupting MyDSL.State.weather with the log-session-
    -- start banner ("Log session starting at ... on Sunday...") every time
    -- a new Mudlet log file opened. Frontier pattern requires a non-letter
    -- on both sides of the word.
    if lc:find("%f[%a]" .. w .. "%f[%A]") then found = true; break end
  end
  if not found then return end
  local fields = { description = desc }
  -- Wind is embedded in this same sentence in the standard (comma-joined)
  -- form -- confirmed 53/53 real corpus samples take this shape, so this
  -- alone covers the common case with no extra trigger needed.
  local windClause = MyDSL.extractWindClause(desc)
  if windClause then fields.windDescription = windClause end
  update("weather", fields)
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

-- Rewritten 2026-07-05 -- confirmed broken against DSL_CommandRef.md's own
-- documented real format and PNP's tested People.lua regex:
--   `[level race class] (org_code) name title`  -- clan, PARENS
--   `[level race class] [ Kingdom ] name title`  -- kingdom, BRACKETS (with
--                                                    spaces inside)
-- The old version only ever looked for the org/clan in [brackets] --
-- real clan tags like "(NT)"/"(VR)" (confirmed live in log/) are in
-- PARENS, so `entry.clan` was always nil, and the leftover "(WANTED)"/
-- "(VR)" parenthetical text shifted every word after it by one position,
-- corrupting `kingdom` and `name` for any WANTED or clan-tagged entry
-- (confirmed: "[27 Goblin Bnd] (WANTED) (VR) Vrokt." parsed as
-- kingdom="()" name="(VR)" instead of org="VR" name="Vrokt"). Also dropped
-- "QUIET" -- never found anywhere in log/ or DSL_CommandRef.md, unconfirmed.
function MyDSL.parseWhoLine(line)
  local level, race, class = line:match("%[%s*(%d+)%s+([%w%-]+)%s+(%w+)%]")
  if not level then return end

  local entry = {
    level  = tonumber(level),
    race   = trim(race),
    class  = trim(class),
    wanted = false,
    afk    = false,
  }

  -- Everything after the closing [level race class] bracket.
  local rest = line:match("%](.+)$") or ""

  -- Bare, unwrapped AFK (confirmed live in log/ alongside "[AFK]"/"(AFK)" --
  -- DSL isn't consistent about the delimiter, so check all three forms).
  if rest:find("%sAFK%s") or rest:find("%sAFK$") then entry.afk = true end
  rest = rest:gsub("%sAFK%s", " "):gsub("%sAFK$", "")

  -- Every remaining ()/[] group, in order. Per DSL_CommandRef.md + confirmed
  -- live in log/:
  --   (WANTED) / (Hostile) / [AFK] / (AFK)  -- status markers, not org
  --   (org_code)                 -- clan short code: (NT), (VR), (Abaddon)
  --   [ Kingdom ]                 -- kingdom name (spaces inside brackets)
  --   (Queen)(Verminasia)         -- multi-org: two groups, both real orgs
  --   (New Thalos), ( Dragon )    -- multi-word org, spaces inside parens too
  local orgs = {}
  rest = rest:gsub("[%(%[]%s*([^%)%]]-)%s*[%)%]]", function(tag)
    tag = trim(tag)
    if tag == "WANTED" then entry.wanted = true
    elseif tag == "Hostile" then entry.hostile = true
    elseif tag == "AFK" then entry.afk = true
    elseif tag ~= "" then orgs[#orgs + 1] = tag
    end
    return " "
  end)
  if #orgs > 0 then entry.org = table.concat(orgs, ", ") end

  -- Whatever's left: name, then title (if any words follow).
  local parts = {}
  for w in trim(rest):gmatch("%S+") do parts[#parts + 1] = w end
  entry.name = parts[1]
  if #parts > 1 then
    local t = {}
    for i = 2, #parts do t[#t + 1] = parts[i] end
    entry.title = table.concat(t, " ")
  end

  if entry.name then whoBlock[#whoBlock + 1] = entry end
end

function MyDSL.endWho()
  update("who", { players = whoBlock, count = #whoBlock })
  whoBlock = {}
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
  -- %s* after "[" added 2026-07-11 -- real bug found live: DSL right-justifies
  -- the level in a fixed-width field, so single-digit levels get a leading
  -- space ("[ 1 Mob] An untrained guardhand ...") instead of none
  -- ("[51 War] Olyndros ..."). The old pattern required a digit immediately
  -- after "[", so it silently failed to match ANY line (self included) once
  -- a group member's level dropped below 10 -- confirmed via
  -- Vaelis's real "[ 1 Mob]"/"[ 1 Mag]" group listing, which is what caused
  -- the reported "follower not showing in group" symptom.
  local level, class, name, hp, mana, mv =
    line:match("%[%s*(%d+)%s+(%a+)%]%s+(.-)%s+(%d+)%%%s+hp%s+(%d+)%%%s+mana%s+(%d+)%%%s+mv")
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

-- parseImproveStatusLine() -- added 2026-07-07, per Steven (wants a
-- LiveView bar showing remaining time for the skill being improved).
-- A DIFFERENT real message from the completion line above -- the response
-- to typing "improve" (no args): a status snapshot with a countdown.
-- Confirmed real text, both trailing-period forms (DSL is inconsistent):
--   "You are currently improving astrology (100%). (71 online minutes to improvement)"
--   "You are currently improving blind fighting (91%). (0 online minutes to improvement)."
-- User-initiated only (typing "improve" yourself) -- MyDSL never sends
-- this command automatically. The bar shows the last snapshot as-is
-- between checks rather than a live-ticking countdown ("stale data beats
-- spam"); `MyDSL.State.improve.last_updated` already records when.
function MyDSL.parseImproveStatusLine(line)
  local skill, pct, mins = line:match(
    "^You are currently improving (.-) %((%d+)%%%)%. %((%d+) online minutes to improvement%)%.?$")
  if skill then
    update("improve", { skill = trim(skill), percent = tonumber(pct), remaining = tonumber(mins) })
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

-- normalizeForMatch(name) / bestFuzzyMatch(target, candidates) -- added
-- 2026-07-16, ported from a real, tested technique found in the Shattered
-- Archive client's own equipment delta-matching (useEquipmentDeltas.ts,
-- ~/Downloads/Shattered-Archive-release-dev.zip): normalize both sides,
-- score an exact match highest, a substring match (either direction)
-- lower, and refuse to pick a winner if two candidates tie -- a false
-- merge (treating two different mobs/items as the same one) is worse
-- than declining to match at all. Shared by resolveMobName() (below) and
-- MyDSL.resolveGroundItem() (see the ITEM LORE section further down).
--
-- normalizeForMatch() strips the same decorations isLookFixtureLine()/
-- itemKey() already strip elsewhere in this file (leading article,
-- ground-sentence suffixes) so a truncated/generic capture (e.g. "a
-- gnome" from "A gnome is here using levers...") can still match a
-- fuller known name ("a gnome machinist") via substring containment.
local function normalizeForMatch(name)
  local s = tostring(name or ""):lower()
  while true do
    local stripped = s:match("^%(.-%)%s*(.+)$")
    if not stripped then break end
    s = stripped
  end
  s = s:gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  s = s:gsub("%s+lies? here.*$", "")
  s = s:gsub("%s+is lying here.*$", "")
  s = s:gsub("%s+are lying here.*$", "")
  s = s:gsub("%s+has been left here.*$", "")
  s = s:gsub("%s+floats above the ground.*$", "")
  s = s:gsub("[%.,;:!?'\"`]", " ")
  s = s:gsub("%s+", " ")
  return trim(s)
end

-- bestFuzzyMatch(target, candidates) -- candidates is an array of tables
-- each with a .name field (any other fields are carried through on the
-- returned match unchanged). Returns the winning candidate table, or nil
-- if nothing scored, or the top score was tied between two+ candidates.
local function bestFuzzyMatch(target, candidates)
  local t = normalizeForMatch(target)
  if t == "" then return nil end
  local best, bestScore, tie = nil, 0, false
  for _, c in ipairs(candidates or {}) do
    local cName = normalizeForMatch(c.name)
    if cName ~= "" then
      local score = 0
      if cName == t then
        score = 100
      elseif cName:find(t, 1, true) or t:find(cName, 1, true) then
        score = 50
      end
      if score > bestScore then
        best, bestScore, tie = c, score, false
      elseif score > 0 and score == bestScore then
        tie = true
      end
    end
  end
  if not best or tie then return nil end
  return best
end

-- resolveMobName(key, capturedName) -- added 2026-07-12, per Steven ("mob
-- names are the most important... if we need to use an identifier alias,
-- where we look then creaturelore, that could be an option"). Confirmed
-- via corpus research that a room's `look` text usually already matches
-- `scan`'s own noun phrase word-for-word, but real divergence does happen
-- (generic/truncated look descriptions, e.g. "A gnome is here using
-- levers..." vs. a specific creaturelore-known "gnome machinist") --
-- `MyDSL_CreatureLore.lua`'s DB is already keyed and populated exactly
-- this way from real `creaturelore` captures, so a "known" hit there is
-- a definitively-correct name, better than whatever got truncated out of
-- a room description. Falls back to the captured name whenever there's no
-- "known" (real lore data) match -- never guesses between multiple
-- possible creaturelore entries sharing a generic prefix (e.g. several
-- different "gnome ..." types) since that's not actually resolvable from
-- a generic captured name alone -- per Steven ("if we are unable to guess
-- then a generic is better than none").
--
-- Broadened 2026-07-16: the exact-key check above already covered the
-- case where `look`'s text happens to normalize to the identical key
-- CreatureLore was populated under. It never covered Steven's own example
-- ("a gnome" vs. a CreatureLore entry keyed "gnome machinist") since those
-- are two different keys -- exact match can't find that, only a fuzzy one
-- can. Tries the current room's own `scan` capture first (scan.byName --
-- per Steven, "using the propper scan name" -- small, same-room-visit,
-- least likely to collide with an unrelated same-prefix creature type),
-- then falls back to the full CreatureLore DB only if nothing in-room
-- matched. Still refuses to guess on a tie (bestFuzzyMatch's own rule) --
-- a wrong auto-resolved name is worse than the untouched generic capture.
local function resolveMobName(key, capturedName)
  local cl = MyDSL.CreatureLore
  if cl and cl.knownState and cl.knownState(key) == "known" then
    local rec = cl.get(key)
    if rec and rec.name then return rec.name end
  end

  local scan = MyDSL.State and MyDSL.State.scan
  if scan and scan.byName then
    local candidates = {}
    for k, entry in pairs(scan.byName) do
      if k ~= key and entry.is_mob then
        candidates[#candidates + 1] = { name = entry.name, key = k }
      end
    end
    local hit = bestFuzzyMatch(capturedName, candidates)
    if hit then return hit.name end
  end

  if cl and cl.db then
    local candidates = {}
    for k, rec in pairs(cl.db) do
      if k ~= key and rec and rec.name then
        candidates[#candidates + 1] = { name = rec.name, key = k }
      end
    end
    local hit = bestFuzzyMatch(capturedName, candidates)
    if hit then return hit.name end
  end

  return capturedName
end

function MyDSL.beginScan(mode, direction)
  -- Fresh table replaces any stale scan state.
  MyDSL.State.scan = {
    mode         = mode,
    direction    = direction,
    rows         = {},
    rightHere    = {},
    byName       = {},
    groundItems  = {},
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
    local newRow = nil
    if MyDSL.parseScanLine then
      local before = #MyDSL.State.scan.rows
      MyDSL.parseScanLine(ln)
      if #MyDSL.State.scan.rows > before then
        newRow = MyDSL.State.scan.rows[#MyDSL.State.scan.rows]
      end
    end
    selectCurrentLine()
    copy()
    if MyDSL.ScanView and MyDSL.ScanView.ui and MyDSL.ScanView.ui.scanConsole then
      MyDSL.ScanView.ui.scanConsole:appendBuffer()
      MyDSL.applyScanBadgeHover(newRow)
    end
  end)
end

-- applyScanBadgeHover(row) -- added 2026-07-16, per Steven ("scan window
-- should show seen/known flags"). RightHere already shows a visible
-- [Known]/[Seen]/[Unknown] badge (SV.renderRightHere(), MyDSL_ScanView.lua)
-- because that panel is decho-built from scratch every time. The Scan
-- body itself is raw copied game text (selectCurrentLine()+copy()+
-- appendBuffer() above) -- "move text, don't invent it" -- so a visible
-- inline badge would mean editing the pasted line after the fact, the
-- same mechanism already tried once for a left-margin space and reverted
-- ("no visible changes... not a big enough issue to chase"). Uses the
-- safer, already-proven hover technique instead (same as AffectsView's
-- applyLinks() / the equipment-line hover in parseEquipLine()):
-- selectString()+setLink() on the just-appended line, tooltip only, never
-- touches the visible text. Selects on the pre-resolution rawName (not
-- the possibly-substituted display name) so it still matches the literal
-- on-screen text even for a "Known" mob whose resolved name differs from
-- what the game actually printed.
function MyDSL.applyScanBadgeHover(row)
  if not row or not row.is_mob then return end
  if not (MyDSL.CreatureLore and MyDSL.CreatureLore.knownState) then return end
  if not (selectString and setLink) then return end
  local mc = MyDSL.ScanView and MyDSL.ScanView.ui and MyDSL.ScanView.ui.scanConsole
  if not mc then return end
  -- Known fixed name (MyDSL_ScanView.lua's SCAN_MC constant), not read off
  -- the Geyser object -- matches how the rest of this codebase treats
  -- console window names (e.g. AffectsView's A.config.windowName) as
  -- known string literals rather than introspected object fields.
  local windowName = "MyDSL_Scan_MC"
  local state = MyDSL.CreatureLore.knownState(row.key)
  local hint
  if state == "known" then hint = "Known -- lore data captured"
  elseif state == "seen" then hint = "Seen -- not yet lore'd"
  else hint = "Unknown -- never seen before this scan" end
  local target = row.rawName or row.name
  if not target or target == "" then return end
  local okSel, selected = pcall(selectString, windowName, target, 1)
  if okSel and selected then
    pcall(setLink, windowName, "", hint)
  end
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
  -- Mark seen + resolve to CreatureLore's canonical name if known -- see
  -- resolveMobName()'s comment above for the full reasoning. Mobs only
  -- (not players) -- CreatureLore is a creature DB, "lore"-ing a player
  -- isn't a real thing.
  if is_mob and MyDSL.CreatureLore and MyDSL.CreatureLore.markSeen then
    MyDSL.CreatureLore.markSeen(key, name)
  end
  local dispName = is_mob and resolveMobName(key, name) or name
  local row = {
    raw     = line,
    name    = dispName,
    display = dispName,
    rawName = name,  -- pre-resolution captured name -- see applyScanBadgeHover()
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
      name    = dispName,
      display = dispName,
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
        name    = dispName,
        display = dispName,
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
-- 9o.1  LOOK -- refresh RightHere from a full room look, not just scan
------------------------------------------------------------------------
-- Fixed 2026-07-07, per Steven: "RightHere should update on look too, not
-- just scan." `look`'s room-content lines use a different, plainer format
-- than scan's ("<Name> is here[, <status>].", optionally prefixed with a
-- "(<Flag>) " tag) -- confirmed real text from log/2026-07-07#18-29-43.html:
-- "(Golden Aura) A gnome factory worker is here.", "(Charmed) a wild bear
-- is here, fighting a gnome machinist.", "A gnome is here using levers and
-- pullies to yank up a large parts of the" (no comma at all before the
-- trailing description). Anchored on the room's own "[Exits: ...]" line
-- (always the line immediately after the room description, immediately
-- before its content listing) rather than a fixed header phrase, since
-- `look` has no distinct start-of-listing banner the way scan's "Looking
-- around you see:" does -- this also means RightHere now refreshes on
-- every room entry (movement reprints the room), not just an explicit
-- `look`, which is a strict improvement, not scope creep (still 100%
-- observational, no command ever sent). Long status phrases can wrap onto
-- a following physical line (confirmed: "...keeping the gears" /
-- "lubricated." split across two lines in the same real example) --
-- since only presence (not the wrapped remainder) matters for RightHere,
-- continuation lines are recognized by starting with a lowercase letter
-- (DSL always capitalizes the start of a new game message) and are
-- skipped without ending capture. Any other line ends capture, since
-- look's listing has no blank-line terminator the way scan's does --
-- real-time events (arrivals, tells, etc.) can start appearing
-- immediately after the last content line with no gap.

-- isLookFixtureLine() -- fixed 2026-07-08. Real bug found live: a room
-- with an item on the ground ("A grand arcanium hoopak lies here.")
-- ended capture immediately after that ONE line, silently dropping every
-- mob listed after it -- "lies here"/"is lying here" don't match
-- parseLookHereLine's mob pattern, and the line starts with a capital
-- letter so the wrapped-continuation check didn't save it either,
-- leaving only the "unrelated event, end capture" fallback. Confirmed
-- these phrasings are common, not rare -- dozens of real examples across
-- items ("X lies here[.| on the ground.]") and corpses ("The corpse of X
-- is lying here.") in the DSL2-era corpus -- checked specifically for
-- any mob using these two verbs and found none, unlike "sits here"
-- (see parseLookHereLine, handled there instead since it's genuinely
-- ambiguous). These lines are real, static room content (like mob lines)
-- -- just not something RightHere tracks -- so they should be skipped
-- without ending capture, same treatment as a wrapped continuation line.
local function isLookFixtureLine(line)
  return line:match("lies? here%f[%A]") ~= nil
      or line:match("is lying here%f[%A]") ~= nil
      or line:match("are lying here%f[%A]") ~= nil
      or line:match("has been left here%f[%A]") ~= nil
      or line:match("^You see .- here%f[%A]") ~= nil
      -- Found live 2026-07-08: "(Glowing) (Humming) A Parrying dagger
      -- floats above the ground." has no "here"/"in the room" anchor at
      -- all, so it fell through every check (including the broad mob
      -- fallback) straight to "unrelated event, end capture" -- confirmed
      -- via screenshot to have silently dropped 4 real gnomes/excavators
      -- listed right after it in the same room.
      or line:match("floats above the ground%f[%A]") ~= nil
end

-- extractGroundItemName(line) / MyDSL.captureGroundItem(line) -- added
-- 2026-07-16 for ground-vs-inventory item linking (Steven: "the item on
-- the ground needs a map to the inventory/equipment"). Only ever called
-- after isLookFixtureLine() has already confirmed one of its suffixes is
-- present -- strips the same leading parenthetical tags and trailing
-- fixture-sentence phrasing to recover the item's core name (e.g. "A
-- grand arcanium hoopak lies here." -> "A grand arcanium hoopak") for
-- storage. Before this, isLookFixtureLine-matched lines were only ever
-- skipped, never stored anywhere -- there was no ground-item data at all
-- to match against.
local function extractGroundItemName(line)
  local rest = trim(line)
  while true do
    local stripped = rest:match("^%([^()]+%)%s*(.+)$")
    if not stripped then break end
    rest = stripped
  end
  local seen = rest:match("^You see%s+(.-)%s+here")
  if seen then return trim(seen) end
  rest = rest:gsub("%s+lies? here.*$", "")
  rest = rest:gsub("%s+is lying here.*$", "")
  rest = rest:gsub("%s+are lying here.*$", "")
  rest = rest:gsub("%s+has been left here.*$", "")
  rest = rest:gsub("%s+floats above the ground.*$", "")
  return trim(rest)
end

function MyDSL.captureGroundItem(line)
  local scan = MyDSL.State and MyDSL.State.scan
  if not scan then return end
  scan.groundItems = scan.groundItems or {}
  local name = extractGroundItemName(line)
  if name == "" then return end
  local key = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  if scan.groundItems[key] then
    scan.groundItems[key].count = scan.groundItems[key].count + 1
  else
    scan.groundItems[key] = { raw = line, name = name, key = key, count = 1 }
  end
  MyDSL.applyGroundItemHover(name, key)
end

-- applyGroundItemHover(name, key) -- added 2026-07-16, wires
-- MyDSL.resolveGroundItem() (built the prior pass, never connected to any
-- UI) into an actual hover, same "move text, don't invent it" technique
-- as the equipment-line hover in parseEquipLine(): selectString()+
-- setLink() on the raw line already sitting in the main console, never
-- touching its visible text. Only attaches a hover when a resolution
-- actually exists (manual override, ItemLore DB hit, or an unambiguous
-- fuzzy match) -- the real fraction of ground items with no resolution
-- at all (per Steven's own "best effort" framing) get no hover, not a
-- fabricated one.
function MyDSL.applyGroundItemHover(name, key)
  if not (selectString and setLink) then return end
  local resolved = MyDSL.resolveGroundItem and MyDSL.resolveGroundItem(key)
  if not resolved then return end
  local rec = MyDSL.ItemLore and MyDSL.ItemLore.get and MyDSL.ItemLore.get(resolved.key or key)
  local hint = "Resolved to \"" .. tostring(resolved.name) .. "\" (" .. tostring(resolved.source) .. ")"
  if rec then
    if rec.itemType then hint = hint .. " -- " .. rec.itemType end
    if rec.damageDice then hint = hint .. " -- " .. rec.damageDice .. " (avg " .. tostring(rec.damageAvg) .. ")" end
    if rec.armorClass then
      local ac = rec.armorClass
      hint = hint .. string.format(" -- AC %s/%s/%s/%s", tostring(ac.pierce), tostring(ac.bash), tostring(ac.slash), tostring(ac.magic))
    end
  end
  hint = hint .. " -- Click for Item Reference"
  local cmd = string.format(
    'if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.render("%s"); MyDSL.ItemReference.show() end',
    tostring(resolved.name):gsub('"', '\\"'))
  local okSel, selected = pcall(selectString, "main", name, 1)
  if okSel and selected then
    pcall(setLink, "main", cmd, hint)
  end
end

-- isUnparsedPresenceLine() -- broadened 2026-07-09, third confirmed live
-- instance of the same underlying problem. Originally added 2026-07-08 as
-- isCharmedStatusLine() for charmed/summoned pets' varying idle-action
-- verbs ("sloshes around here.", "follows their client." with no "here"
-- anchor at all -- see git history for the full original writeup; this is
-- what Steven meant by "the space after certain followers"). That version
-- only checked for a literal "(Charmed)" tag. Confirmed live 2026-07-09
-- via screenshot: "A dark elven commoner stands around looking bored."
-- and "The dark elven scout slips in and out from the shadows unheard."
-- -- ordinary room NPCs, no "(Charmed)" tag at all, no "here"/"in the
-- room" anchor either -- caused RightHere to come back completely empty
-- for that room. Enumerating every possible DSL verb phrase has now
-- failed three times (round 2's fallback, the Charmed-tag safety net,
-- now this) -- so generalize: every confirmed example of this whole bug
-- class, charmed-tagged or not, has always started with an article
-- ("A"/"An"/"The", the same shape isMobName() already checks) once any
-- leading parenthetical tags are stripped. Treat that shape alone as
-- sufficient proof of a live presence line worth skipping past, whether
-- or not a clean name can be extracted from it -- strictly broader than
-- the old Charmed-only check, so it subsumes it.
local function isUnparsedPresenceLine(line)
  -- trim() added 2026-07-09 -- real bug found live: static room-landmark
  -- lines are sometimes indented with leading whitespace (e.g. "     A
  -- twisted and gnarled pine tree grows crookedly here."), which broke
  -- this function's `^`-anchored article check even though the *content*
  -- is identical in shape to every other confirmed presence line. This
  -- silently ended capture (RightHere showed completely empty) the
  -- moment an indented landmark line like this was the first thing after
  -- "[Exits: ...]" in the listing. isLookFixtureLine()'s unanchored
  -- substring checks never had this problem; only the `^`-anchored ones
  -- here and in parseLookHereLine() did.
  -- "This " added 2026-07-16 -- fourth confirmed live instance of this
  -- same bug class. Found by tracing a real room-look line by line
  -- (log/2026-07-16#17-23-54.html): "This studded mace looks particularly
  -- dangerous." is an item-flavor-text line, same shape as every other
  -- confirmed presence/fixture line, but starts with neither "A"/"An"/
  -- "The" nor a "lies/lying/left/floats" fixture keyword -- it fell
  -- through every check straight to endLook(), which would have silently
  -- dropped everything listed after it in that same room, including two
  -- real mobs (a war mage, three novice mages) at the very end of the
  -- listing.
  local rest = trim(line)
  while true do
    local stripped = rest:match("^%([^()]+%)%s*(.+)$")
    if not stripped then break end
    rest = stripped
  end
  return rest:match("^[Aa]n? ") ~= nil or rest:match("^[Tt]he ") ~= nil
      or rest:match("^This ") ~= nil
end

function MyDSL.beginLook()
  -- REAL GOTCHA, found live 2026-07-12 -- Steven discovered GMCP is not
  -- enabled by default for newly created DSL characters (confirmed on
  -- Vexgar: traced a full real play session, autowhere/improve/scan/look
  -- all working normally, but zero MyDSL debug output past boot and zero
  -- character-bound files ever created). MyDSL.character.identified only
  -- ever fires from the gmcp.login_data handler above -- if GMCP itself
  -- is off for that character, it silently never fires, and NOTHING
  -- per-character loads, saves, or persists for the whole session, with
  -- no visible sign anything's wrong. This warns once: beginLook() fires
  -- on plain text ("[Exits: ...]"), no GMCP dependency, so it still
  -- fires even with GMCP fully off -- and by the time real room content
  -- is displaying, login/MOTD/character-select are long done, so a still-
  -- nil MyDSL.Char() here is a real signal, not normal startup timing.
  if not MyDSL.Char() and not MyDSL._gmcpWarnedNoChar then
    MyDSL._gmcpWarnedNoChar = true
    cecho("\n<red>[MyDSL] WARNING: no character identified yet (GMCP login_data never arrived).<reset>\n"
       .. "<yellow>If this is a newly created character, GMCP may be OFF by default for it -- "
       .. "check/enable GMCP, or none of MyDSL's per-character saving/loading will work this session.<reset>\n")
  end

  MyDSL.State.scan = MyDSL.State.scan or {
    mode = nil, direction = nil, rows = {}, rightHere = {}, byName = {}, groundItems = {}, last_updated = 0,
  }
  MyDSL.State.scan.rightHere = {}
  MyDSL.State.scan.groundItems = {}
  -- Only one listing-capture should ever be active at a time -- kill a
  -- leftover scan catch-all too, not just a leftover look one.
  if MyDSL._triggers.scanBody then
    pcall(killTrigger, MyDSL._triggers.scanBody)
    MyDSL._triggers.scanBody = nil
  end
  if MyDSL._triggers.lookBody then
    pcall(killTrigger, MyDSL._triggers.lookBody)
    MyDSL._triggers.lookBody = nil
  end
  MyDSL._triggers.lookBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.scan) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    -- Blank lines DON'T end capture here (fixed 2026-07-08) -- confirmed
    -- real, repeatable: a busy room's mob listing can include a genuine
    -- blank line mid-list (same room, same blank-line position, on both
    -- a movement-triggered reprint and an explicit "look"), so treating
    -- blank as a terminator was silently dropping every mob after it.
    -- look has no reliable terminator at all (see the header comment
    -- above) -- skip blanks silently and keep waiting for real content.
    if t == "" then return end
    -- REAL ROOT CAUSE, found 2026-07-08 via a live debug trace (static
    -- analysis alone couldn't catch this): this catch-all gets installed
    -- by lookExits's callback WHILE that same "[Exits: ...]" line is still
    -- being processed, and Mudlet evaluates newly-registered triggers
    -- against that same current line in the same pass -- so this trigger
    -- immediately re-fires on the very "[Exits: ...]" line that just
    -- created it, before any real content line is ever seen. Confirmed
    -- via trace: every single look showed anchor-fired -> beginLook() ->
    -- endLook(), zero entities, every time, with the "unrelated event"
    -- endLook() blamed on turned out to be the Exits line itself. This is
    -- why RightHere showed 0 entries/capture-inactive on every real test
    -- despite the anchor and body logic both being individually correct.
    if t:match("^%[Exits: .*%]$") then return end  -- the anchor line re-seeing itself, not content
    -- Fixture check MUST run before parseLookHereLine -- item lines like
    -- "X lies here." also satisfy parseLookHereLine's broad "here"
    -- fallback below, and would otherwise get miscaptured as mobs.
    if isLookFixtureLine(ln) then MyDSL.captureGroundItem(ln); return end  -- item/corpse/fixture, keep capturing
    if MyDSL.parseLookHereLine(ln) then return end
    if isUnparsedPresenceLine(ln) then return end  -- see comment above the function
    if t:match("^%l") then return end  -- wrapped continuation, keep capturing
    MyDSL.endLook()
  end)
end

function MyDSL.parseLookHereLine(line)
  local scan = MyDSL.State.scan
  if not scan then return false end
  -- Strip ALL leading parenthetical tags, not just one -- confirmed real
  -- multi-tag stacking, e.g. "(Glowing) (Humming) (Green Aura) A ..." and
  -- "(Translucent) (White Aura) An air elemental ...".
  -- trim() added 2026-07-09 -- see isUnparsedPresenceLine()'s comment
  -- above for the confirmed bug this fixes (indented landmark lines
  -- breaking every `^`-anchored check in this function).
  local rest = trim(line)
  while true do
    local stripped = rest:match("^%([^()]+%)%s*(.+)$")
    if not stripped then break end
    rest = stripped
  end
  -- "stands here"/"sits here"/"hovers" added 2026-07-08: confirmed via
  -- corpus frequency check that "stands here" (2,740 occurrences) is
  -- actually MORE common than "is here" (1,928) for describing stationary
  -- NPCs (guards, shopkeepers, mounts) -- these were never captured at
  -- all before this fix. "sits here" is genuinely ambiguous between mobs
  -- ("A hill dwarf sits here, panning for gold.") and items/fixtures
  -- ("A jewel-encrusted dagger sits here."/an altar) -- erred toward
  -- capturing it (a spurious item entry in RightHere is a harmless
  -- cosmetic rough edge; silently dropping a real mob is worse). "hovers"
  -- (139 occurrences, e.g. "An air elemental hovers in the room like a
  -- cloud.", "A half elven child hovers nearby, looking for food.") isn't
  -- always followed by "here" so it's matched on its own.
  -- Broad fallback added 2026-07-08 (see isUnparsedPresenceLine comment
  -- above for the confirmed corpus evidence): charmed/summoned pets use
  -- many different idle-action verbs before "here"/"in the room" ("sloshes
  -- around here.", "prances about here.", "looms here.", "burns hotly in
  -- the room."). Restricted to lines starting with an article (same
  -- shape isMobName already requires) to avoid misreading ordinary room-
  -- description prose. Only reached after isLookFixtureLine has already
  -- ruled out "lies here"/"is lying here" item/corpse lines (see caller).
  local name = rest:match("^(.-) is here%f[%A]")
            or rest:match("^(.-) stands here%f[%A]")
            or rest:match("^(.-) sits here%f[%A]")
            or rest:match("^(.-) hovers%f[%A]")
            or rest:match("^([Aa]n? .+) here%f[%A]")
            or rest:match("^([Tt]he .+) here%f[%A]")
            or rest:match("^([Aa]n? .+) in the room%f[%A]")
            or rest:match("^([Tt]he .+) in the room%f[%A]")
  if not name then return false end
  name = trim(name)
  if name == "" then return false end
  local key    = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  local is_mob = isMobName(name)
  -- Mark seen + resolve to CreatureLore's canonical name if known -- see
  -- resolveMobName()'s comment (above beginScan()) for the full reasoning.
  -- This is exactly where a `look`-derived name is most likely to be
  -- generic/truncated relative to `scan`'s fuller noun phrase (e.g. "A
  -- gnome is here using levers..." only captures "A gnome" here), so this
  -- is the primary place CreatureLore's better-identified name helps.
  if is_mob and MyDSL.CreatureLore and MyDSL.CreatureLore.markSeen then
    MyDSL.CreatureLore.markSeen(key, name)
  end
  local dispName = is_mob and resolveMobName(key, name) or name
  -- Fixed 2026-07-08, per Steven ("not updating correctly on mob
  -- counts"): this used to unconditionally overwrite scan.rightHere[key]
  -- with a fresh count=1 table every time, so a room with 3 identical
  -- mobs (e.g. "A gnome in a protective heat suit is studying here."
  -- appearing twice) always showed count=1 in the RightHere window --
  -- each repeat just clobbered the previous one instead of incrementing.
  -- Matches the same increment-if-exists pattern parseScanLine already
  -- uses for scan.rightHere just above.
  if scan.rightHere[key] then
    scan.rightHere[key].count = scan.rightHere[key].count + 1
  else
    scan.rightHere[key] = {
      raw = line, name = dispName, display = dispName, key = key,
      where = "right here", is_mob = is_mob, count = 1,
    }
  end
  return true
end

function MyDSL.endLook()
  if MyDSL._triggers.lookBody then
    pcall(killTrigger, MyDSL._triggers.lookBody)
    MyDSL._triggers.lookBody = nil
  end
  MyDSL.State.scan.last_updated = os.time()
  MyDSL.emit("scan")
end


------------------------------------------------------------------------
-- 9o.2  PLAYERS NEAR YOU
------------------------------------------------------------------------
-- Fixed 2026-07-05, per Steven: "Players near you:" (fired every ~20s by
-- his own autowhere-style alias, not part of this project) was flowing
-- untouched into main console -- MyDSL.Route.players() already existed in
-- RouteHelper (auto-creates the MyDSL_PlayersNear MiniConsole) but was
-- never actually called from anywhere. Confirmed real body shape from
-- log/: "Players near you:" header, one "<Name><padding><Room>" line per
-- player, terminated by a blank line -- same begin/catch-all/end shape as
-- beginScan(), and the same "move text, don't rewrite it" observer pattern
-- (appendBuffer via Route.players(nil), not a reformatted decho).

-- isPlayersNearBodyLine() -- added 2026-07-11, real bug found live via
-- screenshot: the catch-all below used to accept ANY non-blank line
-- unconditionally, relying solely on a blank line to end capture. Same
-- fragile shape as every RightHere-on-look bug fixed earlier this
-- session -- if DSL interleaves an unrelated broadcast (a combat
-- condition update, a bare single-letter weapon-flag proc line) before
-- the real blank-line terminator arrives, it gets vacuumed into
-- MyDSL_PlayersNear right along with real players. Confirmed live:
-- "A tinker gnome mage is in awful condition." and bare "S" lines (the
-- Stunning proc flag's own wire text) both showed up mixed in with real
-- "Meshkin   A Sloped Hall" / "Uldek   Arena" entries. Real body lines
-- never end in sentence punctuation and always have a wide column-
-- padding gap between name and room (confirmed shape, see the header
-- comment above) -- a condition sentence ends in "." and a bare proc
-- letter has no gap at all, so both are cheaply distinguishable without
-- needing to enumerate every possible interrupting broadcast.
local function isPlayersNearBodyLine(line)
  if line:match("[%.!?]%s*$") then return false end
  if not line:match("^%S+%s%s+%S") then return false end
  return true
end

-- routePlayersNearBodyLine(line) -- added 2026-07-12, per Steven
-- ("playersnearyou: can we reduce the space between the players name and
-- the room, make the text tighter together for a smaller window without
-- losing the coloring of the players name?"). DSL's own wide column-
-- padding between name and room (confirmed shape above) is what made the
-- gap so wide -- still real text DSL sent, not fabricated, so this only
-- changes how much of that whitespace gets carried over, not the name or
-- room text itself.
--
-- REAL BUG, found live 2026-07-12 via screenshot (Steven: "players near
-- you has room names in it"): the first version of this function called
-- selectSection()/copy()/con:appendBuffer() TWICE (once for the name,
-- once for the room), with a con:echo("  ") in between to join them on
-- one line. appendBuffer() doesn't work that way -- confirmed via the
-- Mudlet forums (search: "appendBuffer... cursor stays on line 1, this
-- output call doesn't update the cursor position") -- each appendBuffer()
-- call always lands its copied text as its OWN new line in the
-- destination console, regardless of where echo() thinks the cursor is.
-- That's why the screenshots showed "Kien" and the room name ("The Magic
-- Facility"/"Advanced Magics") as two separate stacked lines with no
-- visible gap between them -- the con:echo("  ") calls were writing to a
-- stale cursor position that never lined up with either appended line.
-- Every other Route.to()-based window in this profile (History/Combat/
-- Scan/Group/RightHere) only ever calls copy()+appendBuffer() ONCE per
-- routed line for exactly this reason.
--
-- Fixed by tightening the gap IN PLACE on the source line before doing a
-- single whole-line copy: selectSection() the gap substring only and
-- replace() it with a fixed 2-space gap -- this edits real whitespace in
-- the actual captured line (not the name or room text, which are left
-- completely untouched, coloring included), so the one-shot
-- selectCurrentLine()/copy()/appendBuffer() below still carries the DSL-
-- original color for both name and room, just with a tighter gap between
-- them. Falls back to routing the line unchanged if the expected shape
-- isn't found (never guesses at a split that isn't really there).
local function routePlayersNearBodyLine(line)
  local name, gap, rest = line:match("^(%S+)(%s%s+)(%S.*)$")
  if name and gap ~= "  " then
    selectSection(#name, #gap)
    replace("  ")
  end
  MyDSL.Route.players(nil)
end

function MyDSL.beginPlayersNear()
  if not (MyDSL and MyDSL.Route) then return end
  MyDSL.Route.clear("MyDSL_PlayersNear")
  selectCurrentLine()
  copy()
  MyDSL.Route.players(nil)
  deleteLine()

  if MyDSL._triggers.playersNearBody then
    pcall(killTrigger, MyDSL._triggers.playersNearBody)
    MyDSL._triggers.playersNearBody = nil
  end
  MyDSL._triggers.playersNearBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.Route) then return end
    local ln = getCurrentLine()
    if trim(ln) == "" then MyDSL.endPlayersNear(); return end
    -- Unrelated broadcast interleaved mid-block -- skip it, but keep
    -- capturing (don't end early): more real player lines may still
    -- follow before the actual blank-line terminator arrives.
    if not isPlayersNearBodyLine(ln) then return end
    routePlayersNearBodyLine(ln)
    deleteLine()
  end)
end

function MyDSL.endPlayersNear()
  if MyDSL._triggers.playersNearBody then
    pcall(killTrigger, MyDSL._triggers.playersNearBody)
    MyDSL._triggers.playersNearBody = nil
  end
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

-- splitWords(s) -- "mental disease" -> {"mental","disease"}. Used for the
-- Immunities/Resistances/Vulnerabilities/Affects lines below, which are
-- real DSL space-separated flag lists (confirmed via log-corpus grep:
-- "Immunities: summon charm magic weapon blunt poison negative holy
-- mental disease", no commas) -- stored as tables to match
-- MyDSL_CreatureReference.lua's existing listLine() display helper, which
-- already expects a table (`#tbl > 0`), not a bare string.
local function splitWords(s)
  local out = {}
  for w in tostring(s or ""):gmatch("%S+") do table.insert(out, w) end
  return out
end

function MyDSL.parseCreatureLoreLine(line)
  local r = MyDSL.State.creaturelore
  if not r then return end
  table.insert(r.lines, line)
  -- Alignment: real phrasing varies more than the raw capture used to
  -- keep -- confirmed via log-corpus grep across many creatures: "a good
  -- soul.", "a more neutral soul." (filler "more"), "a evil and corrupt
  -- soul." (extra qualifier after "evil"). Narrowed 2026-07-11 per Steven
  -- ("only need to capture the good evil neutral for align") -- search
  -- the captured phrase for whichever of the 3 real keywords is present,
  -- instead of storing the whole variable phrase verbatim.
  local a = line:match("^.- appears to be (.+) soul%.")
  if a then
    r.alignmentText = a:match("(good)") or a:match("(evil)") or a:match("(neutral)") or trim(a)
  end
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

  -- Added 2026-07-11, per Steven's TargetView redesign ("should show the
  -- stats we collect with creaturelore") -- confirmed real via log-corpus
  -- grep + DSL_Helpfiles/creaturelore.txt ("physical and magical health,
  -- level of training, weapon damage type, immunities and resistances,
  -- vulnerabilities and magical affects"), none of these 6 fields were
  -- being captured at all before, only race/align/wealth/sex/hp.

  -- Magic: "The base magically ability of this creature is 1336."
  local mg = line:match("^The base magically ability of this creature is%s+(%d+)%.")
  if mg then r.magic = tonumber(mg) end

  -- Damage: "This creature does 6d7 damage in a slash manner."
  local dice, dtype = line:match("^This creature does%s+(.-)%s+damage in a?n?%s*(.-)%s+manner%.")
  if dice then r.damage = dice; r.damageType = trim(dtype) end

  -- Characteristics list, each its own line: "Immunities: charm",
  -- "Resistances: blunt cold". Vulnerabilities line format is unconfirmed
  -- in the log corpus (zero real examples found) but documented in
  -- DSL_Helpfiles/creaturelore.txt as a real category -- parsed the same
  -- way defensively; harmless if it never matches.
  local imm = line:match("^Immunities:%s*(.+)$")
  if imm then r.immunities = splitWords(imm) end
  local res = line:match("^Resistances:%s*(.+)$")
  if res then r.resists = splitWords(res) end
  local vuln = line:match("^Vulnerabilities:%s*(.+)$")
  if vuln then r.vulns = splitWords(vuln) end

  -- Affects: "This creature is affected by charm" -- confirmed real via
  -- log-corpus grep, a sentence, not a "Affects:" label line.
  local aff = line:match("^This creature is affected by%s+(.+)$")
  if aff then r.affects = splitWords(aff) end

  -- Offensive Tactics + training cycle ("level") -- added 2026-07-11, per
  -- Steven ("we arent capturing the offensive tactics and level of the
  -- mobs (level is IC cycles of training)"). Both confirmed real via
  -- log-corpus grep across many creatures:
  --   "Offensive Tactics:bash disarm dodge parry trip assist_vnum"
  --   (NO space after the colon, unlike Immunities:/Resistances:/etc.)
  --   "This creature is upon the cycle of training '50'"
  --   (single-quoted number, no trailing period).
  local tactics = line:match("^Offensive Tactics:(.+)$")
  if tactics then r.tactics = splitWords(tactics) end
  local cycle = line:match("^This creature is upon the cycle of training '(%d+)'")
  if cycle then r.trainingCycle = tonumber(cycle) end
end

function MyDSL.endCreatureLore()
  if MyDSL._triggers.loreBody then
    pcall(killTrigger, MyDSL._triggers.loreBody)
    MyDSL._triggers.loreBody = nil
  end
  MyDSL.State.creaturelore.last_updated = os.time()
  -- Merge into the persistent DB (MyDSL_CreatureLore.lua) if it's loaded.
  --
  -- REAL BUG, found live 2026-07-11 (Steven: "doesnt look like its auto
  -- updating stats"): this used to ALSO write to
  -- MyDSL.State.creatureLoreCache[key] here -- a session-only cache that
  -- got superseded by the real persistent DB earlier the same day. Its
  -- initializer (MyDSL_DataLayer.lua's old
  -- "MyDSL.State.creatureLoreCache = ... or {}" line) was removed as part
  -- of that same edit, but THIS write site was missed -- so every real
  -- "creaturelore" capture threw "attempt to index a nil value" right
  -- here, which aborted endCreatureLore() before it ever reached
  -- CreatureLore.merge() or MyDSL.emit() below. Confirmed live: no
  -- MyDSL/creaturelore_db.lua file existed on disk at all after a real
  -- capture, and the Focus window never got the "creaturelore.updated"
  -- event to redraw from. Fixed by deleting the dead write entirely --
  -- nothing reads MyDSL.State.creatureLoreCache anymore.
  if MyDSL.CreatureLore and MyDSL.CreatureLore.merge then
    MyDSL.CreatureLore.merge(MyDSL.State.creaturelore)
  end
  MyDSL.emit("creaturelore")
end


------------------------------------------------------------------------
-- 9p.1  ITEM LORE / IDENTIFY
------------------------------------------------------------------------
-- Feeds MyDSL_ItemLore.lua's persistent DB. Two live capture paths, both
-- confirmed real via live sessions 2026-07-16 (full transcripts in
-- docs/CapturedPatterns_Reference.txt / CHANGELOG.md):
--   `c identify <keyword>` (the spell) -- full stats, including bonuses/
--   enchants ("Affects X by N", "Weapons flags:", "Armor class is...").
--   `lore <keyword>` (the skill, chance-based) -- a real subset of the
--   same fields, but NEVER bonuses/enchants -- confirmed absent from
--   every real lore transcript. This is what makes MyDSL_ItemLore.lua's
--   merge() safe to reuse unmodified for both: lore's own parsed record
--   simply never has those keys, so it can never downgrade an
--   already-identified item back to partial.

local function itemKey(name)
  return trim(tostring(name or "")):lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
end

-- MyDSL.resolveGroundItem(key) -- added 2026-07-16, ItemLore's counterpart
-- to resolveMobName() (see the SCAN section above for the shared
-- normalizeForMatch()/bestFuzzyMatch() helper both use). Given a ground
-- item's key (from MyDSL.State.scan.groundItems, populated by
-- captureGroundItem()), tries to resolve it to the same item already seen
-- equipped or carried. Checks ItemLore's own DB by exact key first (if
-- this ground item was already identified/lore'd directly under this
-- exact name, no fuzzy step is needed). Otherwise fuzzy-matches the
-- ground sentence's stripped core name against every currently-known
-- equipment slot and inventory item -- confirmed via a real paired sample
-- (log/2026-07-16#17-23-54.html) that roughly 2/3 of items share a clean
-- substring once both sides are normalized (e.g. "a decanter of endless
-- water" <-> "A decanter of endless water lies here."); the rest
-- (independently-phrased ground flavor text, e.g. "a shaping mallet" vs.
-- "a mallet used to shape metal") correctly score 0 and return nil rather
-- than guessing -- best-effort only, per Steven ("best effort mapping is
-- fine, maybe a manual map option").
function MyDSL.resolveGroundItem(key)
  local ground = MyDSL.State.scan and MyDSL.State.scan.groundItems and MyDSL.State.scan.groundItems[key]
  if not ground then return nil end

  -- Manual override wins outright -- see MyDSL.setGroundItemOverride()
  -- below ("item map <ground text> = <inventory/equipment text>").
  local override = MyDSL.State.groundItemOverrides and MyDSL.State.groundItemOverrides[key]
  if override then return { key = override, name = override, source = "manual" } end

  if MyDSL.ItemLore and MyDSL.ItemLore.get then
    local rec = MyDSL.ItemLore.get(key)
    if rec then return { key = key, name = rec.name or ground.name, source = "itemlore" } end
  end

  local candidates = {}
  local eq = MyDSL.State.equipment and MyDSL.State.equipment.slots
  if eq then
    for slot, entry in pairs(eq) do
      if entry and entry.item then
        candidates[#candidates + 1] = {
          name = entry.item, key = itemKey(entry.item), source = "equipment", slot = slot,
        }
      end
    end
  end
  local inv = MyDSL.State.inventory and MyDSL.State.inventory.items
  if inv then
    for k, entry in pairs(inv) do
      candidates[#candidates + 1] = { name = entry.item, key = k, source = "inventory" }
    end
  end

  return bestFuzzyMatch(ground.name, candidates)
end

-- MyDSL.setGroundItemOverride(groundText, targetText) -- the "manual map
-- option" Steven asked for, for the real fraction of items where the
-- automatic fuzzy match correctly declines (no shared substring) but the
-- player knows for certain it's the same item. Keyed by the ground text's
-- own itemKey() so it applies to every future sighting of that same
-- ground description, not just the one currently in view.
function MyDSL.setGroundItemOverride(groundText, targetText)
  groundText = trim(tostring(groundText or ""))
  targetText = trim(tostring(targetText or ""))
  if groundText == "" or targetText == "" then
    echo("usage: item map <ground item text> = <inventory/equipment item name>\n")
    return
  end
  local key = itemKey(groundText)
  MyDSL.State.groundItemOverrides = MyDSL.State.groundItemOverrides or {}
  MyDSL.State.groundItemOverrides[key] = targetText
  echo("Ground item \"" .. groundText .. "\" manually mapped to \"" .. targetText .. "\".\n")
end

-- Shared body-line parser -- both identify and lore blocks use the same
-- optional-line shapes (confirmed identical wording in both real
-- transcripts); which subset actually appears just depends on which
-- command produced the block.
local function parseItemBodyLine(r, line)
  local weight, value, level = line:match("^Weight is (%d+), value is (%d+), level is (%d+)%.$")
  if weight then r.weight = tonumber(weight); r.value = tonumber(value); r.level = tonumber(level); return end

  local material = line:match("^The object is made of (.+)%.$")
  if material then r.material = material; return end

  local wtype = line:match("^Weapon type is (.+)%.$")
  if wtype then r.weaponType = wtype; return end

  local dice, avg = line:match("^Damage is (%d+d%d+) %(average (%d+)%)%.$")
  if dice then r.damageDice = dice; r.damageAvg = tonumber(avg); return end

  local wflags = line:match("^Weapons flags: (.+)$")
  if wflags then r.weaponFlags = wflags; return end

  local p, b, s, m = line:match("^Armor class is (%d+) pierce, (%d+) bash, (%d+) slash, and (%d+) vs%. magic%.$")
  if p then r.armorClass = { pierce = tonumber(p), bash = tonumber(b), slash = tonumber(s), magic = tonumber(m) }; return end

  local size, cond, pct = line:match("^Size: (%a+)%s+Condition: (.-) %((%d+)%%%)$")
  if size then r.size = size; r.condition = cond .. " (" .. pct .. "%)"; return end

  local cap, maxw, cflags = line:match("^Capacity: (%d+)#%s+Maximum weight: (%d+)#%s+flags: (.+)$")
  if cap then r.capacity = tonumber(cap); r.maxWeight = tonumber(maxw); r.containerFlags = cflags; return end

  local mult = line:match("^Weight multiplier: (%d+)%%$")
  if mult then r.weightMultiplier = tonumber(mult); return end

  local charges, clevel, spell = line:match("^Has (%d+) charges of level (%d+) '(.+)'%.$")
  if charges then r.spellCharges = { charges = tonumber(charges), level = tonumber(clevel), spell = spell }; return end

  local slevel = line:match("^Level (%d+) spells of: ")
  if slevel then
    local spells = {}
    for s2 in line:gmatch("'([^']*)'") do spells[#spells + 1] = s2 end
    r.spellList = { level = tonumber(slevel), spells = spells }
    return
  end

  local color, liquid = line:match("^It holds (.-)%-colored (.+)%.$")
  if color then r.drinkLiquid = color .. "-colored " .. liquid; return end

  local stat, amt = line:match("^Affects (.+) by (%-?%d+)%.$")
  if stat then
    r.affects = r.affects or {}
    table.insert(r.affects, { stat = stat, amount = tonumber(amt) })
    return
  end
end

-- ---- identify (the spell, full stats) ----
-- First line carries name+type+flags all at once, e.g. "Object 'mushroom'
-- is type food, extra flags none." -- same reasoning as CreatureLore's
-- "Creature: X  Race: Y" first line.

function MyDSL.beginIdentify(line)
  local name, itype, flags = line:match("^Object '(.-)' is type ([%w_]+), extra flags (.+)%.$")
  if not name then return end
  MyDSL.State.identify = {
    name = name, key = itemKey(name), itemType = itype,
    extraFlags = (flags ~= "none" and flags or nil),
    source = "identify",
  }
  if MyDSL._triggers.identifyBody then
    pcall(killTrigger, MyDSL._triggers.identifyBody)
    MyDSL._triggers.identifyBody = nil
  end
  MyDSL._triggers.identifyBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.identify) then return end
    local ln = getCurrentLine()
    if trim(ln) == "" then MyDSL.endIdentify(); return end
    parseItemBodyLine(MyDSL.State.identify, ln)
  end)
end

function MyDSL.endIdentify()
  if MyDSL._triggers.identifyBody then
    pcall(killTrigger, MyDSL._triggers.identifyBody)
    MyDSL._triggers.identifyBody = nil
  end
  local r = MyDSL.State.identify
  if r and MyDSL.ItemLore and MyDSL.ItemLore.merge then
    MyDSL.ItemLore.merge(r)
  end
  -- MyDSL.emit() raises "MyDSL.itemlore.updated" with MyDSL.State.itemlore
  -- as its payload (see MyDSL.emit()'s own implementation) -- set it here
  -- so MyDSL_ItemReference.lua's listener has the just-captured record to
  -- render, same convention MyDSL.State.creaturelore already follows for
  -- CreatureReference. Left set (not nil'd) so a later read still works.
  if r then MyDSL.State.itemlore = r end
  MyDSL.emit("itemlore")
end

-- ---- lore <item> (the skill, chance-based, partial) ----
-- Real shape: "You turn a X every which way." always fires first, THEN
-- either "Can't make heads or tails of it." (fail, terminal, confirmed
-- real 2026-07-16) or a blank line followed by the "Name(s): '...'" /
-- "Type: ... Weight: ... Value: ... Level: ... Material: ...." block.

function MyDSL.beginLoreItem(line)
  MyDSL.State.loreItem = { lines = { line }, pending = true }
  if MyDSL._triggers.loreItemBody then
    pcall(killTrigger, MyDSL._triggers.loreItemBody)
    MyDSL._triggers.loreItemBody = nil
  end
  MyDSL._triggers.loreItemBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.loreItem) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    local r  = MyDSL.State.loreItem
    if r.pending then
      if t == "Can't make heads or tails of it." then
        MyDSL.endLoreItem(false)
      elseif t == "" then
        r.pending = false
      else
        -- Unexpected text between the flavor line and the block --
        -- bail out rather than silently misparsing.
        MyDSL.endLoreItem(false)
      end
      return
    end
    if t == "" then MyDSL.endLoreItem(true); return end
    local name = ln:match("^Name%(s%): '(.+)'$")
    if name then r.name = name; r.key = itemKey(name); return end
    local itype, weight, value, level, material =
      ln:match("^Type: (%a+)%s+Weight: (%d+)%s+Value: (%d+)%s+Level: (%d+)%. Material: (.+)%.$")
    if itype then
      r.itemType = itype; r.weight = tonumber(weight); r.value = tonumber(value)
      r.level = tonumber(level); r.material = material
      return
    end
    parseItemBodyLine(r, ln)
  end)
end

function MyDSL.endLoreItem(success)
  if MyDSL._triggers.loreItemBody then
    pcall(killTrigger, MyDSL._triggers.loreItemBody)
    MyDSL._triggers.loreItemBody = nil
  end
  local r = MyDSL.State.loreItem
  MyDSL.State.loreItem = nil
  if success and r and r.key and MyDSL.ItemLore and MyDSL.ItemLore.merge then
    r.source = "lore"
    MyDSL.ItemLore.merge(r)
    MyDSL.State.itemlore = r
    MyDSL.emit("itemlore")
  end
end


------------------------------------------------------------------------
-- 9q  COMBAT
------------------------------------------------------------------------
-- Always-active triggers (no begin/end block — DSL emits combat lines
-- continuously with no header). Round boundary: MyDSL.char.updated (fires
-- on every gmcp.char_data packet, once per combat round).
--
-- Rewritten 2026-07-05 to port DSL_PNP_Battle.lua's actual display/format
-- logic close to verbatim (per Steven: "make it work like PNP, then discuss
-- the additions"), instead of the from-scratch condensed-table format this
-- module invented earlier. What's ported: the dam_info severity/decoration
-- table, battle_format() token substitution, the per-swing live-window
-- echo (raw sentence + severity score, unconditional for non-miss damage),
-- the round-summary aggregation (calc_dam_verb + battle_format, output to
-- MAIN console gated only by summarize_damage -- NOT by gag_combat, matching
-- PNP exactly), and critically the last_attacker/last_target/last_noun
-- technique for weapon-flag proc attribution (replacing our old pseudo-
-- attacker-row workaround with PNP's actual, more correct fix). What's kept
-- as our own addition on top: persistent multi-fight history/snapshots
-- (active[]/history[], PNP has no such concept -- its battle_data resets
-- every single round) and the Poison proc sequence (no PNP equivalent).

-- ---- Severity/decoration ladder (PNP's exact dam_info table) ---------
-- color/suffix/pre/suf/things mirror PNP's dam_info[verb] = {score, color,
-- suffix, pre, suf, ...} exactly, translated from dsl_color names to decho
-- RGB strings. "things" marks the GHASTLY..UNSPEAKABLE tier, which wraps as
-- "does/do <VERB> things to" instead of "<verb>s <target>".
local DAM_LADDER_ORDER = {
  "miss","scratch","graze","hit","injure","wound","maul","decimate","devastate","maim",
  "MUTILATE","DISEMBOWEL","DISMEMBER","MASSACRE","MANGLE",
  "DEMOLISH","DEVASTATE","OBLITERATE","ANNIHILATE","ERADICATE",
  "GHASTLY","HORRID","DREADFUL","HIDEOUS","INDESCRIBABLE","UNSPEAKABLE",
}

-- Colors below are PNP's exact color_table RGB values (DSL_PNP_Support.lua),
-- confirmed 2026-07-11 per Steven's "match PNP for community recognition"
-- request -- our previous values were our own softer/pastel guesses.
local DSL_LT_RED = "255,0,0"
local DSL_WHITE  = "192,192,192"

-- PNP's GHASTLY..UNSPEAKABLE tier bakes a letter-by-letter alternating
-- dsl_lt_red/dsl_white color effect directly into the decorated verb text
-- (DSL_PNP_Battle.lua's dam_info literals, e.g.
-- "<dsl_lt_red>G<dsl_white>H<dsl_lt_red>A..."), not a single flat color --
-- this is the distinctive visual signature real DSL/PNP players recognize.
-- Our previous implementation had no equivalent at all (flat single color).
local function alternateLetters(word, colorA, colorB)
  local out = {}
  for i = 1, #word do
    out[#out + 1] = "<" .. (i % 2 == 1 and colorA or colorB) .. ">" .. word:sub(i, i)
  end
  return table.concat(out)
end

local DAM_INFO = {
  miss          = { score=0,   color="128,128,0", suffix="es", pre=" ",     suf=" " },
  scratch       = { score=2.5, color="0,179,0",   suffix="es", pre=" ",     suf=" " },
  graze         = { score=6.5, color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  hit           = { score=10.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  injure        = { score=14.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  wound         = { score=18.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  maul          = { score=22.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  decimate      = { score=26.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  devastate     = { score=30.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  maim          = { score=34.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  MUTILATE      = { score=38.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  DISEMBOWEL    = { score=42.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  DISMEMBER     = { score=46.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  MASSACRE      = { score=50.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  MANGLE        = { score=54.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  DEMOLISH      = { score=58.5,color="255,0,0",   suffix="ES", pre=" *** ", suf=" *** " },
  DEVASTATE     = { score=68,  color="255,0,0",   suffix="S",  pre=" *** ", suf=" *** " },
  OBLITERATE    = { score=88,  color="255,0,0",   suffix="S",  pre=" === ", suf=" === " },
  ANNIHILATE    = { score=113, color="255,0,0",   suffix="S",  pre=" >>> ", suf=" <<< " },
  ERADICATE     = { score=138, color="255,0,0",   suffix="S",  pre=" <<< ", suf=" >>> " },
  GHASTLY       = { score=163, color="255,0,0", decorated=alternateLetters("GHASTLY", DSL_LT_RED, DSL_WHITE),             suffix="", pre=" does ", suf=" things to ", things=true },
  HORRID        = { score=188, color="255,0,0", decorated=alternateLetters("HORRID", DSL_LT_RED, DSL_WHITE),              suffix="", pre=" does ", suf=" things to ", things=true },
  DREADFUL      = { score=213, color="255,0,0", decorated=alternateLetters("DREADFUL", DSL_LT_RED, DSL_WHITE),            suffix="", pre=" does ", suf=" things to ", things=true },
  HIDEOUS       = { score=238, color="255,0,0", decorated=alternateLetters("HIDEOUS", DSL_LT_RED, DSL_WHITE),             suffix="", pre=" does ", suf=" things to ", things=true },
  INDESCRIBABLE = { score=263, color="255,0,0", decorated=alternateLetters("INDESCRIBABLE", DSL_LT_RED, DSL_WHITE),       suffix="", pre=" does ", suf=" things to ", things=true },
  UNSPEAKABLE   = { score=276, color="255,0,0", decorated=alternateLetters("UNSPEAKABLE", DSL_LT_RED, DSL_WHITE),         suffix="", pre=" does ", suf=" things to ", things=true },
}

local SEVERITY_SCORE = {}
for word, info in pairs(DAM_INFO) do SEVERITY_SCORE[word] = info.score end

-- Weapon-flag color map (PNP's flag_info table, PNP's exact color_table RGB
-- values as of 2026-07-11). P (Poison) has no PNP equivalent since Poison is
-- our own addition; kept our existing purple.
local FLAG_COLOR = {
  L = "255,255,0", F = "255,0,0", C = "0,255,255",   H = "255,0,255",
  M = "0,0,255",   S = "0,179,0", U = "128,128,128", O = "192,192,192",
  P = "170,68,204",
}

-- ---- battle_format() equivalent (PNP's token-substitution formatter) ----
-- Tokens: %a attacker %t target %n noun %v verb %d damage %h hits %s swings
-- %f flags %r possessive %p punctuation. fields is a table with keys
-- a/t/n/v/d/h/s/f/r/p (any subset; missing ones substitute empty string).
local function battleFormat(fmt, f)
  local subs = {
    ["%%a"] = trim(f.a or ""),            ["%%t"] = trim(f.t or ""),
    ["%%n"] = trim(f.n or ""),             ["%%v"] = trim(f.v or ""),
    ["%%f"] = trim(f.f or ""),             ["%%d"] = trim(tostring(f.d or "")),
    ["%%h"] = trim(tostring(f.h or "")),   ["%%s"] = trim(tostring(f.s or "")),
    ["%%r"] = trim(f.r or ""),             ["%%p"] = trim(f.p or ""),
  }
  for pat, val in pairs(subs) do fmt = fmt:gsub(pat, val) end
  return (fmt:gsub("  ", " "))
end

-- ---- calc_dam_verb() equivalent (round-summary aggregate verb) ----
-- Finds the highest severity tier whose score is <= totalScore, decorated
-- exactly like PNP: the "does"->"do" swap only applies to the You-only
-- special case, and the plural suffix is dropped entirely for You (this is
-- a DIFFERENT, simpler pluralization rule than the per-swing one below --
-- ported as its own thing, matching PNP's two genuinely distinct rules).
local function calcDamVerb(totalScore, isYou)
  local bestScore, bestWord = nil, "miss"
  for _, word in ipairs(DAM_LADDER_ORDER) do
    local info = DAM_INFO[word]
    if info.score <= totalScore and (not bestScore or info.score >= bestScore) then
      bestScore, bestWord = info.score, word
    end
  end
  local info   = DAM_INFO[bestWord]
  local pre    = (isYou and info.pre == " does ") and " do " or info.pre
  local suffix = isYou and "" or info.suffix
  local decoratedWord = info.decorated or ("<" .. info.color .. ">" .. bestWord)
  return trim(pre .. decoratedWord .. suffix .. "<r>" .. info.suf)
end

-- ---- Condition ladder -----------------------------------------------
-- Self-phrased ("You are"/"You have"/"You look") entries added 2026-07-09
-- -- confirmed real bug, TOP PRIORITY item: DSL phrases your OWN condition
-- in second person, a different verb conjugation from the third-person
-- form ("has"->"have", "is"->"are", "looks"->"look"), so neither our old
-- pattern list nor PNP's ever matched it -- self-condition silently never
-- registered. Corpus-confirmed for 3 of 7 rungs ("You are in excellent
-- condition.", "You have a few scratches.", "You have some big nasty
-- wounds and scratches." -- the third one only via its clean third-person
-- form; the self-phrased instances found in the corpus had a garbled
-- "nasty's...And...(18.5)" suffix that turned out to be OUR OWN severity-
-- score decorator leaking into the log, not raw DSL text, so matched on
-- the clean prefix instead of that artifact). The other 4 rungs have no
-- direct self-phrased corpus example (Steven/his characters haven't
-- logged taking that much damage yet) -- inferred via the same
-- consistent grammatical transformation, confirmed consistent across
-- every rung that DOES have direct evidence.
local CONDITION_PATTERNS = {
  { pat = " is in excellent condition",       label = "excellent"    },
  { pat = " are in excellent condition",      label = "excellent"    },
  { pat = " has a few scratches",             label = "few scratches" },
  { pat = " have a few scratches",            label = "few scratches" },
  { pat = " has some small wounds",           label = "small wounds"  },
  { pat = " have some small wounds",          label = "small wounds"  },
  { pat = " has some big nasty wounds",       label = "big wounds"    },
  { pat = " have some big nasty wounds",      label = "big wounds"    },
  { pat = " has quite a few wounds",          label = "quite a few"   },
  { pat = " have quite a few wounds",         label = "quite a few"   },
  { pat = " looks pretty hurt",               label = "pretty hurt"   },
  { pat = " look pretty hurt",                label = "pretty hurt"   },
  { pat = " is in awful condition",           label = "awful"         },
  { pat = " are in awful condition",          label = "awful"         },
}
-- PNP's condition_info percentage-range strings, keyed by our own label
-- (same content, just reordered by label instead of by pattern text).
local CONDITION_PERCENT = {
  excellent = "100%", ["few scratches"] = "90-99%", ["small wounds"] = "75-89%",
  ["big wounds"] = "30-49%", ["quite a few"] = "50-74%",
  ["pretty hurt"] = "15-29%", awful = "0-14%",
}

-- ---- Scope + key helpers --------------------------------------------
local function normalizeKey(name)
  if not name then return "" end
  local s = trim(name:lower())
  s = s:gsub("^a%s+", ""):gsub("^an%s+", ""):gsub("^the%s+", "")
  return trim(s)
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

-- Ordering for a numeric bar-fill estimate (7=full health, 1=near death) --
-- added 2026-07-11 for the Focus/Target window's health bar ("should have
-- healthbars that work on the enemies health message"), same 7 tiers as
-- CONDITION_PATTERNS/CONDITION_PERCENT above.
local CONDITION_ORDER = {
  excellent = 7, ["few scratches"] = 6, ["small wounds"] = 5,
  ["quite a few"] = 4, ["big wounds"] = 3, ["pretty hurt"] = 2, awful = 1,
}

-- MyDSL.getTargetCondition(name) -- public read-only API, same shape as
-- MyDSL.Affects.getRemaining(): returns nil if no live combat-condition
-- data exists for this name (never fought this session, or DSL hasn't
-- sent a condition line yet), otherwise (label, percentRangeText, order).
-- This is the REAL "enemy health message" data Steven asked for -- not
-- creaturelore's static "base health" stat, which is a fixed per-species
-- number, not the current fight's damage state.
function MyDSL.getTargetCondition(name)
  local key = normalizeKey(name)
  local entry = MyDSL.State.combat and MyDSL.State.combat.active and MyDSL.State.combat.active[key]
  if not entry or not entry.target_condition or entry.target_condition == "unknown" then
    return nil
  end
  local label = entry.target_condition
  return label, CONDITION_PERCENT[label], CONDITION_ORDER[label]
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

-- ---- parseCombatDamageLine (PNP's handle_damage(), close to verbatim) ----
local FALSE_POSITIVE_GUARDS = {"You gain", "has big nasty", "Affects", "has some small", "Wimpy"}
local NOUN_FLAG_MAP = { ["life drain"] = "H", ["shocking bite"] = "L" }  -- our own addition, kept

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
  punct    = punct or "."

  local info = DAM_INFO[verb]
  if not info then return end

  local aKey = (attacker == "You" or attacker:lower() == "you") and "you" or normalizeKey(attacker)
  local tKey = (target:lower() == "you") and "you" or normalizeKey(target)
  -- No relevance filter, matching PNP: every combat line DSL shows you gets
  -- tracked, relying on DSL's own vicinity-based broadcast rules rather
  -- than filtering client-side (confirmed 2026-07-05).

  -- ---- Per-swing decorated verb (PNP's handle_damage construction) ----
  -- Pluralization here keys off whether a weapon noun is present at all
  -- (true for every normal hit; the "does...things to" tier has no noun,
  -- but its own suffix is always "" anyway) -- this is a different,
  -- simpler rule than calc_dam_verb's You-based one below, ported as its
  -- own thing to match PNP's actual (slightly redundant) two rules.
  local damVerb = info.decorated or ("<" .. info.color .. ">" .. verb)
  if attacker ~= "You" or noun ~= "" then damVerb = damVerb .. info.suffix end
  damVerb = info.pre .. damVerb .. "<r>" .. info.suf

  local possessive, displayNoun = "", noun
  if noun ~= "" then
    displayNoun = " " .. noun
    possessive = (attacker == "You") and "r" or "'s"
  end

  -- Live Combat-window echo -- every non-miss swing, unconditional, raw
  -- sentence + severity score in brackets. Matches PNP's battle_console
  -- cecho exactly: misses/evasion/procs never appear here at all, only
  -- real damage.
  if verb ~= "miss" then
    -- No separator between damVerb and target -- damVerb's own trailing
    -- info.suf (e.g. " " or " *** ") already provides the space, matching
    -- PNP's exact concatenation (adding one here would double it).
    local swingLine = " " .. attacker .. possessive .. displayNoun .. damVerb .. target .. punct .. " [" .. info.score .. "]\n"
    if MyDSL.CombatView and MyDSL.CombatView.appendSwing then
      MyDSL.CombatView.appendSwing(swingLine)
    end
  end

  -- ---- Main-console gag/show decision (PNP's exact boolean formula) ----
  local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}
  local showDamage = (cfg.show_miss or verb ~= "miss")
    and (cfg.show_damage or (cfg.show_damage_by_me and aKey == "you") or (cfg.show_damage_to_me and tKey == "you"))
  if showDamage then
    local str = battleFormat(cfg.dam_format or "%a%r %n %v %t (%d)", {
      a = attacker, r = possessive, n = noun, v = damVerb, t = target, d = info.score, p = punct,
    })
    selectCurrentLine()
    replace("")
    decho(str)
  elseif noun ~= "trip" and noun ~= "kicked dirt" then
    deleteLine()
  end

  -- ---- Accumulation ----
  -- round_data: PNP's battle_data equivalent, reset every round.
  -- active[]: our own persistent-fight-history addition, layered on top --
  -- PNP has no concept of "this fight, start to finish" at all.
  local nounKey = noun:lower()
  local score = info.score

  local entry = ensureActive(tKey, target)
  local ba    = entry.by_attacker
  ba[aKey]        = ba[aKey]        or {}
  ba[aKey][nounKey] = ba[aKey][nounKey] or { swings=0, hits=0, misses=0, score_total=0, flags={} }
  local nd = ba[aKey][nounKey]
  nd.swings = nd.swings + 1
  if verb == "miss" then
    nd.misses = nd.misses + 1
  else
    nd.hits        = nd.hits + 1
    nd.score_total = nd.score_total + score
  end

  -- Compound-noun proc flags (our own addition, kept from the earlier fix).
  local impliedFlag = NOUN_FLAG_MAP[nounKey]
  if impliedFlag and verb ~= "miss" then
    nd.flags[impliedFlag] = (nd.flags[impliedFlag] or 0) + 1
    if impliedFlag == "H" and aKey == "you" then
      MyDSL.State.combat.rage.vamp = MyDSL.State.combat.rage.vamp + 2.5
    end
  end

  local rd    = MyDSL.State.combat.round_data
  local rdKey = aKey .. "→" .. tKey .. "→" .. nounKey
  rd[rdKey] = rd[rdKey] or { attacker=aKey, target=tKey, noun=nounKey, score=0, swings=0, hits=0 }
  rd[rdKey].score  = rd[rdKey].score + score
  rd[rdKey].swings = rd[rdKey].swings + 1
  if verb ~= "miss" then rd[rdKey].hits = rd[rdKey].hits + 1 end

  -- PNP's last_attacker/last_target/last_noun technique: weapon-flag procs
  -- (parseCombatProcLine below) attach to whichever combatant/noun this
  -- damage line involved, instead of trying to resolve identity from the
  -- proc line's own (often weapon-named) text.
  MyDSL.State.combat.last_attacker = aKey
  MyDSL.State.combat.last_target   = tKey
  MyDSL.State.combat.last_noun     = nounKey

  if tKey == "you" then
    MyDSL.State.combat.rage.damage = MyDSL.State.combat.rage.damage + score
  end
end

-- ---- parseCombatAvoidLine (PNP's handle_evasion(), close to verbatim) ----
-- Two call shapes:
--   (evader, verb, attacker) -- dodge/parry/block triggers, PNP-derived PCRE
--     capture groups. attacker is the literal word "your" when you're the
--     one whose attack got avoided, otherwise a "Name's" possessive.
--   (line)                   -- sense triggers, still whole-line Lua-pattern
--     parsed (unchanged; not part of the PNP evasion-trigger port).
-- Note: evasion never appears in the Combat window at all, matching PNP --
-- handle_evasion never touches battle_console, only the main-console gag.
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
  -- No relevance filter, matching PNP.

  local entry = ensureActive(eKey, evader)
  entry.by_attacker[aKey] = entry.by_attacker[aKey] or {}
  entry.by_attacker[aKey]["(evade)"] = entry.by_attacker[aKey]["(evade)"]
    or { swings=0, hits=0, misses=0, score_total=0, flags={} }
  entry.by_attacker[aKey]["(evade)"].swings = entry.by_attacker[aKey]["(evade)"].swings + 1

  local rd    = MyDSL.State.combat.round_data
  local rdKey = aKey .. "→" .. eKey .. "→(evade)"
  rd[rdKey] = rd[rdKey] or { attacker=aKey, target=eKey, noun="(evade)", score=0, swings=0, hits=0 }
  rd[rdKey].swings = rd[rdKey].swings + 1

  -- Gag decision (PNP's exact formula).
  local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}
  if (cfg.gag_combat or cfg.gag_non_damage or not cfg.show_evade) then deleteLine() end
end

-- ---- parseCombatConditionLine (PNP's handle_condition(), close to verbatim) ----
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
  if entry then entry.target_condition = label end  -- our own per-target addition

  -- PNP's battle_data.screen_condition/window_condition equivalent -- a
  -- single pending note, flushed alongside the next round summary.
  -- "has" inserted 2026-07-16, per Steven ("missing the word 'has'
  -- between mob name and state") -- confirmed live via log/*.html:
  -- "A gray wolf cub big wounds [30-49%]" read with no connecting verb
  -- at all between name and label.
  local pct = CONDITION_PERCENT[label] or ""
  MyDSL.State.combat.pending_condition = {
    screen = "<255,68,255>" .. name .. "<r> has " .. label .. (pct ~= "" and (" [" .. pct .. "]") or ""),
    window = "<255,68,68>" .. name .. "<r> [" .. pct .. "]\n",
  }

  -- Gag decision -- was PNP's exact formula (`(not show_condition) and
  -- ((gag_combat or gag_non_damage) and (not summarize_damage))`), which
  -- never deletes the raw line in condensed mode (summarize_damage=true)
  -- specifically because the round-flush handler below is about to decho
  -- its own colored copy of the same condition info -- confirmed this is
  -- PNP's own original behavior too (DSL_PNP_Battle.lua, identical
  -- formula), not a MyDSL-introduced bug, but Steven reported it live as
  -- an unwanted duplicate ("one we create and one from the game... if
  -- its just a duplicate line lets not duplicate it") and asked for it
  -- fixed here specifically, diverging from PNP on this one point.
  -- Fixed 2026-07-16: added summarize_damage to the OR clause, so the raw
  -- line is now deleted in condensed mode too (only our own recap shows).
  -- Raw mode is unaffected (gag_combat/gag_non_damage/summarize_damage
  -- all false there, so this stays false and nothing is deleted -- the
  -- one real condition line shows, same as always). show_condition still
  -- overrides everything and forces the raw line to stay, per its own
  -- documented purpose.
  local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}
  if (not cfg.show_condition) and (cfg.gag_combat or cfg.gag_non_damage or cfg.summarize_damage) then
    deleteLine()
  end
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
  -- Dedicated death event -- added 2026-07-11, per Steven ("then clear
  -- target, or populate with next in room mob from scan" once the
  -- current Focus target dies). Raised independent of whether
  -- snapshotFight() found an active-combat entry -- our own damage
  -- tracking might never have started for this specific kill (e.g.
  -- someone else landed the killing blow), but the creature still died.
  -- Any module that cares about "did THIS specific creature just die"
  -- needs the raw key/name, not the aggregated fight-history snapshot
  -- MyDSL.combat.ended carries -- that event also fires for flee/rescue,
  -- not just death, so it can't distinguish the two.
  raiseEvent("MyDSL.combat.died", { key = tKey, name = trim(name) })
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

-- ---- parseCombatProcLine (PNP's handle_flag(), close to verbatim) ----
-- flagCode: C=Frost F=Flaming L=Shocking H=Vampiric S=Stunning M=ManaDrain O=Holy U=Unholy P=Poison
--
-- Rewritten 2026-07-05 to use PNP's actual technique: don't try to resolve
-- identity from the proc line's own text (frequently a weapon name, not a
-- person -- e.g. "A grand arcanium hoopak draws life from Kien.") -- just
-- attach to whichever attacker/target/noun the most recent damage line
-- involved (MyDSL.State.combat.last_attacker/last_target/last_noun, set at
-- the end of parseCombatDamageLine). This replaces the old pseudo-
-- attacker-row workaround entirely with PNP's actual, more correct fix --
-- confirmed in DSL_PNP_Battle.lua's handle_flag(), which does exactly this.
function MyDSL.parseCombatProcLine(flagCode)
  -- PNP's drowning/freeze false-positive guard.
  if flagCode == "C" and getCurrentLine() == "The panic of drowning freezes you in your tracks!" then
    return
  end

  local combat = MyDSL.State.combat
  local aKey, tKey, noun = combat.last_attacker, combat.last_target, combat.last_noun
  if not (aKey and tKey and noun) then return end

  if flagCode == "H" and aKey == "you" then
    combat.rage.vamp = combat.rage.vamp + 2.5
  end

  local entry = combat.active[tKey]
  if entry then
    local nd = entry.by_attacker[aKey] and entry.by_attacker[aKey][noun]
    if nd then nd.flags[flagCode] = (nd.flags[flagCode] or 0) + 1 end
  end

  local rdEntry = combat.round_data[aKey .. "→" .. tKey .. "→" .. noun]
  if rdEntry then
    rdEntry.flags = rdEntry.flags or {}
    rdEntry.flags[flagCode] = (rdEntry.flags[flagCode] or 0) + 1
  end

  -- Gag decision (PNP's exact formula) -- Stunning (S) is special-cased to
  -- always show regardless of show_flag, matching PNP exactly.
  local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}
  if (cfg.gag_combat or cfg.gag_non_damage or not cfg.show_flag) and flagCode ~= "S" then
    deleteLine()
  end
end


------------------------------------------------------------------------
-- 9r  EQUIPMENT
------------------------------------------------------------------------
-- Ported 2026-07-07 from DSL_PNP_Character.equipment.lua (PNP/EMCO
-- cannibalization pass, Phase E) -- passive capture only. PNP's own
-- version also has a useItem() convenience that SENDS commands
-- (wear/wield/get) -- deliberately NOT ported: this file's own header
-- says "Never sends commands to the game", and CLAUDE.md reserves
-- user-initiated game commands for a display-module button (like
-- TargetView's action buttons), not Layer 1. A future EquipmentView
-- could add an interactive "use equipped item" button if wanted.
--
-- Real format confirmed against 154 unique lines in the clean corpus:
--   "You are using:"
--   "<used as light>     (Blue Aura) (Glowing) a Guiding jewel -[30] ..."
--   "<worn on finger>    (nothing)"
--   "<worn about body>   a long robe -[30] 7/7/7/3 (W)-1S,2D ..."
-- Slot descriptions actually seen: "floating nearby", "held", "secondary
-- weapon", "sheathed", "used as light", "wielded", "worn about
-- body/waist", "worn around neck/wrist", "worn as quiver/shield",
-- "worn on arms/feet/finger/hands/head/legs/torso" -- matches PNP's own
-- expected slot list. finger/neck/wrist auto-number to 1/2 (you can wear
-- two), same as PNP. Item text can itself contain parens after any
-- leading flag-parens (weapon/armor stat blocks like "(W)-1S,2D (R)
-- 4Con,2H") -- the trigger only captures broad boundaries (slot / rest
-- of line), the flags-vs-item split happens in Lua below, where it's
-- just stripping consecutive leading "(x) " groups -- avoids relying on
-- PCRE backtracking to split two overlapping-charset capture groups the
-- way PNP's own regex does.

local equipBlock = {}
local ringIdx, neckIdx, wristIdx = 0, 0, 0

-- Same filler words PNP strips, same order -- confirmed via the log-
-- corpus test above that this normalizes every real slot string seen.
local EQUIP_FILLER_WORDS = { "worn ", "used ", "as ", "on ", "around ", "about ", " nearby", " weapon" }

local function normalizeEquipSlot(raw)
  local slot = raw
  for _, w in ipairs(EQUIP_FILLER_WORDS) do
    slot = slot:gsub(w, "", 1)
  end
  slot = trim(slot)
  if slot == "finger" then ringIdx = ringIdx + 1; slot = slot .. ringIdx end
  if slot == "neck"   then neckIdx = neckIdx + 1; slot = slot .. neckIdx end
  if slot == "wrist"  then wristIdx = wristIdx + 1; slot = slot .. wristIdx end
  return slot
end

function MyDSL.beginEquip()
  equipBlock = {}
  ringIdx, neckIdx, wristIdx = 0, 0, 0
  if MyDSL._triggers.equipBody then
    pcall(killTrigger, MyDSL._triggers.equipBody)
    MyDSL._triggers.equipBody = nil
  end
  MyDSL._triggers.equipBody = tempRegexTrigger(".*", function()
    local ln = getCurrentLine()
    if trim(ln) == "" then MyDSL.endEquip(); return end
    local rawSlot, rest = ln:match("^<([a-z ]+)>%s*(.+)$")
    if rawSlot and MyDSL.parseEquipLine then MyDSL.parseEquipLine(rawSlot, rest) end
  end)
end

function MyDSL.parseEquipLine(rawSlot, rest)
  local slot = normalizeEquipSlot(rawSlot)
  if rest == "(nothing)" then
    equipBlock[slot] = { item = nil, flags = {} }
    return
  end
  local flags = {}
  local remaining = rest
  while true do
    local flag, tail = remaining:match("^%((.-)%)%s*(.*)$")
    if not flag then break end
    flags[#flags + 1] = flag
    remaining = tail
  end
  local itemName = trim(remaining)
  equipBlock[slot] = { item = itemName, flags = flags }

  -- Hover/click on the equipment line's own item-name text -- added
  -- 2026-07-16 for Layer 4's item reference. "Move text, don't invent
  -- it": uses selectString()+setLink() (same technique already proven in
  -- MyDSL_AffectsView.lua's applyLinks(), specifically to avoid the real
  -- Mudlet limitation that reconstructing a line via decho/cecho would
  -- discard the game's own ANSI coloring) to attach a hover tooltip +
  -- click-to-open-Item-Reference directly onto the already-printed,
  -- untouched equipment line in the main console -- never deletes or
  -- reprints anything.
  if itemName ~= "" and setLink and selectString then
    local key = itemName:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
    local rec = MyDSL.ItemLore and MyDSL.ItemLore.get and MyDSL.ItemLore.get(key)
    local hint = "Click for Item Reference"
    if rec then
      if rec.itemType then hint = hint .. " -- " .. rec.itemType end
      if rec.damageDice then
        hint = hint .. " -- " .. rec.damageDice .. " (avg " .. tostring(rec.damageAvg) .. ")"
      end
      if rec.armorClass then
        local ac = rec.armorClass
        hint = hint .. string.format(" -- AC %s/%s/%s/%s",
          tostring(ac.pierce), tostring(ac.bash), tostring(ac.slash), tostring(ac.magic))
      end
    end
    local cmd = string.format(
      'if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.render("%s"); MyDSL.ItemReference.show() end',
      itemName:gsub('"', '\\"'))
    local okSel, selected = pcall(selectString, "main", itemName, 1)
    if okSel and selected then
      pcall(setLink, "main", cmd, hint)
    end
  end
end

function MyDSL.endEquip()
  if MyDSL._triggers.equipBody then
    pcall(killTrigger, MyDSL._triggers.equipBody)
    MyDSL._triggers.equipBody = nil
  end
  update("equipment", { slots = equipBlock })
  equipBlock = {}
end


------------------------------------------------------------------------
-- 9q  INVENTORY  ("i"/"inv")
------------------------------------------------------------------------
-- Added 2026-07-16, per Steven ("you should be able to hover over
-- inventory items not just equipment"). Didn't exist at all before this --
-- confirmed via grep. Same begin/body/end shape as equip capture above,
-- fires on "You are carrying:", ends on the first blank line. Each line
-- is "( N) [tags] name" (count prefix omitted, i.e. just leading
-- whitespace, when count is 1) -- confirmed via
-- log/2026-07-16#17-23-54.html.

local inventoryBlock = {}

function MyDSL.beginInventory()
  inventoryBlock = {}
  if MyDSL._triggers.inventoryBody then
    pcall(killTrigger, MyDSL._triggers.inventoryBody)
    MyDSL._triggers.inventoryBody = nil
  end
  MyDSL._triggers.inventoryBody = tempRegexTrigger(".*", function()
    local ln = getCurrentLine()
    if trim(ln) == "" then MyDSL.endInventory(); return end
    if MyDSL.parseInventoryLine then MyDSL.parseInventoryLine(ln) end
  end)
end

function MyDSL.parseInventoryLine(line)
  local count, rest = line:match("^%(%s*(%d+)%)%s+(.+)$")
  if not rest then
    rest = line:match("^%s+(.+)$")
    count = "1"
  end
  if not rest then return end
  local flags = {}
  local remaining = rest
  while true do
    local flag, tail = remaining:match("^%((.-)%)%s*(.*)$")
    if not flag then break end
    flags[#flags + 1] = flag
    remaining = tail
  end
  local itemName = trim(remaining)
  if itemName == "" then return end
  local key = itemName:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  inventoryBlock[key] = { item = itemName, flags = flags, count = tonumber(count) or 1 }
end

function MyDSL.endInventory()
  if MyDSL._triggers.inventoryBody then
    pcall(killTrigger, MyDSL._triggers.inventoryBody)
    MyDSL._triggers.inventoryBody = nil
  end
  update("inventory", { items = inventoryBlock })
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

-- Rare edge case, found live 2026-07-12 (Steven: "Rain falls steadily
-- from the clouded sky. and a cold gentle breeze blows in from the
-- north."): DSL occasionally joins the precipitation and wind clauses
-- with a period instead of a comma, splitting what's normally one
-- sentence into two lines -- the second starting with a lowercase
-- "and", which the broad trigger above (requires a capital first
-- letter) never matches, silently dropping the wind info. Zero
-- historical occurrences of this exact shape anywhere in the full log/
-- archive (only the standard comma-joined form, 53/53 samples) --
-- genuinely rare, but real, so worth a narrow dedicated catch. Routes to
-- extractWindClause() directly (not parseWeatherLine(), which would
-- overwrite the precipitation description that was likely just captured
-- moments before from the first line) so only windDescription updates.
MyDSL._triggers.weatherWindContinuation = tempRegexTrigger(
  "^and (a \\w+ \\w+ (breeze|wind) blows in from the \\w+|the wind is calm)",
  function()
    local ln = getCurrentLine()
    local clause = MyDSL.extractWindClause and MyDSL.extractWindClause(ln)
    if clause then update("weather", { windDescription = clause }) end
  end
)


------------------------------------------------------------------------
-- Scan triggers
------------------------------------------------------------------------
-- Two permanent triggers: one for "scan" (all-directions), one for
-- "scan <dir>" (directional). Both call beginScan() which resets
-- State.scan and installs the body catch-all.

-- Hardened 2026-07-08 (same bug class as the Exits-line fix above):
-- corpus check found 9 of 412 real occurrences have a leading double-space
-- ("  Looking around you see:") that the old exact anchor missed.
MyDSL._triggers.scanAround = tempRegexTrigger(
  "^\\s*Looking around you see:$",
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

-- Room's own "[Exits: ...]" line -- always immediately precedes a `look`'s
-- (or any room reprint's, e.g. after movement) content listing. See the
-- beginLook() comment above for why this anchor was picked over a fixed
-- header phrase.
-- FIX 2026-07-08: this anchor never fired, ever -- confirmed via corpus
-- grep across every single "Exits:" line in the DSL2-era logs (172
-- distinct room/exit combos, 100% of them), the real line always has one
-- leading space before "[Exits:" (e.g. " [Exits: north east south west
-- ]"), which the old "^\[Exits: ..." pattern's start anchor rejects. This
-- means beginLook() has never actually been triggered by real gameplay --
-- every fix made to the capture body logic today was real but moot, since
-- capture never started in the first place. My emulation testing missed
-- this because it called MyDSL.beginLook() directly, never exercising
-- this trigger's own pattern against real text.
-- Round 4, found via a live debug trace 2026-07-08 (see beginLook()'s
-- catch-all comment for the actual root cause -- a self-retrigger on this
-- same anchor line, not this trigger's own pattern).
MyDSL._triggers.lookExits = tempRegexTrigger(
  "^\\s*\\[Exits: .*\\]\\s*$",
  function()
    if MyDSL and MyDSL.beginLook then MyDSL.beginLook() end
  end
)

-- "Players near you:" -- fires independently of scan's own catch-all (which
-- only uses this line to know scan has ended, doesn't gag/route it itself).
MyDSL._triggers.playersNearStart = tempRegexTrigger(
  "^Players near you:$",
  function()
    if MyDSL and MyDSL.beginPlayersNear then MyDSL.beginPlayersNear() end
  end
)

-- REAL BUG, found live 2026-07-12 via log-corpus grep (Steven: "something
-- broke the autowhere alias and it now displays none instead of gaging
-- it"): confirmed against log/2026-07-12#09-01-16.html that DSL's `where`
-- command has TWO distinct response shapes -- the "Players near you:"
-- header + name/room lines (handled above) when other players ARE
-- nearby, but a bare, standalone "None" line with NO header at all when
-- nobody is. The trigger above only ever matches the header, so the
-- no-one-nearby case was never captured/routed -- it fell straight
-- through into the main console untouched every ~20s (Steven's own
-- autowhere alias, not part of this project, sends `where` on that
-- cadence). Not actually specific to any one room, despite how it first
-- looked live -- confirmed via corpus grep this fires constantly
-- whenever no other player happens to be nearby, room-independent.
-- Same move-not-duplicate handling as the header case: MOVES the literal
-- "None" line into MyDSL_PlayersNear (clearing stale names first) rather
-- than inventing different text, consistent with "move text, don't
-- replace it." Matched only as the ENTIRE line content (`^None$`), not a
-- substring, to minimize collision risk with any other real DSL text
-- that might legitimately be the single word "None" in a different
-- context.
MyDSL._triggers.playersNearEmpty = tempRegexTrigger(
  "^None$",
  function()
    if not (MyDSL and MyDSL.Route) then return end
    MyDSL.Route.clear("MyDSL_PlayersNear")
    selectCurrentLine()
    copy()
    MyDSL.Route.players(nil)
    deleteLine()
  end
)

------------------------------------------------------------------------
-- Pos'n (physical position) -- real-time text triggers
------------------------------------------------------------------------
-- Added 2026-07-12, per Steven ("liveview pos'n doesnt update on
-- changing without score, it should update with the gmcp... check
-- sibling profiles and other liveview scripts, this was active once
-- before and update the character position as it happened"). LiveView's
-- Pos'n field was sourced only from score.posn, a text-parsed field that
-- only refreshes when `score` is actually run -- exactly the bug
-- reported.
--
-- Found the real prior implementation in
-- "../Dark & Shattered Lands - PNP/PNP/DSL_PNP_Statusbar.posn.lua":
-- real-time text triggers on the server's own first-person confirmation
-- lines ("You stand up.", "You sit down.", etc.), not GMCP polling --
-- genuinely more precise than score, since it updates the instant the
-- position actually changes rather than waiting for the next `score`.
--
-- NOT ported verbatim -- PNP's own "stand" pattern
-- (`^You (?:go to )?(stand|rest|sit|sleep|mount|dismount)`, no end
-- anchor) would be a real bug here: confirmed via log-corpus grep that
-- many DSL2 room descriptions independently start with "You stand on/in
-- the..." (second-person descriptive prose, unrelated to any stand
-- action -- confirmed it also appears after a plain `look`), which that
-- pattern would have matched and misfired on constantly. Rebuilt against
-- the actual exact confirmation sentences, confirmed real via corpus
-- grep across the full log/ archive: "You stand up.", "You sit down.",
-- "You rest.", "You go to sleep.", "You are already standing.", "You
-- are already sitting down.", "You wake and stand up.", "You wake up
-- and start resting.", "You mount <name>.", "You dismount.", "You
-- (slowly float|float gently) to the ground." (landing). "You stop
-- resting." kept from PNP (its own "stop resting -> back to sitting"
-- case) but NOT corpus-confirmed for DSL2 specifically -- low collision
-- risk (a specific, unambiguous full sentence), flagged in TODO.md like
-- the CharacterAssist disarm patterns were.
--
-- Flying is handled separately, via GMCP's is_flying in the char_data
-- handler above (real, confirmed field, updates instantly -- no text
-- trigger needed; directly confirmed live via a real session transcript
-- showing "You stand up." -> "c fly" -> "Your feet rise off the
-- ground." -> is_flying flipping to true in the very same capture).
--
-- setPosn(value) does NOT trust a trigger's text match as the final
-- word -- per Steven ("id prefer that the trigger patterns be the point
-- to check gmcp, not make its own decision to avoid the issues with
-- room descriptions or other cross contamination. so stand trigger
-- fires, check gmcp for the change and update"). GMCP's char_data has no
-- direct Standing/Sitting/Resting/Sleeping equivalent (only the boolean
-- flags already captured above -- is_flying/is_riding/is_fighting), so
-- "check GMCP" concretely means: is_flying is the one flag that actually
-- competes with a text-implied position, and it's authoritative -- a
-- trigger firing (whether from a deliberate action or, despite the
-- anchoring above, some future unanticipated text collision) can never
-- downgrade a character GMCP still confirms is flying. Every trigger
-- below reports what the text implied; setPosn() is the single place
-- that reconciles it against real GMCP state before committing.
local function setPosn(textImpliedValue)
  local char = MyDSL.State.char or {}
  local value = textImpliedValue
  if char.is_flying and value ~= "Flying" then
    value = "Flying"
  end
  update("char", { posn = value })
end

MyDSL._triggers.posnStandUp      = tempRegexTrigger([[^You stand up\.$]],                              function() setPosn("Standing") end)
MyDSL._triggers.posnSitDown      = tempRegexTrigger([[^You sit down\.$]],                               function() setPosn("Sitting") end)
MyDSL._triggers.posnRest         = tempRegexTrigger([[^You rest\.$]],                                   function() setPosn("Resting") end)
MyDSL._triggers.posnSleep        = tempRegexTrigger([[^You go to sleep\.$]],                            function() setPosn("Sleeping") end)
MyDSL._triggers.posnAlreadyStand = tempRegexTrigger([[^You are already standing\.$]],                   function() setPosn("Standing") end)
MyDSL._triggers.posnAlreadySit   = tempRegexTrigger([[^You are already sitting down\.$]],                function() setPosn("Sitting") end)
MyDSL._triggers.posnWakeStand    = tempRegexTrigger([[^You wake and stand up\.$]],                      function() setPosn("Standing") end)
MyDSL._triggers.posnWakeRest     = tempRegexTrigger([[^You wake up and start resting\.$]],              function() setPosn("Resting") end)
MyDSL._triggers.posnMount        = tempRegexTrigger([[^You mount .+\.$]],                                function() setPosn("Mounted") end)
MyDSL._triggers.posnDismount     = tempRegexTrigger([[^You dismount\.$]],                                function() setPosn("Standing") end)
-- Landing is the one case that must bypass the is_flying override above
-- (it's the trigger THAT clears Flying) -- confirmed live (same
-- transcript cited above) that GMCP's is_flying flips false slightly
-- before this line prints, so by the time it fires char.is_flying is
-- already false and setPosn()'s normal check passes "Standing" through
-- untouched; no special-casing needed here.
MyDSL._triggers.posnLand         = tempRegexTrigger([[^You (?:slowly float|float gently) to the ground\.$]], function() setPosn("Standing") end)
MyDSL._triggers.posnStopRest     = tempRegexTrigger([[^You stop resting\.$]],                            function() setPosn("Sitting") end)

------------------------------------------------------------------------
-- Wimpy -- real-time text trigger, same shape as Pos'n above
------------------------------------------------------------------------
-- Added 2026-07-12, per Steven ("wimpy should update when its changed as
-- well and gmcp, or how it collects info. but also with the manual
-- wimpy command"). MyDSL.DB.score.wimpy (MyDSL_DataBridge.lua) already
-- prefers char.wimpy (GMCP) over the text-parsed score.wimpy fallback --
-- that priority was already correct -- but nothing fed char.wimpy in
-- real time; it only refreshed whenever the next unrelated gmcp.char_data
-- packet happened to arrive with an updated value. Unlike Pos'n this
-- doesn't need a GMCP cross-check (no ambiguous states to reconcile,
-- just a number) -- confirmed real, exact response text via corpus grep,
-- identical for both a bare "wimpy" query and "wimpy <n>" to actually
-- set it: "Wimpy set to N hit points." Captures the number directly from
-- the confirmation line itself rather than guessing it.
MyDSL._triggers.wimpySet = tempRegexTrigger(
  [[^Wimpy set to (\d+) hit points\.$]],
  function()
    local n = tonumber(matches[2])
    if n then update("char", { wimpy = n }) end
  end
)

------------------------------------------------------------------------
-- Dragon Vitality -- text trigger on the `stat` command's output
------------------------------------------------------------------------
-- Added 2026-07-12, per Steven ("dragon vitality stat next for dragons/
-- qinrathaz only, see help files for dragon vitality if needed at it
-- below con in the stats window"). DSL_Helpfiles/dragons.txt confirms:
-- "Dragons will lose vitality with every death though not alterforms.
-- When a dragon's vitality is gone, the dragon will permanently die" --
-- a dragon-only permadeath-countdown stat, not present for any other
-- race. Real format confirmed from Steven's own cecho breadcrumb in
-- log/2026-07-07#20-17-54.html (typed `stat` on Qinrathaz):
-- "Str: 72(80)  Int: 60(72)  Wis: 60(72)  Dex: 60(60)  Con: 66(82)
-- Vit: 20" -- captures just the trailing "Vit: N", which only appears
-- at all for dragon characters (confirmed no "Vit:" field anywhere in
-- non-dragon corpus samples), so this naturally never fires/populates
-- for anyone else -- no race check needed. Character-bound via
-- update("char", ...), same persistence as posn/wimpy, since Steven
-- noted this can only really be confirmed by watching it live (changes
-- on a PK death), not re-testable on demand -- stale-but-persisted beats
-- blank between sessions.
MyDSL._triggers.vitalitySet = tempRegexTrigger(
  [[Vit:\s*(\d+)\s*$]],
  function()
    local n = tonumber(matches[2])
    if n then update("char", { vitality = n }) end
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

MyDSL._triggers.equipStart = tempRegexTrigger(
  "^You are using:$",
  function()
    if MyDSL and MyDSL.beginEquip then
      MyDSL.beginEquip()
    end
  end
)

MyDSL._triggers.inventoryStart = tempRegexTrigger(
  "^You are carrying:$",
  function()
    if MyDSL and MyDSL.beginInventory then
      MyDSL.beginInventory()
    end
  end
)

------------------------------------------------------------------------
-- Identify / item-lore triggers
------------------------------------------------------------------------
-- Fires on "Object '<name>' is type ..." -- the first line of any
-- `c identify <keyword>` block. Body lines handled by the catch-all
-- installed inside beginIdentify().
MyDSL._triggers.identifyStart = tempRegexTrigger(
  "^Object '",
  function()
    if MyDSL and MyDSL.beginIdentify then
      MyDSL.beginIdentify(getCurrentLine())
    end
  end
)

-- Fires on "You turn a <item> every which way." -- the flavor line every
-- `lore <keyword>` attempt prints regardless of success/fail.
MyDSL._triggers.loreItemStart = tempRegexTrigger(
  "^You turn .+ every which way\\.$",
  function()
    if MyDSL and MyDSL.beginLoreItem then
      MyDSL.beginLoreItem(getCurrentLine())
    end
  end
)


------------------------------------------------------------------------
-- Combat triggers (always-active — no begin/end block)
------------------------------------------------------------------------
-- Gag/show decisions for damage/evasion/condition/proc all moved INTO
-- their respective parse functions as of 2026-07-05 (matching PNP, where
-- handle_damage/handle_evasion/handle_condition/handle_flag each make
-- their own gag decision) -- trigger bodies below just call the parser.

-- ---- Unified damage trigger (PNP-derived PCRE, one trigger for all damage types)
-- Deliberately `^`-anchored directly to the attacker name, NOT tolerant of
-- a leading "[ The Center of the Coliseum ]"/"[ Southern Coliseum Wall ]"
-- location-broadcast prefix. This was briefly "fixed" 2026-07-09 to accept
-- that prefix (real, confirmed via sibling-profile logs -- every combat
-- line fought in the Coliseum carries one), but reverted same-day per
-- Steven: Coliseum combat (and the Algoron Combat League event) is
-- explicitly OUT of scope for this regular single-target combat tracker --
-- it's planned as its own later module (a large window with 4 floating
-- cardinal-direction sub-windows matching the Coliseum's wall echoes).
-- The strict anchor is what naturally excludes Coliseum broadcasts from
-- this tracker today, so it stays as-is on purpose -- don't "fix" this
-- again without building/coordinating with that module first.
local DAMAGE_VERBS = "miss|scratch|graze|hit|injure|wound|maul|decimate|devastate|maim|MUTILATE|DISEMBOWEL|DISMEMBER|MASSACRE|MANGLE|DEMOLISH|DEVASTATE|OBLITERATE|ANNIHILATE|ERADICATE|GHASTLY|HORRID|DREADFUL|HIDEOUS|INDESCRIBABLE|UNSPEAKABLE"
MyDSL._triggers.combatDamage = tempRegexTrigger(
  "^(You|[\\w\\-\\s,']+?)(?:(?<=You)r|'s)?(?:\\s?((?<=Your )[\\w\\s]+?|(?<='s )[\\w\\s]+?|))(?: do[es]*| [\\>\\<\\=\\*]+|) ("
    .. DAMAGE_VERBS .. ")[esES]*(?: things to| [\\>\\<\\=\\*]+|) ([\\w\\-\\s,']+)([\\.\\.!]+)$",
  function()
    if MyDSL and MyDSL.parseCombatDamageLine then
      MyDSL.parseCombatDamageLine(matches[2], matches[3], matches[4], matches[5], matches[6])
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
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end end)
MyDSL._triggers.combatParry = tempRegexTrigger(
  "(You|[\\w\\-\\,\\s']+) (parry|parries) (your|[\\w\\-\\,\\s']+) attack\\.$",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end end)
MyDSL._triggers.combatBlock = tempRegexTrigger(
  "(You|[\\w\\-\\,\\s']+) (block)[s]? (your|[\\w\\-\\,\\s']+) attack .*\\.$",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end end)
MyDSL._triggers.combatSense1 = tempRegexTrigger(
  "^[\\w\\-\\s,']+ senses they.?re about to be hit and deflects the blow\\.",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(getCurrentLine()) end end)
MyDSL._triggers.combatSense2 = tempRegexTrigger(
  "^[\\w\\-\\s,']+ senses [\\w\\-\\s,']+'s attack coming and avoids its blow\\.",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(getCurrentLine()) end end)

-- ---- Condition trigger (excludes DEAD — handled by combatDead below)
-- Self-phrased alternatives added 2026-07-09 -- see CONDITION_PATTERNS'
-- header comment above for the confirmed self-condition bug and evidence.
MyDSL._triggers.combatCondition = tempRegexTrigger(
  "(?:is in excellent condition|are in excellent condition|has a few scratches|have a few scratches|has some small wounds|have some small wounds|has some big nasty wounds|have some big nasty wounds|has quite a few wounds|have quite a few wounds|looks pretty hurt|look pretty hurt|is in awful condition|are in awful condition)",
  function() if MyDSL and MyDSL.parseCombatConditionLine then MyDSL.parseCombatConditionLine(getCurrentLine()) end end)

-- ---- Death trigger (no PNP equivalent for the second form -- own addition)
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

-- ---- Weapon-flag proc triggers ----
-- Simplified 2026-07-05: no longer resolve attacker/target keys from each
-- trigger's own capture groups (parseCombatProcLine now uses PNP's
-- last_attacker/last_target/last_noun technique instead -- see 9q above).
-- The quote-inclusive character classes stay in the regex patterns
-- (Frost/Vampiric/Stunning) since they're still needed to MATCH lines with
-- quoted weapon names ("Nadrik's Honor") -- just no longer used to extract
-- a key from the match.

-- C: Frost
MyDSL._triggers.procFrostFreeze = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) freezes ([\\w\\-\\s,'\"]+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("C") end end)
MyDSL._triggers.procFrostTouch = tempRegexTrigger(
  "^The cold touch of ([\\w\\-\\s,']+) surrounds you with ice",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("C") end end)

-- F: Flaming
MyDSL._triggers.procFlameBurn = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is burned by ([\\w\\-\\s,']+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("F") end end)
MyDSL._triggers.procFlameSear = tempRegexTrigger(
  "^([\\w\\-\\s,']+) sears your flesh",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("F") end end)

-- L: Shocking
MyDSL._triggers.procShockLightning = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is struck by lightning from ([\\w\\-\\s,']+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("L") end end)
MyDSL._triggers.procShockShocked = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is shocked by a",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("L") end end)

-- H: Vampiric
MyDSL._triggers.procVampDraw = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) draws life from ([\\w\\-\\s,'\"]+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("H") end end)
MyDSL._triggers.procVampDrain = tempRegexTrigger(
  "^You feel ([\\w\\-\\s,']+) drawing your life away",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("H") end end)

-- S: Stunning
MyDSL._triggers.procStun = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) is knocked to the ground by ([\\w\\-\\s,'\"]+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("S") end end)

-- M: Mana drain
MyDSL._triggers.procManaSelf = tempRegexTrigger(
  "^You feel something drawing your energy away",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("M") end end)
MyDSL._triggers.procManaDraw = tempRegexTrigger(
  "^([\\w\\-\\s,']+) draws energy from ([\\w\\-\\s,']+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("M") end end)

-- O: Holy
MyDSL._triggers.procHolyWrath = tempRegexTrigger(
  "^You feel a surge of ([\\w\\-\\s,']+)'s holy wrath race through your body",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("O") end end)
MyDSL._triggers.procHolyFlash = tempRegexTrigger(
  "^A flash of holy power erupts from ([\\w\\-\\s,']+) and hits ([\\w\\-\\s,']+)!$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("O") end end)

-- U: Unholy
MyDSL._triggers.procUnholy = tempRegexTrigger(
  "^You feel a surge of ([\\w\\-\\s,']+)'s unholy wrath race through your body",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("U") end end)

-- Sharp: confirmed via Steven 2026-07-09 (from a Discord question) --
-- the Sharp weapon flag just adds bonus damage and never echoes anything
-- at all, so there's no trigger text to write, ever. Not a gap, working
-- as intended -- no action needed.
-- Vorpal: confirmed non-functional (produces no echo) — deliberately omitted

-- P: Poison (our own confirmed addition; no PNP equivalent)
-- procPoisonOnset/procPoisonTick both confirmed real via sibling-profile
-- logs 2026-07-09 (DSL1/log/2026-06-26#17-54-43.html), both seen with a
-- Coliseum location-broadcast prefix ("[ The Center of the Coliseum ]
-- Rylae is poisoned by the venom on a flail of eels.", "[ Southern
-- Coliseum Wall ] Rylae shivers and suffers.") -- same as every other
-- proc, these triggers deliberately do NOT match that prefix (see
-- combatDamage's header comment above for why) -- they'll still fire
-- normally for regular (non-Coliseum) poison procs.
MyDSL._triggers.procPoisonSetup = tempRegexTrigger(
  "^([\\w\\-\\s,']+) coats ([\\w\\-\\s,']+) with deadly lifebane poison\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("P") end end)
MyDSL._triggers.procPoisonOnset = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is poisoned by the venom on ([\\w\\-\\s,']+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("P") end end)
MyDSL._triggers.procPoisonTick = tempRegexTrigger(
  "^([\\w\\-\\s,']+) shivers and suffers\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("P") end end)

-- ---- Round-flush handler (PNP's output_damage(), close to verbatim) ----
-- Fires on every GMCP char_data packet (vitals refresh), which the game
-- sends once per prompt/combat round -- see 9q's header comment for why
-- this event (not updatePrompt-equivalent) is the right once-per-round
-- signal for us. For each (attacker,target) pair active this round, combine
-- nouns/hits/swings/dam (excluding "(evade)" from the noun/hit/dam
-- combination but INCLUDING its swings in the total, matching PNP's exact
-- `if k3 ~= "evaded"` scope), compute an aggregate verb via calcDamVerb(),
-- and output ONE summary sentence per pair to MAIN CONSOLE.
--
-- Critical PNP behavior, confirmed by reading output_damage() directly:
-- this summary is gated ONLY by summarize_damage -- NOT by gag_combat. That
-- means PNP's actual out-of-box default (gag_combat=true, gag_non_damage=
-- true, summarize_damage=true) already gives exactly a "condensed" mode:
-- raw per-swing lines hidden, one aggregate sentence per round shown. The
-- 3-way raw/condensed/gag toggle Steven described maps directly onto these
-- two flags -- raw: gag_combat=false, summarize_damage=false; condensed:
-- gag_combat=true, summarize_damage=true (the PNP default); gag: both true/
-- false respectively (summarize_damage=false, nothing to main at all).
if MyDSL._handlers.combatRoundFlush then
  pcall(killAnonymousEventHandler, MyDSL._handlers.combatRoundFlush)
end
MyDSL._handlers.combatRoundFlush = registerAnonymousEventHandler(
  "MyDSL.char.updated",
  function()
    if not (MyDSL and MyDSL.State and MyDSL.State.combat) then return end
    local combat = MyDSL.State.combat
    local rd  = combat.round_data
    local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}

    if next(rd) and cfg.summarize_damage then
      -- Group round_data entries by (attacker,target) pair.
      local roundPairs = {}
      for _, e in pairs(rd) do
        local pairKey = e.attacker .. "→" .. e.target
        roundPairs[pairKey] = roundPairs[pairKey]
          or { attacker=e.attacker, target=e.target, swings=0, hits=0, dam=0, nouns={}, flags={} }
        local p = roundPairs[pairKey]
        p.swings = p.swings + (e.swings or 0)
        if e.noun ~= "(evade)" then
          p.hits = p.hits + (e.hits or 0)
          p.dam  = p.dam  + (e.score or 0)
          p.nouns[#p.nouns + 1] = e.noun
          if e.flags then
            for code, cnt in pairs(e.flags) do p.flags[code] = (p.flags[code] or 0) + cnt end
          end
        end
      end

      local first = true
      for _, p in pairs(roundPairs) do
        if p.swings > 0 then
          local isYou           = (p.attacker == "you")
          local displayAttacker = isYou and "You" or string.title(p.attacker)
          local displayTarget   = string.title(p.target)
          local possessive      = isYou and "r" or "'s"
          local nounsStr        = table.concat(p.nouns, ", ")
          local flagsStr        = ""
          for code, _ in pairs(p.flags) do
            flagsStr = flagsStr .. "<" .. (FLAG_COLOR[code] or "255,215,65") .. ">" .. code
          end
          if flagsStr ~= "" then flagsStr = flagsStr .. "<r>" end

          local str = battleFormat(cfg.summary_format or "%a%r %n %v %t (%d)", {
            a = displayAttacker, r = possessive, n = nounsStr, v = calcDamVerb(p.dam, isYou),
            t = displayTarget, d = p.dam, h = p.hits, s = p.swings, f = flagsStr,
          })
          decho((first and "" or "\n") .. str)
          first = false
        end
      end

      if combat.pending_condition then
        decho("\n" .. combat.pending_condition.screen)
      end
    end

    if combat.pending_condition and MyDSL.CombatView and MyDSL.CombatView.appendSwing then
      MyDSL.CombatView.appendSwing(combat.pending_condition.window)
    end
    combat.pending_condition = nil

    combat.last_updated = os.time()
    raiseEvent("MyDSL.combat.updated", rd)
    combat.round_data = {}

    -- Rage: check if HP is hidden this round
    local rage = combat.rage
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
-- Improve triggers -- wired 2026-07-07 (both parse functions existed but
-- nothing called them; see parseImproveLine/parseImproveStatusLine above).
-- Per Steven: keep this one specifically, feeds a LiveView bar.
------------------------------------------------------------------------

MyDSL._triggers.improveComplete = tempRegexTrigger(
  "^Your knowledge of .+ improves to \\d+%\\.?$",
  function() if MyDSL and MyDSL.parseImproveLine then MyDSL.parseImproveLine(getCurrentLine()) end end)
MyDSL._triggers.improveGetBetter = tempRegexTrigger(
  "^You feel yourself getting better at .+\\. \\(\\d+%\\)$",
  function() if MyDSL and MyDSL.parseImproveLine then MyDSL.parseImproveLine(getCurrentLine()) end end)
MyDSL._triggers.improveStatus = tempRegexTrigger(
  "^You are currently improving .+ \\(\\d+%\\)\\. \\(\\d+ online minutes to improvement\\)\\.?$",
  function() if MyDSL and MyDSL.parseImproveStatusLine then MyDSL.parseImproveStatusLine(getCurrentLine()) end end)


------------------------------------------------------------------------
-- READY
------------------------------------------------------------------------
debugc("[MyDSL] DataLayer v1.0 loaded. Character: "
  .. tostring(MyDSL.Char() or "(not yet known)"))
