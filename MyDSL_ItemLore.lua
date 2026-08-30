-- =============================================================================
-- MyDSL_ItemLore.lua  --  Persistent, cross-session item-stats DB
-- =============================================================================
-- Layer 4, first slice. Per the maintainer (2026-07-16): "it should use the skill
-- lore, and the spell identify to fill a database of items stats in game."
--
-- Directly modeled on MyDSL_CreatureLore.lua's real, already-proven merge
-- pattern (upsert-by-key for live captures, fill-gaps-only for a bulk
-- scrape import). Shared across characters, not character-bound -- same
-- reasoning as CreatureLore/ThemeEngine: a sword's damage dice are
-- objective game data, not something that differs by which character
-- identified it.
--
-- Key design point, confirmed against real captured `identify`/`lore`
-- output (see docs/CapturedPatterns_Reference.txt and CHANGELOG.md for the
-- exact transcripts): `lore` is a chance-based skill that never reports
-- bonuses/enchants (no "Affects X by N" lines, no "Weapons flags:", no
-- "Armor class is..."), while `identify` (the spell) reports everything
-- including those. Because merge() below only overwrites fields the new
-- capture actually has (non-nil) and leaves the rest untouched, a `lore`
-- capture can NEVER downgrade an already-`identify`d item back to
-- partial -- it simply never includes those keys in the first place. No
-- separate "partial vs. full" merge path is needed; this is automatic.
--
-- Real bug found live 2026-07-19, per the maintainer ("when an item is identified
-- in game, it doesnt replace the shattered archive info and persist. it
-- reverts to shattered info not the identified info"). Confirmed by
-- decoding the live itemlore_db.lua: a real in-game identify of "badger
-- claw" ("... extra flags none.") correctly updated affects/damageDice/
-- lastIdentified/source, but left a stale scrape-imported
-- extraFlags="2 hit, 2 dam" in place untouched. Root cause: the
-- fill-if-non-nil rule above is only safe for `lore`'s genuine partiality
-- -- `identify` is authoritative, and DSL's real identify output always
-- reports an explicit value for these fields (e.g. "extra flags none"),
-- which our own parser turns into Lua `nil` -- indistinguishable, to plain
-- merge(), from "this capture doesn't know." So a real identify
-- confirming an item has NO flags/bonuses/AC/etc. could never clear a
-- wrong or stale scrape-derived value already sitting in that field. See
-- FULL_STAT_FIELDS below for the fix: identify captures now authoritatively
-- clear these fields to nil when absent, instead of preserving whatever
-- was there before. Items already identified once under the old buggy
-- behavior need a fresh in-game identify to clear their stale fields --
-- there's no way to tell retroactively, from the DB alone, which stored
-- values are real vs. leftover scrape data, so no blanket auto-cleanup is
-- safe here (same reasoning as the spellCharges cleanup below, which COULD
-- be done safely only because it had an unambiguous "wrong item type"
-- signal to key off).
-- =============================================================================

MyDSL           = MyDSL           or {}
MyDSL.ItemLore  = MyDSL.ItemLore  or {}
local IL = MyDSL.ItemLore

IL.db = IL.db or {}

local function dbFile()
  return getMudletHomeDir() .. "/MyDSL/itemlore_db.lua"
end

-- table.load(file, target) does not return anything -- it unpickles INTO
-- the explicit 2nd-argument table (confirmed real Mudlet behavior, same
-- bug class already found/fixed across ~10 call sites this profile --
-- see MyDSL_CreatureLore.lua's identical comment for the full writeup).
function IL.load()
  local f = io.open(dbFile(), "r")
  if not f then
    debugc("[MyDSL] ItemLore: no saved DB file yet at " .. dbFile())
    return
  end
  f:close()
  local data = {}
  local ok = pcall(table.load, dbFile(), data)
  if ok and next(data) then
    IL.db = data
  else
    debugc("[MyDSL] ItemLore: DB file exists but failed to load")
  end
end

function IL.save()
  pcall(table.save, dbFile(), IL.db)
end

-- get(key) -- key is the same normalized name every lookup computes
-- (name:lower(), leading "a/an/the" stripped, same convention as
-- CreatureLore/RightHere/TargetView).
function IL.get(key)
  if not key or key == "" then return nil end
  return IL.db[key]
end

-- Fields a live `identify`/`lore` capture can populate (see
-- MyDSL_DataLayer.lua's parseIdentifyLine()/parseLoreItemLine()). `lore`
-- only ever fills a subset of these (itemType/weight/value/level/material/
-- weaponType/spellCharges/spellList/drinkLiquid) -- affects/weaponFlags/
-- armorClass/condition/size/capacity/maxWeight/weightMultiplier/
-- damageDice/damageAvg/extraFlags come from `identify` (or the scrape).
local FIELDS = {
  "name", "itemType", "weight", "value", "level", "material", "extraFlags",
  "weaponType", "damageDice", "damageAvg", "weaponFlags", "armorClass",
  "size", "condition", "capacity", "maxWeight", "weightMultiplier",
  "spellCharges", "spellList", "drinkLiquid", "affects",
}

-- Fields `identify` (the spell) reports authoritatively -- confirmed
-- against real transcripts that identify always gives an explicit answer
-- for each of these (its own conditional block either prints with a real
-- value, or the field is confirmed genuinely absent for this item), never
-- a "didn't check" gap. `lore` never reports any of these at all, so it
-- never sets rec[f] for them and this list has no effect on a lore merge.
local FULL_STAT_FIELDS = {
  "extraFlags", "weaponType", "damageDice", "damageAvg", "weaponFlags",
  "armorClass", "size", "condition", "capacity", "maxWeight",
  "weightMultiplier", "spellCharges", "spellList", "drinkLiquid", "affects",
}

-- merge(rec) -- upsert by rec.key. Fields present (non-nil) in the new
-- capture always overwrite. For a real `identify` capture specifically
-- (rec.source == "identify"), an absent FULL_STAT_FIELDS entry is treated
-- as confirmed-empty and clears any existing value (see the file-header
-- writeup for why) -- everything else (name/itemType/weight/value/level/
-- material, always present in a real identify; anything from `lore`,
-- which never sets these fields to begin with) keeps the original
-- fill-if-non-nil behavior, so a partial `lore` capture still can't
-- downgrade an already-identified item.
function IL.merge(rec)
  if not rec or not rec.key or rec.key == "" then return end
  local existing = IL.db[rec.key] or {}
  local isIdentify = rec.source == "identify"
  for _, f in ipairs(FIELDS) do
    if rec[f] ~= nil then
      existing[f] = rec[f]
    elseif isIdentify and table.contains(FULL_STAT_FIELDS, f) then
      existing[f] = nil
    end
  end
  existing.key            = rec.key
  existing.lastIdentified = os.time()
  existing.source         = rec.source or existing.source
  IL.db[rec.key] = existing
  IL.save()
end

-- hasFullStats(rec) -- true if this record has any field ONLY `identify`
-- (not the weaker `lore` skill) could have filled in. Three-state model,
-- same as CreatureLore's known/seen/unknown: "known" (identify-level
-- detail), "seen" (lore or scrape data only, no bonuses/enchants
-- confirmed), "unknown" (no record at all).
function IL.hasFullStats(rec)
  if type(rec) ~= "table" then return false end
  return rec.affects ~= nil or rec.weaponFlags ~= nil or rec.armorClass ~= nil
end

function IL.knownState(key)
  local rec = IL.get(key)
  if not rec then return "unknown" end
  return IL.hasFullStats(rec) and "known" or "seen"
end

-- importScraped(path) -- fills gaps from a bulk community scrape
-- (shatteredarchive.com/items/all-items, 6,473 items at scrape time).
-- Deliberately does NOT reuse merge(): merge() unconditionally stamps
-- lastIdentified = os.time(), which would misrepresent thousands of
-- items as freshly identified just now; this also never overwrites ANY
-- existing field (official or not), only fills genuinely empty gaps --
-- a real in-game capture always wins. Saves once at the end, not
-- per-record.
local IMPORT_FIELDS = {
  "name", "itemType", "weight", "value", "level", "material", "extraFlags",
  "weaponType", "damageDice", "damageAvg", "armorClass", "area",
}

function IL.importScraped(path)
  path = path or (getMudletHomeDir() .. "/MyDSL/item_scrape_import.lua")
  local f = io.open(path, "r")
  if not f then
    -- Fixed 2026-07-18, real bug found live: "mydsl itemlore import"
    -- silently did nothing on the fresh MyDSL profile (the staging file
    -- only ever existed in DSL2's own MyDSL/ data dir, never copied over
    -- -- this is a raw data file, not part of the script package, same
    -- category as Sounds.zip/RoomPics.zip). The ONLY feedback on a
    -- missing file was debugc(), which only reaches Mudlet's own debug
    -- console (closed by default) -- zero visible sign on the main
    -- console that the command did nothing, or why. Now echo()s a real,
    -- visible error too, matching every other user-facing message in
    -- this file.
    local msg = "[MyDSL] ItemLore: import file not found at " .. tostring(path)
    echo(msg .. "\n")
    debugc(msg)
    return
  end
  f:close()
  local ok, records = pcall(dofile, path)
  if not ok or type(records) ~= "table" then
    local msg = "[MyDSL] ItemLore: import file failed to load: " .. tostring(records)
    echo(msg .. "\n")
    debugc(msg)
    return
  end

  local added, supplemented, untouched = 0, 0, 0
  for _, rec in ipairs(records) do
    if rec.key and rec.key ~= "" then
      local existing = IL.db[rec.key]
      local isNew = existing == nil
      existing = existing or { key = rec.key }
      local filledAny = false
      for _, f2 in ipairs(IMPORT_FIELDS) do
        if existing[f2] == nil and rec[f2] ~= nil then
          existing[f2] = rec[f2]
          filledAny = true
        end
      end
      -- spellInfo -- added 2026-07-18, real gap found live (the maintainer: "the
      -- platinum wand is missing the actual spell it uses magic missle
      -- lvl(30)"). Confirmed the raw scrape record DOES have this --
      -- "spellInfo=[[magic missile]]" -- it just was never in
      -- IMPORT_FIELDS at all, so it was silently dropped on every import
      -- despite being right there in the source file. Not a plain field
      -- copy like the others: the scrape's spellInfo is just a bare spell
      -- name string, while a real in-game `identify` capture builds a
      -- structured spellCharges = {charges=N, level=N, spell="name"}
      -- table (see MyDSL_DataLayer.lua's parseIdentifyLine()) -- mapped
      -- into that same field/shape here (charges/level left nil, since
      -- the scrape has neither) so hover code only ever needs to check
      -- one field name, and a later real `identify` naturally upgrades
      -- this to the full charges+level via merge()'s existing
      -- fill-gaps-only rule, never overwriting a real capture.
      -- NOTE: the scrape has no separate "spell level" number anywhere
      -- (confirmed -- only the bare spell name) -- the "lvl(30)" the maintainer
      -- remembers can only come from a real `identify` on that specific
      -- wand; this fix can't recover a number the source data never had.
      --
      -- RESTRICTED to wand/staff 2026-07-18, real bug found live (the maintainer:
      -- "seems to affect wands and potions, maybe scrolls" -- a "yellow
      -- potion with red swirls" example). Checked the site's own raw HTML
      -- directly (curl): wands/staves always have exactly one clean spell
      -- name in this field (confirmed: 152/152 real wand/staff records,
      -- zero exceptions) -- but potions/scrolls/pills can carry up to 4
      -- spells packed into the SAME field with no real delimiter, e.g.
      -- data-spell="cure light light cure blindness" or "haste reserved
      -- reserved" ("reserved" marks an empty slot). Attempted a greedy
      -- longest-match parse against a 113-entry spell-name dictionary
      -- built from DSL_Helpfiles/*spells.txt -- only ~30% of these
      -- strings resolved unambiguously; the rest have real structural
      -- ambiguity (e.g. is "faerie fog fog detect good" one spell "faerie
      -- fog" + a stray repeated "fog" + "detect good", or something else
      -- entirely?) that can't be resolved with confidence from the
      -- concatenated string alone. Rather than guess and risk showing a
      -- WRONG spell name as if verified, potion/scroll/pill spellInfo is
      -- simply not imported -- those items get real spell data only from
      -- an actual in-game `identify`/`lore`, same as before this fix
      -- existed at all. Wand/staff keeps the reliable mapping.
      if rec.spellInfo and not existing.spellCharges
      and (rec.itemType == "wand" or rec.itemType == "staff") then
        existing.spellCharges = { spell = rec.spellInfo }
        filledAny = true
      end
      if isNew or filledAny then
        if existing.source == nil then existing.source = "shatteredarchive" end
        if existing.scrapedAt == nil then existing.scrapedAt = os.time() end
        IL.db[rec.key] = existing
        if isNew then added = added + 1 else supplemented = supplemented + 1 end
      else
        untouched = untouched + 1
      end
    end
  end
  IL.save()
  local msg = string.format(
    "[MyDSL] ItemLore import: %d new, %d existing supplemented, %d already complete, %d total in DB now.",
    added, supplemented, untouched, (function() local n=0; for _ in pairs(IL.db) do n=n+1 end; return n end)())
  echo(msg .. "\n")
  debugc(msg)
end

-- cleanupBadSpellCharges() -- added 2026-07-18, one-time fixup for
-- anyone (the maintainer included) who already ran "mydsl itemlore import" before
-- the wand/staff restriction above existed. importScraped()'s own
-- fill-gaps-only rule means a stale, wrongly-imported spellCharges
-- (potion/scroll spellInfo mapped in when it shouldn't have been) can
-- never self-correct on a later re-import -- it only fills gaps, never
-- overwrites. Only clears spellCharges that are clearly scrape-derived
-- junk: wrong item type AND no charges/level at all (a real `identify`
-- always fills both, so this can't accidentally delete real captured
-- data). One-time command, not part of the regular surface -- same
-- category as "mydsl itemlore import" itself.
function IL.cleanupBadSpellCharges()
  local cleaned = 0
  for key, rec in pairs(IL.db) do
    if rec.spellCharges and rec.itemType ~= "wand" and rec.itemType ~= "staff"
    and rec.spellCharges.charges == nil and rec.spellCharges.level == nil then
      rec.spellCharges = nil
      cleaned = cleaned + 1
    end
  end
  if cleaned > 0 then IL.save() end
  local msg = string.format("[MyDSL] ItemLore cleanup: cleared %d bad spellCharges entries (wrong item type, scrape-only data).", cleaned)
  echo(msg .. "\n")
  debugc(msg)
end

if not IL._cleanupAliasInstalled then
  tempAlias("^mydsl itemlore cleanup$", [[MyDSL.ItemLore.cleanupBadSpellCharges()]])
  IL._cleanupAliasInstalled = true
end

IL.load()

local function itemCount()
  local n = 0
  for _ in pairs(IL.db) do n = n + 1 end
  return n
end
-- echo(), not just debugc() -- same reasoning as CreatureLore's identical
-- boot-time line: always visible on the main console, a checkable answer
-- to "is this actually persisting" without needing the debug console open.
echo("[MyDSL] ItemLore DB loaded (" .. tostring(itemCount()) .. " items known).\n")
debugc("[MyDSL] ItemLore DB loaded (" .. tostring(itemCount()) .. " items known).")

-- "mydsl itemlore import" -- one-time command, not part of the regular
-- command surface long-term (mirrors "mydsl creaturelore import").
if not IL._importAliasInstalled then
  tempAlias("^mydsl itemlore import$", [[MyDSL.ItemLore.importScraped()]])
  IL._importAliasInstalled = true
end
