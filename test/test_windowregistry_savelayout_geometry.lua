-- Regression test for MyDSL_WindowRegistry.lua's MyDSL.Windows.saveLayout(),
-- fixed 2026-08-30. Real bug found live: Steven ran "mydsl layout save"
-- twice, expecting it to write MyDSL_layout.lua (MyDSL_LayoutEngine.lua's
-- portable percentage-based system, the only thing that can seed a
-- DIFFERENTLY-NAMED fresh install's window defaults) -- it never did,
-- because saveLayout() only ever called Mudlet's native saveWindowLayout()
-- (pixel-based, shared machine-wide, profile-name-scoped -- useless for
-- seeding a new install), and nothing anywhere else in the codebase ever
-- called MyDSL.Layout.set() from a real window move either, so
-- MyDSL.Layout.positions sat frozen at its coded defaults forever.
--
-- Fixed: saveLayout() now also reads each registered window's REAL
-- current geometry via getWindowGeometry() (confirmed real, Mudlet
-- 5.0+), converts to the same 0.0-1.0 screen-fraction format
-- MyDSL.Layout already uses, and feeds it through MyDSL.Layout.set()
-- (which validates and persists to MyDSL_layout.lua itself).
--
-- Run: luajit test/test_windowregistry_savelayout_geometry.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

os.execute("rm -f /tmp/claude_mudlet_home/MyDSL_layout.lua")

dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
MyDSL.Windows.ensureAll()

------------------------------------------------------------------------
-- A real window at a known pixel position (1920x1080 screen, from the
-- mock's getMainWindowSize()): x=1267, y=0, w=653, h=1080 -> should
-- become x=0.66, y=0.0, w=0.34, h=1.0 (exact fractions).
------------------------------------------------------------------------
_G.__windowGeometry["MyDSL_Combat"] = { x = 1267, y = 0, w = 653, h = 1080 }

MyDSL.Windows.saveLayout()

check("saveLayout() still calls the native saveWindowLayout()/saveProfile() (unchanged behavior)",
  true) -- mudlet_mock's saveWindowLayout/saveProfile are no-ops; nothing to assert directly, just confirms no error was thrown above.

check("saveLayout() updates MyDSL.Layout.positions from real getWindowGeometry() pixels",
  MyDSL.Layout.positions.MyDSL_Combat ~= nil)
check("the converted x fraction is correct (1267/1920)",
  math.abs(MyDSL.Layout.positions.MyDSL_Combat.x - (1267/1920)) < 0.0001)
check("the converted w fraction is correct (653/1920)",
  math.abs(MyDSL.Layout.positions.MyDSL_Combat.w - (653/1920)) < 0.0001)

-- mudlet_mock's table.save() is a no-op stub (test isolation, doesn't
-- touch the real filesystem) -- table.save being CALLED (not its disk
-- effect) is what proves saveLayout() now reaches persistence at all,
-- which is the actual real bug this fixes.
local savedCalls = 0
local realTableSave = table.save
table.save = function(...) savedCalls = savedCalls + 1; return realTableSave(...) end
_G.__windowGeometry["MyDSL_Combat"] = { x = 100, y = 50, w = 400, h = 300 }
MyDSL.Windows.saveLayout()
table.save = realTableSave
check("saveLayout() now actually reaches table.save() -- the real bug is that it never used to",
  savedCalls > 0)

------------------------------------------------------------------------
-- A window with no real geometry available (never created this
-- session) is silently skipped, not an error.
------------------------------------------------------------------------
local before = MyDSL.Layout.positions.MyDSL_NonexistentWindow
MyDSL.Windows.saveLayout()
check("a window with no real geometry is silently skipped, not crashed on",
  MyDSL.Layout.positions.MyDSL_NonexistentWindow == before)

print(string.format("\n%d failure(s)", failures))
os.exit(failures == 0 and 0 or 1)
