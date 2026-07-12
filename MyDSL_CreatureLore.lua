-- =============================================================================
-- MyDSL_CreatureLore.lua  --  Persistent, cross-session creature-lore DB
-- =============================================================================
-- New 2026-07-11, per Steven ("creaturelore should be persistent and
-- tabled... so we can recall creatures for information and to populate the
-- focus window with any creature we have lored over any session").
--
-- MyDSL_DataLayer.lua's endCreatureLore() already had a conditional call to
-- MyDSL.CreatureLore.merge() (and MyDSL_CreatureReference.lua's "Bestiary"
-- window already had a MyDSL.CreatureLore.get() lookup) -- both guarded
-- with "if MyDSL.CreatureLore and ... then" because the module itself was
-- never actually written (confirmed dead reference, tracked in memory from
-- an earlier session). This file is the real implementation both of those
-- call sites were always meant to reach.
--
-- Shared across characters, not character-bound -- same reasoning already
-- recorded for ThemeEngine in CLAUDE.md: a gnome machinist's race/HP/
-- immunities are objective game data, not something that differs by which
-- character looked it up, so there's nothing to key per-character here.
-- =============================================================================

MyDSL              = MyDSL              or {}
MyDSL.CreatureLore = MyDSL.CreatureLore or {}
local CL = MyDSL.CreatureLore

CL.db = CL.db or {}

local function dbFile()
  return getMudletHomeDir() .. "/MyDSL/creaturelore_db.lua"
end

-- REAL BUG, found live 2026-07-11: Mudlet's real table.load(file, target)
-- does not return anything -- it unpickles INTO an explicit second-
-- argument table (confirmed in Mudlet's own bundled source). This used
-- to call table.load(dbFile()) with no second argument, so `data` was
-- always nil and the persistent DB never actually survived a restart,
-- despite the file itself always being written correctly (same bug
-- found across ~10 call sites project-wide the same day -- see
-- MyDSL_DataLayer.lua's MyDSL.load() for the full writeup).
function CL.load()
  local f = io.open(dbFile(), "r")
  if not f then
    debugc("[MyDSL] CreatureLore: no saved DB file yet at " .. dbFile())
    return
  end
  f:close()
  local data = {}
  local ok = pcall(table.load, dbFile(), data)
  if ok and next(data) then
    CL.db = data
  else
    debugc("[MyDSL] CreatureLore: DB file exists but failed to load")
  end
end

function CL.save()
  pcall(table.save, dbFile(), CL.db)
end

-- get(key) -- key is the same normalized name every lookup already
-- computes (name:lower(), leading "a/an/the" stripped).
function CL.get(key)
  if not key or key == "" then return nil end
  return CL.db[key]
end

-- Fields a real "creaturelore <name>" capture can populate (see
-- MyDSL_DataLayer.lua's parseCreatureLoreLine()). Deliberately excludes
-- killCount/avgXP/lastXP/roomsFound/drops -- confirmed via codebase grep
-- (docs/TODO.md, TargetView redesign entry) that nothing anywhere tracks
-- those; they stay untouched by merge() below if some future feature ever
-- adds them; this module doesn't invent placeholder data for them.
local FIELDS = {
  "name", "race", "alignmentText", "sex", "gold", "silver", "hp", "magic",
  "damage", "damageType", "immunities", "resists", "vulns", "affects",
  -- Added 2026-07-11 per Steven ("offensive tactics and level of the
  -- mobs") -- trainingCycle is DSL's own "cycle of training" number,
  -- what Steven's asking for as "level."
  "tactics", "trainingCycle",
}

-- merge(rec) -- upsert by rec.key. Only overwrites fields present (non-nil)
-- in the new capture, so a record already in the DB keeps its existing
-- values for anything the new capture didn't happen to include (DSL's
-- creaturelore output is normally the same full block every time, but this
-- is defensive against a partial/interrupted capture overwriting good data
-- with blanks).
function CL.merge(rec)
  if not rec or not rec.key or rec.key == "" then return end
  local existing = CL.db[rec.key] or {}
  for _, f in ipairs(FIELDS) do
    if rec[f] ~= nil then existing[f] = rec[f] end
  end
  existing.key      = rec.key
  existing.lastLore = os.time()
  CL.db[rec.key] = existing
  CL.save()
end

CL.load()

-- echo(), not just debugc() -- 2026-07-11, per the same live-persistence
-- investigation: debugc() writes to Mudlet's separate Errors/debug
-- console, which isn't necessarily open/visible -- echo() always shows
-- in the main console, so this boot-time count is actually visible on
-- every real login/reload, not just when the debug console happens to be
-- open. This is the concrete, checkable answer to "is creaturelore
-- actually persisting" -- if this count is 0 right after a restart when
-- it shouldn't be, that's real evidence of a load-side bug; if it's
-- correct, the bug is elsewhere (a later render() not picking it up).
local function creatureCount()
  local n = 0
  for _ in pairs(CL.db) do n = n + 1 end
  return n
end
echo("[MyDSL] CreatureLore DB loaded (" .. tostring(creatureCount()) .. " creatures known).\n")
debugc("[MyDSL] CreatureLore DB loaded (" .. tostring(creatureCount()) .. " creatures known).")
