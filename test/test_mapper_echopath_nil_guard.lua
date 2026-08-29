-- Regression test for map.echoPath()'s searchRoom() nil-guard, added
-- 2026-08-29 -- ported from upstream generic_mapper.xml 2.1.9 (Mudlet
-- PR #9467, "Fix: searchRoom returns nil+message for a missing roomID").
--
-- Our DSL fork was forked from upstream 2.1.8, before that fix landed,
-- so it still carried the old unguarded `string.upper(searchRoom(from))`
-- call -- harmless on our pinned Mudlet 4.20.1 today (that C++ return-
-- shape change hasn't shipped for us yet), but a hard crash the moment
-- it does, since string.upper(nil) errors. This extracts the REAL
-- current map.echoPath() straight out of the git-tracked
-- DSL_Generic_Mapper.xml (not a hand-copied paraphrase) and exercises
-- both the found-room and missing-room paths against a searchRoom mock
-- that returns nil for an unknown ID, matching the newer Mudlet
-- behavior this fix defends against.
--
-- Run: luajit test/test_mapper_echopath_nil_guard.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Extract the real map.echoPath() source between two robust text anchors
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
  if body:find("function map.echoPath", 1, true) then scriptBody = body; break end
end
assert(scriptBody, "couldn't find the mapper's Map Script <script> block")
scriptBody = xmlUnescape(scriptBody)

local startIdx = scriptBody:find("function map.echoPath(from, to)", 1, true)
local endIdx = scriptBody:find("function map.listSpecialExits", 1, true)
assert(startIdx and endIdx, "extraction anchors not found -- has DSL_Generic_Mapper.xml's source shape around map.echoPath changed?")
local snippet = scriptBody:sub(startIdx, endIdx - 1)

------------------------------------------------------------------------
-- Minimal sandbox: map.echo captures its args instead of printing,
-- getPath/speedWalkDir/searchRoom mocked to drive both branches.
------------------------------------------------------------------------
local echoedLines = {}
map = map or {}
function map.echo(msg) echoedLines[#echoedLines + 1] = msg end

local pathExists = true
function _G.getPath(from, to) return pathExists end
_G.speedWalkDir = { "north", "east" }

local rooms = { [1] = "Town Square", [2] = "Market Street" }
function _G.searchRoom(id)
  local name = rooms[id]
  if name then return name end
  return nil, "number " .. tostring(id) .. " is not a valid roomID"
end

local chunk, loadErr = load(snippet, "echopath_extract")
check("extracted map.echoPath source loads without a syntax error", chunk ~= nil and loadErr == nil)
if chunk then
  local ok, runErr = pcall(chunk)
  check("extracted source runs without error (defines map.echoPath)", ok)
  if not ok then print("  runtime error: " .. tostring(runErr)) end
end

------------------------------------------------------------------------
-- Both rooms exist -- normal path
------------------------------------------------------------------------
if map.echoPath then
  echoedLines = {}
  pathExists = true
  local ok, err = pcall(map.echoPath, 1, 2)
  check("both-rooms-exist call does not error", ok)
  if not ok then print("  error: " .. tostring(err)) end
  check("echoes the found room names", ok and echoedLines[1] and
    echoedLines[1]:find("TOWN SQUARE", 1, true) ~= nil and
    echoedLines[1]:find("MARKET STREET", 1, true) ~= nil)

  ------------------------------------------------------------------------
  -- One room ID doesn't exist -- searchRoom returns nil -- the actual bug
  ------------------------------------------------------------------------
  echoedLines = {}
  pathExists = true
  local ok2, err2 = pcall(map.echoPath, 1, 999)
  check("missing-room call does not crash on string.upper(nil)", ok2)
  if not ok2 then print("  error: " .. tostring(err2)) end
  check("falls back to a 'room <id>' placeholder for the missing room",
    ok2 and echoedLines[1] and echoedLines[1]:find("ROOM 999", 1, true) ~= nil)

  ------------------------------------------------------------------------
  -- No path exists, and the destination room is missing too
  ------------------------------------------------------------------------
  echoedLines = {}
  pathExists = false
  local ok3, err3 = pcall(map.echoPath, 999, 2)
  check("no-path + missing-room call does not crash either", ok3)
  check("no-path message also falls back cleanly",
    ok3 and echoedLines[1] and echoedLines[1]:find("ROOM 999", 1, true) ~= nil)
end

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
