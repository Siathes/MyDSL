# Module Contract: MyDSL_RouteHelper.lua
**Layer 3 — Text Routing to Windows**
*Written from actual code. File: MyDSL_RouteHelper.lua (114 lines)*

---

## What This Module Is

RouteHelper is the dispatch layer between Mudlet triggers and display windows.
When a trigger fires on a game text line, it calls `MyDSL.Route.to("History")`
(or any destination name) and RouteHelper gets the text into the correct window.

It also handles lazy MiniConsole creation — UserWindows are just frames. The first
time a window receives routed text, RouteHelper creates a MiniConsole inside it
to hold that text.

**RouteHelper is NOT used for chat.** Chat goes through `demonnic.chat:append()`.
RouteHelper handles: History, Combat, Scan, Group, Target, RightHere, PlayersNear.

---

## Namespace

```lua
MyDSL.Route          -- sub-namespace
MyDSL.Route.to()     -- primary routing function
MyDSL.Route.history() MyDSL.Route.combat()    -- shorthand helpers
MyDSL.Route.scan()   MyDSL.Route.group()
MyDSL.Route.players() MyDSL.Route.righthere()
```

---

## Route Name Map (DSL1 → DSL2)

Backward-compatible names so old trigger code keeps working:

| DSL1 name | DSL2 window |
|---|---|
| `"History"` | `MyDSL_History` |
| `"Combat"` | `MyDSL_Combat` |
| `"Scan"` | `MyDSL_Scan` |
| `"Group"` | `MyDSL_Group` |
| `"PlayersNearYou"` or `"PlayersNear"` | `MyDSL_PlayersNear` |
| `"Target"` | `MyDSL_Target` |
| `"RightHere"` | `MyDSL_RightHere` |
| Any `"MyDSL_*"` name | Direct window lookup (no map needed) |

---

## Public API — Current

```lua
-- Route text to a window:
MyDSL.Route.to(name, line)
-- name: DSL1 name OR direct "MyDSL_WindowName"
-- line: optional string. If nil, uses getCurrentLine() — plain text, NO colors.
-- Currently uses decho() — original ANSI colors NOT preserved. See Gap 1.

-- Shorthands (all call Route.to internally):
MyDSL.Route.history(line)
MyDSL.Route.combat(line)
MyDSL.Route.scan(line)
MyDSL.Route.group(line)
MyDSL.Route.players(line)
MyDSL.Route.righthere(line)
```

---

## Public API — Proposed (after Gap 1 fix)

```lua
-- Route current trigger line WITH original game colors preserved:
MyDSL.Route.to("History")           -- no line arg → appendBuffer mode
-- Route explicit formatted text without game colors:
MyDSL.Route.to("History", "<red>System message<reset>")   -- line arg → decho mode

-- Clear a routed window (for scan refresh, group refresh, etc.):
MyDSL.Route.clear("Scan")          -- Gap 3 — needs adding

-- Access the MiniConsole object directly (for Layer 3 modules):
MyDSL.Route.getConsole("History")  -- Gap 4 — needs adding
```

---

## How Lazy MiniConsole Creation Works

On first call to `Route.to("History")`:

1. Look up `"MyDSL_History"` in `MyDSL.Windows.registry`
2. If window object doesn't exist yet, call `MyDSL.Windows.ensure("MyDSL_History")`
3. Create `Geyser.MiniConsole:new({ name="MyDSL_History_con", x=0, y=0, w="100%", h="100%", scrollBar=true })` as a child of the UserWindow
4. Store reference in `registry["MyDSL_History"].console`
5. On every subsequent call, return the stored reference — no re-creation

The console reference is stored in the registry entry under `.console`. This means
Layer 3 modules that need to access the MiniConsole directly (for `clear()`, `echo()`,
or scroll operations) should read `MyDSL.Windows.registry["MyDSL_History"].console`.

---

## Trigger Pattern — Correct Usage

```lua
-- In a trigger: route current line to History AND gag from main console:
MyDSL.Route.to("History")     -- routes the line
deleteLine()                   -- removes from main console (caller's responsibility)

-- Route current line without gagging (shows in both places):
MyDSL.Route.to("History")     -- no deleteLine() = line stays in main console too

-- Route explicit text (system messages, not game text):
MyDSL.Route.to("History", "<yellow>[System] Connected.\n<reset>")
```

**Key rule:** RouteHelper never calls `deleteLine()`. Gagging is always the trigger's
responsibility. This keeps RouteHelper single-purpose.

---

## What This Module Does NOT Do

- Does not gag lines from main console (trigger's job)
- Does not route chat (use `demonnic.chat:append()`)
- Does not apply themes to created MiniConsoles (gap — see Gap 2)
- Does not clear windows (gap — see Gap 3)
- Does not raise events
- Does not read from DataLayer
- Does not send game commands

---

## Dependencies

**Reads:** `MyDSL.Windows.registry` and `MyDSL.Windows.ensure()` — WindowRegistry
**Uses:** `Geyser.MiniConsole`, `getCurrentLine()`, `selectCurrentLine()`, `copy()`,
`appendBuffer()` — Mudlet built-ins
**Must load after:** WindowRegistry

---

## Gaps and Issues Found in Code

### Gap 1 — Uses decho instead of appendBuffer — BREAKS COLOR PRESERVATION ❌
**Critical.** Current implementation:
```lua
local text = line or (getCurrentLine and getCurrentLine()) or ""
con:decho(text .. "\n")
```
`getCurrentLine()` returns plain text — all ANSI game colors are stripped.
`con:decho()` on that plain text shows in the MiniConsole's default color only.

This violates the Observer UI philosophy: "move text, don't rewrite it."
Game text routed to History or Combat should look exactly as DSL sent it.

**Fix:** Split into two modes based on whether `line` is provided:
```lua
function MyDSL.Route.to(name, line)
  local winName = routeMap[name] or name
  local con = getOrCreateConsole(winName)
  if not con then return end

  if line then
    -- Explicit text with decho color tags — caller controls formatting
    con:decho(line .. "\n")
  else
    -- Route current trigger line with all original ANSI colors intact
    selectCurrentLine()
    copy()
    con:appendBuffer()
  end
end
```

This gives two clean modes:
- No `line` arg → `appendBuffer` (colors preserved, passive observer)
- `line` string → `decho` (explicit formatted message)

### Gap 2 — MiniConsole ignores ThemeEngine ⚠️
MiniConsoles are created with hardcoded values:
```lua
fontSize = 9, color = "black"
```
Should use:
```lua
fontSize = MyDSL.Theme.get(windowName, "fontSize") or 9,
-- background color via setColor() using ThemeEngine bgColor
```
ThemeEngine's `applyToAll()` + `registerRefreshCallback()` mechanism should
re-style MiniConsoles when the theme changes. Currently they're invisible to
the theme system.

**Fix:** In `getOrCreateConsole()`, read from ThemeEngine. Register a refresh
callback so theme changes re-apply font/color.

### Gap 3 — No clear() function ⚠️
Scan output, group lists, and players near all need their windows cleared before
new content is written. Currently callers must access `entry.console:clear()`
directly via `MyDSL.Windows.registry[name].console`.

**Fix:** Add:
```lua
function MyDSL.Route.clear(name)
  local winName = routeMap[name] or name
  local entry = MyDSL.Windows.registry[winName]
  if entry and entry.console then entry.console:clear() end
end
```

### Gap 4 — No public accessor for console object ⚠️
Display modules that need to call `console:echo()`, `console:cecho()`, or
`console:getLineCount()` directly must dig into the registry. A clean accessor
would be safer:

```lua
function MyDSL.Route.getConsole(name)
  local winName = routeMap[name] or name
  return getOrCreateConsole(winName)
end
```

### Gap 5 — Bloodbath not in route map ℹ️
`MyDSL_Bloodbath` is in the WindowRegistry but not in routeMap. Any trigger
calling `MyDSL.Route.to("Bloodbath")` would fall through to direct window name
lookup (`routeMap["Bloodbath"]` = nil → tries `"Bloodbath"` as a window name,
fails).

**Fix:** Add `Bloodbath = "MyDSL_Bloodbath"` to routeMap.

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ |
| No window creation (UserWindows) | ✅ |
| Backward-compatible DSL1 names | ✅ |
| Lazy MiniConsole creation | ✅ |
| Duplicate handler prevention | ✅ (no handlers — pure function calls) |
| Does not gag lines (caller's job) | ✅ Correct design |
| Does not route chat | ✅ Chat is EMCO only |
| Color preservation (appendBuffer) | ❌ Currently uses decho — Gap 1 |
| ThemeEngine integration | ❌ Hardcoded — Gap 2 |
| clear() function | ❌ Missing — Gap 3 |
| getConsole() accessor | ❌ Missing — Gap 4 |
| Bloodbath in route map | ❌ Missing — Gap 5 |
EOF