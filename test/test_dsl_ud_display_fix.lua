-- Real structural coverage for the DSL Generic Mapper fork's `dslroom raw`
-- blank-field display fix, rebuilt 2026-08-24 -- the original test cited
-- by name in docs/CHANGELOG.md's 2026-07-18 entry (`test_dsl_ud_display_
-- fix.lua`) does not exist anywhere in git history or on disk (found via
-- an independent Claude Desktop review, tracked in docs/TODO.md's TOP
-- PRIORITY section as a real verification-integrity gap). Replays
-- Steven's exact real reported bug: `dslroom raw` on an unweighted room
-- showed "Room weight: 1 (source=, samples=, avg cost=0.0)" -- blank
-- fields, not a clear placeholder -- because getRoomUserData() returns ""
-- for an unset key, not nil, and the old code did plain tostring() on it.
--
-- Run: luajit test/test_dsl_ud_display_fix.lua

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
  if body:find("dsl_long_dirs", 1, true) and body:find("function map.dsl.roomRaw", 1, true) then
    scriptBody = body; break
  end
end
assert(scriptBody, "couldn't find the mapper's Map Script <script> block")
scriptBody = xmlUnescape(scriptBody)

local startIdx = scriptBody:find("function map.dsl.echo(msg)", 1, true)
local endIdx = scriptBody:find("-- Register DSL assist handlers", 1, true)
assert(startIdx and endIdx, "extraction anchors not found -- has DSL_Generic_Mapper.xml's source shape changed?")
local snippet = scriptBody:sub(startIdx, endIdx - 1)

map = map or {}
map.dsl = map.dsl or {}
map.roomexists = _G.roomexists
map.echo = map.echo or function(...) end
-- roomLook() is stock Generic Mapper's own "rl"/"room look" command --
-- deliberately stubbed rather than extracted: roomRaw() only reuses it
-- for display, this test is about the DSL-specific fields appended
-- after it, and stock's own room-look formatting is untouched by this
-- fix (real coverage for it, if ever needed, belongs in its own test).
map.roomLook = function(...) return true end

local chunk, loadErr = load(snippet, "mapper_extract")
check("extracted mapper source loads without a syntax error", chunk ~= nil and loadErr == nil)
if not chunk then print("  load error: " .. tostring(loadErr)); os.exit(1) end
local ok, runErr = pcall(chunk)
check("extracted mapper source runs without error", ok)
if not ok then print("  runtime error: " .. tostring(runErr)); os.exit(1) end

------------------------------------------------------------------------
-- Part 1: dsl_ud() itself -- the real root-cause fix
------------------------------------------------------------------------
_G.__mock_defineRoom(100, "A Never-Visited Room")

check("dsl_ud() returns the placeholder for a genuinely unset key (getRoomUserData's real \"\")",
  map.dsl.dsl_ud(100, "dsl.weight_source", "?") == "?")
check("dsl_ud() returns a custom placeholder string, not a hardcoded one",
  map.dsl.dsl_ud(100, "dsl.weight_source", "none yet -- still default weight") == "none yet -- still default weight")

setRoomUserData(100, "dsl.weight_source", "auto")
check("dsl_ud() returns the real value once one is actually set",
  map.dsl.dsl_ud(100, "dsl.weight_source", "?") == "auto")

------------------------------------------------------------------------
-- Part 2: roomRaw() -- Steven's exact reported scenario replayed.
-- Real bug report: "Room weight: 1 (source=, samples=, avg cost=0.0)"
-- on a room with zero real movement samples yet (he was flying, so no
-- movement cost was ever observed -- a real data limitation, not a bug,
-- but the DISPLAY should say so clearly instead of showing blanks).
------------------------------------------------------------------------
_G.__mock_defineRoom(200, "A Room Only Ever Reached By Flying")
map.currentRoom = 200

-- Capture cecho() output so the actual displayed text can be checked,
-- not just that dsl_ud() as a unit returns the right thing in isolation.
local echoed = {}
local realCecho = _G.cecho
_G.cecho = function(s) echoed[#echoed + 1] = s; return realCecho(s) end

local ok2, err2 = pcall(map.dsl.roomRaw)
check("roomRaw() runs without error on a room with zero movement samples", ok2)
if not ok2 then print("  runtime error: " .. tostring(err2)) end

local full = table.concat(echoed, "")
check("weight source shows a real placeholder, not a blank field",
  full:find("Weight source: <white>none yet", 1, true) ~= nil)
check("no field silently rendered as a raw empty value (the exact old bug shape: '=,' or '=)')",
  full:find("=,", 1, true) == nil and full:find("=%)") == nil)
check("avg cost correctly shows 'n/a' rather than a fabricated 0.0 when there are zero samples",
  full:find("avg cost=<white>n/a", 1, true) ~= nil)

_G.cecho = realCecho

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
