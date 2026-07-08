-- =============================================================================
-- MyDSL_ThemeEngine.lua  --  Layer 2, File 1 of 3: Visual Theme System
-- =============================================================================
-- This file owns all visual constants: fonts, colors, borders.
-- It has NO display logic — it never creates windows, never echoes text,
-- never sends commands to the game.
-- Layer 3 (the UI layer) calls MyDSL.Theme.get() to read values from here.
-- =============================================================================


------------------------------------------------------------------------
-- NAMESPACE GUARD
------------------------------------------------------------------------
-- In Lua, every name you use without 'local' is a global variable.
-- MyDSL is a global table that all our scripts share.
--
-- The 'or {}' pattern means:
--   "If MyDSL already exists in memory, keep it exactly as it is.
--    If it doesn't exist yet, create a new empty table and use that."
--
-- This matters because Mudlet lets you re-save and re-run a script
-- while the game is still connected. Without this guard, every reload
-- would wipe out whatever the other scripts had already stored in MyDSL.

MyDSL = MyDSL or {}

-- Same guard for the Theme sub-namespace.
-- MyDSL.Theme is itself a table inside the MyDSL table.
MyDSL.Theme = MyDSL.Theme or {}


------------------------------------------------------------------------
-- SECTION 1: DEFAULT THEME VALUES
------------------------------------------------------------------------
-- MyDSL.Theme.defaults is a Lua table used as a dictionary:
-- each key is a string name, each value is the setting for that name.
--
-- A "table literal" in Lua looks like:  { key = value, key = value }
-- The curly braces create a new table. The key = value pairs go inside.
-- Sub-tables (like the color entries) are just tables inside tables.
--
-- RGBA color tables have four fields: r, g, b (0-255) and a (0-255).
-- Full opacity is a=255. Fully transparent is a=0.
-- The 'a' channel is used when converting to CSS (e.g. Geyser stylesheets).
-- decho only supports RGB so alpha is ignored there.
--
-- We use the guard pattern again here: if Theme.defaults already exists
-- (e.g. from a previous load), we keep it rather than overwriting it.
-- This lets a future config system pre-populate defaults before this
-- file runs, and we won't stomp on it.

MyDSL.Theme.defaults = MyDSL.Theme.defaults or {

  -- ---- FONTS -------------------------------------------------------

  -- font: the typeface used in all content windows (miniConsoles).
  -- A monospace font is strongly recommended for MUD output — it keeps
  -- columns aligned and makes the ASCII map readable.
  font          = "Courier New",

  -- fontSize: point size for content text. 9pt is readable at 1920x1080
  -- without wasting vertical space in narrow side panels.
  fontSize      = 9,

  -- titleFont: typeface used in window title bars or header labels.
  -- A slightly different font here gives titles visual separation from content.
  titleFont     = "Arial",

  -- titleFontSize: title bars can be slightly larger than body text
  -- to help the eye find window boundaries quickly.
  titleFontSize = 10,

  -- ---- BASE COLORS -------------------------------------------------

  -- bgColor: the background fill of every window.
  -- Near-black with slight blue tint — easier on eyes than pure black,
  -- and distinguishable from the Mudlet main console background.
  bgColor       = { r =  18, g =  20, b =  28, a = 242 },  -- ~95% opaque

  -- textColor: default foreground for body text.
  -- Slightly warm off-white rather than pure white — reduces contrast
  -- fatigue during long play sessions.
  textColor     = { r = 210, g = 208, b = 200, a = 255 },

  -- borderColor: the thin line drawn around window edges.
  -- A muted blue-grey that's visible against the dark background
  -- without screaming for attention.
  borderColor   = { r =  60, g =  70, b =  90, a = 255 },

  -- borderSize: thickness of the window border in pixels.
  -- 1px is sufficient at 1920x1080. Increase if running on a 4K display.
  borderSize    = 1,

  -- titleColor: text color used in window title bars.
  -- Slightly brighter than body text so the title stands out.
  titleColor    = { r = 200, g = 220, b = 255, a = 255 },

  -- ---- SEMANTIC COLORS ---------------------------------------------
  -- These colors carry meaning. Layer 3 uses them consistently so the
  -- player learns: gold = notable, red = danger, green = good.

  -- highlightColor: used for active, selected, or recently-updated elements.
  -- Warm amber/gold — visible without being aggressive.
  highlightColor = { r = 220, g = 180, b =  60, a = 255 },

  -- dimColor: used for inactive, stale, or secondary information.
  -- Dark grey — present but receding.
  dimColor       = { r =  90, g =  90, b =  90, a = 255 },

  -- warnColor: low HP, expiring affects, resource alerts.
  -- Clear red that stands out immediately.
  warnColor      = { r = 210, g =  50, b =  50, a = 255 },

  -- goodColor: full health, active buffs, positive conditions.
  -- Soft green — readable and clearly positive.
  goodColor      = { r =  80, g = 185, b =  80, a = 255 },
}


------------------------------------------------------------------------
-- SECTION 2: PER-WINDOW OVERRIDES
------------------------------------------------------------------------
-- MyDSL.Theme.overrides is a table of tables.
-- The outer key is the window name (a string matching the Geyser window name).
-- The inner table contains only the keys that differ from the defaults.
-- Keys not present in the override simply fall through to defaults.
--
-- Example structure (do not uncomment — this is illustration only):
--
--   MyDSL.Theme.overrides["MyDSL_Chat"] = {
--     fontSize  = 8,                              -- smaller text in chat
--     bgColor   = { r=10, g=10, b=10, a=255 },   -- slightly darker background
--   }
--
--   MyDSL.Theme.overrides["MyDSL_Affects"] = {
--     font      = "Consolas",   -- different font for the affects panel
--   }
--
-- To set an override from Lua at runtime, use MyDSL.Theme.setOverride().

MyDSL.Theme.overrides = MyDSL.Theme.overrides or {}


------------------------------------------------------------------------
-- SECTION 3: ACCESSOR — get(windowName, key)
------------------------------------------------------------------------
-- Reading a theme value should always go through this function,
-- never by accessing MyDSL.Theme.defaults directly.
--
-- Why? Because it gives us two things for free:
--   1. Per-window overrides are checked first, so a window can look
--      different from the default without touching shared state.
--   2. If we ever change where values are stored, only this function
--      needs to change — every caller continues to work unchanged.
--
-- 'local' means this variable exists only inside this function.
-- Using locals for intermediate values is a Lua best practice:
-- local lookups are faster than global lookups, and they don't
-- accidentally leak names into the shared environment.

function MyDSL.Theme.get(windowName, key)
  -- Check if this window has any overrides at all.
  -- The 'and' here is a short-circuit guard: if overrides[windowName]
  -- is nil (no entry exists), Lua would crash trying to index nil[key].
  -- Writing 'a and a[key]' prevents that — if 'a' is nil, the expression
  -- returns nil immediately without evaluating 'a[key]'.
  local overrideTable = MyDSL.Theme.overrides[windowName]
  if overrideTable then
    local overrideValue = overrideTable[key]
    if overrideValue ~= nil then
      -- Found an override for this window and key — return it directly.
      return overrideValue
    end
  end

  -- No override found — fall back to the shared defaults.
  return MyDSL.Theme.defaults[key]
  -- If the key doesn't exist in defaults either, this returns nil.
  -- Callers should handle nil gracefully (e.g. 'value or fallback').
end


------------------------------------------------------------------------
-- SECTION 4: COLOR CONVERTERS
------------------------------------------------------------------------

-- colorToCSS(rgba)
-- Converts an RGBA table {r,g,b,a} to a CSS color string.
-- Used when setting Geyser window stylesheets, which accept CSS syntax.
--
-- Example: { r=18, g=20, b=28, a=242 }  →  "rgba(18,20,28,0.95)"
--
-- CSS alpha is a decimal 0.0 (transparent) to 1.0 (opaque).
-- Our tables store alpha as 0–255, so we divide by 255 to convert.
--
-- string.format() works like printf in C. "%.2f" means: format as a
-- floating-point number with exactly 2 decimal places.

function MyDSL.Theme.colorToCSS(rgba)
  -- Guard: if rgba is nil or missing fields, return a safe default.
  if not rgba then return "rgba(0,0,0,1)" end
  local r = rgba.r or 0
  local g = rgba.g or 0
  local b = rgba.b or 0
  local a = rgba.a or 255
  return string.format("rgba(%d,%d,%d,%.2f)", r, g, b, a / 255)
end

-- colorToEcho(rgba)
-- Converts an RGBA table to a Mudlet decho color tag.
-- decho uses the format "<r,g,b>" for foreground color.
-- Alpha is not supported by decho, so we ignore it here.
--
-- Example: { r=210, g=50, b=50, a=255 }  →  "<210,50,50>"
--
-- decho tags are used inline in strings passed to decho(), e.g.:
--   decho("<210,50,50>WARNING<r>\n")
-- The "<r>" at the end resets the color back to default.

function MyDSL.Theme.colorToEcho(rgba)
  if not rgba then return "<255,255,255>" end
  local r = rgba.r or 255
  local g = rgba.g or 255
  local b = rgba.b or 255
  return string.format("<%d,%d,%d>", r, g, b)
end


------------------------------------------------------------------------
-- SECTION 5: OVERRIDE MANAGEMENT
------------------------------------------------------------------------

-- setOverride(windowName, key, value)
-- Sets a single theme value for a specific window.
-- Only that key is overridden — all other keys still fall back to defaults.
--
-- Example usage from another script:
--   MyDSL.Theme.setOverride("MyDSL_Chat", "fontSize", 8)
--   MyDSL.Theme.setOverride("MyDSL_Chat", "bgColor", {r=10,g=10,b=10,a=255})

function MyDSL.Theme.setOverride(windowName, key, value)
  -- Key validation added 2026-07-07 (confirmed LOW PRIORITY gap: this
  -- silently accepted any key, so a typo'd key would set a value that
  -- nothing ever reads, with no error to notice by). MyDSL.Theme.defaults
  -- is the canonical key set every real theme property is drawn from, so
  -- anything not already in there isn't a real theme key.
  if MyDSL.Theme.defaults[key] == nil then
    debugc("[MyDSL] ThemeEngine: setOverride() ignored unknown key '" .. tostring(key) .. "'")
    return false
  end
  -- If there's no override table for this window yet, create one.
  -- This is the same 'or {}' guard pattern, applied per-window.
  MyDSL.Theme.overrides[windowName] = MyDSL.Theme.overrides[windowName] or {}
  MyDSL.Theme.overrides[windowName][key] = value
  return true
end

-- clearOverride(windowName)
-- Removes all overrides for a named window, returning it to defaults.
-- Sets the window's override entry to nil, which removes it from the table.
-- In Lua, setting a table key to nil deletes that key entirely.

function MyDSL.Theme.clearOverride(windowName)
  MyDSL.Theme.overrides[windowName] = nil
end


------------------------------------------------------------------------
-- LOAD CONFIRMATION
------------------------------------------------------------------------
debugc("[MyDSL] ThemeEngine loaded.")
