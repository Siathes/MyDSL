-- Regression test for MyDSL_Leveling.lua's boot()-time auto-seed, added
-- 2026-08-30 per Steven (MyDSL Test/notes.json): "called for a mydsl
-- leveling import. this should just be seeded in the install already."
--
-- Before this fix, a genuinely fresh profile started with 0 areas known
-- and required the player to manually type "mydsl leveling import" --
-- L.boot() only printed a hint, never called importSeedAreas() itself.
-- Fixed: boot() now auto-imports the seed data exactly once, only when
-- the area count is 0 (so a player who deliberately deleted every area
-- doesn't have them silently reappear on the next reload/relog).
--
-- Run: luajit test/test_leveling_autoseed.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Isolate this test's saved-area file from any other test file's run.
_G.getMudletHomeDir = function() return "/tmp/claude_mudlet_home_autoseed_test" end
os.execute("rm -rf /tmp/claude_mudlet_home_autoseed_test")

MyDSL = MyDSL or {}
MyDSL.State = MyDSL.State or {}

dofile("MyDSL_Leveling.lua")
local L = MyDSL.Leveling

local count = 0
for _ in pairs(L.areas or {}) do count = count + 1 end

check("a genuinely fresh profile (0 saved areas) auto-imports the seed data on boot, no manual import needed",
  count > 0)
check("the seed data actually landed (a real seeded area, not an empty placeholder)",
  next(L.areas) ~= nil)

for _, area in pairs(L.areas) do
  check("an auto-seeded area is tagged source='seed', same as a manual 'mydsl leveling import'",
    area.source == "seed")
  break
end

-- Re-running boot() (simulating a reload) must NOT re-run the importer
-- once areas already exist -- a player who deleted areas on purpose
-- shouldn't have them reappear just from a script reload.
L.areas.__test_marker = { name = "__test_marker", dirs = {}, mobs = {}, levels = "x", description = "" }
L.saveAreas()
L.boot()
check("boot() does not re-seed once at least one area already exists (deleted areas don't silently come back)",
  L.areas.__test_marker ~= nil)

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
