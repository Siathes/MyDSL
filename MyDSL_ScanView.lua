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
SV.config    = SV.config or { gagScan = false }

-- Window and MiniConsole name constants.
local SCAN_WIN    = "MyDSL_Scan"
local RH_WIN      = "MyDSL_RightHere"
local SCAN_MC     = "MyDSL_Scan_MC"
local RH_MC       = "MyDSL_RightHere_MC"


------------------------------------------------------------------------
-- Local helpers
------------------------------------------------------------------------

local function isMob(name)
  return name:match("^[Aa]n? ") ~= nil or name:match("^[Tt]he ") ~= nil
end


------------------------------------------------------------------------
-- renderScan()  —  redraws the MyDSL_Scan window
------------------------------------------------------------------------
-- Right Here section uses byName (aggregated, deduplicated with counts).
-- Nearby section uses rows in order (may list same creature multiple times).

function SV.renderScan()
  clearWindow(SCAN_MC)
  local scan = MyDSL.State and MyDSL.State.scan
  if not scan or #scan.rows == 0 then
    cecho(SCAN_MC, "<#555555>[Empty scan]\n<reset>")
    return
  end

  -- [Right Here] — aggregated entries from rightHere table
  cecho(SCAN_MC, "<#888888>[Right Here]\n<reset>")
  local has_rh = scan.rightHere and next(scan.rightHere) ~= nil
  if not has_rh then
    cecho(SCAN_MC, "<#444444>  (none)\n<reset>")
  else
    for _, entry in pairs(scan.rightHere) do
      local c      = entry.is_mob and "#cc4444" or "#88aaff"
      local suffix = entry.count > 1
        and string.format(" <#ffcc44>(×%d)<reset>", entry.count) or ""
      cecho(SCAN_MC, string.format("<%s>  %s%s\n<reset>", c, entry.display, suffix))
    end
  end

  -- [Nearby] — individual rows excluding right-here entries
  cecho(SCAN_MC, "<#888888>[Nearby]\n<reset>")
  local has_nearby = false
  for _, row in ipairs(scan.rows) do
    if row.where ~= "right here" then
      has_nearby = true
      local c   = row.is_mob and "#886644" or "#6688cc"
      local dir = string.format(" <#444444>→<reset> <#888888>%s<reset>", row.where)
      cecho(SCAN_MC, string.format("<%s>  %s<reset>%s\n", c, row.display, dir))
    end
  end
  if not has_nearby then
    cecho(SCAN_MC, "<#444444>  (none)\n<reset>")
  end
end


------------------------------------------------------------------------
-- renderRightHere()  —  redraws the MyDSL_RightHere window
------------------------------------------------------------------------
-- Each entry is a clickable cechoLink that calls MyDSL.Target.set().

function SV.renderRightHere()
  clearWindow(RH_MC)
  local scan = MyDSL.State and MyDSL.State.scan
  cecho(RH_MC, "<#888888>Right Here:\n<reset>")

  if not scan or not next(scan.rightHere) then
    cecho(RH_MC, "<#444444>  (empty)\n<reset>")
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
    cechoLink(RH_MC, text, cmd, hint, false)
    cecho(RH_MC, "\n")
  end
end


------------------------------------------------------------------------
-- render()  —  redraws both windows
------------------------------------------------------------------------

function SV.render()
  SV.renderScan()
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
  local scanWin = MyDSL.Windows.ensure(SCAN_WIN)
  if not SV._mc.scan then
    SV._mc.scan = Geyser.MiniConsole:new({
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

  -- Register scan.updated event handler.
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
