-- =============================================================================
-- MyDSL_DataLayer_CreatureLore.lua  --  Layer 1: Data Collection (CreatureLore capture)
-- =============================================================================
-- Split out of MyDSL_DataLayer.lua 2026-08-25, per the split-by-domain
-- refactor flagged in docs/TODO.md (that file had grown to 4,745 lines,
-- ~20% of the whole codebase, two independent reviews flagged the
-- trajectory even though nothing was broken). This is the FIRST slice of
-- that split, deliberately the smallest and most self-contained domain
-- (confirmed via grep before moving anything: every function/local here
-- is used ONLY within this domain, plus one MyDSL.* table reference from
-- the trigger-registration block below) -- proving out the mechanism
-- (new file, dofile wiring, test updates) on low-risk code before the
-- bigger domains (Combat, Scan/Look, Items).
--
-- Same contract as before the split: zero display logic, never sends
-- commands to the game. Depends on MyDSL_DataLayer.lua already being
-- loaded (MyDSL.State/MyDSL._triggers/MyDSL.emit come from there) --
-- dofile() order matters, this file must load AFTER it.
--
-- Captures DSL's `creaturelore <target>` command output (confirmed real,
-- distinct from the general item-only `lore` skill -- see docs/TODO.md's
-- DECISIONS RECORDED). MyDSL.State.creaturelore's default shape is still
-- declared in MyDSL_DataLayer.lua's own STATE TABLE section alongside
-- every other domain's defaults -- not moved here, since that section is
-- a single flat reference for all domains, not yet itself split.
-- =============================================================================

MyDSL = MyDSL or {}

local function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end

-- beginCreatureLore() fires on "^Creature:%s" and parses name+race from
-- the first line. A catch-all feeds body lines to parseCreatureLoreLine().
-- endCreatureLore() fires on blank line, commits to State, and optionally
-- merges into MyDSL_CreatureLore.lua DB if that module is loaded.

function MyDSL.beginCreatureLore(line)
  local name, race = line:match("^Creature:%s*(.-)%s+Race:%s*(.+)$")
  name = trim(name or "")
  race = trim(race or "")
  local key = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  MyDSL.State.creaturelore = {
    name         = name,
    race         = race,
    key          = key,
    lines        = { line },
    last_updated = 0,
  }
  -- Kill leftover catch-all if a previous lore block never ended.
  if MyDSL._triggers.loreBody then
    pcall(killTrigger, MyDSL._triggers.loreBody)
    MyDSL._triggers.loreBody = nil
  end
  MyDSL._triggers.loreBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.creaturelore) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    if t == "" then MyDSL.endCreatureLore(); return end
    if MyDSL.parseCreatureLoreLine then MyDSL.parseCreatureLoreLine(ln) end
  end)
end

-- splitWords(s) -- "mental disease" -> {"mental","disease"}. Used for the
-- Immunities/Resistances/Vulnerabilities/Affects lines below, which are
-- real DSL space-separated flag lists (confirmed via log-corpus grep:
-- "Immunities: summon charm magic weapon blunt poison negative holy
-- mental disease", no commas) -- stored as tables to match
-- MyDSL_CreatureReference.lua's existing listLine() display helper, which
-- already expects a table (`#tbl > 0`), not a bare string.
local function splitWords(s)
  local out = {}
  for w in tostring(s or ""):gmatch("%S+") do table.insert(out, w) end
  return out
end

function MyDSL.parseCreatureLoreLine(line)
  local r = MyDSL.State.creaturelore
  if not r then return end
  table.insert(r.lines, line)
  -- Alignment: real phrasing varies more than the raw capture used to
  -- keep -- confirmed via log-corpus grep across many creatures: "a good
  -- soul.", "a more neutral soul." (filler "more"), "a evil and corrupt
  -- soul." (extra qualifier after "evil"). Narrowed 2026-07-11 per Steven
  -- ("only need to capture the good evil neutral for align") -- search
  -- the captured phrase for whichever of the 3 real keywords is present,
  -- instead of storing the whole variable phrase verbatim.
  local a = line:match("^.- appears to be (.+) soul%.")
  if a then
    r.alignmentText = a:match("(good)") or a:match("(evil)") or a:match("(neutral)") or trim(a)
  end
  -- Wealth: "Their wealth appears to be 5 gold and 10 silver."
  local g, s = line:match("Their wealth appears to be%s+(%d+)%s+gold and%s+(%d+)%s+silver")
  if g then r.gold = tonumber(g); r.silver = tonumber(s) end
  -- Sex: "They appear to be Undetermined sex." — skip only when THIS SAME
  -- line also matched the alignment pattern (a creature whose alignment
  -- text happens to be phrased "They appear to be X soul." — the sex
  -- pattern's prefix is a strict subset of that shape, so it would
  -- otherwise capture "X soul" as a bogus sex value from the same line).
  -- REAL BUG, found 2026-08-25 while writing this module's first real
  -- test (it had none before): the guard used to check `not
  -- r.alignmentText` -- whether alignment had EVER been captured from
  -- ANY earlier line for this creature -- instead of `not a`, whether
  -- THIS line matched. That meant a real creature with alignment
  -- correctly captured from one line ("<name> appears to be a good
  -- soul.") then a genuinely separate, unambiguous sex line ("They
  -- appear to be male.") had its sex silently dropped every time,
  -- confirmed against a real corpus fixture
  -- (log/2026-07-11#12-15-16.html) where this happens on every visit.
  local x = line:match("^They appear to be%s+(.+)%.")
  if x and not a then r.sex = trim(x) end
  -- HP: "The base health of this creature is 1000."
  local h = line:match("^The base health of this creature is%s+(%d+)%.")
  if h then r.hp = tonumber(h) end

  -- Added 2026-07-11, per Steven's TargetView redesign ("should show the
  -- stats we collect with creaturelore") -- confirmed real via log-corpus
  -- grep + DSL_Helpfiles/creaturelore.txt ("physical and magical health,
  -- level of training, weapon damage type, immunities and resistances,
  -- vulnerabilities and magical affects"), none of these 6 fields were
  -- being captured at all before, only race/align/wealth/sex/hp.

  -- Magic: "The base magically ability of this creature is 1336."
  local mg = line:match("^The base magically ability of this creature is%s+(%d+)%.")
  if mg then r.magic = tonumber(mg) end

  -- Damage: "This creature does 6d7 damage in a slash manner."
  local dice, dtype = line:match("^This creature does%s+(.-)%s+damage in a?n?%s*(.-)%s+manner%.")
  if dice then r.damage = dice; r.damageType = trim(dtype) end

  -- Characteristics list, each its own line: "Immunities: charm",
  -- "Resistances: blunt cold". Vulnerabilities line format is unconfirmed
  -- in the log corpus (zero real examples found) but documented in
  -- DSL_Helpfiles/creaturelore.txt as a real category -- parsed the same
  -- way defensively; harmless if it never matches.
  local imm = line:match("^Immunities:%s*(.+)$")
  if imm then r.immunities = splitWords(imm) end
  local res = line:match("^Resistances:%s*(.+)$")
  if res then r.resists = splitWords(res) end
  local vuln = line:match("^Vulnerabilities:%s*(.+)$")
  if vuln then r.vulns = splitWords(vuln) end

  -- Affects: "This creature is affected by charm" -- confirmed real via
  -- log-corpus grep, a sentence, not a "Affects:" label line.
  local aff = line:match("^This creature is affected by%s+(.+)$")
  if aff then r.affects = splitWords(aff) end

  -- Offensive Tactics + training cycle ("level") -- added 2026-07-11, per
  -- Steven ("we arent capturing the offensive tactics and level of the
  -- mobs (level is IC cycles of training)"). Both confirmed real via
  -- log-corpus grep across many creatures:
  --   "Offensive Tactics:bash disarm dodge parry trip assist_vnum"
  --   (NO space after the colon, unlike Immunities:/Resistances:/etc.)
  --   "This creature is upon the cycle of training '50'"
  --   (single-quoted number, no trailing period).
  local tactics = line:match("^Offensive Tactics:(.+)$")
  if tactics then r.tactics = splitWords(tactics) end
  local cycle = line:match("^This creature is upon the cycle of training '(%d+)'")
  if cycle then r.trainingCycle = tonumber(cycle) end
end

function MyDSL.endCreatureLore()
  if MyDSL._triggers.loreBody then
    pcall(killTrigger, MyDSL._triggers.loreBody)
    MyDSL._triggers.loreBody = nil
  end
  MyDSL.State.creaturelore.last_updated = os.time()
  -- Merge into the persistent DB (MyDSL_CreatureLore.lua) if it's loaded.
  --
  -- REAL BUG, found live 2026-07-11 (Steven: "doesnt look like its auto
  -- updating stats"): this used to ALSO write to
  -- MyDSL.State.creatureLoreCache[key] here -- a session-only cache that
  -- got superseded by the real persistent DB earlier the same day. Its
  -- initializer (MyDSL_DataLayer.lua's old
  -- "MyDSL.State.creatureLoreCache = ... or {}" line) was removed as part
  -- of that same edit, but THIS write site was missed -- so every real
  -- "creaturelore" capture threw "attempt to index a nil value" right
  -- here, which aborted endCreatureLore() before it ever reached
  -- CreatureLore.merge() or MyDSL.emit() below. Confirmed live: no
  -- MyDSL/creaturelore_db.lua file existed on disk at all after a real
  -- capture, and the Focus window never got the "creaturelore.updated"
  -- event to redraw from. Fixed by deleting the dead write entirely --
  -- nothing reads MyDSL.State.creatureLoreCache anymore.
  if MyDSL.CreatureLore and MyDSL.CreatureLore.merge then
    MyDSL.CreatureLore.merge(MyDSL.State.creaturelore)
  end
  MyDSL.emit("creaturelore")
end

------------------------------------------------------------------------
-- Trigger registration -- moved here with its functions rather than left
-- in MyDSL_DataLayer.lua's own trigger-registration section, so this file
-- is a complete, self-contained module (same precedent as every Layer-3
-- view file installing its own triggers/aliases internally).
------------------------------------------------------------------------
-- Fires on "^Creature: <name>  Race: <race>" — the first line of any
-- creaturelore block. Body lines handled by catch-all installed inside
-- beginCreatureLore().

if MyDSL._triggers.loreStart then
  pcall(killTrigger, MyDSL._triggers.loreStart)
  MyDSL._triggers.loreStart = nil
end
MyDSL._triggers.loreStart = tempRegexTrigger(
  "^Creature:\\s",
  function()
    if MyDSL and MyDSL.beginCreatureLore then
      MyDSL.beginCreatureLore(getCurrentLine())
    end
  end
)
