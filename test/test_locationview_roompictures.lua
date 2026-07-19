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

-- Real bug fixed 2026-07-19, per Steven's 6 real "The Tail of the Stone
-- Dragon" rooms: the first room ID auto-claimed correctly, but the
-- second just said "no picture" instead of finding an already-existing
-- "(2)" file left over from the old variant system. pathForRoomId() must
-- check numbered variant files too, not just the plain name.
local f3a = io.open(tmpDir .. "/Tail Room.png", "w"); f3a:write("fake"); f3a:close()
local f3b = io.open(tmpDir .. "/Tail Room (2).png", "w"); f3b:write("fake"); f3b:close()
local pathA, sourceA = M.pathForRoomId("400", "Tail Room")
check("first room ID claims the plain-name file", sourceA == "auto-safe")
local pathB, sourceB = M.pathForRoomId("401", "Tail Room")
check("second room ID finds the pre-existing numbered variant instead of giving up",
  pathB == tmpDir .. "/Tail Room (2).png" and sourceB == "auto-variant")
check("the numbered-variant claim persists too", M.roomPictures["401"] == pathB)
-- A third room ID, same name, with no more pre-existing files -- must
-- correctly fall through to "conflict", not invent anything.
local pathC, sourceC = M.pathForRoomId("402", "Tail Room")
check("a third room ID with no existing file left to claim reports conflict",
  pathC == nil and sourceC == "conflict")

-- fileForRoomVariant()/nextAvailableFilename() -- the 2026-07-19
-- auto-increment-suggestion feature ("can it auto increment in the style
-- we did before ... until no file is present then ask?").
check("fileForRoomVariant index 1 is the plain name",
  M.fileForRoomVariant("The Wing of the Stone Dragon", 1) == "The Wing of the Stone Dragon.png")
check("fileForRoomVariant index 2 uses the old ' (N)' suffix convention",
  M.fileForRoomVariant("The Wing of the Stone Dragon", 2) == "The Wing of the Stone Dragon (2).png")

-- "Test Room.png" already exists on disk (claimed by room 100); the next
-- suggestion must skip it and land on "Test Room (2).png".
local suggestedFile, suggestedPath = M.nextAvailableFilename("Test Room")
check("nextAvailableFilename skips an existing file and suggests (2)",
  suggestedFile == "Test Room (2).png" and suggestedPath == (tmpDir .. "/Test Room (2).png"))

-- Once that suggested file actually exists too, the next suggestion must
-- skip to (3).
local f2 = io.open((tmpDir .. "/Test Room (2).png"), "w"); f2:write("fake"); f2:close()
local suggestedFile2 = M.nextAvailableFilename("Test Room")
check("nextAvailableFilename keeps incrementing past additional taken slots",
  suggestedFile2 == "Test Room (3).png")

-- resolveImageInput() -- bare filename resolves against M.dir; an
-- absolute path passes through unchanged (backward compatible).
check("resolveImageInput resolves a bare filename against M.dir",
  M.resolveImageInput("Test Room (2).png") == (tmpDir .. "/Test Room (2).png"))
check("resolveImageInput passes an absolute path through unchanged",
  M.resolveImageInput("/some/absolute/path.png") == "/some/absolute/path.png")

-- setImage() end-to-end with a bare filename (not a full path) -- the
-- actual ask: "instead of set path, can we set filename".
_G.getPlayerRoom = function() return 300 end
M.setImage("Test Room (2).png")
check("setImage() accepts a bare filename and resolves+persists it",
  M.roomPictures["300"] == (tmpDir .. "/Test Room (2).png"))

os.execute("rm -rf " .. tmpDir)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
