-- =============================================================================
-- MyDSL_DataLayer.lua  --  Layer 1: Data Collection
-- =============================================================================
-- Zero display logic. Never sends commands to the game.
-- All data lives under MyDSL.State[section] and MyDSL.Data[charName][section].
-- Other modules receive updates via registerAnonymousEventHandler("MyDSL.
-- <section>.updated", "Some.Named.Function") and read MyDSL.State[section]
-- directly -- the decided 1.0 standard (docs/MYDSL_1.0_PHILOSOPHY.md,
-- Principle 3). The old MyDSL.on(section, fn) direct-Lua-callback API was
-- removed 2026-08-26, per Steven ("remove api") -- see MyDSL.emit()'s own
-- comment below.
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

-- Stub the old PNP framework's `dslpnp` global -- added 2026-08-23. A
-- handful of leftover native triggers (confirmed so far: "Charge",
-- "BACKSTABS") still guard themselves with `if dslpnp.battle.Active then`,
-- a pattern from the pre-DSL2 PNP client this profile no longer loads.
-- Real, reproducible, currently spamming the error log every time one of
-- those triggers fires (confirmed live 2026-08-21/22 in MyDSL's own
-- error log) -- but not a MyDSL_*.lua bug, since our own code already
-- checks `_G.dslpnp and ...` defensively everywhere it touches this. This
-- stub only defines the one field every known usage actually reads, so
-- `dslpnp.battle.Active` reads `false` (correctly: no PNP battle system
-- is really active here) instead of erroring -- it does not attempt to
-- resurrect any other part of the old `dslpnp` API surface.
dslpnp = dslpnp or {}
dslpnp.battle = dslpnp.battle or { Active = false }


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
-- is debug-only -- off by default, opt-in when actually debugging that
-- specific window, not something worth the disk churn during normal
-- play. All of them remain individually toggleable regardless of default.
-- Corrected 2026-08-24, re-confirmed against Steven's still-open TODO.md
-- ask ("stop logging anything except combat/main window/chat and
-- history... others dont seem needed"): `target`/`scan`/`bloodbath`
-- were dead entries -- no current code calls MyDSL.logWindow() with any
-- of those three names (confirmed via grep across every MyDSL_*.lua
-- file; they're leftovers from the old MyDSL.Route.scan()/combat()/
-- group()/righthere() shorthands removed 2026-08-23 as confirmed dead
-- code, which used to route raw text through this same mechanism before
-- ScanView/GroupView/TargetView grew their own direct structured
-- rendering). Meanwhile `focus` (MyDSL_TargetView.lua's real, active
-- log category) was MISSING from this list entirely -- so Focus/Target
-- updates were logging by default this whole time, contradicting
-- Steven's own stated wish, simply because the category got renamed
-- from `target` to `focus` at some point and this list was never
-- updated to match. Removed the 3 dead entries, added the 1 real
-- missing one.
MyDSL.LogConfig = MyDSL.LogConfig or {
  enabled = true,
  disabled_categories = {
    playersnear = true,
    group       = true,
    righthere   = true,
    focus       = true,
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
-- Dirs already confirmed to exist this session -- added 2026-07-19 after a
-- PVP perf audit found this function was shelling out to "mkdir -p" (a full
-- process fork/exec, easily the most expensive line in this function) on
-- EVERY flushed log line, forever, for every category -- "combat" isn't in
-- disabled_categories by default, so every single combat swing during a
-- fight paid for a shell spawn just to recheck a directory that's already
-- there. The directory only needs creating once per path per session.
MyDSL._logDirsEnsured = MyDSL._logDirsEnsured or {}

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
  if not MyDSL._logDirsEnsured[dir] then
    -- mkdir -p equivalent: lfs.mkdir only makes one level, so try os.execute
    -- too for the full path in case MyDSL/logs/ itself doesn't exist yet
    -- (fresh checkout -- git doesn't track empty dirs). Same dual approach as
    -- MyDSL_ChatWrapper.lua's ensureDir(). Only done once per dir per
    -- session now, not on every flushed line.
    if lfs and lfs.mkdir then pcall(lfs.mkdir, dir) end
    if os and os.execute then pcall(os.execute, "mkdir -p " .. string.format("%q", dir)) end
    MyDSL._logDirsEnsured[dir] = true
  end
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

-- MyDSL.normalizeForMatch(name) / MyDSL.bestFuzzyMatch(target, candidates)
-- -- promoted to real MyDSL.* table functions 2026-08-25 while splitting
-- MyDSL_DataLayer.lua by domain (see docs/TODO.md): confirmed via grep
-- these are needed by BOTH the Scan/Look domain (resolveMobName(), being
-- split into MyDSL_DataLayer_ScanLook.lua) AND the not-yet-split ItemLore
-- section's resolveGroundItem() further down this same file -- a genuine
-- shared utility, not owned by either domain alone, so it stays here in
-- core rather than being duplicated (drift risk) or forcing both domains
-- into one file. Originally added 2026-07-16, ported from a real, tested
-- technique found in the Shattered Archive client's own equipment
-- delta-matching (useEquipmentDeltas.ts,
-- ~/Downloads/Shattered-Archive-release-dev.zip): normalize both sides,
-- score an exact match highest, a substring match (either direction)
-- lower, and refuse to pick a winner if two candidates tie -- a false
-- merge (treating two different mobs/items as the same one) is worse
-- than declining to match at all.
--
-- normalizeForMatch() strips the same decorations isLookFixtureLine()/
-- itemKey() already strip elsewhere (leading article, ground-sentence
-- suffixes) so a truncated/generic capture (e.g. "a gnome" from "A gnome
-- is here using levers...") can still match a fuller known name ("a
-- gnome machinist") via substring containment.
function MyDSL.normalizeForMatch(name)
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
function MyDSL.bestFuzzyMatch(target, candidates)
  local t = MyDSL.normalizeForMatch(target)
  if t == "" then return nil end
  local best, bestScore, tie = nil, 0, false
  for _, c in ipairs(candidates or {}) do
    local cName = MyDSL.normalizeForMatch(c.name)
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

-- Per-character persistent storage.  Keyed by character name so each
-- logged-in character has completely separate saved state.
MyDSL.Data = MyDSL.Data or {}

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
-- Display/feature modules listen via registerAnonymousEventHandler
-- ("MyDSL.<section>.updated", "Some.Named.Function") and read
-- MyDSL.State[section] directly inside that handler -- the decided 1.0
-- standard (docs/MYDSL_1.0_PHILOSOPHY.md, Principle 3).
--
-- The old MyDSL.on(section, callback) direct-Lua-callback API (an
-- in-memory listener list, dispatched synchronously from inside this
-- same function) was removed 2026-08-26, per Steven ("remove api") --
-- docs/MYDSL_1.0_MODULE_REDESIGN.md #1 confirmed MyDSL_MovementSounds.lua
-- was the only real caller of the paired Get/Set API, and MyDSL_Leveling
-- .lua (the only real MyDSL.on() caller) was ported to the standard
-- registerAnonymousEventHandler pattern in the same pass.

function MyDSL.emit(section)
  -- Mudlet event — any trigger or script can hear "MyDSL.char.updated" etc.
  raiseEvent("MyDSL." .. section .. ".updated", MyDSL.State[section])
end


------------------------------------------------------------------------
-- SECTION 6: BULK STATE WRITER
------------------------------------------------------------------------
-- MyDSL.get()/MyDSL.set() (the old Get/Set indirection API) removed
-- 2026-08-26 per Steven ("remove api") -- docs/MYDSL_1.0_MODULE_REDESIGN.md
-- #1 confirmed MyDSL_MovementSounds.lua was the only real caller
-- project-wide (ported to read MyDSL.State directly, same lookup this
-- API always did with one extra indirection); every other module
-- already read/wrote MyDSL.State directly, the decided 1.0 standard
-- (docs/MYDSL_1.0_PHILOSOPHY.md, Principle 3).

-- Bulk writer.  Merges a table of fields into a section, stamps
-- last_updated once, emits once, then mirrors into per-character Data so
-- the next save() captures it.
--
-- Promoted from a file-local helper to MyDSL.update() 2026-08-26 --
-- real bug found via the MyDSL 1.0 roadmap's PromptVitals test-coverage
-- item: the 2026-08-25 DataLayer split-by-domain refactor moved every
-- CALL SITE of this function out into MyDSL_DataLayer_PromptVitals.lua
-- and MyDSL_DataLayer_ItemLore.lua (13 sites total) while this
-- definition stayed `local` here -- since a Lua `local` never crosses a
-- separate dofile()'d chunk, every one of those 13 call sites has been
-- throwing "attempt to call global 'update' (a nil value)" since the
-- split landed, silently breaking score/flags/lunar/time/weather/who/
-- group/improve/posn/wimpy/vitality (PromptVitals) and equipment/
-- inventory (ItemLore) capture entirely. `local update = MyDSL.update`
-- right below keeps every pre-existing bare `update(...)` call already
-- in this file working unchanged.
function MyDSL.update(section, fields)
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
local update = MyDSL.update


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

-- Disk-write debounce -- added 2026-07-19 after a PVP perf audit found
-- MyDSL.save() was doing a synchronous table.save() of the WHOLE MyDSL.Data
-- table (every character ever played on this profile, not just the current
-- one) on every single affect_data/add_affect/remove_affect event -- i.e.
-- every buff/debuff landing or expiring mid-fight paid for a full-table disk
-- serialize. The in-memory snapshot into MyDSL.Data (cheap, just field
-- copies) still happens on every call so anything reading MyDSL.Data
-- directly stays current; only the actual disk write is coalesced, so a
-- burst of affect changes in one fight round becomes one write shortly
-- after the burst ends instead of one write per change. Trade-off: a crash
-- or hard kill inside the debounce window can lose the last <1.5s of
-- state -- flushed immediately on disconnect/exit below to shrink that
-- window for the case that matters (a normal quit or link loss).
MyDSL._pendingDiskSave = MyDSL._pendingDiskSave or nil

local function flushSaveToDisk()
  MyDSL._pendingDiskSave = nil
  table.save(saveFilePath(), MyDSL.Data)
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
  if not MyDSL._pendingDiskSave then
    MyDSL._pendingDiskSave = tempTimer(1.5, flushSaveToDisk)
  end
end

-- Force an immediate flush on disconnect/exit so a debounced write in
-- flight isn't silently dropped by a normal quit or link loss.
MyDSL._handlers.saveFlushOnDisconnect = registerAnonymousEventHandler(
  "sysDisconnectionEvent",
  function() if MyDSL._pendingDiskSave then flushSaveToDisk() end end
)
MyDSL._handlers.saveFlushOnExit = registerAnonymousEventHandler(
  "sysExitEvent",
  function() if MyDSL._pendingDiskSave then flushSaveToDisk() end end
)

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
-- READY
------------------------------------------------------------------------
debugc("[MyDSL] DataLayer v1.0 loaded. Character: "
  .. tostring(MyDSL.Char() or "(not yet known)"))
