# Project Sync — 2026-06-30
*Full audit from actual file reads. Supersedes previous SYNC.md from this date.*

---

## Namespace Reality

Every `.lua` file on disk uses sub-namespaces under a single global `MyDSL` table.
`MyDSL` is created by DataLayer at load #1 (`MyDSL = MyDSL or {}`); every other
file guards with the same pattern so they are all safe to load in any order after DataLayer.

| Namespace | Owner file | What it holds |
|---|---|---|
| `MyDSL` | DataLayer | Root table; guards alive across reloads |
| `MyDSL.State.*` | DataLayer | All live game data — `char`, `login`, `room`, `tick`, `time`, `score`, `lunar`, `affects`, `flags`, `weather`, `who`, `group`, `inv`, `map`, `improve`, `unread` |
| `MyDSL.Data` | DataLayer | Per-character persistence store (`MyDSL.Data["Kien"]["score"]`, etc.) |
| `MyDSL.listeners` | DataLayer | Direct Lua callback tables for `MyDSL.on()` |
| `MyDSL._triggers` | DataLayer | `tempRegexTrigger` IDs for safe reload |
| `MyDSL._handlers` | DataLayer | `registerAnonymousEventHandler` IDs for safe reload |
| `MyDSL.DB.*` | DataBridge | Translated output consumed by DSL1-era display modules |
| `MyDSL.DB._handlers` | DataBridge | Handler IDs for safe reload |
| `MyDSL.DB.live` | DataBridge | Vitals + identity from State.char + State.login |
| `MyDSL.DB.score` | DataBridge | Stats (GMCP) + text fields (score parser) merged |
| `MyDSL.DB.room` | DataBridge | Room name, exits, sector |
| `MyDSL.DB.tick` | DataBridge | Tick timing from State.tick; also written by TickSource |
| `MyDSL.DB.time` | DataBridge | clock, day_name, day_num, month, hour, ampm, is_night — translated from State.time |
| `MyDSL.DB.affects` | DataBridge | State.affects.active pass-through |
| `MyDSL.DB.timers` | DataBridge + TickSource | Both write here; tick alias |
| `MyDSL.DB.xp` | DataBridge | TNL shorthand |
| `MyDSL.Theme.*` | ThemeEngine | Color defaults + per-window overrides |
| `MyDSL.Layout.*` | LayoutEngine | Fractional window positions + persistence |
| `MyDSL.Windows.*` | WindowRegistry | Window objects + visibility state + persistence |
| `MyDSL.Route.*` | RouteHelper | Passive routing console + API |
| `MyDSL.TickSource.*` | TickSource | Tick countdown engine + config |
| `MyDSL.LiveView.*` | LiveView | Live stat display; also writes `MyDSL.DB.room.*` fields |
| `MyDSL.Location.*` | LocationView | Room display; local `M` alias |
| `MyDSL.MoonWeather.*` | MoonWeather | Moon/time HUD; local `MW` alias |
| `MyDSL.Prompt.*` | PromptView | Prompt gag overlay |

**Both `MyDSL.State.*` and `MyDSL.DB.*` exist on disk and at runtime.**
- `MyDSL.State.*` is written exclusively by DataLayer.
- `MyDSL.DB.*` is written by DataBridge (sync from State) and also directly by
  TickSource (writes `MyDSL.DB.tick`) and LiveView (writes `MyDSL.DB.room.*` fields).
- No display module writes to `MyDSL.State.*`.

---

## Event Name Convention (actual)

**Two completely separate conventions exist in this codebase. They never cross-fire.**

### Convention 1 — DataLayer lowercase dotted
Pattern: `"MyDSL.<section>.updated"` (all lowercase, no spaces)
Raised by: `MyDSL.emit(section)` in DataLayer via `raiseEvent("MyDSL." .. section .. ".updated", ...)`

Events actually raised:
```
"MyDSL.char.updated"     -- every GMCP char_data packet
"MyDSL.login.updated"    -- every GMCP login_data packet
"MyDSL.room.updated"     -- every GMCP room_data packet
"MyDSL.tick.updated"     -- every GMCP tick packet
"MyDSL.time.updated"     -- when parseTimeLine() fires (player types 'time')
"MyDSL.score.updated"    -- when endScore() fires
"MyDSL.lunar.updated"    -- when endLunar() fires
"MyDSL.affects.updated"  -- on GMCP affect_data / add_affect / remove_affect
"MyDSL.flags.updated"    -- when endFlags() fires
"MyDSL.weather.updated"  -- when parseWeatherLine() fires (NO TRIGGER WIRED YET)
"MyDSL.who.updated"      -- when endWho() fires
"MyDSL.improve.updated"  -- when parseImproveLine() fires
"MyDSL.unread.updated"   -- when parseUnreadLine() fires
```
Consumed by: DataBridge (all sections it needs), MoonWeather (lunar/tick/time/login)

### Convention 2 — DSL1-era TitleCase
Pattern: `"MyDSL.Section.Verb"` (TitleCase words)
Raised by: TickSource, AffectsView, LiveView

Events actually raised and consumed:
```
"MyDSL.Tick.Updated"          ← TickSource raises, TickView listens ✅
"MyDSL.Tick.Pulse"            ← TickSource raises (nobody listens currently)
"MyDSL.Tick.Warning"          ← TickSource raises, TickView listens ✅
"MyDSL.Timers.Pulse"          ← TickSource raises (nobody listens)
"MyDSL.Timers.Updated"        ← TickSource raises, TickView+AffectsView+LiveView listen ✅
"MyDSL.Affects.Updated"       ← AffectsView raises (nobody listens)
"MyDSL.Live.ExitsColoredUpdated" ← LiveView raises (nobody listens)
```

### Dead subscriptions — nobody raises these
LiveView listens to these TitleCase events that NO file ever raises:
```
"MyDSL.Live.Updated"      ← dead
"MyDSL.Status.Updated"    ← dead
"MyDSL.Score.Updated"     ← dead
"MyDSL.Time.Updated"      ← dead  ← KEY: DataLayer raises "MyDSL.time.updated" (lowercase)
"MyDSL.Improve.Updated"   ← dead
"MyDSL.Progress.Updated"  ← dead
"MyDSL.Room.Updated"      ← dead  ← DataLayer raises "MyDSL.room.updated" (lowercase)
```

**LiveView only actually re-renders on `"MyDSL.Timers.Updated"` (every 0.25s from TickSource).**
Its other 7 event subscriptions are all dead. It still works because 0.25s is fast enough
that stale data is never visible. But score changes, time changes, etc. do not trigger
a targeted render — only the timer fires.

---

## Data Flow — Time (confirmed)

**Origin:** Text capture only. No GMCP field carries parsed time. `gmcp.tick.time` is a
clock-string only (`"8:00am"`) — no date, no day name. `gmcp.login_data.time` is the
login timestamp only.

**DataLayer trigger:** `tempRegexTrigger("^It is ", ...)` at DataLayer line 1124. Fires
when game sends a time-command response line. Calls `MyDSL.parseTimeLine(getCurrentLine())`.

**`parseTimeLine()` stores into `MyDSL.State.time`:**
```lua
{
  hour     = integer,   -- e.g. 9
  ampm     = string,    -- "am" or "pm"
  day_name = string,    -- e.g. "the Great Gods"
  day_num  = integer,   -- e.g. 26
  month    = string,    -- e.g. "the Great Evil"
  last_updated = integer,
}
```

**Event raised after storage:** `"MyDSL.time.updated"` (lowercase) — Convention 1.

**DataBridge.sync()** listens for `"MyDSL.time.updated"` and translates into `MyDSL.DB.time`:
```lua
{
  hour     = t.hour,
  ampm     = ap,
  clock    = (t.hour and ap ~= "") and (t.hour .. ":00 " .. ap) or "",
  day_name = t.day_name,
  day_num  = t.day_num,
  month    = t.month,
  is_night = is_night_val,
  -- is_night priority: period (from prompt, every event) > is_night trigger > GMCP clock
}
```

**MoonWeather.buildTimeRow()** reads from `MyDSL.DB.time` (correct).
Fields used: `db.clock`, `db.day_name`, `db.day_num`, `db.month`, `db.is_night`.

**Data is only available after the player manually types `time` in game.** Before that,
`MyDSL.State.time` is `{ last_updated = 0 }` and `DB.time` has nil fields everywhere.
Time row correctly shows `"-- -- --"` until first `time` command.

**No mismatch in MoonWeather.** Event subscriptions and field names are correct.
The time row will show data once the player types `time`.

---

## Module Inventory

### Files on disk (DSL2 profile root, `*.lua`)

| File | In autosave.xml? | Contract doc? | Notes |
|---|---|---|---|
| `MyDSL_DataLayer.lua` | ✅ | ✅ `Contract_DataLayer.md` | Layer 1. Working. |
| `MyDSL_DataBridge.lua` | ✅ | ⚠️ `Contract_DataBridge.md` — STALE | Contract says DB.time+DB.affects missing; actual code has both. Contract has not been updated since June 24 fix. |
| `MyDSL_ThemeEngine.lua` | ✅ | ✅ `Contract_ThemeEngine.md` | Layer 2. Working. |
| `MyDSL_LayoutEngine.lua` | ✅ | ✅ `Contract_LayoutEngine.md` | Layer 2. Working. |
| `MyDSL_WindowRegistry.lua` | ✅ | ✅ `Contract_WindowRegistry.md` | Layer 2. Working. |
| `MyDSL_RouteHelper.lua` | ✅ | ✅ `Contract_RouteHelper.md` | Layer 3. Working. |
| `MyDSL_TickSource.lua` | ✅ | ✅ `Contract_TickSource.md` | Layer 3. Working. Uses TitleCase events. |
| `MyDSL_TickView.lua` | ✅ | ✅ `Contract_TickView.md` | Layer 3. Working. Consumes TitleCase events from TickSource. |
| `MyDSL_ChatWrapper.lua` | ✅ | ✅ `Contract_ChatWrapper.md` | Layer 3. Working. |
| `MyDSL_AffectsView.lua` | ✅ | ✅ `Contract_AffectsView.md` | Layer 3. Working. |
| `MyDSL_PortraitView.lua` | ✅ | ✅ `Contract_PortraitView.md` | Layer 3. Working. |
| `MyDSL_LocationView.lua` | ✅ | ✅ `Contract_LocationView.md` | Layer 3. Working. |
| `MyDSL_LiveView.lua` | ✅ | ✅ `Contract_LiveView.md` | Layer 3. Working (renders on 0.25s timer). 7 of 8 event subscriptions are dead. |
| `MyDSL_PromptView.lua` | ✅ | ✅ `Contract_PromptView.md` | Layer 3. In autosave. |
| `MyDSL_MoonWeather.lua` | ✅ | ✅ `Contract_MoonWeather.md` | Layer 3. ✅ Feature-complete 2026-07-02. Tagged v1.2-moonweather-final. |
| `MyDSL_ChatTriggers.lua` | ❌ NOT in autosave | ❌ No contract | **Not loaded by Mudlet. Dead on disk.** |
| `MyDSL_creaturelore.lua` | ❌ NOT in autosave | ❌ No contract | **Not loaded by Mudlet. Dead on disk.** |
| `MyDSL_state.lua` | N/A (data file) | N/A | Saved state — loaded by DataLayer via table.load(), not as a script. |
| `MyDSL_layout.lua` | N/A (data file) | N/A | Saved layout — loaded by LayoutEngine via table.load(), not as a script. |

### Contracts that exist in docs/ but have no matching .lua on disk

None found. All contracts in `docs/Contract_*.md` have a corresponding `.lua` file.

### Contract accuracy issues

| Contract | Issue |
|---|---|
| `Contract_DataBridge.md` | **Stale — written pre-June-24 fix.** Says DB.time, DB.affects, score text fields, and score.updated listener are all missing. All four exist in the actual DataBridge.lua. |
| `Contract_DataLayer.md` | Minor: Gap 1 (no equipment section) still accurate. Score trigger wiring note says "must exist in Mudlet Trigger editor" — actually fixed by tempRegexTrigger in DataLayer itself. |

---

## Load Order (actual)

From `current/autosave.xml` — these are the live `dofile()` wrappers Mudlet executes at profile load.

```
#  Script name            Layer   Notes
1  MyDSL_DataLayer        1       Creates MyDSL, all State sections, tempRegexTriggers
2  MyDSL_DataBridge       3 inf   Reads State, writes DB; event handlers registered here
3  MyDSL_ThemeEngine      2       MyDSL.Theme
4  MyDSL_LayoutEngine     2       MyDSL.Layout; loads saved positions from disk
5  MyDSL_WindowRegistry   2       MyDSL.Windows; creates all windows; calls loadWindowLayout()
6  MyDSL_RouteHelper      3       MyDSL.Route
7  MyDSL_TickSource       3       MyDSL.TickSource; starts 0.25s timer; raises TitleCase events
8  MyDSL_TickView         3       Consumes MyDSL.Tick.Updated from TickSource
9  MyDSL_ChatWrapper      3       EMCO-based chat console
10 MyDSL_AffectsView      3       Consumes gmcp.affect_data directly + Timers.Updated
11 MyDSL_PortraitView     3       Consumes MyDSL.login.updated
12 MyDSL_LocationView     3       Consumes gmcp.room_data directly
13 MyDSL_LiveView         3       Consumes Timers.Updated (0.25s) + many dead subscriptions
14 MyDSL_PromptView       3       Consumes MyDSL.login.updated
15 MyDSL_MoonWeather      3       Loads LAST. Consumes lowercase DataLayer events.
```

**DataBridge loads 2nd (immediately after DataLayer), before all Layer 2 modules.**
This means DataBridge runs its `DB.sync()` before any windows exist — safe, it only reads State.

**MoonWeather loads 15th (last).** Its DataBridge dependency is satisfied. ✅

**Note:** The `MyDSL_Full.xml` package (for fresh installs) has a different order
(Layer 2 before DataBridge). The live autosave diverges from the package. The autosave
is the ground truth for what actually runs.

---

## Git State

**Branch:** `main`

**Recent commits:**
```
ca86ad8 fix: correct time row field names, event name, data source
8aacd9f fix: wire time row event and field names, add debug logging
8881e58 fix: wire time row event and field names in MoonWeather
662cdee refactor: single-label HTML table layout per contract spec
3a5a35a fix: moon slot sizing, black moon dim, time event, gag toggle
766db78 fix: add lockStyle=padding to MoonWeather container in WindowRegistry
07d461e feat: add MyDSL_MoonWeather Phase B HUD widget
c67e528 fix: wire lunar block triggers in DataLayer Section 10
```

**Uncommitted changes (not related to MoonWeather work):**
- `MyDSL/affects/Kien.lua`, `Rhaex.lua`, `Unknown.lua`, `Vhaelyr.lua` — affects data files
- `MyDSL/tickview_settings.lua`
- `MyDSL_Full/MyDSL_Full.xml`, `MyDSL_Full/config.lua` — stale Full package (not the live profile)
- `docs/TODO.md`

**All MoonWeather-related files are clean and committed.**

**All docs/Contract_*.md files are untracked by git** — they exist on disk but are
not in the repository. Only CHANGELOG.md and SYNC.md are tracked in docs/.

---

## ✅ MoonWeather — CONFIRMED WORKING (2026-06-30), ENHANCED 2026-07-01

Confirmed working in-game by Steven (screenshot 2026-06-30). All features verified:
- Three moon circles with correct focal/side sizing (red focal = larger center slot)
- Phase text and bonus line populating from `lunar` command
- Time row showing correct date with ordinal ("25th the Month of Nature") and neutral ✦
- Widget moveable and resizable via Adjustable.Container

**2026-07-01 enhancements (pending in-game validation):**
- Living DSL clock: MW.clockStr() interpolates DSL time forward in real-time between
  GMCP ticks using rate 60/82.5 DSL-min/real-sec; snaps to :00/:30 half-hour steps
- Compact stacked layout: three rows (indicator+period, clock, date) instead of one
  horizontal row; day_name truncation fixed; month strips "the " prefix
- Circle sizes reduced: focal 32pt (was 42pt), sides 18pt (was 28pt)
- Period label from prompt parser: "☀ Day Time", "✦ Night Time", "☀ Dawn"
- Day/night debug lines added to buildTimeRow() — remove after Steven confirms day_name

**Resolution history of blockers:**
- Root cause of "-- -- --": `parseTimeLine()` trigger missing from Section 10 → fixed
- Ordinal "th" instead of "25th": `ordinal()` returns suffix only; call site now prepends `db.day_num`
- `is_day` derivation from am/pm was wrong (Algoron day/night ≠ 12h clock) → removed; fixed neutral ✦
- Horizontal time row truncating day_name → replaced with stacked 3-line layout (2026-07-01)

**Remaining minor gap — weather handler unused:**
MoonWeather subscribes to `"MyDSL.weather.updated"` but has no weather display row.
The weather trigger in DataLayer has only a TODO comment — no actual trigger wired.
Deferred to Phase B+ (see Open Items below).

---

## Phase B Progress

| Module | Status |
|---|---|
| MoonWeather | ✅ Feature-complete — 2026-07-02 (tagged v1.2-moonweather-final) |
| Combat window | Not started |
| Scan/RightHere | Not started |
| Group window | Not started |
| Target window | Not started |

**MoonWeather note:** Date field re-anchors automatically via the player's existing
dawn/dusk triggers which fire `send('time')` — no calendar math needed. Clock anchors
to `gmcp.tick.time` on every tick (zero drift). All visual tweaks complete.

---

## Open Items Before Next Module

These items are not blocking Phase B but should be addressed before the next window is built:

1. ~~**Score parser: stance field**~~ — ✅ Already fixed (commit `468ee77`, Jun-29).
   `%S+` has been in place since Phase A completion. SESSION_START.md was stale.
2. ~~**Score parser: profession field**~~ — ✅ Already fixed (commit `468ee77`, Jun-29).
   Three-separator logic with `_saw_profession` flag already in DataLayer.
3. ~~**Weather trigger**~~ — ✅ Wired (this session). Broad pattern `"^[A-Z][^%.]+%.$"`
   with weather keyword guard in `parseWeatherLine()`. MoonWeather subscription
   (`"MyDSL.weather.updated"`) now receives events. Weather display row deferred to Phase B+.
4. ~~**Day/night indicator**~~ — ✅ Fully wired via prompt parser (2026-07-01).
   `State.time.period` set on every prompt from `parsePromptLine()` — most reliable source.
   Period strings confirmed: `"Night Time"`, `"Dawn"`, `"Day Time"`.
   `DB.time.is_night` priority: period (prompt) → sunrise/sunset triggers → GMCP clock.
   Secondary triggers still wired:
   - `"The sun rises in the east."` → `is_night = false` (☀)
   - `"The night has begun."` → `is_night = true` (✦)
   Note: `"* * * * * Night folds the land in shadow * * * * *"` is a cecho line — NOT triggerable.
5. **LiveView dead event subscriptions** — 7 of 8 subscriptions never fire (TitleCase
   events that nothing raises). LiveView works via 0.25s `"MyDSL.Timers.Updated"` tick.
   Low priority — functional as-is.
6. **Moon phase PNG images** — art assets not yet created. Widget shows Unicode colored
   circle fallback (●) for all moon slots. Needs 24 PNGs (8 phases × 3 moons).

---

## Recommended Next Actions

*Updated 2026-07-02 — MoonWeather feature-complete, tagged v1.2-moonweather-final.*

1. ~~**Validate time row in game**~~ — ✅ Done. Steven confirmed working 2026-06-30.
2. ~~**Remove debug logging from `buildTimeRow()`**~~ — ✅ Done (commit `d758806`).
3. ~~**Update `Contract_DataBridge.md`**~~ — ✅ Done (commit `6398094`).
4. ~~**Fix score parser issues**~~ — ✅ Already done (Jun-29). No action needed.
5. ~~**Wire weather trigger**~~ — ✅ Done. No display row yet — deferred to Phase B+.
6. ~~**Validate day/night indicator, living clock, stacked layout**~~ — ✅ MoonWeather feature-complete.

7. **Begin Phase B next window** — Combat window (BattleCondenser port) or Scan/RightHere.
   Read `Contract_MoonWeather.md` as a structural template; write Contract for the next window first.

8. **LiveView dead event subscriptions** — low priority. Works via 0.25s timer. Fix when convenient.
