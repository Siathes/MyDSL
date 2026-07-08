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
-- text 7"). Now persisted character-bound (same pattern as
-- MyDSL_CombatView.lua/MyDSL_TargetView.lua's configFile()), closing the
-- "should eventually live in a persisted config" gap noted here before.
local FONT_SIZE_OVERRIDES = {
  MyDSL_History = 7,
}

local function historyCharName()
  if gmcp and gmcp.login_data and gmcp.login_data.name and gmcp.login_data.name ~= "" then
    return tostring(gmcp.login_data.name)
  end
  if MyCore and MyCore.getChar then
    local ok, name = pcall(MyCore.getChar)
    if ok and name and name ~= "" then return tostring(name) end
  end
  return "Unknown"
end

local function historySafeFileName(s)
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

local function historyFontConfigFile()
  return getMudletHomeDir() .. "/MyDSL/history_font_" .. historySafeFileName(historyCharName()) .. ".lua"
end

local function loadHistoryFontConfig()
  local ok, data = pcall(table.load, historyFontConfigFile())
  if ok and type(data) == "table" and type(data.fontSize) == "number" then
    FONT_SIZE_OVERRIDES.MyDSL_History = data.fontSize
  end
end

local function saveHistoryFontConfig()
  pcall(table.save, historyFontConfigFile(), { fontSize = FONT_SIZE_OVERRIDES.MyDSL_History })
end

loadHistoryFontConfig()

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
  saveHistoryFontConfig()
  echo("MyDSL_History font=" .. tostring(size) .. "\n")
end

MyDSL._aliases = MyDSL._aliases or {}
if MyDSL._aliases.historyFont then pcall(killAlias, MyDSL._aliases.historyFont) end
MyDSL._aliases.historyFont = tempAlias(
  "^mydsl history font (\\d+)$",
  [[MyDSL.Route.setHistoryFont(matches[2])]]
)

-- Re-load once the real character is known -- fixed 2026-07-07.
-- loadHistoryFontConfig() above runs at script-boot time, which on a
-- genuinely fresh Mudlet start happens before login, so it loads
-- "Unknown"'s font size (or the bare default) and would otherwise never
-- pick up this character's real saved font. MyDSL_DataLayer.lua's
-- gmcp.login_data handler raises "MyDSL.character.identified" once the
-- real name is known.
MyDSL._handlers = MyDSL._handlers or {}
if MyDSL._handlers.historyCharacterIdentified then
  pcall(killAnonymousEventHandler, MyDSL._handlers.historyCharacterIdentified)
end
MyDSL._handlers.historyCharacterIdentified = registerAnonymousEventHandler(
  "MyDSL.character.identified",
  function()
    loadHistoryFontConfig()
    local entry = MyDSL.Windows and MyDSL.Windows.registry
                  and MyDSL.Windows.registry.MyDSL_History
    if entry and entry.console then
      entry.console:setFontSize(FONT_SIZE_OVERRIDES.MyDSL_History)
    end
  end
)

debugc("[MyDSL] RouteHelper loaded.")
