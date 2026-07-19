-- Structural test for the 2026-07-19 IL.merge() fix: a real `identify`
-- capture must clear stale/wrong FULL_STAT_FIELDS values (e.g. a bad
-- scrape-imported extraFlags) when it confirms the item has none, instead
-- of preserving whatever was already in the DB. `lore` must keep its old
-- fill-gaps-only behavior (never touches fields it doesn't set at all).
--
-- Run: luajit test/test_itemlore_merge_fix.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_ItemLore.lua")
local IL = MyDSL.ItemLore

local failures = 0
local function check(name, cond)
  if cond then
    print("PASS: " .. name)
  else
    print("FAIL: " .. name)
    failures = failures + 1
  end
end

-- Seed a stale scrape-imported record, same shape as the real "badger
-- claw" bug: wrong/stale extraFlags sitting there from importScraped().
IL.db["badger claw"] = {
  key = "badger claw", name = "badger claw", itemType = "weapon",
  extraFlags = "2 hit, 2 dam", source = "shatteredarchive", scrapedAt = 1,
}

-- A real in-game identify: "Object 'badger claw' is type weapon, extra
-- flags none." -- beginIdentify() turns "none" into extraFlags=nil, and
-- reports real weapon stats identify actually captured.
IL.merge({
  key = "badger claw", name = "badger claw", itemType = "weapon",
  weaponType = "exotic", damageDice = "3d4", damageAvg = 7,
  affects = { { stat = "damage roll", amount = 2 }, { stat = "hit roll", amount = 2 } },
  source = "identify",
})

local rec = IL.get("badger claw")
check("identify clears stale extraFlags to nil (confirmed 'none')", rec.extraFlags == nil)
check("identify still applies real fields it captured (damageDice)", rec.damageDice == "3d4")
check("identify still applies real fields it captured (affects)", rec.affects and #rec.affects == 2)
check("source updated to identify", rec.source == "identify")

-- Second scenario: identify legitimately DOES have weaponFlags -- must
-- still get applied normally (this isn't a "always clear" regression).
IL.db["glowing sword"] = {
  key = "glowing sword", name = "glowing sword", itemType = "weapon",
  weaponFlags = "stale wrong flags", source = "shatteredarchive",
}
IL.merge({
  key = "glowing sword", name = "glowing sword", itemType = "weapon",
  weaponFlags = "glow, hum", source = "identify",
})
local rec2 = IL.get("glowing sword")
check("identify overwrites a present field normally", rec2.weaponFlags == "glow, hum")

-- Third scenario: a `lore` capture (partial) must NOT clear fields it
-- doesn't report -- the original fill-gaps-only guarantee must survive.
IL.db["old dagger"] = {
  key = "old dagger", name = "old dagger", itemType = "weapon",
  armorClass = { pierce = 1, bash = 1, slash = 1, magic = 1 },
  affects = { { stat = "damage roll", amount = 3 } },
  source = "identify",
}
IL.merge({
  key = "old dagger", name = "old dagger", itemType = "weapon",
  weight = 5, source = "lore",
})
local rec3 = IL.get("old dagger")
check("lore never clears fields it doesn't report (armorClass survives)", rec3.armorClass ~= nil)
check("lore never clears fields it doesn't report (affects survives)", rec3.affects ~= nil)
check("lore still fills the field it does have (weight)", rec3.weight == 5)

-- Fourth scenario: always-present identify fields (weight/value/level/
-- material/itemType/name) are untouched by the FULL_STAT_FIELDS logic --
-- confirm they still work exactly as before (not accidentally added to
-- the clear-if-absent list).
IL.db["plain robe"] = { key = "plain robe", name = "plain robe", weight = 99 }
IL.merge({ key = "plain robe", name = "plain robe", itemType = "armor", source = "identify" })
local rec4 = IL.get("plain robe")
check("non-FULL_STAT_FIELDS fields not present in capture are left alone", rec4.weight == 99)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
