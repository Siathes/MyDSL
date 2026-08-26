-- =============================================================================
-- MyDSL_ThemeEngine.lua  --  Layer 2, File 1 of 3: Visual Theme System
-- =============================================================================
-- This file owns all visual constants: fonts, colors, borders, and (as of
-- 2026-07-11) a set of named, switchable theme presets.
-- It has no window-content display logic — it never writes into a
-- MiniConsole and never sends commands to the game — but it does own the
-- `theme` alias (list/set/show), matching the precedent already set by
-- MyDSL_WindowRegistry.lua owning "mydsl layout save/reset": a Layer-2 file
-- can own the small set of commands that operate purely on its own data.
-- Layer 3 (the UI layer) calls MyDSL.Theme.get()/panelCSS()/styleConsole()
-- to read values from here, and listens for "MyDSL.theme.changed" to
-- restyle live windows when the active theme switches. (Corrected
-- 2026-08-23: this used to also name titleCSS()/bodyTextCSS() as the
-- contract, but every real consumer builds title/body CSS itself via
-- get()+colorToCSS() instead -- those two functions were dead, removed.)
-- =============================================================================


------------------------------------------------------------------------
-- SECTION 1: NAMESPACE GUARDS
------------------------------------------------------------------------

MyDSL = MyDSL or {}
MyDSL.Theme = MyDSL.Theme or {}
MyDSL.Theme._handlers = MyDSL.Theme._handlers or {}


------------------------------------------------------------------------
-- SECTION 2: BARE DEFAULTS (ultimate fallback, also the key allowlist)
------------------------------------------------------------------------
-- MyDSL.Theme.defaults is the canonical set of every real theme key.
-- setOverride() checks against this table to reject typo'd keys.
-- Values here are only used if the active preset and the "refined
-- convergence" values below happen to omit a key -- in practice every
-- preset below sets every key, so this mostly exists as the validation
-- allowlist plus a safety net.

MyDSL.Theme.defaults = MyDSL.Theme.defaults or {
  font           = "Courier New",
  fontSize       = 9,
  titleFont      = "Courier New",
  titleFontSize  = 9,
  bgColor        = { r =  18, g =  20, b =  28, a = 242 },
  textColor      = { r = 210, g = 208, b = 200, a = 255 },
  borderColor    = { r =  60, g =  70, b =  90, a = 255 },
  borderSize     = 1,
  radius         = 6,
  titleColor     = { r = 200, g = 220, b = 255, a = 255 },
  titleBgColor   = { r =   0, g =   0, b =   0, a =   0 },
  highlightColor = { r = 220, g = 180, b =  60, a = 255 },
  dimColor       = { r =  90, g =  90, b =  90, a = 255 },
  warnColor      = { r = 210, g =  50, b =  50, a = 255 },
  goodColor      = { r =  80, g = 185, b =  80, a = 255 },
}


------------------------------------------------------------------------
-- SECTION 3: NAMED PRESETS
------------------------------------------------------------------------
-- Five directions, presented to Steven as an Artifact mockup (2026-07-11)
-- plus two adapted from ChatGPT concept renders he supplied the same day.
-- Each preset is a complete key set (every MyDSL.Theme.defaults key) so
-- switching presets never leaves a window half-styled from an old theme.
--
-- "zones" (zoned_hud only): per-category border/title/titleBg overrides,
-- keyed by a category name assigned per-window in MyDSL.Theme.windowZone
-- below. Only zoned_hud defines this table; every other preset ignores
-- window zone assignment entirely and uses its own flat border/title
-- colors for every window.

MyDSL.Theme.presets = MyDSL.Theme.presets or {

  -- ---- A: Refined Convergence ---------------------------------------
  -- Promotes Live/Tick's existing look (slate-teal, gold titles) to
  -- every window instead of inventing a fourth style. Lowest risk.
  refined_convergence = {
    font = "Noto Sans Mono", fontSize = 9,
    titleFont = "Noto Sans Mono", titleFontSize = 9,
    bgColor        = { r =  11, g =  16, b =  19, a = 242 },
    textColor      = { r = 232, g = 230, b = 224, a = 255 },
    -- Dimmed 2026-07-11 per Steven ("border thickness, can we make
    -- slimmer?") -- border was already at 1px, the CSS floor for a
    -- visible solid line, so the fix is a subtler color (was full-
    -- brightness 51,67,74,255) rather than a narrower one.
    borderColor    = { r =  33, g =  44, b =  48, a = 200 },
    borderSize     = 1,
    radius         = 8,
    titleColor     = { r = 255, g = 209, b = 102, a = 255 },
    titleBgColor   = { r = 255, g = 209, b = 102, a =  15 },
    highlightColor = { r = 255, g = 209, b = 102, a = 255 },
    dimColor       = { r = 139, g = 150, b = 155, a = 255 },
    warnColor      = { r = 226, g = 102, b =  95, a = 255 },
    goodColor      = { r = 143, g = 214, b = 122, a = 255 },
  },

  -- ---- B: Terminal Purist -------------------------------------------
  -- Near-black, square corners, barely-there borders. The only color in
  -- the whole UI is the text itself (PNP's own green/red/gold) plus a
  -- single muted amber for window titles.
  terminal_purist = {
    font = "Courier New", fontSize = 9,
    titleFont = "Courier New", titleFontSize = 9,
    bgColor        = { r =  10, g =  10, b =  10, a = 255 },
    textColor      = { r = 201, g = 201, b = 192, a = 255 },
    borderColor    = { r =  27, g =  27, b =  27, a = 190 },
    borderSize     = 1,
    radius         = 0,
    titleColor     = { r = 201, g = 162, b =  39, a = 255 },
    titleBgColor   = { r =   0, g =   0, b =   0, a =   0 },
    highlightColor = { r = 255, g = 255, b =  85, a = 255 },
    dimColor       = { r = 110, g = 110, b = 102, a = 255 },
    warnColor      = { r = 255, g =  85, b =  85, a = 255 },
    goodColor      = { r =  79, g = 191, b =  63, a = 255 },
  },

  -- ---- C: Zoned HUD ---------------------------------------------------
  -- ThemeEngine's own original blue-black base, but each window's border
  -- and title pick up a color for its category (combat/status/reference/
  -- social) so window clusters are identifiable at a glance.
  zoned_hud = {
    font = "Noto Sans Mono", fontSize = 9,
    titleFont = "Noto Sans Mono", titleFontSize = 9,
    bgColor        = { r =  18, g =  20, b =  28, a = 242 },
    textColor      = { r = 210, g = 208, b = 200, a = 255 },
    borderColor    = { r =  43, g = 110, b = 104, a = 195 },
    borderSize     = 1,
    radius         = 10,
    titleColor     = { r = 127, g = 214, b = 204, a = 255 },
    titleBgColor   = { r =  72, g = 184, b = 174, a =  26 },
    highlightColor = { r = 240, g = 198, b = 116, a = 255 },
    dimColor       = { r = 136, g = 144, b = 160, a = 255 },
    warnColor      = { r = 239, g = 138, b = 137, a = 255 },
    goodColor      = { r = 127, g = 214, b = 138, a = 255 },
    -- Zone border colors dimmed 2026-07-11 alongside every other preset's
    -- borderColor (see refined_convergence's comment above) -- titleColor/
    -- titleBgColor stay at full brightness (legibility), only the border
    -- line itself is toned down.
    zones = {
      combat    = {
        borderColor  = { r = 130, g =  58, b =  57, a = 195 },
        titleColor   = { r = 239, g = 138, b = 137, a = 255 },
        titleBgColor = { r = 217, g =  96, b =  95, a =  26 },
      },
      status    = {
        borderColor  = { r =  43, g = 110, b = 104, a = 195 },
        titleColor   = { r = 127, g = 214, b = 204, a = 255 },
        titleBgColor = { r =  72, g = 184, b = 174, a =  26 },
      },
      reference = {
        borderColor  = { r =  93, g =  76, b = 134, a = 195 },
        titleColor   = { r = 188, g = 170, b = 240, a = 255 },
        titleBgColor = { r = 155, g = 127, b = 224, a =  26 },
      },
      social    = {
        borderColor  = { r =  64, g = 124, b =  76, a = 195 },
        titleColor   = { r = 140, g = 224, b = 156, a = 255 },
        titleBgColor = { r = 107, g = 207, b = 127, a =  26 },
      },
    },
  },

  -- ---- D: Obsidian Ember ----------------------------------------------
  -- Adapted from a ChatGPT concept render Steven supplied 2026-07-11
  -- ("Obsidian Ember"). Clean near-black, hairline borders, warm ember
  -- accent -- the cheapest of the ChatGPT directions to build 1:1 since
  -- it needs no new art assets, just color/border/font values.
  obsidian_ember = {
    font = "Noto Sans Mono", fontSize = 9,
    titleFont = "Noto Sans Mono", titleFontSize = 9,
    bgColor        = { r =  13, g =  13, b =  13, a = 240 },
    textColor      = { r = 225, g = 220, b = 210, a = 255 },
    borderColor    = { r =  38, g =  38, b =  38, a = 200 },
    borderSize     = 1,
    radius         = 4,
    titleColor     = { r = 230, g = 126, b =  60, a = 255 },
    titleBgColor   = { r = 230, g = 126, b =  60, a =  20 },
    highlightColor = { r = 230, g = 126, b =  60, a = 255 },
    dimColor       = { r = 120, g = 115, b = 108, a = 255 },
    warnColor      = { r = 214, g =  69, b =  65, a = 255 },
    goodColor      = { r = 122, g = 201, b = 122, a = 255 },
  },

  -- ---- E: Arcane Midnight -----------------------------------------------
  -- Adapted from a ChatGPT concept render Steven supplied 2026-07-11
  -- ("Arcane Midnight v2"). Deep indigo/violet, distinct from every other
  -- preset's blue/teal/amber families.
  arcane_midnight = {
    font = "Noto Sans Mono", fontSize = 9,
    titleFont = "Noto Sans Mono", titleFontSize = 9,
    bgColor        = { r =  20, g =  16, b =  36, a = 240 },
    textColor      = { r = 216, g = 210, b = 232, a = 255 },
    borderColor    = { r =  59, g =  46, b =  91, a = 195 },
    borderSize     = 1,
    radius         = 8,
    titleColor     = { r = 185, g = 150, b = 235, a = 255 },
    titleBgColor   = { r =  90, g =  70, b = 140, a =  25 },
    highlightColor = { r = 200, g = 160, b = 255, a = 255 },
    dimColor       = { r = 130, g = 120, b = 150, a = 255 },
    warnColor      = { r = 230, g =  90, b = 110, a = 255 },
    goodColor      = { r = 110, g = 210, b = 160, a = 255 },
  },
}

-- Explicit display/listing order -- pairs() iteration order over
-- MyDSL.Theme.presets is not guaranteed, and "theme list" should show
-- presets in a stable, meaningful order every time.
MyDSL.Theme.presetOrder = MyDSL.Theme.presetOrder or {
  "refined_convergence", "terminal_purist", "zoned_hud",
  "obsidian_ember", "arcane_midnight",
}


------------------------------------------------------------------------
-- SECTION 4: WINDOW -> ZONE ASSIGNMENT (used only by zoned_hud)
------------------------------------------------------------------------

MyDSL.Theme.windowZone = MyDSL.Theme.windowZone or {
  MyDSL_Combat            = "combat",
  MyDSL_Focus             = "combat", -- renamed from MyDSL_Target 2026-07-11
  MyDSL_Group             = "combat",
  MyDSL_Tick              = "combat",
  MyDSL_Alterform         = "combat",
  MyDSL_Affects           = "status",
  MyDSL_Live              = "status",
  MyDSL_PlayersNear       = "status",
  MyDSL_Scan              = "reference",
  MyDSL_RightHere         = "reference",
  MyDSL_Location          = "reference",
  MyDSL_CreatureReference = "reference",
  MyDSL_Portrait          = "reference",
  MyDSL_MoonWeather       = "reference",
  MyDSL_Chat              = "social",
  MyDSL_History           = "social",
}


------------------------------------------------------------------------
-- SECTION 5: PER-WINDOW OVERRIDES (explicit, highest priority)
------------------------------------------------------------------------
-- Unchanged from the original design: a per-window escape hatch that
-- wins over both zone and active-preset values. Set at runtime via
-- MyDSL.Theme.setOverride("MyDSL_Chat", "fontSize", 8).

MyDSL.Theme.overrides = MyDSL.Theme.overrides or {}

-- Player-created named presets, added 2026-08-25 -- closes a real gap
-- between Section 6's own long-standing comment ("Themes are user-
-- creatable named presets") and the actual implementation, which only
-- ever supported switching between the 5 hardcoded ones below. Kept in
-- a separate table from MyDSL.Theme.presets (which stays purely
-- source-defined, read-only) so a custom preset can never collide with
-- or overwrite a built-in on load -- merged into `presets` (and
-- `presetOrder`) in loadActive() below, so every existing read path
-- (get()/setTheme()/list()) needs zero changes to treat a custom
-- preset identically to a built-in one.
MyDSL.Theme.customPresets = MyDSL.Theme.customPresets or {}


------------------------------------------------------------------------
-- SECTION 6: ACTIVE THEME + PERSISTENCE
------------------------------------------------------------------------
-- Themes are user-creatable named presets, shared across all characters
-- (recorded decision, CLAUDE.md "Character-binding" section) -- so this
-- file, not one per character.

local function THEME_FILE()
  return getMudletHomeDir() .. "/MyDSL_theme_settings.lua"
end

MyDSL.Theme.active = MyDSL.Theme.active or "refined_convergence"

-- REAL BUG, found live 2026-07-11: Mudlet's real table.load(file, target)
-- does not return anything -- it unpickles INTO an explicit second-
-- argument table (confirmed in Mudlet's own bundled source). This used
-- to call table.load(THEME_FILE()) with no second argument, so `loaded`
-- was always nil and a saved theme choice never actually survived a
-- restart (same bug found across ~10 call sites project-wide the same
-- day -- see MyDSL_DataLayer.lua's MyDSL.load() for the full writeup).
function MyDSL.Theme.loadActive()
  local f = io.open(THEME_FILE(), "r")
  if not f then return end
  f:close()
  local loaded = {}
  local ok = pcall(table.load, THEME_FILE(), loaded)
  if not ok then return end

  -- Custom presets merged in FIRST, before the active-theme restore
  -- check below -- otherwise a saved active theme that happens to be a
  -- custom one would fail the MyDSL.Theme.presets[loaded.active] check
  -- (not merged in yet) and silently fall back to the hardcoded
  -- default on every single reload. Added 2026-08-25 alongside
  -- theme new/edit/delete/preview.
  if type(loaded.customPresets) == "table" then
    MyDSL.Theme.customPresets = loaded.customPresets
    for name, preset in pairs(MyDSL.Theme.customPresets) do
      MyDSL.Theme.presets[name] = preset
      if not table.contains(MyDSL.Theme.presetOrder, name) then
        table.insert(MyDSL.Theme.presetOrder, name)
      end
    end
  end

  if type(loaded.active) == "string"
     and MyDSL.Theme.presets[loaded.active] then
    MyDSL.Theme.active = loaded.active
  end
  -- Per-window overrides -- added 2026-08-23 alongside the "theme override"
  -- alias below. Same file as `active` since both are profile-level,
  -- non-character-bound theme state.
  if type(loaded.overrides) == "table" then
    MyDSL.Theme.overrides = loaded.overrides
  end
end

function MyDSL.Theme.saveActive()
  local ok = pcall(table.save, THEME_FILE(), {
    active = MyDSL.Theme.active,
    overrides = MyDSL.Theme.overrides,
    customPresets = MyDSL.Theme.customPresets,
  })
  if not ok then
    debugc("[MyDSL] ThemeEngine: failed to save theme settings to " .. THEME_FILE())
  end
  return ok
end

MyDSL.Theme.loadActive()

-- list()
-- Returns the preset names in stable display order.
function MyDSL.Theme.list()
  return MyDSL.Theme.presetOrder
end

-- setTheme(name)
-- Switches the active preset, persists it, and raises "MyDSL.theme.changed"
-- so every live window can restyle itself immediately. Returns true/false.
function MyDSL.Theme.setTheme(name)
  if not MyDSL.Theme.presets[name] then
    return false
  end
  MyDSL.Theme.active = name
  MyDSL.Theme.saveActive()
  raiseEvent("MyDSL.theme.changed", name)
  return true
end


------------------------------------------------------------------------
-- SECTION 7: ACCESSOR — get(windowName, key)
------------------------------------------------------------------------
-- Precedence, highest to lowest:
--   1. Per-window override           (MyDSL.Theme.overrides[windowName])
--   2. Active preset's zone entry    (only if the preset defines zones
--                                      AND this window has a zone AND
--                                      the zone table has this key)
--   3. Active preset's flat value    (MyDSL.Theme.presets[active][key])
--   4. Bare fallback                 (MyDSL.Theme.defaults[key])

function MyDSL.Theme.get(windowName, key)
  local overrideTable = MyDSL.Theme.overrides[windowName]
  if overrideTable then
    local overrideValue = overrideTable[key]
    if overrideValue ~= nil then return overrideValue end
  end

  local preset = MyDSL.Theme.presets[MyDSL.Theme.active] or {}

  if preset.zones then
    local zoneName = MyDSL.Theme.windowZone[windowName]
    local zoneTable = zoneName and preset.zones[zoneName]
    if zoneTable and zoneTable[key] ~= nil then
      return zoneTable[key]
    end
  end

  if preset[key] ~= nil then return preset[key] end
  return MyDSL.Theme.defaults[key]
end


------------------------------------------------------------------------
-- SECTION 8: COLOR CONVERTERS
------------------------------------------------------------------------

function MyDSL.Theme.colorToCSS(rgba)
  if not rgba then return "rgba(0,0,0,1)" end
  local r = rgba.r or 0
  local g = rgba.g or 0
  local b = rgba.b or 0
  local a = rgba.a or 255
  return string.format("rgba(%d,%d,%d,%.2f)", r, g, b, a / 255)
end

-- colorToBracket(rgba) -- Geyser's OWN color format ("<r,g,b>"), used by
-- Geyser.Color.hex() wherever a plain foreground-color argument is
-- expected (e.g. Geyser.Label:echo()'s color param, and EMCO's
-- activeTabFGColor/inactiveTabFGColor). Not interchangeable with
-- colorToCSS() -- that one is real CSS (alpha-aware, for setStyleSheet()
-- properties), this one is Geyser's own bracket notation (no alpha,
-- for a plain fgColor-style argument).
function MyDSL.Theme.colorToBracket(rgba)
  if not rgba then return "<255,255,255>" end
  return string.format("<%d,%d,%d>", rgba.r or 255, rgba.g or 255, rgba.b or 255)
end


------------------------------------------------------------------------
-- SECTION 9: READY-MADE STYLESHEET STRINGS
------------------------------------------------------------------------
-- Added 2026-07-11 alongside named presets. Every window that builds its
-- own "panel" background Label (Live/Tick's existing pattern, extended
-- to every other window in Layer 3) can call these instead of hand-
-- rolling its own string.format(), so a theme switch actually reaches
-- every window's chrome from one place.

-- panelCSS(windowName)
-- Background + border + radius for a full-bleed panel Label. Bare
-- declarations only (no selector) -- this is what a Label's
-- setStyleSheet() needs, and it's what LiveView/AlterformView/TickView's
-- own background Labels use it for.
function MyDSL.Theme.panelCSS(windowName)
  local bg     = MyDSL.Theme.get(windowName, "bgColor")
  local border = MyDSL.Theme.get(windowName, "borderColor")
  local size   = MyDSL.Theme.get(windowName, "borderSize") or 1
  local radius = MyDSL.Theme.get(windowName, "radius") or 0
  return string.format(
    "background-color: %s; border: %dpx solid %s; border-radius: %dpx;",
    MyDSL.Theme.colorToCSS(bg), size, MyDSL.Theme.colorToCSS(border), radius
  )
end

-- titleBarCSS(windowName) -- MyDSL 1.0 visual pass v2, "One Bar, Renamed
-- and Colored" -- final locked spec, 2026-08-26, replacing an earlier
-- "Direction A+" attempt (flatten the native bar to a blank sliver, add
-- a SEPARATE themed Geyser.Label underneath for the real title). Live on
-- Steven's own machine that showed two stacked title-like elements at
-- once, not one: the flatten step's setTitle("") never actually blanked
-- Mudlet's native title text (untested edge case, turned out not to
-- work), so the full default native title AND the new Label both
-- rendered. His verdict, in his own words: "User window - MyDSL -
-- MyDSL_Location should be Location, but colored and maybe styled to
-- look pretty, small text/titlebar as possible" -- one bar, not two.
--
-- This function now carries the accent coloring the removed Label used
-- to (same formula, confirmed against the delivered mockup's rendered
-- values for all 5 presets: text = titleColor at full alpha, background
-- = titleBgColor at its own alpha -- the first real consumer of that
-- previously-dead preset key -- border-bottom = the window's own
-- borderColor) directly onto a QDockWidget::title{} sub-control
-- selector, NOT the bare declarations panelCSS() above returns -- must
-- be concatenated onto a UserWindow's setStyleSheet() call, never passed
-- to a plain Label. Renaming the bar to the real short name ("Combat",
-- "Location") is the caller's job via the normal, documented
-- winObj:setTitle(realText) -- this function only returns the coloring.
--
-- Renders while a QDockWidget is docked (confirmed on Steven's own
-- screenshots -- dark-tinted, not default OS grey); native OS chrome
-- can take over once floated/detached, a Qt docked-vs-floating
-- distinction (independently corroborated via Qt's own forum/docs,
-- 2026-08-26) rather than a strict per-OS rule -- worth a spot-check on
-- a floated window and on a real Windows/macOS machine before treating
-- the platform question as fully closed, per Claude Desktop's own
-- caveat, but no longer a purely-theoretical risk either.
function MyDSL.Theme.titleBarCSS(windowName)
  local titleColor   = MyDSL.Theme.get(windowName, "titleColor")
  local titleBgColor = MyDSL.Theme.get(windowName, "titleBgColor")
  local border       = MyDSL.Theme.get(windowName, "borderColor")
  local size         = MyDSL.Theme.get(windowName, "borderSize") or 1
  return string.format(
    "QDockWidget::title { background-color: %s; color: %s; border-bottom: %dpx solid %s; padding: 4px 10px; }",
    MyDSL.Theme.colorToCSS(titleBgColor), MyDSL.Theme.colorToCSS(titleColor),
    size, MyDSL.Theme.colorToCSS(border)
  )
end

-- styleConsole(consoleObj, windowName, fontSizeOverride)
-- Applies the active theme's background fill and font to a MiniConsole
-- (or any Geyser.Window subclass with setColor/setFont/setFontSize --
-- Geyser.UserWindow qualifies too, for windows like MyDSL_Affects that
-- cecho() straight into the window itself instead of a MiniConsole
-- child). A UserWindow's own setStyleSheet (applied by WindowRegistry's
-- applyTheme()) only themes its border/title area -- a MiniConsole paints
-- its own background independently, so this second call is what keeps
-- the interior fill from staying whatever color it last had.
--
-- fontSizeOverride: pass a per-window persisted user font-size override
-- (e.g. CombatView's CV.config.fontSize) so a theme switch changes color
-- and font family without clobbering a size the user explicitly set.
-- Every call is pcall-wrapped: some target objects may not implement
-- every method (e.g. plain UserWindow has no setFont), and that's fine --
-- silently skip what doesn't apply rather than erroring.
function MyDSL.Theme.styleConsole(consoleObj, windowName, fontSizeOverride)
  if not consoleObj then return end
  local bg = MyDSL.Theme.get(windowName, "bgColor")
  if bg then pcall(function() consoleObj:setColor(bg.r, bg.g, bg.b, bg.a) end) end
  local font = MyDSL.Theme.get(windowName, "font")
  if font then pcall(function() consoleObj:setFont(font) end) end
  local size = fontSizeOverride or MyDSL.Theme.get(windowName, "fontSize")
  if size then pcall(function() consoleObj:setFontSize(size) end) end
end


------------------------------------------------------------------------
-- SECTION 10: OVERRIDE MANAGEMENT
------------------------------------------------------------------------

function MyDSL.Theme.setOverride(windowName, key, value)
  if MyDSL.Theme.defaults[key] == nil then
    debugc("[MyDSL] ThemeEngine: setOverride() ignored unknown key '" .. tostring(key) .. "'")
    return false
  end
  MyDSL.Theme.overrides[windowName] = MyDSL.Theme.overrides[windowName] or {}
  MyDSL.Theme.overrides[windowName][key] = value
  MyDSL.Theme.saveActive()
  raiseEvent("MyDSL.theme.changed", MyDSL.Theme.active)
  return true
end

function MyDSL.Theme.clearOverride(windowName)
  MyDSL.Theme.overrides[windowName] = nil
  MyDSL.Theme.saveActive()
  raiseEvent("MyDSL.theme.changed", MyDSL.Theme.active)
end


------------------------------------------------------------------------
-- SECTION 10.5: CUSTOM PRESET MANAGEMENT
------------------------------------------------------------------------
-- newCustom/setCustomKey/deleteCustom/previewText -- added 2026-08-25
-- per Steven ("i wan to be able to customize the theme in the ui").
-- Deliberately in-Mudlet, command-driven (no color-picker widget exists
-- in Mudlet's own Lua API), matching this file's existing "theme
-- override" alias's r,g,b syntax rather than inventing a second one.

-- newCustom(name) -- clones the ACTIVE preset's full key set into a new
-- custom preset and switches to it immediately, so "theme edit" always
-- has a complete starting point rather than a half-empty table missing
-- keys get()'s fallback chain would otherwise have to cover silently.
-- Refuses to collide with any existing name, built-in or custom --
-- 'theme delete <name>' first to reuse one.
function MyDSL.Theme.newCustom(name)
  if not name or name == "" then return false, "name required" end
  if MyDSL.Theme.presets[name] then
    return false, "'" .. name .. "' already exists -- pick a different name or 'theme delete " .. name .. "' first"
  end
  local base = MyDSL.Theme.presets[MyDSL.Theme.active] or MyDSL.Theme.defaults
  local clone = table.deepcopy and table.deepcopy(base)
  if not clone then
    -- Manual fallback -- every value here is either a plain scalar or a
    -- flat {r,g,b,a} table, so one level of copying is sufficient; this
    -- only exists in case table.deepcopy() isn't present on some Mudlet
    -- version (confirmed real and used unconditionally by EMCOChat's
    -- own vendored demontools.lua, but defended here anyway rather than
    -- assumed, same caution as DSL_Generic_Mapper.xml's own usage of it).
    clone = {}
    for k, v in pairs(base) do
      if type(v) == "table" then
        local t = {}
        for k2, v2 in pairs(v) do t[k2] = v2 end
        clone[k] = t
      else
        clone[k] = v
      end
    end
  end
  MyDSL.Theme.customPresets[name] = clone
  MyDSL.Theme.presets[name] = clone
  table.insert(MyDSL.Theme.presetOrder, name)
  MyDSL.Theme.active = name
  MyDSL.Theme.saveActive()
  raiseEvent("MyDSL.theme.changed", name)
  return true
end

-- setCustomKey(key, value) -- edits ONE key on the CURRENTLY ACTIVE
-- preset, only if it's a player-created custom one. Built-in presets
-- are read-only by design (Lua source, not disk-loaded) -- editing one
-- in memory would be silently lost on the next reload (nothing
-- persists it), a confusing outcome if allowed; 'theme new <name>'
-- first makes a real, editable, persisted copy instead.
function MyDSL.Theme.setCustomKey(key, value)
  local name = MyDSL.Theme.active
  if not MyDSL.Theme.customPresets[name] then
    return false, "'" .. name .. "' is a built-in theme, not a custom one -- 'theme new <name>' first"
  end
  if MyDSL.Theme.defaults[key] == nil then
    return false, "unknown theme key '" .. tostring(key) .. "'"
  end
  -- customPresets[name] and presets[name] are the SAME table
  -- (newCustom() assigns both to the identical clone), so this one
  -- write is already visible through presets[name] too.
  MyDSL.Theme.customPresets[name][key] = value
  MyDSL.Theme.saveActive()
  raiseEvent("MyDSL.theme.changed", name)
  return true
end

-- deleteCustom(name) -- refuses to delete a built-in (checked via
-- customPresets, not presets, so this can never be tricked by a name
-- collision -- built-ins are never in customPresets). Falls back to the
-- hardcoded default if the deleted theme was the active one.
function MyDSL.Theme.deleteCustom(name)
  if not MyDSL.Theme.customPresets[name] then
    return false, "'" .. tostring(name) .. "' isn't a custom theme (built-ins can't be deleted)"
  end
  MyDSL.Theme.customPresets[name] = nil
  MyDSL.Theme.presets[name] = nil
  for i, n in ipairs(MyDSL.Theme.presetOrder) do
    if n == name then table.remove(MyDSL.Theme.presetOrder, i); break end
  end
  if MyDSL.Theme.active == name then
    MyDSL.Theme.active = "refined_convergence"
  end
  MyDSL.Theme.saveActive()
  raiseEvent("MyDSL.theme.changed", MyDSL.Theme.active)
  return true
end

-- previewText(name) -- real in-Mudlet visual feedback for a theme's
-- actual colors, using Mudlet's own decho "<r,g,b>" tag to render real
-- swatches rather than just printing numbers -- this is the actual
-- "customize in the UI" loop: pick a color, preview it, see it for
-- real, adjust. Defaults to the active theme.
function MyDSL.Theme.previewText(name)
  name = name or MyDSL.Theme.active
  local preset = MyDSL.Theme.presets[name]
  if not preset then return nil, "unknown theme '" .. tostring(name) .. "'" end
  local order = {
    "titleColor", "textColor", "borderColor", "highlightColor",
    "dimColor", "warnColor", "goodColor", "bgColor",
  }
  local lines = {}
  for _, key in ipairs(order) do
    local v = preset[key] or MyDSL.Theme.defaults[key]
    if type(v) == "table" and v.r then
      lines[#lines + 1] = string.format(
        "<%d,%d,%d>\226\150\136\226\150\136\226\150\136<r> %-14s (%d,%d,%d)",
        v.r, v.g, v.b, key, v.r, v.g, v.b
      )
    end
  end
  return table.concat(lines, "\n")
end


------------------------------------------------------------------------
-- SECTION 11: "theme" ALIAS — list / set / show / override / customize
------------------------------------------------------------------------
-- theme            -> shows the active theme name
-- theme list        -> lists all available preset names (built-in + custom)
-- theme set <name>  -> switches the active preset
-- Bare "theme" verb confirmed to have zero collision with real DSL
-- vocabulary (grepped DSL_Helpfiles/, 2026-07-11) -- safe per this
-- session's command-surface convention (see docs/TODO.md / CHANGELOG.md).
--
-- theme new <name>          -> clone the active preset into a new,
--   editable custom preset and switch to it (see SECTION 10.5)
-- theme edit <key> <value>  -> change one key on the active preset, only
--   if it's a custom one (same <value> syntax as 'theme override' below)
-- theme delete <name>       -> delete a custom preset (built-ins can't
--   be deleted)
-- theme preview [name]      -> real color swatches for a theme's keys
--   (defaults to the active theme)
--
-- theme override <window> <key> <value>  -> per-window escape hatch, wins
--   over the active preset for that one window (get()'s precedence,
--   Section 7). Wired up 2026-08-23 -- MyDSL.Theme.setOverride()/
--   clearOverride() and get()'s override-reading branch existed since
--   2026-07-11 but nothing ever called setOverride(), so this was a
--   fully dead mechanism until now. <value> is parsed by the key's own
--   type in MyDSL.Theme.defaults: numeric keys (fontSize/titleFontSize/
--   borderSize/radius) take a plain number; font/titleFont take a font
--   name; color keys (bgColor/textColor/borderColor/titleColor/
--   titleBgColor/highlightColor/dimColor/warnColor) take "r,g,b" or
--   "r,g,b,a".
-- theme override <window> clear          -> remove all overrides for
--   that window
-- theme override <window>                -> show current overrides for
--   that window

local function parseOverrideValue(key, raw)
  local defaultVal = MyDSL.Theme.defaults[key]
  if type(defaultVal) == "number" then
    local n = tonumber(raw)
    if not n then return nil, "expected a number for '" .. key .. "'" end
    return n
  elseif type(defaultVal) == "table" then
    local r, g, b, a = raw:match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*,?%s*(%d*)%s*$")
    if not r then return nil, "expected \"r,g,b\" or \"r,g,b,a\" for '" .. key .. "'" end
    return { r = tonumber(r), g = tonumber(g), b = tonumber(b), a = tonumber(a) or 255 }
  else
    return raw
  end
end

if not MyDSL.Theme._aliasesInstalled then
  tempAlias("^theme list$", function()
    cecho("\n<gold>[MyDSL] Available themes:\n")
    for _, name in ipairs(MyDSL.Theme.list()) do
      local marker = (name == MyDSL.Theme.active) and " <-- active" or ""
      local tag = MyDSL.Theme.customPresets[name] and " (custom)" or ""
      cecho("<white>  " .. name .. tag .. marker .. "\n")
    end
  end)

  tempAlias("^theme set (.+)$", function()
    local name = matches[2]
    if MyDSL.Theme.setTheme(name) then
      cecho("\n<green>[MyDSL] Theme set to '" .. name .. "'.\n")
    else
      cecho("\n<firebrick>[MyDSL] Unknown theme '" .. tostring(name) .. "'. Try 'theme list'.\n")
    end
  end)

  tempAlias("^theme new (.+)$", function()
    local name = matches[2]
    local ok, err = MyDSL.Theme.newCustom(name)
    if ok then
      cecho("\n<green>[MyDSL] Created and switched to custom theme '" .. name
        .. "'. Try 'theme edit <key> <r,g,b>' or 'theme preview'.\n")
    else
      cecho("\n<firebrick>[MyDSL] " .. err .. "\n")
    end
  end)

  tempAlias("^theme edit (\\S+) (.+)$", function()
    local key, raw = matches[2], matches[3]
    if MyDSL.Theme.defaults[key] == nil then
      cecho("\n<firebrick>[MyDSL] Unknown theme key '" .. key .. "'.\n")
      return
    end
    local value, err = parseOverrideValue(key, raw)
    if not value then
      cecho("\n<firebrick>[MyDSL] " .. err .. "\n")
      return
    end
    local ok, err2 = MyDSL.Theme.setCustomKey(key, value)
    if ok then
      cecho("\n<green>[MyDSL] '" .. MyDSL.Theme.active .. "' " .. key .. " updated. 'theme preview' to see it.\n")
    else
      cecho("\n<firebrick>[MyDSL] " .. err2 .. "\n")
    end
  end)

  tempAlias("^theme delete (.+)$", function()
    local name = matches[2]
    local ok, err = MyDSL.Theme.deleteCustom(name)
    if ok then
      cecho("\n<green>[MyDSL] Deleted custom theme '" .. name .. "'.\n")
    else
      cecho("\n<firebrick>[MyDSL] " .. err .. "\n")
    end
  end)

  tempAlias("^theme preview$", function()
    local text = MyDSL.Theme.previewText()
    cecho("\n<gold>[MyDSL] Preview of '" .. MyDSL.Theme.active .. "':\n")
    decho(text .. "\n")
  end)

  tempAlias("^theme preview (.+)$", function()
    local name = matches[2]
    local text, err = MyDSL.Theme.previewText(name)
    if not text then
      cecho("\n<firebrick>[MyDSL] " .. err .. "\n")
      return
    end
    cecho("\n<gold>[MyDSL] Preview of '" .. name .. "':\n")
    decho(text .. "\n")
  end)

  tempAlias("^theme override (\\S+) clear$", function()
    local windowName = matches[2]
    MyDSL.Theme.clearOverride(windowName)
    cecho("\n<green>[MyDSL] Cleared all theme overrides for '" .. windowName .. "'.\n")
  end)

  tempAlias("^theme override (\\S+) (\\S+) (.+)$", function()
    local windowName, key, raw = matches[2], matches[3], matches[4]
    if MyDSL.Theme.defaults[key] == nil then
      cecho("\n<firebrick>[MyDSL] Unknown theme key '" .. key .. "'.\n")
      return
    end
    local value, err = parseOverrideValue(key, raw)
    if not value then
      cecho("\n<firebrick>[MyDSL] " .. err .. "\n")
      return
    end
    MyDSL.Theme.setOverride(windowName, key, value)
    -- Soft, guarded typo check -- added 2026-08-23 (Claude.ai review
    -- pass): a typo'd window name used to silently create an override
    -- nothing would ever read, no error at all. Deliberately NOT a hard
    -- MyDSL.Windows dependency (this file has none by design, and
    -- WindowRegistry might not even be loaded yet) -- just a warning
    -- when it's available and the name isn't recognized; the override
    -- still gets set either way, since a window registered later could
    -- still legitimately use it.
    if MyDSL.Windows and MyDSL.Windows.registry and not MyDSL.Windows.registry[windowName] then
      cecho("\n<gold>[MyDSL] Warning: '" .. windowName .. "' isn't a known window name -- check for a typo.\n")
    end
    cecho("\n<green>[MyDSL] '" .. windowName .. "' " .. key .. " overridden.\n")
  end)

  tempAlias("^theme override (\\S+)$", function()
    local windowName = matches[2]
    local overrideTable = MyDSL.Theme.overrides[windowName]
    if not overrideTable or not next(overrideTable) then
      cecho("\n<gold>[MyDSL] No overrides set for '" .. windowName .. "'.\n")
      return
    end
    cecho("\n<gold>[MyDSL] Overrides for '" .. windowName .. "':\n")
    for key, value in pairs(overrideTable) do
      local shown = (type(value) == "table")
        and string.format("%d,%d,%d,%d", value.r or 0, value.g or 0, value.b or 0, value.a or 255)
        or tostring(value)
      cecho("<white>  " .. key .. " = " .. shown .. "\n")
    end
  end)

  tempAlias("^theme$", function()
    cecho("\n<gold>[MyDSL] Active theme: <white>" .. MyDSL.Theme.active
      .. "<gold> (try 'theme list', 'theme set <name>', 'theme new <name>', "
      .. "'theme edit <key> <r,g,b>', 'theme preview', or 'theme override <window> <key> <value>')\n")
  end)

  MyDSL.Theme._aliasesInstalled = true
end


------------------------------------------------------------------------
-- LOAD CONFIRMATION
------------------------------------------------------------------------
debugc("[MyDSL] ThemeEngine loaded. Active theme: " .. MyDSL.Theme.active)
