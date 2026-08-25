-- Structural test for the 2026-07-19 "eq of others" hover feature, per
-- Steven ("integrate the eq of others hover text note"). Confirmed real
-- format via log corpus: "<Name> is using:" (both mobs, e.g. "Brash is
-- using:", and real player/dragon characters, e.g. "Qinrathaz is
-- using:") followed by the exact same "<slot>  (flags) item" body-line
-- shape as your own "You are using:" listing.
--
-- Run: luajit test/test_others_equipment_hover.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

-- setLink isn't stubbed in the shared mock at all -- spy on it here so
-- this test can confirm the hover actually gets applied, without
-- changing the shared mock for every other test.
local setLinkCalls = {}
_G.setLink = function(win, cmd, hint) setLinkCalls[#setLinkCalls + 1] = { win = win, cmd = cmd, hint = hint } end

dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_DataLayer_ScanLook.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- Real captured multi-slot block (Qinrathaz, MyDSL/log/2026-07-19#16-33-40.html).
MyDSL.beginOthersEquip("Qinrathaz")
check("beginOthersEquip registers a body trigger", MyDSL._triggers.othersEquipBody ~= nil)

local realLines = {
  "<used as light>     (Glowing) a glowing blue crystal",
  "<worn on finger>    a tarnished mithril ring",
  "<worn around neck>  (Glowing) a silvery-white feather",
  "<worn on head>      (Glowing) a tarnished gold crown",
  "<held>              the book of Knowledge",
}
for _, ln in ipairs(realLines) do
  local rawSlot, rest = ln:match("^<([a-z ]+)>%s*(.+)$")
  MyDSL.parseOthersEquipLine(rest)
end
check("a hover was applied for every real item line", #setLinkCalls == #realLines)
check("the last hover's hint mentions Item Reference",
  setLinkCalls[#setLinkCalls] and setLinkCalls[#setLinkCalls].hint:find("Item Reference") ~= nil)

-- "(nothing)" (an empty slot) must not attempt a hover.
setLinkCalls = {}
MyDSL.parseOthersEquipLine("(nothing)")
check("(nothing) produces no hover", #setLinkCalls == 0)

-- Seeing someone ELSE's equipment must never touch YOUR OWN equipment
-- state -- that table specifically drives CharacterAssist's rearm/
-- spellup decisions about your own gear.
MyDSL.State.equipment = MyDSL.State.equipment or {}
MyDSL.State.equipment.slots = { wielded = { item = "your own sword", flags = {} } }
setLinkCalls = {}
MyDSL.parseOthersEquipLine("(Glowing) someone else's amulet")
check("MyDSL.State.equipment.slots is never touched by others' equipment",
  MyDSL.State.equipment.slots.wielded.item == "your own sword"
  and MyDSL.State.equipment.slots["worn around neck"] == nil)

-- Blank line ends the body capture (same mechanism as your own
-- equipment's endEquip(), but no state to flush here since there's
-- nothing accumulated).
_G.line = ""
local bodyTriggerId = MyDSL._triggers.othersEquipBody
_G.__triggers[bodyTriggerId].func()
check("a blank line kills the body trigger", MyDSL._triggers.othersEquipBody == nil)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
