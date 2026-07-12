-- =============================================================================
-- MyDSL_RouteHelper.lua  --  Layer 3: Text routing to windows
-- =============================================================================
-- Provides MyDSL.Route.to(windowName, line) and shorthand helpers.
-- Called by triggers to route captured text lines to the correct window.
-- Creates a MiniConsole inside the UserWindow on first use if not present.
--
-- The routeMap (DSL1→DSL2 name compat) was removed per the June 2026 addendum:
-- all DSL2 triggers are written fresh, so backward-compat aliases add no value.
-- Use shorthand helpers (Route.history, Route.combat, etc.) or direct window
-- names ("MyDSL_History") with Route.to().
-- =============================================================================

MyDSL = MyDSL or {}
MyDSL.Route = MyDSL.Route or {}

-- Per-window font size override -- default 9 for anything not listed here.
-- History dropped to 8 2026-07-05, then to 7 2026-07-07 per Steven ("history
-- text 7"). Persistence moved 2026-07-11 to MyDSL.Windows' shared,
-- PROFILE-level (not character-bound) font-size store
-- (MyDSL_WindowRegistry.lua) -- per Steven ("the fonts should be saving
-- like theme or window manager whatever tracks that... per profile not
-- user, remember for the layout"). This used to be its own bespoke
-- character-bound file + "re-load once character is known" handler,
-- structurally identical to the confirmed-working MyDSL_ChatWrapper.lua
-- pattern -- but Steven reported it still not surviving a reload (same
-- report as MyDSL_TargetView.lua's font, fixed the same way), so both
-- moved to the shared mechanism together, removing the character-name
-- dependency (and that whole class of timing bug) entirely.
local FONT_SIZE_OVERRIDES = {
  MyDSL_History = MyDSL.Windows.getFontSize("MyDSL_History", 7),
}

-- Display titles for windows this file creates via WindowRegistry --
-- added 2026-07-11, per Steven ("fix all window titles/names"). These
-- windows previously never got a title set anywhere, so they showed
-- Mudlet's raw default ("User window - DSL2 - MyDSL_History") instead of
-- matching Live/Tick/Portrait/Location's "-= Name =-" convention.
local WINDOW_TITLES = {
  MyDSL_History     = "-= History =-",
  MyDSL_PlayersNear = "-= Players Near =-",
}

-- getOrCreateConsole(windowName)
-- Returns the MiniConsole inside a window, creating it if needed.
-- A Geyser.UserWindow is just a frame — text output needs a MiniConsole child.
-- We store the MiniConsole reference in entry.console so we only create it once.
local function getOrCreateConsole(windowName)
  if not (MyDSL and MyDSL.Windows and MyDSL.Windows.registry) then return nil end
  local entry = MyDSL.Windows.registry[windowName]
  if not entry then return nil end

  -- Ensure the window object exists first.
  if not entry.obj then
    MyDSL.Windows.ensure(windowName)
  end
  if not entry.obj then return nil end

  -- Return existing console if already created.
  if entry.console then return entry.console end

  if WINDOW_TITLES[windowName] and entry.obj.setTitle then
    pcall(function() entry.obj:setTitle(WINDOW_TITLES[windowName]) end)
  end

  local fontSize = FONT_SIZE_OVERRIDES[windowName] or 9

  -- Create a MiniConsole filling the entire UserWindow. Left edge inset
  -- by a fixed 8px (roughly one character at these windows' font sizes)
  -- 2026-07-12, per Steven (corrected same day: "did i say right hand
  -- padding, i meant left to take the first letter off the edge of the
  -- window") -- x=8 combined with width="-8" (Geyser's relative-width
  -- sizing, same trick Adjustable.Container's own Inside container uses
  -- for its padding) starts the console 8px in from the left and still
  -- ends flush at the parent's right edge -- left-only, right/top/bottom
  -- untouched. Applies to every window routed through this shared
  -- console (Combat/History/Scan/Group/PlayersNear/RightHere);
  -- Focus/Affects/Live and the other Label-based windows use their own
  -- bespoke layouts, not this function, and aren't covered by this
  -- change.
  -- scrollBar=false 2026-07-11, per Steven ("remove scroll bars from
  -- history and playersn near you (consistent)") -- matches Scan/RightHere/
  -- Target/Group, which never had one.
  local con = Geyser.MiniConsole:new({
    name   = windowName .. "_con",
    x = 8, y = 0,
    width  = "-8",
    height = "100%",
    fontSize = fontSize,
    color = "black",
    scrollBar = false,
  }, entry.obj)

  if con then
    entry.console = con
    -- Theme-driven background/font, added 2026-07-11 (was hardcoded
    -- black) -- fontSize stays the per-window persisted override
    -- (History's user-configurable size, "mydsl history font <n>") so a
    -- theme switch changes color/font family without resetting it.
    if MyDSL.Theme and MyDSL.Theme.styleConsole then
      MyDSL.Theme.styleConsole(con, windowName, fontSize)
    else
      con:setFontSize(fontSize)
      con:setColor(0, 0, 0)
    end
    -- History-only, added 2026-07-12 per Steven ("history needs adaptive
    -- word wrap, so it text wraps with the size of the window"). Real
    -- Mudlet API, confirmed via its bundled GeyserMiniConsole.lua:
    -- enableAutoWrap() sets self.autoWrap=true and computes wrapAt from
    -- the console's current pixel width / font width; MiniConsole's own
    -- reposition() override (also confirmed in that same source) already
    -- recalls resetAutoWrap() automatically whenever the window resizes,
    -- so a resize keeps it correct with no extra wiring needed here.
    -- History-only, not applied to the other routed windows (Combat/
    -- Scan/Group/PlayersNear/RightHere) -- Steven's ask was specific to
    -- History, and those other windows' short structured lines don't
    -- have the same wrapping problem.
    if windowName == "MyDSL_History" then
      pcall(function() con:enableAutoWrap() end)
    end
  end
  return con
end

-- Re-theme every already-created routed console when the active theme
-- switches. Added 2026-07-11 alongside named ThemeEngine presets.
if MyDSL.Route._themeHandler then
  pcall(killAnonymousEventHandler, MyDSL.Route._themeHandler)
  MyDSL.Route._themeHandler = nil
end
MyDSL.Route._themeHandler = registerAnonymousEventHandler(
  "MyDSL.theme.changed",
  function()
    if not (MyDSL.Windows and MyDSL.Windows.registry and MyDSL.Theme) then return end
    for windowName, entry in pairs(MyDSL.Windows.registry) do
      if entry.console then
        local fontSize = FONT_SIZE_OVERRIDES[windowName] or 9
        MyDSL.Theme.styleConsole(entry.console, windowName, fontSize)
      end
    end
  end
)

-- Turns "MyDSL_PlayersNear" into "playersnear" for MyDSL.logWindow()'s
-- category argument -- keeps every routed window's plain-text log under
-- MyDSL/logs/<category>/<CharName>/ without a second naming scheme to track.
local function logCategory(windowName)
  return tostring(windowName or "unknown"):gsub("^MyDSL_", ""):lower()
end

-- MyDSL.Route.to(windowName, line)
-- Routes text to the named window (direct DSL2 name, e.g. "MyDSL_History").
-- Two modes:
--   line provided → decho mode: caller controls color/format via decho tags.
--   line nil      → appendBuffer mode: copies the current trigger line with all
--                   original ANSI game colors intact. This is the observer pattern —
--                   "move text, don't rewrite it."
-- Also mirrors into MyDSL/logs/<category>/ (2026-07-05 -- same reasoning as
-- CombatView/GroupView/ScanView/TargetView: Mudlet can't log a MiniConsole's
-- content at all, see MyDSL_MudletAPIReference.md).
function MyDSL.Route.to(windowName, line)
  local con = getOrCreateConsole(windowName)
  if not con then return end

  local text = line
  if line then
    con:decho(line .. "\n")
  else
    selectCurrentLine()
    text = getCurrentLine()
    copy()
    con:appendBuffer()
  end
  if MyDSL.logWindow then MyDSL.logWindow(logCategory(windowName), text) end
end

-- MyDSL.Route.clear(windowName)
-- Clears all text from a window's MiniConsole.
-- Call before writing fresh scan/group/players-near content.
function MyDSL.Route.clear(windowName)
  local entry = MyDSL.Windows and MyDSL.Windows.registry
                and MyDSL.Windows.registry[windowName]
  if entry and entry.console then
    entry.console:clear()
  end
end

-- MyDSL.Route.getConsole(windowName)
-- Returns the raw MiniConsole object for direct echo/cecho/getLineCount access.
function MyDSL.Route.getConsole(windowName)
  return getOrCreateConsole(windowName)
end

-- Shorthand helpers — use these in triggers instead of hardcoding window names.
-- Each one is a thin wrapper around Route.to() with the direct DSL2 window name.

function MyDSL.Route.history(line)   MyDSL.Route.to("MyDSL_History",     line) end
function MyDSL.Route.combat(line)    MyDSL.Route.to("MyDSL_Combat",      line) end
function MyDSL.Route.scan(line)      MyDSL.Route.to("MyDSL_Scan",        line) end
function MyDSL.Route.group(line)     MyDSL.Route.to("MyDSL_Group",       line) end
function MyDSL.Route.players(line)   MyDSL.Route.to("MyDSL_PlayersNear", line) end
function MyDSL.Route.righthere(line) MyDSL.Route.to("MyDSL_RightHere",   line) end

-- MyDSL.Route.setHistoryFont(size) + "mydsl history font <n>" -- added
-- 2026-07-06. Every other routed/module window has its own "mydsl <name>
-- font <n>" alias (chat/live/tickview all confirmed); History only had a
-- fixed FONT_SIZE_OVERRIDES entry with no way to change it in-game.
-- Confirmed real gap: Steven typed "mydsl history font 9" twice in logged
-- sessions and got "Huh?" both times.
function MyDSL.Route.setHistoryFont(size)
  size = tonumber(size)
  if not size then echo("usage: mydsl history font <size>\n"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  FONT_SIZE_OVERRIDES.MyDSL_History = size
  local entry = MyDSL.Windows and MyDSL.Windows.registry
                and MyDSL.Windows.registry.MyDSL_History
  if entry and entry.console then
    entry.console:setFontSize(size)
  end
  -- Persist to the shared, profile-level store (2026-07-11) instead of
  -- History's own now-removed character-bound font file.
  MyDSL.Windows.setFontSize("MyDSL_History", size)
  echo("MyDSL_History font=" .. tostring(size) .. "\n")
end

MyDSL._aliases = MyDSL._aliases or {}
if MyDSL._aliases.historyFont then pcall(killAlias, MyDSL._aliases.historyFont) end
MyDSL._aliases.historyFont = tempAlias(
  "^mydsl history font (\\d+)$",
  [[MyDSL.Route.setHistoryFont(matches[2])]]
)

-- MyDSL.Route.historyStatus() + "mydsl history status" -- added
-- 2026-07-11, per Steven ("are the settings loading at creating from
-- save files or they saving and never reading/updating?"). Same 3-way
-- diagnostic as "focus status"'s font section: disk (re-read fresh from
-- MyDSL_windowfonts.lua, not memory), memory (FONT_SIZE_OVERRIDES.
-- MyDSL_History -- what this module currently believes), and live
-- (Geyser.MiniConsole:getFontSize(), Mudlet's own real getter for what
-- the widget is ACTUALLY rendering right now). Pinpoints exactly which
-- stage is wrong instead of guessing.
function MyDSL.Route.historyStatus()
  local diskVal = "?"
  if MyDSL.Windows and MyDSL.Windows.loadFontSizes and MyDSL.Windows.fontSizes then
    local before = MyDSL.Windows.fontSizes.MyDSL_History
    MyDSL.Windows.loadFontSizes()
    diskVal = tostring(MyDSL.Windows.fontSizes.MyDSL_History)
    if before ~= nil then MyDSL.Windows.fontSizes.MyDSL_History = before end
  end
  local liveVal = "?"
  local entry = MyDSL.Windows and MyDSL.Windows.registry
                and MyDSL.Windows.registry.MyDSL_History
  if entry and entry.console and entry.console.getFontSize then
    local ok, size = pcall(function() return entry.console:getFontSize() end)
    if ok then liveVal = tostring(size) end
  end
  echo("[MyDSL.Route] history font: disk=" .. diskVal ..
       "; memory(FONT_SIZE_OVERRIDES)=" .. tostring(FONT_SIZE_OVERRIDES.MyDSL_History) ..
       "; live(widget getFontSize)=" .. liveVal .. "\n")
end

MyDSL._aliases.historyStatus = tempAlias(
  "^mydsl history status$",
  [[MyDSL.Route.historyStatus()]]
)

debugc("[MyDSL] RouteHelper loaded.")
