-- =============================================================================
-- MyDSL_RouteHelper.lua  --  Layer 3: Text routing to windows
-- =============================================================================
-- Provides MyDSL.Route.to(name, line) and shorthand helpers.
-- Called by triggers to route captured text lines to the correct window.
-- Creates a MiniConsole inside the UserWindow on first use if not present.
--
-- Route name map (DSL1 names → DSL2 window names):
--   "History"       → MyDSL_History
--   "Combat"        → MyDSL_Combat
--   "Scan"          → MyDSL_Scan
--   "Group"         → MyDSL_Group
--   "PlayersNearYou"→ MyDSL_PlayersNear
--   "Target"        → MyDSL_Target
--   "RightHere"     → MyDSL_RightHere
-- =============================================================================

MyDSL = MyDSL or {}
MyDSL.Route = MyDSL.Route or {}

-- Map DSL1 route destination names to DSL2 window registry names.
-- This lets old trigger code like MyDSL.Route.to("History") still work.
local routeMap = {
  History        = "MyDSL_History",
  Combat         = "MyDSL_Combat",
  Scan           = "MyDSL_Scan",
  Group          = "MyDSL_Group",
  PlayersNearYou = "MyDSL_PlayersNear",
  PlayersNear    = "MyDSL_PlayersNear",
  Target         = "MyDSL_Target",
  RightHere      = "MyDSL_RightHere",
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

  -- Create a MiniConsole filling the entire UserWindow.
  -- MiniConsole is Mudlet's scrollable text area — the right tool for routed text.
  local con = Geyser.MiniConsole:new({
    name   = windowName .. "_con",
    x = 0, y = 0,
    width  = "100%",
    height = "100%",
    fontSize = 9,
    color = "black",
    scrollBar = true,
  }, entry.obj)

  if con then
    entry.console = con
    con:setFontSize(9)
    con:setColor(0, 0, 0)
  end
  return con
end

-- MyDSL.Route.to(name, line)
-- Routes a text line to the named window.
-- name: DSL1 route name (e.g. "History") or DSL2 window name (e.g. "MyDSL_History")
-- line: optional text to write. If nil, uses getCurrentLine() (the current trigger line).

function MyDSL.Route.to(name, line)
  local winName = routeMap[name] or name
  local con = getOrCreateConsole(winName)
  if not con then return end

  local text = line or (getCurrentLine and getCurrentLine()) or ""
  if text ~= "" then
    con:decho(text .. "\n")
  end
end

-- Shorthand helpers matching DSL1 API

function MyDSL.Route.history(line)
  MyDSL.Route.to("History", line)
end

function MyDSL.Route.combat(line)
  MyDSL.Route.to("Combat", line)
end

function MyDSL.Route.scan(line)
  MyDSL.Route.to("Scan", line)
end

function MyDSL.Route.group(line)
  MyDSL.Route.to("Group", line)
end

function MyDSL.Route.players(line)
  MyDSL.Route.to("PlayersNearYou", line)
end

function MyDSL.Route.righthere(line)
  MyDSL.Route.to("RightHere", line)
end

debugc("[MyDSL] RouteHelper loaded.")
