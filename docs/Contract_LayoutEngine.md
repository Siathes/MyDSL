# Module Contract: MyDSL_LayoutEngine.lua
**Layer 2 — Window Layout System, File 2 of 3**
*Written from actual code + screenshot measurement + design decisions June 9–13, 2026*
*Revised June 28 2026 — critical correction to sysWindowResizeEvent handler*

---

## What This Module Is

LayoutEngine owns where every window lives on screen as fractional defaults.
It stores all positions as fractions of the screen (0.0–1.0), converts them
to pixels at runtime, and provides persistence for user-saved positions.

**It does NOT automatically reposition windows on resize events.**
See the critical note below.

---

## CRITICAL NOTE — sysWindowResizeEvent Handler REMOVED

**The `sysWindowResizeEvent` handler was the root cause of windows snapping
back to default positions on every dock operation.**

The handler called `reflowAll()` → `applyToWindow()` → `winObj:resize()` +
`winObj:move()` on every window, every time Mudlet fired a resize event.
Docking a UserWindow fires `sysWindowResizeEvent`. So every dock operation
forced all windows back to LayoutEngine's default pixel positions.

**The handler has been removed from the file.** `reflowAll()` and
`applyToWindow()` remain as callable functions for explicit use, but are
NOT registered on any automatic event.

Mudlet handles the main console space adjustment automatically when UserWindows
are docked. No `setBorderLeft/Right/Bottom` calls and no automatic reflow
are needed.

---

## Namespace

```lua
MyDSL.Layout             -- sub-namespace
MyDSL.Layout.defaults    -- factory positions (never modified at runtime)
MyDSL.Layout.positions   -- working copy — modified by set(), loaded from disk
MyDSL.Layout._handlers   -- stores event handler IDs for clean reload
```

---

## Default Positions
*Measured from actual DSL1 screenshot (Steven's preferred layout)*
*Target resolution: 1920×939.*

### Layout regions
```
┌──────────────┬───────────────────────────────┬─────────────────────┐
│  LEFT COL    │        MAIN CONSOLE           │    RIGHT COL        │
│  x=0, w=0.23 │       x=0.23, w=0.55          │  x=0.78, w=0.22     │
│              │                               │                     │
│ = Location = │   [game text scrolls here]    │    = Chat =         │
│  h=0.23      │                               │    h=0.46           │
│              │                               │                     │
│              │                               │    = Affects =      │
│              │                               │    h=0.25           │
│              │                               │                     │
│              │                               │    = Group =        │
│              │                               │    h=0.18           │
├──────────────┴───────────────────────────────┴─────────────────────┤
│ Combat │ PlayNear│    = Scan =    │   Tick  │        History       │
│ x=0.00 │ x=0.18  │    x=0.34     │  x=0.59 │        x=0.34        │
│ y=0.60 │ y=0.60  │    y=0.60     │  y=0.79 │        y=0.82        │
└────────┴─────────┴───────────────┴─────────┴──────────────────────┘
│              = Live (bottom strip) =              │
│                    x=0.10, y=0.82                 │
└───────────────────────────────────────────────────┘
```

### Complete defaults table

```lua
MyDSL.Layout.defaults = {

  -- ---- RIGHT PANEL -------------------------------------------------
  MyDSL_Chat             = { x=0.66, y=0.00, w=0.34, h=0.30 },
  MyDSL_Affects          = { x=0.66, y=0.30, w=0.34, h=0.25 },
  MyDSL_Group            = { x=0.74, y=0.55, w=0.26, h=0.18 },
  MyDSL_CreatureReference= { x=0.66, y=0.73, w=0.34, h=0.27 },
  MyDSL_Inventory        = { x=0.66, y=0.30, w=0.34, h=0.45 },
  MyDSL_Equipment        = { x=0.66, y=0.30, w=0.34, h=0.45 },

  -- ---- LEFT PANEL --------------------------------------------------
  MyDSL_Portrait         = { x=0.00, y=0.00, w=0.10, h=0.18 },
  MyDSL_Location         = { x=0.00, y=0.18, w=0.10, h=0.18 },
  MyDSL_Target           = { x=0.00, y=0.36, w=0.18, h=0.24 },
  MyDSL_RightHere        = { x=0.00, y=0.60, w=0.18, h=0.22 },
  MyDSL_PlayersNear      = { x=0.18, y=0.60, w=0.16, h=0.22 },

  -- ---- BOTTOM STRIP ------------------------------------------------
  MyDSL_Combat           = { x=0.00, y=0.60, w=0.34, h=0.22 },
  MyDSL_History          = { x=0.34, y=0.82, w=0.32, h=0.18 },
  MyDSL_Scan             = { x=0.34, y=0.60, w=0.32, h=0.22 },
  MyDSL_Live             = { x=0.10, y=0.82, w=0.56, h=0.18 },
  MyDSL_Tick             = { x=0.59, y=0.79, w=0.03, h=0.21 },

  -- ---- MAIN CONSOLE OVERLAYS (Adjustable.Container) ---------------
  MyDSL_MoonWeather      = { x=0.10, y=0.00, w=0.56, h=0.05 },
  MyDSL_AsciiMap         = { x=0.10, y=0.05, w=0.30, h=0.25 },
  MyDSL_Banner           = { x=0.20, y=0.40, w=0.40, h=0.10 },
  MyDSL_Bloodbath        = { x=0.10, y=0.75, w=0.46, h=0.08 },
}
```

---

## Public API

```lua
-- Get the current {x, y, w, h} fractional position for a window:
MyDSL.Layout.get(windowName)
-- Checks positions first, then defaults. Returns nil if unknown.

-- Save a new fractional position for a window:
MyDSL.Layout.set(windowName, x, y, w, h)
-- All values must be numbers 0.0–1.0.

-- Reset one window to factory default position:
MyDSL.Layout.snapBack(windowName)

-- Check if a window's saved position fits within current screen bounds:
MyDSL.Layout.isOnScreen(windowName) → bool

-- Convert fractions to pixels and apply to a live Geyser window object:
MyDSL.Layout.applyToWindow(windowName, geyserWindowObj)
-- resize() then move() — Geyser required order
-- NOTE: Only call explicitly. NOT called automatically on resize events.

-- Reposition all open windows to their saved percentage positions:
MyDSL.Layout.reflowAll(registry)
-- registry passed as parameter (not imported — circular dep prevention)
-- NOTE: Only call explicitly. NOT called automatically on resize events.

-- Persistence:
MyDSL.Layout.save()      -- write current positions to disk
MyDSL.Layout.load()      -- load positions from disk
MyDSL.Layout.validate()  -- clean stale/corrupt entries after load
```

---

## Persistence

**Save file:**
```
getMudletHomeDir()/MyDSL_layout.lua
```

`MyDSL.Layout.load()` is called at the bottom of LayoutEngine on every script
load. This means positions are loaded from disk before any window is created.

`MyDSL.Layout.save()` is called by `MyDSL.Windows.saveLayout()` when the user
runs `mydsl layout save`. It captures the current live window positions and
writes them so the next load creates windows at the correct positions.

---

## What This Module Does NOT Do

- Does not create windows
- Does not import WindowRegistry
- Does not control visibility (show/hide is WindowRegistry's job)
- Does not set `setBorderLeft/Right/Bottom`
- Does not echo text or send game commands
- Does NOT automatically reposition windows on `sysWindowResizeEvent`

---

## Dependencies

**Requires:** `MyDSL` to exist (ThemeEngine creates it, or LayoutEngine guard creates it)
**Calls at runtime:** `getMainWindowSize()`, `table.save()`, `table.load()`
**Must load after:** ThemeEngine
**Must load before:** WindowRegistry, all Layer 3 modules

---

## Gaps

### Gap 2 — resetAll() missing ❌
`snapBack(windowName)` exists for one window. No function to reset all at once.
**Fix:** Iterate `defaults`, call `snapBack()` for each.

### Gap 3 — save() no error handling ⚠️
`table.save()` can fail silently. Wrap in pcall, debugc on failure.

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ |
| No display logic | ✅ |
| No window creation | ✅ |
| No WindowRegistry import | ✅ |
| All positions as fractions 0.0–1.0 | ✅ |
| Deep copy of defaults | ✅ |
| isOnScreen() + snapBack() | ✅ |
| resize() before move() in applyToWindow() | ✅ |
| validate() after load() | ✅ |
| load() called at startup | ✅ |
| sysWindowResizeEvent handler REMOVED | ✅ Was root cause of window resets |
| reflowAll/applyToWindow explicit-only | ✅ Not auto-triggered |
| resetAll() function | 🔲 Needs adding — Gap 2 |
| save() error handling | 🔲 Needs adding — Gap 3 |
