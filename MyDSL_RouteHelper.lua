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
-- History dropped to 8 2026-07-05 per Steven (still cramped at 9). This
-- should eventually live in the same in-game-adjustable/persisted config as
-- the other window font sizes -- tracked in TODO.md, not done yet.
local FONT_SIZE_OVERRIDES = {
  MyDSL_History = 8,
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

  local fontSize = FONT_SIZE_OVERRIDES[windowName] or 9

  -- Create a MiniConsole filling the entire UserWindow.
  -- MiniConsole is Mudlet's scrollable text area — the right tool for routed text.
  local con = Geyser.MiniConsole:new({
    name   = windowName .. "_con",
    x = 0, y = 0,
    width  = "100%",
    height = "100%",
    fontSize = fontSize,
    color = "black",
    scrollBar = true,
  }, entry.obj)

  if con then
    entry.console = con
    con:setFontSize(fontSize)
    con:setColor(0, 0, 0)
  end
  return con
end

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
function MyDSL.Route.bloodbath(line) MyDSL.Route.to("MyDSL_Bloodbath",   line) end

debugc("[MyDSL] RouteHelper loaded.")
