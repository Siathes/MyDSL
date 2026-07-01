# MyDSL Mudlet Window Management Reference
**Compiled from official Mudlet wiki (wiki.mudlet.org/w/Manual:Geyser)**
**and Geyser source documentation (mudlet.org/geyser)**
*Revised June 28 2026 — corrects errors in the June 25 2026 version*

---

## Geyser.UserWindow — Official Parameter Defaults

From the official Geyser UserWindow documentation
(https://www.mudlet.org/geyser/files/geyser/Geyser.UserWindow.html):

| Parameter | Default | Description |
|---|---|---|
| `restoreLayout` | **false** | Restore previously saved layout on load |
| `autoDock` | **true** | Allow docking when dragged to window borders |
| `dockPosition` | **"right"** | Which side when docked=true |
| `docked` | nil/false | Start already docked (x/y/w/h IGNORED when true) |
| `titleText` | window name | Title bar text |

---

## What Each Parameter Actually Does

### `docked = true`
Creates the window already docked to a side. When this is set:
- x, y, width, height are IGNORED entirely
- dockPosition determines which side
- Multiple windows docked to the same side form a tab group

```lua
testuserwindow = Geyser.UserWindow:new({
  name = "DockedTestUserWindow",
  docked = true,
  dockPosition = "left",
})
```

### `autoDock = true` (THE DEFAULT)
When the user drags a window near a screen edge, it docks there.
This is Mudlet's default — you do not need to set it explicitly.
To PREVENT a window from docking when dragged:
```lua
myWindow:disableAutoDock()
```

### `restoreLayout = true`
When `true`, `loadWindowLayout()` will restore this window's saved position.
When `false` (default), `loadWindowLayout()` has no effect on this window.

**This parameter does NOT conflict with specifying x/y/w/h in the constructor.**
The conflict in earlier versions of this document was caused by calling
`winObj:move()` and `winObj:resize()` AFTER construction — those post-construction
moves fight with `restoreLayout`. The constructor x/y/w/h are the initial placement
only and do not conflict.

DSL1 proves this: it creates windows at `x="5%", y="5%"` AND patches
`restoreLayout=true` into every window via the constructor patch. This works
because DSL1 never calls `move()`/`resize()` after construction.

---

## saveWindowLayout() / loadWindowLayout()

The official Mudlet manual workflow:
```lua
-- create your userwindows first with Geyser.UserWindow:new
-- then restore them to the positions they were at:
loadWindowLayout()
```

- `saveWindowLayout()` — saves current position and dock state of ALL UserWindows
  with `restoreLayout=true`
- `loadWindowLayout()` — restores to the last saved state
- Must call `loadWindowLayout()` AFTER all windows are created, not before

**User workflow:**
1. Load profile → windows appear at their initial positions
2. Move and dock windows where you want them
3. Run `mydsl layout save` → calls `saveWindowLayout()` + `saveProfile()`
4. Every future load: windows restore to your saved arrangement

---

## The sysWindowResizeEvent / reflowAll() Problem — ROOT CAUSE OF RESETS

**This was the actual cause of windows snapping back to default positions.**

LayoutEngine registered a `sysWindowResizeEvent` handler that called
`reflowAll()`, which called `applyToWindow()` on every window. `applyToWindow()`
calls `winObj:resize(px, ph)` and `winObj:move(px, py)` using LayoutEngine's
default pixel positions.

`sysWindowResizeEvent` fires when:
- The Mudlet application window is resized
- A UserWindow is docked (changes the internal Qt layout)

So every dock operation triggered `reflowAll()` which forcibly moved ALL windows
back to LayoutEngine's default positions via `resize()` and `move()` calls.

**The fix:** Remove the `sysWindowResizeEvent` handler from LayoutEngine entirely.
`reflowAll()` and `applyToWindow()` remain available as functions for explicit
calls, but are no longer triggered automatically on resize/dock events.

**This was the root cause. Not `loadWindowLayout()`. Not timers. Not
`restoreLayout` conflicts. The LayoutEngine resize handler was doing it.**

---

## Console Border Management

**Mudlet adjusts the main console automatically when UserWindows are docked.**
`setBorderLeft/Right/Bottom` is NOT needed for UserWindows that the user
positions via drag-and-dock.

`setBorderLeft` is only needed if you want to reserve space for windows that
are NOT docked — i.e., floating windows that overlap the console. For our
design where users dock panels to the sides and bottom, Mudlet handles the
console space automatically.

**Do NOT call `setBorderLeft/Right/Bottom` in response to `sysWindowResizeEvent`
— this causes cascading resize events.**

---

## Constructor Patch (DSL2 approach, matching DSL1)

```lua
local function patchUserWindowConstructor()
  if MyDSL.Windows._constructorPatched then return end
  local origNew = Geyser.UserWindow.new
  Geyser.UserWindow.new = function(self, cons, ...)
    cons = cons or {}
    if cons.restoreLayout == nil then cons.restoreLayout = true end
    if cons.autoDock == nil then cons.autoDock = true end
    return origNew(self, cons, ...)
  end
  MyDSL.Windows._constructorPatched = true
end
```

This patches ALL UserWindow creation across all modules — WindowRegistry,
ChatWrapper, AffectsView, PortraitView — so every window gets `restoreLayout=true`
without each module needing to specify it.

---

## Correct DSL2 Startup Sequence

```lua
patchUserWindowConstructor()   -- before any windows are created
MyDSL.Windows.loadState()      -- restore visibility booleans from disk
MyDSL.Windows.ensureAll()      -- create all windows at LayoutEngine positions
if loadWindowLayout then        -- restore previously saved positions/dock state
  loadWindowLayout()
end
```

No timers needed — all windows exist synchronously after `ensureAll()`.
No `saveWindowLayout()` at startup — that would overwrite the user's saved layout.
No `sysWindowResizeEvent` handler — that caused the reset problem.

---

## Modules That Create Their Own UserWindows

Three Layer 3 modules create their own UserWindows outside WindowRegistry:

| Module | Window | Hardcoded position |
|---|---|---|
| `MyDSL_ChatWrapper.lua` | `MyDSL_Chat` | x=78%, y=0%, w=22%, h=46% |
| `MyDSL_AffectsView.lua` | `MyDSL_Affects` | x=70%, y=35%, w=30%, h=25% |
| `MyDSL_PortraitView.lua` | `MyDSL_Portrait` | x=0%, y=0%, w=20%, h=30% |

The constructor patch catches all three and injects `restoreLayout=true`.
Their hardcoded positions are the initial/default placement only.
`loadWindowLayout()` at startup overrides with the user's saved positions.

ChatWrapper also fires `C.resize()` on timers at 0.4s, 1.5s, 3.5s, and 5s.
`C.resize()` calls `ch:move(0,0)` and `ch:resize("100%","100%")` on the EMCO
object INSIDE the Chat window — not on the window itself. This is correct.

---

## What Was Wrong in Earlier Versions of This Document

| Claim | Correct answer |
|---|---|
| "`restoreLayout=true` conflicts with x/y/w/h" | False. The conflict was post-construction `move()`/`resize()` calls, not constructor parameters. |
| "Remove `restoreLayout=true` from constructor patch" | Wrong. It must stay in the patch. |
| "Add `applyBorders()` on `sysWindowResizeEvent`" | Wrong. This caused cascading resize events and isn't needed for docked windows. |
| "The reset is caused by `loadWindowLayout()`" | Wrong. It was caused by LayoutEngine's `sysWindowResizeEvent` handler calling `reflowAll()`. |
| "Need `saveWindowLayout()` immediately after `ensureAll()`" | Wrong. This overwrites the user's saved layout with defaults. |
| "Need two timers (1s and 3s) calling `loadWindowLayout()`" | Unnecessary. One immediate `loadWindowLayout()` after `ensureAll()` is sufficient. |

---

## Key References

- Official Geyser manual: https://wiki.mudlet.org/w/Manual:Geyser#Geyser.UserWindow
- Official Geyser UserWindow API: https://www.mudlet.org/geyser/files/geyser/Geyser.UserWindow.html
- Mudlet UI Functions (saveWindowLayout, loadWindowLayout): https://wiki.mudlet.org/w/Manual:UI_Functions
