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
-- 9a  SCORE
------------------------------------------------------------------------
-- Trigger wiring is done in code at the bottom of this file.
-- beginScore() is called by a permanent tempRegexTrigger on "^Score for ".
-- It installs a catch-all line trigger that feeds every subsequent line to
-- parseScoreLine(). The catch-all is killed by endScore() so it is only
-- active during the score block.
--
-- The score block has three "^---" separator lines:
--   Line 1: "Score for <Name> -= <Title> =- ..."  → beginScore()
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
  -- (e.g. "Created: Wed May 21 15:20:26 2025", from a real captured score
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
-- (confirmed: "[27 Goblin Bnd] (WANTED) (VR) <Name>." parsed as
-- kingdom="()" name="(VR)" instead of org="VR" name="<Name>"). Also dropped
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
-- Example: "[51 War] <Name>                     100% hp 100% mana 100% mv"
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
  -- ("[51 War] <Name> ..."). The old pattern required a digit immediately
  -- after "[", so it silently failed to match ANY line (self included) once
  -- a group member's level dropped below 10 -- confirmed via a real
  -- "[ 1 Mob]"/"[ 1 Mag]" group listing, which is what caused
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
-- SECTION 10: TRIGGER REGISTRATION
------------------------------------------------------------------------
-- Score header: "Score for <Name> -= <Title> =- (Companion) *Observer*"
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
-- Also matches "==-<Name>" (name echo) but parsePromptLine() drops it (no " - HH:MM :: ").

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
-- log/2026-07-07#20-17-54.html (typed `stat` on a dragon character):
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
-- Fires on "<Name>'s group:" (any character name followed by "'s group:").
-- Installs the body catch-all via beginGroup(); endGroup() kills it on
-- blank line and commits to State.group.

MyDSL._triggers.groupStart = tempRegexTrigger(
  "^.+'s group:$",
  function()
    if MyDSL and MyDSL.beginGroup then MyDSL.beginGroup() end
  end
)

-- CreatureLore trigger registration moved to
-- MyDSL_DataLayer_CreatureLore.lua (2026-08-25 split), alongside the
-- begin/parse/end functions it wires up -- see that file for the
-- MyDSL._triggers.loreStart registration.



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
