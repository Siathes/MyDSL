-- Regression test for map.export_area()/map.import_area()'s room-hash
-- preservation, added 2026-08-29 -- ported from upstream generic_mapper.xml
-- 2.1.10 (Mudlet PR #9364, "sharing an area from the generic mapper now
-- carries its room hashes"). Our fork was forked from upstream 2.1.8,
-- before this landed, so an exported/imported area used to arrive
-- hashless every time -- a real problem since DSL identifies the current
-- room by hash (see this file's own map.prompt.hash usage throughout).
--
-- Extracts the REAL current map.export_area()/map.import_area() straight
-- out of the git-tracked DSL_Generic_Mapper.xml (not a hand-copied
-- paraphrase) and round-trips two connected rooms through a real
-- export+import, confirming: (1) a room with a hash keeps it on import
-- into a map that doesn't already have that hash, and (2) importing into
-- a map that ALREADY has a room using that hash leaves the new room
-- hashless and counts a conflict instead of silently stealing the hash
-- off the existing room (the actual bug upstream fixed -- re-importing an
-- area you already had used to move the mapper's own room-identification
-- onto the freshly created duplicate).
--
-- Run: luajit test/test_mapper_area_hash_preservation.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Extract the real export_area/import_area source between two anchors
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
  if body:find("function map.export_area", 1, true) then scriptBody = body; break end
end
assert(scriptBody, "couldn't find the mapper's Map Script <script> block")
scriptBody = xmlUnescape(scriptBody)

local startIdx = scriptBody:find("function map.export_area(name)", 1, true)
local endIdx = scriptBody:find("function map.set_recall()", 1, true)
assert(startIdx and endIdx, "extraction anchors not found -- has DSL_Generic_Mapper.xml's source shape around export_area/import_area changed?")
local snippet = scriptBody:sub(startIdx, endIdx - 1)

------------------------------------------------------------------------
-- Self-contained mocks (not shared mudlet_mock.lua's no-op table.save/
-- load -- this test needs a REAL round trip through them). A minimal,
-- in-memory map: rooms are plain tables keyed by ID.
------------------------------------------------------------------------
local __rooms = {}      -- id -> {name, exits={dir->id}, area, coords={x,y,z}, hash, ...}
local __hashIndex = {}  -- hash -> roomID
local __areas = {}      -- name -> areaID
local __nextRoomID = 100
local __store = {}      -- fake filesystem for table.save/table.load

function _G.getAreaTable() return __areas end
function _G.getAreaRooms(areaID)
  local out = {}
  for id, r in pairs(__rooms) do if r.area == areaID then out[#out + 1] = id end end
  return out
end
function _G.show_err(msg) error("show_err: " .. tostring(msg)) end
table.contains = function(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
table.is_empty = function(t) return next(t) == nil end
table.save = function(path, tbl) __store[path] = tbl; return true end
table.load = function(path, target)
  local saved = __store[path]
  if not saved then return end
  for k, v in pairs(saved) do target[k] = v end
end
_G.profilePath = "/tmp/mock_profile"

function _G.getRoomName(id) return __rooms[id] and __rooms[id].name or "" end
function _G.setRoomName(id, name) __rooms[id].name = name end
function _G.getRoomExits(id) return __rooms[id].exits or {} end
function _G.getExitStubs(id) return __rooms[id].stubs or {} end
function _G.getDoors(id) return __rooms[id].doors or {} end
function _G.getSpecialExitsSwap(id) return __rooms[id].special or {} end
function _G.getRoomUserData(id, key) return __rooms[id].userdata and __rooms[id].userdata[key] end
function _G.setRoomUserData(id, key, val) __rooms[id].userdata = __rooms[id].userdata or {}; __rooms[id].userdata[key] = val end
function _G.getRoomEnv(id) return __rooms[id].env or 0 end
function _G.setRoomEnv(id, env) __rooms[id].env = env end
function _G.getRoomChar(id) return __rooms[id].roomChar end
function _G.setRoomChar(id, c) __rooms[id].roomChar = c end
function _G.getRoomCoordinates(id) local c = __rooms[id].coords or {0,0,0}; return c[1], c[2], c[3] end
function _G.setRoomCoordinates(id, x, y, z) __rooms[id].coords = {x, y, z} end
function _G.setExitStub(id, dir, on) __rooms[id].stubs = __rooms[id].stubs or {}; __rooms[id].stubs[dir] = on end
function _G.setDoor(id, dir, kind) __rooms[id].doors = __rooms[id].doors or {}; __rooms[id].doors[dir] = kind end
function _G.setRoomArea(id, areaID) __rooms[id].area = areaID end
function _G.addAreaName(name) local id = (#__areas > 0 and #__areas or 0) + 1; __areas[name] = id; return id end
function _G.createRoomID() __nextRoomID = __nextRoomID + 1; return __nextRoomID end
function _G.addRoom(id) __rooms[id] = __rooms[id] or {} end
function _G.connect_rooms(a, b, dir) __rooms[a].exits = __rooms[a].exits or {}; __rooms[a].exits[dir] = b end
function _G.addSpecialExit(a, b, dir) __rooms[a].special = __rooms[a].special or {}; __rooms[a].special[dir] = b end
function _G.getRoomHashByID(id) return __rooms[id] and __rooms[id].hash end
function _G.getRoomIDbyHash(hash) return __hashIndex[hash] or -1 end
function _G.setRoomIDbyHash(id, hash) __hashIndex[hash] = id; __rooms[id].hash = hash end

local echoedLines = {}
map = map or {}
function map.echo(msg) echoedLines[#echoedLines + 1] = msg end
function map.fix_portals() end

local chunk, loadErr = load(snippet, "area_export_import_extract")
check("extracted export_area/import_area source loads without a syntax error", chunk ~= nil and loadErr == nil)
if chunk then
  local ok, runErr = pcall(chunk)
  check("extracted source runs without error (defines the functions)", ok)
  if not ok then print("  runtime error: " .. tostring(runErr)) end
end

if map.export_area and map.import_area then
  ------------------------------------------------------------------------
  -- Case 1: a room WITH a hash round-trips into a map that doesn't
  -- already have that hash -- it should keep it.
  ------------------------------------------------------------------------
  __areas = { ["Testville"] = 1 }
  __rooms = {
    [10] = { name = "Town Square", area = 1, exits = { north = 11 }, coords = {0,0,0}, hash = "hash-A" },
    [11] = { name = "Market",      area = 1, exits = {},            coords = {0,1,0} },
  }
  __hashIndex = { ["hash-A"] = 10 }

  echoedLines = {}
  local ok = pcall(map.export_area, "Testville")
  check("export_area runs without error", ok)

  -- Simulate a fresh map (the exported area's rooms don't exist here yet)
  __rooms = {}
  __hashIndex = {}
  __areas = {}

  echoedLines = {}
  local ok2 = pcall(map.import_area, "Testville")
  check("import_area runs without error", ok2)

  local importedHashOwner = _G.getRoomIDbyHash("hash-A")
  check("hash-A is now owned by a real imported room", importedHashOwner ~= -1)
  check("that room really is the imported Town Square",
    importedHashOwner ~= -1 and _G.getRoomName(importedHashOwner) == "Town Square")
  check("no hash-conflict warning was echoed (nothing to conflict with)",
    not table.contains(echoedLines, nil) and (function()
      for _, line in ipairs(echoedLines) do
        if line:find("left without a hash", 1, true) then return false end
      end
      return true
    end)())

  ------------------------------------------------------------------------
  -- Case 2: re-importing into a map that ALREADY has a room using that
  -- hash -- the new room must NOT steal it; a conflict should be counted
  -- and warned about instead. This is the actual bug the upstream fix
  -- addresses (re-import used to move identification onto the duplicate).
  ------------------------------------------------------------------------
  __rooms = {
    [500] = { name = "Existing Town Square", area = 9, exits = {}, coords = {0,0,0}, hash = "hash-A" },
  }
  __hashIndex = { ["hash-A"] = 500 }
  __areas = {}

  echoedLines = {}
  local ok3 = pcall(map.import_area, "Testville")
  check("re-import into a map with an existing hash owner runs without error", ok3)

  check("the pre-existing room still owns hash-A (not stolen)",
    _G.getRoomIDbyHash("hash-A") == 500)

  local sawConflictWarning = false
  for _, line in ipairs(echoedLines) do
    if line:find("left without a hash", 1, true) then sawConflictWarning = true end
  end
  check("a hash-conflict warning was echoed", sawConflictWarning)
end

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
