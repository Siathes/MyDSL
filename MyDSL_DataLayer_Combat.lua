-- =============================================================================
-- MyDSL_DataLayer_Combat.lua  --  Layer 1: Data Collection (Combat capture)
-- =============================================================================
-- Split out of MyDSL_DataLayer.lua 2026-08-25, second slice of the split-
-- by-domain refactor (see docs/TODO.md for the full plan and slice-1
-- writeup). This is the LARGEST domain in the original file (~890 lines
-- combined: parse functions + trigger registration) -- moved only after
-- slice 1 (CreatureLore) proved out the whole mechanism live, and only
-- after confirming via grep that every local/function here is used
-- ONLY within this domain (zero cross-domain references either
-- direction) -- the same clean-boundary check done before moving
-- anything, not assumed safe because it worked for a smaller domain.
--
-- Same contract as before the split: zero display logic, never sends
-- commands to the game. Depends on MyDSL_DataLayer.lua already being
-- loaded (MyDSL.State.combat/MyDSL._triggers/MyDSL._handlers/MyDSL.emit
-- all come from there) -- dofile() order matters, this file must load
-- AFTER it. MyDSL.State.combat's default shape is still declared in
-- MyDSL_DataLayer.lua's own STATE TABLE section, same as every other
-- not-yet-split domain's defaults -- not moved here.
-- =============================================================================

MyDSL = MyDSL or {}

local function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end

------------------------------------------------------------------------
-- 9q  COMBAT
------------------------------------------------------------------------
-- Always-active triggers (no begin/end block — DSL emits combat lines
-- continuously with no header). Round boundary: MyDSL.char.updated (fires
-- on every gmcp.char_data packet, once per combat round).
--
-- Rewritten 2026-07-05 to port DSL_PNP_Battle.lua's actual display/format
-- logic close to verbatim (per Steven: "make it work like PNP, then discuss
-- the additions"), instead of the from-scratch condensed-table format this
-- module invented earlier. What's ported: the dam_info severity/decoration
-- table, battle_format() token substitution, the per-swing live-window
-- echo (raw sentence + severity score, unconditional for non-miss damage),
-- the round-summary aggregation (calc_dam_verb + battle_format, output to
-- MAIN console gated only by summarize_damage -- NOT by gag_combat, matching
-- PNP exactly), and critically the last_attacker/last_target/last_noun
-- technique for weapon-flag proc attribution (replacing our old pseudo-
-- attacker-row workaround with PNP's actual, more correct fix). What's kept
-- as our own addition on top: persistent multi-fight history/snapshots
-- (active[]/history[], PNP has no such concept -- its battle_data resets
-- every single round) and the Poison proc sequence (no PNP equivalent).

-- ---- Severity/decoration ladder (PNP's exact dam_info table) ---------
-- color/suffix/pre/suf/things mirror PNP's dam_info[verb] = {score, color,
-- suffix, pre, suf, ...} exactly, translated from dsl_color names to decho
-- RGB strings. "things" marks the GHASTLY..UNSPEAKABLE tier, which wraps as
-- "does/do <VERB> things to" instead of "<verb>s <target>".
local DAM_LADDER_ORDER = {
  "miss","scratch","graze","hit","injure","wound","maul","decimate","devastate","maim",
  "MUTILATE","DISEMBOWEL","DISMEMBER","MASSACRE","MANGLE",
  "DEMOLISH","DEVASTATE","OBLITERATE","ANNIHILATE","ERADICATE",
  "GHASTLY","HORRID","DREADFUL","HIDEOUS","INDESCRIBABLE","UNSPEAKABLE",
}

-- Colors below are PNP's exact color_table RGB values (DSL_PNP_Support.lua),
-- confirmed 2026-07-11 per Steven's "match PNP for community recognition"
-- request -- our previous values were our own softer/pastel guesses.
local DSL_LT_RED = "255,0,0"
local DSL_WHITE  = "192,192,192"

-- PNP's GHASTLY..UNSPEAKABLE tier bakes a letter-by-letter alternating
-- dsl_lt_red/dsl_white color effect directly into the decorated verb text
-- (DSL_PNP_Battle.lua's dam_info literals, e.g.
-- "<dsl_lt_red>G<dsl_white>H<dsl_lt_red>A..."), not a single flat color --
-- this is the distinctive visual signature real DSL/PNP players recognize.
-- Our previous implementation had no equivalent at all (flat single color).
local function alternateLetters(word, colorA, colorB)
  local out = {}
  for i = 1, #word do
    out[#out + 1] = "<" .. (i % 2 == 1 and colorA or colorB) .. ">" .. word:sub(i, i)
  end
  return table.concat(out)
end

local DAM_INFO = {
  miss          = { score=0,   color="128,128,0", suffix="es", pre=" ",     suf=" " },
  scratch       = { score=2.5, color="0,179,0",   suffix="es", pre=" ",     suf=" " },
  graze         = { score=6.5, color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  hit           = { score=10.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  injure        = { score=14.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  wound         = { score=18.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  maul          = { score=22.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  decimate      = { score=26.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  devastate     = { score=30.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  maim          = { score=34.5,color="0,179,0",   suffix="s",  pre=" ",     suf=" " },
  MUTILATE      = { score=38.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  DISEMBOWEL    = { score=42.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  DISMEMBER     = { score=46.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  MASSACRE      = { score=50.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  MANGLE        = { score=54.5,color="255,255,0", suffix="S",  pre=" ",     suf=" " },
  DEMOLISH      = { score=58.5,color="255,0,0",   suffix="ES", pre=" *** ", suf=" *** " },
  DEVASTATE     = { score=68,  color="255,0,0",   suffix="S",  pre=" *** ", suf=" *** " },
  OBLITERATE    = { score=88,  color="255,0,0",   suffix="S",  pre=" === ", suf=" === " },
  ANNIHILATE    = { score=113, color="255,0,0",   suffix="S",  pre=" >>> ", suf=" <<< " },
  ERADICATE     = { score=138, color="255,0,0",   suffix="S",  pre=" <<< ", suf=" >>> " },
  GHASTLY       = { score=163, color="255,0,0", decorated=alternateLetters("GHASTLY", DSL_LT_RED, DSL_WHITE),             suffix="", pre=" does ", suf=" things to ", things=true },
  HORRID        = { score=188, color="255,0,0", decorated=alternateLetters("HORRID", DSL_LT_RED, DSL_WHITE),              suffix="", pre=" does ", suf=" things to ", things=true },
  DREADFUL      = { score=213, color="255,0,0", decorated=alternateLetters("DREADFUL", DSL_LT_RED, DSL_WHITE),            suffix="", pre=" does ", suf=" things to ", things=true },
  HIDEOUS       = { score=238, color="255,0,0", decorated=alternateLetters("HIDEOUS", DSL_LT_RED, DSL_WHITE),             suffix="", pre=" does ", suf=" things to ", things=true },
  INDESCRIBABLE = { score=263, color="255,0,0", decorated=alternateLetters("INDESCRIBABLE", DSL_LT_RED, DSL_WHITE),       suffix="", pre=" does ", suf=" things to ", things=true },
  UNSPEAKABLE   = { score=276, color="255,0,0", decorated=alternateLetters("UNSPEAKABLE", DSL_LT_RED, DSL_WHITE),         suffix="", pre=" does ", suf=" things to ", things=true },
}

local SEVERITY_SCORE = {}
for word, info in pairs(DAM_INFO) do SEVERITY_SCORE[word] = info.score end

-- Weapon-flag color map (PNP's flag_info table, PNP's exact color_table RGB
-- values as of 2026-07-11). P (Poison) has no PNP equivalent since Poison is
-- our own addition; kept our existing purple.
local FLAG_COLOR = {
  L = "255,255,0", F = "255,0,0", C = "0,255,255",   H = "255,0,255",
  M = "0,0,255",   S = "0,179,0", U = "128,128,128", O = "192,192,192",
  P = "170,68,204",
}

-- ---- battle_format() equivalent (PNP's token-substitution formatter) ----
-- Tokens: %a attacker %t target %n noun %v verb %d damage %h hits %s swings
-- %f flags %r possessive %p punctuation. fields is a table with keys
-- a/t/n/v/d/h/s/f/r/p (any subset; missing ones substitute empty string).
local function battleFormat(fmt, f)
  local subs = {
    ["%%a"] = trim(f.a or ""),            ["%%t"] = trim(f.t or ""),
    ["%%n"] = trim(f.n or ""),             ["%%v"] = trim(f.v or ""),
    ["%%f"] = trim(f.f or ""),             ["%%d"] = trim(tostring(f.d or "")),
    ["%%h"] = trim(tostring(f.h or "")),   ["%%s"] = trim(tostring(f.s or "")),
    ["%%r"] = trim(f.r or ""),             ["%%p"] = trim(f.p or ""),
  }
  for pat, val in pairs(subs) do fmt = fmt:gsub(pat, val) end
  return (fmt:gsub("  ", " "))
end

-- ---- calc_dam_verb() equivalent (round-summary aggregate verb) ----
-- Finds the highest severity tier whose score is <= totalScore, decorated
-- exactly like PNP: the "does"->"do" swap only applies to the You-only
-- special case, and the plural suffix is dropped entirely for You (this is
-- a DIFFERENT, simpler pluralization rule than the per-swing one below --
-- ported as its own thing, matching PNP's two genuinely distinct rules).
local function calcDamVerb(totalScore, isYou)
  local bestScore, bestWord = nil, "miss"
  for _, word in ipairs(DAM_LADDER_ORDER) do
    local info = DAM_INFO[word]
    if info.score <= totalScore and (not bestScore or info.score >= bestScore) then
      bestScore, bestWord = info.score, word
    end
  end
  local info   = DAM_INFO[bestWord]
  local pre    = (isYou and info.pre == " does ") and " do " or info.pre
  local suffix = isYou and "" or info.suffix
  local decoratedWord = info.decorated or ("<" .. info.color .. ">" .. bestWord)
  return trim(pre .. decoratedWord .. suffix .. "<r>" .. info.suf)
end

-- ---- Condition ladder -----------------------------------------------
-- Self-phrased ("You are"/"You have"/"You look") entries added 2026-07-09
-- -- confirmed real bug, TOP PRIORITY item: DSL phrases your OWN condition
-- in second person, a different verb conjugation from the third-person
-- form ("has"->"have", "is"->"are", "looks"->"look"), so neither our old
-- pattern list nor PNP's ever matched it -- self-condition silently never
-- registered. Corpus-confirmed for 3 of 7 rungs ("You are in excellent
-- condition.", "You have a few scratches.", "You have some big nasty
-- wounds and scratches." -- the third one only via its clean third-person
-- form; the self-phrased instances found in the corpus had a garbled
-- "nasty's...And...(18.5)" suffix that turned out to be OUR OWN severity-
-- score decorator leaking into the log, not raw DSL text, so matched on
-- the clean prefix instead of that artifact). The other 4 rungs have no
-- direct self-phrased corpus example (Steven/his characters haven't
-- logged taking that much damage yet) -- inferred via the same
-- consistent grammatical transformation, confirmed consistent across
-- every rung that DOES have direct evidence.
local CONDITION_PATTERNS = {
  { pat = " is in excellent condition",       label = "excellent"    },
  { pat = " are in excellent condition",      label = "excellent"    },
  { pat = " has a few scratches",             label = "few scratches" },
  { pat = " have a few scratches",            label = "few scratches" },
  { pat = " has some small wounds",           label = "small wounds"  },
  { pat = " have some small wounds",          label = "small wounds"  },
  { pat = " has some big nasty wounds",       label = "big wounds"    },
  { pat = " have some big nasty wounds",      label = "big wounds"    },
  { pat = " has quite a few wounds",          label = "quite a few"   },
  { pat = " have quite a few wounds",         label = "quite a few"   },
  { pat = " looks pretty hurt",               label = "pretty hurt"   },
  { pat = " look pretty hurt",                label = "pretty hurt"   },
  { pat = " is in awful condition",           label = "awful"         },
  { pat = " are in awful condition",          label = "awful"         },
}
-- PNP's condition_info percentage-range strings, keyed by our own label
-- (same content, just reordered by label instead of by pattern text).
local CONDITION_PERCENT = {
  excellent = "100%", ["few scratches"] = "90-99%", ["small wounds"] = "75-89%",
  ["big wounds"] = "30-49%", ["quite a few"] = "50-74%",
  ["pretty hurt"] = "15-29%", awful = "0-14%",
}

-- ---- Scope + key helpers --------------------------------------------
local function normalizeKey(name)
  if not name then return "" end
  local s = trim(name:lower())
  s = s:gsub("^a%s+", ""):gsub("^an%s+", ""):gsub("^the%s+", "")
  return trim(s)
end


local function ensureActive(tKey, tDisplay)
  if not MyDSL.State.combat.active[tKey] then
    MyDSL.State.combat.active[tKey] = {
      target_display   = tDisplay or tKey,
      target_condition = "unknown",
      by_attacker      = {},
      started_at       = os.time(),
    }
  end
  return MyDSL.State.combat.active[tKey]
end

-- Ordering for a numeric bar-fill estimate (7=full health, 1=near death) --
-- added 2026-07-11 for the Focus/Target window's health bar ("should have
-- healthbars that work on the enemies health message"), same 7 tiers as
-- CONDITION_PATTERNS/CONDITION_PERCENT above.
local CONDITION_ORDER = {
  excellent = 7, ["few scratches"] = 6, ["small wounds"] = 5,
  ["quite a few"] = 4, ["big wounds"] = 3, ["pretty hurt"] = 2, awful = 1,
}

-- MyDSL.getTargetCondition(name) -- public read-only API, same shape as
-- MyDSL.Affects.getRemaining(): returns nil if no live combat-condition
-- data exists for this name (never fought this session, or DSL hasn't
-- sent a condition line yet), otherwise (label, percentRangeText, order).
-- This is the REAL "enemy health message" data Steven asked for -- not
-- creaturelore's static "base health" stat, which is a fixed per-species
-- number, not the current fight's damage state.
function MyDSL.getTargetCondition(name)
  local key = normalizeKey(name)
  local entry = MyDSL.State.combat and MyDSL.State.combat.active and MyDSL.State.combat.active[key]
  if not entry or not entry.target_condition or entry.target_condition == "unknown" then
    return nil
  end
  local label = entry.target_condition
  return label, CONDITION_PERCENT[label], CONDITION_ORDER[label]
end

local function snapshotFight(tKey)
  local entry = MyDSL.State.combat.active[tKey]
  if not entry then return nil end
  local hist = MyDSL.State.combat.history
  table.insert(hist, 1, entry)
  while #hist > MyDSL.State.combat.history_max do table.remove(hist) end
  MyDSL.State.combat.active[tKey] = nil
  return entry
end

-- ---- parseCombatDamageLine (PNP's handle_damage(), close to verbatim) ----
local FALSE_POSITIVE_GUARDS = {"You gain", "has big nasty", "Affects", "has some small", "Wimpy"}
local NOUN_FLAG_MAP = { ["life drain"] = "H", ["shocking bite"] = "L" }  -- our own addition, kept

function MyDSL.parseCombatDamageLine(attacker, noun, verb, target, punct)
  -- PNP's false-positive guard
  local combined = (attacker or "") .. " " .. (noun or "")
  for _, g in ipairs(FALSE_POSITIVE_GUARDS) do
    if combined:find(g, 1, true) then return end
  end

  attacker = trim(attacker or "")
  noun     = trim(noun     or "")
  verb     = trim(verb     or "")
  target   = trim(target   or "")
  punct    = punct or "."

  local info = DAM_INFO[verb]
  if not info then return end

  local aKey = (attacker == "You" or attacker:lower() == "you") and "you" or normalizeKey(attacker)
  local tKey = (target:lower() == "you") and "you" or normalizeKey(target)
  -- No relevance filter, matching PNP: every combat line DSL shows you gets
  -- tracked, relying on DSL's own vicinity-based broadcast rules rather
  -- than filtering client-side (confirmed 2026-07-05).

  -- ---- Per-swing decorated verb (PNP's handle_damage construction) ----
  -- Pluralization here keys off whether a weapon noun is present at all
  -- (true for every normal hit; the "does...things to" tier has no noun,
  -- but its own suffix is always "" anyway) -- this is a different,
  -- simpler rule than calc_dam_verb's You-based one below, ported as its
  -- own thing to match PNP's actual (slightly redundant) two rules.
  local damVerb = info.decorated or ("<" .. info.color .. ">" .. verb)
  if attacker ~= "You" or noun ~= "" then damVerb = damVerb .. info.suffix end
  damVerb = info.pre .. damVerb .. "<r>" .. info.suf

  local possessive, displayNoun = "", noun
  if noun ~= "" then
    displayNoun = " " .. noun
    possessive = (attacker == "You") and "r" or "'s"
  end

  -- Live Combat-window echo -- every non-miss swing, unconditional, raw
  -- sentence + severity score in brackets. Matches PNP's battle_console
  -- cecho exactly: misses/evasion/procs never appear here at all, only
  -- real damage.
  if verb ~= "miss" then
    -- No separator between damVerb and target -- damVerb's own trailing
    -- info.suf (e.g. " " or " *** ") already provides the space, matching
    -- PNP's exact concatenation (adding one here would double it).
    local swingLine = " " .. attacker .. possessive .. displayNoun .. damVerb .. target .. punct .. " [" .. info.score .. "]\n"
    if MyDSL.CombatView and MyDSL.CombatView.appendSwing then
      MyDSL.CombatView.appendSwing(swingLine)
    end
  end

  -- ---- Main-console gag/show decision (PNP's exact boolean formula) ----
  local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}
  local showDamage = (cfg.show_miss or verb ~= "miss")
    and (cfg.show_damage or (cfg.show_damage_by_me and aKey == "you") or (cfg.show_damage_to_me and tKey == "you"))
  if showDamage then
    local str = battleFormat(cfg.dam_format or "%a%r %n %v %t (%d)", {
      a = attacker, r = possessive, n = noun, v = damVerb, t = target, d = info.score, p = punct,
    })
    selectCurrentLine()
    replace("")
    decho(str)
  elseif noun ~= "trip" and noun ~= "kicked dirt" then
    deleteLine()
  end

  -- ---- Accumulation ----
  -- round_data: PNP's battle_data equivalent, reset every round.
  -- active[]: our own persistent-fight-history addition, layered on top --
  -- PNP has no concept of "this fight, start to finish" at all.
  local nounKey = noun:lower()
  local score = info.score

  local entry = ensureActive(tKey, target)
  local ba    = entry.by_attacker
  ba[aKey]        = ba[aKey]        or {}
  ba[aKey][nounKey] = ba[aKey][nounKey] or { swings=0, hits=0, misses=0, score_total=0, flags={} }
  local nd = ba[aKey][nounKey]
  nd.swings = nd.swings + 1
  if verb == "miss" then
    nd.misses = nd.misses + 1
  else
    nd.hits        = nd.hits + 1
    nd.score_total = nd.score_total + score
  end

  -- Compound-noun proc flags (our own addition, kept from the earlier fix).
  local impliedFlag = NOUN_FLAG_MAP[nounKey]
  if impliedFlag and verb ~= "miss" then
    nd.flags[impliedFlag] = (nd.flags[impliedFlag] or 0) + 1
    if impliedFlag == "H" and aKey == "you" then
      MyDSL.State.combat.rage.vamp = MyDSL.State.combat.rage.vamp + 2.5
    end
  end

  local rd    = MyDSL.State.combat.round_data
  local rdKey = aKey .. "→" .. tKey .. "→" .. nounKey
  rd[rdKey] = rd[rdKey] or { attacker=aKey, target=tKey, noun=nounKey, score=0, swings=0, hits=0 }
  rd[rdKey].score  = rd[rdKey].score + score
  rd[rdKey].swings = rd[rdKey].swings + 1
  if verb ~= "miss" then rd[rdKey].hits = rd[rdKey].hits + 1 end

  -- PNP's last_attacker/last_target/last_noun technique: weapon-flag procs
  -- (parseCombatProcLine below) attach to whichever combatant/noun this
  -- damage line involved, instead of trying to resolve identity from the
  -- proc line's own (often weapon-named) text.
  MyDSL.State.combat.last_attacker = aKey
  MyDSL.State.combat.last_target   = tKey
  MyDSL.State.combat.last_noun     = nounKey

  if tKey == "you" then
    MyDSL.State.combat.rage.damage = MyDSL.State.combat.rage.damage + score
  end
end

-- ---- parseCombatAvoidLine (PNP's handle_evasion(), close to verbatim) ----
-- Two call shapes:
--   (evader, verb, attacker) -- dodge/parry/block triggers, PNP-derived PCRE
--     capture groups. attacker is the literal word "your" when you're the
--     one whose attack got avoided, otherwise a "Name's" possessive.
--   (line)                   -- sense triggers, still whole-line Lua-pattern
--     parsed (unchanged; not part of the PNP evasion-trigger port).
-- Note: evasion never appears in the Combat window at all, matching PNP --
-- handle_evasion never touches battle_console, only the main-console gag.
function MyDSL.parseCombatAvoidLine(evader, verb, attacker)
  if not attacker then
    local line = evader
    evader, attacker = line:match("^(.+) senses (.+)'s attack coming and avoids")
    if not evader then evader = line:match("^(.+) senses they'?re about to be hit") end
    if not evader then return end
  end

  evader = trim(evader)
  local eKey = normalizeKey(evader)
  local aKey
  if attacker and attacker:lower() == "your" then
    aKey = "you"
  elseif attacker then
    aKey = normalizeKey(trim(attacker):gsub("'s$", ""))
  else
    aKey = "unknown"
  end
  -- No relevance filter, matching PNP.

  local entry = ensureActive(eKey, evader)
  entry.by_attacker[aKey] = entry.by_attacker[aKey] or {}
  entry.by_attacker[aKey]["(evade)"] = entry.by_attacker[aKey]["(evade)"]
    or { swings=0, hits=0, misses=0, score_total=0, flags={} }
  entry.by_attacker[aKey]["(evade)"].swings = entry.by_attacker[aKey]["(evade)"].swings + 1

  local rd    = MyDSL.State.combat.round_data
  local rdKey = aKey .. "→" .. eKey .. "→(evade)"
  rd[rdKey] = rd[rdKey] or { attacker=aKey, target=eKey, noun="(evade)", score=0, swings=0, hits=0 }
  rd[rdKey].swings = rd[rdKey].swings + 1

  -- Gag decision (PNP's exact formula).
  local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}
  if (cfg.gag_combat or cfg.gag_non_damage or not cfg.show_evade) then deleteLine() end
end

-- ---- parseCombatConditionLine (PNP's handle_condition(), close to verbatim) ----
function MyDSL.parseCombatConditionLine(line)
  local name, label
  for _, c in ipairs(CONDITION_PATTERNS) do
    local idx = line:find(c.pat, 1, true)
    if idx and idx > 1 then
      name  = trim(line:sub(1, idx - 1))
      label = c.label
      break
    end
  end
  if not name or not label then return end

  local tKey = normalizeKey(name)
  local entry = MyDSL.State.combat.active[tKey]
  if entry then entry.target_condition = label end  -- our own per-target addition

  -- PNP's battle_data.screen_condition/window_condition equivalent -- a
  -- single pending note, flushed alongside the next round summary.
  -- "has" inserted 2026-07-16, per Steven ("missing the word 'has'
  -- between mob name and state") -- confirmed live via log/*.html:
  -- "A gray wolf cub big wounds [30-49%]" read with no connecting verb
  -- at all between name and label.
  local pct = CONDITION_PERCENT[label] or ""
  MyDSL.State.combat.pending_condition = {
    screen = "<255,68,255>" .. name .. "<r> has " .. label .. (pct ~= "" and (" [" .. pct .. "]") or ""),
    window = "<255,68,68>" .. name .. "<r> [" .. pct .. "]\n",
  }

  -- Gag decision -- was PNP's exact formula (`(not show_condition) and
  -- ((gag_combat or gag_non_damage) and (not summarize_damage))`), which
  -- never deletes the raw line in condensed mode (summarize_damage=true)
  -- specifically because the round-flush handler below is about to decho
  -- its own colored copy of the same condition info -- confirmed this is
  -- PNP's own original behavior too (DSL_PNP_Battle.lua, identical
  -- formula), not a MyDSL-introduced bug, but Steven reported it live as
  -- an unwanted duplicate ("one we create and one from the game... if
  -- its just a duplicate line lets not duplicate it") and asked for it
  -- fixed here specifically, diverging from PNP on this one point.
  -- Fixed 2026-07-16: added summarize_damage to the OR clause, so the raw
  -- line is now deleted in condensed mode too (only our own recap shows).
  -- Raw mode is unaffected (gag_combat/gag_non_damage/summarize_damage
  -- all false there, so this stays false and nothing is deleted -- the
  -- one real condition line shows, same as always). show_condition still
  -- overrides everything and forces the raw line to stay, per its own
  -- documented purpose.
  local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}
  if (not cfg.show_condition) and (cfg.gag_combat or cfg.gag_non_damage or cfg.summarize_damage) then
    deleteLine()
  end
end

-- ---- parseCombatDeathLine -------------------------------------------
function MyDSL.parseCombatDeathLine(line)
  -- Two confirmed death-message forms (DSL-Logs, 2026-07-05 audit):
  -- "<mob> is DEAD!!" (room/kill broadcast) and "<mob> hits the ground ...
  -- DEAD." (the killing-blow line, seen exclusively in some sessions with
  -- zero "is DEAD!!" anywhere). Both fire for the same kill in some logs,
  -- only one in others -- treat identically. snapshotFight() already
  -- returns nil and no-ops if the target was already cleared, so if both
  -- somehow fire for the same death this doesn't double-snapshot.
  local name = line:match("^(.+) is DEAD!!$")
  if not name then name = line:match("^(.+) hits the ground %.%.%. DEAD%.$") end
  if not name then return end
  local tKey   = normalizeKey(trim(name))
  local snap   = snapshotFight(tKey)
  if snap then raiseEvent("MyDSL.combat.ended", snap) end
  -- Dedicated death event -- added 2026-07-11, per Steven ("then clear
  -- target, or populate with next in room mob from scan" once the
  -- current Focus target dies). Raised independent of whether
  -- snapshotFight() found an active-combat entry -- our own damage
  -- tracking might never have started for this specific kill (e.g.
  -- someone else landed the killing blow), but the creature still died.
  -- Any module that cares about "did THIS specific creature just die"
  -- needs the raw key/name, not the aggregated fight-history snapshot
  -- MyDSL.combat.ended carries -- that event also fires for flee/rescue,
  -- not just death, so it can't distinguish the two.
  raiseEvent("MyDSL.combat.died", { key = tKey, name = trim(name) })
end

-- ---- parseCombatEndLine ---------------------------------------------
function MyDSL.parseCombatEndLine(line)
  -- Escape fail: no state change
  if line:match("^You cannot escape from combat") then return end

  -- You flee
  if line:match("^You flee from combat!") then
    -- Clear the first active entry where you are attacker
    for tKey, entry in pairs(MyDSL.State.combat.active) do
      if entry.by_attacker and entry.by_attacker["you"] then
        local snap = snapshotFight(tKey)
        if snap then raiseEvent("MyDSL.combat.ended", snap) end
        return
      end
    end
    return
  end

  -- Rescued out: "<name> rescues you!"
  if line:match("rescues you!$") then
    for tKey, _ in pairs(MyDSL.State.combat.active) do
      local snap = snapshotFight(tKey)
      if snap then raiseEvent("MyDSL.combat.ended", snap) end
      return  -- clear only first (most recent) active fight
    end
    return
  end

  -- A mob or pet flees: "<name> has fled!"
  local fled = line:match("^(.+) has fled!$")
  if fled then
    local tKey = normalizeKey(trim(fled))
    local snap = snapshotFight(tKey)
    if snap then raiseEvent("MyDSL.combat.ended", snap) end
  end
end

-- ---- parseCombatProcLine (PNP's handle_flag(), close to verbatim) ----
-- flagCode: C=Frost F=Flaming L=Shocking H=Vampiric S=Stunning M=ManaDrain O=Holy U=Unholy P=Poison
--
-- Rewritten 2026-07-05 to use PNP's actual technique: don't try to resolve
-- identity from the proc line's own text (frequently a weapon name, not a
-- person -- e.g. "A grand arcanium hoopak draws life from <Name>.") -- just
-- attach to whichever attacker/target/noun the most recent damage line
-- involved (MyDSL.State.combat.last_attacker/last_target/last_noun, set at
-- the end of parseCombatDamageLine). This replaces the old pseudo-
-- attacker-row workaround entirely with PNP's actual, more correct fix --
-- confirmed in DSL_PNP_Battle.lua's handle_flag(), which does exactly this.
function MyDSL.parseCombatProcLine(flagCode)
  -- PNP's drowning/freeze false-positive guard.
  if flagCode == "C" and getCurrentLine() == "The panic of drowning freezes you in your tracks!" then
    return
  end

  local combat = MyDSL.State.combat
  local aKey, tKey, noun = combat.last_attacker, combat.last_target, combat.last_noun
  if not (aKey and tKey and noun) then return end

  if flagCode == "H" and aKey == "you" then
    combat.rage.vamp = combat.rage.vamp + 2.5
  end

  local entry = combat.active[tKey]
  if entry then
    local nd = entry.by_attacker[aKey] and entry.by_attacker[aKey][noun]
    if nd then nd.flags[flagCode] = (nd.flags[flagCode] or 0) + 1 end
  end

  local rdEntry = combat.round_data[aKey .. "→" .. tKey .. "→" .. noun]
  if rdEntry then
    rdEntry.flags = rdEntry.flags or {}
    rdEntry.flags[flagCode] = (rdEntry.flags[flagCode] or 0) + 1
  end

  -- Gag decision (PNP's exact formula) -- Stunning (S) is special-cased to
  -- always show regardless of show_flag, matching PNP exactly.
  local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}
  if (cfg.gag_combat or cfg.gag_non_damage or not cfg.show_flag) and flagCode ~= "S" then
    deleteLine()
  end
end




------------------------------------------------------------------------
-- Trigger registration above moved here with its functions rather than
-- left in MyDSL_DataLayer.lua's own trigger-registration section, same
-- precedent as MyDSL_DataLayer_CreatureLore.lua (slice 1) -- this file
-- is a complete, self-contained module.
------------------------------------------------------------------------

------------------------------------------------------------------------
-- Combat triggers (always-active — no begin/end block)
------------------------------------------------------------------------
-- Gag/show decisions for damage/evasion/condition/proc all moved INTO
-- their respective parse functions as of 2026-07-05 (matching PNP, where
-- handle_damage/handle_evasion/handle_condition/handle_flag each make
-- their own gag decision) -- trigger bodies below just call the parser.

-- ---- Unified damage trigger (PNP-derived PCRE, one trigger for all damage types)
-- Deliberately `^`-anchored directly to the attacker name, NOT tolerant of
-- a leading "[ The Center of the Coliseum ]"/"[ Southern Coliseum Wall ]"
-- location-broadcast prefix. This was briefly "fixed" 2026-07-09 to accept
-- that prefix (real, confirmed via sibling-profile logs -- every combat
-- line fought in the Coliseum carries one), but reverted same-day per
-- Steven: Coliseum combat (and the Algoron Combat League event) is
-- explicitly OUT of scope for this regular single-target combat tracker --
-- it's planned as its own later module (a large window with 4 floating
-- cardinal-direction sub-windows matching the Coliseum's wall echoes).
-- The strict anchor is what naturally excludes Coliseum broadcasts from
-- this tracker today, so it stays as-is on purpose -- don't "fix" this
-- again without building/coordinating with that module first.
local DAMAGE_VERBS = "miss|scratch|graze|hit|injure|wound|maul|decimate|devastate|maim|MUTILATE|DISEMBOWEL|DISMEMBER|MASSACRE|MANGLE|DEMOLISH|DEVASTATE|OBLITERATE|ANNIHILATE|ERADICATE|GHASTLY|HORRID|DREADFUL|HIDEOUS|INDESCRIBABLE|UNSPEAKABLE"
-- REAL BUG, found live 2026-07-20 (Steven, via the actual Olyndros
-- session log, flagged as "combat remains in the main window, the
-- readicates and others should be going to combat with the condenser"):
-- this trigger's own final group used to require the line to end in one
-- or more literal "."/"!" characters -- but DSL's real current combat
-- text always ends with a parenthesized (possibly decimal) damage
-- number instead, e.g. "Your wrath do UNSPEAKABLE things to Tinker
-- gnome janitor (340)", "Beautiful white charger's bite wounds Tinker
-- gnome janitor (14.5)", "Tinker gnome janitor's misses You (0)" --
-- confirmed via direct regex testing against the real captured corpus:
-- every single one of these failed to match at all under the old
-- pattern (only a line with a literal trailing "." or "!", e.g. the
-- "<<< ERADICATES >>> ...!" charge-skill form, ever matched). Since
-- nothing matched, parseCombatDamageLine() never ran for ordinary
-- swings -- no round-data accumulation, no Combat-window condenser
-- summary, no gagging -- so every real swing just printed raw and
-- untracked to the main console, exactly matching the reported symptom.
-- Fixed: the target-name capture is now non-greedy and the final group
-- accepts EITHER a parenthesized number OR the old literal punctuation,
-- so both the current live format and any older/other-verb literal-
-- punctuation form still match. `parseCombatDamageLine()`'s own `punct`
-- parameter only ever gets used as cosmetic trailing decoration on the
-- raw per-swing display line -- the actual severity score shown always
-- comes from a fixed per-verb DAM_INFO[verb].score lookup, not parsed
-- from this text -- so passing a "(340)"-shaped punct through is safe,
-- nothing depends on it being exactly "."/"!".
-- REAL BUG, found live 2026-07-25 (Steven, via a real Olyndros leveling
-- session): even after the 2026-07-20 fix above (matching the "(340)"
-- damage-number ending), Steven's own note says "damage still appearing
-- in main window and not being moved to combat" -- and the log confirms
-- it: every single swing this session printed completely raw, verbatim
-- game text with real, varying damage numbers (297, 167.5, 173...), which
-- only happens if this trigger NEVER matched at all (parseCombatDamageLine
-- always replaces the line with a fixed per-verb DAM_INFO score, never
-- the raw number -- seeing the raw number means the trigger flat-out
-- didn't fire). Independently re-verified the fixed regex against the
-- exact real corpus line via BOTH Python's re AND real PCRE (perl) --
-- both match correctly and extract the right groups, so the pattern
-- logic itself is sound. The remaining, well-precedented suspect in this
-- exact file's own history (the "[Exits: " leading-space bug 2026-07-08,
-- the indented-landmark-line anchor bug 2026-07-09) is invisible leading/
-- trailing whitespace in DSL's REAL raw line that a plain-text HTML log
-- capture doesn't visibly show. Hardened both anchors to tolerate it --
-- cheap and safe regardless of whether this turns out to be the actual
-- cause; if swings still don't route after this, the next real step is
-- a live debug trace (this file's own established last-resort technique,
-- see the "[Exits: " self-retrigger fix's history) since static analysis
-- has been exhausted here.
MyDSL._triggers.combatDamage = tempRegexTrigger(
  "^\\s*(You|[\\w\\-\\s,']+?)(?:(?<=You)r|'s)?(?:\\s?((?<=Your )[\\w\\s]+?|(?<='s )[\\w\\s]+?|))(?: do[es]*| [\\>\\<\\=\\*]+|) ("
    .. DAMAGE_VERBS .. ")[esES]*(?: things to| [\\>\\<\\=\\*]+|) ([\\w\\-\\s,']+?)\\s*(\\([\\d\\.]+\\)|[\\.\\.!]+)\\s*$",
  function()
    if MyDSL and MyDSL.parseCombatDamageLine then
      MyDSL.parseCombatDamageLine(matches[2], matches[3], matches[4], matches[5], matches[6])
    end
  end
)

-- ---- Avoidance triggers
-- Dodge/parry/block patterns are a direct port of DSL_PNP_Battle.lua's
-- tested trigger text (make_triggers(), the {dodge/parry/block/sense}
-- table) -- PNP already solved the you-as-subject vs third-party grammar
-- split: the (your|[\w\-\,\s']+) alternation matches "your" as a literal
-- alternative, while the same char class lets the non-"your" branch swallow
-- a possessive like "a gnome greaser's" whole (the embedded "'" keeps the
-- trailing 's inside the captured name instead of breaking the match).
MyDSL._triggers.combatDodge = tempRegexTrigger(
  "(You|[\\w\\-\\,\\s']+) (dodge)s? (your|[\\w\\-\\,\\s']+) attack\\.$",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end end)
MyDSL._triggers.combatParry = tempRegexTrigger(
  "(You|[\\w\\-\\,\\s']+) (parry|parries) (your|[\\w\\-\\,\\s']+) attack\\.$",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end end)
MyDSL._triggers.combatBlock = tempRegexTrigger(
  "(You|[\\w\\-\\,\\s']+) (block)[s]? (your|[\\w\\-\\,\\s']+) attack .*\\.$",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(matches[2], matches[3], matches[4]) end end)
MyDSL._triggers.combatSense1 = tempRegexTrigger(
  "^[\\w\\-\\s,']+ senses they.?re about to be hit and deflects the blow\\.",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(getCurrentLine()) end end)
MyDSL._triggers.combatSense2 = tempRegexTrigger(
  "^[\\w\\-\\s,']+ senses [\\w\\-\\s,']+'s attack coming and avoids its blow\\.",
  function() if MyDSL and MyDSL.parseCombatAvoidLine then MyDSL.parseCombatAvoidLine(getCurrentLine()) end end)

-- ---- Condition trigger (excludes DEAD — handled by combatDead below)
-- Self-phrased alternatives added 2026-07-09 -- see CONDITION_PATTERNS'
-- header comment above for the confirmed self-condition bug and evidence.
MyDSL._triggers.combatCondition = tempRegexTrigger(
  "(?:is in excellent condition|are in excellent condition|has a few scratches|have a few scratches|has some small wounds|have some small wounds|has some big nasty wounds|have some big nasty wounds|has quite a few wounds|have quite a few wounds|looks pretty hurt|look pretty hurt|is in awful condition|are in awful condition)",
  function() if MyDSL and MyDSL.parseCombatConditionLine then MyDSL.parseCombatConditionLine(getCurrentLine()) end end)

-- ---- Death trigger (no PNP equivalent for the second form -- own addition)
MyDSL._triggers.combatDead = tempRegexTrigger(
  " is DEAD!!$",
  function()
    if MyDSL and MyDSL.parseCombatDeathLine then MyDSL.parseCombatDeathLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)
MyDSL._triggers.combatDeadGroundHit = tempRegexTrigger(
  " hits the ground \\.\\.\\. DEAD\\.$",
  function()
    if MyDSL and MyDSL.parseCombatDeathLine then MyDSL.parseCombatDeathLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)

-- ---- Flee / rescue / escape-fail triggers
MyDSL._triggers.combatFlee = tempRegexTrigger(
  "^You flee from combat!$",
  function() if MyDSL and MyDSL.parseCombatEndLine then MyDSL.parseCombatEndLine(getCurrentLine()) end
    if MyDSL and MyDSL.CombatView and MyDSL.CombatView.config and MyDSL.CombatView.config.gag_combat then deleteLine() end
  end)
MyDSL._triggers.combatEscapeFail = tempRegexTrigger(
  "^You cannot escape from combat!!!$",
  function() if MyDSL and MyDSL.parseCombatEndLine then MyDSL.parseCombatEndLine(getCurrentLine()) end end)
MyDSL._triggers.combatRescued = tempRegexTrigger(
  "rescues you!$",
  function() if MyDSL and MyDSL.parseCombatEndLine then MyDSL.parseCombatEndLine(getCurrentLine()) end end)
MyDSL._triggers.combatTargetFled = tempRegexTrigger(
  "^[\\w\\-\\s,']+ has fled!$",
  function() if MyDSL and MyDSL.parseCombatEndLine then MyDSL.parseCombatEndLine(getCurrentLine()) end end)

-- ---- Weapon-flag proc triggers ----
-- Simplified 2026-07-05: no longer resolve attacker/target keys from each
-- trigger's own capture groups (parseCombatProcLine now uses PNP's
-- last_attacker/last_target/last_noun technique instead -- see 9q above).
-- The quote-inclusive character classes stay in the regex patterns
-- (Frost/Vampiric/Stunning) since they're still needed to MATCH lines with
-- quoted weapon names ("Nadrik's Honor") -- just no longer used to extract
-- a key from the match.

-- C: Frost
MyDSL._triggers.procFrostFreeze = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) freezes ([\\w\\-\\s,'\"]+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("C") end end)
MyDSL._triggers.procFrostTouch = tempRegexTrigger(
  "^The cold touch of ([\\w\\-\\s,']+) surrounds you with ice",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("C") end end)

-- F: Flaming
MyDSL._triggers.procFlameBurn = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is burned by ([\\w\\-\\s,']+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("F") end end)
MyDSL._triggers.procFlameSear = tempRegexTrigger(
  "^([\\w\\-\\s,']+) sears your flesh",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("F") end end)

-- L: Shocking
MyDSL._triggers.procShockLightning = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is struck by lightning from ([\\w\\-\\s,']+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("L") end end)
MyDSL._triggers.procShockShocked = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is shocked by a",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("L") end end)

-- H: Vampiric
MyDSL._triggers.procVampDraw = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) draws life from ([\\w\\-\\s,'\"]+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("H") end end)
MyDSL._triggers.procVampDrain = tempRegexTrigger(
  "^You feel ([\\w\\-\\s,']+) drawing your life away",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("H") end end)

-- S: Stunning
MyDSL._triggers.procStun = tempRegexTrigger(
  "^([\\w\\-\\s,'\"]+) is knocked to the ground by ([\\w\\-\\s,'\"]+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("S") end end)

-- M: Mana drain
MyDSL._triggers.procManaSelf = tempRegexTrigger(
  "^You feel something drawing your energy away",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("M") end end)
MyDSL._triggers.procManaDraw = tempRegexTrigger(
  "^([\\w\\-\\s,']+) draws energy from ([\\w\\-\\s,']+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("M") end end)

-- O: Holy
MyDSL._triggers.procHolyWrath = tempRegexTrigger(
  "^You feel a surge of ([\\w\\-\\s,']+)'s holy wrath race through your body",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("O") end end)
MyDSL._triggers.procHolyFlash = tempRegexTrigger(
  "^A flash of holy power erupts from ([\\w\\-\\s,']+) and hits ([\\w\\-\\s,']+)!$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("O") end end)

-- U: Unholy
MyDSL._triggers.procUnholy = tempRegexTrigger(
  "^You feel a surge of ([\\w\\-\\s,']+)'s unholy wrath race through your body",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("U") end end)

-- Sharp: confirmed via Steven 2026-07-09 (from a Discord question) --
-- the Sharp weapon flag just adds bonus damage and never echoes anything
-- at all, so there's no trigger text to write, ever. Not a gap, working
-- as intended -- no action needed.
-- Vorpal: confirmed non-functional (produces no echo) — deliberately omitted

-- P: Poison (our own confirmed addition; no PNP equivalent)
-- procPoisonOnset/procPoisonTick both confirmed real via sibling-profile
-- logs 2026-07-09 (DSL1/log/2026-06-26#17-54-43.html), both seen with a
-- Coliseum location-broadcast prefix ("[ The Center of the Coliseum ]
-- Rylae is poisoned by the venom on a flail of eels.", "[ Southern
-- Coliseum Wall ] Rylae shivers and suffers.") -- same as every other
-- proc, these triggers deliberately do NOT match that prefix (see
-- combatDamage's header comment above for why) -- they'll still fire
-- normally for regular (non-Coliseum) poison procs.
MyDSL._triggers.procPoisonSetup = tempRegexTrigger(
  "^([\\w\\-\\s,']+) coats ([\\w\\-\\s,']+) with deadly lifebane poison\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("P") end end)
MyDSL._triggers.procPoisonOnset = tempRegexTrigger(
  "^([\\w\\-\\s,']+) is poisoned by the venom on ([\\w\\-\\s,']+)\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("P") end end)
MyDSL._triggers.procPoisonTick = tempRegexTrigger(
  "^([\\w\\-\\s,']+) shivers and suffers\\.$",
  function() if MyDSL and MyDSL.parseCombatProcLine then MyDSL.parseCombatProcLine("P") end end)

-- ---- Round-flush handler (PNP's output_damage(), close to verbatim) ----
-- Fires on every GMCP char_data packet (vitals refresh), which the game
-- sends once per prompt/combat round -- see 9q's header comment for why
-- this event (not updatePrompt-equivalent) is the right once-per-round
-- signal for us. For each (attacker,target) pair active this round, combine
-- nouns/hits/swings/dam (excluding "(evade)" from the noun/hit/dam
-- combination but INCLUDING its swings in the total, matching PNP's exact
-- `if k3 ~= "evaded"` scope), compute an aggregate verb via calcDamVerb(),
-- and output ONE summary sentence per pair to MAIN CONSOLE.
--
-- Critical PNP behavior, confirmed by reading output_damage() directly:
-- this summary is gated ONLY by summarize_damage -- NOT by gag_combat. That
-- means PNP's actual out-of-box default (gag_combat=true, gag_non_damage=
-- true, summarize_damage=true) already gives exactly a "condensed" mode:
-- raw per-swing lines hidden, one aggregate sentence per round shown. The
-- 3-way raw/condensed/gag toggle Steven described maps directly onto these
-- two flags -- raw: gag_combat=false, summarize_damage=false; condensed:
-- gag_combat=true, summarize_damage=true (the PNP default); gag: both true/
-- false respectively (summarize_damage=false, nothing to main at all).
if MyDSL._handlers.combatRoundFlush then
  pcall(killAnonymousEventHandler, MyDSL._handlers.combatRoundFlush)
end
MyDSL._handlers.combatRoundFlush = registerAnonymousEventHandler(
  "MyDSL.char.updated",
  function()
    if not (MyDSL and MyDSL.State and MyDSL.State.combat) then return end
    local combat = MyDSL.State.combat
    local rd  = combat.round_data
    local cfg = (MyDSL.CombatView and MyDSL.CombatView.config) or {}

    if next(rd) and cfg.summarize_damage then
      -- Group round_data entries by (attacker,target) pair.
      local roundPairs = {}
      for _, e in pairs(rd) do
        local pairKey = e.attacker .. "→" .. e.target
        roundPairs[pairKey] = roundPairs[pairKey]
          or { attacker=e.attacker, target=e.target, swings=0, hits=0, dam=0, nouns={}, flags={} }
        local p = roundPairs[pairKey]
        p.swings = p.swings + (e.swings or 0)
        if e.noun ~= "(evade)" then
          p.hits = p.hits + (e.hits or 0)
          p.dam  = p.dam  + (e.score or 0)
          p.nouns[#p.nouns + 1] = e.noun
          if e.flags then
            for code, cnt in pairs(e.flags) do p.flags[code] = (p.flags[code] or 0) + cnt end
          end
        end
      end

      local first = true
      for _, p in pairs(roundPairs) do
        if p.swings > 0 then
          local isYou           = (p.attacker == "you")
          local displayAttacker = isYou and "You" or string.title(p.attacker)
          local displayTarget   = string.title(p.target)
          local possessive      = isYou and "r" or "'s"
          local nounsStr        = table.concat(p.nouns, ", ")
          local flagsStr        = ""
          for code, _ in pairs(p.flags) do
            flagsStr = flagsStr .. "<" .. (FLAG_COLOR[code] or "255,215,65") .. ">" .. code
          end
          if flagsStr ~= "" then flagsStr = flagsStr .. "<r>" end

          local str = battleFormat(cfg.summary_format or "%a%r %n %v %t (%d)", {
            a = displayAttacker, r = possessive, n = nounsStr, v = calcDamVerb(p.dam, isYou),
            t = displayTarget, d = p.dam, h = p.hits, s = p.swings, f = flagsStr,
          })
          decho((first and "" or "\n") .. str)
          first = false
        end
      end

      if combat.pending_condition then
        decho("\n" .. combat.pending_condition.screen)
      end
    end

    if combat.pending_condition and MyDSL.CombatView and MyDSL.CombatView.appendSwing then
      MyDSL.CombatView.appendSwing(combat.pending_condition.window)
    end
    combat.pending_condition = nil

    combat.last_updated = os.time()
    raiseEvent("MyDSL.combat.updated", rd)
    combat.round_data = {}

    -- Rage: check if HP is hidden this round
    local rage = combat.rage
    local char = MyDSL.State.char
    if char and char.hp_raw == "???" then
      raiseEvent("MyDSL.combat_rage", rage.damage, rage.vamp)
    else
      rage.damage = 0
      rage.vamp   = 0
    end
  end
)

