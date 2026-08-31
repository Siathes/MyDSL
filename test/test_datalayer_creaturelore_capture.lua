-- Real structural coverage for CreatureLore capture, written 2026-08-25
-- alongside splitting this domain out of MyDSL_DataLayer.lua into its own
-- file (MyDSL_DataLayer_CreatureLore.lua) -- a real pre-existing coverage
-- gap (this capture had zero tests before the split, confirmed via grep
-- across every existing test file), closed while touching this code
-- anyway rather than left open.
--
-- Real corpus fixture, verbatim (log/2026-07-11#12-15-16.html).
--
-- Run: luajit test/test_datalayer_creaturelore_capture.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_DataLayer_CreatureLore.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

check("beginCreatureLore exists on the split-out file", type(MyDSL.beginCreatureLore) == "function")
check("parseCreatureLoreLine exists on the split-out file", type(MyDSL.parseCreatureLoreLine) == "function")
check("endCreatureLore exists on the split-out file", type(MyDSL.endCreatureLore) == "function")

MyDSL.beginCreatureLore("Creature: a gnome in a protective heat suit Race: tinker gnome")
check("beginCreatureLore captures name", MyDSL.State.creaturelore.name == "a gnome in a protective heat suit")
check("beginCreatureLore captures race", MyDSL.State.creaturelore.race == "tinker gnome")
check("beginCreatureLore derives a normalized key (article stripped)",
  MyDSL.State.creaturelore.key == "gnome in a protective heat suit")
check("beginCreatureLore installs the body catch-all trigger", MyDSL._triggers.loreBody ~= nil)

local realBody = {
  "----------------------------------------------------------",
  "a gnome in a protective heat suit appears to be a good soul.",
  "Their wealth appears to be 0 gold and 0 silver",
  "They appear to be male.",
  "The base health of this creature is 5797.",
  "The base magically ability of this creature is 1214.",
  "This creature is upon the cycle of training '52'",
  "This creature does 6d7 damage in a punch manner.",
  "The creature has the following characteristics:",
  "Immunities: summon charm fire tornado",
  "Resistances: mental disease",
}
for _, ln in ipairs(realBody) do
  _G.line = ln
  _G.__triggers[MyDSL._triggers.loreBody].func()
end

local r = MyDSL.State.creaturelore
check("alignment captured (real 'appears to be X soul' line)", r.alignmentText == "good")
check("wealth captured (gold/silver)", r.gold == 0 and r.silver == 0)
check("sex NOT overwritten by the alignment-shaped line ('They appear to be male.')",
  r.sex == "male")
check("hp captured", r.hp == 5797)
check("magic captured", r.magic == 1214)
check("training cycle captured", r.trainingCycle == 52)
check("damage dice + type captured", r.damage == "6d7" and r.damageType == "punch")
check("immunities captured as a real table, not a bare string",
  type(r.immunities) == "table" and #r.immunities == 4 and r.immunities[1] == "summon")
check("resistances captured as a table", type(r.resists) == "table" and #r.resists == 2)

_G.line = ""
MyDSL.endCreatureLore()
check("endCreatureLore kills the body trigger", MyDSL._triggers.loreBody == nil)
check("endCreatureLore stamps last_updated", MyDSL.State.creaturelore.last_updated > 0)

------------------------------------------------------------------------
-- The real trigger registration itself: fires on the exact confirmed
-- header line shape and calls beginCreatureLore with it.
------------------------------------------------------------------------
check("the real loreStart trigger is registered", MyDSL._triggers.loreStart ~= nil)
check("loreStart's real pattern is the confirmed real header shape",
  _G.__triggers[MyDSL._triggers.loreStart].pattern == "^Creature:\\s")

------------------------------------------------------------------------
-- Vulnerabilities capture -- real corpus fixture confirmed 2026-08-30 via
-- a live screenshot (bloodshackle brute). DSL's own game text misspells
-- the label ("Vulnerbilities:" not "Vulnerabilities:"), which is why the
-- correctly-spelled pattern alone never matched anything -- see
-- MyDSL_DataLayer_CreatureLore.lua's own comment on the fix.
------------------------------------------------------------------------
MyDSL.beginCreatureLore("Creature: a bloodshackle brute Race: half-ogre")
local vulnBody = {
  "The creature has the following characteristics:",
  "Resistances: blunt",
  "Vulnerbilities: mental",
}
for _, ln in ipairs(vulnBody) do
  _G.line = ln
  _G.__triggers[MyDSL._triggers.loreBody].func()
end
local rv = MyDSL.State.creaturelore
check("vulnerabilities captured from DSL's real misspelled label ('Vulnerbilities:')",
  type(rv.vulns) == "table" and #rv.vulns == 1 and rv.vulns[1] == "mental")
check("resistances still captured alongside the vulnerabilities fix",
  type(rv.resists) == "table" and #rv.resists == 1 and rv.resists[1] == "blunt")

_G.line = ""
MyDSL.endCreatureLore()

-- Correctly-spelled fallback still works too, in case DSL ever fixes the
-- typo or another mob uses the correct spelling.
MyDSL.beginCreatureLore("Creature: a test correctly-spelled mob Race: human")
_G.line = "Vulnerabilities: fire"
_G.__triggers[MyDSL._triggers.loreBody].func()
check("correctly-spelled 'Vulnerabilities:' still matches as a fallback",
  type(MyDSL.State.creaturelore.vulns) == "table" and MyDSL.State.creaturelore.vulns[1] == "fire")
_G.line = ""
MyDSL.endCreatureLore()

print(string.rep("-", 60))
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
