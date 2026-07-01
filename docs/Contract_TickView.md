# Module Contract: MyDSL_TickView.lua
**Layer 3 — Tick Countdown Display**
*Written from actual code. Version: v4C5 QuietBoot. File: MyDSL_TickView.lua (411 lines)*

---

## What This Module Is

TickView is the visual face of the tick timer. It reads from `MyDSL.DB.tick`,
renders a vertical gauge with color-coded remaining time, and updates every
0.25 seconds. It owns no timing logic — that is entirely TickSource's job.

PNP features ported: vertical gauge, color changes at close/warn thresholds,
average tick display, tick count display.

---

## Namespace

```lua
MyDSL.TickView          -- the module
MyDSL.TickView.config   -- display configuration
MyDSL.TickView.ui       -- live Geyser object references
```

---

## Visual Layout

The window is a narrow vertical panel containing stacked Labels:

```
┌─────────────────┐
│   TICK / WAIT   │  ← title label (gold text)
│                 │
│     ┌───┐       │
│     │▓▓▓│ fill  │  ← tube + fill gauge (rises from bottom)
│     │▓▓▓│       │
│     │▓▓▓│       │
│     └───┘       │
│     12s          │  ← seconds label (large, color-coded)
│                 │
│   avg 40.0s     │  ← detail label (small, grey)
│   #42           │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓ │  ← color strip (3% height at bottom)
└─────────────────┘
```

---

## Color Palette

The palette changes based on seconds remaining and running state:

| State | Trigger | Colors |
|---|---|---|
| `ready` | running, remaining > 15s | Green: `#69f542` |
| `warn` | running, remaining ≤ 15s | Yellow: `#ffd84a` |
| `danger` | running, remaining ≤ 5s | Red: `#ff4040` |
| `wait` | not running | Grey: `#77838a` |

The 5s and 15s thresholds correspond to `TickSource.config.warnTime` and
`TickSource.config.closeTime`. TickView reads remaining from `MyDSL.DB.tick`
and applies palette independently — it does not listen for warning events.

**Important:** The visual warning at 5 seconds IS working (gauge turns red).
What is NOT working is any audio or echo alert — that requires TickSource's
`MyDSL.Tick.Warning` event to be implemented (TickSource Gap 1).

---

## Display Modes

```lua
V.config.mode = "compact"  -- default
-- compact: shows "avg 40.0s" and "#42" (tick count)
-- full:    adds source string ("gmcp.tick", "expired", etc.)
```

Toggled via: `mydsl tickview mode compact|full`

---

## Events Listened To

| Event | Source | Result |
|---|---|---|
| `MyDSL.Tick.Updated` | TickSource (every 0.25s) | `V.render()` |
| `MyDSL.Timers.Updated` | ❌ Never fired — see Gap 6 | Would also call `V.render()` |

---

## Settings Persistence

Saves to: `getMudletHomeDir() .. "/MyDSL/tickview_settings.lua"`

Persists: `shown`, `font`, `mode`, `title`

**Not character-bound** — shared across all characters (see Gap 3).

---

## Aliases

```
mydsl tickview status
mydsl tickview show / hide
mydsl tickview rebuild
mydsl tickview font <size>
mydsl tickview mode compact|full
mydsl tickview title <text>
mydsl tickview save
mydsl tickview reload settings
```

---

## Dependencies

**Reads from:** `MyDSL.DB.tick` and `MyDSL.DB.timers.tick` — DataBridge must be loaded
**Listens to:** `MyDSL.Tick.Updated` — TickSource must be running
**Must load after:** DataBridge, TickSource
**Creates its own window:** See Gap 1 — does not use WindowRegistry

---

## What This Module Does NOT Do

- Does not own timing logic (TickSource's job)
- Does not send game commands
- Does not fire audio or echo alerts (TickSource Gap 1 must be fixed first)

---

## Gaps and Issues Found in Code

### Gap 1 — Creates its own window, bypasses WindowRegistry ❌
**Critical architectural issue.**

`V.ensureUI()` calls `Geyser.UserWindow:new({name="MyDSL_Tick", x="80%", y="70%", width="7%", height="18%"})` directly. This means:
- Position is hardcoded, not read from LayoutEngine
- Window is not registered in WindowRegistry
- `saveWindowLayout()` / `loadWindowLayout()` do not save/restore it
- ThemeEngine cannot call refresh callbacks on it
- The window cannot be shown/hidden via `MyDSL.Windows.show/hide()`

**Fix:** Remove `V.ensureUI()` window creation. Let WindowRegistry create
`MyDSL_Tick` via `MyDSL.Windows.ensure("MyDSL_Tick")`. TickView reads the
window object from the registry and creates its Labels inside it:
```lua
function V.ensureUI()
  local entry = MyDSL.Windows and MyDSL.Windows.registry and
                MyDSL.Windows.registry["MyDSL_Tick"]
  if not entry then return false end
  MyDSL.Windows.ensure("MyDSL_Tick")
  local win = entry.obj
  if not win then return false end
  -- create Labels as children of win...
end
```

### Gap 2 — Hardcoded colors, no ThemeEngine integration ⚠️
Background (`#0b1013`), border (`#33434a`), tube, text colors are all hardcoded.
The semantic palette colors (green/yellow/red for ready/warn/danger) can stay
hardcoded as they carry meaning. But panel background, text, and border should
use ThemeEngine:

```lua
-- Instead of:
background-color: #0b1013;
-- Use:
local bg = MyDSL.Theme.colorToCSS(MyDSL.Theme.get("MyDSL_Tick", "bgColor"))
```

No ThemeEngine refresh callback registered. If theme changes, colors don't update.

### Gap 3 — Settings not character-bound ⚠️
`tickview_settings.lua` is a single file shared by all characters. If Kien
prefers `full` mode and Olyndros prefers `compact`, they conflict.

**Fix:** Include character name in settings file path:
```lua
function V.settingsFile(charName)
  charName = charName or (MyDSL and MyDSL.Char and MyDSL.Char()) or "default"
  return profileDir() .. "/tickview_" .. charName .. "_settings.lua"
end
```

### Gap 4 — Handler deregistration missing ⚠️
Same issue as TickSource. `V.handlersInstalled` prevents re-registration on
reload but old handlers are never killed. Multiple reloads accumulate redundant
`render()` calls.

**Fix:** Same pattern as DataBridge — store handler IDs, kill on reload:
```lua
function V.deregisterHandlers()
  if V.handlers then
    for _, id in ipairs(V.handlers) do pcall(killAnonymousEventHandler, id) end
  end
  V.handlers = {}
  V.handlersInstalled = false
end
-- Call at top of V.boot()
```

### Gap 5 — Render rate is 4 calls/second ℹ️
`MyDSL.Tick.Updated` fires 4 times per second (every 0.25s from TickSource).
`V.render()` calls multiple `pcall()` + Geyser style operations each time.
This is 240 Geyser updates per minute. Not harmful in practice but worth
monitoring if performance issues appear on low-end hardware.

No action needed unless performance becomes an observed issue.

### Gap 6 — Listens to wrong event name ❌
```lua
-- TickView listens for:
"MyDSL.Timers.Updated"

-- TickSource actually raises:
"MyDSL.Timers.Pulse"
```

`MyDSL.Timers.Updated` never fires. The listener is dead code. Renders are
triggered only by `MyDSL.Tick.Updated` which is correct.

**Fix:** Either:
- Remove the `MyDSL.Timers.Updated` listener (dead code removal)
- Change TickSource to also raise `MyDSL.Timers.Updated` (makes the name consistent)

Recommendation: have TickSource raise both `MyDSL.Timers.Pulse` and
`MyDSL.Timers.Updated` for forward compatibility with other timer displays.

### Gap 7 — Warning is visual only, no audio or echo ℹ️
At 5 seconds remaining, the gauge turns red (danger palette). This IS working.
What is NOT working: any sound or text alert. This requires TickSource to
implement the `MyDSL.Tick.Warning` event (TickSource Gap 1). Once that event
fires, TickView can listen to it and add:
```lua
registerAnonymousEventHandler("MyDSL.Tick.Warning", function(_, secs)
  cecho("<red>[!] Tick in " .. secs .. " seconds!\n")
  -- playSoundFile("tick_warn.wav")  -- optional
end)
```

---

## Contract Status

| Clause | Status |
|---|---|
| No timing logic (TickSource owns it) | ✅ |
| No game commands sent | ✅ |
| Reads from MyDSL.DB.tick | ✅ |
| Vertical gauge fill | ✅ Working |
| Color palette at 5/15 second thresholds | ✅ Working |
| Average and tick count display | ✅ Working |
| Two display modes (compact/full) | ✅ Working |
| Audio/echo warning at 5 seconds | ❌ Requires TickSource Gap 1 fix |
| Uses WindowRegistry for window | ❌ Creates own window — Gap 1 |
| ThemeEngine integration | ❌ Hardcoded colors — Gap 2 |
| Character-bound settings | ❌ Shared file — Gap 3 |
| Handler deregistration | ❌ Missing — Gap 4 |
| Event name typo (Timers.Updated) | ❌ Dead listener — Gap 6 |
EOF