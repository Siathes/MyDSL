-- Regression test for map.dsl.safeDelete(), added 2026-08-29 (standalone-
-- mapper design pass -- see docs/MAPPER_REDESIGN.md). Ported/adapted from
-- the mapaddons-safe-delete community package: confirmed 2026-08-29 that
-- none of this file's own deleteRoom() call sites converted OTHER rooms'
-- now-dangling incoming exits into stubs -- a deleted room silently left
-- neighboring rooms pointing at a room ID that no longer exists.
--
-- Extracts the REAL current map.dsl.safeDelete() straight out of the
-- git-tracked DSL_Generic_Mapper.xml (not a hand-copied paraphrase) and
-- exercises: a room with one incoming exit (gets stubbed), a room with
-- multiple incoming exits from different directions (all get stubbed),
-- and a room with no incoming exits (deletes cleanly, nothing to stub).
--
-- Run: luajit test/test_mapper_safe_delete.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Extract the real map.dsl.safeDelete() source between two anchors
------------------------------------------------------------------------
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
  if body:find("function map.dsl.safeDelete", 1, true) then scriptBody = body; break end
end
assert(scriptBody, "couldn't find the mapper's Map Script <script> block")
scriptBody = xmlUnescape(scriptBody)

local startIdx = scriptBody:find("function map.dsl.safeDelete(ids)", 1, true)
local endIdx = scriptBody:find("registerAnonymousEventHandler(\"mapAddOnEvent\"", 1, true)
assert(startIdx and endIdx, "extraction anchors not found -- has DSL_Generic_Mapper.xml's source shape around safeDelete changed?")
local snippet = scriptBody:sub(startIdx, endIdx - 1)

------------------------------------------------------------------------
-- Minimal sandbox: a fake room/exit graph, real getAllRoomEntrances/
-- getRoomExits/deleteRoom/setExitStub/updateMap mocks.
------------------------------------------------------------------------
map = map or {}
map.dsl = map.dsl or {}

local __rooms = {}       -- id -> { exits = {dir -> id} }
local __deleted = {}
local __stubsSet = {}    -- {roomId, dir} pairs, order preserved
local __updateMapCalls = 0

function _G.getAllRoomEntrances(id)
  local out = {}
  for rid, r in pairs(__rooms) do
    if not __deleted[rid] then
      for _, exit in pairs(r.exits) do
        if exit == id then out[#out + 1] = rid; break end
      end
    end
  end
  return out
end

function _G.getRoomExits(id)
  return (__rooms[id] and __rooms[id].exits) or {}
end

function _G.deleteRoom(id)
  __deleted[id] = true
end

function _G.setExitStub(id, dir, on)
  __stubsSet[#__stubsSet + 1] = {id, dir, on}
end

function _G.updateMap()
  __updateMapCalls = __updateMapCalls + 1
end

local chunk, loadErr = load(snippet, "safedelete_extract")
check("extracted map.dsl.safeDelete source loads without a syntax error", chunk ~= nil and loadErr == nil)
if chunk then
  local ok, runErr = pcall(chunk)
  check("extracted source runs without error (defines map.dsl.safeDelete)", ok)
  if not ok then print("  runtime error: " .. tostring(runErr)) end
end

if map.dsl.safeDelete then
  ------------------------------------------------------------------------
  -- Case 1: room 20 has exactly one incoming exit, from room 10 (north)
  ------------------------------------------------------------------------
  __rooms = {
    [10] = { exits = { north = 20 } },
    [20] = { exits = { south = 10 } },
  }
  __deleted, __stubsSet, __updateMapCalls = {}, {}, 0

  local ok = pcall(map.dsl.safeDelete, {20})
  check("single-incoming-exit delete runs without error", ok)
  check("room 20 was really deleted", __deleted[20] == true)
  check("room 10's north exit got stubbed instead of left dangling",
    #__stubsSet == 1 and __stubsSet[1][1] == 10 and __stubsSet[1][2] == "north" and __stubsSet[1][3] == true)
  check("updateMap() was called", __updateMapCalls == 1)

  ------------------------------------------------------------------------
  -- Case 2: room 30 has incoming exits from TWO different rooms/directions
  ------------------------------------------------------------------------
  __rooms = {
    [1] = { exits = { east = 30 } },
    [2] = { exits = { west = 30 } },
    [30] = { exits = { west = 1, east = 2 } },
  }
  __deleted, __stubsSet, __updateMapCalls = {}, {}, 0

  local ok2 = pcall(map.dsl.safeDelete, {30})
  check("multi-incoming-exit delete runs without error", ok2)
  check("room 30 was really deleted", __deleted[30] == true)
  local stubbed = {}
  for _, s in ipairs(__stubsSet) do stubbed[s[1] .. ":" .. s[2]] = s[3] end
  check("both incoming exits (room 1 east, room 2 west) got stubbed",
    stubbed["1:east"] == true and stubbed["2:west"] == true)

  ------------------------------------------------------------------------
  -- Case 3: room 99 has NO incoming exits -- deletes cleanly, no stubs
  ------------------------------------------------------------------------
  __rooms = { [99] = { exits = {} } }
  __deleted, __stubsSet, __updateMapCalls = {}, {}, 0

  local ok3 = pcall(map.dsl.safeDelete, {99})
  check("no-incoming-exits delete runs without error", ok3)
  check("room 99 was really deleted", __deleted[99] == true)
  check("nothing got stubbed (nothing pointed at it)", #__stubsSet == 0)
end

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
