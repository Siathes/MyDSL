-- =============================================================================
-- MyDSL_DataLayer_PromptVitals.lua  --  Layer 1: Data Collection (Score/Flags/Lunar/Time/Weather/Who/Group/Improve capture)
-- =============================================================================
-- Split out of MyDSL_DataLayer.lua 2026-08-25, fifth and final slice of
-- the split-by-domain refactor (see docs/TODO.md for the full plan and
-- prior slices' writeup). Covers everything prompt/vitals-shaped: score
-- block capture, the flags toggle sub-block, lunar phase block, game
-- time/prompt-line day-night period, weather (including the rare
-- lowercase-"and" wind-clause split case), sunrise/sunset, real-time
-- Pos'n and Wimpy text triggers, Dragon Vitality (`stat` output), who
-- list, group block, and improve (skill practice) progress lines.
--
-- Genuinely the most cross-cutting domain of the five (Pos'n/Wimpy/
-- Dragon Vitality are all real-time single-line text triggers layered
-- on top of GMCP, not begin/end blocks like the others) -- this is why
-- it was left for last. Grepped every function/local for cross-domain
-- call sites before moving anything, same as every prior slice: found
-- zero real code dependencies outside this domain (a few name mentions
-- in MyDSL_DataBridge.lua/MyDSL_LiveView.lua/MyDSL_MoonWeather.lua/
-- MyDSL_GroupView.lua comments, but those modules all read from
-- MyDSL.State/MyDSL.DB, populated via the event bus -- none of them
-- call these functions directly). No new MyDSL.* promotions needed.
--
-- Same contract as before the split: zero display logic, never sends
-- commands to the game. Depends on MyDSL_DataLayer.lua already being
-- loaded (MyDSL.State/MyDSL._triggers/MyDSL.emit/MyDSL.save all come
-- from there) -- dofile() order matters, this file must load AFTER it.
--
-- With this slice, MyDSL_DataLayer.lua's own Section 9 (trigger-capture
-- parsing functions) and Section 10 (trigger registration) are now both
-- fully empty -- the core file holds only Sections 1-8 (namespace guard,
-- private utilities, state table, character name, event bus, get/set
-- API, GMCP handlers, persistence): genuinely shared infrastructure
-- every domain module depends on, the natural floor for this refactor.
-- =============================================================================

MyDSL = MyDSL or {}

local function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end

------------------------------------------------------------------------
-- 9a  SCORE
------------------------------------------------------------------------
-- Trigger wiring is done in code at the bottom of this file.
-- beginScore() is called by a permanent tempRegexTrigger on "^Score for ".
-- It installs a catch-all line trigger that feeds every subsequent line to
-- parseScoreLine(). The catch-all is killed by endScore() so it is only
-- active during the score block.
--
-- The score block has three "^---" separator lines:
--   Line 1: "Score for <Name> -= <Title> =- ..."  → beginScore()
--   Line 2: "---..."                              → first separator, skip
--   Lines 3-N: main stat body                    → parseScoreLine()
--   Line N+1: "---..."                            → middle separator, skip
--   Lines N+2-M: PROFESSION / Reclass section    → parseScoreLine()
--   Line M+1: "---..."                            → endScore() (only after _saw_profession)

local scoreBlock = nil

function MyDSL.beginScore(charName)
  scoreBlock = { name = trim(charName), lines = {}, _saw_sep = false, _saw_profession = false }
  -- Install a catch-all trigger to pipe subsequent lines to parseScoreLine.
  -- Killed by endScore() so it is never active outside a score block.
  if MyDSL._triggers.scoreParse then
    pcall(killTrigger, MyDSL._triggers.scoreParse)
  end
  MyDSL._triggers.scoreParse = tempRegexTrigger(
    ".*",
    [[if MyDSL and MyDSL.parseScoreLine then MyDSL.parseScoreLine(line) end]]
  )
end

function MyDSL.parseScoreLine(line)
  if not scoreBlock then return end
  -- Three "^---" separator lines in the block:
  -- First (after header): skip. Middle (before PROFESSION section): skip.
  -- Final (after PROFESSION section): commit — but only once _saw_profession is true.
  if line:match("^%-%-%-") then
    if not scoreBlock._saw_sep then
      scoreBlock._saw_sep = true   -- first separator, skip
      return
    elseif scoreBlock._saw_profession then
      MyDSL.endScore()             -- final separator, after PROFESSION — commit
      return
    else
      return                       -- middle separator, before PROFESSION — skip
    end
  end
  scoreBlock.lines[#scoreBlock.lines + 1] = line

  local v  -- reused temp

  -- Created: <weekday> <month> <day> <hh:mm:ss> <year>  -- added
  -- 2026-07-12 for LiveView's in-game age display, per Steven. Real
  -- current format confirmed in docs/DSL_CommandRef.md and live corpus
  -- (e.g. "Created: Wed May 21 15:20:26 2025", from a real captured score
  -- output). A bare numeric fallback ("Created:  07.28.2024", no
  -- time-of-day) also seen in older captures -- handled too, in case any
  -- character still shows it. Stores a real Lua timestamp
  -- (created_ts), not the raw string -- age is computed live from this
  -- in MyDSL_LiveView.lua, same "store the anchor, compute fresh on
  -- render" pattern as improveLiveText().
  do
    local MONTH_NUM = {
      Jan=1, Feb=2, Mar=3, Apr=4, May=5, Jun=6,
      Jul=7, Aug=8, Sep=9, Oct=10, Nov=11, Dec=12,
    }
    local _, cmonth, cday, chh, cmin, csec, cyear =
      line:match("^Created:%s*(%a+)%s+(%a+)%s+(%d+)%s+(%d+):(%d+):(%d+)%s+(%d+)")
    if cmonth and MONTH_NUM[cmonth] then
      local ok, ts = pcall(os.time, {
        year = tonumber(cyear), month = MONTH_NUM[cmonth], day = tonumber(cday),
        hour = tonumber(chh), min = tonumber(cmin), sec = tonumber(csec),
      })
      if ok and ts then scoreBlock.created_ts = ts end
    else
      local nmonth, nday, nyear = line:match("^Created:%s*(%d+)%.(%d+)%.(%d+)")
      if nmonth then
        local ok, ts = pcall(os.time, {
          year = tonumber(nyear), month = tonumber(nmonth), day = tonumber(nday),
          hour = 0, min = 0, sec = 0,
        })
        if ok and ts then scoreBlock.created_ts = ts end
      end
    end
  end

  -- LEVEL: 051  Race: High Elf  Played: 1234
  local lv, race, played =
    line:match("LEVEL:%s*(%d+)%s+Race%s*:%s*(.-)%s+Played:%s*(%d+)")
  if lv then
    scoreBlock.level        = tonumber(lv)
    scoreBlock.race         = trim(race)
    scoreBlock.played_hours = tonumber(played)
    return
  end

  -- YEARS: 012  Class: Warrior  Log In: ...
  local yr, cl = line:match("YEARS:%s*(%d+)%s+Class%s*:%s*(.-)%s+Log In:")
  if yr then
    scoreBlock.years = tonumber(yr)
    scoreBlock.class = trim(cl)
    return
  end

  -- SEX: Male  Reclass@: 200
  local sx, rc = line:match("SEX%s*:%s*(%S+)%s+Reclass@:%s*(%S*)")
  if sx then
    scoreBlock.sex        = sx
    scoreBlock.reclass_at = rc ~= "" and rc or nil
    return
  end

  -- Stats: STR  : 051(050)  INT  : 064(064)  etc. — stored flat on scoreBlock
  for _, stat in ipairs({ "STR", "INT", "WIS", "DEX", "CON" }) do
    local cur, base = line:match(stat .. "%s*:%s*(%d+)%((%d+)%)")
    if cur then
      local k = stat:lower()
      scoreBlock[k]            = tonumber(cur)
      scoreBlock[k .. "_base"] = tonumber(base)
    end
  end

  -- HitRoll: B:21  P:31   (on STR line)
  local hB, hP = line:match("HitRoll:%s*B:([%+%-]?%d+)%s+P:([%+%-]?%d+)")
  if hB then scoreBlock.hit_roll_base = tonumber(hB); scoreBlock.hit_roll = tonumber(hP) end

  -- DamRoll: B:37  P:47   (on INT line)
  local dB, dP = line:match("DamRoll:%s*B:([%+%-]?%d+)%s+P:([%+%-]?%d+)")
  if dB then scoreBlock.dam_roll_base = tonumber(dB); scoreBlock.dam_roll = tonumber(dP) end

  -- Items: 133   (max 196  )   (on STR line)
  local items_cur, items_max = line:match("Items:%s*(%d+)%s+%(max%s+(%d+)%s*%)")
  if items_cur then
    scoreBlock.items     = tonumber(items_cur)
    scoreBlock.max_items = tonumber(items_max)
  end

  -- Weight: 592   (max 603   )   (on INT line — was missing entirely)
  local wt, mwt = line:match("Weight:%s*(%d+)%s+%(max%s+(%d+)%s*%)")
  if wt then
    scoreBlock.weight     = tonumber(wt)
    scoreBlock.max_weight = tonumber(mwt)
  end

  -- Armor: P:-160 B:-160 S:-160 M:-80   (on WIS line)
  local ap, ab, as_, am =
    line:match("Armor:%s*P:([%+%-]?%d+)%s+B:([%+%-]?%d+)%s+S:([%+%-]?%d+)%s+M:([%+%-]?%d+)")
  if ap then
    scoreBlock.armor_pierce = tonumber(ap)
    scoreBlock.armor_bash   = tonumber(ab)
    scoreBlock.armor_slash  = tonumber(as_)
    scoreBlock.armor_magic  = tonumber(am)
  end

  -- Hitpoints / Mana / Move
  local hp, mhp = line:match("Hitpoints:%s*(%d+)%s+of%s+(%d+)")
  if hp then scoreBlock.hp = tonumber(hp); scoreBlock.max_hp = tonumber(mhp) end
  local mn, mmn = line:match("Mana:%s*(%d+)%s+of%s+(%d+)")
  if mn then scoreBlock.mana = tonumber(mn); scoreBlock.max_mana = tonumber(mmn) end
  local mv, mmv = line:match("Move:%s*(%d+)%s+of%s+(%d+)")
  if mv then scoreBlock.move = tonumber(mv); scoreBlock.max_move = tonumber(mmv) end

  -- GOLD : 222  Silver: 187   (actual caps/spacing — old code used Gold: which never matched)
  local g, s = line:match("GOLD%s*:%s*(%d+)%s+Silver:%s*(%d+)")
  if g then scoreBlock.gold = tonumber(g); scoreBlock.silver = tonumber(s) end

  -- BANK : 60  QPoints: 1164   (old code: Bank:/Qpoints: — both wrong)
  local bk, qp = line:match("BANK%s*:%s*(%d+)%s+QPoints:%s*(%d+)")
  if bk then scoreBlock.bank = tonumber(bk); scoreBlock.qpoints = tonumber(qp) end

  v = line:match("PRACT:%s*(%d+)");       if v then scoreBlock.practices = tonumber(v) end
  v = line:match("TRAIN:%s*(%d+)");       if v then scoreBlock.trains    = tonumber(v) end
  v = line:match("XP%s*:%s*(%d+)");       if v then scoreBlock.xp       = tonumber(v) end
  v = line:match("TNL:%s*(%d+)");         if v then scoreBlock.tnl      = tonumber(v) end
  -- Align: stops at double-space so "Prestige hours: 460" on the same line is excluded
  v = line:match("Align:%s*(.-)%s%s");    if v then scoreBlock.align    = trim(v) end
  -- Dragon-only, added 2026-07-12 per Steven ("for dragons/Qin only, we
  -- need the chamber stat for breath weapon shown in score as
  -- Chamber:"). Real format confirmed via corpus grep: same DEX/Align
  -- row, dragon-only variant that replaces the non-dragon "Prestige
  -- hours:" field -- "DEX  : 060(060)    Align: True Neutral
  -- Chamber: 100". DSL_Helpfiles/dragons.txt: dragons "chamber their
  -- breath until such a time that they wish to unleash it" -- this is
  -- that charge level. Only ever present for dragons, so no race check
  -- needed here either, same as Vitality above.
  v = line:match("Chamber:%s*(%d+)");     if v then scoreBlock.chamber  = tonumber(v) end
  v = line:match("Wimpy:%s*(%d+)");       if v then scoreBlock.wimpy    = tonumber(v) end
  -- Pos'n: single-word value (Standing/Sleeping/etc.) followed by flag columns
  v = line:match("Pos'n:%s*(%S+)");       if v then scoreBlock.position = trim(v) end
  v = line:match("Stance:%s*(%S+)");       if v then scoreBlock.stance      = v end
  v = line:match("Speaking:%s*(%S+)");    if v then scoreBlock.language   = v end
  -- Fixed 2026-07-12, per Steven (LiveView identity row overflowing):
  -- real format is "Religion: Cliath -=- the God of Creation -=-"
  -- (confirmed via corpus grep across every god name seen: Cliath/
  -- Devion/Dragoth/Drakkara/Fatale/Kwainin/Nadrik/Raije/Zandrey/
  -- Zandreya) -- capturing "(.+)$" grabbed the whole trailing title
  -- along with the name. Every real god name is a single word (cross-
  -- checked against DSL_Helpfiles' own god files), so just the first
  -- token is the name.
  v = line:match("Religion:%s*(%S+)");    if v then scoreBlock.religion   = v end
  v = line:match("PROFESSION:%s*(.+)$")
  if v then scoreBlock.profession = trim(v); scoreBlock._saw_profession = true end

  -- Craftskill: 241  Craft Rank: Apprentice Hunter
  -- Old code looked for "Craft: name pct%" which is completely wrong format.
  -- Key is the craft type (last word of rank), value is 1-1000 skillpoints.
  local cs, cr = line:match("Craftskill:%s*(%d+)%s+Craft Rank:%s*(.+)$")
  if cs then
    scoreBlock.crafts = scoreBlock.crafts or {}
    local type_word = trim(cr):match("%S+$")
    if type_word then
      scoreBlock.crafts[type_word:lower()] = tonumber(cs)
    end
  end

  -- PKill: [ Win: 0  Giants: 0  BB Wins: 0 ]   (old code: PKills:/PKilled: — wrong format)
  local pk_win, pk_giants, pk_bb =
    line:match("PKill:.*Win:%s*(%d+).*Giants:%s*(%d+).*BB Wins:%s*(%d+)")
  if pk_win then
    scoreBlock.pkills        = tonumber(pk_win)
    scoreBlock.pkills_giants = tonumber(pk_giants)
    scoreBlock.pkills_bb     = tonumber(pk_bb)
  end
end

function MyDSL.endScore()
  -- Kill the catch-all line trigger before doing anything else.
  if MyDSL._triggers.scoreParse then
    pcall(killTrigger, MyDSL._triggers.scoreParse)
    MyDSL._triggers.scoreParse = nil
  end
  if not scoreBlock then return end
  local fields = { raw = scoreBlock.lines }
  for k, v in pairs(scoreBlock) do
    if k ~= "lines" and k ~= "_saw_sep" and k ~= "_saw_profession" then fields[k] = v end
  end
  update("score", fields)
  scoreBlock = nil
  MyDSL.save()
end

------------------------------------------------------------------------
-- 9b  FLAGS  (toggle section inside score output)
------------------------------------------------------------------------
-- Trigger wiring:
--   flags block header → MyDSL.beginFlags()
--   each flag line     → MyDSL.parseFlagsLine(line)
--   block end          → MyDSL.endFlags()

local KNOWN_FLAGS = {
  "NoFollow","AutoAssist","AutoExit","AutoGold","AutoLoot","AutoSac",
  "AutoSplit","NoBattle","NoPkLoot","NoTake","NoHeal","NoFly",
  "NoSummon","NoLink","NoCancel","Compact","Prompt","Combine",
  "AutoQuit","BeepTell","Ticks","TelnetGA","NoSurrender","NoToast",
}

-- Lowercase → canonical name lookup for fast word matching
local FLAG_SET = {}
for _, f in ipairs(KNOWN_FLAGS) do FLAG_SET[f:lower()] = f end

local flagsBlock = {}

function MyDSL.beginFlags()
  flagsBlock = {}
end

function MyDSL.parseFlagsLine(line)
  -- Detect "(X)" = ON and "( )" = OFF. Pattern handles both "Flag(X)" and "Flag (X)".
  -- Old code only checked word presence, never read the X/space state.
  for name, state in line:gmatch("(%w+)%s*%(([X ])%)") do
    local canon = FLAG_SET[name:lower()]
    if canon then flagsBlock[canon] = (state == "X") end
  end
end

function MyDSL.endFlags()
  -- parseFlagsLine writes true/false per flag. nil means the line was never seen
  -- (treat as OFF). "flag == true" collapses nil→false, false→false, true→true.
  local fields = {}
  for _, canon in ipairs(KNOWN_FLAGS) do
    fields[canon] = flagsBlock[canon] == true
  end
  update("flags", fields)
  flagsBlock = {}
  MyDSL.save()
end

------------------------------------------------------------------------
-- 9c  LUNAR
------------------------------------------------------------------------
-- Trigger wiring:
--   lunar section header → MyDSL.beginLunar()
--   each moon line       → MyDSL.parseLunarLine(line)
--   blank line / end     → MyDSL.endLunar()
--
-- Actual 2-line-per-moon format (confirmed from in-game capture):
--   The red moon is full and not visible.
--      [Mana +15%]  [Saves -3]  [Casting +3]  [Regen   0%]  [Cycles remaining 45 (22 Hours)]
--   The white moon is crescent waning and not visible.
--      [Mana +5%]   [Saves -1]  [Casting +1]  [Regen   0%]  [Cycles remaining 12 (6 Hours)]
-- Old code expected a completely different single-line format — full rewrite.

local lunarBlock = {}
local MOON_COLORS = { red = true, white = true, black = true }

function MyDSL.beginLunar()
  -- Reset the in-progress block. Each moon sub-table pre-initialised with
  -- has_bonuses=false so the field always exists even when no bonus block arrives.
  lunarBlock = {
    red   = { has_bonuses = false },
    white = { has_bonuses = false },
    black = { has_bonuses = false },
    _last = nil,
  }
end

function MyDSL.parseLunarLine(line)
  -- Type 1 — Moon description line:
  --   "The red moon is empty and not visible."
  --   "The white moon is waxing three-quarters and in high sanction."
  -- Three-capture pattern splits color, phase, and raw position in one step.
  -- The optional %.? accepts lines with or without a trailing period.
  local color, phase, position = line:match("^The (%a+) moon is (.+) and (.-)%.?$")
  if color and MOON_COLORS[color] then
    -- Strip "in " prefix so "in high sanction" → "high sanction".
    position = (position or ""):gsub("^in ", "")
    local moon = lunarBlock[color]
    moon.phase       = trim(phase or "")
    moon.position    = trim(position)
    moon.has_bonuses = false  -- remains false unless a bonus line follows
    lunarBlock._last = color
    return
  end

  -- Type 2 — Bonus stat line (only for focal moon with high Astrology):
  --   "   [Mana   0%]  [Saves  0]  [Casting  0]  [Regen   0%]  [Cycles remaining 38 (19 1/2 Hours)]"
  -- %s+ handles multiple spaces between label and value (game output is ragged).
  if lunarBlock._last and line:find("%[Mana") then
    local moon = lunarBlock[lunarBlock._last]
    moon.mana_bonus       = tonumber(line:match("%[Mana%s+([%+%-]?%d+)%%%]"))
    moon.saves_modifier   = tonumber(line:match("%[Saves%s+([%+%-]?%d+)%]"))
    moon.casting_modifier = tonumber(line:match("%[Casting%s+([%+%-]?%d+)%]"))
    moon.regen_pct        = tonumber(line:match("%[Regen%s+([%+%-]?%d+)%%%]"))
    moon.cycles_remaining = tonumber(line:match("%[Cycles remaining (%d+)"))
    -- Capture integer hours from "(19 1/2 Hours)" or "(22 Hours)".
    -- [^%)]* eats the fractional part so the capture is always just the integer.
    moon.hours_remaining  = tonumber(line:match("%((%d+)[^%)]*%)"))
    moon.has_bonuses      = true
  end
end

function MyDSL.endLunar()
  update("lunar", {
    red       = lunarBlock.red   or {},
    white     = lunarBlock.white or {},
    black     = lunarBlock.black or {},
    parsed_at = os.time(),   -- timestamp for MoonWeather countdown anchor
  })
  lunarBlock = {}
  MyDSL.save()
end

------------------------------------------------------------------------
-- 9d  TIME
------------------------------------------------------------------------
-- Single-line.  Trigger matches "It is \d" and calls this.
-- Two confirmed real formats (both must match):
--   "It is 9:30 am, Day of the Great Gods, 26th the Month of the Great Evil."
--   "It is 10:00 o'clock am, Day of the Great Gods, 26th the Month of the Great Evil."
-- Old code only handled a single wrong variant ("on the Day of", no HH:MM).
-- New pattern: [^,]- lazily skips " o'clock" when present, absorbs nothing otherwise.

function MyDSL.parseTimeLine(line)
  local hour, min, ampm, day_name, day_num, month =
    line:match("It is (%d+):(%d+)[^,]-(%a+), Day of ([^,]+), (%d+)%a+ the Month of ([^%.]+)")
  if hour then
    update("time", {
      hour     = tonumber(hour),
      minute   = tonumber(min) or 0,
      ampm     = ampm,
      day_name = trim(day_name),
      day_num  = tonumber(day_num),
      month    = trim(month),
    })
  end
end

------------------------------------------------------------------------
-- 9d2  PROMPT LINE (day/night period)
------------------------------------------------------------------------
-- Fires on prompt line 2 (fires every server event — most reliable day/night source):
--   "==-Night Time - 5:00am :: [room] :: [exits]-=="
--   "==-Day Time - 10:30am :: ..."
--   "==-Dawn - 6:00am :: ..."
-- Period confirmed from live session (Steven, 2026-06-30): Night Time, Dawn, Day Time.

function MyDSL.parsePromptLine(line)
  local period = line:match("^==%-(%a[%a%s]+) %- %d+:%d+%a+ :: ")
  if not period then return end
  period = trim(period)
  if period == "" then return end
  MyDSL.State.time.period   = period
  MyDSL.State.time.is_night = (period == "Night Time")
  MyDSL.State.time.last_updated = now()
  MyDSL.emit("time")
end

------------------------------------------------------------------------
-- 9e  WEATHER
------------------------------------------------------------------------
-- Single-line.  Trigger matches a weather description line.
-- Example: "A light snow falls quietly from the sky."

-- Weather keyword guard: the trigger pattern is broad (any capitalised sentence)
-- so we filter here. Require at least one atmospheric/weather-indicative word.
-- Expand this list as more weather line formats are confirmed in CommandRef.
local _weatherWords = {
  "cloud", "breeze", "wind", "rain", "snow", "storm", "fog", "sky",
  "sun", "wave", "shore", "ocean", "drizzle", "mist", "hail",
  "thunder", "lightning", "overcast", "chilly", "sleet",
}

-- extractWindClause(text) -- added 2026-07-12, per Steven ("wind should
-- be captured. clouds, clear, rain, gold [cold] breeze, temperate wind,
-- etc"). Pulls just the wind portion out of a weather sentence, if
-- present. Real corpus-confirmed shape (96 samples across the full
-- log/ archive, 193 files): "a <cold|temperate|warm>
-- <gentle|moderate> breeze/wind blows in from the
-- <north|south|east|west>", or the calm form "the wind is calm" --
-- no other temperature/strength/direction words found anywhere in the
-- corpus, so this is a complete, not partial, taxonomy. Returns the
-- matched fragment (capitalized) or nil if the text has no wind clause.
function MyDSL.extractWindClause(text)
  if not text then return nil end
  local s, e = text:find("a %a+ %a+ %a+ blows in from the %a+")
  if s then
    local clause = text:sub(s, e)
    return clause:sub(1, 1):upper() .. clause:sub(2)
  end
  if text:find("[Tt]he wind is calm") then return "The wind is calm" end
  return nil
end

function MyDSL.parseWeatherLine(line)
  local desc = trim(line)
  if desc == "" then return end
  local lc = desc:lower()
  local found = false
  for _, w in ipairs(_weatherWords) do
    -- Word-boundary match, not plain substring (fixed 2026-07-06). The
    -- trigger itself is intentionally broad (any capitalized sentence,
    -- matches ~13% of all lines) and this filter is the real safety net --
    -- but a plain substring check meant "sun" matched inside "Sunday",
    -- confirmed live-corrupting MyDSL.State.weather with the log-session-
    -- start banner ("Log session starting at ... on Sunday...") every time
    -- a new Mudlet log file opened. Frontier pattern requires a non-letter
    -- on both sides of the word.
    if lc:find("%f[%a]" .. w .. "%f[%A]") then found = true; break end
  end
  if not found then return end
  local fields = { description = desc }
  -- Wind is embedded in this same sentence in the standard (comma-joined)
  -- form -- confirmed 53/53 real corpus samples take this shape, so this
  -- alone covers the common case with no extra trigger needed.
  local windClause = MyDSL.extractWindClause(desc)
  if windClause then fields.windDescription = windClause end
  update("weather", fields)
end

------------------------------------------------------------------------
-- 9f  WHO
------------------------------------------------------------------------
-- Trigger wiring:
--   who header line        → MyDSL.beginWho()
--   "[level class]" line   → MyDSL.parseWhoLine(line)
--   end of who block       → MyDSL.endWho()
--
-- Format: "[level race class] (org) name title"
-- Bracket contains THREE tokens: level, race, class.
-- Races include hyphens (W-Elf, M-Dwf, D-Elf, H-Ogre) so %a+ was wrong.
-- Old code: "%[(%d+)%s+(%a+)%]" — only captured level + one word (was treating race as class).
-- New code: captures all three tokens from the bracket.

local whoBlock = {}

function MyDSL.beginWho() whoBlock = {} end

-- Rewritten 2026-07-05 -- confirmed broken against DSL_CommandRef.md's own
-- documented real format and PNP's tested People.lua regex:
--   `[level race class] (org_code) name title`  -- clan, PARENS
--   `[level race class] [ Kingdom ] name title`  -- kingdom, BRACKETS (with
--                                                    spaces inside)
-- The old version only ever looked for the org/clan in [brackets] --
-- real clan tags like "(NT)"/"(VR)" (confirmed live in log/) are in
-- PARENS, so `entry.clan` was always nil, and the leftover "(WANTED)"/
-- "(VR)" parenthetical text shifted every word after it by one position,
-- corrupting `kingdom` and `name` for any WANTED or clan-tagged entry
-- (confirmed: "[27 Goblin Bnd] (WANTED) (VR) <Name>." parsed as
-- kingdom="()" name="(VR)" instead of org="VR" name="<Name>"). Also dropped
-- "QUIET" -- never found anywhere in log/ or DSL_CommandRef.md, unconfirmed.
function MyDSL.parseWhoLine(line)
  local level, race, class = line:match("%[%s*(%d+)%s+([%w%-]+)%s+(%w+)%]")
  if not level then return end

  local entry = {
    level  = tonumber(level),
    race   = trim(race),
    class  = trim(class),
    wanted = false,
    afk    = false,
  }

  -- Everything after the closing [level race class] bracket.
  local rest = line:match("%](.+)$") or ""

  -- Bare, unwrapped AFK (confirmed live in log/ alongside "[AFK]"/"(AFK)" --
  -- DSL isn't consistent about the delimiter, so check all three forms).
  if rest:find("%sAFK%s") or rest:find("%sAFK$") then entry.afk = true end
  rest = rest:gsub("%sAFK%s", " "):gsub("%sAFK$", "")

  -- Every remaining ()/[] group, in order. Per DSL_CommandRef.md + confirmed
  -- live in log/:
  --   (WANTED) / (Hostile) / [AFK] / (AFK)  -- status markers, not org
  --   (org_code)                 -- clan short code: (NT), (VR), (Abaddon)
  --   [ Kingdom ]                 -- kingdom name (spaces inside brackets)
  --   (Queen)(Verminasia)         -- multi-org: two groups, both real orgs
  --   (New Thalos), ( Dragon )    -- multi-word org, spaces inside parens too
  local orgs = {}
  rest = rest:gsub("[%(%[]%s*([^%)%]]-)%s*[%)%]]", function(tag)
    tag = trim(tag)
    if tag == "WANTED" then entry.wanted = true
    elseif tag == "Hostile" then entry.hostile = true
    elseif tag == "AFK" then entry.afk = true
    elseif tag ~= "" then orgs[#orgs + 1] = tag
    end
    return " "
  end)
  if #orgs > 0 then entry.org = table.concat(orgs, ", ") end

  -- Whatever's left: name, then title (if any words follow).
  local parts = {}
  for w in trim(rest):gmatch("%S+") do parts[#parts + 1] = w end
  entry.name = parts[1]
  if #parts > 1 then
    local t = {}
    for i = 2, #parts do t[#t + 1] = parts[i] end
    entry.title = table.concat(t, " ")
  end

  if entry.name then whoBlock[#whoBlock + 1] = entry end
end

function MyDSL.endWho()
  update("who", { players = whoBlock, count = #whoBlock })
  whoBlock = {}
end

------------------------------------------------------------------------
-- 9i  GROUP
------------------------------------------------------------------------
-- Example: "[51 War] <Name>                     100% hp 100% mana 100% mv"
--          "[30 Mob] A throughbred stallion    100% hp 100% mana 100% mv"
-- beginGroup() is called by a permanent trigger on "^.+'s group:$".
-- It installs a catch-all body trigger that feeds each line to
-- parseGroupLine() and kills itself on blank line (calling endGroup()).

local groupBlock = {}

function MyDSL.beginGroup()
  groupBlock = {}
  -- Kill any leftover catch-all from a previous group block that never ended.
  if MyDSL._triggers.groupBody then
    pcall(killTrigger, MyDSL._triggers.groupBody)
    MyDSL._triggers.groupBody = nil
  end
  MyDSL._triggers.groupBody = tempRegexTrigger(".*", function()
    if not (MyDSL and MyDSL.State) then return end
    local ln = getCurrentLine()
    local t  = trim(ln)
    -- Blank line signals end of group block.
    if t == "" then MyDSL.endGroup(); return end
    if MyDSL.parseGroupLine then MyDSL.parseGroupLine(ln) end
    -- Body line gagging delegated here so GroupView doesn't need its own body trigger.
    if MyDSL.GroupView and MyDSL.GroupView.config and MyDSL.GroupView.config.gagGroup then
      deleteLine()
    end
  end)
end

function MyDSL.parseGroupLine(line)
  -- %s* after "[" added 2026-07-11 -- real bug found live: DSL right-justifies
  -- the level in a fixed-width field, so single-digit levels get a leading
  -- space ("[ 1 Mob] An untrained guardhand ...") instead of none
  -- ("[51 War] <Name> ..."). The old pattern required a digit immediately
  -- after "[", so it silently failed to match ANY line (self included) once
  -- a group member's level dropped below 10 -- confirmed via a real
  -- "[ 1 Mob]"/"[ 1 Mag]" group listing, which is what caused
  -- the reported "follower not showing in group" symptom.
  local level, class, name, hp, mana, mv =
    line:match("%[%s*(%d+)%s+(%a+)%]%s+(.-)%s+(%d+)%%%s+hp%s+(%d+)%%%s+mana%s+(%d+)%%%s+mv")
  if not level then return end
  groupBlock[#groupBlock + 1] = {
    level    = tonumber(level),
    class    = trim(class),
    name     = trim(name),
    hp_pct   = tonumber(hp),
    mana_pct = tonumber(mana),
    mv_pct   = tonumber(mv),
    is_mob   = trim(class) == "Mob",
  }
end

function MyDSL.endGroup()
  -- Kill the catch-all before updating State to avoid re-entry.
  if MyDSL._triggers.groupBody then
    pcall(killTrigger, MyDSL._triggers.groupBody)
    MyDSL._triggers.groupBody = nil
  end
  update("group", { members = groupBlock, count = #groupBlock })
  groupBlock = {}
end

------------------------------------------------------------------------
-- 9n  IMPROVE
------------------------------------------------------------------------
-- Single-line.  Fires naturally when a skill improves during combat.
-- Example: "Your knowledge of bash improves to 72%."

function MyDSL.parseImproveLine(line)
  local skill, pct = line:match("Your knowledge of (.+) improves to (%d+)%%")
  if not skill then
    skill, pct = line:match("You feel yourself getting better at (.+)%. %((%d+)%%%)")
  end
  if skill then
    update("improve", { skill = trim(skill), percent = tonumber(pct) })
  end
end

-- parseImproveStatusLine() -- added 2026-07-07, per Steven (wants a
-- LiveView bar showing remaining time for the skill being improved).
-- A DIFFERENT real message from the completion line above -- the response
-- to typing "improve" (no args): a status snapshot with a countdown.
-- Confirmed real text, both trailing-period forms (DSL is inconsistent):
--   "You are currently improving astrology (100%). (71 online minutes to improvement)"
--   "You are currently improving blind fighting (91%). (0 online minutes to improvement)."
-- User-initiated only (typing "improve" yourself) -- MyDSL never sends
-- this command automatically. The bar shows the last snapshot as-is
-- between checks rather than a live-ticking countdown ("stale data beats
-- spam"); `MyDSL.State.improve.last_updated` already records when.
function MyDSL.parseImproveStatusLine(line)
  local skill, pct, mins = line:match(
    "^You are currently improving (.-) %((%d+)%%%)%. %((%d+) online minutes to improvement%)%.?$")
  if skill then
    update("improve", { skill = trim(skill), percent = tonumber(pct), remaining = tonumber(mins) })
  end
end


------------------------------------------------------------------------
-- SECTION 10: TRIGGER REGISTRATION
------------------------------------------------------------------------
-- Score header: "Score for <Name> -= <Title> =- (Companion) *Observer*"
-- Pattern matches only the first 10 chars so the full decorated header line
-- fires beginScore(). charName is captured as the first word after "Score for ".
-- beginScore() then installs the catch-all trigger for the body lines.

MyDSL._triggers.scoreBegin = tempRegexTrigger(
  "^Score for ",
  [[if MyDSL and MyDSL.beginScore then MyDSL.beginScore(line:match("^Score for (%S+)")) end]]
)


------------------------------------------------------------------------
-- Lunar block trigger
------------------------------------------------------------------------
-- Mirrors the score trigger pattern exactly.
--
-- A permanent trigger fires on the first moon line ("The red moon is ...").
-- It calls beginLunar() once to reset state, immediately parses that first
-- line, then installs a catch-all trigger (".*") that feeds every subsequent
-- line to parseLunarLine(). The catch-all kills itself when it detects a
-- blank line, which marks the end of the lunar block, then calls endLunar()
-- to commit the parsed data.
--
-- Guard: if the catch-all is already running (because this session has a
-- second or third moon line in the block), the permanent trigger returns
-- without calling beginLunar() again. The catch-all handles the line.

MyDSL._triggers.lunarBegin = tempRegexTrigger(
  "^The (red|white|black) moon is",
  function()
    if not (MyDSL and MyDSL.beginLunar) then return end
    -- If the catch-all is already active this line is handled there — skip.
    if MyDSL._triggers.lunarParse then return end
    -- Start a fresh block and parse the triggering line immediately.
    MyDSL.beginLunar()
    MyDSL.parseLunarLine(getCurrentLine())
    -- Install catch-all for all remaining lines in the block.
    MyDSL._triggers.lunarParse = tempRegexTrigger(".*", function()
      if not MyDSL then return end
      local ln = getCurrentLine()
      if ln:match("^%s*$") then
        -- Blank line = end of lunar block. Commit data and remove catch-all.
        killTrigger(MyDSL._triggers.lunarParse)
        MyDSL._triggers.lunarParse = nil
        if MyDSL.endLunar then MyDSL.endLunar() end
      else
        if MyDSL.parseLunarLine then MyDSL.parseLunarLine(ln) end
      end
    end)
  end
)

------------------------------------------------------------------------
-- Time line trigger
------------------------------------------------------------------------
-- Fires on every game-time output line:
--   "It is 9:30 am, Day of the Great Gods, 26th the Month of the Great Evil."
--   "It is 10:00 o'clock am, ..."
-- Pattern "^It is " is a safe literal prefix — both variants start with it.

MyDSL._triggers.timeLine = tempRegexTrigger(
  "^It is ",
  function()
    if MyDSL and MyDSL.parseTimeLine then
      MyDSL.parseTimeLine(getCurrentLine())
    end
  end
)

------------------------------------------------------------------------
-- Prompt line trigger (day/night period)
------------------------------------------------------------------------
-- Fires on every prompt line 2 — far more frequent than sunrise/sunset triggers.
-- PCRE: "^==-[A-Z]" matches "==-Night...", "==-Day...", "==-Dawn..." etc.
-- Also matches "==-<Name>" (name echo) but parsePromptLine() drops it (no " - HH:MM :: ").

MyDSL._triggers.promptLine = tempRegexTrigger(
  "^==-[A-Z]",
  function()
    if MyDSL and MyDSL.parsePromptLine then
      MyDSL.parsePromptLine(getCurrentLine())
    end
  end
)

------------------------------------------------------------------------
-- Sunrise / Sunset triggers
------------------------------------------------------------------------
-- Confirmed exact text from live session (Steven, 2026-06-30):
--   "The sun rises in the east."  — at ~6:30am game time
--   "The night has begun."        — night transition (plain text, triggerable)
-- Note: "* * * * * Night folds the land in shadow * * * * *" is a cecho line — NOT triggerable.
-- Sets State.time.is_night and re-emits "time" so DataBridge + MoonWeather update.

MyDSL._triggers.sunrise = tempRegexTrigger(
  "^The sun rises in the east\\.$",
  function()
    if MyDSL and MyDSL.State and MyDSL.State.time then
      MyDSL.State.time.is_night = false
      MyDSL.emit("time")
    end
  end
)

MyDSL._triggers.sunset = tempRegexTrigger(
  "^The night has begun\\.$",
  function()
    if MyDSL and MyDSL.State and MyDSL.State.time then
      MyDSL.State.time.is_night = true
      MyDSL.emit("time")
    end
  end
)

------------------------------------------------------------------------
-- Weather trigger
------------------------------------------------------------------------
-- Broad pattern: any line starting with a capital letter and ending with
-- a period. Fires on room descriptions too — parseWeatherLine() filters
-- internally using a weather keyword list.

MyDSL._triggers.weather = tempRegexTrigger(
  "^[A-Z][^.]+\\.$",
  function()
    local ln = getCurrentLine()
    if MyDSL and MyDSL.parseWeatherLine then
      MyDSL.parseWeatherLine(ln)
    end
  end
)

-- Rare edge case, found live 2026-07-12 (Steven: "Rain falls steadily
-- from the clouded sky. and a cold gentle breeze blows in from the
-- north."): DSL occasionally joins the precipitation and wind clauses
-- with a period instead of a comma, splitting what's normally one
-- sentence into two lines -- the second starting with a lowercase
-- "and", which the broad trigger above (requires a capital first
-- letter) never matches, silently dropping the wind info. Zero
-- historical occurrences of this exact shape anywhere in the full log/
-- archive (only the standard comma-joined form, 53/53 samples) --
-- genuinely rare, but real, so worth a narrow dedicated catch. Routes to
-- extractWindClause() directly (not parseWeatherLine(), which would
-- overwrite the precipitation description that was likely just captured
-- moments before from the first line) so only windDescription updates.
MyDSL._triggers.weatherWindContinuation = tempRegexTrigger(
  "^and (a \\w+ \\w+ (breeze|wind) blows in from the \\w+|the wind is calm)",
  function()
    local ln = getCurrentLine()
    local clause = MyDSL.extractWindClause and MyDSL.extractWindClause(ln)
    if clause then update("weather", { windDescription = clause }) end
  end
)


------------------------------------------------------------------------
-- Pos'n (physical position) -- real-time text triggers
------------------------------------------------------------------------
-- Added 2026-07-12, per Steven ("liveview pos'n doesnt update on
-- changing without score, it should update with the gmcp... check
-- sibling profiles and other liveview scripts, this was active once
-- before and update the character position as it happened"). LiveView's
-- Pos'n field was sourced only from score.posn, a text-parsed field that
-- only refreshes when `score` is actually run -- exactly the bug
-- reported.
--
-- Found the real prior implementation in
-- "../Dark & Shattered Lands - PNP/PNP/DSL_PNP_Statusbar.posn.lua":
-- real-time text triggers on the server's own first-person confirmation
-- lines ("You stand up.", "You sit down.", etc.), not GMCP polling --
-- genuinely more precise than score, since it updates the instant the
-- position actually changes rather than waiting for the next `score`.
--
-- NOT ported verbatim -- PNP's own "stand" pattern
-- (`^You (?:go to )?(stand|rest|sit|sleep|mount|dismount)`, no end
-- anchor) would be a real bug here: confirmed via log-corpus grep that
-- many DSL2 room descriptions independently start with "You stand on/in
-- the..." (second-person descriptive prose, unrelated to any stand
-- action -- confirmed it also appears after a plain `look`), which that
-- pattern would have matched and misfired on constantly. Rebuilt against
-- the actual exact confirmation sentences, confirmed real via corpus
-- grep across the full log/ archive: "You stand up.", "You sit down.",
-- "You rest.", "You go to sleep.", "You are already standing.", "You
-- are already sitting down.", "You wake and stand up.", "You wake up
-- and start resting.", "You mount <name>.", "You dismount.", "You
-- (slowly float|float gently) to the ground." (landing). "You stop
-- resting." kept from PNP (its own "stop resting -> back to sitting"
-- case) but NOT corpus-confirmed for DSL2 specifically -- low collision
-- risk (a specific, unambiguous full sentence), flagged in TODO.md like
-- the CharacterAssist disarm patterns were.
--
-- Flying is handled separately, via GMCP's is_flying in the char_data
-- handler above (real, confirmed field, updates instantly -- no text
-- trigger needed; directly confirmed live via a real session transcript
-- showing "You stand up." -> "c fly" -> "Your feet rise off the
-- ground." -> is_flying flipping to true in the very same capture).
--
-- setPosn(value) does NOT trust a trigger's text match as the final
-- word -- per Steven ("id prefer that the trigger patterns be the point
-- to check gmcp, not make its own decision to avoid the issues with
-- room descriptions or other cross contamination. so stand trigger
-- fires, check gmcp for the change and update"). GMCP's char_data has no
-- direct Standing/Sitting/Resting/Sleeping equivalent (only the boolean
-- flags already captured above -- is_flying/is_riding/is_fighting), so
-- "check GMCP" concretely means: is_flying is the one flag that actually
-- competes with a text-implied position, and it's authoritative -- a
-- trigger firing (whether from a deliberate action or, despite the
-- anchoring above, some future unanticipated text collision) can never
-- downgrade a character GMCP still confirms is flying. Every trigger
-- below reports what the text implied; setPosn() is the single place
-- that reconciles it against real GMCP state before committing.
local function setPosn(textImpliedValue)
  local char = MyDSL.State.char or {}
  local value = textImpliedValue
  if char.is_flying and value ~= "Flying" then
    value = "Flying"
  end
  update("char", { posn = value })
end

MyDSL._triggers.posnStandUp      = tempRegexTrigger([[^You stand up\.$]],                              function() setPosn("Standing") end)
MyDSL._triggers.posnSitDown      = tempRegexTrigger([[^You sit down\.$]],                               function() setPosn("Sitting") end)
MyDSL._triggers.posnRest         = tempRegexTrigger([[^You rest\.$]],                                   function() setPosn("Resting") end)
MyDSL._triggers.posnSleep        = tempRegexTrigger([[^You go to sleep\.$]],                            function() setPosn("Sleeping") end)
MyDSL._triggers.posnAlreadyStand = tempRegexTrigger([[^You are already standing\.$]],                   function() setPosn("Standing") end)
MyDSL._triggers.posnAlreadySit   = tempRegexTrigger([[^You are already sitting down\.$]],                function() setPosn("Sitting") end)
MyDSL._triggers.posnWakeStand    = tempRegexTrigger([[^You wake and stand up\.$]],                      function() setPosn("Standing") end)
MyDSL._triggers.posnWakeRest     = tempRegexTrigger([[^You wake up and start resting\.$]],              function() setPosn("Resting") end)
MyDSL._triggers.posnMount        = tempRegexTrigger([[^You mount .+\.$]],                                function() setPosn("Mounted") end)
MyDSL._triggers.posnDismount     = tempRegexTrigger([[^You dismount\.$]],                                function() setPosn("Standing") end)
-- Landing is the one case that must bypass the is_flying override above
-- (it's the trigger THAT clears Flying) -- confirmed live (same
-- transcript cited above) that GMCP's is_flying flips false slightly
-- before this line prints, so by the time it fires char.is_flying is
-- already false and setPosn()'s normal check passes "Standing" through
-- untouched; no special-casing needed here.
MyDSL._triggers.posnLand         = tempRegexTrigger([[^You (?:slowly float|float gently) to the ground\.$]], function() setPosn("Standing") end)
MyDSL._triggers.posnStopRest     = tempRegexTrigger([[^You stop resting\.$]],                            function() setPosn("Sitting") end)

------------------------------------------------------------------------
-- Wimpy -- real-time text trigger, same shape as Pos'n above
------------------------------------------------------------------------
-- Added 2026-07-12, per Steven ("wimpy should update when its changed as
-- well and gmcp, or how it collects info. but also with the manual
-- wimpy command"). MyDSL.DB.score.wimpy (MyDSL_DataBridge.lua) already
-- prefers char.wimpy (GMCP) over the text-parsed score.wimpy fallback --
-- that priority was already correct -- but nothing fed char.wimpy in
-- real time; it only refreshed whenever the next unrelated gmcp.char_data
-- packet happened to arrive with an updated value. Unlike Pos'n this
-- doesn't need a GMCP cross-check (no ambiguous states to reconcile,
-- just a number) -- confirmed real, exact response text via corpus grep,
-- identical for both a bare "wimpy" query and "wimpy <n>" to actually
-- set it: "Wimpy set to N hit points." Captures the number directly from
-- the confirmation line itself rather than guessing it.
MyDSL._triggers.wimpySet = tempRegexTrigger(
  [[^Wimpy set to (\d+) hit points\.$]],
  function()
    local n = tonumber(matches[2])
    if n then update("char", { wimpy = n }) end
  end
)

------------------------------------------------------------------------
-- Dragon Vitality -- text trigger on the `stat` command's output
------------------------------------------------------------------------
-- Added 2026-07-12, per Steven ("dragon vitality stat next for dragons/
-- qinrathaz only, see help files for dragon vitality if needed at it
-- below con in the stats window"). DSL_Helpfiles/dragons.txt confirms:
-- "Dragons will lose vitality with every death though not alterforms.
-- When a dragon's vitality is gone, the dragon will permanently die" --
-- a dragon-only permadeath-countdown stat, not present for any other
-- race. Real format confirmed from Steven's own cecho breadcrumb in
-- log/2026-07-07#20-17-54.html (typed `stat` on a dragon character):
-- "Str: 72(80)  Int: 60(72)  Wis: 60(72)  Dex: 60(60)  Con: 66(82)
-- Vit: 20" -- captures just the trailing "Vit: N", which only appears
-- at all for dragon characters (confirmed no "Vit:" field anywhere in
-- non-dragon corpus samples), so this naturally never fires/populates
-- for anyone else -- no race check needed. Character-bound via
-- update("char", ...), same persistence as posn/wimpy, since Steven
-- noted this can only really be confirmed by watching it live (changes
-- on a PK death), not re-testable on demand -- stale-but-persisted beats
-- blank between sessions.
MyDSL._triggers.vitalitySet = tempRegexTrigger(
  [[Vit:\s*(\d+)\s*$]],
  function()
    local n = tonumber(matches[2])
    if n then update("char", { vitality = n }) end
  end
)

------------------------------------------------------------------------
-- Group trigger
------------------------------------------------------------------------
-- Fires on "<Name>'s group:" (any character name followed by "'s group:").
-- Installs the body catch-all via beginGroup(); endGroup() kills it on
-- blank line and commits to State.group.

MyDSL._triggers.groupStart = tempRegexTrigger(
  "^.+'s group:$",
  function()
    if MyDSL and MyDSL.beginGroup then MyDSL.beginGroup() end
  end
)

-- CreatureLore trigger registration moved to
-- MyDSL_DataLayer_CreatureLore.lua (2026-08-25 split), alongside the
-- begin/parse/end functions it wires up -- see that file for the
-- MyDSL._triggers.loreStart registration.



------------------------------------------------------------------------
-- Improve triggers -- wired 2026-07-07 (both parse functions existed but
-- nothing called them; see parseImproveLine/parseImproveStatusLine above).
-- Per Steven: keep this one specifically, feeds a LiveView bar.
------------------------------------------------------------------------

MyDSL._triggers.improveComplete = tempRegexTrigger(
  "^Your knowledge of .+ improves to \\d+%\\.?$",
  function() if MyDSL and MyDSL.parseImproveLine then MyDSL.parseImproveLine(getCurrentLine()) end end)
MyDSL._triggers.improveGetBetter = tempRegexTrigger(
  "^You feel yourself getting better at .+\\. \\(\\d+%\\)$",
  function() if MyDSL and MyDSL.parseImproveLine then MyDSL.parseImproveLine(getCurrentLine()) end end)
MyDSL._triggers.improveStatus = tempRegexTrigger(
  "^You are currently improving .+ \\(\\d+%\\)\\. \\(\\d+ online minutes to improvement\\)\\.?$",
  function() if MyDSL and MyDSL.parseImproveStatusLine then MyDSL.parseImproveStatusLine(getCurrentLine()) end end)


