# Module Contract: MyDSL_ThemeEngine.lua
**Layer 2 — Visual Theme System, File 1 of 3**
*Written from actual code + design decisions recorded June 9, 2026*
*File: MyDSL_ThemeEngine.lua (261 lines current — will grow with persistence)*

---

## What This Module Is

ThemeEngine owns all visual constants for the Observer UI — fonts, colors, borders.
It is a pure data store with converters. It has no display logic, creates no windows,
echoes no text, and sends nothing to the game. Every module that needs a color or font
reads it from here via `MyDSL.Theme.get()`.

---

## Namespace

```lua
MyDSL.Theme             -- sub-namespace
MyDSL.Theme.defaults    -- hardcoded fallback values (in file, never written to disk)
MyDSL.Theme.presets     -- named themes shared across all characters (saved to disk)
MyDSL.Theme.characters  -- per-character active settings (saved to disk, per file)
MyDSL.Theme.overrides   -- runtime per-window overrides (session only, applied on top)
```

All use safe reload guards (`or {}`).

---

## Public API — Reading

```lua
-- Read a theme value for a specific window (always use this):
MyDSL.Theme.get(windowName, key)
-- Resolution order (first match wins):
--   1. runtime overrides[windowName][key]
--   2. characters[currentChar].overrides[key]
--   3. presets[characters[currentChar].activePreset][key]
--   4. defaults[key]
--   5. nil

-- Get the name of the active preset for the current character:
MyDSL.Theme.activePreset()
-- Returns: string (e.g. "druid") or nil if using raw defaults

-- List all available named presets:
MyDSL.Theme.listPresets()
-- Returns: sorted table of preset name strings

-- List all valid theme keys (for validation and alias help):
MyDSL.Theme.validKeys()
-- Returns: sorted table of key strings from defaults
```

---

## Public API — Creating & Managing Presets

```lua
-- Save current settings as a named preset (available to all characters):
MyDSL.Theme.savePreset(presetName)
-- Saves characters[currentChar] state as a named preset in presets[presetName]
-- Writes presets to: getMudletHomeDir() .. "/MyDSL_theme_presets.lua"

-- Load a named preset, applying it to the current character:
MyDSL.Theme.loadPreset(presetName)
-- Sets characters[currentChar].activePreset = presetName
-- Refreshes the active UI (see applyToAll())
-- Saves character settings to disk

-- Delete a named preset:
MyDSL.Theme.deletePreset(presetName)
-- Removes from presets table and re-saves the presets file

-- Rename a preset:
MyDSL.Theme.renamePreset(oldName, newName)
```

---

## Public API — Character Settings

```lua
-- Called automatically by DataLayer on login event:
MyDSL.Theme.onLogin(charName)
-- Loads character theme file if it exists
-- If no file found: creates entry using defaults, saves it, announces new character

-- Save current character's theme settings to disk:
MyDSL.Theme.saveCharacter(charName)
-- Writes to: getMudletHomeDir() .. "/MyDSL_theme_Kien.lua" (name substituted)

-- Load a character's saved theme from disk:
MyDSL.Theme.loadCharacter(charName)
-- Reads from the character's theme file
-- Falls back to defaults if file not found

-- Apply the current active theme to every open window:
MyDSL.Theme.applyToAll()
-- Calls a registered callback for each Layer 3 module so they can re-style themselves
-- Modules register via: MyDSL.Theme.registerRefreshCallback(moduleName, fn)
```

---

## Public API — Runtime Overrides

```lua
-- Set one value for one window (session only, on top of character/preset settings):
MyDSL.Theme.setOverride(windowName, key, value)

-- Remove all runtime overrides for one window:
MyDSL.Theme.clearOverride(windowName)

-- Promote current runtime overrides to character permanent settings:
MyDSL.Theme.commitOverrides()
-- Merges overrides into characters[currentChar].overrides and saves
```

---

## Public API — Converters

```lua
-- RGBA table → CSS string (for Geyser stylesheets):
MyDSL.Theme.colorToCSS({r=18, g=20, b=28, a=242})
-- Returns: "rgba(18,20,28,0.95)"

-- RGBA table → decho tag (for MiniConsole text):
MyDSL.Theme.colorToEcho({r=210, g=50, b=50, a=255})
-- Returns: "<210,50,50>"
-- Note: alpha ignored — decho does not support transparency
```

---

## Default Values

| Key | Value | Description |
|---|---|---|
| `font` | `"Courier New"` | Body text — monospace |
| `fontSize` | `9` | Body text point size |
| `titleFont` | `"Arial"` | Window title bar |
| `titleFontSize` | `10` | Title bar point size |
| `bgColor` | `{r=18,g=20,b=28,a=242}` | Window background |
| `textColor` | `{r=210,g=208,b=200,a=255}` | Body text |
| `borderColor` | `{r=60,g=70,b=90,a=255}` | Window border |
| `borderSize` | `1` | Border thickness (px) |
| `titleColor` | `{r=200,g=220,b=255,a=255}` | Title bar text |
| `highlightColor` | `{r=220,g=180,b=60,a=255}` | Active/selected (amber) |
| `dimColor` | `{r=90,g=90,b=90,a=255}` | Inactive/stale (grey) |
| `warnColor` | `{r=210,g=50,b=50,a=255}` | Danger/alert (red) |
| `goodColor` | `{r=80,g=185,b=80,a=255}` | Positive/healthy (green) |

---

## Data Model on Disk

**Two file types, both written by ThemeEngine:**

```
getMudletHomeDir()/MyDSL_theme_presets.lua       ← shared, all characters
getMudletHomeDir()/MyDSL_theme_Kien.lua          ← per character (name substituted)
getMudletHomeDir()/MyDSL_theme_Olyndros.lua
getMudletHomeDir()/MyDSL_theme_Tibbins.lua
```

**Presets file structure:**
```lua
-- MyDSL_theme_presets.lua
return {
  druid = {
    bgColor   = { r=10, g=20, b=10, a=255 },
    textColor = { r=200, g=230, b=200, a=255 },
    -- only keys that differ from defaults need to be stored
  },
  combat = {
    warnColor = { r=255, g=0, b=0, a=255 },
    fontSize  = 10,
  },
}
```

**Character file structure:**
```lua
-- MyDSL_theme_Kien.lua
return {
  activePreset = "druid",   -- name of the loaded preset (nil = using defaults)
  overrides    = {          -- personal overrides on top of the preset
    ["MyDSL_Chat"] = { fontSize = 8 },
  },
}
```

---

## get() Resolution Order (full)

```
get("MyDSL_Chat", "fontSize")
  │
  ├─ 1. overrides["MyDSL_Chat"]["fontSize"]?          → runtime window override
  ├─ 2. characters["Kien"].overrides["fontSize"]?     → character-level override
  ├─ 3. presets["druid"]["fontSize"]?                 → active preset value
  ├─ 4. defaults["fontSize"]?                         → hardcoded default (9)
  └─ 5. nil                                           → caller uses own fallback
```

---

## Alias Commands (for Claude Code to implement)

```
mydsl theme list                     → list all saved presets
mydsl theme load <name>              → load a named preset for current character
mydsl theme save <name>              → save current settings as a named preset
mydsl theme delete <name>            → delete a named preset
mydsl theme set <key> <value>        → set one value (runtime, current character)
mydsl theme reset                    → clear all overrides, return to active preset
mydsl theme info                     → show current character's active preset and overrides
```

---

## What This Module Does NOT Do

- Does not create windows
- Does not echo text to any console
- Does not send commands to the game
- Does not listen to GMCP events (onLogin is called BY DataLayer, not registered here)
- Does not read from DataLayer
- Does not manage window positions (that is LayoutEngine's job)

---

## Dependencies

**Requires:** Nothing at load time. `MyDSL` created if absent.
**onLogin called by:** DataLayer login handler (passes character name)
**Refresh callbacks registered by:** Layer 3 display modules at their init

**Must load before:** LayoutEngine, WindowRegistry, all Layer 3 modules.

---

## Load Order

```
ThemeEngine     ← loads first, no dependencies
LayoutEngine    ← reads ThemeEngine
WindowRegistry  ← reads ThemeEngine + LayoutEngine
[Layer 3]       ← reads all Layer 2, registers refresh callbacks with ThemeEngine
```

---

## Gaps from Original Code — Resolution Status

| Gap | Description | Resolution |
|---|---|---|
| Gap 1 — No persistence | Runtime overrides lost on reload | ✅ RESOLVED — add save/load per character |
| Gap 2 — No key validation | Typos in setOverride silently fail | ✅ RESOLVED — validKeys() function added to API |
| Gap 3 — UserWindow alpha | setStyleSheet not available on UserWindow | ⚠️ Known Mudlet constraint — document in Layer 3 contracts, not fixable here |
| Gap 4 — No theme switcher | No named themes, no per-character themes | ✅ RESOLVED — presets system + character binding added |

---

## Contract Status

| Clause | Status |
|---|---|
| Never sends game commands | ✅ |
| No display logic | ✅ |
| No window creation | ✅ |
| Safe reload guards | ✅ |
| get() checks all levels in order | 🔲 Needs implementation |
| Persistent preset storage | 🔲 Needs implementation |
| Per-character theme binding | 🔲 Needs implementation |
| onLogin hook | 🔲 Needs implementation |
| applyToAll() with callbacks | 🔲 Needs implementation |
| Alias command set | 🔲 Needs implementation |
| colorToCSS() nil-safe | ✅ Already in code |
| colorToEcho() nil-safe | ✅ Already in code |
