-- Terrain/room-color corruption fix + "set once" manual-lock feature,
-- 2026-08-24, per Steven's direct report: "sometimes the mapper or
-- character is on the wrong location displayed on the map and it takes
-- the terrain of that room rather than its actual terrain... this needs
-- to get set once then have to be manually changed."
--
-- Two independent things verified here, both added to DSL_Generic_Mapper.xml:
--
-- 1. map.dsl.roomLooksStale(rid) -- detects the desync (map.currentRoom
--    stuck on the wrong room) by comparing a FRESH GMCP room name against
--    the candidate room's own stored name. applyRoomMetadata()/
--    onTerrainLine() must both skip writing terrain/sector/color data
--    entirely when this is true.
--
-- 2. dsl.terrain_locked room userdata -- once either auto-detection or the
--    new "rt"/"room terrain" alias successfully sets a room's terrain,
--    no later auto pass may change it again. Mirrors the existing
--    dsl.weight_source=="manual" guard for room weight.
--
-- Extraction technique matches test_mapper_gmcp_and_doorverb.lua exactly:
-- pull the real <script> body out of the git-tracked XML (not a
-- hand-copied paraphrase) and run it for real against real-behaving map
-- API mocks (test/mudlet_mock.lua's __rooms table).
--
-- Run: luajit test/test_mapper_terrain_lock.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local function xmlUnescape(s)
  s = s:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
       :gsub("&apos;", "'"):gsub("&#39;", "'")
  s = s:gsub("&amp;", "&")  -- must be last
  return s
end

local f = io.open("DSL_Generic_Mapper.xml", "r")
assert(f, "DSL_Generic_Mapper.xml not found -- run from the repo root")
local xml = f:read("*a")
f:close()

local scriptBody
for body in xml:gmatch("<script>(.-)</script>") do
  if body:find("dsl_long_dirs", 1, true) and body:find("setManualTerrain", 1, true) then
    scriptBody = body; break
  end
end
assert(scriptBody, "couldn't find the mapper's Map Script <script> block")
scriptBody = xmlUnescape(scriptBody)

local startIdx = scriptBody:find("function map.dsl.echo(msg)", 1, true)
local endIdx = scriptBody:find("function map.dsl.install", 1, true)
assert(startIdx and endIdx, "extraction anchors not found -- has DSL_Generic_Mapper.xml's source shape changed?")
local snippet = scriptBody:sub(startIdx, endIdx - 1)

map = map or {}
map.dsl = map.dsl or {}
map.roomexists = _G.roomexists

local chunk, loadErr = load(snippet, "mapper_extract")
check("extracted mapper source loads without a syntax error", chunk ~= nil and loadErr == nil)
if not chunk then print("  load error: " .. tostring(loadErr)); os.exit(1) end
local ok, runErr = pcall(chunk)
check("extracted mapper source runs without error", ok)
if not ok then print("  runtime error: " .. tostring(runErr)); os.exit(1) end

------------------------------------------------------------------------
-- Part 1: roomLooksStale()
------------------------------------------------------------------------
_G.__mock_defineRoom(100, "The Town Square")
_G.__mock_defineRoom(101, "A Dark Alley")

map.dsl.gmcp = { room_data = nil, room_data_time = nil }
check("no GMCP data at all -> not stale (must not block a normal move)",
  map.dsl.roomLooksStale(100) == false)

map.dsl.gmcp.room_data = { room = "The Town Square" }
map.dsl.gmcp.room_data_time = os.time()
check("fresh GMCP naming the SAME room as currentRoom -> not stale",
  map.dsl.roomLooksStale(100) == false)

map.dsl.gmcp.room_data = { room = "A Dark Alley" }
map.dsl.gmcp.room_data_time = os.time()
check("fresh GMCP naming a DIFFERENT room than currentRoom -> stale (the real bug)",
  map.dsl.roomLooksStale(100) == true)

map.dsl.gmcp.room_data = { room = "A Dark Alley" }
map.dsl.gmcp.room_data_time = os.time() - 999
check("STALE (too-old) GMCP payload -> not flagged as a room desync (must not false-positive on lag)",
  map.dsl.roomLooksStale(100) == false)

-- Real corpus-confirmed case (8 occurrences in log/): GMCP reports the
-- literal string "darkness" when the room is too dark to see its name --
-- never a real room's actual name. Must not be treated as a mismatch.
map.dsl.gmcp.room_data = { room = "darkness" }
map.dsl.gmcp.room_data_time = os.time()
check("GMCP's 'darkness' placeholder is never treated as a name mismatch",
  map.dsl.roomLooksStale(100) == false)

------------------------------------------------------------------------
-- Part 2: applyRoomMetadata() -- corruption guard + set-once lock
------------------------------------------------------------------------
_G.__mock_defineRoom(200, "A Sunny Field")
map.currentRoom = 200
map.dsl.gmcp = {
  room_data = { room = "A Sunny Field", sector = "Open fields." },
  room_data_time = os.time(),
}
map.dsl.last_terrain_text = nil
map.dsl.applyRoomMetadata()
check("first real pass sets normalized_sector", getRoomUserData(200, "dsl.normalized_sector") == "field")
check("first real pass locks the room", getRoomUserData(200, "dsl.terrain_locked") == "true")
check("first real pass colors the room", getRoomEnv(200) ~= 0)

-- Second visit: GMCP now (wrongly, or just differently) claims a
-- different sector for the SAME room -- locked, must not change.
map.dsl.gmcp.room_data = { room = "A Sunny Field", sector = "Dense forest." }
map.dsl.gmcp.room_data_time = os.time()
map.dsl.applyRoomMetadata()
check("locked room's sector is NOT overwritten by a later auto pass",
  getRoomUserData(200, "dsl.normalized_sector") == "field")

-- A fresh, never-visited room + a stale GMCP mismatch: must skip
-- entirely, including the base bookkeeping fields.
_G.__mock_defineRoom(201, "An Unrelated Room")
map.currentRoom = 201
map.dsl.gmcp = {
  room_data = { room = "Somewhere Else Entirely", sector = "Icy tundra." },
  room_data_time = os.time(),
}
map.dsl.applyRoomMetadata()
check("stale/desynced currentRoom gets NO sector data written at all",
  getRoomUserData(201, "dsl.normalized_sector") == "")

-- Real functional benefit of not treating "darkness" as a mismatch: a
-- room visited only in the dark should still get colored from rd.sector
-- (corpus-confirmed sector keeps reporting correctly even when the name
-- doesn't).
_G.__mock_defineRoom(202, "A Dark Cellar")
map.currentRoom = 202
map.dsl.gmcp = {
  room_data = { room = "darkness", sector = "Underground tunnels." },
  room_data_time = os.time(),
}
map.dsl.applyRoomMetadata()
check("a room visited while dark still gets colored via rd.sector",
  getRoomUserData(202, "dsl.normalized_sector") == "underground")
check("stale/desynced currentRoom is not locked either (nothing was set)",
  getRoomUserData(201, "dsl.terrain_locked") ~= "true")

------------------------------------------------------------------------
-- Part 3: onTerrainLine() -- the function Steven's report implicated most
------------------------------------------------------------------------
_G.__mock_defineRoom(300, "A Mountain Pass")
map.currentRoom = 300
map.dsl.gmcp = { room_data = nil, room_data_time = nil }
map.dsl.onTerrainLine("You are surrounded by huge mountains.")
check("onTerrainLine sets sector on first real call", getRoomUserData(300, "dsl.normalized_sector") == "mountain")
check("onTerrainLine locks the room on first real call", getRoomUserData(300, "dsl.terrain_locked") == "true")

map.dsl.onTerrainLine("You are wading through a swamp.")
check("onTerrainLine does NOT overwrite an already-locked room",
  getRoomUserData(300, "dsl.normalized_sector") == "mountain")

-- The exact reported scenario: player types "terrain" but map.currentRoom
-- is stuck on the wrong (stale) room per fresh GMCP.
_G.__mock_defineRoom(301, "A Room Never Actually Entered")
map.currentRoom = 301
map.dsl.gmcp = {
  room_data = { room = "The Actual Room The Player Is In" },
  room_data_time = os.time(),
}
map.dsl.onTerrainLine("You are wading through a swamp.")
check("onTerrainLine skips writing anything onto a stale/desynced room",
  getRoomUserData(301, "dsl.terrain_text") == "")

------------------------------------------------------------------------
-- Part 4: setManualTerrain() -- backs the "rt"/"room terrain" alias
------------------------------------------------------------------------
_G.__mock_defineRoom(400, "A Test Room")
local ok1, sector1 = map.dsl.setManualTerrain(400, "desert")
check("setManualTerrain accepts a known sector name", ok1 == true and sector1 == "desert")
check("setManualTerrain writes the sector", getRoomUserData(400, "dsl.normalized_sector") == "desert")
check("setManualTerrain marks the source manual", getRoomUserData(400, "dsl.sector_source") == "manual")
check("setManualTerrain locks the room", getRoomUserData(400, "dsl.terrain_locked") == "true")
check("setManualTerrain actually applies the color", getRoomEnv(400) ~= 0)

local ok2, msg2 = map.dsl.setManualTerrain(400, "not_a_real_sector")
check("setManualTerrain rejects an unknown sector name", ok2 == false and type(msg2) == "string")
check("locked room's sector is unaffected by the rejected call", getRoomUserData(400, "dsl.normalized_sector") == "desert")

-- Manual command must still be able to override an ALREADY-locked room
-- (it's the one path that's supposed to be able to).
local ok3, sector3 = map.dsl.setManualTerrain(400, "ice")
check("a second manual call can still override an already-locked room", ok3 == true and sector3 == "ice")
check("the override actually took", getRoomUserData(400, "dsl.normalized_sector") == "ice")

------------------------------------------------------------------------
-- Part 5: announceAreaChange() -- per Steven's MyDSL notes 2026-08-24
-- ("mapper should announce entering/exiting a named area map").
------------------------------------------------------------------------
local echoed = {}
local realCecho = _G.cecho
_G.cecho = function(s) echoed[#echoed + 1] = s; return realCecho(s) end

_G.__mock_defineRoom(500, "First Room Ever")
_G.setRoomArea(500, 10)
_G.setAreaName(10, "Althainia")
map.dsl.last_area_id = nil  -- fresh session, no prior area known
map.dsl.announceAreaChange(500)
check("no banner on the very first room of a session (nothing to compare against)",
  #echoed == 0)
check("last_area_id is still recorded after the first room", map.dsl.last_area_id == 10)

_G.__mock_defineRoom(501, "Still In Althainia")
_G.setRoomArea(501, 10)
map.dsl.announceAreaChange(501)
check("no banner when the area hasn't actually changed", #echoed == 0)

_G.__mock_defineRoom(502, "Death's Corridor Entrance")
_G.setRoomArea(502, 20)
_G.setAreaName(20, "Death's Corridor")
map.dsl.announceAreaChange(502)
check("a real area change produces exactly one banner", #echoed == 1)
check("the banner names both the new and the old area",
  echoed[1]:find("Death's Corridor", 1, true) ~= nil and echoed[1]:find("Althainia", 1, true) ~= nil)

echoed = {}
_G.__mock_defineRoom(503, "An Unassigned Room")
_G.setRoomArea(503, -1)
map.dsl.announceAreaChange(503)
check("a room with no assigned area (-1) never triggers a banner", #echoed == 0)

_G.cecho = realCecho

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
