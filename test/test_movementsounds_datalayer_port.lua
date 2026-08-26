-- Real fix 2026-08-26, per Steven ("remove api"): the deprecated
-- MyDSL.get()/MyDSL.set() indirection API was removed from
-- MyDSL_DataLayer.lua -- MyDSL_MovementSounds.lua was its one remaining
-- real caller project-wide (docs/MYDSL_1.0_MODULE_REDESIGN.md #1/#14).
-- dataGet() now reads MyDSL.State directly, the same lookup MyDSL.get()
-- always did with one extra indirection.
--
-- Run: luajit test/test_movementsounds_datalayer_port.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

MyDSL = MyDSL or {}
MyDSL.State = { char = {}, room = {} }

check("MyDSL.get/MyDSL.set do not exist (removed)", MyDSL.get == nil and MyDSL.set == nil)

dofile("MyDSL_MovementSounds.lua")

MyDSL.State.char.is_riding = true
check("mode() reads is_riding straight from MyDSL.State (no Get/Set API involved)",
  MyDSL.MoveSound.mode() == "ride")

MyDSL.State.char.is_riding = false
MyDSL.State.char.is_flying = true
check("mode() reads is_flying straight from MyDSL.State", MyDSL.MoveSound.mode() == "fly")

MyDSL.State.char.is_flying = false
MyDSL.State.room.sector = "shallow swim"
check("isSwimmingSector() reads room.sector straight from MyDSL.State", MyDSL.MoveSound.isSwimmingSector() == true)
check("mode() falls through to swim once riding/flying are both false", MyDSL.MoveSound.mode() == "swim")

MyDSL.State.room.sector = "forest"
check("mode() falls back to walk when nothing else applies", MyDSL.MoveSound.mode() == "walk")

-- GMCP fallback path must still work when MyDSL.State has no entry at all
-- for that section (e.g. DataLayer not loaded yet).
MyDSL.State.char = nil
_G.gmcp = { char_data = { is_riding = true } }
check("dataGet() still falls back to raw GMCP when MyDSL.State[section] is absent",
  MyDSL.MoveSound.mode() == "ride")

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
