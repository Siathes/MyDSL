-- =============================================================================
-- MyDSL_ItemLore.lua  --  Persistent, cross-session item-stats DB
-- =============================================================================
-- Layer 4, first slice. Per Steven (2026-07-16): "it should use the skill
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

-- merge(rec) -- upsert by rec.key. Only overwrites fields present
-- (non-nil) in the new capture, leaving everything else untouched. Same
-- defensive shape as CreatureLore.merge() (a partial/interrupted capture
-- can't blank out good data), and the mechanism that makes the
-- lore-can't-downgrade-identify guarantee above hold automatically.
function IL.merge(rec)
  if not rec or not rec.key or rec.key == "" then return end
  local existing = IL.db[rec.key] or {}
  for _, f in ipairs(FIELDS) do
    if rec[f] ~= nil then existing[f] = rec[f] end
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
