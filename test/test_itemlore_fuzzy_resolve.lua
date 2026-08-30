-- Structural test for the 2026-08-30 fix (Steven, live "MyDSL Test" note:
-- "c ident pants... items arent persisting after identifying"). Root
-- cause: identify() persists correctly, but the equipment/inventory/
-- container hover-click sites looked ItemLore up by the EXACT displayed
-- short description, and DSL doesn't guarantee that matches identify's
-- own canonical object name -- real captured example, same session's log
-- (MyDSL Test/log/2026-08-30#01-21-12.txt): equipment shows "a heat
-- resistant pair of pants", identify reports "Object 'heat resistant
-- pants' is type...". Neither string contains the other, so the old
-- exact-key-only lookup silently found nothing every time this happens.
--
-- Covers both halves of the fix: bestFuzzyMatch()'s new token-overlap
-- tier (MyDSL_DataLayer.lua), and MyDSL.resolveItemLoreRecord() wired
-- into parseEquipLine()'s real hover/click path (MyDSL_DataLayer_ItemLore.lua).
--
-- Run: luajit test/test_itemlore_fuzzy_resolve.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local setLinkCalls = {}
_G.setLink = function(win, cmd, hint) setLinkCalls[#setLinkCalls + 1] = { win = win, cmd = cmd, hint = hint } end

dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_ItemLore.lua")
dofile("MyDSL_DataLayer_ItemLore.lua")
dofile("MyDSL_DataLayer_ScanLook.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

-- ---- bestFuzzyMatch(): the new token-overlap tier ----------------------
local hit = MyDSL.bestFuzzyMatch("a heat resistant pair of pants", {
  { name = "heat resistant pants", tag = "correct" },
  { name = "a leather satchel",    tag = "wrong" },
})
check("token-overlap tier finds the reordered/inserted-word match", hit and hit.tag == "correct")

-- Still refuses to guess when nothing shares enough words (no false positive).
local noHit = MyDSL.bestFuzzyMatch("a completely unrelated trinket", {
  { name = "heat resistant pants" },
})
check("token-overlap tier declines an unrelated name", noHit == nil)

-- Existing exact/substring tiers must still win over the new weaker tier
-- when a stronger match is also available (no regression in tier ordering).
local exact = MyDSL.bestFuzzyMatch("heat resistant pants", {
  { name = "heat resistant pants", tag = "exact" },
  { name = "a heat resistant pair of pants", tag = "token-only" },
})
check("exact match still wins over the weaker token-overlap tier", exact and exact.tag == "exact")

-- ---- MyDSL.resolveItemLoreRecord(): real identify -> real equipment line ----
MyDSL.ItemLore.db["heat resistant pants"] = {
  key = "heat resistant pants", name = "heat resistant pants",
  itemType = "cloth_armor", armorClass = { pierce = 11, bash = 11, slash = 11, magic = 6 },
  source = "identify",
}

local rec, resolvedName = MyDSL.resolveItemLoreRecord("a heat resistant pair of pants")
check("resolveItemLoreRecord finds the identify record despite the name mismatch",
  rec ~= nil and rec.armorClass ~= nil)
check("resolveItemLoreRecord returns the DB's canonical name, not the raw display text",
  resolvedName == "heat resistant pants")

-- ---- End-to-end: parseEquipLine()'s real hover/click wiring ----------------
MyDSL.beginEquip()
_G.line = "<worn on legs>      (Fireproof) (Glowing) a heat resistant pair of pants"
local bodyTriggerId = MyDSL._triggers.equipBody
_G.__triggers[bodyTriggerId].func()

check("a hover was applied for the mismatched-name equipment line", #setLinkCalls == 1)
check("the click command renders the DB's resolved name, so MyDSL_ItemReference's own lookup succeeds",
  setLinkCalls[1] and setLinkCalls[1].cmd:find('render("heat resistant pants")', 1, true) ~= nil)
check("the hover hint carries real stats, not the old blank 'no data' state",
  setLinkCalls[1] and setLinkCalls[1].hint:find("Item Reference") ~= nil)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
