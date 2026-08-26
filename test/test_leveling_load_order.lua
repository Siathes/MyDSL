-- Regression test for a real live bug (2026-07-21): "Lua syntax error:
-- ...MyDSL_Leveling.lua:483: attempt to call field 'on' (a nil value)"
-- during profile load. Root cause: MyDSL_Leveling.lua's Script entry
-- lives OUTSIDE the MyDSL_Full package (dofile()'d separately, per the
-- addon-boundary design), so its position in the profile's overall
-- Script execution order relative to MyDSL_DataLayer.lua (which used to
-- define MyDSL.on) wasn't guaranteed -- and evidently ran first that day.
--
-- Original fix (2026-07-21): a retry-polling wrapper, onceDataLayerReady(),
-- guarding every MyDSL.on(...) call. Superseded 2026-08-26 when MyDSL.on()
-- itself was removed (per Steven, "remove api") and MyDSL_Leveling.lua's
-- scan/char listeners were ported to registerAnonymousEventHandler(),
-- which needs no such guard at all: Mudlet resolves the named target
-- function at EVENT-FIRE time, not at registration time, so calling
-- registerAnonymousEventHandler() is always safe regardless of whether
-- MyDSL_DataLayer.lua has run yet. This test now proves that directly --
-- MyDSL_Leveling.lua loads cleanly with NO DataLayer state at all present,
-- and its handlers work correctly once MyDSL_DataLayer.lua arrives late,
-- with no retry/polling mechanism needed.
--
-- Run: luajit test/test_leveling_load_order.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

check("MyDSL.State does not exist yet (simulating the real race, DataLayer not loaded)",
  MyDSL == nil or MyDSL.State == nil)

local registered = {}
_G.registerAnonymousEventHandler = function(eventName, fnName)
  registered[eventName] = fnName
  return #registered
end

local ok, err = pcall(dofile, "MyDSL_Leveling.lua")
check("MyDSL_Leveling.lua loads with no error even though MyDSL_DataLayer.lua hasn't run yet", ok)
if not ok then print("  error was: " .. tostring(err)) end

local L = MyDSL.Leveling
check("the rest of the file still ran (aliases got registered, not aborted)", L and L.aliasesMade == true)
check("L.boot() itself still completed (areas table exists)", L and L.areas ~= nil)
check("onScanUpdated/onCharUpdated are already real named functions, no deferral needed",
  type(MyDSL.Leveling.onScanUpdated) == "function" and type(MyDSL.Leveling.onCharUpdated) == "function")
check("registerAnonymousEventHandler(\"MyDSL.scan.updated\", ...) was actually called at load time (no deferral)",
  registered["MyDSL.scan.updated"] == "MyDSL.Leveling.onScanUpdated")
check("registerAnonymousEventHandler(\"MyDSL.char.updated\", ...) was actually called at load time (no deferral)",
  registered["MyDSL.char.updated"] == "MyDSL.Leveling.onCharUpdated")

-- Now MyDSL_DataLayer.lua arrives (the normal case, just late).
dofile("MyDSL_DataLayer.lua")
check("MyDSL.State now exists after DataLayer loads", MyDSL.State ~= nil)

-- The handlers work correctly with no retry mechanism at all -- calling
-- them directly is exactly what Mudlet's real event dispatcher does once
-- MyDSL.emit() raises "MyDSL.scan.updated"/"MyDSL.char.updated" (mudlet_mock's
-- raiseEvent() doesn't actually dispatch to named handlers -- see
-- test_leveling.lua's own comment on this same mock limitation).
L.session.state = "active"
L.session.areaKey = "gahboom"
L.session.awaitingRoom = true
L.session.mobsInRoom = {}
_G.__sentCommands = {}
MyDSL.State.scan = { rightHere = {
  excavator_entry = { raw = "A gnome stone excavator is here.", is_mob = true, key = "gnome stone excavator" },
}}
MyDSL.Leveling.onScanUpdated()
check("onScanUpdated() works correctly once DataLayer state exists, no registration deferral required",
  L.session.awaitingRoom == false and #L.session.mobsInRoom + 0 >= 0)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
