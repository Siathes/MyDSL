-- Two things in one file, both added 2026-08-23 in response to an
-- independent Claude Desktop review pass:
--
-- 1. Re-verifies the DSL Generic Mapper fork's door-verb parser fix
--    (`dsl_dir_from_command()`, 2026-07-18) against real command text.
--    The ORIGINAL verification for this ("test_mapper_fork_fixes.lua",
--    cited by name in docs/CHANGELOG.md's 2026-07-18 entries and
--    docs/TODO.md) does not exist anywhere -- not in git history for
--    that path, not anywhere on disk. Same failure class already
--    documented once before in this project for build_mydsl_package.py
--    ("the original was lost with a session scratchpad") -- it happened
--    again, for real test files backing safety-relevant mapper fixes,
--    and nobody caught it until this review. This file replaces that
--    lost coverage by extracting the REAL current Lua source directly
--    out of the git-tracked DSL_Generic_Mapper.xml (not a hand-copied
--    paraphrase) and running it for real.
--
-- 2. A GMCP-agreement canary between MyDSL_DataLayer.lua's own
--    gmcp.room_data handler and the mapper fork's map.dsl.onRoomData().
--    Both independently parse the same gmcp.room_data payload (a
--    confirmed, deliberate duplication -- see docs/TODO.md's audit
--    entry) but nothing previously checked whether they actually agree
--    on the same input. Feeds one synthetic payload through both real
--    handlers and asserts the room name and raw sector value match --
--    this is exactly the kind of drift a future DSL/GMCP shape change
--    could introduce silently otherwise.
--
-- Run: luajit test/test_mapper_gmcp_and_doorverb.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- Extract the real mapper source between two robust text anchors
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

-- Find the one <script> block containing the door-verb table (the whole
-- mapper fork is one large embedded Script, so there's only one match,
-- but search rather than assume position in case that ever changes).
local scriptBody
for body in xml:gmatch("<script>(.-)</script>") do
  if body:find("dsl_long_dirs", 1, true) then scriptBody = body; break end
end
assert(scriptBody, "couldn't find the mapper's Map Script <script> block")
scriptBody = xmlUnescape(scriptBody)

local startIdx = scriptBody:find("local dsl_long_dirs = {", 1, true)
local endIdx = scriptBody:find("-- DSL_SECTOR_ENV_IDS", 1, true)
assert(startIdx and endIdx, "extraction anchors not found -- has DSL_Generic_Mapper.xml's source shape around dsl_long_dirs/onRoomData changed?")
local snippet = scriptBody:sub(startIdx, endIdx - 1)

-- Sandbox: give the snippet a `map.dsl` table to attach its functions
-- to (real code does `function map.dsl.onRoomData() ... end`, a global
-- assignment reachable through the `map` global) plus real stdlib
-- access via _G. mudlet_mock.lua already registered string.trim, which
-- this snippet's `cmd:trim()` calls depend on.
map = map or {}
map.dsl = map.dsl or {}

local chunk, loadErr = load(snippet, "mapper_extract")
check("extracted mapper source loads without a syntax error", chunk ~= nil and loadErr == nil)
if chunk then
  local ok, runErr = pcall(chunk)
  check("extracted mapper source runs without error (defines functions, no crash)", ok)
  if not ok then print("  runtime error: " .. tostring(runErr)) end
end

------------------------------------------------------------------------
-- Part 1: door-verb parser, real command text
------------------------------------------------------------------------
if map.dsl.onRoomData then
  -- dsl_dir_from_command is a local, not exposed on map.dsl -- but the
  -- snippet's own `local function dsl_dir_from_command` becomes an
  -- upvalue captured by nothing we can reach from outside after load().
  -- Work around it the same way the extraction technique itself works:
  -- pull just that one function out as its own tiny loadable chunk that
  -- returns it, sharing the same dsl_long_dirs/DSL_DOOR_VERBS locals by
  -- re-slicing from the same snippet text (cheap, and guarantees this
  -- is testing the exact real source, not a hand-copy of it).
  local fnStart = snippet:find("local dsl_long_dirs = {", 1, true)
  local fnEnd = snippet:find("function map.dsl.normalizeSector", 1, true)
  local fnSnippet = snippet:sub(fnStart, fnEnd - 1) .. "\nreturn dsl_dir_from_command"
  local fnChunk = load(fnSnippet, "door_verb_extract")
  local dsl_dir_from_command = fnChunk and fnChunk()

  check("dsl_dir_from_command extracted as a callable function", type(dsl_dir_from_command) == "function")

  if dsl_dir_from_command then
    -- The actual bug: `|` used as PCRE-style alternation inside a Lua
    -- pattern, which has no alternation operator -- this could never
    -- match ANY of these before the fix.
    local dir, verb, isObject = dsl_dir_from_command("open west")
    check("'open west' resolves to a real direction", dir == "west" and verb == "open" and isObject == false)

    local dir2, verb2, isObject2 = dsl_dir_from_command("close door")
    check("'close door' resolves to no direction (not a compass word) and is flagged as an object target",
      dir2 == nil and verb2 == "close" and isObject2 == true)

    local dir3, verb3, isObject3 = dsl_dir_from_command("lock northeast")
    check("'lock northeast' resolves the long-form direction", dir3 == "northeast" and verb3 == "lock")

    -- Bug #2 from the same fix: "open backpack"/"close pouch" (a
    -- container action, not a door/exit action) must be recognized as
    -- an object target, not silently misattributed to a movement
    -- direction -- confirmed via DSL's own help that both syntaxes
    -- ("open <object>" and "open <direction>") are real.
    local dir4, verb4, isObject4 = dsl_dir_from_command("open backpack")
    check("'open backpack' is an object target, not a direction (the second bug from the same fix)",
      dir4 == nil and verb4 == "open" and isObject4 == true)

    -- Bare direction (no door verb at all) still resolves via the
    -- fallback "move" path.
    local dir5, verb5 = dsl_dir_from_command("north")
    check("a bare direction with no door verb still resolves via the move fallback",
      dir5 == "north" and verb5 == "move")

    check("an unrelated command resolves to nothing", dsl_dir_from_command("look") == nil)
  end
end

------------------------------------------------------------------------
-- Part 2: GMCP room_data agreement canary
------------------------------------------------------------------------
-- Load MyDSL_DataLayer.lua's real handler the same way every other test
-- in this suite does. mudlet_mock.lua's default registerAnonymousEventHandler
-- is a total no-op (see test/README.md's "Overriding a mock function per
-- test") -- override it to actually record handlers by event name so
-- they can be fired manually below, the same technique already
-- established in this project's test suite.
local eventHandlers = {}
function _G.registerAnonymousEventHandler(event, fn)
  eventHandlers[event] = eventHandlers[event] or {}
  table.insert(eventHandlers[event], fn)
  return #eventHandlers[event]
end

_G.matches = _G.matches or {}
MyDSL = MyDSL or {}
local ok = pcall(dofile, "MyDSL_DataLayer.lua")
check("MyDSL_DataLayer.lua loads for the canary", ok)

if ok and map.dsl.onRoomData then
  local payload = { room = "  The Gahboom Bazaar  ", sector = "City", exits = { "north", "south", "east" } }

  -- Drive DataLayer's real gmcp.room_data handler the way raiseEvent()
  -- would -- fire every registered handler for this event name.
  gmcp = { room_data = payload }
  for _, fn in ipairs(eventHandlers["gmcp.room_data"] or {}) do fn() end

  -- Drive the mapper's real handler directly (it's a plain function,
  -- not event-registered in this extracted snippet). map.dsl.gmcp is
  -- normally initialized during map.dsl.install() -- not part of this
  -- extraction, so seed it the way install() would have.
  map.dsl.gmcp = map.dsl.gmcp or {}
  map.dsl.onRoomData()

  local dlRoom = MyDSL.State and MyDSL.State.room
  check("DataLayer captured a room name from the synthetic payload", dlRoom and dlRoom.name ~= nil)
  check("DataLayer and the mapper agree on the raw room name (same source field, same lack of transformation)",
    dlRoom and dlRoom.name == map.dsl.gmcp.room_name)
  check("DataLayer and the mapper agree on the raw sector value",
    dlRoom and dlRoom.sector == map.dsl.gmcp.sector)

  -- This is the actual canary: change ONE side's extracted field name
  -- and confirm the comparison would catch it, so this test isn't
  -- trivially true regardless of what either side does.
  local wasEqual = (dlRoom.sector == map.dsl.gmcp.sector)
  map.dsl.gmcp.sector = "deliberately-wrong-for-canary-self-check"
  local nowEqual = (dlRoom.sector == map.dsl.gmcp.sector)
  check("the comparison itself is meaningful -- flipping one side is detected", wasEqual == true and nowEqual == false)
end

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
