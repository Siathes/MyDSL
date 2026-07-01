# Module Contract: MyDSL_DataBridge.lua
**Layer 3 — State-to-DB Translation**
*Written from actual code + confirmed GMCP structure. File: MyDSL_DataBridge.lua (81 lines)*

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
MyDSL.DB.score     -- character stats and flags
MyDSL.DB.room      -- current room
MyDSL.DB.tick      -- tick timing data
MyDSL.DB.timers    -- alias: DB.timers.tick = DB.tick
MyDSL.DB.xp        -- experience shorthand
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
  hp      = MyDSL.State.char.hp,
  maxhp   = MyDSL.State.char.max_hp,
  mana    = MyDSL.State.char.mana,
  maxmana = MyDSL.State.char.max_mana,
  move    = MyDSL.State.char.move,
  maxmove = MyDSL.State.char.max_move,
  name    = MyDSL.State.login.name,
  level   = MyDSL.State.login.level,
}
```

### DB.score
```lua
MyDSL.DB.score = {
  str      = MyDSL.State.char.str,
  int      = MyDSL.State.char.int,
  wis      = MyDSL.State.char.wis,
  dex      = MyDSL.State.char.dex,
  con      = MyDSL.State.char.con,
  gold     = MyDSL.State.char.gold,
  silver   = MyDSL.State.char.silver,
  weight   = MyDSL.State.char.carry_weight,
  maxWeight= MyDSL.State.char.can_carry_weight,
  tnl      = MyDSL.State.char.tnl,
  wimpy    = MyDSL.State.char.wimpy,
  stance   = MyDSL.State.char.stance,
  language = MyDSL.State.char.language,
  flying   = MyDSL.State.char.is_flying,
  riding   = MyDSL.State.char.is_riding,
  fighting = MyDSL.State.char.is_fighting,
}
```

### DB.room
```lua
MyDSL.DB.room = {
  name  = MyDSL.State.room.name,   -- ⚠️ see Gap 1
  exits = MyDSL.State.room.exits,
  area  = MyDSL.State.room.area,   -- ⚠️ see Gap 2
}
```

### DB.tick
```lua
MyDSL.DB.tick = {
  remaining = MyDSL.State.tick.remaining,
  average   = MyDSL.State.tick.average or 40,
  percent   = MyDSL.State.tick.percent,
}
MyDSL.DB.timers.tick = MyDSL.DB.tick   -- alias
```

### DB.xp
```lua
MyDSL.DB.xp = { tnl = MyDSL.State.char.tnl }
```

---

## Event Listeners

DataBridge listens to both MyDSL events AND raw GMCP events and calls `sync()` on any:

```lua
"MyDSL.char.updated"   -- from DataLayer event bus
"MyDSL.room.updated"   -- from DataLayer event bus
"MyDSL.login.updated"  -- from DataLayer event bus
"MyDSL.tick.updated"   -- from DataLayer event bus
"gmcp.char_data"       -- raw GMCP (redundant if DataLayer fires events)
"gmcp.room_data"       -- raw GMCP (redundant)
"gmcp.tick"            -- raw GMCP (redundant)
```

⚠️ See Gap 5 — dual listeners cause double-syncing.

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
- Does not map time, affects, or score text fields (see Gaps 3, 4, 6)

---

## Gaps and Issues Found in Code

### Gap 1 — Room name field mismatch ❌ CONFIRMED BUG
DataBridge reads `MyDSL.State.room.name`.

Confirmed GMCP: `gmcp.room_data.room = "In the Main Gathering Room..."` — the field
is `room`, not `name`. Whether DataLayer correctly maps `gmcp.room_data.room` →
`MyDSL.State.room.name` needs verification. If DataLayer stores it as `room.room`
instead, every display module gets nil for room name.

**Action:** Verify DataLayer's room_data GMCP handler. Confirm the field name
stored in `MyDSL.State.room` and align DataBridge accordingly.

### Gap 2 — Room area field wrong ⚠️
DataBridge maps `area = MyDSL.State.room.area`. DataLayer's room section has
`sector` (e.g., `"inside"`) not `area`. The `area` key is always nil.

**Fix:** Change to `sector = MyDSL.State.room.sector` in DB.room.
Or add both: `sector` for the terrain type, `area` reserved for future area name.

### Gap 3 — No DB.time section ❌
DataBridge never maps `MyDSL.State.time` to `MyDSL.DB.time`. Any display module
reading from `MyDSL.DB.time` for clock, day name, or month gets nil.

**Fix:** Add to sync():
```lua
local t = MyDSL.State.time or {}
MyDSL.DB.time = {
  hour     = t.hour,
  ampm     = t.ampm,
  clock    = t.clock or (t.hour and t.ampm and (t.hour..":00 "..t.ampm) or ""),
  day_name = t.day_name,
  day_num  = t.day_num,
  month    = t.month,
  -- Derived:
  is_day   = t.ampm and t.hour and
             ((t.ampm == "am" and t.hour >= 6) or
              (t.ampm == "pm" and t.hour < 6)),
}
-- gmcp.tick.time = "8:00am" — a clock string only, no day/night label
-- Day/night is derived here from parsed hour + ampm
```

Note: `gmcp.tick.time` confirmed as clock string only (e.g., `"8:00am"`).
Day/Night label must be derived — it is NOT available from GMCP.

### Gap 4 — No DB.affects section ❌
DataBridge never maps `MyDSL.State.affects` to `MyDSL.DB.affects`. AffectsView
and any display reading `MyDSL.DB.affects` gets nil.

**Confirmed GMCP affect structure:**
```lua
-- Individual affect fields (abbreviated keys):
{
  n  = "armor",         -- spell name
  d  = 23,             -- duration in cycles
  lc = "armor class",  -- location (lowercase)
  m  = -20,            -- modifier value
  t  = 0,              -- type integer
}
-- affect_data.affects is an ARRAY, not keyed by name
```

**Fix:** Add to sync():
```lua
MyDSL.DB.affects = MyDSL.State.affects and MyDSL.State.affects.active or {}
-- Display modules read: for name, entry in pairs(MyDSL.DB.affects) do
```

### Gap 5 — Redundant dual event listeners ⚠️
DataBridge listens to both `MyDSL.char.updated` (from DataLayer) AND `gmcp.char_data`
(raw GMCP). If DataLayer fires `MyDSL.char.updated` every time GMCP fires, `sync()`
runs twice per GMCP packet. Not harmful but wasteful.

**Options:**
- A: Remove the raw GMCP listeners — rely on DataLayer events only. Cleaner.
- B: Keep both as a safety net — in case DataLayer hasn't loaded yet. Current behavior.

**Recommendation:** Keep Option B during development. Revisit after all modules stable.

### Gap 6 — Missing score text fields in DB.score ⚠️
The score text parser populates `MyDSL.State.score` with: `align`, `race`, `class`,
`religion`, `profession`, `crafts`, `hp/mana/move`, `xp`, `practices`, `trains`,
`bank`, `qpoints`. None of these are mapped into `MyDSL.DB.score`.

Display modules that need alignment, race, class, or religion currently have no
source in `MyDSL.DB.*`.

**Fix:** Add score text fields to sync():
```lua
local sc = MyDSL.State.score or {}
-- Merge into DB.score (don't overwrite GMCP-backed fields):
MyDSL.DB.score.align     = sc.align     -- ⚠️ score parser currently broken
MyDSL.DB.score.race      = sc.race
MyDSL.DB.score.class_    = sc.class
MyDSL.DB.score.religion  = sc.religion
MyDSL.DB.score.profession= sc.profession
MyDSL.DB.score.crafts    = sc.crafts
MyDSL.DB.score.xp        = sc.xp
MyDSL.DB.score.practices = sc.practices
MyDSL.DB.score.trains    = sc.trains
MyDSL.DB.score.bank      = sc.bank
MyDSL.DB.score.qpoints   = sc.qpoints
-- Note: align only available after `score` is run and parser is fixed
-- Persists until next score run (correct behavior per design decision)
```

Also needs event handler for `MyDSL.score.updated`:
```lua
MyDSL.DB._handlers.score = registerAnonymousEventHandler("MyDSL.score.updated", onAny)
```

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ |
| No window creation | ✅ |
| Duplicate handler prevention on reload | ✅ |
| sync() wrapped in pcall | ✅ |
| DB.live — GMCP vitals fields | ✅ Correct |
| DB.score — GMCP char fields | ✅ Correct |
| DB.tick — tick timing fields | ✅ Correct |
| Room name field (room vs name) | ⚠️ Needs DataLayer verification — Gap 1 |
| Room area field (area vs sector) | ❌ Wrong field — Gap 2 |
| DB.time section | ❌ Missing entirely — Gap 3 |
| DB.affects section | ❌ Missing entirely — Gap 4 |
| Redundant dual listeners | ⚠️ Harmless, noted — Gap 5 |
| Score text fields in DB.score | ❌ Missing — Gap 6 |
| Event listener for score.updated | ❌ Missing — Gap 6 |
EOF