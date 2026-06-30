# Module Contract: MyDSL_MoonWeather.lua
**Layer 3 Phase B — Moon, Weather & Time Display Widget**
*Written June 29, 2026 — finalized after full design session*

---

## What This Module Is

MoonWeather is a passive HUD overlay widget. It displays the three moon phases
with images, their bonuses (where available), and the current time/date. It
never sends commands, never modifies game state, and never automates anything.

It is character-aware: the player's aligned moon is the focal moon, displayed
larger and centered. Alignment is derived from `MyDSL.State.login.align` or
`MyDSL.State.score.align`.

---

## Why This Window Matters

Kien is a Druid. Moon phase directly affects mana regeneration and casting.
The red moon (neutral alignment) gives up to +15% mana, -3 saves, +3 casting
at full phase in high sanction. Having this visible at a glance without running
`lunar` repeatedly is genuinely useful during play.

The widget also serves evil and good characters equally — each sees their own
focal moon centered and prominent.

---

## Alignment → Focal Moon Mapping

```lua
-- Derived from MyDSL.State.login.align or MyDSL.State.score.align
-- DSL alignment strings (exact values to be verified against DataLayer):
local focalMoon = {
  -- Neutral alignments → red moon
  ["True Neutral"]    = "red",
  ["Neutral Good"]    = "red",   -- verify
  ["Neutral Evil"]    = "red",   -- verify
  -- Good alignments → white moon
  ["Lawful Good"]     = "white",
  ["Neutral Good"]    = "white", -- verify exact string
  ["Chaotic Good"]    = "white",
  -- Evil alignments → black moon
  ["Lawful Evil"]     = "black",
  ["Neutral Evil"]    = "black", -- verify exact string
  ["Chaotic Evil"]    = "black",
}
-- Fallback if align not yet loaded: default to "red"
```

**Note:** The exact alignment strings from DSL's login/score GMCP need
verification against DataLayer output. Claude Code should check
`MyDSL.State.login.align` and `MyDSL.State.score.align` field names and
values, and adjust the mapping table accordingly. Neutral = red is confirmed
for Kien. Good = white and Evil = black are confirmed by game lore.

---

## Data Sources

### Moon data — text capture via DataLayer

`MyDSL.State.lunar` is populated when the player runs `lunar` (or `l moons`).
DataLayer already has `beginLunar()`, `parseLunarLine()`, `endLunar()`.

**Critical game mechanic understood from actual output:**
- The `lunar` command shows phase + position for ALL three moons
- The bonus stat block (`[Mana ...] [Saves ...] ...`) appears ONLY for the
  player's aligned (focal) moon, and ONLY if their Astrology skill is high
  enough to read it
- Non-focal moons: phase and position text only, never a bonus block
- Low astrology: focal moon phase/position shown, bonus block absent

```lua
-- MyDSL.State.lunar structure after parsing:
MyDSL.State.lunar = {
  red = {
    phase      = "empty",          -- exact phase string from game
    position   = "not visible",    -- "rising", "high sanction", "setting", "not visible"
    -- bonus fields only present if this is focal moon AND astrology high enough:
    mana_bonus       = 0,          -- integer, may be 0 or negative
    saves_modifier   = 0,
    casting_modifier = 0,
    regen_pct        = 0,
    cycles_remaining = 38,
    hours_remaining  = 19,         -- parsed from "19 1/2 Hours" → 19
    has_bonuses      = false,      -- true only if bonus block was parsed
  },
  white = {
    phase    = "waxing three-quarters",
    position = "not visible",
    has_bonuses = false,
  },
  black = {
    phase    = "half waxing",
    position = "setting",
    has_bonuses = false,
  },
  last_updated = 0,   -- os.time() when last parsed
}
```

**Actual game output samples (confirmed):**

Evil character (low astrology — sees all three moons, no bonus block):
```
The black moon is half waxing and setting.
The red moon is not visible.
The white moon is waxing three-quarters and in high sanction.
```

Kien / neutral character (full astrology — bonus block for aligned moon):
```
The red moon is empty and not visible.
   [Mana   0%]  [Saves  0]  [Casting  0]  [Regen   0%]  [Cycles remaining 38 (19 1/2 Hours)]
The white moon is waxing three-quarters and not visible.
```

Note: Kien's output above does not show the black moon line — this may mean
the black moon is only visible in the output when it has a non-trivial position,
or it may be a parsing gap. Claude Code should handle black moon being absent
from `MyDSL.State.lunar` gracefully.

### Weather data — text capture via DataLayer

`MyDSL.State.weather` populated passively from weather description lines in
the game stream.

```lua
MyDSL.State.weather = {
  description  = "The gentle patter of waves brushing against the shore surrounds you.",
  last_updated = 0,
}
```

Future expansion: capture `weather` command output for sky condition images
(clouds, rain). Not in scope for this version — noted for Phase B+.

### Time of day — from GMCP tick

`MyDSL.State.tick.time` — string e.g. `"Night Time"`, `"Day Time"`, `"Dawn"`.
Updated on every tick via GMCP.

### Game date — from DataLayer time parser

`MyDSL.State.time.date` or equivalent — full DSL date string e.g.
`"26th the Month of the Great Evil"`. Display unabbreviated.
Claude Code should verify the exact field name in DataLayer.

---

## Window Specification

**Window name:** `MyDSL_MoonWeather`
**Window type:** `Adjustable.Container`
**Lock style:** `lockStyle = "padding"` — invisible resize zone. No visible
  border or edge lines. Clean HUD overlay appearance.
**Moveable/resizable:** Yes — user can drag and resize at runtime.
**AutoSave:** `container:setAutoSave(true)` — position saves automatically.
**AutoLoad:** `container:setAutoLoad(true)` — restores last position on init.

**Default position (first run only):**
From `MyDSL.Layout.get("MyDSL_MoonWeather")` → LayoutEngine default is
`x=0.66, y=0.00, w=0.34, h=0.08`. If Layout returns nil, fall back to
`x="66%", y="0%", w="34%", h="10%"`.

**Contents:** One `Geyser.Label` at 100%×100% inside the container.
All content rendered via `label:echo(html)` with inline HTML/CSS.

---

## Layout — Three Sections (top to bottom)

### Section 1 — Moon Images (top row)

Three moon image slots across the top of the widget. Square images.
**Moon images are always shown regardless of time of day — day/night is
indicated separately in the time row (Section 3), not by replacing moon slots.**

```
[ white moon ]  [ RED MOON (focal) ]  [ black moon ]
  small             larger              small
```

Slot sizing (relative to widget width):
- Side moons (non-focal): each ~20% of widget width, square
- Focal moon (center): ~30% of widget width, square (≈1.5x the side moons)
- The three slots together span the full widget width with small gaps

**For Kien (neutral → red focal):**
- Left slot: white moon image (small)
- Center slot: red moon image (larger, 1.5x)
- Right slot: black moon image (small)

**For evil character (black focal):**
- Left slot: red moon image (small)
- Center slot: black moon image (larger, 1.5x)
- Right slot: white moon image (small)

**For good character (white focal):**
- Left slot: black moon image (small)
- Center slot: white moon image (larger, 1.5x)
- Right slot: red moon image (small)

**Image files:** Located at `getMudletHomeDir() .. "/DSL2/moon_phases/"`.

File naming convention:
```
moon_red_full.png
moon_red_three_quarter_waning.png
moon_red_half_waning.png
moon_red_crescent_waning.png
moon_red_empty.png
moon_red_crescent_waxing.png
moon_red_half_waxing.png
moon_red_three_quarter_waxing.png
moon_white_full.png          (same 8 for white)
moon_black_full.png          (same 8 for black)
```

Total image files: 26
- 24 moon phase images (8 phases × 3 colors)
- `sun_small.png` — day/dawn/dusk indicator for time row
- `night_sky.png` — night indicator for time row

**Fallback if PNG missing:** Display a large Unicode colored circle in the
image slot. Phase shape is NOT encoded in the Unicode fallback — the image
itself is expected to communicate phase visually for side moons. The focal
moon's phase text in Section 2 covers the focal moon.

```
Red moon:   ● (colored #cc4444, large)
White moon: ● (colored #dddddd, large)
Black moon: ● (colored #444444, large)
```

Image loading: use `label:setStyleSheet("background-image: url('" .. path .. "');
background-repeat: no-repeat; background-position: center; background-size: contain;")`
to display PNG in a label. Check file exists with `io.open(path, "r")` before
setting — if nil, use Unicode fallback colored circle.

### Section 2 — Bonus / Phase Text (middle row, focal moon only)

Text appears below the **focal moon center slot only**. Side moon slots
have **no text** — their images communicate the phase visually.

**Focal moon with full astrology (has_bonuses=true, after `lunar` run):**
```
Half Waxing · Not Visible
+10%M  -2Sv  +2Cs  Regen+0%  38cy/19h
```
Phase + position on first line. Full bonus line including regen/cycles/hours.

**Focal moon with low/no astrology (has_bonuses=false, but phase is known):**
```
Half Waxing · Not Visible
+10%M  -2Sv  +2Cs
```
Phase + position on first line. Mana/saves/casting derived from wiki table
(always available from phase). Regen/cycles/hours omitted — require bonus block.

**No lunar data yet (never run `lunar` this session):**
```
?
```
Single dim grey question mark. Shown for focal slot only.

**Side moon slots:** No text at all. Images carry the phase information.

**Black moon slot for non-evil characters:** No text, dark dim image only.
Not "?" — simply not visible to this character (permanent game mechanic).

### Section 3 — Time Row (bottom)

Single line across the full widget width:

```
[☀/🌙 img]  Night Time   ·   It is 10:00 pm   ·   26th the Month of the Great Evil
```

A small square image (or Unicode fallback) sits at the left of the time row
as a day/night indicator, followed by the time fields.

**Day/night indicator image files** (in same `/DSL2/moon_phases/` folder):
```
sun_small.png    — used for: Day Time, Dawn, Dusk
night_sky.png    — used for: Night Time
```

Mapping:
- `"Day Time"` → `sun_small.png`
- `"Dawn"`     → `sun_small.png`
- `"Dusk"`     → `sun_small.png`
- `"Night Time"` → `night_sky.png`
- anything else / nil → Unicode fallback

Unicode fallbacks:
- Day/Dawn/Dusk: `☀` colored `#ffdd44`
- Night: `✦` colored `#8888cc` (or `★`)

Time fields separated by dim ` · ` separators:
- Time of day text: colored by period (see Color Scheme)
- Clock time: from `MyDSL.State.tick` or `MyDSL.State.time` — `#cccccc`
- Full date string: from DataLayer time parser — `#999999`, unabbreviated

If time data not yet loaded: show `--` for each field.

Total additional images: 2 files (`sun_small.png`, `night_sky.png`).

---

## Phase String → Image Filename Mapping

The game outputs these exact phase strings (confirmed from help text):

```lua
local phaseToFile = {
  ["full"]                    = "full",
  ["waning three-quarters"]   = "three_quarter_waning",
  ["waning half"]             = "half_waning",       -- verify exact string
  ["half waning"]             = "half_waning",       -- alternate form
  ["waning crescent"]         = "crescent_waning",   -- verify
  ["crescent waning"]         = "crescent_waning",   -- alternate form
  ["empty"]                   = "empty",
  ["waxing crescent"]         = "crescent_waxing",   -- verify
  ["crescent waxing"]         = "crescent_waxing",   -- alternate form
  ["waxing half"]             = "half_waxing",       -- verify
  ["half waxing"]             = "half_waxing",       -- confirmed from evil char sample
  ["waxing three-quarters"]   = "three_quarter_waxing", -- confirmed from evil char sample
  ["three-quarter waxing"]    = "three_quarter_waxing", -- alternate form
}
```

**Note:** The game uses inconsistent word order in phase strings (sometimes
"waxing three-quarters", sometimes "three-quarters waxing"). The mapping table
must handle both forms. Claude Code should map all known variants.

---

## Phase Display Abbreviations (for text in Section 2)

| Game phase string | Display text |
|---|---|
| full | Full |
| waning three-quarters / three-quarter waning | 3/4 Waning |
| waning half / half waning | Half Waning |
| waning crescent / crescent waning | Cres Waning |
| empty | Empty |
| waxing crescent / crescent waxing | Cres Waxing |
| waxing half / half waxing | Half Waxing |
| waxing three-quarters / three-quarter waxing | 3/4 Waxing |

---

## Color Scheme

| Element | Color |
|---|---|
| Red moon symbol/label | `#cc4444` |
| White moon symbol/label | `#dddddd` |
| Black moon symbol/label | `#888888` |
| Sun symbol | `#ffdd44` |
| Mana bonus positive | `#44cc44` (green) |
| Mana bonus negative | `#cc4444` (red) |
| Saves modifier (negative = good) | `#44cc44` |
| Saves modifier (positive = bad) | `#cc4444` |
| Casting modifier (positive = good) | `#44cc44` |
| Casting modifier (negative = bad) | `#cc4444` |
| High sanction | `#ffdd00` (gold) |
| Rising / Setting | `#aaaaaa` (grey) |
| Not visible | `#555555` (dim) |
| Day Time | `#ffdd88` (warm yellow) |
| Night Time | `#8888cc` (cool blue-purple) |
| Dawn | `#dd8844` (orange) |
| Dusk | `#dd8844` (orange) |
| Phase text (non-focal) | `#888888` (grey) |
| Weather text | `#777777` (subdued grey) |
| Separator · | `#444444` (dim) |
| Date text | `#999999` (grey) |
| Clock time | `#cccccc` (near white) |

---

## Label Stylesheet

Applied to the inner `Geyser.Label` (not the container):

```lua
label:setStyleSheet(string.format([[
  background-color: rgba(5, 8, 20, %d);
  border: none;
  border-radius: 4px;
  padding: 3px 6px;
  font-family: "%s";
  font-size: %dpt;
  color: #cccccc;
]], MW.config.opacity, MW.config.font, MW.config.fontSize))
```

---

## Event Subscriptions

```lua
-- All stored in MyDSL.MoonWeather._handlers for clean deregistration on reload
registerAnonymousEventHandler("MyDSL.lunar",   "MyDSL.MoonWeather.onLunarUpdate")
registerAnonymousEventHandler("MyDSL.weather", "MyDSL.MoonWeather.onWeatherUpdate")
registerAnonymousEventHandler("MyDSL.tick",    "MyDSL.MoonWeather.onTickUpdate")
registerAnonymousEventHandler("MyDSL.login",   "MyDSL.MoonWeather.onLoginUpdate")
```

`onLoginUpdate` is needed to detect character alignment on login and set the
focal moon correctly before `lunar` has been run.

All four handlers call `MyDSL.MoonWeather.render()`.

---

## Config Table

```lua
MyDSL.MoonWeather.config = {
  shown    = true,
  font     = "DejaVu Sans Mono",
  fontSize = 9,       -- pt, default small/compact
  opacity  = 210,     -- background alpha 0-255
}
```

Config is NOT separately persisted — position is handled by Adjustable.Container
AutoSave, and visual config (font/opacity) defaults are acceptable to reset on
reload. A future enhancement could save config to a file.

---

## Public API

```lua
MyDSL.MoonWeather.init()          -- create container+label, register all handlers,
                                  -- autoload position, render. Safe to call on reload.
MyDSL.MoonWeather.render()        -- rebuild HTML and call label:echo()
MyDSL.MoonWeather.show()          -- show container, save shown=true
MyDSL.MoonWeather.hide()          -- hide container, save shown=false
MyDSL.MoonWeather.toggle()        -- flip shown state
MyDSL.MoonWeather.focalMoon()     -- returns "red"/"white"/"black" based on align
MyDSL.MoonWeather.phaseImage(color, phase)  -- returns full PNG path or nil if missing
MyDSL.MoonWeather.onLunarUpdate()
MyDSL.MoonWeather.onWeatherUpdate()
MyDSL.MoonWeather.onTickUpdate()
MyDSL.MoonWeather.onLoginUpdate()
```

---

## Aliases

```
mydsl moon toggle       → MoonWeather.toggle()
mydsl moon on           → MoonWeather.show()
mydsl moon off          → MoonWeather.hide()
mydsl moon font <n>     → set config.fontSize = n, re-apply stylesheet, render()
```

Alias patterns are `tempAlias` registered in `init()`, stored in
`MyDSL.MoonWeather._aliases`, killed and re-registered on reload.

---

## Gag Triggers

Registered via `tempRegexTrigger` in `init()`, stored in
`MyDSL.MoonWeather._triggers`, killed and re-registered on reload.

```lua
-- Gag moon description lines from main console:
-- "The red moon is full and not visible."
-- "The black moon is half waxing and setting."
tempRegexTrigger("^The (red|white|black) moon is", function() deleteLine() end)

-- Gag bonus stat lines:
-- "   [Mana   0%]  [Saves  0]  [Casting  0]  ..."
tempRegexTrigger("^%s+%[Mana", function() deleteLine() end)
```

DataLayer's parse functions fire before `deleteLine()` because DataLayer
triggers are registered at profile load (earlier). The gag fires after
DataLayer has already captured the data.

---

## init() Sequence (order matters)

```
1. Kill all existing _handlers, _triggers, _aliases (safe reload)
2. Create Adjustable.Container with lockStyle="padding"
3. Call container:setAutoSave(true), container:setAutoLoad(true)
4. Create Geyser.Label inside container at 100% x 100%
5. Apply label stylesheet
6. Register event handlers → store IDs in _handlers
7. Register gag triggers → store IDs in _triggers
8. Register aliases → store IDs in _aliases
9. Call render() — draws placeholder state if no data yet
```

---

## render() Logic (pseudocode)

```
focal = focalMoon()   -- "red", "white", or "black"
isDay = tick.time in {"Day Time", "Dawn", "Dusk"}

-- Determine slot order:
-- focal=red:   left=white, center=red,   right=black
-- focal=black: left=red,   center=black, right=white
-- focal=white: left=black, center=white, right=red

-- Section 1 (moon images — always three moons, never replaced by sun):
--   For each slot: phaseImage(color, phase) → PNG path or nil
--   If PNG exists: render as background-image on a label
--   If PNG missing: render Unicode colored circle fallback
--   Center slot is larger (1.5x side slots)

-- Section 2 (text — focal moon center slot ONLY, side slots empty):
--   if no lunar data → show "?"
--   if has_bonuses=true → show "Phase · Position" line + bonus line
--   if has_bonuses=false → show "Phase · Position" line only

-- Section 3 (time row):
--   indicator = isDay and sun_small.png or night_sky.png
--   if image missing → Unicode fallback (☀ or ✦)
--   render: [indicator img] TimeOfDay · ClockTime · FullDate

-- Assemble as HTML using a table layout or nested div-like spans
-- Call label:echo(html)
```

---

## What This Module Does NOT Do

- Does not send any commands (no auto-`lunar`, no auto-`weather`, no auto-`time`)
- Does not modify DataLayer state directly
- Does not create timers to auto-refresh moon data
- Does not interact with combat, mapper, or other windows
- Does not display affects, stats, inventory, or any non-moon/weather/time data
- Does not automate gameplay of any kind

---

## Wiki-Confirmed Reference Data

### Moon Phase Bonus Table (from DSL wiki)
These values are authoritative — display them for the focal moon based on
phase even without an astrology bonus block. The bonus block (from `lunar`)
adds regen%, cycles, and hours which cannot be derived from phase alone.

| Phase | Mana | Saves | Cast Lvl |
|---|---|---|---|
| Full Moon | +15% | -3 | +3 |
| Three-Quarter Moon, Waning | +10% | -2 | +2 |
| Half Moon, Waning | +10% | -2 | +2 |
| Crescent Moon, Waning | +5% | -1 | +1 |
| Empty Moon | 0% | 0 | 0 |
| Crescent Moon, Waxing | +5% | -1 | +1 |
| Half Moon, Waxing | +10% | -2 | +2 |
| Three-Quarter Moon, Waxing | +10% | -2 | +2 |

**Implication for display:** If the character's astrology is too low to show
the bonus block in `lunar` output (has_bonuses=false), we can still show the
mana/saves/casting values from this table based on the known phase. Only
regen%, cycles remaining, and hours remaining require the actual bonus block.
This makes the widget useful for all mage characters regardless of astrology skill.

### Position Regen Table (from DSL wiki)
| Position | Regen |
|---|---|
| rising | +25% |
| high sanction | +50% |
| setting | +25% |
| not visible | 0% (exception: Empty Moon always gets +25%) |

### Moon Phase Durations (from DSL wiki)
- Black moon: 66 ticks per phase
- Red moon: 90 ticks per phase
- White moon: 108 ticks per phase

### Calendar Structure (from DSL wiki)
- 17 months, each with 5 weeks of 7 days (35 days/month)
- Real time: 1 day = 33 minutes, 1 month = 19h 15m, 1 year = 13 days 15 minutes
- Days of week: Bull, Deception, Thunder, Freedom, Great Gods, Sun, Moon
- 17 months (in sequence): Old Forces, Grand Struggle, Spring, Nature,
  Futility, Dragon, Sun, Heat, Battle, Dark Shades, Shadows, Long Shadows,
  Ancient Darkness, Great Evil, Winter, Winter Wolf, Frost Giant

Full date format from game: `"It is 10:00 o'clock am, Day of the Great Gods, 26th the Month of the Great Evil."`
Display in widget time row as-is (already a complete readable string from DataLayer's `parseTimeLine`).

### Gap 1 — Lunar data only updates on player action
No GMCP for moon data. Window shows last-known data between `lunar` runs.
Acceptable by observer philosophy — player runs `lunar` when they care.
Auto-run on tick would violate passive observer rules.

### Gap 2 — Phase strings need in-game verification
The phaseToFile mapping covers known variants from help text and two sample
outputs. Additional phase string formats may exist. Claude Code should handle
unknown phase strings gracefully — log a warning and use the Unicode fallback.

### Gap 3 — Black moon not visible to neutral/good chars (confirmed permanent)
Wiki confirms: "The white and red moons may be seen by anyone, the black moon
may only be seen by those of evil alignment." This is a permanent game mechanic,
not a parsing gap. For Kien and all neutral/good characters, `MyDSL.State.lunar.black`
will always be nil — the black moon line never appears in their `lunar` output.

Widget behavior for non-evil characters:
- Black moon image slot: show `moon_black_empty.png` or Unicode ● in `#333333`
  (very dark, indicating invisible/inaccessible)
- No phase text below the slot — the moon simply isn't visible to this character
- This is permanent, not a "run lunar first" state

For evil characters: black moon is the focal moon, shown centered and larger.

### Gap 4 — Weather images (future)
A future Phase B+ enhancement: capture the `weather` command output and
display sky condition images (cloud.png, rain.png, clear.png etc.) in a
fourth section or as a background layer. Not in scope for this version.

### Gap 5 — Alignment string verification
The exact strings in `MyDSL.State.login.align` need verification against
live DataLayer output with Kien. The focal moon mapping table should have
a verified fallback.

---

## DataLayer Dependency Check

Before building the module, Claude Code must verify these DataLayer functions
are wired with triggers in `MyDSL_DataLayer.lua` Section 10:

| Function | Trigger pattern | Status |
|---|---|---|
| `MyDSL.beginLunar()` | `^The (red\|white\|black) moon is` | ⚠️ Verify |
| `MyDSL.parseLunarLine()` | catch-all during lunar block | ⚠️ Verify |
| `MyDSL.endLunar()` | blank line ends block | ⚠️ Verify |
| `MyDSL.parseWeatherLine()` | passive weather lines | ⚠️ Verify |

If missing, add using the same `tempRegexTrigger` pattern as the score trigger.
Commit that fix separately before building the module.

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ By design |
| No gameplay automation | ✅ By design |
| Adjustable.Container, lockStyle="padding" | Must implement |
| AutoSave / AutoLoad position | Must implement |
| Geyser.Label inside, HTML content | Must implement |
| Three moon slots always visible, never replaced by sun | Must implement |
| Focal moon centered, 1.5x larger than side moons | Must implement |
| Side moons: image only, no text | Must implement |
| Focal moon: phase+position text, bonus line if has_bonuses=true | Must implement |
| PNG images with Unicode colored-circle fallback | Must implement |
| Day/night indicator image in time row (sun_small / night_sky) | Must implement |
| Dawn/Dusk reuse sun_small.png | Must implement |
| All three moons always shown (incl. black) | Must implement |
| Time / clock / full date row | Must implement |
| Alignment → focal moon mapping | Must implement |
| onLogin handler to set focal moon on connect | Must implement |
| Font / opacity configurable via config table | Must implement |
| Toggle alias (mydsl moon on/off/toggle) | Must implement |
| Font size alias (mydsl moon font N) | Must implement |
| Gag triggers owned by module, stored in _triggers | Must implement |
| All handlers stored in _handlers, cleaned on reload | Must implement |
| Graceful nil/empty state (? for focal, image-only for sides) | Must implement |
| Unknown phase string → warning + Unicode fallback | Must implement |

---

## Implementation Notes — 2026-06-30

These notes record confirmed field names and event names that differ from what
the contract spec stated above. They take precedence where they conflict.

### Event subscriptions (corrected)

The contract lists event names without `.updated` suffix (e.g. `"MyDSL.lunar"`).
**All actual DataLayer events use the `.updated` suffix.** The correct names are:

```
"MyDSL.lunar.updated"
"MyDSL.weather.updated"
"MyDSL.tick.updated"
"MyDSL.time.updated"
"MyDSL.login.updated"
```

These are what `_registerHandlers()` subscribes to.

### `MyDSL.State.time` field names (confirmed)

`parseTimeLine()` in DataLayer stores:

```lua
{
  hour     = tonumber,   -- integer hour (e.g. 9)
  ampm     = string,     -- "am" or "pm"
  day_name = string,     -- e.g. "the Great Gods"
  day_num  = tonumber,   -- integer day-of-month (e.g. 26)
  month    = string,     -- e.g. "the Great Evil"
}
```

The contract referenced `MyDSL.State.time.date` — **this field does not exist.**
Date is constructed by `buildTimeRow()` from `day_num` + `month`:
`string.format("%d%s the Month of %s", day_num, ordinal(day_num), month)`

### `MyDSL.State.tick.time` (corrected)

The contract described `tick.time` as a "time of day string." It is actually
a **GMCP clock string** of the form `"8:00am"` — not a period descriptor like
`"Night Time"`, `"Day Time"`, `"Dawn"`, or `"Dusk"`. Those period strings
appear in the game prompt (line 2) but are not captured by any current parser.

`buildTimeRow()` derives day/night from `timeData.ampm` (`"am"` = daytime).
This approximation is correct for most of the game clock. Dawn/Dusk
transitions are not distinguishable from this field alone.

### Root cause of "-- -- --" time row (fixed 2026-06-30)

`parseTimeLine()` was defined in DataLayer but had no `tempRegexTrigger` wired
to it in Section 10. The trigger comment existed; the trigger code did not.

Fix: added to Section 10 of `MyDSL_DataLayer.lua`:
```lua
MyDSL._triggers.timeLine = tempRegexTrigger(
  "^It is ",
  function()
    if MyDSL and MyDSL.parseTimeLine then
      MyDSL.parseTimeLine(getCurrentLine())
    end
  end
)
```

Pattern `"^It is "` matches both confirmed time-line formats:
- `"It is 9:30 am, Day of ..."`
- `"It is 10:00 o'clock am, ..."`
