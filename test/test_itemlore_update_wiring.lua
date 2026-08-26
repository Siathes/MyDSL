-- Real, severe bug found via the MyDSL 1.0 roadmap's test-coverage sweep
-- (2026-08-26): the 2026-08-25 DataLayer split-by-domain refactor moved
-- MyDSL_DataLayer_ItemLore.lua's endEquip()/endInventory() out into their
-- own file, but the shared `update(section, fields)` bulk-writer they
-- both call stayed a `local function` back in MyDSL_DataLayer.lua -- a
-- Lua `local` never crosses a separately dofile()'d chunk, so both call
-- sites threw "attempt to call global 'update' (a nil value)" on every
-- real capture. Confirmed via git-stash-equivalent (removing the
-- MyDSL.update promotion) that this exact error reproduces. Neither
-- existing equipment/inventory test (test_others_equipment_hover.lua,
-- test_itemlore_merge_fix.lua) ever called the real endEquip()/
-- endInventory() functions -- both manually seeded MyDSL.State directly,
-- which is exactly why this went uncaught.
--
-- Run: luajit test/test_itemlore_update_wiring.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

_G.matches = _G.matches or {}
MyDSL = MyDSL or {}
dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_DataLayer_ItemLore.lua")

-- ---- endEquip() really writes into MyDSL.State via MyDSL.update() ----------

local okEquip, errEquip = pcall(function()
  MyDSL.beginEquip()
  MyDSL.parseEquipLine("wielded", "a longsword")
  MyDSL.endEquip()
end)

check("endEquip() runs with no error", okEquip)
if not okEquip then print("  error was: " .. tostring(errEquip)) end
check("endEquip() actually reaches MyDSL.State.equipment.slots",
  MyDSL.State.equipment and MyDSL.State.equipment.slots
    and MyDSL.State.equipment.slots.wielded
    and MyDSL.State.equipment.slots.wielded.item == "a longsword")

-- ---- endInventory() really writes into MyDSL.State via MyDSL.update() -----

local okInv, errInv = pcall(function()
  MyDSL.beginInventory()
  MyDSL.parseInventoryLine("(1) a torch")
  MyDSL.endInventory()
end)

check("endInventory() runs with no error", okInv)
if not okInv then print("  error was: " .. tostring(errInv)) end
check("endInventory() actually reaches MyDSL.State.inventory.items",
  MyDSL.State.inventory and MyDSL.State.inventory.items
    and MyDSL.State.inventory.items["torch"]
    and MyDSL.State.inventory.items["torch"].item == "a torch"
    and MyDSL.State.inventory.items["torch"].count == 1)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
