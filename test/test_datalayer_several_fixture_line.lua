-- Regression test for a real live bug (2026-07-21), the fifth confirmed
-- instance of a recurring bug class in MyDSL_DataLayer.lua's room-look
-- capture (isUnparsedPresenceLine()/beginLook()'s catch-all): a line
-- that's neither a recognized mob-presence line nor a recognized
-- fixture line silently ends capture (endLook()) at that exact point,
-- dropping every mob listed after it in the same room.
--
-- Found via MyDSL_Leveling.lua's own live testing (confirmed via 2
-- separate real session logs, "Philosophy Guild"): "     Several small
-- desks are here positioned strategically." -- plural ("are here", not
-- "is here"), starts with neither an article nor "This" -- fell through
-- every check straight to endLook(), silently dropping 2 janitors, 4
-- students, and 1 instructor listed right after it, every single visit
-- to that room where this line was present. This test replays the
-- EXACT real captured room content from that session, verbatim.
--
-- Run: luajit test/test_datalayer_several_fixture_line.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_DataLayer.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Same "[Exits: " anchor mechanism as real gameplay -- MyDSL.beginLook()
-- registers the body trigger (MyDSL._triggers.lookBody), then each
-- subsequent real line is fed through it via _G.line + calling the
-- trigger's own func(), matching test_others_equipment_hover.lua's
-- established pattern for exercising this capture chain directly.
MyDSL.beginLook()

local realLines = {
  "     Several small desks are here positioned strategically.",
  "(Charmed) (White Aura) A beautiful white charger, fitted with saddle, is here.",
  "A small gnome carrying a stack of papers three times his height walks by you.",
  "A tinker gnome janitor is picking up trash here.",
  "A tinker gnome janitor is picking up trash here.",
  "A small gnome carrying a stack of papers three times his height walks by you.",
  "A gnome student is here.",
  "A gnome student is here.",
  "A gnome student is here.",
  "A gnome student is here.",
  "A gnome philosophy instructor is here.",
  "A gnome philosopher's assistant bumps into you causing you to lose your balance.",
  "You cannot sit on that while your riding.",
  "A gnome philosopher's assistant says 'Oh! Iamsososorry!'",
}

-- Feed the fixture line FIRST, alone, and check immediately -- this is
-- the actual bug's exact failure point: capture must NOT end right here.
_G.line = realLines[1]
_G.__triggers[MyDSL._triggers.lookBody].func()
check("capture is still active immediately after the 'Several small desks' "
  .. "fixture line (didn't end prematurely, right at the bug's exact failure point)",
  MyDSL._triggers.lookBody ~= nil)

for i = 2, #realLines do
  _G.line = realLines[i]
  if MyDSL._triggers.lookBody then
    _G.__triggers[MyDSL._triggers.lookBody].func()
  end
end

local rh = MyDSL.State.scan.rightHere
local function hasMob(substr)
  for _, entry in pairs(rh) do
    if entry.is_mob and entry.raw:find(substr, 1, true) then return true end
  end
  return false
end

check("the janitor (listed AFTER the fixture line) was captured as a mob", hasMob("tinker gnome janitor"))
check("the student (listed AFTER the fixture line) was captured as a mob", hasMob("gnome student"))
check("the instructor (listed AFTER the fixture line) was captured as a mob", hasMob("gnome philosophy instructor"))

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
