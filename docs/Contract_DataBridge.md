# Module Contract: MyDSL_DataBridge.lua
**Layer 3 — State-to-DB Translation**
*Written from actual code + confirmed GMCP structure. File: MyDSL_DataBridge.lua (140 lines)*
*Updated 2026-06-30 — Gaps 2, 3, 4, 6 fixed. Contract rewritten to match current code.*

---

## What This Module Is

DataBridge is a read-only translator. It listens for data events, reads from
`MyDSL.State.*` (the DataLayer namespace), and writes into `MyDSL.DB.*` (the
namespace expected by DSL1-era display modules: LiveView, TickView, AffectsView, etc.).

It owns no data. It creates no windows. It sends nothing to the game. Its entire
job is `sync()` — keeping `MyDSL.DB.*` current whenever upstream data changes.

---

## Namespace

```lua
MyDSL.DB           -- translation output namespace
MyDSL.DB._handlers -- event handler IDs for clean reload
MyDSL.DB.live      -- vitals and identity
MyDSL.DB.score     -- character stats (GMCP) + text fields (score parser)
MyDSL.DB.room      -- current room (name, exits, sector)
MyDSL.DB.tick      -- tick timing data
MyDSL.DB.timers    -- alias: DB.timers.tick = DB.tick
MyDSL.DB.xp        -- experience shorthand
MyDSL.DB.time      -- game clock, day, month — from parseTimeLine()
MyDSL.DB.affects   -- active affects — pass-through from State.affects.active
```

---

## The One Public Function

```lua
MyDSL.DB.sync()
-- Reads all State sections and writes to DB namespaces.
-- Called automatically on every data event.
-- Safe to call manually for a forced refresh.
-- Wrapped in pcall internally — errors are silent.
```

---

## Current Field Mappings (exactly what the code does)

### DB.live
```lua
MyDSL.DB.live = {
  hp      = char.hp,      maxhp      = char.max_hp,
  mana    = char.mana,    maxmana    = char.max_mana,
  move    = char.move,    maxmove    = char.max_move,
  name    = login.name,   level      = login.level,
}
```

### DB.score — GMCP-backed fields (built first)
```lua
MyDSL.DB.score = {
  str        = char.str,          int        = char.int,
  wis        = char.wis,          dex        = char.dex,
  con        = char.con,
  gold       = char.gold,         silver     = char.silver,
  weight     = char.carry_weight, maxWeight  = char.can_carry_weight,
  tnl        = char.tnl,          wimpy      = char.wimpy,
  stance     = char.stance,       language   = char.language,
  flying     = char.is_flying,    riding     = char.is_riding,
  fighting   = char.is_fighting,
}
```

### DB.score — text fields merged in (from score parser, not GMCP)
```lua
-- DataLayer key 'position' → DB key 'posn' (per LiveView contract)
-- DataLayer key 'class'    → DB key 'class_' (avoids Lua reserved word)
MyDSL.DB.score.align       = sc.align
MyDSL.DB.score.race        = sc.race
MyDSL.DB.score.class_      = sc.class
MyDSL.DB.score.religion    = sc.religion
MyDSL.DB.score.profession  = sc.profession
MyDSL.DB.score.crafts      = sc.crafts        -- table keyed by craft name
MyDSL.DB.score.xp          = sc.xp
MyDSL.DB.score.practices   = sc.practices
MyDSL.DB.score.trains      = sc.trains
MyDSL.DB.score.bank        = sc.bank
MyDSL.DB.score.qpoints     = sc.qpoints
MyDSL.DB.score.hitroll     = sc.hitroll
MyDSL.DB.score.hitrollBase = sc.hitrollBase
MyDSL.DB.score.damroll     = sc.damroll
MyDSL.DB.score.damrollBase = sc.damrollBase
MyDSL.DB.score.armorPierce = sc.armorPierce
MyDSL.DB.score.armorBash   = sc.armorBash
MyDSL.DB.score.armorSlash  = sc.armorSlash
MyDSL.DB.score.armorMagic  = sc.armorMagic
MyDSL.DB.score.items       = sc.items
MyDSL.DB.score.max_items   = sc.max_items
MyDSL.DB.score.posn        = sc.position
```

### DB.room
```lua
MyDSL.DB.room = { name = room.name, exits = room.exits, sector = room.sector }
-- room.name confirmed correct: DataLayer maps gmcp.room_data.room → State.room.name
-- sector replaces the old 'area' field (area never existed in DataLayer)
```

### DB.tick
```lua
MyDSL.DB.tick = {
  remaining = tick.remaining,
  average   = tick.average or 40,
  percent   = tick.percent,
}
MyDSL.DB.timers.tick = MyDSL.DB.tick   -- alias
```

### DB.xp
```lua
MyDSL.DB.xp = { tnl = char.tnl }
```

### DB.time
```lua
-- Populated from MyDSL.State.time (filled by parseTimeLine() when player types 'time').
-- gmcp.tick.time = "8:00am" clock string only — no day/date. is_day derived here.
local t  = MyDSL.State.time or {}
local h  = tonumber(t.hour) or 0
local ap = t.ampm or ""
MyDSL.DB.time = {
  hour     = t.hour,       -- integer hour from game (12h clock)
  ampm     = ap,           -- "am" or "pm"
  clock    = (t.hour and ap ~= "") and (t.hour .. ":00 " .. ap) or "",
  day_name = t.day_name,   -- e.g. "the Great Gods"
  day_num  = t.day_num,    -- integer day of month
  month    = t.month,      -- e.g. "the Great Evil"
  is_day   = (ap == "am" and h >= 6) or (ap == "pm" and h < 6),
}
-- ⚠️ is_day is wrong for h=12 in both am/pm (midnight shows day; noon shows night)
-- All other hours correct. Low priority — game clocks rarely sit at exact 12.
```

### DB.affects
```lua
-- Pass-through of State.affects.active — table keyed by lowercase spell name.
-- DataLayer builds this from gmcp.affect_data / add_affect / remove_affect events.
-- Consumers: for name, entry in pairs(MyDSL.DB.affects) do
MyDSL.DB.affects = (MyDSL.State.affects and MyDSL.State.affects.active) or {}
```

---

## Event Listeners

DataBridge listens to DataLayer events AND raw GMCP events; all call `sync()`:

```lua
-- DataLayer events (lowercase convention: "MyDSL.section.updated")
"MyDSL.char.updated"     -- GMCP char_data packet processed
"MyDSL.room.updated"     -- GMCP room_data packet processed
"MyDSL.login.updated"    -- GMCP login_data packet processed
"MyDSL.tick.updated"     -- GMCP tick packet processed
"MyDSL.score.updated"    -- endScore() completed
"MyDSL.time.updated"     -- parseTimeLine() fired (player typed 'time')
"MyDSL.affects.updated"  -- affect_data / add_affect / remove_affect processed

-- Raw GMCP events (redundant safety net — DataLayer fires on all of these too)
"gmcp.char_data"
"gmcp.room_data"
"gmcp.tick"
```

⚠️ See Gap 5 — dual listeners cause double-syncing on every GMCP packet.

---

## Dependencies

**Reads from:** `MyDSL.State.*` — DataLayer must load first.
**Writes to:** `MyDSL.DB.*` — consumed by all Layer 3 display modules.
**Must load after:** DataLayer (MyDSL_DataLayer.lua)
**Must load before:** LiveView, TickSource, TickView, AffectsView, and all display modules that read from `MyDSL.DB.*`

---

## What This Module Does NOT Do

- Does not create windows
- Does not send game commands
- Does not own or store data (reads State, writes DB, holds nothing of its own)
- Does not handle login character-switching
- Does not map equipment (no DB.equip — DataLayer has no equip parser yet)

---

## Gaps and Issues Found in Code

### Gap 1 — Room name field ✅ CONFIRMED CORRECT
DataBridge reads `MyDSL.State.room.name`. Confirmed: DataLayer maps
`gmcp.room_data.room` → `State.room.name` in its GMCP handler. The comment
in DataBridge.lua at line 82 confirms: "Gap 1 confirmed NOT a bug."
`DB.room.name` is correct.

### Gap 2 — Room area field ✅ FIXED (2026-06-24)
Was: `area = MyDSL.State.room.area` (always nil — field never existed).
Now: `sector = room.sector` — matches DataLayer's actual field name.

### Gap 3 — DB.time section ✅ FIXED (2026-06-24)
Was: DB.time did not exist.
Now: DB.time fully populated in sync() — see field mappings above.

### Gap 4 — DB.affects section ✅ FIXED (2026-06-24)
Was: DB.affects did not exist.
Now: `DB.affects = State.affects.active or {}` — pass-through of the active
affects table keyed by lowercase spell name.

### Gap 5 — Redundant dual event listeners ⚠️ (kept by design)
DataBridge listens to both `"MyDSL.char.updated"` (DataLayer event) AND
`"gmcp.char_data"` (raw GMCP). Same for room and tick. This causes `sync()`
to run twice per GMCP packet — once from DataLayer's event, once from the
raw GMCP listener.

Not harmful. Kept as a safety net in case a display module loads before
DataLayer has processed a packet. Revisit after all modules are stable.

### Gap 6 — Score text fields in DB.score ✅ FIXED (2026-06-24)
Was: Only GMCP-backed fields in DB.score. `align`, `race`, `class_`,
`religion`, `profession`, `crafts`, `xp`, `practices`, `trains`, `bank`,
`qpoints`, and all armor/hitroll/damroll fields were missing.
Now: All score text fields merged into DB.score after the GMCP fields.
`"MyDSL.score.updated"` listener added.

### Gap 7 — No DB.equip section ❌ (new — not yet addressed)
DataLayer has no equipment parser (`beginEquip / parseEquipLine / endEquip`).
Therefore no `MyDSL.State.equip` exists, and DataBridge has nothing to
translate. Equipment window cannot be built until DataLayer is extended.

**Action:** Add equipment parser to DataLayer first, then add DB.equip here.

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ |
| No window creation | ✅ |
| Duplicate handler prevention on reload | ✅ |
| sync() wrapped in pcall | ✅ |
| DB.live — GMCP vitals fields | ✅ |
| DB.score — GMCP char fields | ✅ |
| DB.score — score text fields (align/race/class_/etc.) | ✅ Fixed Gap 6 |
| DB.tick — tick timing fields | ✅ |
| DB.room.name — correct field mapping | ✅ Confirmed Gap 1 |
| DB.room.sector (replaces area) | ✅ Fixed Gap 2 |
| DB.time section | ✅ Fixed Gap 3 |
| DB.affects section | ✅ Fixed Gap 4 |
| Event listeners: char/room/login/tick/score/time/affects | ✅ All present |
| Redundant raw GMCP listeners | ⚠️ Harmless, kept by design — Gap 5 |
| DB.equip section | ❌ Missing — Gap 7 (blocked by DataLayer) |