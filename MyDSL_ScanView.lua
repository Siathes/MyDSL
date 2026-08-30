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

-- Mirrors RightHere's window text into MyDSL/logs/righthere/ (2026-07-05:
-- Mudlet's startLogging() can't capture MiniConsole content at all).
local function rhLog(mc, text)
  mc:decho(text)
  if MyDSL.logWindow then MyDSL.logWindow("righthere", text) end
end
local function rhLogLink(mc, text, cmd, hint, underline)
  mc:dechoLink(text, cmd, hint, underline)
  if MyDSL.logWindow then MyDSL.logWindow("righthere", text) end
end


------------------------------------------------------------------------
-- renderRightHere()  —  redraws the MyDSL_RightHere window
------------------------------------------------------------------------
-- Scan window fills passively via DataLayer appendBuffer (game colors preserved).
-- RightHere is rebuilt from State.scan.rightHere as clickable target links.

-- FIX 2026-08-29, per the maintainer live-test note ("right here" shows in
-- window also named "Right Here"): dropped the redundant "Right Here:"
-- header text -- the window's own title bar already says that (see
-- MyDSL.Windows.getTitle(RH_WIN, "Right Here") below).
function SV.renderRightHere()
  local mc = SV._mc and SV._mc.rightHere
  if not mc then return end
  mc:clear()
  local scan = MyDSL.State and MyDSL.State.scan
  if not scan or not scan.rightHere then
    rhLog(mc, "<128,128,128>(empty)\n")
    return
  end

  if not next(scan.rightHere) then
    rhLog(mc, "<68,68,68>  (empty)\n<r>")
    return
  end

  for _, entry in pairs(scan.rightHere) do
    local c   = entry.is_mob and "204,136,68" or "136,170,255"
    local cnt = entry.count or 1
    local count_str = cnt > 1
      and string.format(" <255,204,68>×%d<r>", cnt) or ""
    -- Known/Seen/Unknown badge -- added 2026-07-12, per the maintainer ("as we
    -- identify mobs, it should create a table to look up and find more
    -- accurate tags for targets"). Adapted from a prior working
    -- implementation found in the DSL1 sibling profile
    -- (MyDSL.TargetCompact's renderRightHere patch): green "Known" means
    -- MyDSL_CreatureLore.lua has real lore data for this mob (its stored
    -- name is what's actually being targeted -- see resolveMobName() in
    -- MyDSL_DataLayer.lua), cyan "Seen" means it's been sighted before but
    -- never lored, yellow "Unknown" means this is the first sighting ever.
    -- Mobs only -- players/NPCs don't have creaturelore entries.
    local badge = ""
    if entry.is_mob and MyDSL.CreatureLore and MyDSL.CreatureLore.knownState then
      local state = MyDSL.CreatureLore.knownState(entry.key)
      if state == "known" then
        badge = " <68,221,68>[Known]<r>"
      elseif state == "seen" then
        badge = " <68,204,221>[Seen]<r>"
      else
        badge = " <221,204,68>[Unknown]<r>"
      end
    end
    local text = string.format("  <%s>%s%s%s<r>\n", c, entry.display, count_str, badge)
    -- Escape any embedded quotes in the creature name for the Lua callback string.
    local safe_name = entry.display:gsub('"', '\\"')
    local cmd  = string.format(
      'if MyDSL and MyDSL.Target then MyDSL.Target.set("%s", %s, "righthereclick") end',
      safe_name, tostring(entry.is_mob))
    local hint = "Click to target: " .. entry.display
    rhLogLink(mc, text, cmd, hint, true)
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
      "^You peer intently [a-zA-Z]+\\.$",
      function() deleteLine() end
    )
  end
end


------------------------------------------------------------------------
-- init()  —  called once at load; safe to re-call on reload
------------------------------------------------------------------------

------------------------------------------------------------------------
-- ensureUI()  --  creates both windows/consoles if they don't exist yet.
-- Extracted from init() 2026-07-15 so rebuild()/rebuildRightHere() can
-- recreate a console without duplicating the whole setup.
------------------------------------------------------------------------

function SV.ensureUI()
  -- Ensure Scan UserWindow and its MiniConsole exist.
  -- Stored in SV.ui.scanConsole so DataLayer can call appendBuffer on it.
  local scanWin = MyDSL.Windows.ensure(SCAN_WIN)
  -- Visual pass v2 "One Bar, Renamed and Colored" (locked spec,
  -- 2026-08-26) -- short, plain name; applyTheme() colors it.
  if scanWin and scanWin.setTitle then
    pcall(function() scanWin:setTitle(MyDSL.Windows.getTitle(SCAN_WIN, "Scan")) end)
  end
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
  if rhWin and rhWin.setTitle then
    pcall(function() rhWin:setTitle(MyDSL.Windows.getTitle(RH_WIN, "Right Here")) end)
  end
  if not SV._mc.rightHere then
    SV._mc.rightHere = Geyser.MiniConsole:new({
      name      = RH_MC,
      x = 0, y = 0, width = "100%", height = "100%",
      wrapWidth = 300,
      scrollBar = false,
    }, rhWin)
  end

  -- Font sizes now persisted per-window (2026-07-15, "bring Scan/
  -- RightHere up to the same status/show/hide/rebuild/font standard
  -- other windows have" -- see docs/CHANGELOG.md). Same shared
  -- profile-level store MyDSL_History/MyDSL_Focus already use. Was:
  -- Scan had no explicit size at all (inherited theme default),
  -- RightHere was hardcoded to 9 with no way to change it.
  -- Fallback defaults updated 2026-08-23 to match the maintainer's real
  -- long-tuned live sizes (MyDSL_windowfonts.lua: Scan=7, RightHere=8),
  -- confirmed via a full settings-vs-defaults audit -- these only ever
  -- applied to a brand-new window with nothing saved yet, but a genuine
  -- fresh install was shipping the wrong size until re-tuned by hand.
  local scanFont = MyDSL.Windows.getFontSize(SCAN_WIN, 7)
  local rhFont   = MyDSL.Windows.getFontSize(RH_WIN, 8)
  if SV.ui.scanConsole then SV.ui.scanConsole:setFontSize(scanFont) end
  if SV._mc.rightHere then SV._mc.rightHere:setFontSize(rhFont) end

  -- Theme-driven background/font, added 2026-07-11. Both consoles had no
  -- styling at all before (see docs/CHANGELOG.md's ThemeEngine entry).
  if MyDSL.Theme and MyDSL.Theme.styleConsole then
    MyDSL.Theme.styleConsole(SV.ui.scanConsole, SCAN_WIN, scanFont)
    MyDSL.Theme.styleConsole(SV._mc.rightHere, RH_WIN, rhFont)
  end
end

function SV.init()
  SV.ensureUI()

  -- Register scan.updated event handler (rebuilds RightHere clickable list).
  SV._handlers.scanUpdated = registerAnonymousEventHandler(
    "MyDSL.scan.updated",
    function() SV.render() end
  )

  -- Decrement/clear the dying mob's RightHere entry -- added 2026-07-16,
  -- per the maintainer ("proceed" on the investigated cause of Murder/Consider/
  -- Order-All -> "They're not here" reports). Real gap found: identical
  -- mobs collapse into ONE RightHere entry with a `count` field
  -- (parseLookHereLine(), MyDSL_DataLayer.lua), but nothing ever
  -- decremented it when a mob in it actually died mid-fight -- so a
  -- stale count (not room-change staleness, mid-fight staleness) let a
  -- player click a target that had already died since the last
  -- look/scan. MyDSL_TargetView.lua already listens for this same
  -- "MyDSL.combat.died" event to auto-advance/clear the Focus target,
  -- but never touched RightHere's own data -- this is the missing half.
  SV._handlers.combatDied = registerAnonymousEventHandler(
    "MyDSL.combat.died",
    function(_, payload)
      local scan = MyDSL.State and MyDSL.State.scan
      if not (scan and scan.rightHere and payload and payload.key) then return end
      local entry = scan.rightHere[payload.key]
      if not entry then return end
      if (entry.count or 1) > 1 then
        entry.count = entry.count - 1
      else
        scan.rightHere[payload.key] = nil
      end
      SV.render()
    end
  )

  -- Re-theme both consoles when the active theme switches.
  SV._handlers.themeChanged = registerAnonymousEventHandler(
    "MyDSL.theme.changed",
    function()
      if MyDSL.Theme and MyDSL.Theme.styleConsole then
        MyDSL.Theme.styleConsole(SV.ui.scanConsole, SCAN_WIN, MyDSL.Windows.getFontSize(SCAN_WIN, 7))
        MyDSL.Theme.styleConsole(SV._mc.rightHere, RH_WIN, MyDSL.Windows.getFontSize(RH_WIN, 8))
      end
    end
  )

  -- Restore gag triggers if config says so.
  if SV.config.gagScan then SV.setGag(true) end

  -- Initial render (shows empty state).
  SV.render()

  debugc("[MyDSL] ScanView loaded.")
end


------------------------------------------------------------------------
-- Window lifecycle -- status/show/hide/rebuild/font, added 2026-07-15 to
-- bring Scan/RightHere up to the same standard Live/Chat/Portrait/
-- Affects/Tick/Alterform already have (found during a "does Scan have
-- the same options as other windows" check). Font persists via the
-- shared MyDSL.Windows store (same pattern as MyDSL_History/MyDSL_Focus),
-- not a bespoke settings file -- this module has no other per-character
-- config to persist beyond the existing gagScan flag.
------------------------------------------------------------------------

function SV.status()
  decho(string.format(
    "<136,204,255>[MyDSL] Scan: gag=%s font=%d | RightHere: font=%d<r>\n",
    tostring(SV.config.gagScan),
    MyDSL.Windows.getFontSize(SCAN_WIN, 7),
    MyDSL.Windows.getFontSize(RH_WIN, 8)
  ))
end

function SV.show() MyDSL.Windows.show(SCAN_WIN) end
function SV.hide() MyDSL.Windows.hide(SCAN_WIN) end

-- setTitle(title)/setRightHereTitle(title) -- real gap fix, 2026-08-26
-- (command-parity sweep).
function SV.setTitle(title)
  title = tostring(title or ""):match("^%s*(.-)%s*$")
  if title == "" then title = "Scan" end
  MyDSL.Windows.setTitle(SCAN_WIN, title)
  local win = MyDSL.Windows.get and MyDSL.Windows.get(SCAN_WIN)
  if win and win.setTitle then pcall(function() win:setTitle(title) end) end
  echo("Scan title=" .. title .. "\n")
end

function SV.setFont(size)
  size = tonumber(size)
  if not size then echo("usage: mydsl scan font <size>\n"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  if SV.ui.scanConsole then SV.ui.scanConsole:setFontSize(size) end
  MyDSL.Windows.setFontSize(SCAN_WIN, size)
  echo("MyDSL_Scan font=" .. tostring(size) .. "\n")
end

function SV.showRightHere() MyDSL.Windows.show(RH_WIN) end
function SV.hideRightHere() MyDSL.Windows.hide(RH_WIN) end

function SV.setRightHereTitle(title)
  title = tostring(title or ""):match("^%s*(.-)%s*$")
  if title == "" then title = "Right Here" end
  MyDSL.Windows.setTitle(RH_WIN, title)
  local win = MyDSL.Windows.get and MyDSL.Windows.get(RH_WIN)
  if win and win.setTitle then pcall(function() win:setTitle(title) end) end
  echo("Right Here title=" .. title .. "\n")
end

function SV.setRightHereFont(size)
  size = tonumber(size)
  if not size then echo("usage: mydsl righthere font <size>\n"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  if SV._mc.rightHere then SV._mc.rightHere:setFontSize(size) end
  MyDSL.Windows.setFontSize(RH_WIN, size)
  echo("MyDSL_RightHere font=" .. tostring(size) .. "\n")
end


------------------------------------------------------------------------
-- Aliases  (registered as tempAlias so they survive script reloads)
------------------------------------------------------------------------

-- Renamed 2026-07-11, command-surface retrofit (docs/TODO.md "OPEN —
-- Command-surface retrofit"), per the maintainer. Dropped the "mydsl" prefix --
-- confirmed bare "scan"/"scan <dir>" is the real DSL command
-- (DSL_Helpfiles/scan.txt), but "gag"/"ungag" aren't valid directions, so
-- no functional collision. ("mydsl righthere dump" below is left alone --
-- a debug diagnostic, not part of this retrofit's scope.)
tempAlias("^scan gag$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.setGag(true) end")
tempAlias("^scan ungag$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.setGag(false) end")

-- status/show/hide/font -- kept under the "mydsl" prefix (not bare
-- "scan ...") since bare "scan" is real DSL vocabulary and these aren't
-- part of the 2026-07-11 command-surface retrofit's scope. "rebuild"
-- removed 2026-08-26 (command-parity sweep) -- no evidence it was ever
-- needed, and show/hide/status/font already cover every real use.
tempAlias("^mydsl scan status$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.status() end")
tempAlias("^mydsl scan show$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.show() end")
tempAlias("^mydsl scan hide$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.hide() end")
tempAlias("^mydsl scan font (\\d+)$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.setFont(matches[2]) end")
tempAlias("^mydsl scan title (.+)$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.setTitle(matches[2]) end")

tempAlias("^mydsl righthere status$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.status() end")
tempAlias("^mydsl righthere show$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.showRightHere() end")
tempAlias("^mydsl righthere hide$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.hideRightHere() end")
tempAlias("^mydsl righthere font (\\d+)$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.setRightHereFont(matches[2]) end")
tempAlias("^mydsl righthere title (.+)$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.setRightHereTitle(matches[2]) end")

-- mydsl righthere dump -- added 2026-07-08 as a one-shot live diagnostic,
-- per repeated "still not updating" reports that static log analysis
-- couldn't explain any further (trigger anchor, capture body, and window
-- visibility all checked out). Echoes the raw MyDSL.State.scan.rightHere
-- table straight to the main console, bypassing the RightHere window
-- entirely -- lets us tell a capture problem from a display problem in
-- one command instead of guessing from logs alone.
-- Uses decho() (RGB-triple syntax), not cecho() (named-color syntax only)
-- -- confirmed 2026-07-08 live: cecho() with a bare "<r,g,b>" tag doesn't
-- get parsed as a color at all, it just echoes the literal characters.
function SV.dumpRightHere()
  local scan = MyDSL.State and MyDSL.State.scan
  if not scan or not scan.rightHere then
    decho("<255,136,68>[MyDSL] scan.rightHere not initialized (no look/scan run yet this session?)\n")
    return
  end
  local n = 0
  for key, entry in pairs(scan.rightHere) do
    n = n + 1
    decho(string.format("<255,255,68>%s<255,255,255> = \"%s\" (is_mob=%s, count=%s)\n",
      key, entry.name, tostring(entry.is_mob), tostring(entry.count)))
  end
  decho(string.format("<136,204,255>[MyDSL] rightHere total: %d entries. Capture active: %s\n",
    n, tostring(MyDSL._triggers.lookBody ~= nil)))
end
tempAlias("^mydsl righthere dump$",
  "if MyDSL and MyDSL.ScanView then MyDSL.ScanView.dumpRightHere() end")


------------------------------------------------------------------------
-- Boot
------------------------------------------------------------------------

SV.init()
