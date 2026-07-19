-- Structural test for the 2026-07-19 room-ID-keyed picture assignment
-- system that replaced LocationView's old text-heuristic "variant"
-- system entirely (per Steven: "i think i would like to simplify this").
--
-- Run: luajit test/test_locationview_roompictures.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local tmpDir = "/tmp/claude_locationview_test_roompics"
os.execute("rm -rf " .. tmpDir .. " && mkdir -p " .. tmpDir)
local f = io.open(tmpDir .. "/Test Room.png", "w"); f:write("fake png"); f:close()

dofile("MyDSL_LocationView.lua")
local M = MyDSL.Location
M.dir = tmpDir
M.roomMap = {}
M.roomPictures = {}

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Room ID 100 is the first to reach "Test Room" -- should auto-claim the
-- real picture file on disk.
local path1, source1 = M.pathForRoomId("100", "Test Room")
check("first room ID auto-claims the existing picture file",
  path1 == tmpDir .. "/Test Room.png" and source1 == "auto-safe")
check("auto-claim persists into M.roomPictures", M.roomPictures["100"] == path1)

-- Room ID 200 shares the exact same name -- a real duplicate. It must
-- NOT silently reuse room 100's picture.
local path2, source2 = M.pathForRoomId("200", "Test Room")
check("a second room ID sharing the same name gets no auto picture",
  path2 == nil and source2 == "conflict")

-- Re-resolving room 100 must hit the cached assignment directly, not
-- re-derive it (and must NOT flip to "conflict" against its own claim).
local path1b, source1b = M.pathForRoomId("100", "Test Room")
check("re-resolving the same room ID returns its own cached assignment",
  path1b == path1 and source1b == "assigned")

-- isFileClaimedByOther() itself: true for a different ID, false for the
-- claiming ID or an unrelated path.
check("isFileClaimedByOther is true for a different room ID",
  M.isFileClaimedByOther(path1, "999") == true)
check("isFileClaimedByOther is false for the room ID that owns it",
  M.isFileClaimedByOther(path1, "100") == false)
check("isFileClaimedByOther is false for an unrelated path",
  M.isFileClaimedByOther("/nowhere/nothing.png", "999") == false)

-- setImage() must persist the assignment to the CURRENT mapper room ID
-- (this is the real "manual where duplicates arise" flow: standing in
-- room 200, telling it which picture belongs here).
_G.getPlayerRoom = function() return 200 end
M.setImage(tmpDir .. "/Test Room.png")
check("setImage() persists a manual assignment to the current room ID",
  M.roomPictures["200"] == tmpDir .. "/Test Room.png")

-- Now that 200 has its OWN explicit assignment, resolving it again must
-- return that directly, not "conflict".
local path2b, source2b = M.pathForRoomId("200", "Test Room")
check("a manually-assigned room ID resolves cleanly afterward",
  path2b == tmpDir .. "/Test Room.png" and source2b == "assigned")

os.execute("rm -rf " .. tmpDir)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
