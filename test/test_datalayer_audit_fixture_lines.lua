-- Regression test for 3 real live bugs found 2026-07-21 via a full
-- codebase audit (prompted by Steven: "we seem to be regressing to
-- errors we fixed... would it improve if we used a newer ai agent?" --
-- the answer was a systematic re-check, not a bigger model; this test
-- covers what that re-check found). Same recurring bug class as
-- test_datalayer_several_fixture_line.lua and 5 prior CHANGELOG.md
-- entries: a scenery/landmark line with no "here"/"in the room" anchor
-- and no recognized leading word falls through beginLook()'s entire
-- catch-all straight to endLook(), silently dropping every mob listed
-- after it. Each of the 3 lines below, and the real mobs they were
-- independently confirmed (via direct corpus grep) to drop, is replayed
-- here verbatim.
--
-- Run: luajit test/test_datalayer_audit_fixture_lines.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_DataLayer_ScanLook.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local function rightHereHasMob(substr)
  for _, entry in pairs(MyDSL.State.scan.rightHere) do
    if entry.is_mob and entry.raw:find(substr, 1, true) then return true end
  end
  return false
end

local function feedLines(lines)
  MyDSL.beginLook()
  for _, ln in ipairs(lines) do
    _G.line = ln
    if MyDSL._triggers.lookBody then
      _G.__triggers[MyDSL._triggers.lookBody].func()
    end
  end
end

-- Real corpus: log/2026-06-30#21-23-23.txt:281 -- drops a real barmaid
-- (a static NPC, should be captured as a mob) and silently ends capture
-- before a mount that "walks in" (a transient arrival announcement, same
-- mechanic as "Someone walks in." -- confirmed via corpus this is a
-- generic movement-announcement, not room content, so it correctly
-- should NOT become a captured mob -- just shouldn't END capture either).
feedLines({
  "     Sturdy barstools line the outside edge of the lengthy bar.",
  "     Several booths are situated along the wall, allowing for private conversation.",
  "A Dark Elven barmaid stands behind the bar, ready to take your order.",
  "A Dapple Grey Gelding walks in.",
})
check("the barmaid (listed after 'Sturdy barstools...') was captured as a mob",
  rightHereHasMob("Dark Elven barmaid"))
check("capture survived all the way through the transient 'walks in' line too",
  MyDSL._triggers.lookBody ~= nil)

-- Real corpus: log/2026-06-30#21-23-23.txt:189 -- drops an Elite Royal
-- Guard and 2 good samaritans.
feedLines({
  "     (Glowing) High above the cityscape, a jagged rip mars the sky and crackles with charged energy.",
  "An Elite Royal Guard stands here smiling happily.",
  "A good samaritan is here, looking for someone to help.",
  "A good samaritan is here, looking for someone to help.",
})
check("the Elite Royal Guard (listed after the 'jagged rip' line) was captured as a mob",
  rightHereHasMob("Elite Royal Guard"))
check("a good samaritan (listed after the 'jagged rip' line) was captured as a mob",
  rightHereHasMob("good samaritan"))

-- Real corpus: log/2026-06-30#20-29-23.txt:9666 -- this one ends capture
-- on the literal FIRST line after [Exits:], before even a second
-- fixture line reachable via reaching it at all.
feedLines({
  "     Dark marble benches are set facing the statue of the Sons of Liberty.",
  "     A large fountain and statue of the Sons of Liberty.",
})
check("capture survived past 'Dark marble benches...' to reach the next fixture line",
  MyDSL._triggers.lookBody ~= nil)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
