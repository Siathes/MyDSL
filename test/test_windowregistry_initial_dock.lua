-- Fresh-profile "everything docks on the right" fix, 2026-08-24, per
-- Steven ("i want my layout currently to be the default so things land
-- in a visual way i can explain to them... currently it opens all
-- windows docked on the right side and have 20someodd windows makes it
-- impossible to see anything").
--
-- Root cause traced into Mudlet's own C++ source (Host::openWindow()):
-- a dock widget that has never existed before in this profile's history
-- is unconditionally created in Qt::RightDockWidgetArea, and Geyser's
-- UserWindow:new() never passes a dock-side argument through when
-- restoreLayout=true (which patchUserWindowConstructor() always sets).
-- Fix: explicitly dock each window per MyDSL_LayoutEngine.lua's own
-- documented region (left/right/bottom panel comments), but ONLY on a
-- genuine first run for this profile -- gated by a one-line marker file
-- so a later restart never fights a since-customized arrangement.
--
-- Run: luajit test/test_windowregistry_initial_dock.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local MARKER = "/tmp/claude_mudlet_home/MyDSL_dock_initialized.lua"
os.execute("rm -f " .. MARKER)

------------------------------------------------------------------------
-- Part 1: a genuinely fresh profile (no marker file yet) -- every
-- startup-visible window gets explicitly docked to its documented side.
------------------------------------------------------------------------
dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
MyDSL.Windows.ensureAll()

check("marker file was created after the first-ever pass",
  io.open(MARKER, "r") ~= nil)

local expected = {
  MyDSL_Chat = "r", MyDSL_Affects = "r", MyDSL_Tick = "r",
  MyDSL_Group = "r", MyDSL_CreatureReference = "r",
  MyDSL_Portrait = "l", MyDSL_Location = "l", MyDSL_ItemReference = "l",
  MyDSL_Focus = "l", MyDSL_RightHere = "l", MyDSL_PlayersNear = "l",
  MyDSL_Combat = "b", MyDSL_History = "b", MyDSL_Scan = "b", MyDSL_Live = "b",
}
local allCorrect = true
for name, side in pairs(expected) do
  if _G.__dockPositionCalls[name] ~= side then
    allCorrect = false
    print(string.format("  MISMATCH: %s expected %s got %s", name, side, tostring(_G.__dockPositionCalls[name])))
  end
end
check("every startup-visible window got its documented dock side on first run", allCorrect)

check("MyDSL_Help (on-demand, not in the mapping) was left alone",
  _G.__dockPositionCalls.MyDSL_Help == nil)
check("MyDSL_Alterform (a Container, not a real dock widget) was left alone",
  _G.__dockPositionCalls.MyDSL_Alterform == nil)

------------------------------------------------------------------------
-- Part 2: a real restart of the SAME profile (marker file now exists) --
-- must NOT re-dock anything, even if the user has since customized it.
------------------------------------------------------------------------
_G.__dockPositionCalls = {}
MyDSL = nil  -- simulate a real Mudlet restart: fresh Lua state
package.loaded["mudlet_mock"] = nil
require("mudlet_mock")
dofile("MyDSL_LayoutEngine.lua")
dofile("MyDSL_WindowRegistry.lua")
MyDSL.Windows.ensureAll()

check("a later restart of an already-initialized profile docks nothing",
  next(_G.__dockPositionCalls) == nil)

os.execute("rm -f " .. MARKER)

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
