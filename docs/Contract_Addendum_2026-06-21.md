# Contract Addendum — June 21, 2026
*Read alongside the affected contracts. This document records decisions made
after those contracts were uploaded — it supersedes the specific sections
named below, not the entire contract.*

---

## 1. Supersedes: Contract_LayoutEngine.md and Contract_WindowRegistry.md

### Native Mudlet Docking Replaces Manual Position Persistence

Research into Mudlet's actual UserWindow API revealed built-in functionality
that replaces large parts of LayoutEngine's originally-planned custom
persistence system.

**What changes:**

`MyDSL.Layout.save()` / `MyDSL.Layout.load()` — the custom `table.save()`-based
file persistence described in the original LayoutEngine contract is REPLACED by:

```lua
saveWindowLayout([versionNumber])   -- native Mudlet function
loadWindowLayout([versionNumber])   -- native Mudlet function
```

**Character binding via version number, not separate files:**
```lua
local charVersions = { Kien = 1, Olyndros = 2, Tibbins = 3 }

function MyDSL.Layout.onLogin(charName)
  local v = charVersions[charName] or 0
  loadWindowLayout(v)
end

function MyDSL.Layout.save()
  local v = charVersions[MyDSL.Char()] or 0
  saveWindowLayout(v)
end
```

**WindowRegistry constructors now specify docking directly:**
```lua
-- Right-column window (Chat, Affects, History, Group):
Geyser.UserWindow:new({
  name = windowName, docked = true, dockPosition = "right", autoDock = true,
})

-- Bottom-strip window (Live, Tick, Target, Portrait, PlayersNear, RightHere):
Geyser.UserWindow:new({
  name = windowName, docked = true, dockPosition = "bottom", autoDock = true,
})

-- Left-column tabbed window (Scan, Combat):
Geyser.UserWindow:new({
  name = windowName, docked = true, dockPosition = "left", autoDock = true,
})
```

**Stacking/tabbing is automatic.** When multiple UserWindows dock to the same
side, Mudlet's Qt layer groups them as tabs with zero additional code. This is
confirmed by screenshot — Map/Scan/Combat tab together on the left without any
EMCO-style tab logic.

**Critical sequencing caveat (confirmed via Mudlet community research):**
Opening any new UserWindow resets ALL currently-open UserWindows to their last
saved layout. This means `loadWindowLayout()` must be called exactly ONCE,
AFTER all 21 windows have been created — never per-window, never before all
windows exist.

**Corrected startup sequence:**
```
1. WindowRegistry.ensureAll()        -- create all windows, no restoreLayout yet
2. WindowRegistry.applyBorders()     -- setBorderLeft/Right/Bottom
3. MyDSL.Layout.onLogin(charName)    -- ONE call to loadWindowLayout(version)
```

**What LayoutEngine STILL owns (unchanged from original contract):**
- The `defaults` table — first-run fallback positions (now using percentage
  strings matching the confirmed screenshot layout)
- `snapBack()` / `resetAll()` — reset to factory defaults
- Knowledge of which windows are docked vs floating (for `applyBorders()` math)
- The actual `setBorderLeft/Right/Bottom` calls (WindowRegistry executes them,
  using sizes LayoutEngine's defaults imply)

### Docked Window Defaults (replaces fractional x/y/w/h for these windows)

```lua
-- Docked left (tabbed with native mapper):
MyDSL_Scan   = { docked=true, dockSide="left" }
MyDSL_Combat = { docked=true, dockSide="left" }

-- Docked right:
MyDSL_Chat     = { docked=true, dockSide="right" }
MyDSL_Affects  = { docked=true, dockSide="right" }
MyDSL_History  = { docked=true, dockSide="right" }
MyDSL_Group    = { docked=true, dockSide="right" }

-- Docked bottom (order matters — left to right as listed):
MyDSL_PlayersNear = { docked=true, dockSide="bottom" }
MyDSL_Portrait    = { docked=true, dockSide="bottom" }
MyDSL_Live        = { docked=true, dockSide="bottom" }
MyDSL_Tick        = { docked=true, dockSide="bottom" }
MyDSL_Target      = { docked=true, dockSide="bottom" }
MyDSL_RightHere   = { docked=true, dockSide="bottom" }

-- Floating (still uses fractional x/y/w/h):
MyDSL_Location = { x=0.00, y=0.00, w=0.23, h=0.23 }
-- Location is NOT docked — it sits above the docked Map/Scan/Combat group
```

### WindowRegistry Border Management (unchanged requirement, now with exact widths)

```lua
local function applyBorders()
  local sw, sh = getMainWindowSize()
  setBorderLeft(math.floor(sw * 0.23))
  setBorderRight(math.floor(sw * 0.22))
  setBorderBottom(math.floor(sh * 0.21))
  setBorderTop(0)
end
```

---

## 2. Supersedes: Contract_RouteHelper.md — "Route Name Map" section

### routeMap Removed Entirely

Original contract documented a DSL1→DSL2 backward-compatibility name map
(`"History" → "MyDSL_History"` etc.). This was designed for porting old DSL1
trigger code unchanged.

**Decision:** Since all DSL2 triggers are being written fresh (no DSL1 trigger
code is being imported verbatim), the routeMap has no consumers and is
unnecessary complexity.

**New primary API:**
```lua
MyDSL.Route.history(line)     -- shorthand, hides window name entirely
MyDSL.Route.combat(line)
MyDSL.Route.scan(line)
MyDSL.Route.group(line)
MyDSL.Route.players(line)
MyDSL.Route.righthere(line)
MyDSL.Route.bloodbath(line)   -- was missing from old map entirely (Gap 5), now just a shorthand

-- For anything without a shorthand, direct window name:
MyDSL.Route.to("MyDSL_Scan", line)
```

The `routeMap` table and the indirection it required are removed from the
implementation. This simplifies `RouteHelper.lua` and removes Gap 5 (missing
Bloodbath entry) as a side effect — there's no map to forget an entry in.

---

## 3. Supersedes: Contract_PortraitView.md — CharPic compatibility sections

### CharPic Global Removed

Confirmed: no DSL1 triggers call any `CharPic.*` function. The entire
`installCompatGlobal()` function (~22 lines), the `CharPic.boot` alias, and
all `charpic *` compatibility aliases in `installAliases()` are REMOVED from
PortraitView in DSL2.

**Removed from the module:**
- `P.installCompatGlobal()` function entirely
- The `CharPic = CharPic or {}` global creation
- All `installAlias("charpic_*", ...)` calls
- The "Compatibility aliases" section of the header comment block

**What remains unchanged:** Everything else in the PortraitView contract —
auto-discovery, per-character paths, fit modes, the `mydsl portrait *` alias
set — all stays exactly as documented.

This also removes the need for `P.config.windowId = "Portrait"` style legacy
naming overlap with CharPic-era conventions, though that field itself is
harmless and can stay.

---

## 4. New Confirmed Data — DSL1 Mapper Patches (for DataLayer/Mapper contract, future)

See SESSION_START.md "DSL1 Modified Mapper Script" section for the full list
of 8 confirmed patches. This is not yet a formal contract (the mapper script
itself is third-party/Jor'Mox code we patch, not a MyDSL module), but it
affects how the mapper is deployed in DSL2:

- Must be installed from the exact patched file, not a fresh package install
- `download_path = ""` must be preserved or auto-update will silently destroy
  all DSL-specific fixes
- The `.dat` map data file (room/exit data) is separate from the script and
  carries forward independently

This will need its own short reference document when Layer 3 Phase B work
touches the mapper directly (e.g., room icons, terrain colors, weights).

---

## 5. CORRECTION — Docking applies only to the left column, not the bottom strip

**This corrects section 1 above.** On closer reading of the screenshot, the
bottom strip (PlayersNear, Portrait, Live, Tick, Target, RightHere) shows
separate bordered panels with individual title bars side by side — not a
tabbed group. True Mudlet docking (`docked=true, dockPosition=X`) causes
multiple windows on the same side to tab together automatically (confirmed
behavior, visible on the left column where Map/Scan/Combat show actual tab
labels). Since the bottom strip does NOT show tabs, those windows are not
using true docking.

**Corrected model:**
- **Real docking** (`docked=true, dockPosition="left", autoDock=true`):
  ONLY `MyDSL_Scan` and `MyDSL_Combat` — these are meant to tab with the
  native mapper dock.
- **Floating with native position memory** (`restoreLayout=true`, no
  `docked`/`dockPosition`): every other window — the entire bottom strip,
  the entire right column (Chat/Affects/History/Group), and `MyDSL_Location`.
  These use the original fractional x/y/w/h defaults for first-run
  placement, and `saveWindowLayout()`/`loadWindowLayout()` for remembering
  where the user actually puts them afterward.

```lua
-- Bottom strip / right column (floating, remembers position):
Geyser.UserWindow:new({
  name = windowName,
  x = defaults.x, y = defaults.y, width = defaults.w, height = defaults.h,
  restoreLayout = true,
})

-- Left column tabbed group (true docking):
Geyser.UserWindow:new({
  name = windowName, docked = true, dockPosition = "left", autoDock = true,
})
```

This means **LiveView's window is floating, not docked** — its position is
fully under our control via the fractional defaults and is independently
restorable per character via `loadWindowLayout(version)`.

---

## 6. Closes — Contract_LayoutEngine.md Gap 1 and Gap 4

**Gap 1 (mapper window type — was "decision needed"): RESOLVED.**
Two-system approach confirmed: native Mudlet map dock (uncontrollable,
space reserved via `setBorderLeft` only) + minimap via `map.configs.map_window`
+ `map.showMap()` (controllable, not a Geyser.UserWindow). `MyDSL_Mapper`
removed from the WindowRegistry registry and from LayoutEngine's defaults
table entirely — it is not a Layer 2 window of any kind.

**Gap 4 (Tick position — was "placeholder, unclear"): RESOLVED.**
Confirmed via screenshot: standalone floating window in the bottom strip,
positioned between Live and Target. Alterform timer (future) will occupy
the slot immediately to Tick's left when built.

**Corrected LayoutEngine defaults (replaces the relevant lines from the
original contract):**
```lua
-- MyDSL_Mapper entry DELETED — not a Layer 2 window, see section 6 above

MyDSL_Tick   = { x=0.59, y=0.79, w=0.03, h=0.21 },  -- confirmed, not placeholder
-- Reserved for future:
-- MyDSL_Alterform = { x=0.56, y=0.79, w=0.03, h=0.21 },  -- not yet built
```

---

## Summary of Files Affected

| Contract | Sections superseded |
|---|---|
| Contract_LayoutEngine.md | Persistence model, defaults table (MyDSL_Mapper deleted, MyDSL_Tick confirmed), Gap 1 + Gap 4 closed |
| Contract_WindowRegistry.md | Window creation (§ ensure()), startup sequence, docking now left-column-only |
| Contract_RouteHelper.md | § Route Name Map (DSL1 → DSL2) |
| Contract_PortraitView.md | § CharPic Compatibility Global, related aliases |

No other contracts are affected by this addendum.

**Note on section 5:** Section 5 corrects section 1's overly broad docking
claim. Read section 5 as authoritative over section 1 wherever they conflict
— section 1's general Mudlet-docking research is still accurate, but its
application to "every docked window" was too broad. Only Scan/Combat actually
use `docked=true`.
