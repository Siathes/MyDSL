-- Regression test for DSL_Mapper_Addon.xml, added 2026-08-29 (standalone-
-- mapper design pass -- see docs/MAPPER_REDESIGN.md). This file is the
-- genuinely standalone distributable: no bundled copy of Mudlet's own
-- generic_mapper.xml, just the DSL-specific layer + 2 bug-fix overrides
-- + an update-disabling override, all reassigned onto real global map.*
-- functions from OUTSIDE stock's source.
--
-- What this test focuses on (the genuinely new/risky part -- the DSL
-- layer content itself is a verbatim copy of DSL_Generic_Mapper.xml's
-- own already-tested source, not re-verified here):
-- 1. The addon loads without a syntax error.
-- 2. map.dsl.installAddonOverrides() -- called from inside install(),
--    NOT at bare top-level script scope (a real load-order bug caught
--    and fixed before shipping: reassigning map.checkVersion/map.
--    echoPath/etc. at top level could race stock's own script load and
--    get silently clobbered) -- actually reassigns all 5 target
--    functions when it runs.
-- 3. The reassigned map.echoPath()/map.export_area()/map.import_area()
--    carry the same real bug fixes already tested in
--    test_mapper_echopath_nil_guard.lua / test_mapper_area_hash_preservation.lua
--    -- proving the addon's copy is the fixed version, not stock's
--    original buggy one.
-- 4. map.checkVersion()/map.updateVersion() are neutralized (no native
--    download/reinstall behavior fires).
--
-- Run: luajit test/test_dsl_mapper_addon.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Extract the real addon script from DSL_Mapper_Addon.xml
------------------------------------------------------------------------
local function xmlUnescape(s)
  s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
       :gsub("&apos;", "'"):gsub("&#39;", "'")
  s = s:gsub("&amp;", "&")  -- must be last
  return s
end

local f = io.open("DSL_Mapper_Addon.xml", "r")
assert(f, "DSL_Mapper_Addon.xml not found -- run from the repo root")
local xml = f:read("*a")
f:close()

local scriptBody = xml:match("<script>(.-)</script>")
assert(scriptBody, "couldn't find DSL_Mapper_Addon.xml's <script> block")
scriptBody = xmlUnescape(scriptBody)

------------------------------------------------------------------------
-- Minimal sandbox. tempTimer here just needs to not crash (the
-- dependency check schedules one at load time) -- mudlet_mock.lua
-- already provides a real tempTimer mock.
------------------------------------------------------------------------
map = map or {}
map.configs = { debug = false }
map.dsl = map.dsl or {}
function map.echo(msg) end
local searchRoomResults = { [1] = "Town Square", [2] = "Market" }
function _G.searchRoom(id) return searchRoomResults[id] end
function _G.getPath(a, b) return true end
_G.speedWalkDir = {}
function _G.getAreaTable() return {} end
function _G.getAreaRooms() return {} end
function _G.show_err(msg) end
table.contains = table.contains or function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
table.is_empty = table.is_empty or function(t) return next(t) == nil end
table.save = table.save or function() return true end
table.load = table.load or function() end
-- Deliberately NOT stubbing _G.profilePath here (was removed 2026-08-30):
-- doing so papered over a real bug where the addon referenced profilePath
-- without ever defining it -- silently broke logDesync() from the moment
-- it was added, since a real Mudlet run has no such global. The addon
-- now defines its own `local profilePath = getMudletHomeDir()`; leaving
-- no global stub here means a regression back to relying on an
-- undefined/external profilePath would show up as a real test failure
-- (see the logDesync() file-write test below), not silently pass.

local chunk, loadErr = load(scriptBody, "dsl_mapper_addon")
check("DSL_Mapper_Addon.xml's script loads without a syntax error", chunk ~= nil and loadErr == nil)
if not chunk then print("  load error: " .. tostring(loadErr)) end

if chunk then
  local ok, runErr = pcall(chunk)
  check("addon script runs without error at load time", ok)
  if not ok then print("  runtime error: " .. tostring(runErr)) end
end

if map.dsl and map.dsl.installAddonOverrides then
  ------------------------------------------------------------------------
  -- Before installAddonOverrides() runs: map.echoPath etc. don't exist
  -- yet in this sandbox (nothing defined them -- we never loaded a real
  -- stock generic_mapper here, matching how this addon assumes stock is
  -- ALREADY loaded by the time install() actually fires for real).
  ------------------------------------------------------------------------
  check("map.echoPath not yet defined before overrides run", map.echoPath == nil)

  local ok = pcall(map.dsl.installAddonOverrides)
  check("installAddonOverrides() runs without error", ok)

  check("map.echoPath got reassigned", type(map.echoPath) == "function")
  check("map.export_area got reassigned", type(map.export_area) == "function")
  check("map.import_area got reassigned", type(map.import_area) == "function")
  check("map.checkVersion got neutralized", type(map.checkVersion) == "function")
  check("map.updateVersion got reassigned to map.dsl.updateDisabled",
    map.updateVersion == map.dsl.updateDisabled)

  ------------------------------------------------------------------------
  -- Prove the reassigned echoPath carries the real nil-guard fix, not
  -- stock's original crash-on-missing-room behavior.
  ------------------------------------------------------------------------
  local ok2, err2 = pcall(map.echoPath, 1, 999)  -- room 999 doesn't exist in searchRoomResults
  check("reassigned map.echoPath doesn't crash on a missing room (the real fix)", ok2)
  if not ok2 then print("  error: " .. tostring(err2)) end

  ------------------------------------------------------------------------
  -- Prove checkVersion() doesn't attempt any native download behavior --
  -- just confirm it's callable and returns without erroring (it's now a
  -- true no-op).
  ------------------------------------------------------------------------
  local ok3 = pcall(map.checkVersion)
  check("neutralized map.checkVersion() runs without error", ok3)
end

------------------------------------------------------------------------
-- Install-welcome / uninstall-cleanup handler, added 2026-08-29 per
-- Mudlet's own documented package best practices. Must be a real GLOBAL
-- function -- registerAnonymousEventHandler looks its second argument
-- up by name in _G; a `local function` here would silently never be
-- found or called (a real bug caught and fixed before shipping).
------------------------------------------------------------------------
check("install/uninstall handler is a real global function (not local -- would silently never fire)",
  type(_G.dslMapperAddonInstallUninstallHandler) == "function")

if type(_G.dslMapperAddonInstallUninstallHandler) == "function" then
  local removeMapEventCalls = {}
  _G.removeMapEvent = function(name) removeMapEventCalls[#removeMapEventCalls + 1] = name; return true end

  local ok4 = pcall(_G.dslMapperAddonInstallUninstallHandler, "sysInstallPackage", "DSL_Mapper_Addon")
  check("sysInstallPackage handler runs without error", ok4)

  local ok5 = pcall(_G.dslMapperAddonInstallUninstallHandler, "sysInstallPackage", "SomeOtherPackage")
  check("sysInstallPackage for a DIFFERENT package doesn't error either (ignored, not mismatched)", ok5)

  map.dsl.registeredEvents = {111, 222}
  local killedIds = {}
  _G.killAnonymousEventHandler = function(id) killedIds[#killedIds + 1] = id; return true end

  local ok6 = pcall(_G.dslMapperAddonInstallUninstallHandler, "sysUninstallPackage", "DSL_Mapper_Addon")
  check("sysUninstallPackage handler runs without error", ok6)
  check("uninstall killed both registered event handlers",
    #killedIds == 2 and killedIds[1] == 111 and killedIds[2] == 222)
  check("uninstall called removeMapEvent to clean up the Safe Delete menu item",
    #removeMapEventCalls == 1 and removeMapEventCalls[1] == "dslSafeDelete")
end

------------------------------------------------------------------------
-- syncRoomDescription() -- added 2026-08-30, the actual fix Steven asked
-- for after the use_description_matching-off workaround: keep every
-- visited room's stored description CURRENT, so stock's own check_room()
-- (which only ever writes a room's description once, never updates it)
-- can't accumulate the drift that caused the original permanent-lockout
-- bug. Uses mudlet_mock.lua's real __rooms-backed getRoomUserData/
-- setRoomUserData/roomexists, not a reinvented mock.
------------------------------------------------------------------------
if map.dsl and map.dsl.syncRoomDescription then
  _G.__rooms[1] = { exists = true, userdata = {} }
  _G.__rooms[2] = { exists = true, userdata = {} }
  -- map.roomexists is stock's own wrapper (real at runtime, confirmed via
  -- the live installed profile's alias code), not native `roomexists` --
  -- mudlet_mock.lua only mocks the native one, so mock this one too.
  map.roomexists = function(id) return _G.roomexists(id) == 1 end

  map.currentRoom = 1
  map.prompt = { description = "A quiet square with a fountain." }
  map.dsl.syncRoomDescription()
  check("syncRoomDescription() writes the captured description onto the current room",
    getRoomUserData(1, "description") == "A quiet square with a fountain.")

  setRoomUserData(1, "description", "A STALE description from months ago.")
  map.prompt.description = "A quiet square with a fountain."
  map.dsl.syncRoomDescription()
  check("syncRoomDescription() overwrites a drifted stored description with the current capture (the actual self-heal)",
    getRoomUserData(1, "description") == "A quiet square with a fountain.")

  map.currentRoom = 999  -- doesn't exist
  local ok8 = pcall(map.dsl.syncRoomDescription)
  check("syncRoomDescription() on a nonexistent room doesn't error", ok8)

  if map.dsl.onGenericNewRoom then
    map.currentRoom = 2
    map.prompt.description = "A bustling market full of vendors."
    map.dsl.applyRoomMetadata = map.dsl.applyRoomMetadata or function() end
    map.dsl.announceAreaChange = map.dsl.announceAreaChange or function() end
    local ok9 = pcall(map.dsl.onGenericNewRoom)
    check("onGenericNewRoom() runs without error and calls syncRoomDescription internally", ok9)
    check("onGenericNewRoom() actually synced the description for the newly-resolved room",
      getRoomUserData(2, "description") == "A bustling market full of vendors.")
  end
end

------------------------------------------------------------------------
-- use_description_matching default -- REVERSED 2026-08-30 after Steven's
-- own live `map debug` trace showed EVERY automatic room resolution
-- failing with "Room N rejected: description mismatch" on ordinary,
-- correctly name+exits-matched moves (the real cause of "mapper not
-- following"). Confirms install() no longer forces this on for a fresh
-- profile (map.configs.dsl_generic_mapper_seen not yet set) -- a
-- regression back to `true` here would silently reintroduce the same
-- permanent-lockout bug on the next fresh install.
------------------------------------------------------------------------
if map.dsl and map.dsl.install then
  map.configs = { debug = false }  -- fresh profile: dsl_generic_mapper_seen not set
  local ok7 = pcall(map.dsl.install)
  check("install() runs without error", ok7)
  check("use_description_matching defaults to false on a fresh profile (was true, confirmed root cause of the desync)",
    map.configs.use_description_matching == false)
  check("install() marks the profile seen so this default-setting block doesn't re-run",
    map.configs.dsl_generic_mapper_seen == true)
end

------------------------------------------------------------------------
-- applySectorColor()/applyRoomMetadata() terrain-lock fix -- added
-- 2026-08-30 per Steven ("mapper isnt applying the terrain color on
-- first build or revisits. see red boxes on mini map instead of
-- forest"). Real bug: applyRoomMetadata() used to lock a room's terrain
-- as "done" based on whether the sector STRING normalized to something
-- recognized, not whether applySectorColor() actually succeeded at
-- coloring it -- so a room that hit a silent setRoomEnv() failure got
-- permanently locked in its broken (uncolored/default-red) state, with
-- no future visit ever able to retry it. applySectorColor() now returns
-- true/false for real success, and the lock only gets written on true.
------------------------------------------------------------------------
if map.dsl and map.dsl.applySectorColor then
  _G.__rooms[10] = { exists = true, userdata = {}, env = 0 }
  map.roomexists = map.roomexists or function(id) return _G.roomexists(id) == 1 end

  check("applySectorColor() returns true and colors a recognized sector",
    map.dsl.applySectorColor(10, "forest") == true and getRoomEnv(10) == 23)

  check("applySectorColor() returns false for an unrecognized sector string (no envID match)",
    map.dsl.applySectorColor(10, "some_weird_unmapped_text") == false)

  check("applySectorColor() returns false for sector == 'unknown'",
    map.dsl.applySectorColor(10, "unknown") == false)

  if map.dsl.applyRoomMetadata then
    -- Simulate the real failure mode: GMCP room_data present and fresh,
    -- but its sector text doesn't normalize to anything this addon
    -- recognizes -- applySectorColor() will return false, and the room
    -- must NOT get terrain-locked, so a later visit (once the real cause
    -- is fixed, or GMCP sends something recognizable) can still retry it.
    _G.__rooms[11] = { exists = true, userdata = {}, env = 0 }
    map.currentRoom = 11
    map.dsl.gmcp = { room_data = { sector = "totally_unrecognized_sector_text" }, room_data_time = os.time() }
    map.dsl.applyRoomMetadata()
    check("a room whose sector never resolves to a real color does NOT get terrain-locked",
      getRoomUserData(11, "dsl.terrain_locked") ~= "true")

    -- Now the success path: a real, recognized sector should both color
    -- the room AND lock it, same as before this fix for the case that
    -- actually works.
    _G.__rooms[12] = { exists = true, userdata = {}, env = 0 }
    map.currentRoom = 12
    map.dsl.gmcp = { room_data = { sector = "forest" }, room_data_time = os.time() }
    map.dsl.applyRoomMetadata()
    check("a room with a real recognized sector gets colored", getRoomEnv(12) == 23)
    check("a room with a real recognized sector DOES get terrain-locked (unchanged success-path behavior)",
      getRoomUserData(12, "dsl.terrain_locked") == "true")
  end
end

------------------------------------------------------------------------
-- logDesync() actually writes a real file -- added 2026-08-30, the
-- regression test for the profilePath bug fixed above. Without a real
-- getMudletHomeDir()-derived path, this would have silently no-op'd
-- (pcall around io.open swallowing "attempt to concatenate a nil
-- value") for this addon's entire lifetime and nobody would have known
-- until a live report came back with an empty log file.
------------------------------------------------------------------------
if map.dsl and map.dsl.logDesync then
  local logPath = getMudletHomeDir() .. "/mapper_desync_log.txt"
  os.remove(logPath)
  map.dsl.logDesync("test marker line")
  local f = io.open(logPath, "r")
  check("logDesync() actually creates mapper_desync_log.txt at a real, resolvable path", f ~= nil)
  if f then
    local content = f:read("*a")
    f:close()
    check("logDesync() writes the message content", content:find("test marker line", 1, true) ~= nil)
  end
  os.remove(logPath)
end

------------------------------------------------------------------------
-- Event-handler calling convention -- added 2026-08-30, real bug found
-- via Steven ("i also dont see players near you highlighting on the
-- map"). Mudlet ALWAYS passes the event name as a handler's first
-- argument (confirmed against wiki.mudlet.org's Event Engine manual,
-- for both custom raiseEvent()s and built-in system events) --
-- captureCommand() and highlightPlayersNear() were both missing that
-- leading parameter, silently catching the event name string in what
-- should have been their real data argument. This is exactly the class
-- of bug direct unit tests exist to catch -- neither had one before.
------------------------------------------------------------------------
if map.dsl and map.dsl.captureCommand then
  map.dsl.last_command = nil
  map.dsl.captureCommand("sysDataSendRequest", "north")
  check("captureCommand(event, cmd) reads the real command from the SECOND argument, not the event name",
    map.dsl.last_command == "north")
end

if map.dsl and map.dsl.highlightPlayersNear then
  _G.__rooms[20] = { exists = true, userdata = {}, name = "Town Square" }
  _G.__rooms[21] = { exists = true, userdata = {}, name = "Market" }
  local roomsByName = { ["Town Square"] = { [20] = "Town Square" }, ["Market"] = { [21] = "Market" } }
  _G.searchRoom = function(name) return roomsByName[name] or {} end
  local highlightCalls = {}
  _G.highlightRoom = function(rid, fgr, fgg, fgb, bgr, bgg, bgb, radius, a1, a2)
    highlightCalls[#highlightCalls + 1] = { rid = rid, radius = radius, alpha = a1 }
    return true
  end
  local unhighlightCalls = {}
  _G.unHighlightRoom = function(rid) unhighlightCalls[#unhighlightCalls + 1] = rid; return true end
  map.dsl.player_highlights = {}

  map.dsl.highlightPlayersNear("MyDSL.playersNear.parsed", { { name = "Someone", room = "Town Square" } })
  check("highlightPlayersNear(event, list) reads the real list from the SECOND argument, not the event name",
    #highlightCalls == 1 and highlightCalls[1].rid == 20)
  -- Real bug found 2026-08-30 via a live screenshot (Steven: "the
  -- markers yellow circles... are to large"): radius is a multiplier of
  -- the room's own on-screen width (confirmed against Mudlet's real
  -- T2DMap.cpp source: roomRadius = highlightRadius * mRoomWidth / 2.0),
  -- not pixels -- the old value (25) meant a 12.5-room-width radius,
  -- swallowing whole screenfuls of the map. Locks in a sane radius
  -- (comparable to a single room's own size) so a future regression
  -- back to an oversized constant fails this test instead of only
  -- showing up live.
  check("highlight radius is comparable to one room's own size, not dozens of room-widths",
    highlightCalls[1].radius ~= nil and highlightCalls[1].radius > 0 and highlightCalls[1].radius <= 3)

  -- ---- follow + fade, added 2026-08-30 per Steven's own follow-up
  -- ("they should also follow to the rooms for their specidifc temporary
  -- tracking of the players location, but fade when they leave the
  -- area") -----------------------------------------------------------
  highlightCalls, unhighlightCalls = {}, {}
  map.dsl.highlightPlayersNear("MyDSL.playersNear.parsed", { { name = "Someone", room = "Market" } })
  check("a tracked player's highlight follows them to their new room on the next poll",
    #highlightCalls == 1 and highlightCalls[1].rid == 21 and highlightCalls[1].alpha == 150)
  check("the old room's highlight is cleared when following to the new one",
    #unhighlightCalls >= 1 and unhighlightCalls[1] == 20)

  highlightCalls, unhighlightCalls = {}, {}
  map.dsl.highlightPlayersNear("MyDSL.playersNear.parsed", {})  -- player dropped out of this poll
  check("a player missing from one poll gets redrawn at reduced alpha (fading), not removed outright",
    #highlightCalls == 1 and highlightCalls[1].rid == 21 and highlightCalls[1].alpha == 60)
  check("still tracked internally while fading", map.dsl.player_highlights["Someone"] ~= nil)

  highlightCalls, unhighlightCalls = {}, {}
  map.dsl.highlightPlayersNear("MyDSL.playersNear.parsed", {})  -- missing a SECOND consecutive poll
  check("a player missing from a second consecutive poll is actually removed",
    #highlightCalls == 0 and map.dsl.player_highlights["Someone"] == nil)
  check("the faded room's highlight is cleared on final removal", #unhighlightCalls >= 1)
end

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
