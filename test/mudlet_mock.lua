-- Minimal Mudlet global-API mock. Goal: let real MyDSL_*.lua files dofile()
-- cleanly outside Mudlet, then let us call their real parse functions
-- directly with real corpus-derived captures. Not a full emulator --
-- windows/GMCP are stubs, only enough to avoid load-time errors.

_G.matches = {}
_G.line = ""
_G.multimatches = {}

local function noop() return true end
local function idgen() local n = 0; return function() n = n + 1; return n end end
local nextId = idgen()

_G.__triggers = {}   -- id -> {pattern=, func=}
_G.__aliases = {}

function _G.tempRegexTrigger(pattern, codeOrFunc, priority)
  local id = nextId()
  local fn = codeOrFunc
  if type(codeOrFunc) == "string" then
    fn = function() local f = loadstring and loadstring(codeOrFunc) or load(codeOrFunc); if f then f() end end
  end
  _G.__triggers[id] = { pattern = pattern, func = fn }
  return id
end

function _G.tempTrigger(pattern, codeOrFunc, priority)
  return _G.tempRegexTrigger(pattern, codeOrFunc, priority)
end

function _G.permRegexTrigger(name, parent, patterns, codeOrFunc)
  return nextId()
end

function _G.tempAlias(pattern, codeOrFunc)
  local id = nextId()
  local fn = codeOrFunc
  if type(codeOrFunc) == "string" then
    fn = function() local f = loadstring and loadstring(codeOrFunc) or load(codeOrFunc); if f then f() end end
  end
  _G.__aliases[id] = { pattern = pattern, func = fn }
  return id
end

function _G.killTrigger(id) _G.__triggers[id] = nil; return true end
function _G.killAlias(id) _G.__aliases[id] = nil; return true end
function _G.killAnonymousEventHandler(id) return true end
function _G.registerAnonymousEventHandler(event, funcname) return nextId() end
_G.__sentCommands = {}
function _G.send(cmd, ...) _G.__sentCommands[#_G.__sentCommands+1] = cmd end

_G.__raisedEvents = {}
function _G.raiseEvent(name, ...)
  _G.__raisedEvents[#_G.__raisedEvents+1] = { name = name, ... }
  return true
end
function _G.exists(name, kind) return 0 end
function _G.disableAlias(id) return true end
function _G.disableTrigger(id) return true end
function _G.enableTrigger(id) return true end
function _G.tempTimer(delay, codeOrFunc) return nextId() end
function _G.killTimer(id) return true end

-- Echo/console family -- print to stdout so we can see activity if needed,
-- but keep quiet by default (comment the print back in for debugging).
function _G.echo(...) end
function _G.cecho(...) end
function _G.decho(...) end
function _G.hecho(...) end
function _G.dcecho(...) end
function _G.debugc(...) end
function _G.display(...) end
function _G.selectString(...) return -1 end
function _G.replace(...) end
function _G.deleteLine() end
function _G.moveCursor(...) return true end
function _G.selectCurrentLine() end
function _G.copy() end
function _G.appendBuffer() end
function _G.getCurrentLine() return _G.line end
function _G.getLineCount() return 0 end
function _G.getLineNumber() return 0 end
function _G.setFgColor(...) end
function _G.setBgColor(...) end
function _G.getFgColor() return 255, 255, 255 end
function _G.getBgColor() return 0, 0, 0 end
function _G.resetFormat() end
function _G.cinsertText(...) end
function _G.insertText(...) end
function _G.setFontSize(...) end
function _G.setMiniConsoleFontSize(...) end
function _G.getMudletHomeDir() return "/tmp/claude_mudlet_home" end
function _G.loadRawFile(...) end
function _G.saveMap(...) end
function _G.getMainWindowSize() return 1920, 1080 end
function _G.clearWindow(...) end
function _G.dechoLink(...) end
function _G.cechoLink(...) end
function _G.echoLink(...) end
function _G.setLabelClickCallback(...) end
function _G.createLabel(...) end
function _G.deleteLabel(...) end
function _G.resetProfile() end
function _G.raiseWindow(...) end
function _G.lowerWindow(...) end
function _G.moveWindow(...) end
function _G.setWindowWrap(...) end
function _G.enableTimer(...) end
function _G.disableTimer(...) end
function _G.playSoundFile(...) end
function _G.stopSounds(...) end

-- Mudlet global string helpers used by EMCOChat and others.
function _G.trim(s) return (tostring(s or "")):match("^%s*(.-)%s*$") end
function _G.lower(s) return tostring(s or ""):lower() end
function _G.upper(s) return tostring(s or ""):upper() end
string.title = string.title or function(s)
  s = tostring(s or "")
  return (s:gsub("(%a)([%w']*)", function(a,b) return a:upper()..b:lower() end))
end
string.trim = string.trim or function(s) return (tostring(s or "")):match("^%s*(.-)%s*$") end
string.split = string.split or function(s, sep)
  local parts = {}
  for p in tostring(s or ""):gmatch("([^" .. (sep or ",") .. "]+)") do parts[#parts+1] = p end
  return parts
end
function _G.string_or_number(v) return v end
function _G.deepcopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = _G.deepcopy(v) end
  return out
end
function _G.getMudletInfo() return {} end
function _G.getFgColor() return 255, 255, 255 end

-- table.save / table.load -- Mudlet extension, used for persisted settings.
table.save = table.save or function(path, tbl) return true end
table.load = table.load or function(path) return nil end
table.contains = table.contains or function(t, v)
  for _, x in pairs(t) do if x == v then return true end end
  return false
end
table.n_keys = table.n_keys or function(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n
end

-- lfs (Lua File System) -- real module usually isn't loaded here; stub it.
_G.lfs = _G.lfs or { mkdir = function() return true end, attributes = function() return nil end }

-- GMCP / login data tables -- empty by default, tests can populate directly.
_G.gmcp = _G.gmcp or {}

-- Geyser stub -- enough for UserWindow/MiniConsole :new() chains used at
-- module-init time (mostly guarded by "if Geyser and Geyser.UserWindow"
-- checks already, but some files call unconditionally).
local StubWidget = {}
StubWidget.__index = StubWidget
function StubWidget:new(cfg, parent)
  local o = setmetatable({}, StubWidget)
  o.name = cfg and cfg.name or "stub"
  return o
end
for _, m in ipairs({
  "resize","move","reposition","show","hide","setColor","setFontSize",
  "enableAutoWrap","disableAutoWrap","setWrap","echo","cecho","decho",
  "clear","clearAll","append","setTimestampFormat","setTimestampFGColor",
  "setTimestampBGColor","enableTimestamp","disableTimestamp","display",
  "setStyleSheet","dechoLink","cechoLink","echoLink","hechoLink",
  "setClickCallback","setUnderline","setBold","setItalics","setClickFunction",
  "setState","setDoubleClickCallback",
}) do
  StubWidget[m] = function(...) return true end
end
-- Geyser.Label's real get_width()/get_height() -- used by LocationView's/
-- PortraitView's contain/stretch image-scaling HTML builders. Fixed
-- non-zero defaults so those code paths can actually be exercised under
-- test instead of always hitting their "box has no size yet" bail-out.
StubWidget.get_width = function(...) return 300 end
StubWidget.get_height = function(...) return 200 end

-- Real-behaving (not a no-op) -- records what dock side each named
-- window actually requested, so a test can verify real per-window dock
-- assignment rather than just "it didn't crash".
_G.__dockPositionCalls = _G.__dockPositionCalls or {}
StubWidget.setDockPosition = function(self, pos)
  _G.__dockPositionCalls[self.name] = pos
  return true
end

_G.Geyser = _G.Geyser or {
  UserWindow = StubWidget,
  MiniConsole = StubWidget,
  Label = StubWidget,
  Container = StubWidget,
  Button = StubWidget,
  windowList = {},
}

-- Map/room API -- real behaving stubs (a backing table per room), not
-- no-ops, so mapper-fork tests can set up a room's state and read it back
-- to verify what a real Mudlet client would persist. __rooms[id] = {
--   name=, exists=true, env=, userdata={} }.
_G.__rooms = _G.__rooms or {}
local function __room(id)
  _G.__rooms[id] = _G.__rooms[id] or { userdata = {} }
  return _G.__rooms[id]
end
function _G.__mock_defineRoom(id, name)
  local r = __room(id)
  r.exists = true
  r.name = name or r.name or ""
  return r
end
function _G.roomexists(id) return (_G.__rooms[id] and _G.__rooms[id].exists) and 1 or 0 end
function _G.getRoomName(id) return (_G.__rooms[id] and _G.__rooms[id].name) or "" end
function _G.setRoomName(id, name) __room(id).name = name end
function _G.getRoomUserData(id, key)
  local r = _G.__rooms[id]
  if not r then return "" end
  local v = r.userdata[key]
  if v == nil then return "" end
  return v
end
function _G.setRoomUserData(id, key, value) __room(id).userdata[key] = value end
function _G.getRoomEnv(id) return (_G.__rooms[id] and _G.__rooms[id].env) or 0 end
function _G.setRoomEnv(id, envID) __room(id).env = envID end
function _G.setCustomEnvColor(...) return true end
function _G.getRoomWeight(id) return (_G.__rooms[id] and _G.__rooms[id].weight) or 1 end
function _G.setRoomWeight(id, w) __room(id).weight = w end

_G.demonnic = _G.demonnic or {}

-- AdjustableContainer package (vendored 3rd-party package, not DSL2's own
-- code) -- stub with the same shape as the Geyser stub above.
_G.Adjustable = _G.Adjustable or { Container = StubWidget }

print("mudlet_mock.lua loaded")
