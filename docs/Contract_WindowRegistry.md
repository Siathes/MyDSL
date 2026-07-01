# Module Contract: MyDSL_WindowRegistry.lua
**Layer 2 — Window Registry, File 3 of 3**
*Written from actual code + design decisions. Revised June 28 2026.*

---

## What This Module Is

WindowRegistry is the bridge between abstract layout/theme data and the live
Geyser window objects that Mudlet actually draws on screen. It creates, tracks,
shows, hides, and persists the visibility state of every UI window. It does not
control window content — that is Layer 3's job. It does not control positions —
that is LayoutEngine's job. It does not control colors — that is ThemeEngine's job.

---

## Namespace

```lua
MyDSL.Windows              -- sub-namespace
MyDSL.Windows.registry     -- table of window entries (see below)
MyDSL.Windows._handlers    -- event handler IDs for clean reload
```

---

## The Registry — 20 Window Entries

Each entry has four fields:

```lua
{
  obj     = nil,           -- the live Geyser window object (nil until ensure() runs)
  type    = "UserWindow",  -- "UserWindow" or "Container"
  visible = true,          -- whether the window should be shown
  created = false,         -- whether ensure() has run for this window
}
```

### UserWindows (Geyser.UserWindow — detachable to second monitor)

| Window | Default visible | Notes |
|---|:---:|---|
| MyDSL_Chat | ✅ | Primary chat panel, contains EMCO |
| MyDSL_Affects | ✅ | Active spell timers |
| MyDSL_Portrait | ✅ | Character portrait image |
| MyDSL_Location | ✅ | Area/room name text display |
| MyDSL_Live | ✅ | HP/Mana/MV bars + room info |
| MyDSL_Tick | ✅ | Tick countdown timer |
| MyDSL_Combat | ✅ | Combat damage log |
| MyDSL_History | ✅ | General event/notification output |
| MyDSL_Scan | ✅ | Scan output display |
| MyDSL_Group | ✅ | Group member list |
| MyDSL_Target | ✅ | Combat target info |
| MyDSL_RightHere | ✅ | Clickable mob list from scan |
| MyDSL_PlayersNear | ✅ | Players near you |
| MyDSL_CreatureReference | ❌ | Creature lore lookup, hidden by default |
| MyDSL_Inventory | ❌ | Inventory list, shown on demand |
| MyDSL_Equipment | ❌ | Equipment list, shown on demand |

### Containers (Adjustable.Container — anchored in main console)

| Window | Default visible | Notes |
|---|:---:|---|
| MyDSL_MoonWeather | ✅ | Moon phase + weather strip |
| MyDSL_AsciiMap | ❌ | ASCII map inset |
| MyDSL_Banner | ❌ | Alert/notification overlay |
| MyDSL_Bloodbath | ❌ | Bloodbath event overlay |

**Note:** MyDSL_Mapper was removed from the registry. The native Mudlet mapper
is managed by the generic_mapper script and does not need a registry entry.

---

## Public API

```lua
-- Get the live Geyser object for a window (nil if not yet created):
MyDSL.Windows.get(windowName)
-- Primary API for Layer 3. Do NOT access registry directly.

-- Create a window the first time it's needed:
MyDSL.Windows.ensure(windowName)
-- Returns the live object. Creates if not yet created. Safe to call repeatedly.

-- Create all 20 windows (called at startup):
MyDSL.Windows.ensureAll()

-- Show/hide/toggle a window and save state:
MyDSL.Windows.show(windowName)
MyDSL.Windows.hide(windowName)
MyDSL.Windows.toggle(windowName)

-- Persist current visibility state to disk:
MyDSL.Windows.saveState()

-- Load visibility state from disk (called at startup, before ensureAll):
MyDSL.Windows.loadState()

-- Save current window layout (positions + dock state + LayoutEngine positions):
MyDSL.Windows.saveLayout()
-- Reads live Geyser object positions, writes to LayoutEngine + saveWindowLayout()
-- User alias: "mydsl layout save"
```

---

## Event API

Any script, trigger, or alias can toggle a window without importing this module:

```lua
raiseEvent("MyDSL.windows.toggle", "MyDSL_Chat")
-- Calls MyDSL.Windows.toggle("MyDSL_Chat")
```

The event handler is registered on load and deregistered/re-registered on reload
(duplicate prevention).

---

## Window Creation — How `ensure()` Works

```lua
-- 1. Check if already created (return early if so)
-- 2. Get percentage position from LayoutEngine via percentsFromLayout()
-- 3. Create Geyser.UserWindow:new() or Adjustable.Container:new()
--    (constructor patch injects restoreLayout=true and autoDock=true)
-- 4. Apply theme (currently no-op placeholder)
-- 5. Store object in entry.obj, set created=true
-- 6. Apply visibility state (hide if entry.visible == false)
```

**Important:** `applyToWindow()` is NOT called after construction. Post-construction
`move()`/`resize()` calls conflict with `restoreLayout=true` and were the source
of earlier window reset problems. LayoutEngine positions are used as the initial
`x/y/w/h` in the constructor only.

---

## Constructor Patch

`patchUserWindowConstructor()` monkey-patches `Geyser.UserWindow.new` before any
windows are created. Every UserWindow from any module (WindowRegistry, ChatWrapper,
AffectsView, PortraitView) automatically gets:

```lua
restoreLayout = true   -- Mudlet persists this window's position via loadWindowLayout()
autoDock = true        -- user can dock by dragging to screen edges (already default)
```

The patch is guarded by `_constructorPatched` to run only once per session.

---

## Startup Sequence

```lua
patchUserWindowConstructor()   -- patch before ANY window is created
MyDSL.Windows.loadState()      -- restore visibility booleans from disk
MyDSL.Windows.ensureAll()      -- create all 20 windows at LayoutEngine positions
if loadWindowLayout then        -- restore previously saved positions/dock state
  loadWindowLayout()
end
```

**Why no timers:** All windows exist synchronously after `ensureAll()`. There is
no race condition to hedge against.

**Why no `saveWindowLayout()` at startup:** Calling it at startup overwrites the
user's saved layout with LayoutEngine defaults. Only the user should call
`saveWindowLayout()` (via `mydsl layout save`) after arranging windows.

**Why no `sysWindowResizeEvent` handler:** LayoutEngine previously registered this
handler to call `reflowAll()`, which called `applyToWindow()` on every window,
forcing all windows back to default positions on every dock operation. This was
the root cause of the window reset problem. The handler was removed from
LayoutEngine. Mudlet handles console space adjustment automatically when UserWindows
are docked.

---

## Layout Persistence — saveLayout()

`MyDSL.Windows.saveLayout()` is the complete save operation:

1. Reads each live window's current pixel position from the Geyser object
2. Converts to fractions and writes to `MyDSL.Layout.set()`
3. Calls `MyDSL.Layout.save()` to write LayoutEngine positions to disk
4. Calls `saveWindowLayout()` to save Qt dock state
5. Calls `saveProfile()` to flush to disk

This means on the NEXT load, `percentsFromLayout()` creates windows at the
user's saved positions, and `loadWindowLayout()` restores their dock state.

---

## State Persistence

**Visibility state file (single shared file):**
```
getMudletHomeDir()/MyDSL_windowstate.lua
```

Only visibility booleans are saved. Live Geyser objects cannot be serialized.

---

## Console Border Management

**Mudlet adjusts the main console automatically when UserWindows are docked.**
`setBorderLeft/Right/Bottom` is NOT called anywhere in WindowRegistry — this
is correct. Mudlet handles it natively.

---

## What This Module Does NOT Do

- Does not manage window content (Layer 3's job)
- Does not control window positions at runtime (LayoutEngine via percentsFromLayout at creation)
- Does not control colors or fonts (ThemeEngine)
- Does not set console borders (Mudlet handles natively)
- Does not call `move()`/`resize()` on windows after creation

---

## Dependencies

**Requires:**
- `MyDSL.Layout.get()` — LayoutEngine must load first (for percentsFromLayout)
- `MyDSL.Layout.set()` and `MyDSL.Layout.save()` — for saveLayout()
- `Geyser.UserWindow` and `Adjustable.Container` — Mudlet built-ins
- `getMudletHomeDir()`, `table.save()`, `table.load()` — Mudlet built-ins
- `saveWindowLayout()`, `loadWindowLayout()` — Mudlet built-ins

**Must load after:** ThemeEngine, LayoutEngine
**Must load before:** All Layer 3 display modules

---

## Gaps and Issues

### Gap 2 — Comment says 18/20 windows ℹ️
The file header comment may have a stale count. The actual registry has 20 entries.
**Fix:** Update comment. Not a functional issue.

### Gap 3 — applyTheme() is a no-op placeholder ℹ️
`setStyleSheet` is not available on `Geyser.UserWindow` or `Adjustable.Container`.
Theming is applied by Layer 3 when MiniConsole/Label children are created.
**No action needed.** Layer 3 modules own their content theming.

### Gap 6 — Visibility state not character-bound ⚠️
Single `MyDSL_windowstate.lua` shared across all characters.
Decision pending — low priority.

### Gap 7 — saveState() has no error handling ⚠️
`table.save()` can fail silently. Wrap in pcall, debugc on failure.

### Gap 8 — No batch utility functions ℹ️
No `showAll()`, `hideAll()`, `resetAll()`. Useful for debugging. Low priority.

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ |
| No content/display logic | ✅ |
| No position management at runtime | ✅ |
| Constructor patch injects restoreLayout/autoDock | ✅ |
| Duplicate handler prevention on reload | ✅ |
| Safe reload guards on registry | ✅ |
| loadState() before ensureAll() | ✅ |
| loadWindowLayout() after ensureAll() | ✅ |
| No applyToWindow() after construction | ✅ |
| No sysWindowResizeEvent handler | ✅ Correctly absent |
| No saveWindowLayout() at startup | ✅ Correctly absent |
| saveLayout() captures live positions | ✅ |
| MyDSL_Mapper removed from registry | ✅ |
| MyDSL_RoomPicture → MyDSL_Location rename | ✅ Done |
| Console border management | ✅ Handled by Mudlet natively |
| Character-bound visibility state | ⚠️ Decision needed — Gap 6 |
| saveState() error handling | 🔲 Needs adding — Gap 7 |
