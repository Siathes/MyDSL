-- Structural test for MyDSL_Leveling.lua (2026-07-19 leveling-assist addon).
-- Covers: seed-area import (fixes the real ["x"]=["x"]={...} syntax bug
-- present in the forum-sourced data), mob show/hide toggling, scan-event-
-- driven mob recognition (reuses MyDSL_DataLayer.lua's scan.rightHere,
-- no duplicate trigger chain), kill-stealing "finish room first" behavior,
-- the failsafe dead-man's-switch, and the HP safety-net auto-stop.
--
-- Run: luajit test/test_leveling.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_Leveling.lua")

local L = MyDSL.Leveling
local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

------------------------------------------------------------------------
-- 1. Seed import
------------------------------------------------------------------------
L.importSeedAreas("MyDSL/leveling_areas_seed.lua")
local areaCount = 0
for _ in pairs(L.areas) do areaCount = areaCount + 1 end
check("imports all 39 areas", areaCount == 39)
check("fixed the duplicated-key syntax bug (gahboom loads with real dirs/mobs)",
  L.areas["gahboom"] and #L.areas["gahboom"].dirs == 51)
check("gahboom's excavator mob has the AlexK-tested single-word kill keyword",
  L.areas["gahboom"].mobs["excavator"] and L.areas["gahboom"].mobs["excavator"].kill_kw == "excavator")
check("crystfield was renamed to cryfield per the later forum correction",
  L.areas["cryfield"] ~= nil and L.areas["crystfield"] == nil)
-- Regression: real live bug (2026-07-19, Steven: "mydsl leveling import
-- looks like it died or never triggered", no error, no output at all).
-- Root cause: the default path used getMudletHomeDir() (whichever
-- profile is CURRENTLY RUNNING the script -- this addon deliberately
-- runs cross-profile, dofile()'d from the MyDSL play profile into the
-- DSL2 git repo), so the seed file was only ever looked for in a
-- profile folder it was never copied into -- confirmed via `ls` against
-- the real live MyDSL profile directory -- and the failure only called
-- debugc(), invisible unless the separate Errors console happens to be
-- open. Fixed: tries the current profile's own MyDSL/ folder first,
-- then falls back to the known DSL2 repo copy this addon actually ships
-- from, and reports "not found" via ce() (visible on the main console).
check("import falls back to the known DSL2 repo path when no explicit path is given "
  .. "(simulating a profile whose own MyDSL/ folder doesn't have the seed file)", (function()
  L.areas = {}
  L.importSeedAreas(nil)  -- no arg -- must resolve via the fallback chain, not just dataDir()
  local n = 0; for _ in pairs(L.areas) do n = n + 1 end
  return n == 39
end)())

check("re-running import is non-destructive (still 39, not 78)", (function()
  L.importSeedAreas("MyDSL/leveling_areas_seed.lua")
  local n = 0; for _ in pairs(L.areas) do n = n + 1 end
  return n == 39
end)())

------------------------------------------------------------------------
-- 2. Mob show/hide toggling
------------------------------------------------------------------------
L.setMobEnabled("gahboom", "excavator", false)
check("hide disables a single mob", L.areas["gahboom"].mobs["excavator"].enabled == false)
L.setMobEnabled("gahboom", "excavator", true)
check("show re-enables a single mob", L.areas["gahboom"].mobs["excavator"].enabled == true)
L.setMobEnabled("gahboom", "all", false)
local anyEnabled = false
for _, m in pairs(L.areas["gahboom"].mobs) do if m.enabled then anyEnabled = true end end
check("hide all disables every mob in the area", not anyEnabled)
L.setMobEnabled("gahboom", "all", true)

------------------------------------------------------------------------
-- 3. Scan-event-driven mob recognition (no duplicate trigger chain --
--    reuses MyDSL.on("scan", ...) fed by MyDSL_DataLayer.lua's own
--    scan.rightHere capture)
------------------------------------------------------------------------
L.session.state = "active"
L.session.areaKey = "gahboom"
L.session.stepIndex = 1
L.session.awaitingRoom = true
L.session.mobsInRoom = {}
_G.__sentCommands = {}

MyDSL.State.scan = MyDSL.State.scan or {}
MyDSL.State.scan.rightHere = {
  excavator_entry = { raw = "A gnome stone excavator is here.", is_mob = true, key = "gnome stone excavator" },
  heat_entry      = { raw = "A gnome in a protective heat suit is studying here.", is_mob = true, key = "gnome in a protective heat suit" },
  fixture_entry   = { raw = "A pile of rubble lies here.", is_mob = false, key = "pile of rubble" },
}
MyDSL.emit("scan")

check("scan event no longer awaiting room (consumed)", L.session.awaitingRoom == false)
check("a kill command was sent for a recognized enabled mob", (function()
  for _, cmd in ipairs(_G.__sentCommands) do
    if cmd == "kill excavator" or cmd == "kill heat" then return true end
  end
  return false
end)())
check("exactly one mob is still queued after popping the first", #L.session.mobsInRoom == 1)
check("the non-mob fixture line was never queued", (function()
  for _, k in ipairs(L.session.mobsInRoom) do
    if k ~= "excavator" and k ~= "heat" then return false end
  end
  return true
end)())

------------------------------------------------------------------------
-- 4. Kill-stealing: finish remaining enabled mobs in the room before
--    advancing (improvement over AlexK's "abandon room" default)
------------------------------------------------------------------------
check("pendingKillMobKey is set while a kill command is outstanding",
  L.session.pendingKillMobKey == "excavator" or L.session.pendingKillMobKey == "heat")
local killStolenTrig = _G.__triggers[L._triggers.killStolen]
_G.matches = { "They aren't here." }
_G.__sentCommands = {}
killStolenTrig.func()
check("kill-stealing/'they aren't here' tries the NEXT mob in this room, not the next step",
  #_G.__sentCommands == 1 and (_G.__sentCommands[1] == "kill excavator" or _G.__sentCommands[1] == "kill heat"))
check("room's mob queue is now empty", #L.session.mobsInRoom == 0)

------------------------------------------------------------------------
-- 5. XP-gain trigger advances kill count and clears the pending kill
------------------------------------------------------------------------
L.session.mobsInRoom = {}
L.session.pendingKillMobKey = "excavator"
local killedBefore, xpBefore = L.session.stats.killed, L.session.stats.xp
_G.matches = { "You receive 1726 experience points.", "1726" }
local xpTrig = _G.__triggers[L._triggers.xpGain]
xpTrig.func()
check("xp-gain trigger increments kill/xp stats", L.session.stats.killed == killedBefore + 1
  and L.session.stats.xp == xpBefore + 1726)
check("xp-gain trigger clears pendingKillMobKey", L.session.pendingKillMobKey == nil)

------------------------------------------------------------------------
-- 6. Failsafe dead-man's-switch
------------------------------------------------------------------------
local capturedFailsafeFn = nil
local realTempTimer = _G.tempTimer
_G.tempTimer = function(delay, fn) capturedFailsafeFn = fn; return 999 end
L.session.state = "active"
L.armFailsafe()
_G.tempTimer = realTempTimer
check("armFailsafe schedules a callback", capturedFailsafeFn ~= nil)
if capturedFailsafeFn then capturedFailsafeFn() end
check("failsafe firing stops the session", L.session.state == "stopped")

------------------------------------------------------------------------
-- 7. HP safety net
------------------------------------------------------------------------
L.session.state = "active"
L.session.hpThreshold = 30
MyDSL.State.char = MyDSL.State.char or {}
MyDSL.State.char.hp = 100
MyDSL.State.char.max_hp = 1000
MyDSL.emit("char")
check("HP safety net stops the session when HP% drops below threshold", L.session.state == "stopped")

L.session.state = "active"
MyDSL.State.char.hp = 900
MyDSL.State.char.max_hp = 1000
MyDSL.emit("char")
check("HP safety net leaves a healthy session running", L.session.state == "active")

L.session.hpThreshold = 0
MyDSL.State.char.hp = 10
MyDSL.emit("char")
check("HP safety net does nothing when disabled (threshold 0)", L.session.state == "active")

------------------------------------------------------------------------
-- 8. Regression: mob matching must survive a leading aura/charmed tag --
--    real live bug (2026-07-20, Steven: "it did not engage the enemies"
--    -- confirmed via the actual Olyndros session log: a full 12-step
--    pass through "philosophy" completed with 0 kills because DSL was
--    printing every mob with a "(Golden Aura)" prefix, e.g. "(Golden
--    Aura) A gnome student is here.", while the seed data's own raw
--    text has no tag ("A gnome student is here."). The exact real room
--    text from that transcript, used verbatim below.
------------------------------------------------------------------------
L.session.state = "active"
L.session.areaKey = "philosophy"
L.session.stepIndex = 1
L.session.awaitingRoom = true
L.session.mobsInRoom = {}
L.session.pendingKillMobKey = nil
_G.__sentCommands = {}

MyDSL.State.scan.rightHere = {
  mount_entry   = { raw = "(Charmed) (Golden Aura) (White Aura) A beautiful white charger, fitted with saddle, is here.", is_mob = true, key = "beautiful white charger" },
  student_entry = { raw = "(Golden Aura) A gnome student is here.", is_mob = true, key = "gnome student" },
  instruct_entry = { raw = "(Golden Aura) A gnome philosophy instructor is here.", is_mob = true, key = "gnome philosophy instructor" },
}
MyDSL.emit("scan")

check("an aura-tagged mob line still engages (real 'philosophy' transcript replay)", (function()
  for _, cmd in ipairs(_G.__sentCommands) do
    if cmd == "kill student" or cmd == "kill instruct" then return true end
  end
  return false
end)())
check("the aura-tagged mount (not a seed-listed mob in this area) is correctly never queued",
  (function()
    for _, k in ipairs(L.session.mobsInRoom) do
      if k ~= "student" and k ~= "instruct" then return false end
    end
    return true
  end)())

------------------------------------------------------------------------
-- 9. Regression: ensureUI() must NEVER create a MiniConsole with a nil
--    parent -- real live bug (2026-07-19, Steven: "that script blanks my
--    main window"). Root cause was MyDSL_WindowRegistry.lua's registry
--    skipping a newly-added key on an in-session reload, so
--    Windows.ensure() returned nil here; Geyser attaches a parentless
--    console to the main window itself. Fixed in both files -- this
--    locks in MyDSL_Leveling.lua's own half: ensure() failing must bail
--    out cleanly, not fall through to an implicit main-window attach.
------------------------------------------------------------------------
local miniConsoleCalls = 0
local realMiniConsoleNew = Geyser.MiniConsole.new
Geyser.MiniConsole.new = function(self, cfg, parent) miniConsoleCalls = miniConsoleCalls + 1; return realMiniConsoleNew(self, cfg, parent) end

local realWindows = MyDSL.Windows
MyDSL.Windows = nil  -- simulate the registry being unavailable, as in the real bug
L._mc.log = nil
L.ensureUI()
check("ensureUI() never creates a console when the window registry is unavailable",
  miniConsoleCalls == 0 and L._mc.log == nil)

MyDSL.Windows = realWindows
Geyser.MiniConsole.new = realMiniConsoleNew

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
