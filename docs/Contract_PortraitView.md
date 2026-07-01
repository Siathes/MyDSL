# Module Contract: MyDSL_PortraitView.lua
**Layer 3 — Character Portrait Display**
*Written from actual code. Version: v4C4 CoverDefault. File: MyDSL_PortraitView.lua (908 lines)*

---

## What This Module Is

PortraitView shows a character portrait image in the `MyDSL_Portrait` window.
It automatically finds the correct image based on character name, supports
per-character image path overrides, and provides backward compatibility with
the older `CharPic` global used by legacy scripts.

---

## Namespace

```lua
MyDSL.Portrait        -- canonical module namespace
CharPic               -- backward-compatible global (mirrors all Portrait functions)
```

---

## Image Lookup — How It Works

On login or GMCP update, PortraitView resolves which image to show:

```
1. Check P.data.characters[charName] for a manually set override path
2. Auto-discover: look for <imgDir>/<CharName>.png (spaces → underscores)
3. If found: renderImage(path) — display it
4. If not found: renderMissing() — show caption or blank
```

**Auto-discovery naming:**
```
Character: "Kien"       → Kien.png
Character: "John Doe"   → John_Doe.png
```

**Default portrait directory:**
```
getMudletHomeDir()/MyDSL/portraits/
```

Configurable via `mydsl portrait dir <path>`.

---

## Geyser Structure

Two Labels inside the UserWindow:

```
P.window (Geyser.UserWindow "MyDSL_Portrait")
├── P.label  (Geyser.Label — full window, displays image via CSS background-image)
└── P.caption (Geyser.Label — bottom 11%, shows character name text)
```

Image is applied as CSS: `background-image: url(path); background-size: cover;`
Caption is shown when image is missing (`missingMode = "caption"`).

---

## Image Fit Modes

| Mode | Behavior |
|---|---|
| `cover` (default) | Fills window, may crop edges |
| `stretch` | Distorts to fill exactly |
| `contain` | Letterbox — mapped to `cover` on Mudlet/Linux due to CSS limitations |

---

## Per-Character Data

**Profile file (shared, contains all character paths):**
```
getMudletHomeDir()/MyDSL/portraits/portrait_profiles.lua
```

**Structure:**
```lua
{
  settings = {
    imgDir = "/path/to/portraits/",
    fit    = "cover",
  },
  characters = {
    kien     = { name="Kien",     path="/path/to/Kien.png",     file="Kien.png" },
    olyndros = { name="Olyndros", path="/path/to/Olyndros.png", file="Olyndros.png" },
  },
}
```

Character paths are per-character. Settings (imgDir, fit) are shared.
This is a hybrid character-binding model — appropriate for portraits.

---

## Character Name Resolution

`P.getCharName()` reads from (first non-empty wins):

```lua
gmcp.char_data.name        -- "Kien" (confirmed primary)
gmcp.login_data.name       -- secondary
gmcp.char_data.character_name  -- legacy field name variant
```

---

## Handler Management — CORRECT PATTERN ✅

Local `registerHandler(key, eventName, fn)` kills old handler before registering:

```lua
local function registerHandler(key, eventName, fn)
  if P.handlers[key] then
    pcall(killAnonymousEventHandler, P.handlers[key])
    P.handlers[key] = nil
  end
  P.handlers[key] = registerAnonymousEventHandler(eventName, fn)
end
```

Same pattern as AffectsView's `registerHandlerOnce`. Correct reload safety.

---

## Events

```lua
"gmcp.char_data"    → tempTimer(0.15, refresh)  -- character data update
"gmcp.login_data"   → tempTimer(0.15, refresh)  -- login
"sysConnectionEvent"→ tempTimer(1.0, refresh)   -- reconnect
```

All use deferred timers to let GMCP fully populate before reading `charName`.

---

## Window Creation

Tries WindowRegistry first (correct), falls back to own UserWindow:

```lua
-- Fallback (wrong position — see Gap 2):
Geyser.UserWindow:new({
  name  = "MyDSL_Portrait",
  x = "0%", y = "0%",   -- ⚠️ should be bottom strip
  width = "20%", height = "30%",
})
```

---

## CharPic Compatibility Global

`P.installCompatGlobal()` creates a `CharPic` global mirroring all functions:

```lua
CharPic.refresh()          -- P.refresh()
CharPic.setByName(name)    -- P.setByName(name)
CharPic.setImage(path)     -- P.renderImage(path)
CharPic.probe(name)        -- P.probe(name)
CharPic.show() / hide()    -- P.show() / P.hide()
CharPic.setDir(path)       -- P.setDir(path)
CharPic.setFit(mode)       -- P.setFit(mode)
```

Any legacy script calling `CharPic.refresh()` continues working without changes.

---

## Public API

```lua
P.refresh(reason)           -- resolve and display correct image for current char
P.setByName(name)           -- override to display image for named character
P.setPath(path, charName)   -- manually set image path for a character
P.clearPath(charName)       -- remove manual override (returns to auto-discover)
P.probe(name)               -- show which file would be used for a character
P.dump()                    -- print full state and config
P.setDir(path)              -- change portrait directory
P.setFit(mode)              -- cover|stretch|contain
P.setMissing(mode)          -- caption|blank
P.setFont(size)             -- caption text font size
P.setFrame(on|off)          -- show/hide border frame
P.show() / P.hide()
P.rebuild()                 -- destroy and recreate UI elements
P.reset()                   -- clear override, refresh from auto-discover
P.save() / P.load()
P.status()
```

---

## Aliases

```
mydsl portrait [status|show|hide|refresh|rebuild|clear]
mydsl portrait set <path>
mydsl portrait dir [path]
mydsl portrait name <name>
mydsl portrait probe [name]
mydsl portrait font <size>
mydsl portrait frame on|off
mydsl portrait fit cover|stretch|contain
mydsl portrait missing caption|blank
mydsl portrait title <text>
-- CharPic compatibility aliases also installed
```

---

## Philosophy Compliance

Display only. No game commands sent. Auto-refreshes only on GMCP events
(passive). All configuration changes are user-initiated.

---

## Dependencies

**Reads from:** `gmcp.char_data.name`, `gmcp.login_data.name`
**Creates:** `CharPic` global (backward compat)
**Uses:** WindowRegistry when available, own UserWindow as fallback
**Must load after:** WindowRegistry

---

## What This Module Does NOT Do

- Does not fetch images from internet
- Does not modify game text or routing
- Does not interact with other MyDSL modules except WindowRegistry
- Does not send game commands

---

## Gaps and Issues Found in Code

### Gap 1 — WindowRegistry integration partial ⚠️
`P.ensureWindow()` tries WindowRegistry first — this is correct. However,
the `getWindowObject()` function has the same fragile key lookup issue as
ChatWrapper, checking multiple key variants (`entry.obj`, `entry.win`,
`entry.window`, `entry.userWindow`, `entry.container`).

If WindowRegistry stores the window under `entry.obj` (which it does based
on the WindowRegistry contract), this will work. But if the key changes,
it silently falls back to the own-UserWindow path.

**Fix:** Standardize on `entry.obj` as the single canonical key.

### Gap 2 — Fallback window position wrong ❌
If WindowRegistry unavailable:
```lua
x="0%", y="0%", width="20%", height="30%"
```
Confirmed layout has Portrait at x=0.11, y=0.79, w=0.07, h=0.21 (bottom strip).

**Fix:** Update fallback to:
```lua
x="11%", y="79%", width="7%", height="21%"
```

### Gap 3 — Refresh fires on every GMCP event ⚠️
`gmcp.char_data` fires after every server response. Each fire schedules a
0.15s deferred `P.refresh()`. This means the portrait resolves and potentially
re-applies CSS on every single command the player types.

In practice this is harmless because:
- The charName doesn't change (same character)
- `P.pathFor()` returns the same cached path
- CSS re-application is fast

But it is wasteful. A guard checking if charName changed would eliminate
redundant refreshes:

```lua
registerHandler("gmcp_char_data", "gmcp.char_data", function()
  local name = P.getCharName()
  if name ~= P.state.lastResolvedChar then
    tempTimer(0.15, function() P.refresh("gmcp.char_data") end)
  end
end)
```

### Gap 4 — Settings partially shared, partially per-character ℹ️
Image paths are per-character (stored in `P.data.characters[key]`). Settings
like `imgDir` and `fit` are shared across all characters. This is intentional
and appropriate — it would be odd for portrait directory to differ per character
on the same machine.

No action needed. Documenting for clarity.

### Gap 5 — `contain` mode not supported on Mudlet/Linux ℹ️
The code notes that CSS `background-size: contain` doesn't render correctly in
Mudlet's Qt WebEngine on Linux and maps it to `cover` instead. This means
letterbox mode (contain) is not available on the primary development platform.

No action needed — documented in code, confirmed in header.

---

## Contract Status

| Clause | Status |
|---|---|
| Display only, no game commands | ✅ |
| Auto-discover image by character name | ✅ |
| Per-character image path overrides | ✅ |
| Handler management (kills old handlers) | ✅ Correct pattern |
| CharPic compatibility global | ✅ |
| WindowRegistry integration (attempted) | ✅ Tries first |
| Fallback window position correct | ❌ Wrong position — Gap 2 |
| WindowRegistry key lookup | ⚠️ Fragile — Gap 1 |
| Refresh rate optimization | ⚠️ Fires on every GMCP — Gap 3 |
EOF