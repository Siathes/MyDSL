-- =============================================================================
-- MyDSL_DataLayer_ItemLore.lua  --  Layer 1: Data Collection (Item Lore / Equipment / Inventory capture)
-- =============================================================================
-- Split out of MyDSL_DataLayer.lua 2026-08-25, fourth slice of the split-
-- by-domain refactor (see docs/TODO.md for the full plan and prior
-- slices' writeup). Covers everything item-shaped: identify/lore
-- capture, your own equipment ("You are using:"), other characters'/
-- creatures' equipment ("<Name> is using:"), carried inventory, and
-- container contents (exam/look in/search).
--
-- Cross-domain dependencies, both already resolved by the time this
-- slice happened, neither required new promotion work:
--   - MyDSL.bestFuzzyMatch() (promoted to core SECTION 2 during slice 3)
--     is used here by MyDSL.resolveGroundItem().
--   - MyDSL.buildItemStatsSuffix() (moved to MyDSL_DataLayer_ScanLook.lua
--     in slice 3) is called from this file's equip/inventory/container
--     hover-hint lines -- harmless dofile() order either way since both
--     are load-time definitions and the call only happens later at
--     trigger-fire time.
--   - MyDSL.resolveGroundItem() (defined in THIS file) is called by
--     MyDSL_DataLayer_ScanLook.lua's applyGroundItemHover() -- the
--     reverse direction of the buildItemStatsSuffix dependency above,
--     same "harmless either order" reasoning.
--
-- Same contract as before the split: zero display logic, never sends
-- commands to the game. Depends on MyDSL_DataLayer.lua already being
-- loaded (MyDSL.State/MyDSL._triggers/MyDSL.emit/MyDSL.bestFuzzyMatch
-- all come from there) -- dofile() order matters, this file must load
-- AFTER it.
-- =============================================================================

MyDSL = MyDSL or {}

local function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end

------------------------------------------------------------------------
-- 9p.1  ITEM LORE / IDENTIFY
------------------------------------------------------------------------
-- Feeds MyDSL_ItemLore.lua's persistent DB. Two live capture paths, both
-- confirmed real via live sessions 2026-07-16 (full transcripts in
-- docs/CapturedPatterns_Reference.txt / CHANGELOG.md):
--   `c identify <keyword>` (the spell) -- full stats, including bonuses/
--   enchants ("Affects X by N", "Weapons flags:", "Armor class is...").
--   `lore <keyword>` (the skill, chance-based) -- a real subset of the
--   same fields, but NEVER bonuses/enchants -- confirmed absent from
--   every real lore transcript. This is what makes MyDSL_ItemLore.lua's
--   merge() safe to reuse unmodified for both: lore's own parsed record
--   simply never has those keys, so it can never downgrade an
--   already-identified item back to partial.

local function itemKey(name)
  return trim(tostring(name or "")):lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
end

-- MyDSL.resolveItemLoreRecord(itemName) -- added 2026-08-30, real bug
-- found live (Steven: "c ident pants... items arent persisting after
-- identifying"). identify persisted the record correctly (confirmed
-- directly in itemlore_db.lua), but every click-hover site below
-- (equipment/others'-equipment/inventory/container) looked the record up
-- by the exact displayed short description -- which DSL doesn't
-- guarantee matches identify's own canonical object name (real example,
-- same session: equipment shows "a heat resistant pair of pants",
-- identify reports "heat resistant pants"). Exact key first, then the
-- same fuzzy-match fallback MyDSL.resolveGroundItem() already uses
-- against every known ItemLore record, so "no stats" only really means
-- "never identified/lored", not "identified but unreachable by name".
-- Returns (rec, resolvedName) -- resolvedName is what should be passed
-- to MyDSL.ItemReference.render() so its own lookup succeeds too;
-- falls back to the original itemName when nothing matches.
function MyDSL.resolveItemLoreRecord(itemName)
  local key = itemKey(itemName)
  if MyDSL.ItemLore and MyDSL.ItemLore.get then
    local rec = MyDSL.ItemLore.get(key)
    if rec then return rec, itemName end
  end
  if MyDSL.ItemLore and MyDSL.ItemLore.db and MyDSL.bestFuzzyMatch then
    local candidates = {}
    for k, rec in pairs(MyDSL.ItemLore.db) do
      candidates[#candidates + 1] = { name = rec.name or k, rec = rec }
    end
    local hit = MyDSL.bestFuzzyMatch(itemName, candidates)
    if hit then return hit.rec, hit.name end
  end
  return nil, itemName
end

-- MyDSL.resolveGroundItem(key) -- added 2026-07-16, ItemLore's counterpart
-- to resolveMobName() (see the SCAN section above for the shared
-- normalizeForMatch()/bestFuzzyMatch() helper both use). Given a ground
-- item's key (from MyDSL.State.scan.groundItems, populated by
-- captureGroundItem()), tries to resolve it to the same item already seen
-- equipped or carried. Checks ItemLore's own DB by exact key first (if
-- this ground item was already identified/lore'd directly under this
-- exact name, no fuzzy step is needed). Otherwise fuzzy-matches the
-- ground sentence's stripped core name against every currently-known
-- equipment slot and inventory item -- confirmed via a real paired sample
-- (log/2026-07-16#17-23-54.html) that roughly 2/3 of items share a clean
-- substring once both sides are normalized (e.g. "a decanter of endless
-- water" <-> "A decanter of endless water lies here."); the rest
-- (independently-phrased ground flavor text, e.g. "a shaping mallet" vs.
-- "a mallet used to shape metal") correctly score 0 and return nil rather
-- than guessing -- best-effort only, per Steven ("best effort mapping is
-- fine, maybe a manual map option").
function MyDSL.resolveGroundItem(key)
  local ground = MyDSL.State.scan and MyDSL.State.scan.groundItems and MyDSL.State.scan.groundItems[key]
  if not ground then return nil end

  -- Manual override wins outright -- see MyDSL.setGroundItemOverride()
  -- below ("item map <ground text> = <inventory/equipment text>").
  local override = MyDSL.State.groundItemOverrides and MyDSL.State.groundItemOverrides[key]
  if override then return { key = override, name = override, source = "manual" } end

  if MyDSL.ItemLore and MyDSL.ItemLore.get then
    local rec = MyDSL.ItemLore.get(key)
    if rec then return { key = key, name = rec.name or ground.name, source = "itemlore" } end
  end

  local candidates = {}
  local eq = MyDSL.State.equipment and MyDSL.State.equipment.slots
  if eq then
    for slot, entry in pairs(eq) do
      if entry and entry.item then
        candidates[#candidates + 1] = {
          name = entry.item, key = itemKey(entry.item), source = "equipment", slot = slot,
        }
      end
    end
  end
  local inv = MyDSL.State.inventory and MyDSL.State.inventory.items
  if inv then
    for k, entry in pairs(inv) do
      candidates[#candidates + 1] = { name = entry.item, key = k, source = "inventory" }
    end
  end

  return MyDSL.bestFuzzyMatch(ground.name, candidates)
end

-- MyDSL.setGroundItemOverride(groundText, targetText) -- the "manual map
-- option" Steven asked for, for the real fraction of items where the
-- automatic fuzzy match correctly declines (no shared substring) but the
-- player knows for certain it's the same item. Keyed by the ground text's
-- own itemKey() so it applies to every future sighting of that same
-- ground description, not just the one currently in view.
function MyDSL.setGroundItemOverride(groundText, targetText)
  groundText = trim(tostring(groundText or ""))
  targetText = trim(tostring(targetText or ""))
  if groundText == "" or targetText == "" then
    echo("usage: item map <ground item text> = <inventory/equipment item name>\n")
    return
  end
  local key = itemKey(groundText)
  MyDSL.State.groundItemOverrides = MyDSL.State.groundItemOverrides or {}
  MyDSL.State.groundItemOverrides[key] = targetText
  echo("Ground item \"" .. groundText .. "\" manually mapped to \"" .. targetText .. "\".\n")
end

-- Shared body-line parser -- both identify and lore blocks use the same
-- optional-line shapes (confirmed identical wording in both real
-- transcripts); which subset actually appears just depends on which
-- command produced the block.
local function parseItemBodyLine(r, line)
  local weight, value, level = line:match("^Weight is (%d+), value is (%d+), level is (%d+)%.$")
  if weight then r.weight = tonumber(weight); r.value = tonumber(value); r.level = tonumber(level); return end

  local material = line:match("^The object is made of (.+)%.$")
  if material then r.material = material; return end

  local wtype = line:match("^Weapon type is (.+)%.$")
  if wtype then r.weaponType = wtype; return end

  local dice, avg = line:match("^Damage is (%d+d%d+) %(average (%d+)%)%.$")
  if dice then r.damageDice = dice; r.damageAvg = tonumber(avg); return end

  local wflags = line:match("^Weapons flags: (.+)$")
  if wflags then r.weaponFlags = wflags; return end

  local p, b, s, m = line:match("^Armor class is (%d+) pierce, (%d+) bash, (%d+) slash, and (%d+) vs%. magic%.$")
  if p then r.armorClass = { pierce = tonumber(p), bash = tonumber(b), slash = tonumber(s), magic = tonumber(m) }; return end

  local size, cond, pct = line:match("^Size: (%a+)%s+Condition: (.-) %((%d+)%%%)$")
  if size then r.size = size; r.condition = cond .. " (" .. pct .. "%)"; return end

  local cap, maxw, cflags = line:match("^Capacity: (%d+)#%s+Maximum weight: (%d+)#%s+flags: (.+)$")
  if cap then r.capacity = tonumber(cap); r.maxWeight = tonumber(maxw); r.containerFlags = cflags; return end

  local mult = line:match("^Weight multiplier: (%d+)%%$")
  if mult then r.weightMultiplier = tonumber(mult); return end

  local charges, clevel, spell = line:match("^Has (%d+) charges of level (%d+) '(.+)'%.$")
  if charges then r.spellCharges = { charges = tonumber(charges), level = tonumber(clevel), spell = spell }; return end

  local slevel = line:match("^Level (%d+) spells of: ")
  if slevel then
    local spells = {}
    for s2 in line:gmatch("'([^']*)'") do spells[#spells + 1] = s2 end
    r.spellList = { level = tonumber(slevel), spells = spells }
    return
  end

  local color, liquid = line:match("^It holds (.-)%-colored (.+)%.$")
  if color then r.drinkLiquid = color .. "-colored " .. liquid; return end

  local stat, amt = line:match("^Affects (.+) by (%-?%d+)%.$")
  if stat then
    r.affects = r.affects or {}
    table.insert(r.affects, { stat = stat, amount = tonumber(amt) })
    return
  end
end

-- ---- identify (the spell, full stats) ----
-- First line carries name+type+flags all at once, e.g. "Object 'mushroom'
-- is type food, extra flags none." -- same reasoning as CreatureLore's
-- "Creature: X  Race: Y" first line.

-- Identify source-scoping -- real bug found 2026-08-24, per Steven
-- ("if someone posts an identified item, the item reference captures
-- that for its info, but its enchanted and not the normal stats, need
-- a way to seperate or just not replace the info unless self
-- identified"). Confirmed real via 3 distinct corpus mechanisms that
-- all produce the exact same "Object '<name>' is type ..." line
-- beginIdentify() below fires on, with nothing to tell them apart:
--   (1) a real self-cast identify ("c ident <target>", corpus-confirmed) --
--       the intended, authoritative case.
--   (2) `insp`/`inspect <item>` -- confirmed via DSL_Helpfiles/"buy list
--       sell value inspect.txt": a SHOP command showing a shopkeeper's
--       for-sale item's attributes, not the player's own possession.
--   (3) `anote read` -- confirmed via corpus (log/2026-07-04#12-43-48.html):
--       a bulletin-board note whose body text can itself quote an
--       identify-shaped block (a seller pasted their own identify
--       output into an auction note) -- this arrives with zero relation
--       to anything the player just did.
-- Fix: only trust this as a real self-identify if the player's own most
-- recent OUTGOING command (captured via sysDataSendRequest, the same
-- technique DSL_Generic_Mapper.xml already uses for move-cost capture)
-- was genuinely an identify-cast, within a short freshness window (6s,
-- matching that same file's DSL_CONTEXT_TIMEOUT precedent for the exact
-- same class of problem -- a stale command context replayed against an
-- unrelated later message). "c ident <x>" is directly corpus-confirmed;
-- "cast identify"/"cast 'identify'" are included as reasonable syntax
-- variants matching this game's own general cast-command convention,
-- not independently corpus-confirmed for this specific spell. Anything
-- NOT armed this way still gets captured (never discarded -- it's real
-- information about the item) but tagged source="observed" instead of
-- "identify", so IL.merge() (MyDSL_ItemLore.lua) automatically treats it
-- as fill-gaps-only, the same safe treatment `lore` already gets --
-- reusing that existing two-tier trust model instead of inventing a
-- third one.
MyDSL._lastOutgoingCommand = MyDSL._lastOutgoingCommand or nil

local function isIdentifyCastCommand(cmd)
  if not cmd then return false end
  cmd = cmd:lower():trim()
  return cmd:match("^c%s+ident%a*%s") ~= nil
    or cmd:match("^cast%s+'?ident%a*'?%s") ~= nil
end

MyDSL._handlers.identifyCommandCapture = registerAnonymousEventHandler(
  "sysDataSendRequest",
  function(_, cmd)
    MyDSL._lastOutgoingCommand = { cmd = cmd, time = os.time() }
  end
)

local function lastCommandWasIdentifyCast()
  local last = MyDSL._lastOutgoingCommand
  if not last or not last.cmd or not last.time then return false end
  if (os.time() - last.time) > 6 then return false end
  return isIdentifyCastCommand(last.cmd)
end

function MyDSL.beginIdentify(line)
  local name, itype, flags = line:match("^Object '(.-)' is type ([%w_]+), extra flags (.+)%.$")
  if not name then return end
  MyDSL.State.identify = {
    name = name, key = itemKey(name), itemType = itype,
    extraFlags = (flags ~= "none" and flags or nil),
    source = lastCommandWasIdentifyCast() and "identify" or "observed",
  }
  if MyDSL._triggers.identifyBody then
    pcall(killTrigger, MyDSL._triggers.identifyBody)
    MyDSL._triggers.identifyBody = nil
  end
  MyDSL._triggers.identifyBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.identify) then return end
    local ln = getCurrentLine()
    if trim(ln) == "" then MyDSL.endIdentify(); return end
    parseItemBodyLine(MyDSL.State.identify, ln)
  end)
end

function MyDSL.endIdentify()
  if MyDSL._triggers.identifyBody then
    pcall(killTrigger, MyDSL._triggers.identifyBody)
    MyDSL._triggers.identifyBody = nil
  end
  local r = MyDSL.State.identify
  if r and MyDSL.ItemLore and MyDSL.ItemLore.merge then
    MyDSL.ItemLore.merge(r)
  end
  -- MyDSL.emit() raises "MyDSL.itemlore.updated" with MyDSL.State.itemlore
  -- as its payload (see MyDSL.emit()'s own implementation) -- set it here
  -- so MyDSL_ItemReference.lua's listener has the just-captured record to
  -- render, same convention MyDSL.State.creaturelore already follows for
  -- CreatureReference. Left set (not nil'd) so a later read still works.
  if r then MyDSL.State.itemlore = r end
  MyDSL.emit("itemlore")
end

-- ---- lore <item> (the skill, chance-based, partial) ----
-- Real shape: "You turn a X every which way." always fires first, THEN
-- either "Can't make heads or tails of it." (fail, terminal, confirmed
-- real 2026-07-16) or a blank line followed by the "Name(s): '...'" /
-- "Type: ... Weight: ... Value: ... Level: ... Material: ...." block.

function MyDSL.beginLoreItem(line)
  MyDSL.State.loreItem = { lines = { line }, pending = true }
  if MyDSL._triggers.loreItemBody then
    pcall(killTrigger, MyDSL._triggers.loreItemBody)
    MyDSL._triggers.loreItemBody = nil
  end
  MyDSL._triggers.loreItemBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State and MyDSL.State.loreItem) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    local r  = MyDSL.State.loreItem
    if r.pending then
      if t == "Can't make heads or tails of it." then
        MyDSL.endLoreItem(false)
      elseif t == "" then
        r.pending = false
      else
        -- Unexpected text between the flavor line and the block --
        -- bail out rather than silently misparsing.
        MyDSL.endLoreItem(false)
      end
      return
    end
    if t == "" then MyDSL.endLoreItem(true); return end
    local name = ln:match("^Name%(s%): '(.+)'$")
    if name then r.name = name; r.key = itemKey(name); return end
    local itype, weight, value, level, material =
      ln:match("^Type: (%a+)%s+Weight: (%d+)%s+Value: (%d+)%s+Level: (%d+)%. Material: (.+)%.$")
    if itype then
      r.itemType = itype; r.weight = tonumber(weight); r.value = tonumber(value)
      r.level = tonumber(level); r.material = material
      return
    end
    parseItemBodyLine(r, ln)
  end)
end

function MyDSL.endLoreItem(success)
  if MyDSL._triggers.loreItemBody then
    pcall(killTrigger, MyDSL._triggers.loreItemBody)
    MyDSL._triggers.loreItemBody = nil
  end
  local r = MyDSL.State.loreItem
  MyDSL.State.loreItem = nil
  if success and r and r.key and MyDSL.ItemLore and MyDSL.ItemLore.merge then
    r.source = "lore"
    MyDSL.ItemLore.merge(r)
    MyDSL.State.itemlore = r
    MyDSL.emit("itemlore")
  end
end


------------------------------------------------------------------------
-- 9r  EQUIPMENT
------------------------------------------------------------------------
-- Ported 2026-07-07 from DSL_PNP_Character.equipment.lua (PNP/EMCO
-- cannibalization pass, Phase E) -- passive capture only. PNP's own
-- version also has a useItem() convenience that SENDS commands
-- (wear/wield/get) -- deliberately NOT ported: this file's own header
-- says "Never sends commands to the game", and CLAUDE.md reserves
-- user-initiated game commands for a display-module button (like
-- TargetView's action buttons), not Layer 1. A future EquipmentView
-- could add an interactive "use equipped item" button if wanted.
--
-- Real format confirmed against 154 unique lines in the clean corpus:
--   "You are using:"
--   "<used as light>     (Blue Aura) (Glowing) a Guiding jewel -[30] ..."
--   "<worn on finger>    (nothing)"
--   "<worn about body>   a long robe -[30] 7/7/7/3 (W)-1S,2D ..."
-- Slot descriptions actually seen: "floating nearby", "held", "secondary
-- weapon", "sheathed", "used as light", "wielded", "worn about
-- body/waist", "worn around neck/wrist", "worn as quiver/shield",
-- "worn on arms/feet/finger/hands/head/legs/torso" -- matches PNP's own
-- expected slot list. finger/neck/wrist auto-number to 1/2 (you can wear
-- two), same as PNP. Item text can itself contain parens after any
-- leading flag-parens (weapon/armor stat blocks like "(W)-1S,2D (R)
-- 4Con,2H") -- the trigger only captures broad boundaries (slot / rest
-- of line), the flags-vs-item split happens in Lua below, where it's
-- just stripping consecutive leading "(x) " groups -- avoids relying on
-- PCRE backtracking to split two overlapping-charset capture groups the
-- way PNP's own regex does.

local equipBlock = {}
local ringIdx, neckIdx, wristIdx = 0, 0, 0

-- Same filler words PNP strips, same order -- confirmed via the log-
-- corpus test above that this normalizes every real slot string seen.
local EQUIP_FILLER_WORDS = { "worn ", "used ", "as ", "on ", "around ", "about ", " nearby", " weapon" }

local function normalizeEquipSlot(raw)
  local slot = raw
  for _, w in ipairs(EQUIP_FILLER_WORDS) do
    slot = slot:gsub(w, "", 1)
  end
  slot = trim(slot)
  if slot == "finger" then ringIdx = ringIdx + 1; slot = slot .. ringIdx end
  if slot == "neck"   then neckIdx = neckIdx + 1; slot = slot .. neckIdx end
  if slot == "wrist"  then wristIdx = wristIdx + 1; slot = slot .. wristIdx end
  return slot
end

function MyDSL.beginEquip()
  equipBlock = {}
  ringIdx, neckIdx, wristIdx = 0, 0, 0
  if MyDSL._triggers.equipBody then
    pcall(killTrigger, MyDSL._triggers.equipBody)
    MyDSL._triggers.equipBody = nil
  end
  MyDSL._triggers.equipBody = tempRegexTrigger(".*", function()
    local ln = getCurrentLine()
    if trim(ln) == "" then MyDSL.endEquip(); return end
    local rawSlot, rest = ln:match("^<([a-z ]+)>%s*(.+)$")
    if rawSlot and MyDSL.parseEquipLine then MyDSL.parseEquipLine(rawSlot, rest) end
  end)
end

function MyDSL.parseEquipLine(rawSlot, rest)
  local slot = normalizeEquipSlot(rawSlot)
  if rest == "(nothing)" then
    equipBlock[slot] = { item = nil, flags = {} }
    return
  end
  local flags = {}
  local remaining = rest
  while true do
    local flag, tail = remaining:match("^%((.-)%)%s*(.*)$")
    if not flag then break end
    flags[#flags + 1] = flag
    remaining = tail
  end
  local itemName = trim(remaining)
  equipBlock[slot] = { item = itemName, flags = flags }

  -- Hover/click on the equipment line's own item-name text -- added
  -- 2026-07-16 for Layer 4's item reference. "Move text, don't invent
  -- it": uses selectString()+setLink() (same technique already proven in
  -- MyDSL_AffectsView.lua's applyLinks(), specifically to avoid the real
  -- Mudlet limitation that reconstructing a line via decho/cecho would
  -- discard the game's own ANSI coloring) to attach a hover tooltip +
  -- click-to-open-Item-Reference directly onto the already-printed,
  -- untouched equipment line in the main console -- never deletes or
  -- reprints anything.
  if itemName ~= "" and setLink and selectString then
    local rec, resolvedName = MyDSL.resolveItemLoreRecord(itemName)
    local hint = "Click for Item Reference" .. MyDSL.buildItemStatsSuffix(rec)
    local cmd = string.format(
      'if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.render("%s"); MyDSL.ItemReference.show() end',
      resolvedName:gsub('"', '\\"'))
    local okSel, selected = pcall(selectString, "main", itemName, 1)
    if okSel and selected then
      pcall(setLink, "main", cmd, hint)
    end
  end
end

function MyDSL.endEquip()
  if MyDSL._triggers.equipBody then
    pcall(killTrigger, MyDSL._triggers.equipBody)
    MyDSL._triggers.equipBody = nil
  end
  MyDSL.update("equipment", { slots = equipBlock })
  equipBlock = {}
end


------------------------------------------------------------------------
-- 9p.2  OTHER CHARACTERS'/CREATURES' EQUIPMENT ("<Name> is using:")
------------------------------------------------------------------------
-- Added 2026-07-19, per Steven ("integrate the eq of others hover text
-- note") -- confirmed real format via log corpus for both a mob
-- ("Brash is using:", log/2026-07-16#18-07-53.html) and a real player/
-- dragon character ("Qinrathaz is using:",
-- MyDSL/log/2026-07-19#16-33-40.html): identical body-line shape to
-- your own "You are using:" listing (same "<slot>  (flags) item name"
-- format, confirmed multi-slot in the Qinrathaz capture -- light/
-- finger/neck x2/head/wrist x2/held all present and correctly
-- formatted), just prefixed with the subject's name instead of "You".
--
-- Deliberately hover-only, no state accumulation: unlike your own
-- equipment, this must NOT touch MyDSL.State.equipment (that table
-- specifically drives CharacterAssist's rearm/spellup decisions about
-- YOUR OWN gear -- someone else's equipment has nothing to do with
-- that), so there's no begin/end block to assemble or an `MyDSL.update()` to
-- call, just the same per-line hover technique parseEquipLine() already
-- uses, reused directly rather than duplicated with a different shape.
function MyDSL.beginOthersEquip(name)
  if MyDSL._triggers.othersEquipBody then
    pcall(killTrigger, MyDSL._triggers.othersEquipBody)
    MyDSL._triggers.othersEquipBody = nil
  end
  MyDSL._triggers.othersEquipBody = tempRegexTrigger(".*", function()
    local ln = getCurrentLine()
    if trim(ln) == "" then
      if MyDSL._triggers.othersEquipBody then
        pcall(killTrigger, MyDSL._triggers.othersEquipBody)
        MyDSL._triggers.othersEquipBody = nil
      end
      return
    end
    local rawSlot, rest = ln:match("^<([a-z ]+)>%s*(.+)$")
    if rawSlot and MyDSL.parseOthersEquipLine then MyDSL.parseOthersEquipLine(rest) end
  end)
end

function MyDSL.parseOthersEquipLine(rest)
  if rest == "(nothing)" then return end
  local remaining = rest
  while true do
    local flag, tail = remaining:match("^%((.-)%)%s*(.*)$")
    if not flag then break end
    remaining = tail
  end
  local itemName = trim(remaining)
  if itemName == "" or not (setLink and selectString) then return end

  -- Same hover technique as parseEquipLine()'s own already-proven one
  -- (selectString()+setLink() on the raw, already-printed line -- "move
  -- text, don't invent it"). Reads ItemLore for a stats suffix if this
  -- exact item's already known from somewhere else (your own identify/
  -- lore captures, or a scrape import); doesn't write anything back --
  -- seeing someone else hold an item tells us nothing about its stats,
  -- only identify/lore on it would, and that's unchanged.
  local rec, resolvedName = MyDSL.resolveItemLoreRecord(itemName)
  local hint = "Click for Item Reference" .. MyDSL.buildItemStatsSuffix(rec)
  local cmd = string.format(
    'if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.render("%s"); MyDSL.ItemReference.show() end',
    resolvedName:gsub('"', '\\"'))
  local okSel, selected = pcall(selectString, "main", itemName, 1)
  if okSel and selected then
    pcall(setLink, "main", cmd, hint)
  end
end


------------------------------------------------------------------------
-- 9q  INVENTORY  ("i"/"inv")
------------------------------------------------------------------------
-- Added 2026-07-16, per Steven ("you should be able to hover over
-- inventory items not just equipment"). Didn't exist at all before this --
-- confirmed via grep. Same begin/body/end shape as equip capture above,
-- fires on "You are carrying:", ends on the first blank line. Each line
-- is "( N) [tags] name" (count prefix omitted, i.e. just leading
-- whitespace, when count is 1) -- confirmed via
-- log/2026-07-16#17-23-54.html.

local inventoryBlock = {}
local inventoryBlankStreak = 0

-- Blank-line handling hardened 2026-07-18 -- same fix and same real
-- reasoning as MyDSL.beginContainerHolds() below (see its comment for the
-- full writeup): a large "you are carrying" listing can paginate exactly
-- like a large container, and a single blank line is not a reliable
-- end-of-listing signal in that case. Preventive hardening -- Steven's
-- own carried inventory in the confirmed real capture was short enough
-- not to paginate, so this specific failure mode isn't directly proven
-- for inventory yet, but the mechanism (and the fix) is identical.
function MyDSL.beginInventory()
  inventoryBlock = {}
  inventoryBlankStreak = 0
  if MyDSL._triggers.inventoryBody then
    pcall(killTrigger, MyDSL._triggers.inventoryBody)
    MyDSL._triggers.inventoryBody = nil
  end
  MyDSL._triggers.inventoryBody = tempRegexTrigger(".*", function()
    local ln = getCurrentLine()
    if trim(ln) == "" then
      inventoryBlankStreak = inventoryBlankStreak + 1
      if inventoryBlankStreak >= 2 then MyDSL.endInventory() end
      return
    end
    inventoryBlankStreak = 0
    if MyDSL.parseInventoryLine then MyDSL.parseInventoryLine(ln) end
  end)
end

function MyDSL.parseInventoryLine(line)
  local count, rest = line:match("^%(%s*(%d+)%)%s+(.+)$")
  if not rest then
    rest = line:match("^%s+(.+)$")
    count = "1"
  end
  if not rest then return end
  local flags = {}
  local remaining = rest
  while true do
    local flag, tail = remaining:match("^%((.-)%)%s*(.*)$")
    if not flag then break end
    flags[#flags + 1] = flag
    remaining = tail
  end
  local itemName = trim(remaining)
  if itemName == "" then return end
  local key = itemName:lower():gsub("^[Aa]n? ", ""):gsub("^[Tt]he ", "")
  inventoryBlock[key] = { item = itemName, flags = flags, count = tonumber(count) or 1 }

  -- Hover/click -- fixed 2026-07-18, real bug found live (Steven: "does
  -- not work on... my direct inventory 'you are carrying'"). This
  -- function's own header comment already claimed hover was added here
  -- 2026-07-16 ("you should be able to hover over inventory items not
  -- just equipment") -- but the actual attach code was never written,
  -- only the parsing/storage half. Same technique as
  -- MyDSL.parseEquipLine()'s already-working item hover.
  if itemName ~= "" and setLink and selectString then
    local rec, resolvedName = MyDSL.resolveItemLoreRecord(itemName)
    local hint = "Click for Item Reference" .. MyDSL.buildItemStatsSuffix(rec)
    local cmd = string.format(
      'if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.render("%s"); MyDSL.ItemReference.show() end',
      resolvedName:gsub('"', '\\"'))
    local okSel, selected = pcall(selectString, "main", itemName, 1)
    if okSel and selected then
      pcall(setLink, "main", cmd, hint)
    end
  end
end

function MyDSL.endInventory()
  if MyDSL._triggers.inventoryBody then
    pcall(killTrigger, MyDSL._triggers.inventoryBody)
    MyDSL._triggers.inventoryBody = nil
  end
  MyDSL.update("inventory", { items = inventoryBlock })
end


------------------------------------------------------------------------
-- 9q.1  CONTAINER HOLDS  ("exam <container>" / "look in <container>")
------------------------------------------------------------------------
-- Added 2026-07-17, per Steven ("item identification should work in
-- donation pits and bins... pattern might be 'holds:'"). Confirmed via
-- corpus grep: every container (donation pits/bins, satchels, bindles,
-- backpacks, thief bags, pockets) prints this exact same shape after
-- `exam <container>` or `look in <container>` -- e.g. "A bin holds:",
-- "The donation pit holds:", "A leather satchel holds:". Anchored on the
-- "holds:" suffix itself, not any specific container name or command,
-- since there's no fixed vocabulary of container names to match against.
--
-- Each contained item line is the same "(N) [tags] name" shape
-- MyDSL.parseInventoryLine() already handles. An older corpus sample
-- (log/2026-07-03..07-07) showed an extra trailing "-[level] flags,stats"
-- suffix (e.g. "an academy diploma -[0] M,MD,4Wis,4Con") -- per Steven,
-- that was injected by an old native trigger that's since been removed,
-- not real DSL server text; confirmed absent from every current-corpus
-- example (log/2026-07-16 onward, e.g. "A Robe of Many Pockets holds:" /
-- "     a Peace Pipe" / "( 3) a tobacco pouch", no suffix on any of them).
-- No stripping needed for real, current output.

local containerBlock = { items = {} }
local containerBlankStreak = 0

-- Fixed 2026-07-18, real bug found live (Steven: "check mydsl log i dont
-- get hover over click on the items in the bin im looking at" -- a fresh
-- raw-text capture of "exam bin" confirmed it): real DSL output for a
-- large container has a BLANK LINE immediately after "<Name> holds:",
-- before the first item ("A bin holds:\n\n     a petrified sand wyrm
-- egg...") -- the original single-blank-line-ends-capture logic (copied
-- from parseInventoryLine()'s shape) killed the capture on that first
-- blank line, before a single item was ever parsed, so NOTHING in a
-- large container ever got a hover. Smaller containers/pouches in the
-- same real capture ("A small, woven pack holds:", "A backpack holds:")
-- have no such leading blank line, and large containers also paginate
-- mid-listing ("[ (C)ontinue, (R)efresh, ... ]:" prompts, each preceded
-- and followed by a single blank line) -- and back-to-back container
-- blocks are separated by 1-3 blank lines. A single blank is genuinely
-- ambiguous in this output; two IN A ROW never occurs mid-listing in the
-- real capture, only between blocks/around the pager, so that's the
-- actual end signal now, not a single blank.
function MyDSL.beginContainerHolds(containerName)
  containerBlock = { container = containerName, items = {} }
  containerBlankStreak = 0
  if MyDSL._triggers.containerBody then
    pcall(killTrigger, MyDSL._triggers.containerBody)
    MyDSL._triggers.containerBody = nil
  end
  MyDSL._triggers.containerBody = tempRegexTrigger(".*", function()
    local ln = getCurrentLine()
    if trim(ln) == "" then
      containerBlankStreak = containerBlankStreak + 1
      if containerBlankStreak >= 2 then MyDSL.endContainerHolds() end
      return
    end
    containerBlankStreak = 0
    if MyDSL.parseContainerHoldsLine then MyDSL.parseContainerHoldsLine(ln) end
  end)
end

function MyDSL.parseContainerHoldsLine(line)
  local count, rest = line:match("^%(%s*(%d+)%)%s+(.+)$")
  if not rest then
    rest = line:match("^%s+(.+)$")
    count = "1"
  end
  if not rest then return end

  local flags = {}
  local remaining = rest
  while true do
    local flag, tail = remaining:match("^%((.-)%)%s*(.*)$")
    if not flag then break end
    flags[#flags + 1] = flag
    remaining = tail
  end

  local itemName = trim(remaining)
  if itemName == "" then return end

  table.insert(containerBlock.items, { item = itemName, flags = flags, count = tonumber(count) or 1 })

  -- Hover/click, same "move text, don't invent it" technique as
  -- MyDSL.parseEquipLine()'s item hover -- attaches to the already-
  -- printed line in the main console, never edits/reprints it.
  if setLink and selectString then
    local rec, resolvedName = MyDSL.resolveItemLoreRecord(itemName)
    local hint = "Click for Item Reference" .. MyDSL.buildItemStatsSuffix(rec)
    local cmd = string.format(
      'if MyDSL and MyDSL.ItemReference then MyDSL.ItemReference.render("%s"); MyDSL.ItemReference.show() end',
      resolvedName:gsub('"', '\\"'))
    local okSel, selected = pcall(selectString, "main", itemName, 1)
    if okSel and selected then
      pcall(setLink, "main", cmd, hint)
    end
  end
end

function MyDSL.endContainerHolds()
  if MyDSL._triggers.containerBody then
    pcall(killTrigger, MyDSL._triggers.containerBody)
    MyDSL._triggers.containerBody = nil
  end
end



------------------------------------------------------------------------
-- Item Lore / Equipment / Inventory / Container triggers
------------------------------------------------------------------------

MyDSL._triggers.equipStart = tempRegexTrigger(
  "^You are using:$",
  function()
    if MyDSL and MyDSL.beginEquip then
      MyDSL.beginEquip()
    end
  end
)

-- "<Name> is using:" -- someone/something else's equipment (see 9p.2
-- above). "^You are using:$" (immediately above) already matches "You"
-- exactly, so this pattern excludes it explicitly to avoid registering
-- a second, redundant body-capture trigger for the exact same block.
MyDSL._triggers.othersEquipStart = tempRegexTrigger(
  "^(.+) is using:$",
  function()
    local name = matches[2]
    if name == "You" then return end
    if MyDSL and MyDSL.beginOthersEquip then
      MyDSL.beginOthersEquip(name)
    end
  end
)

MyDSL._triggers.inventoryStart = tempRegexTrigger(
  "^You are carrying:$",
  function()
    if MyDSL and MyDSL.beginInventory then
      MyDSL.beginInventory()
    end
  end
)

MyDSL._triggers.containerHoldsStart = tempRegexTrigger(
  "^(.+) holds:$",
  function()
    if MyDSL and MyDSL.beginContainerHolds then
      MyDSL.beginContainerHolds(matches[2])
    end
  end
)

-- "search <container>" -- added 2026-07-18, per Steven ("the item
-- reference doest seem to get the search list. 'your search of a bin
-- finds:' can see sample of a scroll of identity in logs"). A real,
-- different command from `exam`/`look in` (confirmed via a fresh log
-- capture: "Your search of a bin finds:\n     a scroll of identify"),
-- with the exact same item-line shape parseContainerHoldsLine() already
-- handles -- routes to the same capture, just a different anchor phrase.
MyDSL._triggers.containerSearchStart = tempRegexTrigger(
  "^Your search of (.+) finds:$",
  function()
    if MyDSL and MyDSL.beginContainerHolds then
      MyDSL.beginContainerHolds(matches[2])
    end
  end
)

------------------------------------------------------------------------
-- Identify / item-lore triggers
------------------------------------------------------------------------
-- Fires on "Object '<name>' is type ..." -- the first line of any
-- `c identify <keyword>` block. Body lines handled by the catch-all
-- installed inside beginIdentify().
MyDSL._triggers.identifyStart = tempRegexTrigger(
  "^Object '",
  function()
    if MyDSL and MyDSL.beginIdentify then
      MyDSL.beginIdentify(getCurrentLine())
    end
  end
)

-- Fires on "You turn a <item> every which way." -- the flavor line every
-- `lore <keyword>` attempt prints regardless of success/fail.
MyDSL._triggers.loreItemStart = tempRegexTrigger(
  "^You turn .+ every which way\\.$",
  function()
    if MyDSL and MyDSL.beginLoreItem then
      MyDSL.beginLoreItem(getCurrentLine())
    end
  end
)
