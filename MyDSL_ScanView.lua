-- =============================================================================
-- MyDSL_ScanView.lua  --  Layer 3 Phase B: Scan / RightHere display
-- =============================================================================
-- Passive display only. Listens for "MyDSL.scan.updated" and renders two
-- windows: MyDSL_Scan (all nearby entities) and MyDSL_RightHere (current-room
-- entities, clickable to set target).
-- Never sends commands. Stale data after room movement is acceptable.
-- =============================================================================

MyDSL = MyDSL or {}
MyDSL.ScanView = MyDSL.ScanView or {}
local SV = MyDSL.ScanView

-- Safe-reload: kill old handlers/triggers before re-registering.
-- We do this unconditionally at module load, not inside init(), so that
-- a dofile() reload always starts clean even if init() is never called again.
for _, id in pairs(SV._handlers or {}) do pcall(killAnonymousEventHandler, id) end
for _, id in pairs(SV._triggers or {}) do pcall(killTrigger, id) end

SV._handlers = {}
SV._triggers = {}
SV._mc       = SV._mc or {}   -- persists across reloads to avoid duplicate MiniConsole creation
SV.ui        = SV.ui   or {}   -- public: ui.scanConsole used by DataLayer for appendBuffer
SV.config    = SV.config or { gagScan = false }

-- Window and MiniConsole name constants.
local SCAN_WIN    = "MyDSL_Scan"
local RH_WIN      = "MyDSL_RightHere"
local SCAN_MC     = "MyDSL_Scan_MC"
local RH_MC       = "MyDSL_RightHere_MC"


------------------------------------------------------------------------
-- renderRightHere()  —  redraws the MyDSL_RightHere window
------------------------------------------------------------------------
-- Scan window fills passively via DataLayer appendBuffer (game colors preserved).
-- RightHere is rebuilt from State.scan.rightHere as clickable target links.

function SV.renderRightHere()
  local mc = SV._mc and SV._mc.rightHere
  if not mc then return end
  mc:clear()
  local scan = MyDSL.State and MyDSL.State.scan
  if not scan or not scan.rightHere then
    mc:decho("\n<128,128,128>Right Here: (empty)\n")
    return
  end
  mc:decho("<136,136,136>Right Here:\n<r>")

  if not next(scan.rightHere) then
    mc:decho("<68,68,68>  (empty)\n<r>")
    return
  end

  for _, entry in pairs(scan.rightHere) do
    local c   = entry.is_mob and "#cc8844" or "#88aaff"
    local cnt = entry.count or 1
    local count_str = cnt > 1
      and string.format(" <#ffcc44>×%d<reset>", cnt) or ""
    local text = string.format("  <%s>%s%s<reset>", c, entry.display, count_str)
    -- Escape any embedded quotes in the creature name for the Lua callback string.
    local safe_name = entry.display:gsub('"', '\\"')
    local cmd  = string.format(
      'if MyDSL and MyDSL.Target then MyDSL.Target.set("%s", %s, "righthereclick") end',
      safe_name, tostring(entry.is_mob))
    local hint = "Click to target: " .. entry.display
    mc:cechoLink(text, cmd, hint, true)
    mc:decho("\n")
  end
end


------------------------------------------------------------------------
-- render()  —  redraws RightHere (Scan fills via appendBuffer in DataLayer)
------------------------------------------------------------------------

function SV.render()
  SV.renderRightHere()
end


------------------------------------------------------------------------
-- setGag(bool)  —  toggle scan output gagging
------------------------------------------------------------------------
-- Header lines gagged here. Body lines gagged in DataLayer.parseScanLine()
-- via the MyDSL.ScanView.config.gagScan flag check.

function SV.setGag(enabled)
  SV.config.gagScan = enabled
  -- Kill existing gag triggers.
  for _, id in pairs(SV._triggers) do pcall(killTrigger, id) end
  SV._triggers = {}
  if enabled then
    SV._triggers.gagHeader = tempRegexTrigger(
      "^Looking around you see:$",
      function() deleteLine() end
    )
    SV._triggers.gagDir = tempRegexTrigger(
      "^You peer intently %a+%.$",
      function() deleteLine() end
    )
  end
end


------------------------------------------------------------------------
-- init()  —  called once at load; safe to re-call on reload
------------------------------------------------------------------------

function SV.init()
  -- Ensure Scan UserWindow and its MiniConsole exist.
  -- Stored in SV.ui.scanConsole so DataLayer can call appendBuffer on it.
  local scanWin = MyDSL.Windows.ensure(SCAN_WIN)
  if not SV.ui.scanConsole then
    SV.ui.scanConsole = Geyser.MiniConsole:new({
      name      = SCAN_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300,
      scrollBar = false,
    }, scanWin)
  end

  -- Ensure RightHere UserWindow and its MiniConsole exist.
  local rhWin = MyDSL.Windows.ensure(RH_WIN)
  if not SV._mc.rightHere then
    SV._mc.rightHere = Geyser.MiniConsole:new({
      name      = RH_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300,
      scrollBar = false,
    }, rhWin)
  end

  -- Register scan.updated event handler (rebuilds RightHere clickable list).
  SV._handlers.scanUpdated = registerAnonymousEventHandler(
    "MyDSL.scan.updated",
    function() SV.render() end
  )

  -- Restore gag triggers if config says so.
  if SV.config.gagScan then SV.setGag(true) end

  -- Initial render (shows empty state).
  SV.render()

  debugc("[MyDSL] ScanView loaded.")
end


------------------------------------------------------------------------
-- Aliases  (registered as tempAlias so they survive script reloads)
------------------------------------------------------------------------

tempAlias("^mydsl scan gag$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.setGag(true) end")
tempAlias("^mydsl scan ungag$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.setGag(false) end")


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

SV.init()
