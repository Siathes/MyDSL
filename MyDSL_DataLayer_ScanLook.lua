-- =============================================================================
-- MyDSL_DataLayer_ScanLook.lua  --  Layer 1: Data Collection (Scan/Look/PlayersNear capture)
-- =============================================================================
-- Split out of MyDSL_DataLayer.lua 2026-08-25, third slice of the split-
-- by-domain refactor (see docs/TODO.md for the full plan and prior
-- slices' writeup). Covers room-content perception: scan, look/room-
-- content listing, ground-item sighting, and the "Players near you:"
-- capture.
--
-- Real cross-domain dependency found and resolved BEFORE this slice
-- (not discovered by trial and error): normalizeForMatch()/
-- bestFuzzyMatch() are needed by both this domain (resolveMobName())
-- and the not-yet-split ItemLore section's resolveGroundItem() -- so
-- those two were promoted to real MyDSL.* table functions in
-- MyDSL_DataLayer.lua's core SECTION 2 first, and this file calls them
-- that way (MyDSL.normalizeForMatch()/MyDSL.bestFuzzyMatch()), not as
-- bare locals.
--
-- Same contract as before the split: zero display logic, never sends
-- commands to the game. Depends on MyDSL_DataLayer.lua already being
-- loaded (MyDSL.State/MyDSL._triggers/MyDSL.Route/MyDSL.emit/
-- MyDSL.normalizeForMatch/MyDSL.bestFuzzyMatch all come from there) --
-- dofile() order matters, this file must load AFTER it.
--
-- Reverse dependency: MyDSL.buildItemStatsSuffix() is DEFINED in this
-- file but CALLED from MyDSL_DataLayer.lua's not-yet-split Equipment/
-- ItemLore section (the "Others equip" hover-hint lines). Harmless
-- either dofile() order since both are load-time function definitions
-- and the call only happens later at trigger-fire time, but flagging it
-- here so it isn't mistaken for a missing/dead function during the next
-- slice (ItemLore/Equipment/Inventory).
-- =============================================================================

MyDSL = MyDSL or {}

local function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end

------------------------------------------------------------------------
-- 9o  SCAN
------------------------------------------------------------------------
-- Trigger wiring is in Section 10 below.
-- beginScan() is called by permanent triggers on "^Looking around you see:$"
-- and "^You peer intently (%a+)%.$". It resets State.scan and installs a
-- catch-all that feeds body lines to parseScanLine(). endScan() is called
-- by the catch-all on blank line, "Players near you:", or group header.

-- Article-detection helper — mobs always start with a/an/the, players don't.
local function isMobName(name)
  return name:match("^[Aa]n? ") ~= nil or name:match("^[Tt]he ") ~= nil
end

-- normalizeForMatch()/bestFuzzyMatch() promoted to real MyDSL.* table
-- functions in SECTION 2 above (2026-08-25, split-by-domain refactor) --
-- shared by resolveMobName() (below) and MyDSL.resolveGroundItem() (see
-- the ITEM LORE section further down), so it lives in core rather than
-- being duplicated or forcing both domains into one file.

-- resolveMobName(key, capturedName) -- added 2026-07-12, per Steven ("mob
-- names are the most important... if we need to use an identifier alias,
-- where we look then creaturelore, that could be an option"). Confirmed
-- via corpus research that a room's `look` text usually already matches
-- `scan`'s own noun phrase word-for-word, but real divergence does happen
-- (generic/truncated look descriptions, e.g. "A gnome is here using
-- levers..." vs. a specific creaturelore-known "gnome machinist") --
-- `MyDSL_CreatureLore.lua`'s DB is already keyed and populated exactly
-- this way from real `creaturelore` captures, so a "known" hit there is
-- a definitively-correct name, better than whatever got truncated out of
-- a room description. Falls back to the captured name whenever there's no
-- "known" (real lore data) match -- never guesses between multiple
-- possible creaturelore entries sharing a generic prefix (e.g. several
-- different "gnome ..." types) since that's not actually resolvable from
-- a generic captured name alone -- per Steven ("if we are unable to guess
-- then a generic is better than none").
--
-- Broadened 2026-07-16: the exact-key check above already covered the
-- case where `look`'s text happens to normalize to the identical key
-- CreatureLore was populated under. It never covered Steven's own example
-- ("a gnome" vs. a CreatureLore entry keyed "gnome machinist") since those
-- are two different keys -- exact match can't find that, only a fuzzy one
-- can. Tries the current room's own `scan` capture first (scan.byName --
-- per Steven, "using the propper scan name" -- small, same-room-visit,
-- least likely to collide with an unrelated same-prefix creature type),
-- then falls back to the full CreatureLore DB only if nothing in-room
-- matched. Still refuses to guess on a tie (bestFuzzyMatch's own rule) --
-- a wrong auto-resolved name is worse than the untouched generic capture.
local function resolveMobName(key, capturedName)
  local cl = MyDSL.CreatureLore
  if cl and cl.knownState and cl.knownState(key) == "known" then
    local rec = cl.get(key)
    if rec and rec.name then return rec.name end
  end

  local scan = MyDSL.State and MyDSL.State.scan
  if scan and scan.byName then
    local candidates = {}
    for k, entry in pairs(scan.byName) do
      if k ~= key and entry.is_mob then
        candidates[#candidates + 1] = { name = entry.name, key = k }
      end
    end
    local hit = MyDSL.bestFuzzyMatch(capturedName, candidates)
    if hit then return hit.name end
  end

  -- Fixed 2026-07-17, real bug found live: this loop used to accept ANY
  -- cl.db record as a fuzzy-match candidate, including bare markSeen()
  -- stubs (knownState "seen", not "known") -- so a `look` capture minutes
  -- (or moments) earlier in the SAME room could get fuzzy-matched onto a
  -- `scan` capture of the same mob and overwrite scan's own perfectly
  -- good name with look's, purely because look happened to run first and
  -- its stub landed in the shared db. Confirmed live via screenshot:
  -- RightHere showed "A gray wolf cub wanders"/"A small green lizard
  -- wanders" (look's own captured text, verb included per the
  -- parseLookHereLine fallback-pattern fix just below) even after `scan`
  -- ran and correctly parsed "a gray wolf cub, right here."/"a lizard,
  -- right here." -- because cl.db's stub for the look-derived key
  -- ("gray wolf cub wanders") fuzzy-substring-matched scan's own shorter
  -- capture and won. Restricting candidates to real "known" (hasLore)
  -- records only -- matching this function's own step-1 exact-match rule
  -- and its original design intent ("a 'known' hit there is a
  -- definitively-correct name") -- means a bare sighting can never
  -- clobber another capture's name via this path again.
  if cl and cl.db and cl.hasLore then
    local candidates = {}
    for k, rec in pairs(cl.db) do
      if k ~= key and rec and rec.name and cl.hasLore(rec) then
        candidates[#candidates + 1] = { name = rec.name, key = k }
      end
    end
    local hit = MyDSL.bestFuzzyMatch(capturedName, candidates)
    if hit then return hit.name end
  end

  return capturedName
end

function MyDSL.beginScan(mode, direction)
  -- Fresh table replaces any stale scan state.
  MyDSL.State.scan = {
    mode         = mode,
    direction    = direction,
    rows         = {},
    rightHere    = {},
    byName       = {},
    groundItems  = {},
    last_updated = 0,
  }
  -- Clear Scan window for the incoming lines.
  if MyDSL.ScanView and MyDSL.ScanView.ui and MyDSL.ScanView.ui.scanConsole then
    MyDSL.ScanView.ui.scanConsole:clear()
  end
  -- Kill any leftover catch-all from a previous scan that never ended.
  if MyDSL._triggers.scanBody then
    pcall(killTrigger, MyDSL._triggers.scanBody)
    MyDSL._triggers.scanBody = nil
  end
  MyDSL._triggers.scanBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.scan) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    if t == "" then MyDSL.endScan(); return end
    if t == "Players near you:" then MyDSL.endScan(); return end
    if t:match("^.+%'s group:$") then MyDSL.endScan(); return end
    if t == "Looking around you see:" then return end  -- skip header if re-seen
    local newRow = nil
    if MyDSL.parseScanLine then
      local before = #MyDSL.State.scan.rows
      MyDSL.parseScanLine(ln)
      if #MyDSL.State.scan.rows > before then
        newRow = MyDSL.State.scan.rows[#MyDSL.State.scan.rows]
      end
    end
    selectCurrentLine()
    copy()
    if MyDSL.ScanView and MyDSL.ScanView.ui and MyDSL.ScanView.ui.scanConsole then
      MyDSL.ScanView.ui.scanConsole:appendBuffer()
      MyDSL.applyScanBadgeHover(newRow)
    end
  end)
end

-- applyScanBadgeHover(row) -- added 2026-07-16, per Steven ("scan window
-- should show seen/known flags"). RightHere already shows a visible
-- [Known]/[Seen]/[Unknown] badge (SV.renderRightHere(), MyDSL_ScanView.lua)
-- because that panel is decho-built from scratch every time. The Scan
-- body itself is raw copied game text (selectCurrentLine()+copy()+
-- appendBuffer() above) -- "move text, don't invent it" -- so a visible
-- inline badge would mean editing the pasted line after the fact, the
-- same mechanism already tried once for a left-margin space and reverted
-- ("no visible changes... not a big enough issue to chase"). Uses the
-- safer, already-proven hover technique instead (same as AffectsView's
-- applyLinks() / the equipment-line hover in parseEquipLine()):
-- selectString()+setLink() on the just-appended line, tooltip only, never
-- touches the visible text. Selects on the pre-resolution rawName (not
-- the possibly-substituted display name) so it still matches the literal
-- on-screen text even for a "Known" mob whose resolved name differs from
-- what the game actually printed.
function MyDSL.applyScanBadgeHover(row)
  if not row or not row.is_mob then return end
  if not (MyDSL.CreatureLore and MyDSL.CreatureLore.knownState) then return end
  if not (selectString and setLink) then return end
  local mc = MyDSL.ScanView and MyDSL.ScanView.ui and MyDSL.ScanView.ui.scanConsole
  if not mc then return end
  -- Known fixed name (MyDSL_ScanView.lua's SCAN_MC constant), not read off
  -- the Geyser object -- matches how the rest of this codebase treats
  -- console window names (e.g. AffectsView's A.config.windowName) as
  -- known string literals rather than introspected object fields.
  local windowName = "MyDSL_Scan_MC"
  local state = MyDSL.CreatureLore.knownState(row.key)
  local hint
  if state == "known" then hint = "Known -- lore data captured"
  elseif state == "seen" then hint = "Seen -- not yet lore'd"
  else hint = "Unknown -- never seen before this scan" end
  local target = row.rawName or row.name
  if not target or target == "" then return end
  local okSel, selected = pcall(selectString, windowName, target, 1)
  if okSel and selected then
    pcall(setLink, windowName, "", hint)
  end
end

function MyDSL.parseScanLine(line)
  local scan = MyDSL.State.scan
  if not scan then return end
  local name, where
  name = line:match("^(.+),%s+right here%.?$")
  if name then where = "right here" end
  if not name then
    name, where = line:match("^(.+),%s+(nearby to .+)%.?$")
  end
  if not name then
    name, where = line:match("^(.+),%s+(not far .+)%.?$")
  end
  if not name then return end
  name         = trim(name)
  local key    = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  local is_mob = isMobName(name)
  -- Mark seen + resolve to CreatureLore's canonical name if known -- see
  -- resolveMobName()'s comment above for the full reasoning. Mobs only
  -- (not players) -- CreatureLore is a creature DB, "lore"-ing a player
  -- isn't a real thing.
  if is_mob and MyDSL.CreatureLore and MyDSL.CreatureLore.markSeen then
    MyDSL.CreatureLore.markSeen(key, name)
  end
  local dispName = is_mob and resolveMobName(key, name) or name
  local row = {
    raw     = line,
    name    = dispName,
    display = dispName,
    rawName = name,  -- pre-resolution captured name -- see applyScanBadgeHover()
    key     = key,
    where   = where,
    is_mob  = is_mob,
    count   = 1,
  }
  table.insert(scan.rows, row)
  if scan.byName[key] then
    scan.byName[key].count = scan.byName[key].count + 1
  else
    scan.byName[key] = {
      raw     = line,
      name    = dispName,
      display = dispName,
      key     = key,
      where   = where,
      is_mob  = is_mob,
      count   = 1,
    }
  end
  if where == "right here" then
    if scan.rightHere[key] then
      scan.rightHere[key].count = scan.rightHere[key].count + 1
    else
      scan.rightHere[key] = {
        raw     = line,
        name    = dispName,
        display = dispName,
        key     = key,
        where   = where,
        is_mob  = is_mob,
        count   = 1,
      }
    end
  end
  -- ScanView body-line gagging (header lines gagged by ScanView's own triggers).
  if MyDSL.ScanView and MyDSL.ScanView.config and MyDSL.ScanView.config.gagScan then
    deleteLine()
  end
end

function MyDSL.endScan()
  if MyDSL._triggers.scanBody then
    pcall(killTrigger, MyDSL._triggers.scanBody)
    MyDSL._triggers.scanBody = nil
  end
  MyDSL.State.scan.last_updated = os.time()
  MyDSL.emit("scan")
end


------------------------------------------------------------------------
-- 9o.1  LOOK -- refresh RightHere from a full room look, not just scan
------------------------------------------------------------------------
-- Fixed 2026-07-07, per Steven: "RightHere should update on look too, not
-- just scan." `look`'s room-content lines use a different, plainer format
-- than scan's ("<Name> is here[, <status>].", optionally prefixed with a
-- "(<Flag>) " tag) -- confirmed real text from log/2026-07-07#18-29-43.html:
-- "(Golden Aura) A gnome factory worker is here.", "(Charmed) a wild bear
-- is here, fighting a gnome machinist.", "A gnome is here using levers and
-- pullies to yank up a large parts of the" (no comma at all before the
-- trailing description). Anchored on the room's own "[Exits: ...]" line
-- (always the line immediately after the room description, immediately
-- before its content listing) rather than a fixed header phrase, since
-- `look` has no distinct start-of-listing banner the way scan's "Looking
-- around you see:" does -- this also means RightHere now refreshes on
-- every room entry (movement reprints the room), not just an explicit
-- `look`, which is a strict improvement, not scope creep (still 100%
-- observational, no command ever sent). Long status phrases can wrap onto
-- a following physical line (confirmed: "...keeping the gears" /
-- "lubricated." split across two lines in the same real example) --
-- since only presence (not the wrapped remainder) matters for RightHere,
-- continuation lines are recognized by starting with a lowercase letter
-- (DSL always capitalizes the start of a new game message) and are
-- skipped without ending capture. Any other line ends capture, since
-- look's listing has no blank-line terminator the way scan's does --
-- real-time events (arrivals, tells, etc.) can start appearing
-- immediately after the last content line with no gap.

-- isLookFixtureLine() -- fixed 2026-07-08. Real bug found live: a room
-- with an item on the ground ("A grand arcanium hoopak lies here.")
-- ended capture immediately after that ONE line, silently dropping every
-- mob listed after it -- "lies here"/"is lying here" don't match
-- parseLookHereLine's mob pattern, and the line starts with a capital
-- letter so the wrapped-continuation check didn't save it either,
-- leaving only the "unrelated event, end capture" fallback. Confirmed
-- these phrasings are common, not rare -- dozens of real examples across
-- items ("X lies here[.| on the ground.]") and corpses ("The corpse of X
-- is lying here.") in the DSL2-era corpus -- checked specifically for
-- any mob using these two verbs and found none, unlike "sits here"
-- (see parseLookHereLine, handled there instead since it's genuinely
-- ambiguous). These lines are real, static room content (like mob lines)
-- -- just not something RightHere tracks -- so they should be skipped
-- without ending capture, same treatment as a wrapped continuation line.
local function isLookFixtureLine(line)
  return line:match("lies? here%f[%A]") ~= nil
      or line:match("is lying here%f[%A]") ~= nil
      or line:match("are lying here%f[%A]") ~= nil
      or line:match("has been left here%f[%A]") ~= nil
      or line:match("^You see .- here%f[%A]") ~= nil
      -- Found live 2026-07-08: "(Glowing) (Humming) A Parrying dagger
      -- floats above the ground." has no "here"/"in the room" anchor at
      -- all, so it fell through every check (including the broad mob
      -- fallback) straight to "unrelated event, end capture" -- confirmed
      -- via screenshot to have silently dropped 4 real gnomes/excavators
      -- listed right after it in the same room.
      or line:match("floats above the ground%f[%A]") ~= nil
      -- Three more added 2026-07-21, found via a full-codebase audit
      -- prompted by the "Several small desks" fix earlier the same day
      -- (Steven: "we seem to be regressing to errors we fixed... would
      -- it improve if we used a newer ai agent?" -- answer was no, the
      -- gap is systematic re-checking, not model capability; this audit
      -- is that re-check). Same bug class as every fix above and
      -- "Several " in isUnparsedPresenceLine() -- a scenery/landmark
      -- sentence with no "here"/"in the room" anchor and no recognized
      -- leading word, confirmed via direct corpus grep to silently drop
      -- real mobs listed right after it: "Sturdy barstools line the
      -- outside edge of the lengthy bar." (drops a barmaid + a mount,
      -- log/2026-06-30#21-23-23.txt:281), "(Glowing) High above the
      -- cityscape, a jagged rip mars the sky and crackles with charged
      -- energy." (drops an Elite Royal Guard + 2 good samaritans, same
      -- file:189), "Dark marble benches are set facing the statue of the
      -- Sons of Liberty." (ends capture immediately after [Exits:],
      -- log/2026-06-30#20-29-23.txt:9666). Unlike the leading-word
      -- additions, these start with unbounded adjectives ("Sturdy",
      -- "High", "Dark") that can't be generalized into a new allowlist
      -- word the way "Several"/"This" could -- matched as narrow literal
      -- substrings instead, same convention "floats above the ground"
      -- above already established for exactly this situation. NOTE: this
      -- growing-allowlist-of-literal-substrings approach is reaching its
      -- practical limit (6th+ instance of the same bug class) -- flagged
      -- as an open architectural question in docs/TODO.md rather than
      -- unilaterally redesigning beginLook()'s catch-all, since a broader
      -- "default to keep capturing" rule was checked and found to have
      -- real counterexamples in the corpus too (indented lines that ARE
      -- real mob-shaped presence lines, e.g. "A very large bind stone is
      -- here.") -- not a safe drop-in replacement without more design work.
      or line:match("barstools line the outside edge") ~= nil
      or line:match("a jagged rip mars the sky") ~= nil
      or line:match("marble benches are set facing") ~= nil
end

-- extractGroundItemName(line) / MyDSL.captureGroundItem(line) -- added
-- 2026-07-16 for ground-vs-inventory item linking (Steven: "the item on
-- the ground needs a map to the inventory/equipment"). Only ever called
-- after isLookFixtureLine() has already confirmed one of its suffixes is
-- present -- strips the same leading parenthetical tags and trailing
-- fixture-sentence phrasing to recover the item's core name (e.g. "A
-- grand arcanium hoopak lies here." -> "A grand arcanium hoopak") for
-- storage. Before this, isLookFixtureLine-matched lines were only ever
-- skipped, never stored anywhere -- there was no ground-item data at all
-- to match against.
local function extractGroundItemName(line)
  local rest = trim(line)
  while true do
    local stripped = rest:match("^%([^()]+%)%s*(.+)$")
    if not stripped then break end
    rest = stripped
  end
  local seen = rest:match("^You see%s+(.-)%s+here")
  if seen then return trim(seen) end
  rest = rest:gsub("%s+lies? here.*$", "")
  rest = rest:gsub("%s+is lying here.*$", "")
  rest = rest:gsub("%s+are lying here.*$", "")
  rest = rest:gsub("%s+has been left here.*$", "")
  rest = rest:gsub("%s+floats above the ground.*$", "")
  return trim(rest)
end

function MyDSL.captureGroundItem(line)
  local scan = MyDSL.State and MyDSL.State.scan
  if not scan then return end
  scan.groundItems = scan.groundItems or {}
  local name = extractGroundItemName(line)
  if name == "" then return end
  local key = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  if scan.groundItems[key] then
    scan.groundItems[key].count = scan.groundItems[key].count + 1
  else
    scan.groundItems[key] = { raw = line, name = name, key = key, count = 1 }
  end
  MyDSL.applyGroundItemHover(name, key)
end

-- buildItemStatsSuffix(rec) -- extracted 2026-07-18. Every item-hover
-- call site (ground item, equipment, inventory, container-holds) had its
-- own copy-pasted version of this exact stat-formatting logic -- found
-- while investigating Steven's "some have click for item reference, and
-- some have stats, how do we populate the hover tip with stats": all four
-- copies only showed damage info when rec.damageDice was present (real
-- in-game `identify` data only). Steven's own ItemLore DB (checked
-- directly) confirms the bulk scrape import already ran successfully
-- (6,085 items with itemType, 1,562 with armorClass) -- but the scrape's
-- weapon records only ever have rec.damageAvg (a precomputed average,
-- e.g. "damageAvg=[[3.5]]"), never rec.damageDice (exact dice notation
-- like "3d4" only exists in real `identify` captures) -- so ~1,474
-- scrape-imported weapons had real damage data sitting in the record that
-- every hover site was silently throwing away, since nothing gated on
-- damageAvg alone. Now shows whichever is available, preferring the
-- fuller identify-derived damageDice when both exist. One shared
-- function instead of four copies specifically so this kind of fix (or
-- the next one) doesn't need to land in four places and risk drifting
-- apart again.
function MyDSL.buildItemStatsSuffix(rec)
  if not rec then return "" end
  local out = ""
  if rec.itemType then out = out .. " -- " .. rec.itemType end
  if rec.damageDice then
    out = out .. " -- " .. rec.damageDice .. " (avg " .. tostring(rec.damageAvg) .. ")"
  elseif rec.damageAvg then
    out = out .. " -- avg dmg " .. tostring(rec.damageAvg)
  end
  if rec.armorClass then
    local ac = rec.armorClass
    out = out .. string.format(" -- AC %s/%s/%s/%s",
      tostring(ac.pierce), tostring(ac.bash), tostring(ac.slash), tostring(ac.magic))
  end
  -- spellCharges/spellList -- added 2026-07-18, per Steven ("the platinum
  -- wand is missing the actual spell it uses magic missle lvl(30)").
  -- charges/level are shown only when known -- a scrape-imported record
  -- only ever has the bare spell name (see IL.importScraped()'s spellInfo
  -- mapping), while a real in-game `identify` fills in the exact charges
  -- and level too; nil-safe either way so this doesn't print "nil".
  if rec.spellCharges then
    local sc = rec.spellCharges
    out = out .. " -- '" .. tostring(sc.spell) .. "'"
    if sc.level then out = out .. " (level " .. tostring(sc.level) .. ")" end
    if sc.charges then out = out .. " [" .. tostring(sc.charges) .. " charges]" end
  end
  if rec.spellList and rec.spellList.spells then
    out = out .. " -- level " .. tostring(rec.spellList.level) .. " spells: "
      .. table.concat(rec.spellList.spells, ", ")
  end
  return out
end

-- applyGroundItemHover(name, key) -- added 2026-07-16, wires
-- MyDSL.resolveGroundItem() (built the prior pass, never connected to any
-- UI) into an actual hover, same "move text, don't invent it" technique
-- as the equipment-line hover in parseEquipLine(): selectString()+
-- setLink() on the raw line already sitting in the main console, never
-- touching its visible text. Only attaches a hover when a resolution
-- actually exists (manual override, ItemLore DB hit, or an unambiguous
-- fuzzy match) -- the real fraction of ground items with no resolution
-- at all (per Steven's own "best effort" framing) get no hover, not a
-- fabricated one.
function MyDSL.applyGroundItemHover(name, key)
  if not (selectString and setLink) then return end
  local resolved = MyDSL.resolveGroundItem and MyDSL.resolveGroundItem(key)
  if not resolved then return end
  local rec = MyDSL.ItemLore and MyDSL.ItemLore.get and MyDSL.ItemLore.get(resolved.key or key)
  local hint = "Resolved to \"" .. tostring(resolved.name) .. "\" (" .. tostring(resolved.source) .. ")"
    .. MyDSL.buildItemStatsSuffix(rec) .. " -- Click for Item Reference"
  local cmd = string.format(
    'if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.render("%s"); MyDSL.ItemReference.show() end',
    tostring(resolved.name):gsub('"', '\\"'))
  local okSel, selected = pcall(selectString, "main", name, 1)
  if okSel and selected then
    pcall(setLink, "main", cmd, hint)
  end
end

-- isUnparsedPresenceLine() -- broadened 2026-07-09, third confirmed live
-- instance of the same underlying problem. Originally added 2026-07-08 as
-- isCharmedStatusLine() for charmed/summoned pets' varying idle-action
-- verbs ("sloshes around here.", "follows their client." with no "here"
-- anchor at all -- see git history for the full original writeup; this is
-- what Steven meant by "the space after certain followers"). That version
-- only checked for a literal "(Charmed)" tag. Confirmed live 2026-07-09
-- via screenshot: "A dark elven commoner stands around looking bored."
-- and "The dark elven scout slips in and out from the shadows unheard."
-- -- ordinary room NPCs, no "(Charmed)" tag at all, no "here"/"in the
-- room" anchor either -- caused RightHere to come back completely empty
-- for that room. Enumerating every possible DSL verb phrase has now
-- failed three times (round 2's fallback, the Charmed-tag safety net,
-- now this) -- so generalize: every confirmed example of this whole bug
-- class, charmed-tagged or not, has always started with an article
-- ("A"/"An"/"The", the same shape isMobName() already checks) once any
-- leading parenthetical tags are stripped. Treat that shape alone as
-- sufficient proof of a live presence line worth skipping past, whether
-- or not a clean name can be extracted from it -- strictly broader than
-- the old Charmed-only check, so it subsumes it.
local function isUnparsedPresenceLine(line)
  -- trim() added 2026-07-09 -- real bug found live: static room-landmark
  -- lines are sometimes indented with leading whitespace (e.g. "     A
  -- twisted and gnarled pine tree grows crookedly here."), which broke
  -- this function's `^`-anchored article check even though the *content*
  -- is identical in shape to every other confirmed presence line. This
  -- silently ended capture (RightHere showed completely empty) the
  -- moment an indented landmark line like this was the first thing after
  -- "[Exits: ...]" in the listing. isLookFixtureLine()'s unanchored
  -- substring checks never had this problem; only the `^`-anchored ones
  -- here and in parseLookHereLine() did.
  -- "This " added 2026-07-16 -- fourth confirmed live instance of this
  -- same bug class. Found by tracing a real room-look line by line
  -- (log/2026-07-16#17-23-54.html): "This studded mace looks particularly
  -- dangerous." is an item-flavor-text line, same shape as every other
  -- confirmed presence/fixture line, but starts with neither "A"/"An"/
  -- "The" nor a "lies/lying/left/floats" fixture keyword -- it fell
  -- through every check straight to endLook(), which would have silently
  -- dropped everything listed after it in that same room, including two
  -- real mobs (a war mage, three novice mages) at the very end of the
  -- listing.
  -- "Several " added 2026-07-21 -- fifth confirmed live instance, found
  -- via MyDSL_Leveling.lua's own live testing (exactly the shared-risk
  -- scenario that module's own comments flagged as most likely, since a
  -- leveling run generates far more room-look volume than normal play).
  -- Confirmed via 2 separate real session logs (Olyndros, "Philosophy
  -- Guild"): "     Several small desks are here positioned strategically."
  -- is the very FIRST line after "[Exits: ...]" in that room, plural
  -- ("are here", not "is here"), starts with neither an article nor
  -- "This" -- fell through every check straight to endLook(), silently
  -- dropping every real mob listed after it (2 janitors, 4 students, 1
  -- instructor) every single time this room was visited with that line
  -- present. Directly confirmed via corpus grep across DSL2 + MyDSL logs
  -- (78 occurrences, 7 distinct sentences, ALL furniture/scenery --
  -- booths, chairs, doors, tables, logs, wheelbarrows -- zero real
  -- mob-describing counterexamples) before adding this, matching this
  -- project's own "verify against source" standard.
  local rest = trim(line)
  while true do
    local stripped = rest:match("^%([^()]+%)%s*(.+)$")
    if not stripped then break end
    rest = stripped
  end
  return rest:match("^[Aa]n? ") ~= nil or rest:match("^[Tt]he ") ~= nil
      or rest:match("^This ") ~= nil or rest:match("^Several ") ~= nil
end

function MyDSL.beginLook()
  -- REAL GOTCHA, found live 2026-07-12 -- Steven discovered GMCP is not
  -- enabled by default for newly created DSL characters (confirmed on
  -- one character: traced a full real play session, autowhere/improve/scan/look
  -- all working normally, but zero MyDSL debug output past boot and zero
  -- character-bound files ever created). MyDSL.character.identified only
  -- ever fires from the gmcp.login_data handler above -- if GMCP itself
  -- is off for that character, it silently never fires, and NOTHING
  -- per-character loads, saves, or persists for the whole session, with
  -- no visible sign anything's wrong. This warns once: beginLook() fires
  -- on plain text ("[Exits: ...]"), no GMCP dependency, so it still
  -- fires even with GMCP fully off -- and by the time real room content
  -- is displaying, login/MOTD/character-select are long done, so a still-
  -- nil MyDSL.Char() here is a real signal, not normal startup timing.
  if not MyDSL.Char() and not MyDSL._gmcpWarnedNoChar then
    MyDSL._gmcpWarnedNoChar = true
    cecho("\n<red>[MyDSL] WARNING: no character identified yet (GMCP login_data never arrived).<reset>\n"
       .. "<yellow>If this is a newly created character, GMCP may be OFF by default for it -- "
       .. "check/enable GMCP, or none of MyDSL's per-character saving/loading will work this session.<reset>\n")
  end

  MyDSL.State.scan = MyDSL.State.scan or {
    mode = nil, direction = nil, rows = {}, rightHere = {}, byName = {}, groundItems = {}, last_updated = 0,
  }
  MyDSL.State.scan.rightHere = {}
  MyDSL.State.scan.groundItems = {}
  -- Only one listing-capture should ever be active at a time -- kill a
  -- leftover scan catch-all too, not just a leftover look one.
  if MyDSL._triggers.scanBody then
    pcall(killTrigger, MyDSL._triggers.scanBody)
    MyDSL._triggers.scanBody = nil
  end
  if MyDSL._triggers.lookBody then
    pcall(killTrigger, MyDSL._triggers.lookBody)
    MyDSL._triggers.lookBody = nil
  end
  MyDSL._triggers.lookBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.scan) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    -- Blank lines DON'T end capture here (fixed 2026-07-08) -- confirmed
    -- real, repeatable: a busy room's mob listing can include a genuine
    -- blank line mid-list (same room, same blank-line position, on both
    -- a movement-triggered reprint and an explicit "look"), so treating
    -- blank as a terminator was silently dropping every mob after it.
    -- look has no reliable terminator at all (see the header comment
    -- above) -- skip blanks silently and keep waiting for real content.
    if t == "" then return end
    -- REAL ROOT CAUSE, found 2026-07-08 via a live debug trace (static
    -- analysis alone couldn't catch this): this catch-all gets installed
    -- by lookExits's callback WHILE that same "[Exits: ...]" line is still
    -- being processed, and Mudlet evaluates newly-registered triggers
    -- against that same current line in the same pass -- so this trigger
    -- immediately re-fires on the very "[Exits: ...]" line that just
    -- created it, before any real content line is ever seen. Confirmed
    -- via trace: every single look showed anchor-fired -> beginLook() ->
    -- endLook(), zero entities, every time, with the "unrelated event"
    -- endLook() blamed on turned out to be the Exits line itself. This is
    -- why RightHere showed 0 entries/capture-inactive on every real test
    -- despite the anchor and body logic both being individually correct.
    if t:match("^%[Exits: .*%]$") then return end  -- the anchor line re-seeing itself, not content
    -- Fixture check MUST run before parseLookHereLine -- item lines like
    -- "X lies here." also satisfy parseLookHereLine's broad "here"
    -- fallback below, and would otherwise get miscaptured as mobs.
    if isLookFixtureLine(ln) then MyDSL.captureGroundItem(ln); return end  -- item/corpse/fixture, keep capturing
    if MyDSL.parseLookHereLine(ln) then return end
    if isUnparsedPresenceLine(ln) then return end  -- see comment above the function
    if t:match("^%l") then return end  -- wrapped continuation, keep capturing
    MyDSL.endLook()
  end)
end

function MyDSL.parseLookHereLine(line)
  local scan = MyDSL.State.scan
  if not scan then return false end
  -- Strip ALL leading parenthetical tags, not just one -- confirmed real
  -- multi-tag stacking, e.g. "(Glowing) (Humming) (Green Aura) A ..." and
  -- "(Translucent) (White Aura) An air elemental ...".
  -- trim() added 2026-07-09 -- see isUnparsedPresenceLine()'s comment
  -- above for the confirmed bug this fixes (indented landmark lines
  -- breaking every `^`-anchored check in this function).
  local rest = trim(line)
  while true do
    local stripped = rest:match("^%([^()]+%)%s*(.+)$")
    if not stripped then break end
    rest = stripped
  end
  -- "stands here"/"sits here"/"hovers" added 2026-07-08: confirmed via
  -- corpus frequency check that "stands here" (2,740 occurrences) is
  -- actually MORE common than "is here" (1,928) for describing stationary
  -- NPCs (guards, shopkeepers, mounts) -- these were never captured at
  -- all before this fix. "sits here" is genuinely ambiguous between mobs
  -- ("A hill dwarf sits here, panning for gold.") and items/fixtures
  -- ("A jewel-encrusted dagger sits here."/an altar) -- erred toward
  -- capturing it (a spurious item entry in RightHere is a harmless
  -- cosmetic rough edge; silently dropping a real mob is worse). "hovers"
  -- (139 occurrences, e.g. "An air elemental hovers in the room like a
  -- cloud.", "A half elven child hovers nearby, looking for food.") isn't
  -- always followed by "here" so it's matched on its own.
  -- Broad fallback added 2026-07-08 (see isUnparsedPresenceLine comment
  -- above for the confirmed corpus evidence): charmed/summoned pets use
  -- many different idle-action verbs before "here"/"in the room" ("sloshes
  -- around here.", "prances about here.", "looms here.", "burns hotly in
  -- the room."). Restricted to lines starting with an article (same
  -- shape isMobName already requires) to avoid misreading ordinary room-
  -- description prose. Only reached after isLookFixtureLine has already
  -- ruled out "lies here"/"is lying here" item/corpse lines (see caller).
  -- "stands behind"/"sits behind" added 2026-07-21, found via a full-
  -- codebase audit (same day as the "Several "/3-substring fixture
  -- fixes above): confirmed real and recurring via corpus grep --
  -- bartenders/shopkeepers described as "stands behind the bar/counter"
  -- ("A Dark Elven barmaid stands behind the bar, ready to take your
  -- order.", "A gentleman stands behind the counter.", "A young lady
  -- stands behind a desk here...") or "sits behind" ("Grokk sits behind
  -- the counter working on his latest leather piece.") never matched
  -- "stands here"/"sits here" (different preposition, no "here" at all
  -- in most real examples) -- these NPCs were never captured as mobs at
  -- all, silently, the whole time.
  local name = rest:match("^(.-) is here%f[%A]")
            or rest:match("^(.-) stands here%f[%A]")
            or rest:match("^(.-) sits here%f[%A]")
            or rest:match("^(.-) stands behind%f[%A]")
            or rest:match("^(.-) sits behind%f[%A]")
            or rest:match("^(.-) hovers%f[%A]")
            -- "wanders here" added 2026-07-17 -- confirmed live (screenshot
            -- + corpus check, 90 real occurrences across log/*.html) common
            -- enough to deserve its own pattern like the others above,
            -- rather than falling through to the broad "^An? .+ here"
            -- fallback below, which greedily captures the verb along with
            -- the name ("A gray wolf cub wanders" instead of "A gray wolf
            -- cub") -- cosmetic on its own, but that verb-polluted name
            -- also got stored into CreatureLore's "seen" stub for this key
            -- (see resolveMobName()'s fix above), so fixing the capture
            -- here prevents the bad name from ever entering the db too.
            or rest:match("^(.-) wanders here%f[%A]")
            or rest:match("^([Aa]n? .+) here%f[%A]")
            or rest:match("^([Tt]he .+) here%f[%A]")
            or rest:match("^([Aa]n? .+) in the room%f[%A]")
            or rest:match("^([Tt]he .+) in the room%f[%A]")
  if not name then return false end
  name = trim(name)
  if name == "" then return false end
  local key    = name:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  local is_mob = isMobName(name)
  -- Mark seen + resolve to CreatureLore's canonical name if known -- see
  -- resolveMobName()'s comment (above beginScan()) for the full reasoning.
  -- This is exactly where a `look`-derived name is most likely to be
  -- generic/truncated relative to `scan`'s fuller noun phrase (e.g. "A
  -- gnome is here using levers..." only captures "A gnome" here), so this
  -- is the primary place CreatureLore's better-identified name helps.
  if is_mob and MyDSL.CreatureLore and MyDSL.CreatureLore.markSeen then
    MyDSL.CreatureLore.markSeen(key, name)
  end
  local dispName = is_mob and resolveMobName(key, name) or name
  -- Fixed 2026-07-08, per Steven ("not updating correctly on mob
  -- counts"): this used to unconditionally overwrite scan.rightHere[key]
  -- with a fresh count=1 table every time, so a room with 3 identical
  -- mobs (e.g. "A gnome in a protective heat suit is studying here."
  -- appearing twice) always showed count=1 in the RightHere window --
  -- each repeat just clobbered the previous one instead of incrementing.
  -- Matches the same increment-if-exists pattern parseScanLine already
  -- uses for scan.rightHere just above.
  if scan.rightHere[key] then
    scan.rightHere[key].count = scan.rightHere[key].count + 1
  else
    scan.rightHere[key] = {
      raw = line, name = dispName, display = dispName, key = key,
      where = "right here", is_mob = is_mob, count = 1,
    }
  end
  return true
end

function MyDSL.endLook()
  if MyDSL._triggers.lookBody then
    pcall(killTrigger, MyDSL._triggers.lookBody)
    MyDSL._triggers.lookBody = nil
  end
  MyDSL.State.scan.last_updated = os.time()
  MyDSL.emit("scan")
end




------------------------------------------------------------------------
-- 9o.2  PLAYERS NEAR YOU
------------------------------------------------------------------------
-- Fixed 2026-07-05, per Steven: "Players near you:" (fired every ~20s by
-- his own autowhere-style alias, not part of this project) was flowing
-- untouched into main console -- MyDSL.Route.players() already existed in
-- RouteHelper (auto-creates the MyDSL_PlayersNear MiniConsole) but was
-- never actually called from anywhere. Confirmed real body shape from
-- log/: "Players near you:" header, one "<Name><padding><Room>" line per
-- player, terminated by a blank line -- same begin/catch-all/end shape as
-- beginScan(), and the same "move text, don't rewrite it" observer pattern
-- (appendBuffer via Route.players(nil), not a reformatted decho).

-- isPlayersNearBodyLine() -- added 2026-07-11, real bug found live via
-- screenshot: the catch-all below used to accept ANY non-blank line
-- unconditionally, relying solely on a blank line to end capture. Same
-- fragile shape as every RightHere-on-look bug fixed earlier this
-- session -- if DSL interleaves an unrelated broadcast (a combat
-- condition update, a bare single-letter weapon-flag proc line) before
-- the real blank-line terminator arrives, it gets vacuumed into
-- MyDSL_PlayersNear right along with real players. Confirmed live:
-- "A tinker gnome mage is in awful condition." and bare "S" lines (the
-- Stunning proc flag's own wire text) both showed up mixed in with real
-- "<Name>   A Sloped Hall" / "<Name>   Arena" entries. Real body lines
-- never end in sentence punctuation and always have a wide column-
-- padding gap between name and room (confirmed shape, see the header
-- comment above) -- a condition sentence ends in "." and a bare proc
-- letter has no gap at all, so both are cheaply distinguishable without
-- needing to enumerate every possible interrupting broadcast.
local function isPlayersNearBodyLine(line)
  if line:match("[%.!?]%s*$") then return false end
  if not line:match("^%S+%s%s+%S") then return false end
  return true
end

-- routePlayersNearBodyLine(line) -- added 2026-07-12, per Steven
-- ("playersnearyou: can we reduce the space between the players name and
-- the room, make the text tighter together for a smaller window without
-- losing the coloring of the players name?"). DSL's own wide column-
-- padding between name and room (confirmed shape above) is what made the
-- gap so wide -- still real text DSL sent, not fabricated, so this only
-- changes how much of that whitespace gets carried over, not the name or
-- room text itself.
--
-- REAL BUG, found live 2026-07-12 via screenshot (Steven: "players near
-- you has room names in it"): the first version of this function called
-- selectSection()/copy()/con:appendBuffer() TWICE (once for the name,
-- once for the room), with a con:echo("  ") in between to join them on
-- one line. appendBuffer() doesn't work that way -- confirmed via the
-- Mudlet forums (search: "appendBuffer... cursor stays on line 1, this
-- output call doesn't update the cursor position") -- each appendBuffer()
-- call always lands its copied text as its OWN new line in the
-- destination console, regardless of where echo() thinks the cursor is.
-- That's why the screenshots showed the character name and the room name ("The Magic
-- Facility"/"Advanced Magics") as two separate stacked lines with no
-- visible gap between them -- the con:echo("  ") calls were writing to a
-- stale cursor position that never lined up with either appended line.
-- Every other Route.to()-based window in this profile (History/Combat/
-- Scan/Group/RightHere) only ever calls copy()+appendBuffer() ONCE per
-- routed line for exactly this reason.
--
-- Fixed by tightening the gap IN PLACE on the source line before doing a
-- single whole-line copy: selectSection() the gap substring only and
-- replace() it with a fixed 2-space gap -- this edits real whitespace in
-- the actual captured line (not the name or room text, which are left
-- completely untouched, coloring included), so the one-shot
-- selectCurrentLine()/copy()/appendBuffer() below still carries the DSL-
-- original color for both name and room, just with a tighter gap between
-- them. Falls back to routing the line unchanged if the expected shape
-- isn't found (never guesses at a split that isn't really there).
local function routePlayersNearBodyLine(line)
  local name, gap, rest = line:match("^(%S+)(%s%s+)(%S.*)$")
  if name and gap ~= "  " then
    selectSection(#name, #gap)
    replace("  ")
  end
  MyDSL.Route.players(nil)
end

-- parsePlayersNearBodyLine(line) -- structured name+room extraction, per
-- Steven's MyDSL notes ("mapper: highlight other players' rooms from the
-- where command"). Same split this function's raw-text sibling above
-- already relies on (confirmed real DSL column-padded shape); this just
-- ALSO keeps the two parts instead of only using them to tighten
-- whitespace. Room text feeds map.dsl.highlightPlayersNear() in
-- DSL_Generic_Mapper.xml via a raised event -- deliberately NOT resolved
-- to a room ID here, since room lookup (searchRoom()) is the mapper's
-- own domain, not DataLayer's.
local function parsePlayersNearBodyLine(line)
  local name, _, room = line:match("^(%S+)(%s%s+)(%S.*)$")
  if not name or not room then return nil end
  return { name = name, room = trim(room) }
end

-- FIX 2026-08-29, per Steven live-test note ("players near you shows in
-- window also named players near you"): this used to copy/route the
-- literal "Players near you:" header line into MyDSL_PlayersNear before
-- capturing body lines, duplicating the window's own title ("Players
-- Near"). The window title already says this -- gag the header off main
-- console instead of routing it as content, same as beginScan()'s header
-- line is handled.
function MyDSL.beginPlayersNear()
  if not (MyDSL and MyDSL.Route) then return end
  MyDSL.Route.clear("MyDSL_PlayersNear")
  MyDSL._playersNearParsed = {}
  selectCurrentLine()
  deleteLine()

  if MyDSL._triggers.playersNearBody then
    pcall(killTrigger, MyDSL._triggers.playersNearBody)
    MyDSL._triggers.playersNearBody = nil
  end
  MyDSL._triggers.playersNearBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.Route) then return end
    local ln = getCurrentLine()
    if trim(ln) == "" then MyDSL.endPlayersNear(); return end
    -- Unrelated broadcast interleaved mid-block -- skip it, but keep
    -- capturing (don't end early): more real player lines may still
    -- follow before the actual blank-line terminator arrives.
    if not isPlayersNearBodyLine(ln) then return end
    local parsed = parsePlayersNearBodyLine(ln)
    if parsed then table.insert(MyDSL._playersNearParsed, parsed) end
    routePlayersNearBodyLine(ln)
    deleteLine()
  end)
end

function MyDSL.endPlayersNear()
  if MyDSL._triggers.playersNearBody then
    pcall(killTrigger, MyDSL._triggers.playersNearBody)
    MyDSL._triggers.playersNearBody = nil
  end
  if MyDSL._playersNearParsed and #MyDSL._playersNearParsed > 0 then
    raiseEvent("MyDSL.playersNear.parsed", MyDSL._playersNearParsed)
  end
end



------------------------------------------------------------------------
-- Trigger registration above moved here with its functions rather than
-- left in MyDSL_DataLayer.lua's own trigger-registration section, same
-- precedent as the prior two slices -- this file is a complete,
-- self-contained module.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Scan triggers
------------------------------------------------------------------------
-- Two permanent triggers: one for "scan" (all-directions), one for
-- "scan <dir>" (directional). Both call beginScan() which resets
-- State.scan and installs the body catch-all.

-- Hardened 2026-07-08 (same bug class as the Exits-line fix above):
-- corpus check found 9 of 412 real occurrences have a leading double-space
-- ("  Looking around you see:") that the old exact anchor missed.
MyDSL._triggers.scanAround = tempRegexTrigger(
  "^\\s*Looking around you see:$",
  function()
    if MyDSL and MyDSL.beginScan then MyDSL.beginScan("around", nil) end
  end
)

MyDSL._triggers.scanDir = tempRegexTrigger(
  "^You peer intently ([a-zA-Z]+)\\.$",
  function()
    if not (MyDSL and MyDSL.beginScan) then return end
    local dir = getCurrentLine():match("^You peer intently (%a+)%.$")
    MyDSL.beginScan("direction", dir)
  end
)

-- Room's own "[Exits: ...]" line -- always immediately precedes a `look`'s
-- (or any room reprint's, e.g. after movement) content listing. See the
-- beginLook() comment above for why this anchor was picked over a fixed
-- header phrase.
-- FIX 2026-07-08: this anchor never fired, ever -- confirmed via corpus
-- grep across every single "Exits:" line in the DSL2-era logs (172
-- distinct room/exit combos, 100% of them), the real line always has one
-- leading space before "[Exits:" (e.g. " [Exits: north east south west
-- ]"), which the old "^\[Exits: ..." pattern's start anchor rejects. This
-- means beginLook() has never actually been triggered by real gameplay --
-- every fix made to the capture body logic today was real but moot, since
-- capture never started in the first place. My emulation testing missed
-- this because it called MyDSL.beginLook() directly, never exercising
-- this trigger's own pattern against real text.
-- Round 4, found via a live debug trace 2026-07-08 (see beginLook()'s
-- catch-all comment for the actual root cause -- a self-retrigger on this
-- same anchor line, not this trigger's own pattern).
MyDSL._triggers.lookExits = tempRegexTrigger(
  "^\\s*\\[Exits: .*\\]\\s*$",
  function()
    -- Used to also call MyDSL.captureRoomDescription() here (the old
    -- room-description-for-LocationView capture, 9o.1b) -- removed
    -- 2026-07-19 along with that whole section: LocationView now reads
    -- name/description/exits/terrain straight from the mapper's own
    -- per-room-ID userdata instead (the DSL_Generic_Mapper fork already
    -- captures a real description there, anchored to the room ID at
    -- resolution time, not derived from this file's own backward text
    -- scan) -- see docs/CHANGELOG.md 2026-07-19. Nothing else read
    -- MyDSL.State.room.description, so the whole capture was retired
    -- rather than left running unused.
    if MyDSL and MyDSL.beginLook then MyDSL.beginLook() end
  end
)

-- "Players near you:" -- fires independently of scan's own catch-all (which
-- only uses this line to know scan has ended, doesn't gag/route it itself).
MyDSL._triggers.playersNearStart = tempRegexTrigger(
  "^Players near you:$",
  function()
    if MyDSL and MyDSL.beginPlayersNear then MyDSL.beginPlayersNear() end
  end
)

-- REAL BUG, found live 2026-07-12 via log-corpus grep (Steven: "something
-- broke the autowhere alias and it now displays none instead of gaging
-- it"): confirmed against log/2026-07-12#09-01-16.html that DSL's `where`
-- command has TWO distinct response shapes -- the "Players near you:"
-- header + name/room lines (handled above) when other players ARE
-- nearby, but a bare, standalone "None" line with NO header at all when
-- nobody is. The trigger above only ever matches the header, so the
-- no-one-nearby case was never captured/routed -- it fell straight
-- through into the main console untouched every ~20s (Steven's own
-- autowhere alias, not part of this project, sends `where` on that
-- cadence). Not actually specific to any one room, despite how it first
-- looked live -- confirmed via corpus grep this fires constantly
-- whenever no other player happens to be nearby, room-independent.
-- Same move-not-duplicate handling as the header case: MOVES the literal
-- "None" line into MyDSL_PlayersNear (clearing stale names first) rather
-- than inventing different text, consistent with "move text, don't
-- replace it." Matched only as the ENTIRE line content (`^None$`), not a
-- substring, to minimize collision risk with any other real DSL text
-- that might legitimately be the single word "None" in a different
-- context.
MyDSL._triggers.playersNearEmpty = tempRegexTrigger(
  "^None$",
  function()
    if not (MyDSL and MyDSL.Route) then return end
    MyDSL.Route.clear("MyDSL_PlayersNear")
    selectCurrentLine()
    copy()
    MyDSL.Route.players(nil)
    deleteLine()
  end
)

