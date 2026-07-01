# Module Contract: MyDSL_TickSource.lua
**Layer 3 — Tick Timing Authority**
*Written from actual code. File: MyDSL_TickSource.lua (249 lines)*
*Ported from PNP DSL_PNP_Ticktimer.lua with adjustments.*

---

## What This Module Is

TickSource is the single authority on tick timing. It listens to `gmcp.tick`,
maintains a smoothed average tick interval, drives a 0.25-second real-time
countdown, and publishes results to `MyDSL.DB.tick`. It raises events that
TickView and any other module can listen to. It has no display code.

Think of it as the clock. TickView is the clock face.

---

## Namespace

```lua
MyDSL.TickSource           -- the module
MyDSL.TickSource.config    -- configurable parameters
MyDSL.TickSource.state     -- live runtime state
MyDSL.DB.tick              -- published output (read by TickView and others)
```

---

## Configuration

```lua
MyDSL.TickSource.config = {
  average   = 40,    -- starting assumed tick interval in seconds
  window    = 5,     -- smoothing acceptance window in seconds
  increment = 0.25,  -- timer resolution in seconds
  warnTime  = 5,     -- seconds remaining to fire warning event ⚠️ Gap 1: unused
  closeTime = 15,    -- seconds remaining for "close" visual state ℹ️ Gap 6: unused
}
```

Aliases to adjust at runtime:
```
mydsl tick average <10-120>   -- change assumed average
mydsl tick window <1-30>      -- change smoothing window
mydsl tick debug on|off       -- verbose debug output
mydsl tick reset              -- reset to configured defaults
mydsl tick status             -- print current state
```

---

## The Smoothing Algorithm (from PNP)

On each real game tick, the measured interval (`current` seconds elapsed) is
compared to the running average. If it falls within `window` seconds of the
average, exponential smoothing applies:

```lua
new_avg = 0.9 * old_avg + 0.1 * measured
-- 90% weight on historical average, 10% on new measurement
```

If the measured interval is outside the window (server lag, reconnect, etc.),
the average resets to the configured default. This prevents a single bad tick
from distorting the average.

---

## Events Raised

| Event | When |
|---|---|
| `MyDSL.Tick.Pulse` | Every real game tick (`gmcp.tick` fires) |
| `MyDSL.Tick.Updated` | Every 0.25-second countdown step |
| `MyDSL.Timers.Pulse` | Every 0.25-second step (shared timer bus) |
| `MyDSL.Tick.Warning` | When remaining hits `warnTime` seconds ❌ Gap 1: not yet implemented |

---

## DB.tick Fields (published every 0.25 seconds)

```lua
MyDSL.DB.tick = {
  running      = bool,    -- is the ticker active
  ticks        = number,  -- total game ticks this session
  current      = number,  -- seconds elapsed since last tick
  remaining    = number,  -- estimated seconds until next tick
  average      = number,  -- smoothed average interval
  configured   = number,  -- manually configured average
  window       = number,  -- current smoothing window
  increment    = number,  -- timer resolution (0.25)
  percent      = number,  -- remaining/average as 0–1 fraction
  source       = string,  -- "gmcp.tick"|"timer"|"reset"|"boot"|"expired"
  lastMeasured = number,  -- last measured tick interval in seconds
  lastTickAt   = number,  -- epoch timestamp of last tick
  reason       = string,  -- why this publish was triggered
  updatedAt    = number,  -- epoch timestamp of this publish
  version      = string,  -- module version string
}
```

---

## GMCP Events Listened To

```lua
"gmcp.tick"   -- primary (confirmed format: { time = "8:00am" })
"gmcp.Tick"   -- capitalization variant for compatibility
"onTick"      -- legacy event name
```

All three call `T.onGameTick()`. Multiple names handled for safety.

---

## The Timer Loop

`T.loop()` creates a self-rescheduling `tempTimer` chain at 0.25-second intervals.
Each step calls `T.updateTimer()` which increments `current` and publishes.

```
boot() → loop() → step() → updateTimer() → publish() → tempTimer(0.25, loop)
                                                              ↑ repeats forever
```

The loop auto-expires if `current > average + 5` (tick is 5 seconds overdue),
setting `running = false` and `source = "expired"`. The countdown still updates
but indicates the tick is late.

---

## Dependencies

**Reads:** `gmcp.tick` (GMCP event), `getEpoch()`, `os.time()` — Mudlet built-ins
**Writes:** `MyDSL.DB.tick` — consumed by TickView and any module needing tick data
**Raises events consumed by:** TickView, any module needing tick timing
**Must load after:** DataLayer (for `MyDSL` namespace), DataBridge (for `MyDSL.DB`)
**Must load before:** TickView

---

## What This Module Does NOT Do

- Does not display anything
- Does not send game commands
- Does not read from DataLayer state sections
- Does not know about game time (hours, day/night) — that is DataLayer's job

---

## Gaps and Issues Found in Code

### Gap 1 — warnTime defined but never used ❌ THE KNOWN BUG
`T.config.warnTime = 5` and `T.state.lastWarnSecond` are defined, and
`lastWarnSecond` is reset to nil on each tick. But **nothing fires when remaining
hits 5 seconds.** The warning logic is absent from `updateTimer()`.

This is the confirmed broken "5-second alert" from the backlog.

**Fix:** Add to `T.updateTimer()`:
```lua
local rem = math.floor(T.state.remaining or 0)
local warn = tonumber(T.config.warnTime) or 5
if T.state.running and rem == warn and T.state.lastWarnSecond ~= rem then
  T.state.lastWarnSecond = rem
  safeRaise("MyDSL.Tick.Warning", rem)
end
```

TickView listens to `MyDSL.Tick.Warning` to flash the display and optionally
play a sound. The `warn` threshold is configurable via `T.config.warnTime`.

### Gap 2 — No handler deregistration on reload ⚠️
DataBridge has `deregisterHandlers()` to prevent duplicate handlers on reload.
TickSource does not. The `T.handlersInstalled` flag prevents new registrations
on reload, but old handlers from previous loads are never killed.

During development (frequent reloads), old handlers accumulate silently.
After N reloads, N copies of `onGameTick()` fire per tick.

**Fix:** Add handler ID tracking and deregistration at boot:
```lua
function T.deregisterHandlers()
  if T.handlers then
    for _, id in ipairs(T.handlers) do pcall(killAnonymousEventHandler, id) end
  end
  T.handlers = {}
  T.handlersInstalled = false
end
-- Call at top of T.boot()
```

### Gap 3 — Timer loop multiplies on reload ⚠️
`T.loop()` starts a `tempTimer` chain. On reload, `T.looping` may be false
(reset mid-step), allowing a second loop to start alongside the first. Over
multiple reloads, parallel loops accumulate, causing multiple publishes per
0.25-second step and inflated `current` values.

**Fix:** Add a loop generation counter:
```lua
T.generation = (T.generation or 0) + 1
local myGen = T.generation
local function step()
  if T.generation ~= myGen then return end  -- abort if superseded
  T.looping = false
  T.updateTimer()
  tempTimer(T.config.increment, function() T.loop() end)
end
```

### Gap 4 — closeTime defined but unused ℹ️
`T.config.closeTime = 15` exists but nothing uses it. Originally intended for
a "closing" visual state in TickView (e.g., display turns amber when less than
15 seconds remain). TickView should read `MyDSL.DB.tick.remaining <= closeTime`
to apply close-state styling. No code change needed in TickSource — just
document that TickView should use this field.

### Gap 5 — Config not persisted across restarts ℹ️
If the player runs `mydsl tick average 42` to calibrate the timer, that value
lives in `T.config.average` which survives script reloads but not Mudlet
restarts. On next login, average resets to 40.

**Future fix:** Persist `T.config` to character file via ThemeEngine/LayoutEngine
pattern. Low priority — the smoothing algorithm recovers quickly.

### Gap 6 — tempAlias for command registration ⚠️
Aliases are registered with `tempAlias()` which disappears on Mudlet restart
(though `T.aliasesInstalled` prevents re-registration on script reload, which
is fine). On Mudlet restart: `T.aliasesInstalled` is nil (table rebuilt),
`boot()` runs, aliases are re-registered. This actually works correctly.
**No action needed** — noting for clarity.

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ |
| No display logic | ✅ |
| Single timing authority | ✅ |
| Smoothed average via EMA (90/10) | ✅ |
| Publishes to MyDSL.DB.tick | ✅ |
| Raises MyDSL.Tick.Pulse on real ticks | ✅ |
| Raises MyDSL.Tick.Updated on countdown | ✅ |
| 5-second warning (warnTime) | ❌ Config defined, logic missing — Gap 1 |
| Handler deregistration on reload | ❌ Missing — Gap 2 |
| Timer loop isolation on reload | ❌ Missing — Gap 3 |
| closeTime visual state for TickView | ℹ️ Defined, unused — Gap 4 |
| Config persistence across restarts | ℹ️ Session-only — Gap 5 |
EOF