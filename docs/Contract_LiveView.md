# Module Contract: MyDSL_LiveView.lua
**Layer 3 — Room / Vitals / Character Summary Display**
*Written from collaborative design session, June 21 2026. Supersedes the baseline*
*contract entirely. File: MyDSL_LiveView.lua (to be substantially rewritten)*

---

## What This Module Is

LiveView is the single, comprehensive at-a-glance panel -- room, exits, identity,
combat-readiness, time, all five attributes paired with their combat stats
(mirroring DSL's own score sheet pairing), wealth, encumbrance, and four
status bars (HP/Mana/Move/Improve) with a graduated danger-color system.

No compact/full toggle. Everything is visible at once, by design. The
window is floating (not docked) with restoreLayout=true, so it can be a bit
taller than the standard bottom-strip height -- the user resizes it once and
Mudlet remembers.

This was designed iteratively with the user via interactive drag-and-drop
mockups validated against Mudlet's actual Geyser/QSS capabilities. The layout
below is the confirmed final design.

---

## Window Setup

```lua
L.ui.win = Geyser.UserWindow:new({
  name = "MyDSL_Live",
  x = defaults.x, y = defaults.y,        -- from LayoutEngine, first-run only
  width = 660, height = 230,              -- default size, in pixels
  restoreLayout = true,                    -- NOT docked -- floating, remembers position/size
})
```

Not docked=true -- per the Layer 2 addendum, only MyDSL_Scan and
MyDSL_Combat use true Mudlet docking. Live is floating, sized taller than
the standard 21%-height bottom strip to fit its content, and the user is
expected to do one one-time resize after first install.

All child elements use percentage positions relative to the window's own
width/height -- never hardcoded pixels. This was a confirmed real bug pattern
in DSL1 (LocationView used raw pixel x/y and broke at non-reference
resolutions -- see MyDSL_Audit.md item 9). Percentages scale correctly if the
user resizes the window.

---

## Layout -- 12 Content Rows + Header (confirmed final design)

Row positions as y percentage of window height (12 rows + 4 header lines,
16 lines total, each roughly 6.25% of height):

| Row | y% | Left content | Mid content | Right content |
|---|---|---|---|---|
| Room | 0% | Room name (full width, truncated) | | |
| 2 | 8% | Exits | | Kingdom . sector |
| 3 | 17% | | | Badges: ready/fighting . stance . position |
| 4 | 25% | Identity: name . level . class . alignment | | Speaking: language |
| 5 | 33% | Time/date | | HP bar |
| 6 | 42% | STR | Hit B/P/S | Mana bar |
| 7 | 50% | INT | Dam B/P/S | Move bar |
| 8 | 58% | WIS | Armor P/B/S/M | Improve bar |
| 9 | 67% | DEX | | |
| 10 | 75% | CON | Wimpy | |
| 11 | 83% | Bank/Gold/Silver | QPoints | XP . TNL |
| 12 | 92% | Items (count/max) | Weight (cur/max) | |

Column x-positions (percentage of window width):
```lua
local COL = {
  primary   = "1%",    -- room/exits/identity/time/str-con/bank/items
  secondary = "20%",   -- hit/dam/arm/wimpy/qp/weight
  tertiary  = "37%",   -- sector/speaking
  bars      = "55%",   -- HP/Mana/Move/Improve gauges, width 42%
  badge1    = "68%",   -- ready
  badge2    = "76%",   -- stance
  badge3    = "88%",   -- position
}
```

---

## Field-by-Field Data Sources

Already reliable via GMCP -- no score command needed, always fresh:
```
room name/exits  -> MyDSL.Location.roomData()  (confirmed handles "room" field correctly)
HP/Mana/Move     -> MyDSL.DB.live (char_data)
str/int/wis/dex/con -> char_data.str/int/wis/dex/con -- CONFIRMED in GMCP, not score-only
wimpy            -> char_data.wimpy -- CONFIRMED in GMCP
gold/silver      -> char_data.gold/silver -- CONFIRMED in GMCP
tnl              -> char_data.tnl -- CONFIRMED in GMCP
language(Speaking) -> char_data.language -- CONFIRMED in GMCP
weight (current/max) -> char_data.carry_weight / can_carry_weight -- CONFIRMED in GMCP
name/level/kingdom -> login_data -- CONFIRMED in GMCP
is_fighting/is_flying/is_riding -> char_data booleans -- CONFIRMED in GMCP
```

Score-text-only -- stale until score is run, persists until next run (same
pattern as alignment, by design, no auto-send):
```
class, alignment        -> score parser (Contract_DataLayer bug list -- needs fix)
HitRoll/DamRoll/Armor    -> score parser (Contract_DataLayer bug list -- needs fix)
Bank, QPoints            -> score parser (Contract_DataLayer bug list -- needs fix)
Items count (87/110)     -> score parser -- NEW FIELD, not previously parsed at all,
                           needs to be ADDED to DataLayer's score handler
XP total (not tnl)       -> score parser -- confirm DataLayer captures this
Position label (Standing)-> score's Pos'n field -- see derivation logic below
```

Derived, not directly sourced:
```
Position badge -> see deriveTextPosition() below
Day/Night not shown directly on Live (see Prompt System design) -- time line
  shows raw clock + day name + month from DB.time (DataBridge Gap 3, not yet built)
Sector/terrain ("inside") -> room.sector (confirmed GMCP field, NOT "area" --
  area name is not in GMCP at all)
```

---

## Position Derivation Logic (new, not previously specified)

```lua
local function derivePosition()
  local c = MyDSL.DB.live or {}
  if c.is_fighting then return "fighting" end
  if c.is_flying then return "flying" end
  if c.is_riding then return "riding" end
  return (MyDSL.DB.score and MyDSL.DB.score.posn) or "standing"
end
```
GMCP booleans take priority when true (instant, reliable). Falls back to the
score-parsed Pos'n: text field, defaulting to "standing" if score has never
been run. This mirrors the alignment pattern -- GMCP overrides when available,
score text fills the gap otherwise.

---

## Bar Color Logic -- Graduated Danger Thresholds

Confirmed design (from user color decisions):

| Bar | >50% | 25-50% | <25% |
|---|---|---|---|
| HP | green #50B950 | amber #EF9F27 | red #D23232 |
| Mana | dark blue #0c447c | grey-blue #5F5E5A | red #D23232 |
| Move | gold #BA7517 | orange #D85A30 | red #D23232 |
| Improve | static purple #534AB7 -- never changes | | |

```lua
local function gaugeColor(percent, kind)
  if kind == "improve" then return "#534AB7" end
  local stops = {
    hp   = { full="#50B950", mid="#EF9F27" },
    mana = { full="#0c447c", mid="#5F5E5A" },
    move = { full="#BA7517", mid="#D85A30" },
  }
  local s = stops[kind]
  if percent > 0.5 then return s.full
  elseif percent > 0.25 then return s.mid
  else return "#D23232" end
end

-- Called in render(), before each bar update:
hpGauge.front:setStyleSheet(gaugeFrontCss(gaugeColor(hpPct, "hp")))
```

This is the same front:setStyleSheet() pattern already used by TickView,
PortraitView, and the old PNP HUD -- confirmed-working Mudlet/Qt technique,
just called dynamically on every render instead of once at creation.

---

## Room Name Truncation -- Lua String Cutting, NOT CSS

Confirmed via Qt documentation: QLabel does not support text-overflow:
ellipsis. Must truncate the string itself before setting it.

```lua
local function truncate(s, maxChars)
  if not s or #s <= maxChars then return s or "" end
  return s:sub(1, maxChars - 1) .. "..."
end

-- In render():
roomLabel:echo(truncate(roomData.room, 58))  -- tune maxChars to actual rendered width
```

maxChars should be tuned empirically in-game against the actual font/window
width -- it cannot be calculated precisely from CSS alone the way a browser
would handle overflow.

---

## What This Module Does NOT Do

- Does not parse score/time/improve text itself (DataLayer's job)
- Does not send game commands
- Does not manage the mapper
- Does not route chat
- Does not use compact/full modes (explicitly removed per design decision)

---

## Dependencies

Reads from: MyDSL.DB.live, MyDSL.DB.score, MyDSL.Location.roomData(),
raw gmcp.char_data/gmcp.login_data as fallback
Must load after: DataBridge, LocationView
Window setup: Floating with restoreLayout=true, NOT docked

---

## New Gaps This Design Surfaces (add to existing DataBridge/DataLayer lists)

### DataLayer -- new score field needed
Items count ("Items: 87 (max 110)") was never parsed before. This is a
new addition to the score text parser, not a fix to an existing broken
pattern. Add alongside the other confirmed score field fixes:
```lua
-- New pattern needed:
local items, itemsMax = line:match("Items:%s*(%d+)%s*%(max%s*(%d+)%s*%)")
```

### DataBridge -- expand DB.score mapping
In addition to the previously-documented Gap 6 (align/race/class/religion/
crafts/xp/practices/trains/bank/qpoints), LiveView also needs:
```lua
MyDSL.DB.score.hitroll  = sc.hitroll   -- {b=, p=, s=}
MyDSL.DB.score.damroll  = sc.damroll   -- {b=, p=, s=}
MyDSL.DB.score.armor    = sc.armor     -- {p=, b=, s=, m=}
MyDSL.DB.score.items    = sc.items     -- {count=, max=}
MyDSL.DB.score.posn     = sc.posn      -- "Standing" etc, for derivePosition() fallback
```
Also confirm wimpy, str/int/wis/dex/con, weight, gold/silver, tnl,
language are pulled from DB.live (GMCP-backed) rather than DB.score
(text-backed) -- these are reliable without score ever being run.

### DataBridge -- DB.time still needed (existing Gap 3, now has a concrete consumer)
LiveView's time row is the first confirmed consumer of DB.time. This raises
DataBridge Gap 3's priority -- it was previously "missing but nothing
critically needs it yet." Now something does.

---

## Contract Status

| Clause | Status |
|---|---|
| Single unified view, no compact/full toggle | Confirmed design decision |
| Floating window with restoreLayout | Confirmed, not docked |
| Percentage-based child positioning (not pixels) | Confirmed, avoids known DSL1 bug pattern |
| 12-row layout with attribute/combat-stat pairing | Confirmed via iterative drag-and-drop design |
| Graduated bar color thresholds | Confirmed (HP/Mana/Move graduate to red, Improve static) |
| Room name truncation via Lua, not CSS | Confirmed necessary, verified against Qt docs |
| Position field derivation | Confirmed logic (GMCP booleans -> score fallback -> "standing") |
| GMCP vs score-text field sourcing documented | Complete |
| DataLayer: Items count parsing | New field, needs adding |
| DataBridge: hitroll/damroll/armor/items/posn mapping | New fields, needs adding |
| DataBridge: DB.time | Still missing (existing Gap 3, now higher priority) |
