-- Real structural coverage for the DSL Generic Mapper fork's real-
-- movement-cost room-weighting system, rebuilt 2026-08-24 -- the
-- original test cited by name in docs/CHANGELOG.md's 2026-07-18 entries
-- (`test_move_cost_weight.lua`) does not exist anywhere in git history
-- or on disk (found via an independent Claude Desktop review, tracked in
-- docs/TODO.md's TOP PRIORITY section as a real verification-integrity
-- gap). This replaces that lost coverage by extracting the REAL current
-- Lua source directly out of the git-tracked DSL_Generic_Mapper.xml (not
-- a hand-copied paraphrase) and running it for real, same technique as
-- test_mapper_gmcp_and_doorverb.lua / test_mapper_terrain_lock.lua.
--
-- Covers map.dsl.captureMovePoints()/map.dsl.applyMoveCost(rid):
--   1. A real observed movement cost becomes the room's weight.
--   2. A regen-tick (cost <= 0) or implausible (cost > 20) reading is
--      discarded, not corrupting the running average.
--   3. Repeat visits average into a stable weight across samples.
--   4. A manually-set weight (dsl.weight_source == "manual") is never
--      overwritten by a later auto pass.
--
-- Run: luajit test/test_move_cost_weight.lua

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

local startIdx = scriptBody:find("local dsl_long_dirs = {", 1, true)
local endIdx = scriptBody:find("function map.dsl.install", 1, true)
assert(startIdx and endIdx, "extraction anchors not found -- has DSL_Generic_Mapper.xml's source shape changed?")
local snippet = scriptBody:sub(startIdx, endIdx - 1)

map = map or {}
map.dsl = map.dsl or {}
map.roomexists = _G.roomexists
map.echo = map.echo or function(...) end  -- stock Generic Mapper's own debug echo, outside this extraction

local chunk, loadErr = load(snippet, "mapper_extract")
check("extracted mapper source loads without a syntax error", chunk ~= nil and loadErr == nil)
if not chunk then print("  load error: " .. tostring(loadErr)); os.exit(1) end
local ok, runErr = pcall(chunk)
check("extracted mapper source runs without error", ok)
if not ok then print("  runtime error: " .. tostring(runErr)); os.exit(1) end

------------------------------------------------------------------------
-- Part 1: a real observed cost becomes the room's weight
------------------------------------------------------------------------
_G.__mock_defineRoom(100, "A Quiet Hallway")
_G.gmcp = { char_data = { move = 400 } }
map.dsl.captureMovePoints()  -- records "before" = 400
_G.gmcp.char_data.move = 397  -- 3 points spent to arrive
map.dsl.applyMoveCost(100)

check("a real 3-point cost becomes the room weight", getRoomWeight(100) == 3)
check("the room is marked auto-weighted", getRoomUserData(100, "dsl.weight_source") == "auto")
check("one sample recorded", getRoomUserData(100, "dsl.move_cost_samples") == "1")

------------------------------------------------------------------------
-- Part 2: implausible readings are discarded, not corrupting the average
------------------------------------------------------------------------
_G.__mock_defineRoom(200, "A Regen Room")
_G.gmcp.char_data.move = 400
map.dsl.captureMovePoints()
_G.gmcp.char_data.move = 405  -- natural regen ticked upward mid-move -> negative cost
map.dsl.applyMoveCost(200)
check("a negative (regen-tick) cost is discarded, not applied as a weight",
  getRoomWeight(200) == 1)  -- Mudlet's own room-weight default, untouched
check("a discarded regen-tick reading leaves no sample recorded",
  getRoomUserData(200, "dsl.move_cost_samples") == "")

_G.gmcp.char_data.move = 400
map.dsl.captureMovePoints()
_G.gmcp.char_data.move = 375  -- a wildly implausible 25-point single-step cost
map.dsl.applyMoveCost(200)
check("an implausibly large (>20) cost is also discarded",
  getRoomUserData(200, "dsl.move_cost_samples") == "")

------------------------------------------------------------------------
-- Part 3: repeat visits average into a stable weight
------------------------------------------------------------------------
_G.__mock_defineRoom(300, "A Well-Traveled Path")
local costs = {4, 6, 5}  -- average 5
for _, cost in ipairs(costs) do
  _G.gmcp.char_data.move = 400
  map.dsl.captureMovePoints()
  _G.gmcp.char_data.move = 400 - cost
  map.dsl.applyMoveCost(300)
end
check("repeat visits average into a stable weight (3 samples, avg 5)",
  getRoomWeight(300) == 5 and getRoomUserData(300, "dsl.move_cost_samples") == "3")

------------------------------------------------------------------------
-- Part 4: a manually-set weight is never overwritten by a later auto pass
------------------------------------------------------------------------
_G.__mock_defineRoom(400, "A Deliberately Weighted Room")
setRoomUserData(400, "dsl.weight_source", "manual")
setRoomWeight(400, 9)
_G.gmcp.char_data.move = 400
map.dsl.captureMovePoints()
_G.gmcp.char_data.move = 397
map.dsl.applyMoveCost(400)
check("a manually-set weight is untouched by a later real-cost observation",
  getRoomWeight(400) == 9)
check("the manual source marker itself is preserved",
  getRoomUserData(400, "dsl.weight_source") == "manual")

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
