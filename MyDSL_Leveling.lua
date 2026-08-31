-- =============================================================================
-- MyDSL_Leveling.lua  --  Leveling-assist addon (SENDS REAL GAME COMMANDS)
-- =============================================================================
-- Added 2026-07-19. Unlike every other MyDSL_*.lua file, this module
-- deliberately sends automatic game commands (movement, "kill <mob>",
-- "drop <n> silver", optional buff-reapply) -- an explicit, narrow exception
-- to the project's normal "passive observation only" rule, granted by
-- the maintainer: "the no automation is suspended for thes modules, they will be
-- outside addons for the ui, for the specific task of automating these
-- features." Scope is limited to this file and a future MyDSL_Questing.lua
-- -- see docs/TODO.md's DECISIONS RECORDED section. Every other module in
-- this profile stays passive-only.
--
-- Ported/redesigned from AlexK's 2015 community "Leveling" Mudlet package
-- (dsl-mud.org forums), with the raw hunting-area data (MyDSL/
-- leveling_areas_seed.lua) sourced and corrected from forum 111 "Mudlet
-- Scripts" thread 99388 "Leveling.areas Combined". Reuses this codebase's
-- own existing infrastructure instead of AlexK's 3-trigger room-capture
-- chain: MyDSL_DataLayer.lua's scan.rightHere (fed by the SAME "[Exits: "
-- anchor AlexK's own capture used) and the real DSL_Generic_Mapper.xml
-- fork's map.speedwalk()/getPath().
--
-- Session control is deliberately just start/resume/pause/stop, per
-- the maintainer (2026-07-20): "whatever timer stops combat is not useful, just
-- keep walking and fighting till you get back to the start point and
-- give report like in PNP, we only need the pause resume and stop, not
-- a fallback safety timer or whatever it is." An earlier version had a
-- CharacterAssist-style dead-man's-switch failsafe timer -- removed
-- entirely, not just disabled, per that ask. The one remaining automatic
-- stop is the HP%-threshold safety net (SECTION 10) -- not timer-based,
-- and an explicitly separate, earlier, still-standing decision.
-- =============================================================================

MyDSL         = MyDSL         or {}
MyDSL.Leveling = MyDSL.Leveling or {}

local L = MyDSL.Leveling

-- Safe-reload: kill old handlers/triggers/aliases on every load, same
-- boilerplate as every other MyDSL Layer 3 module (TargetView,
-- CombatView, CharacterAssist). No timer to kill here -- the failsafe
-- timer this once had was removed entirely 2026-07-20, per the maintainer.
for _, id in pairs(L._handlers or {}) do pcall(killAnonymousEventHandler, id) end
for _, id in pairs(L._triggers or {}) do pcall(killTrigger, id) end
for _, id in pairs(L._aliases  or {}) do pcall(killAlias, id) end

L._handlers = {}
L._triggers = {}
L._aliases  = {}
L._mc = L._mc or {}
L.aliasesMade = false

local WIN = "MyDSL_Leveling"
local MC  = "MyDSL_Leveling_MC"


------------------------------------------------------------------------
-- SECTION 1: LOCAL HELPERS (each MyDSL module carries its own small
-- copies of these -- established project convention, see MyDSL_DataLayer
-- .lua's safeFileName() comment and MyDSL_LocationView.lua's exists()/
-- join()/ensureDir()).
------------------------------------------------------------------------

local function ce(msg)
  local line = "<cyan>[MyDSL.Leveling]<reset> " .. tostring(msg)
  cecho("\n" .. line .. "\n")
  -- Also mirror into Leveling's own status window -- wired up 2026-08-23,
  -- per the maintainer ("wire it up"). L.log()/L._mc.log existed since this file's
  -- first commit but nothing ever called L.log(), so the window was
  -- permanently blank; every run's status only ever reached the main
  -- console. Kept both (not moved, per this project's "move text, don't
  -- replace it" principle only applies to text the GAME sends -- this is
  -- our own status output, and the maintainer's ask was to ALSO show it in the
  -- dedicated window, not relocate it away from the main console).
  if L.log then L.log(line) end
end
local function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end

local function exists(path)
  if not path then return false end
  if io and io.exists then return io.exists(path) end
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function join(dir, file)
  if not dir or not file then return nil end
  if string.sub(dir, -1) == "/" then return dir .. file end
  return dir .. "/" .. file
end

local function ensureDir(path)
  if not path or path == "" then return end
  pcall(function() os.execute('mkdir -p "' .. tostring(path):gsub('"', '\\"') .. '"') end)
end

local function profileDir()
  return (getMudletHomeDir and getMudletHomeDir()) or "."
end

local function dataDir() return join(profileDir(), "MyDSL") end

-- selfDir() -- real bug fix, 2026-08-23 (found via an independent
-- Claude.ai/Claude Desktop review, both hit the same "known false alarm"
-- test failure on their own machines and correctly traced it to this).
-- The seed-file fallback below used to hardcode a literal absolute path
-- specific to the maintainer's own machine
-- ("/home/owner/.config/mudlet/profiles/DSL2/MyDSL/..."). That's real
-- and necessary in spirit -- this addon is deliberately dofile()'d from
-- an absolute path into the DSL2 repo from inside the MyDSL play
-- profile (see importSeedAreas()'s own header comment), so a real,
-- machine-specific fallback genuinely matters -- but baking one
-- specific person's home directory into tracked source breaks on any
-- other machine, including a review pass running this test suite
-- somewhere else entirely, now that this repo is public. Since Mudlet's
-- real dofile() always loads this file by its real absolute path,
-- debug.getinfo can recover that same path from the running chunk
-- itself (Lua sets the chunk's "source" to "@<path-as-given>") --
-- portable to literally any machine this file is deployed on, derived
-- at runtime instead of hardcoded. Falls back to "." (this process's own
-- cwd) if introspection isn't available or the file was loaded some
-- other way (e.g. a relative dofile(), as this project's own test suite
-- uses) -- harmless, since the caller below tries several candidates
-- and simply skips whichever ones don't resolve to a real file.
local function selfDir()
  local info = debug and debug.getinfo and debug.getinfo(1, "S")
  local source = info and info.source
  if source and source:sub(1, 1) == "@" then
    local path = source:sub(2)
    local dir = path:match("^(.*)[/\\][^/\\]+$")
    if dir and dir ~= "" then return dir end
  end
  return "."
end

-- Same last-word-reduction TargetView's private commandArg() uses --
-- confirmed live (MyDSL_TargetView.lua): DSL's own kill/target keyword
-- matching only succeeds on a single word. Kept as our own tiny copy
-- rather than exporting TargetView's private local, to keep this file's
-- "separate outside addon" boundary strict (no edits to a passive-
-- observation core module just for this addon's benefit).
local function normalizeName(s)
  s = tostring(s or ""):lower()
  s = s:gsub('[",.]', " ")
  s = s:gsub("^a%s+", ""):gsub("^an%s+", ""):gsub("^the%s+", "")
  s = s:gsub("%s+", " ")
  return trim(s)
end

local function commandArg(name)
  local s = normalizeName(name or "")
  if s == "" then return "" end
  return s:match("(%S+)$") or s
end

-- onceDataLayerReady() (guarded a load-order race against MyDSL.on(),
-- see docs/CHANGELOG.md 2026-07-21) removed 2026-08-26 along with
-- MyDSL.on() itself, per the maintainer ("port if it doesnt break anything").
-- The replacement, registerAnonymousEventHandler("MyDSL.scan.updated",
-- "MyDSL.Leveling.onScanUpdated") below, doesn't need this guard at all
-- -- Mudlet resolves the named target function at EVENT-FIRE time, not
-- at registration time, so it's always safe to call at file load
-- regardless of MyDSL_DataLayer.lua's own load-order position.

-- stripLeadingTags(line) -- strips ALL leading parenthetical tags
-- ("(Charmed) (Golden Aura) (White Aura) A beautiful..."), same loop
-- MyDSL_DataLayer.lua's parseLookHereLine() already uses. Needed here
-- because scan.rightHere[key].raw is deliberately the UNSTRIPPED
-- original line (kept for display/audit) -- see REAL BUG comment below
-- at the mob-matching site for why comparing against it directly broke
-- every match.
local function stripLeadingTags(line)
  local rest = trim(line or "")
  while true do
    local stripped = rest:match("^%([^()]+%)%s*(.+)$")
    if not stripped then break end
    rest = stripped
  end
  return rest
end

-- Derive a short display label from a captured room-presence line, for
-- status/help display only -- never used for matching (matching against
-- scan.rightHere is always exact-string on the "raw" field). Strips
-- leading parentheticals/articles and trailing verb-phrase filler.
local function deriveLabel(raw)
  local rest = stripLeadingTags(raw)
  rest = rest:gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  local cut = rest:find(" is here") or rest:find(" stands here") or rest:find(" sits here")
           or rest:find(" hovers") or rest:find(" wanders here") or rest:find(",")
  if cut then rest = rest:sub(1, cut - 1) end
  return trim(rest)
end

-- mapperRoomId() -- same defensive fallback chain MyDSL_LocationView.lua's
-- own mapperRoomId() uses (getPlayerRoom() first, then a few common mapper-
-- package globals), copied rather than exported for the same addon-
-- boundary reason as commandArg() above.
local function validRoomId(id)
  if id == nil then return nil end
  local s = tostring(id)
  if s == "" or s == "0" or s == "-1" or s == "nil" then return nil end
  return id
end

local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, ret = pcall(fn, ...)
  if ok then return ret end
  return nil
end

local function mapperRoomId()
  local id = validRoomId(call(_G.getPlayerRoom))
  if id then return id end
  local candidates = {
    _G.currentRoom, _G.current_room, _G.currentRoomID, _G.current_room_id,
    _G.map and (_G.map.currentRoom or _G.map.current_room or _G.map.room or _G.map.currentRoomID),
    _G.mapper and (_G.mapper.currentRoom or _G.mapper.current_room or _G.mapper.room or _G.mapper.currentRoomID),
  }
  for _, v in ipairs(candidates) do
    id = validRoomId(v)
    if id then return id end
  end
  return nil
end


------------------------------------------------------------------------
-- SECTION 2: PERSISTENCE
------------------------------------------------------------------------
-- Same table.save()/table.load(file, target) 2-arg pattern
-- MyDSL_LocationView.lua's roomPictures uses -- the 2-arg form is
-- required (table.load has no return value; a documented recurring bug
-- in this codebase otherwise).

function L.areasFile() return join(dataDir(), "leveling_areas.lua") end

function L.loadAreas()
  L.areas = L.areas or {}
  if exists(L.areasFile()) then
    pcall(function() table.load(L.areasFile(), L.areas) end)
  end
end

function L.saveAreas()
  ensureDir(dataDir())
  pcall(table.save, L.areasFile(), L.areas or {})
end

-- importSeedAreas(path) -- same non-destructive merge-into-live-db pattern
-- as MyDSL_CreatureLore.lua's importScraped()/bestiary_scrape_import.lua.
-- The seed file ships in AlexK's original raw shape (dirs/allowed_mobs/
-- description/levels) -- converted to our schema here rather than shipping
-- pre-converted, mirroring CreatureLore's own two-stage scrape->live-db
-- pattern. Never overwrites an area the user already has (so re-running
-- "mydsl leveling import" after hand-editing mobs is always safe).
-- REAL BUG, found live 2026-07-19 (the maintainer: "mydsl leveling import looks
-- like it died or never triggered" -- no output at all, not an error).
-- Two compounding causes: (1) the default path used getMudletHomeDir(),
-- which resolves to whichever profile is CURRENTLY RUNNING the script,
-- not the DSL2 repo the dofile() actually points at -- this addon is
-- deliberately cross-profile (its Script entry dofile()s an absolute
-- path into the DSL2 git repo from inside the MyDSL play profile, so
-- fixes land without a reinstall), so the seed file was only ever
-- looked for inside the MyDSL profile's own (nonexistent) MyDSL/
-- folder, confirmed via `ls` -- never found. (2) the failure path only
-- called debugc(), which writes to Mudlet's separate Errors/debug
-- console (not necessarily open) -- so the command silently did
-- nothing, with zero visible sign anything went wrong. Fixed both:
-- tries the current profile's own MyDSL/ folder first (so a genuinely
-- standalone install still works), falls back to the known DSL2 repo
-- copy this addon is actually deployed from, and reports failure via
-- ce() (visible on the main console) instead of only debugc().
function L.importSeedAreas(path)
  local candidates = {}
  if path then table.insert(candidates, path) end
  table.insert(candidates, join(dataDir(), "leveling_areas_seed.lua"))
  table.insert(candidates, join(selfDir(), "MyDSL/leveling_areas_seed.lua"))
  -- Last-resort plain-relative guess, covers running from the repo root
  -- with no absolute-path introspection available (selfDir() can't
  -- recover a real directory from a relative dofile(), which is exactly
  -- how this project's own test suite loads this file).
  table.insert(candidates, "MyDSL/leveling_areas_seed.lua")

  local resolvedPath = nil
  for _, p in ipairs(candidates) do
    local f = io.open(p, "r")
    if f then f:close(); resolvedPath = p; break end
  end
  if not resolvedPath then
    ce("Seed file not found. Looked in: " .. table.concat(candidates, "  |  "))
    return
  end
  path = resolvedPath

  local ok, rawAreas = pcall(dofile, path)
  if not ok or type(rawAreas) ~= "table" then
    ce("Seed file failed to load (" .. path .. "): " .. tostring(rawAreas))
    return
  end

  L.areas = L.areas or {}
  local added, skipped = 0, 0
  for name, def in pairs(rawAreas) do
    local key = normalizeName(name)
    if L.areas[key] then
      skipped = skipped + 1
    else
      local mobs = {}
      for abbrev, raw in pairs(def.allowed_mobs or {}) do
        mobs[abbrev] = {
          raw = raw, label = deriveLabel(raw), kill_kw = commandArg(abbrev), enabled = true,
        }
      end
      L.areas[key] = {
        name = name, dirs = def.dirs or {}, mobs = mobs,
        levels = def.levels or "Unknown.", description = def.description or "",
        startRoomId = nil, roomPath = {}, source = "seed",
      }
      added = added + 1
    end
  end
  L.saveAreas()
  local msg = string.format(
    "[MyDSL] Leveling import: %d new area(s), %d already present (left untouched).", added, skipped)
  echo(msg .. "\n")
  debugc(msg)
end


------------------------------------------------------------------------
-- SECTION 3: SESSION STATE (non-persisted)
------------------------------------------------------------------------

-- No failsafe/timeout field, by design, per the maintainer ("whatever timer
-- stops combat is not useful... we only need the pause resume and
-- stop, not a fallback safety timer or whatever it is") -- removed
-- 2026-07-20 along with the timer mechanism itself. state is only ever
-- "stopped" | "paused" | "active" ("navigating" retired the same day --
-- see SECTION 5's own header comment).
L.session = L.session or {
  state             = "stopped",
  areaKey           = nil,
  stepIndex         = 1,
  awaitingRoom      = false,
  mobsInRoom        = {},
  pendingKillMobKey = nil,
  stats             = { killed = 0, xp = 0, started = nil },
  hpThreshold       = 30,   -- percent; 0 disables
  buffs             = {},   -- {fury=cmd, haste=cmd, detects=cmd, sanc=cmd}
  -- "order all kill <target>" instead of a direct "kill <target>" --
  -- per the maintainer's own MyDSL notes ("an order all kill option instead of
  -- direct attack, for classes where thats the right opener"): DSL's
  -- real `order` command (DSL_Helpfiles/order.txt, confirmed) orders
  -- every charmed follower/pet to act, which is the correct opener for
  -- a class that fights through summoned/charmed creatures rather than
  -- personally. Defaults to "direct" -- this is an opt-in per-class
  -- choice, not a universal behavior change.
  attackMode        = "direct",  -- "direct" | "orderall"
}


------------------------------------------------------------------------
-- SECTION 4: WINDOW / UI (on-demand, visible=false -- same precedent as
-- MyDSL_CreatureReference.lua)
------------------------------------------------------------------------

function L.ensureUI()
  local win = MyDSL.Windows and MyDSL.Windows.ensure(WIN)
  -- REAL BUG, found live 2026-07-19 (the maintainer: "that script blanks my main
  -- window") -- root cause was MyDSL_WindowRegistry.lua's own registry
  -- table skipping newly-added keys on an in-session reload (fixed there,
  -- see that file's comment), which meant Windows.ensure() returned nil
  -- here and a Geyser.MiniConsole got created with `nil` as its parent --
  -- Geyser attaches a parentless console to the main window itself, at
  -- the requested 100%x100%, blanking it. Never let that happen again
  -- regardless of WHY ensure() failed: bail out with a debug warning
  -- instead of falling through to an implicit main-window attach.
  if not win then
    debugc("[MyDSL] Leveling: window '" .. WIN .. "' unavailable (not registered yet?) -- skipping UI.")
    return
  end
  -- Visual pass v2 "One Bar, Renamed and Colored" (locked spec, 2026-08-26).
  if win.setTitle then pcall(function() win:setTitle("Leveling") end) end
  if not L._mc.log then
    L._mc.log = Geyser.MiniConsole:new({
      name = MC, x = 0, y = 0, width = "100%", height = "100%", scrollBar = true,
    }, win)
  end
  local fontSize = MyDSL.Windows and MyDSL.Windows.getFontSize(WIN, 9) or 9
  if L._mc.log then L._mc.log:setFontSize(fontSize) end
  if MyDSL.Windows and MyDSL.Windows.enableAdaptiveWrap then
    MyDSL.Windows.enableAdaptiveWrap(L._mc.log, fontSize)
  end
end

function L.log(text)
  -- :cecho(), not :decho() -- every real caller (ce(), below) uses cecho-
  -- style named tags (<cyan>, <reset>), which :decho() doesn't understand.
  -- Fixed 2026-08-23 while wiring this up for real (see ce()).
  if L._mc.log then L._mc.log:cecho(text .. "\n") end
end

function L.show() if MyDSL.Windows then MyDSL.Windows.show(WIN) end end
function L.hide() if MyDSL.Windows then MyDSL.Windows.hide(WIN) end end


------------------------------------------------------------------------
-- SECTION 5: NAVIGATE-TO-AREA
------------------------------------------------------------------------
-- Uses the real DSL_Generic_Mapper.xml fork's map.speedwalk(roomID) --
-- confirmed real, already in production (its own "room find"/"rf" alias
-- drives it the same way from an arbitrary current room via getPath()).
--
-- REDESIGNED 2026-07-20, per the maintainer ("its to many steps to start"): the
-- original design required a SECOND explicit "start <area>" call to
-- confirm arrival before "resume" would work -- one command to kick off
-- navigation, wait, then another to confirm you're actually there. Now
-- "start <area>" does its best (speedwalk if the room id is already
-- known, otherwise prints manual directions) and lands directly in
-- "paused" either way -- no confirmation round-trip. The tradeoff:
-- "paused" no longer strictly means "confirmed in position," just
-- "session is set up and waiting on you" -- acceptable since resuming
-- into the wrong room just produces a few harmless failed-move messages
-- from the area's own dirs list, not a fabricated command that couldn't
-- happen. Room-id caching (for next time's speedwalk) is now
-- opportunistic inside resume() instead of gating the whole flow.

-- REAL BUG, found live 2026-07-21 (the maintainer: "the path even seems
-- incorrect", confirmed via log: "(mapper): (error): No path to chosen
-- room found."). map.speedwalk() fails by echoing to the map console
-- itself, not by raising a Lua error -- so the pcall() below always
-- returns ok=true even when the speedwalk silently did nothing, and the
-- old code only ever showed the manual `area.description` directions in
-- the OTHER branch (no cached room at all), leaving a failed-speedwalk
-- player with zero fallback guidance -- exactly the scenario that made
-- the subsequent raw-dirs-list walk look like it was following "an
-- incorrect path" (it was correct, just starting from the wrong room).
-- Fixed: always show the manual directions as a fallback reference
-- alongside a speedwalk attempt, not only when there's no cached room to
-- try -- harmless one extra line when speedwalk actually succeeds, a
-- real fallback when it silently doesn't.
function L.startArea(areaKey)
  local area = L.areas[areaKey]
  if not area then ce("No such area: " .. tostring(areaKey) .. ". Try: mydsl leveling areas"); return end

  L.session.areaKey = areaKey
  L.session.stepIndex = 1
  L.session.mobsInRoom = {}
  L.session.pendingKillMobKey = nil

  if area.startRoomId and _G.map and _G.map.speedwalk then
    ce("Navigating to " .. area.name .. " (cached start room)...")
    pcall(_G.map.speedwalk, area.startRoomId)
    if area.description ~= "" then
      ce("(if that didn't work) Directions to " .. area.name .. ": " .. area.description)
    end
  elseif area.description ~= "" then
    ce("Directions to " .. area.name .. ": " .. area.description)
  end

  L.session.state = "paused"
  ce(area.name .. ": ready. 'mydsl leveling resume' when in position (buffs/food first if you want).")
end


------------------------------------------------------------------------
-- SECTION 6: INTERNAL-AREA STEPPING
------------------------------------------------------------------------
-- Raw direction-list replay is authoritative (matches proven community
-- data); map.speedwalk() is an opportunistic same-session upgrade for
-- hops already independently corroborated by the mapper, never the other
-- way around.

local function sendStep(token)
  for part in tostring(token):gmatch("[^;]+") do
    send(trim(part))
  end
end

-- report() -- a fuller end-of-run summary, per the maintainer ("give report like
-- in PNP") replacing the old one-line "pass complete. N killed, M xp."
-- Shown once, when a full lap of the area's dirs list completes (walking
-- + fighting the whole way through without stopping in between, exactly
-- as the maintainer asked -- "just keep walking and fighting till you get back
-- to the start point").
local function formatDuration(seconds)
  seconds = math.max(0, math.floor(seconds))
  local m = math.floor(seconds / 60)
  local s = seconds % 60
  return m .. "m " .. s .. "s"
end

function L.report()
  local s = L.session
  local area = L.areas[s.areaKey]
  local elapsed = s.stats.started and (os.time() - s.stats.started) or 0
  local perHour = (elapsed > 0) and math.floor(s.stats.xp / elapsed * 3600) or 0
  cecho("\n<cyan>[MyDSL.Leveling] ===== Leveling Report: " .. (area and area.name or s.areaKey) .. " =====<reset>\n"
    .. "  Duration: " .. formatDuration(elapsed) .. "\n"
    .. "  Killed:   " .. s.stats.killed .. "\n"
    .. "  XP:       " .. s.stats.xp .. "  (" .. perHour .. "/hr)\n"
    .. "<cyan>=========================================<reset>\n")
end

function L.processStep()
  local area = L.areas[L.session.areaKey]
  if not area then L.stop(); return end

  if L.session.stepIndex > #area.dirs then
    L.report()
    L.stop(true)
    return
  end

  local idx = L.session.stepIndex
  local cachedRoomId = area.roomPath[idx]
  local curRoomId = mapperRoomId()

  L.session.awaitingRoom = true
  L.session.stepIndex = idx + 1

  if cachedRoomId and curRoomId and _G.map and _G.getPath then
    local ok = pcall(_G.getPath, curRoomId, cachedRoomId)
    if ok and _G.map.speedwalk then
      _G.map.speedwalk(cachedRoomId)
      return
    end
  end

  sendStep(area.dirs[idx])
  -- Opportunistically cache this hop once the mapper confirms a new room.
  L._pendingCache = { stepIndex = idx, fromRoomId = curRoomId }
end

-- Called from the scan-event listener once a room's content has been
-- captured after a step -- opportunistically records the room id this
-- step landed in, for next pass's map.speedwalk() upgrade.
local function cacheStepArrival()
  if not L._pendingCache then return end
  local area = L.areas[L.session.areaKey]
  local roomId = mapperRoomId()
  if area and roomId then
    area.roomPath[L._pendingCache.stepIndex] = roomId
  end
  L._pendingCache = nil
end


------------------------------------------------------------------------
-- SECTION 7: MOB RECOGNITION (reuses MyDSL_DataLayer.lua's scan capture
-- -- no duplicate trigger chain)
------------------------------------------------------------------------
-- Fires on MyDSL.emit("scan"), called from MyDSL.endLook() -- anchored on
-- the same "[Exits: " line (confirmed: fires on every room reprint,
-- including after movement, not just a manual "look") that AlexK's own
-- original capture trigger used.
--
-- Shared-risk note (per the maintainer, 2026-07-19): this depends entirely on
-- MyDSL_DataLayer.lua's isUnparsedPresenceLine()/parseLookHereLine(),
-- hardened three separate times (2026-07-08/09) for charmed/summoned-
-- follower idle-line phrasing that kept evading enumeration, finally
-- generalized to "an article-led line is a skippable presence line"
-- rather than matching specific verbs. A leveling run generates far more
-- room-look volume than normal play, so it's the most likely place a
-- still-unseen edge case would surface. If a new gap shows up during
-- live testing, fix it at the shared DataLayer level (benefits every
-- module reading scan.rightHere), not with a local workaround here.
--
-- Ported off the deprecated MyDSL.on() API 2026-08-26, per the maintainer ("port
-- if it doesnt break anything") -- registerAnonymousEventHandler +
-- reading MyDSL.State.scan directly is the same standard pattern
-- MyDSL_CharacterAssist.lua's own "MyDSL.char.updated" handler already
-- uses (no positional event argument -- state is read straight from
-- MyDSL.State, matching Principle 3).
function MyDSL.Leveling.onScanUpdated()
  if not (L.session.state == "active" and L.session.awaitingRoom) then return end
  L.session.awaitingRoom = false
  cacheStepArrival()

  local area = L.areas[L.session.areaKey]
  if not area then return end

  -- REAL BUG, found live 2026-07-20 (the maintainer: "it did not engage the
  -- enemies", confirmed via a second test character's session log -- a full 12-step
  -- pass through "philosophy" completed with 0 kills despite every room
  -- showing real, enabled mobs, e.g. "(Golden Aura) A gnome student is
  -- here."). Root cause: `entry.raw` (MyDSL_DataLayer.lua's
  -- scan.rightHere) is the UNSTRIPPED original captured line, kept as-is
  -- for display/audit -- but the seed data's own mob.raw text was
  -- transcribed from a much older forum post with no aura tag, so a
  -- straight `mobDef.raw == entry.raw` comparison silently never matched
  -- ANY mob in a zone/moment with an active aura effect (confirmed real
  -- in the live transcript: literally every entity in the room, mount
  -- included, carried a "(Golden Aura)" prefix). Fixed by comparing
  -- against the same leading-tag-stripped text deriveLabel() already
  -- normalizes to, rather than the raw line verbatim.
  local scanState = MyDSL.State and MyDSL.State.scan
  L.session.mobsInRoom = {}
  for _, entry in pairs((scanState and scanState.rightHere) or {}) do
    if entry.is_mob then
      local stripped = stripLeadingTags(entry.raw)
      for mobKey, mobDef in pairs(area.mobs) do
        if mobDef.enabled and mobDef.raw == stripped then
          table.insert(L.session.mobsInRoom, mobKey)
        end
      end
    end
  end
  L.tryKill()
end
registerAnonymousEventHandler("MyDSL.scan.updated", "MyDSL.Leveling.onScanUpdated")


------------------------------------------------------------------------
-- SECTION 8: COMBAT LOOP
------------------------------------------------------------------------

-- REAL BUG, found live 2026-07-25, per the maintainer's own MyDSL-profile notes
-- ("target window not populating when im in combat, should become the
-- target im fighting, have all the mob info etc."). Confirmed against
-- this exact leveling session's own log (a second test character): zero Focus/TargetView
-- activity of any kind the whole run. Root cause: Leveling tracks its
-- own kill target entirely independently (L.session.pendingKillMobKey)
-- and never told the shared MyDSL.Target API about it -- so Focus never
-- learned what was being fought, even during real, successful combat.
-- Fixed by calling the same MyDSL.Target.set(name, is_mob, source) API
-- a manual click/target alias already uses (MyDSL_TargetView.lua) --
-- Focus's own existing auto-clear-on-death logic (keyed off
-- MyDSL.combat.died) should then handle clearing/advancing for free as
-- Leveling kills mobs one after another, no separate wiring needed here.
function L.tryKill()
  if L.session.state ~= "active" then return end
  if #L.session.mobsInRoom == 0 then
    L.session.pendingKillMobKey = nil
    L.processStep()
    return
  end
  local area = L.areas[L.session.areaKey]
  local mobKey = table.remove(L.session.mobsInRoom, 1)
  local mobDef = area.mobs[mobKey]
  L.session.pendingKillMobKey = mobKey
  if MyDSL.Target and MyDSL.Target.set and mobDef.label and mobDef.label ~= "" then
    pcall(MyDSL.Target.set, mobDef.label, true, "leveling")
  end
  if L.session.attackMode == "orderall" then
    send("order all kill " .. mobDef.kill_kw)
  else
    send("kill " .. mobDef.kill_kw)
  end
end

L._triggers.xpGain = tempRegexTrigger("^You receive (\\d+) experience points\\.$", function()
  if L.session.state ~= "active" then return end
  L.session.stats.xp = L.session.stats.xp + tonumber(matches[2])
  L.session.stats.killed = L.session.stats.killed + 1
  L.session.pendingKillMobKey = nil
  L.tryKill()
end)


------------------------------------------------------------------------
-- SECTION 9: INTERRUPTION HANDLING
------------------------------------------------------------------------
-- All corpus-confirmed real DSL text (grepped log/ directly, not
-- invented) -- see docs/DSL_CommandRef.md.

-- REDESIGNED 2026-07-20, per the maintainer ("also fix what you can... check
-- open combat issues"; "just keep walking and fighting till you get
-- back to the start point... we only need pause resume and stop, not a
-- fallback safety timer or whatever it is"): a flee used to stop the
-- whole run outright. Fleeing usually drops you in a random adjacent
-- room, which desyncs from the area's own fixed dirs list -- but per
-- the maintainer's own explicit "just keep going" preference, that's an
-- acceptable tradeoff (the worst case is a few harmless failed-move
-- messages until the path naturally reconverges or the player steps in
-- with pause/stop) rather than a hard stop on every flee.
L._triggers.fleeCombat = tempRegexTrigger("^You flee from combat!$", function()
  if L.session.state ~= "active" then return end
  ce("Fled from combat -- continuing.")
  L.session.pendingKillMobKey = nil
  L.session.mobsInRoom = {}
  L.session.awaitingRoom = false
  L.processStep()
end)

-- Guarded on pendingKillMobKey being set, since "They aren't here." is a
-- generic catch-all reused by other commands too. Finishes remaining
-- enabled mobs already found in this room before advancing (improves on
-- AlexK's "abandon room and move on" default).
L._triggers.killStolen = tempRegexTrigger(
  "^(Kill stealing is not permitted\\.|They aren't here\\.)$",
  function()
    if L.session.state ~= "active" or not L.session.pendingKillMobKey then return end
    L.session.pendingKillMobKey = nil
    L.tryKill()
  end)

L._triggers.cannotMove = tempRegexTrigger("^You cannot move while fighting!$", function()
  if L.session.state ~= "active" then return end
  tempTimer(2, function()
    if L.session.state == "active" then L.session.awaitingRoom = false; L.tryKill() end
  end)
end)

L._triggers.tooHeavy = tempRegexTrigger("^You are carrying too much to go anywhere\\.$", function()
  if L.session.state ~= "active" then return end
  send("drop 2000 silver")
  L.session.stepIndex = L.session.stepIndex - 1
  tempTimer(2, function()
    if L.session.state == "active" then L.processStep() end
  end)
end)

-- Optional reapply-on-wearoff, configured via "mydsl leveling buff".
local BUFF_WEAROFF = {
  fury     = "^The fury within you wears off%.$",
  haste    = "^You feel yourself slow down%.$",
  detects  = "^You feel less aware of your surroundings%.$",
  sanc     = "^The white aura around your body fades%.$",
}
for buffKey, pattern in pairs(BUFF_WEAROFF) do
  L._triggers["buffWearoff_" .. buffKey] = tempRegexTrigger(pattern, function()
    if L.session.state ~= "active" then return end
    local cmd = L.session.buffs[buffKey]
    if cmd and cmd ~= "" then send(cmd) end
  end)
end


------------------------------------------------------------------------
-- SECTION 10: HP SAFETY NET
------------------------------------------------------------------------
-- Extra layer on top of (not instead of) DSL's own wimpy. Cheap to build
-- since MyDSL.State.char.hp/.max_hp are already flowing (update("char",
-- ...) calls MyDSL.emit("char") on every gmcp.char_data event).
--
-- Ported off the deprecated MyDSL.on() API 2026-08-26, per the maintainer ("port
-- if it doesnt break anything") -- see onScanUpdated()'s comment above
-- for the same reasoning.
function MyDSL.Leveling.onCharUpdated()
  if L.session.state ~= "active" then return end
  if not L.session.hpThreshold or L.session.hpThreshold <= 0 then return end
  local charState = MyDSL.State and MyDSL.State.char
  local hp, maxHp = charState and charState.hp, charState and charState.max_hp
  if not hp or not maxHp or maxHp <= 0 then return end
  if (hp / maxHp * 100) < L.session.hpThreshold then
    ce("HP safety net: " .. hp .. "/" .. maxHp .. " below " .. L.session.hpThreshold .. "% -- stopping.")
    L.stop()
  end
end
registerAnonymousEventHandler("MyDSL.char.updated", "MyDSL.Leveling.onCharUpdated")


------------------------------------------------------------------------
-- SECTION 11: SESSION CONTROL
------------------------------------------------------------------------

function L.pause()
  if L.session.state ~= "active" then ce("Not running."); return end
  L.session.state = "paused"
  ce("Paused. 'mydsl leveling resume' to continue.")
end

function L.resume()
  if L.session.state ~= "paused" then ce("Nothing paused. 'mydsl leveling start <area>' first."); return end
  local area = L.areas[L.session.areaKey]
  if not area then ce("No active area."); return end
  -- Opportunistic room-id caching (moved here from the old two-step
  -- navigate/confirm flow, 2026-07-20) -- if the mapper happens to know
  -- where we are right now and this area has never had a start room
  -- cached, grab it for next time's speedwalk. Never blocks resuming
  -- either way.
  if not area.startRoomId then
    local roomId = mapperRoomId()
    if roomId then area.startRoomId = roomId; L.saveAreas() end
  end
  L.session.state = "active"
  L.session.stats.started = L.session.stats.started or os.time()
  ce("Resuming " .. area.name .. "...")
  L.session.awaitingRoom = false
  L.tryKill()
end

-- quiet=true skips the "Stopped." echo -- used when processStep() has
-- already shown a full end-of-run report (see SECTION 7) so the two
-- messages don't stack redundantly.
function L.stop(quiet)
  L.session.state = "stopped"
  L.session.awaitingRoom = false
  L.session.mobsInRoom = {}
  L.session.pendingKillMobKey = nil
  if not quiet then ce("Stopped.") end
end

function L.status()
  local s = L.session
  ce("State: " .. s.state)
  if s.areaKey then
    local area = L.areas[s.areaKey]
    ce("Area: " .. (area and area.name or s.areaKey) .. "  Step: " .. s.stepIndex
      .. (area and ("/" .. #area.dirs) or ""))
  end
  ce("Killed: " .. s.stats.killed .. "  XP: " .. s.stats.xp)
  if #s.mobsInRoom > 0 then ce("Mobs remaining in room: " .. #s.mobsInRoom) end
end


------------------------------------------------------------------------
-- SECTION 12: AREA MANAGEMENT COMMANDS
------------------------------------------------------------------------

-- REDESIGNED 2026-07-20, per the maintainer's own MyDSL-profile notes ("mydsl
-- leveling areas needs a cleaner display, it is very spaced out and
-- doesnt need the [MyDSL.Leveing] line start"): ce() prepends a blank
-- line and the "[MyDSL.Leveling]" tag to EVERY call, so calling it once
-- per row produced one blank-line-separated, re-tagged row per area --
-- for a ~39-row listing that's extremely spaced out. Now builds the
-- whole table as one string and echoes it once, with a single header
-- tag instead of one per row.
function L.listAreas()
  local names = {}
  for key, area in pairs(L.areas or {}) do table.insert(names, key) end
  table.sort(names)
  if #names == 0 then ce("No areas yet. 'mydsl leveling import' to load the seed data."); return end
  local rows = {}
  for _, key in ipairs(names) do
    local area = L.areas[key]
    local total, enabled = 0, 0
    for _, m in pairs(area.mobs) do total = total + 1; if m.enabled then enabled = enabled + 1 end end
    table.insert(rows, string.format("  %-16s  %-10s  %d/%d mobs enabled", key, area.levels or "?", enabled, total))
  end
  cecho("\n<cyan>[MyDSL.Leveling] Areas (" .. #names .. "):<reset>\n" .. table.concat(rows, "\n") .. "\n")
end

-- Same one-echo-block redesign as listAreas() above -- was one ce() call
-- per mob, spacing/re-tagging every single row.
function L.areaInfo(areaKey)
  local area = L.areas[areaKey]
  if not area then ce("No such area: " .. tostring(areaKey)); return end
  local keys = {}
  for k in pairs(area.mobs) do table.insert(keys, k) end
  table.sort(keys)
  local rows = {}
  for _, k in ipairs(keys) do
    local m = area.mobs[k]
    local danger = ""
    if MyDSL.CreatureLore and MyDSL.CreatureLore.knownState then
      local ok, state = pcall(MyDSL.CreatureLore.knownState, k)
      if ok and state then danger = "  [" .. tostring(state) .. "]" end
    end
    table.insert(rows, string.format("  %-10s %-6s %s%s", k, m.enabled and "on" or "off", m.label, danger))
  end
  local header = "\n<cyan>[MyDSL.Leveling] " .. area.name .. "  (" .. (area.levels or "Unknown.") .. ")<reset>\n"
  if area.description ~= "" then header = header .. "Directions: " .. area.description .. "\n" end
  cecho(header .. table.concat(rows, "\n") .. "\n")
end

function L.newArea(name)
  local key = normalizeName(name)
  if key == "" then ce("Usage: mydsl leveling area new <name>"); return end
  if L.areas[key] then ce("Area already exists: " .. key); return end
  L.areas[key] = { name = name, dirs = {}, mobs = {}, levels = "Unknown.", description = "",
    startRoomId = nil, roomPath = {}, source = "user" }
  L.saveAreas()
  ce("Created area: " .. key .. ". 'mydsl leveling scan' here to add mobs, "
    .. "'mydsl leveling area record start' to record the direction list.")
end

function L.deleteArea(name)
  local key = normalizeName(name)
  if not L.areas[key] then ce("No such area: " .. key); return end
  L.areas[key] = nil
  L.saveAreas()
  ce("Deleted area: " .. key)
end

-- "mydsl leveling scan" -- the "auto-fill mobs" ask. Reads the room
-- you're standing in right now from MyDSL.State.scan.rightHere and adds
-- any not-yet-known mobs to the target area (active session's area, or
-- an explicit second argument).
function L.scanMobs(areaKeyArg)
  local areaKey = areaKeyArg and normalizeName(areaKeyArg) or L.session.areaKey
  local area = areaKey and L.areas[areaKey]
  if not area then ce("Usage: mydsl leveling scan [area]  (or have an active area)"); return end
  local scan = MyDSL.State and MyDSL.State.scan
  if not scan then ce("No scan data yet -- look around first."); return end

  -- Stores/dedupes against the tag-stripped text, same reasoning as the
  -- scan-event mob-matching fix above -- otherwise a mob scanned while
  -- an aura/charmed tag happens to be active would get stored with that
  -- tag baked into its raw text, and silently stop matching the moment
  -- the tag isn't present (or vice versa).
  local added = 0
  for _, entry in pairs(scan.rightHere or {}) do
    if entry.is_mob then
      local stripped = stripLeadingTags(entry.raw)
      local already = false
      for _, m in pairs(area.mobs) do
        if m.raw == stripped then already = true; break end
      end
      if not already then
        local abbrev = entry.key:match("(%S+)$") or entry.key
        area.mobs[abbrev] = {
          raw = stripped, label = deriveLabel(stripped), kill_kw = commandArg(abbrev), enabled = true,
        }
        added = added + 1
      end
    end
  end
  L.saveAreas()
  ce("Added " .. added .. " new mob(s) to " .. area.name .. ".")
end

function L.setMobEnabled(areaKey, mobArg, enabled)
  local area = L.areas[normalizeName(areaKey)]
  if not area then ce("No such area: " .. tostring(areaKey)); return end
  if mobArg == "all" then
    for _, m in pairs(area.mobs) do m.enabled = enabled end
    L.saveAreas()
    ce((enabled and "Enabled" or "Disabled") .. " all mobs in " .. area.name .. ".")
    return
  end
  local mobDef = area.mobs[mobArg]
  if not mobDef then ce("No such mob '" .. tostring(mobArg) .. "' in " .. area.name); return end
  mobDef.enabled = enabled
  L.saveAreas()
  ce((enabled and "Enabled " or "Disabled ") .. mobArg .. " in " .. area.name .. ".")
end


------------------------------------------------------------------------
-- SECTION 13: COMMAND DISPATCHER
------------------------------------------------------------------------
-- Single catch-all alias + Lua dispatch, same pattern as
-- MyDSL_LocationView.lua's locationCommand()/M._cmd().

local function help()
  ce("mydsl leveling start <area> | resume | pause | stop | status")
  ce("mydsl leveling areas | area info <area> | area new <name> | area delete <name>")
  ce("mydsl leveling scan [area]  -- add mobs seen in the current room")
  ce("mydsl leveling show <area> <mob>|all | hide <area> <mob>|all")
  ce("mydsl leveling show | hide  -- window visibility")
  ce("mydsl leveling import  -- load the seed area data")
  ce("mydsl leveling hp <percent> | buff <fury|haste|detects|sanc> <cmd|off>")
  ce("mydsl leveling attackmode <direct|orderall>  -- 'kill <target>' vs 'order all kill <target>'")
end

local function command(rest)
  rest = trim(rest or "")
  if rest == "" or rest == "help" then help(); return end
  if rest == "import" then L.importSeedAreas(); return end
  if rest == "areas" then L.listAreas(); return end
  if rest == "status" then L.status(); return end
  if rest == "pause" then L.pause(); return end
  if rest == "resume" then L.resume(); return end
  if rest == "stop" then L.stop(); return end
  if rest == "show" then L.show(); return end
  if rest == "hide" then L.hide(); return end

  local startArea = rest:match("^start%s+(.+)$")
  if startArea then L.startArea(normalizeName(startArea)); return end

  local scanArea = rest:match("^scan%s*(.*)$")
  if scanArea ~= nil and rest:match("^scan") then L.scanMobs(scanArea ~= "" and scanArea or nil); return end

  if rest == "area new" then ce("Usage: mydsl leveling area new <name>"); return end
  local newName = rest:match("^area new%s+(.+)$"); if newName then L.newArea(newName); return end
  local delName = rest:match("^area delete%s+(.+)$"); if delName then L.deleteArea(delName); return end
  local infoName = rest:match("^area info%s+(.+)$"); if infoName then L.areaInfo(normalizeName(infoName)); return end

  local showArea, showMob = rest:match("^show%s+(%S+)%s+(%S+)$")
  if showArea then L.setMobEnabled(showArea, showMob, true); return end
  local hideArea, hideMob = rest:match("^hide%s+(%S+)%s+(%S+)$")
  if hideArea then L.setMobEnabled(hideArea, hideMob, false); return end

  local hp = rest:match("^hp%s+(%d+)$")
  if hp then L.session.hpThreshold = tonumber(hp); ce("HP safety threshold set to " .. hp .. "%."); return end

  local attackMode = rest:match("^attackmode%s+(%a+)$")
  if attackMode then
    if attackMode ~= "direct" and attackMode ~= "orderall" then
      ce("Usage: mydsl leveling attackmode <direct|orderall>")
      return
    end
    L.session.attackMode = attackMode
    ce("Attack mode set to " .. attackMode .. (attackMode == "orderall" and " (order all kill <target>)." or " (kill <target>)."))
    return
  end

  local buffName, buffCmd = rest:match("^buff%s+(%a+)%s+(.+)$")
  if buffName then
    if not BUFF_WEAROFF[buffName] then ce("Unknown buff: " .. buffName .. " (fury|haste|detects|sanc)"); return end
    L.session.buffs[buffName] = (buffCmd == "off") and nil or buffCmd
    ce("Buff " .. buffName .. " reapply " .. ((buffCmd == "off") and "cleared." or ("set to: " .. buffCmd)))
    return
  end

  ce("Unknown command. Try: mydsl leveling help")
end

function L._cmd(rest) command(rest) end

function L.makeAliases()
  if L.aliasesMade then return end
  L._aliases.main = tempAlias([[^mydsl leveling(?:\s+(.*))?$]], [[MyDSL.Leveling._cmd(matches[2])]])
  L.aliasesMade = true
end


------------------------------------------------------------------------
-- SECTION 14: BOOT
------------------------------------------------------------------------

-- Auto-seeds the area DB on a genuinely fresh profile (0 areas known) so
-- a new install doesn't need a manual "mydsl leveling import" first --
-- the maintainer, MyDSL Test/notes.json (2026-08-30): "called for a mydsl
-- leveling import. this should just be seeded in the install already."
-- Safe to call unconditionally on every boot: importSeedAreas() only
-- ever ADDS areas not already present (see its own comment above), and
-- this only fires when the count is 0, so a player who deleted every
-- area on purpose won't have them silently reappear on the next reload.
function L.boot()
  L.loadAreas()
  local count = 0
  for _ in pairs(L.areas or {}) do count = count + 1 end
  if count == 0 then
    L.importSeedAreas()
    for _ in pairs(L.areas or {}) do count = count + 1 end
  end
  L.ensureUI()
  L.makeAliases()
  echo("[MyDSL] Leveling loaded (" .. count .. " areas known).\n")
end

L.boot()
