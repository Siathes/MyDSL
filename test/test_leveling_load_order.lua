-- Regression test for a real live bug (2026-07-21): "Lua syntax error:
-- ...MyDSL_Leveling.lua:483: attempt to call field 'on' (a nil value)"
-- during profile load. Root cause: MyDSL_Leveling.lua's Script entry
-- lives OUTSIDE the MyDSL_Full package (dofile()'d separately, per the
-- addon-boundary design), so its position in the profile's overall
-- Script execution order relative to MyDSL_DataLayer.lua (which defines
-- MyDSL.on) isn't guaranteed -- and evidently ran first this time.
-- Worse than just the one failing call: a Lua runtime error aborts
-- everything AFTER it in the same linear script execution too, so this
-- also silently skipped alias registration and L.boot() itself for the
-- rest of that load. This test deliberately dofiles MyDSL_Leveling.lua
-- BEFORE MyDSL_DataLayer.lua -- the exact failure ordering -- to prove
-- the whole file still loads cleanly and finishes initializing, and
-- that the deferred MyDSL.on(...) registrations catch up once
-- MyDSL_DataLayer.lua arrives.
--
-- Run: luajit test/test_leveling_load_order.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Capture tempTimer retries instead of letting the mock discard them --
-- same technique the failsafe test in test_leveling.lua already uses.
local pendingRetries = {}
local realTempTimer = _G.tempTimer
_G.tempTimer = function(delay, fn) table.insert(pendingRetries, fn); return #pendingRetries end

check("MyDSL.on does not exist yet (simulating the real race)", MyDSL == nil or MyDSL.on == nil)

local ok, err = pcall(dofile, "MyDSL_Leveling.lua")
check("MyDSL_Leveling.lua loads with no error even though MyDSL.on doesn't exist yet", ok)
if not ok then print("  error was: " .. tostring(err)) end

local L = MyDSL.Leveling
check("the rest of the file still ran (aliases got registered, not aborted)", L and L.aliasesMade == true)
check("L.boot() itself still completed (areas table exists)", L and L.areas ~= nil)
check("a retry was scheduled for the deferred MyDSL.on(...) registrations", #pendingRetries > 0)

-- Now MyDSL_DataLayer.lua arrives (the normal case, just late) --
-- firing the pending retries should complete the deferred registration.
dofile("MyDSL_DataLayer.lua")
check("MyDSL.on now exists after DataLayer loads", MyDSL.on ~= nil)

for _, fn in ipairs(pendingRetries) do fn() end
check("the deferred 'scan' listener is now actually registered",
  MyDSL.listeners.scan ~= nil and #MyDSL.listeners.scan > 0)
check("the deferred 'char' listener is now actually registered",
  MyDSL.listeners.char ~= nil and #MyDSL.listeners.char > 0)

_G.tempTimer = realTempTimer

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
