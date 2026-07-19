-- Structural test for the 2026-07-19 captureRoomDescription() fix:
-- a stale/racing room name must never let the backward title-search cross
-- an older room-block boundary and mis-attribute an unrelated room's
-- description -- confirmed live via location_variants.lua showing
-- "A Beautiful Courtyard" holding 4 completely unrelated rooms' text, and
-- "An alleyway" holding a byte-for-byte duplicate of "On the Porch of the
-- Fellowship Saloon"'s real description.
--
-- Run: luajit test/test_room_description_capture_fix.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_DataLayer.lua")

local failures = 0
local function check(name, cond)
  if cond then
    print("PASS: " .. name)
  else
    print("FAIL: " .. name)
    failures = failures + 1
  end
end

local function pushLine(text)
  MyDSL._roomLineBuffer[#MyDSL._roomLineBuffer + 1] = { text = text, color = { 200, 200, 200 } }
end

-- Scenario 1: normal case, single room block, no ambiguity -- capture
-- must still work exactly as before this fix.
MyDSL._roomLineBuffer = {}
pushLine("An alleyway")
pushLine("Some alley text A.")
pushLine("[Exits: N S]")
MyDSL.State.room = { name = "An alleyway" }
MyDSL.captureRoomDescription()
check("normal single-block capture still works",
  MyDSL.State.room.description == "Some alley text A.")

-- Scenario 2: the real bug -- a generic/reused title ("An alleyway")
-- appears in an OLDER block; the CURRENT room ("On the Porch...") hasn't
-- had its own title line buffered yet by the time this fires (simulates
-- MyDSL.State.room.name racing ahead of the text stream). The old code
-- would scan straight past the intervening "[Exits: N S]" boundary and
-- wrongly match the older "An alleyway" title, stealing its description.
MyDSL._roomLineBuffer = {}
pushLine("An alleyway")
pushLine("Some alley text A.")
pushLine("[Exits: N S]")          -- block 1 boundary
pushLine("Porch text, not yet titled in the buffer.")
MyDSL.State.room = { name = "An alleyway", description = nil }  -- STALE name, race condition
MyDSL.captureRoomDescription()
check("stale/racing name does not cross an older room-block boundary",
  MyDSL.State.room.description == nil)

-- Scenario 3: same setup, but the CURRENT room's own title line IS
-- present after the boundary -- must still find and use it, not the
-- older occurrence further back.
MyDSL._roomLineBuffer = {}
pushLine("An alleyway")
pushLine("Some alley text A.")
pushLine("[Exits: N S]")
pushLine("An alleyway")
pushLine("Some alley text B, a totally different real room.")
pushLine("[Exits: E W]")
MyDSL.State.room = { name = "An alleyway" }
MyDSL.captureRoomDescription()
check("reused generic title still resolves to the CURRENT block, not an older one",
  MyDSL.State.room.description == "Some alley text B, a totally different real room.")

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
