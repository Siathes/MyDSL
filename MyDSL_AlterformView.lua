
--[[=====================================================================
  MyDSL AlterformView v1
  ----------------------------------------------------------------------
  Small standalone countdown window for the "alterform" affect, meant to
  sit beside MyDSL_Tick -- added 2026-07-11, per Steven ("create an
  alterform timer like tick to go beside it when we have the alterform
  affect"). Structurally mirrors MyDSL_TickView.lua closely (same panel/
  tube/fill/seconds/detail shape) so the two read as a matched pair, with
  its own accent color and a genuine "not active" state (alterform isn't
  always running the way the tick is).

  Data source: MyDSL.Affects.getRemaining("alterform") -- reuses
  MyDSL_AffectsView.lua's existing tick-average-based conversion (the
  exact same math Tick/Affects/MoonWeather's clock already share), so this
  file owns no timing/parsing of its own. Confirmed real affect via
  log-corpus grep: "Spell: alterform : modifies none by 0 for 90 cycles,
  (45 hours)" -- a long-duration buff, tens of hours not tens of seconds,
  so remaining time is shown as h/m, not raw seconds like Tick.

  Passive display only. Never sends game commands.
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.AlterformView = MyDSL.AlterformView or {}

local F = MyDSL.AlterformView
F.version = "AlterformView v1"

F.name = F.name or "MyDSL_Alterform"
F.title = F.title or "-= Alterform =-"

F.config = F.config or {}
F.config.shown = F.config.shown ~= false
F.config.font = tonumber(F.config.font or 9) or 9
F.config.debug = F.config.debug == true
-- Warning/danger sound before Alterform falls off, per Steven's MyDSL
-- notes ("warning + sound before it falls off (countdown from the last
-- 5 ticks, warning at 10 ticks left)"). F.palette() already implements
-- exactly these two thresholds visually (color-only, since 2026-07-11)
-- -- this just adds the sound half at the same thresholds, firing once
-- per transition into a zone, not on every render. Files are optional
-- (per this project's own MyDSL_MovementSounds.lua precedent -- provide
-- your own under Sounds/, silently skipped if missing rather than
-- erroring).
F.config.soundEnabled = F.config.soundEnabled ~= false
F.config.warnSound = F.config.warnSound or "alterform_warning.mp3"
F.config.dangerSound = F.config.dangerSound or "alterform_danger.mp3"

F.ui = F.ui or {}

local function ce(msg)
  cecho("\n<cyan>[MyDSL.AlterformView]<reset> " .. tostring(msg) .. "\n")
end

local function trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function profileDir()
  local root = getMudletHomeDir and getMudletHomeDir() or "."
  return root .. "/MyDSL"
end

local function ensureDir(path)
  if lfs and lfs.mkdir then pcall(lfs.mkdir, path) end
  if os and os.execute then pcall(os.execute, "mkdir -p " .. string.format("%q", path)) end
end

function F.settingsFile()
  return profileDir() .. "/alterformview_settings.lua"
end

function F.serializeSettings()
  local out = { "return {\n" }
  table.insert(out, string.format("  savedAt = %q,\n", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(out, string.format("  shown = %s,\n", F.config.shown and "true" or "false"))
  table.insert(out, string.format("  font = %d,\n", tonumber(F.config.font) or 9))
  table.insert(out, string.format("  title = %q,\n", tostring(F.title or "-= Alterform =-")))
  table.insert(out, string.format("  soundEnabled = %s,\n", F.config.soundEnabled and "true" or "false"))
  table.insert(out, "}\n")
  return table.concat(out)
end

function F.saveSettings()
  ensureDir(profileDir())
  local file = F.settingsFile()
  local f = io.open(file, "w")
  if not f then ce("<red>could not save settings: " .. tostring(file) .. "<reset>"); return false end
  f:write(F.serializeSettings())
  f:close()
  F.settingsLoaded = true
  F.settingsFilePath = file
  return true
end

function F.loadSettings()
  local file = F.settingsFile()
  local f = io.open(file, "r")
  if not f then F.settingsLoaded = false; F.settingsFilePath = file; return false end
  f:close()

  local ok, data = pcall(dofile, file)
  if not ok or type(data) ~= "table" then
    ce("<red>could not load settings: " .. tostring(data) .. "<reset>")
    F.settingsLoaded = false
    F.settingsFilePath = file
    return false
  end

  if data.shown ~= nil then F.config.shown = data.shown == true end
  F.config.font = tonumber(data.font or F.config.font) or F.config.font
  if data.title and tostring(data.title) ~= "" then F.title = tostring(data.title) end
  if data.soundEnabled ~= nil then F.config.soundEnabled = data.soundEnabled == true end
  F.settingsLoaded = true
  F.settingsFilePath = file
  return true
end

-- formatHM(seconds) -- alterform runs tens of hours, not tens of
-- seconds like Tick, so this shows h/m (falling back to m/s under an
-- hour, bare seconds under a minute) instead of Tick's plain "Ns".
local function formatHM(seconds)
  seconds = tonumber(seconds)
  if not seconds then return "--" end
  seconds = math.max(0, math.floor(seconds + 0.5))
  local hours = math.floor(seconds / 3600)
  local mins  = math.floor((seconds % 3600) / 60)
  local secs  = seconds % 60
  if hours > 0 then return string.format("%dh%02dm", hours, mins) end
  if mins > 0 then return string.format("%dm%02ds", mins, secs) end
  return string.format("%ds", secs)
end

local function stylePanel()
  if MyDSL.Theme and MyDSL.Theme.panelCSS then
    return MyDSL.Theme.panelCSS(F.name)
  end
  return [[
    background-color: #0b1013;
    border: 1px solid #33434a;
    border-radius: 8px;
  ]]
end

local function titleColorCSS()
  if MyDSL.Theme then
    local ok, css = pcall(MyDSL.Theme.colorToCSS, MyDSL.Theme.get(F.name, "titleColor"))
    if ok and css then return css end
  end
  return "#ffd166"
end

local function styleTube()
  return [[
    background-color: QLinearGradient(
      x1: 0, y1: 0, x2: 1, y2: 0,
      stop: 0 #070a0c,
      stop: 0.5 #151d20,
      stop: 1 #070a0c
    );
    border: 1px solid #53636b;
    border-radius: 7px;
  ]]
end

local function styleFill(color1, color2, color3)
  return string.format([[
    background-color: QLinearGradient(
      x1: 0, y1: 0, x2: 1, y2: 0,
      stop: 0 %s,
      stop: 0.25 %s,
      stop: 0.70 %s,
      stop: 1 %s
    );
    border: 1px solid #111111;
    border-radius: 6px;
  ]], color3, color1, color2, color3)
end

local function styleText(size, color, weight)
  return string.format([[
    background-color: rgba(0,0,0,0);
    color: %s;
    border: 0px;
    font-family: "Noto Sans Mono", monospace;
    font-size: %dpt;
    font-weight: %s;
    qproperty-alignment: 'AlignCenter';
  ]], color or "#eeeeee", tonumber(size or F.config.font) or 9, weight or "normal")
end

local function styleStrip(color)
  return string.format([[
    background-color: %s;
    border: 0px;
    border-radius: 2px;
  ]], color or "#9b7fe0")
end

-- palette(cycles, active) -- same low-cycle thresholds AffectsView's own
-- colorForDuration() already uses (A.config.lowCycles=5, then 10) so
-- "about to expire" means the same thing everywhere in this profile.
-- "ready" here is violet, not Tick's green -- a deliberate, distinct
-- accent so the two widgets read as a matched pair, not duplicates.
function F.palette(cycles, active)
  if not active then
    return {
      name = "off",
      main = "#4a4d52", bright = "#7a7d82", dark = "#26282b",
      text = "#8b8f94", strip = "#4a4d52",
    }
  end

  cycles = tonumber(cycles)
  local lowCycles = (MyDSL.Affects and MyDSL.Affects.config and MyDSL.Affects.config.lowCycles) or 5

  if cycles and cycles <= lowCycles then
    return {
      name = "danger",
      main = "#ff4040", bright = "#ff8989", dark = "#8c1515",
      text = "#ffd1d1", strip = "#ff4040",
    }
  elseif cycles and cycles <= 10 then
    return {
      name = "warn",
      main = "#ffd84a", bright = "#fff09b", dark = "#8a6d00",
      text = "#fff3bc", strip = "#ffd84a",
    }
  end

  return {
    name = "ready",
    main = "#9b7fe0", bright = "#c9b8f5", dark = "#4a3a7a",
    text = "#e6dcff", strip = "#9b7fe0",
  }
end

-- ensureUI() -- changed 2026-07-11 to an Adjustable.Container, per Steven
-- ("alterform window change to same as moonweather, we will keep it
-- inside the main window for layout cleanness"). Mirrors
-- MyDSL_MoonWeather.lua's _buildUI() exactly: builds its own container
-- directly (bypassing MyDSL.Windows.ensure()) so the native title bar can
-- be blanked to "" the same way, with a pcall-then-registry-fallback in
-- case a same-named object already exists. Was a Geyser.UserWindow
-- (detachable, its own floating window like Tick) before this change.
function F.ensureUI()
  if F.ui.win and F.ui.panel and F.ui.tube and F.ui.fill and F.ui.title and F.ui.seconds then return true end

  local layoutDef = MyDSL.Layout and MyDSL.Layout.get(F.name)
  local defX = layoutDef and (math.floor(layoutDef.x * 100) .. "%") or "62%"
  local defY = layoutDef and (math.floor(layoutDef.y * 100) .. "%") or "79%"
  local defW = layoutDef and (math.floor(layoutDef.w * 100) .. "%") or "3%"
  local defH = layoutDef and (math.floor(layoutDef.h * 100) .. "%") or "21%"

  local ok, container = pcall(function()
    return Adjustable.Container:new({
      name          = F.name,
      x             = defX, y = defY, width = defW, height = defH,
      adjLabelstyle = "background-color: rgba(0,0,0,0); border: none; padding: 0px;",
    })
  end)

  if not ok or not container then
    ce("Adjustable.Container:new() failed: " .. tostring(container) .. " -- trying WindowRegistry fallback")
    container = MyDSL.Windows and MyDSL.Windows.get(F.name)
    if not container then
      ce("FATAL: cannot create or find container. ensureUI() aborted.")
      return false
    end
  end

  F.ui.win = container
  pcall(function() F.ui.win:setTitle(" ") end)   -- minimize title bar chrome, same as MoonWeather

  -- REAL BUG, found live 2026-07-12 (Steven: "the min/close buttons were
  -- off till kien loaded in then they appeared again"): this module
  -- builds and locks its own container directly, bypassing
  -- MyDSL.Windows.ensure() -- but never told the registry, so
  -- registry[F.name].obj stayed nil forever. MyDSL.Windows.show()/hide()
  -- (fired for every registered window on "MyDSL.character.identified",
  -- see WindowRegistry's own characterIdentified handler) falls back to
  -- MyDSL.Windows.ensure(windowName) whenever entry.obj is nil -- which
  -- saw no existing object and created a SECOND, fresh, unlocked
  -- Adjustable.Container under the same name, replacing the first one's
  -- lock state. Registering the real object here so that fallback finds
  -- it and reuses it instead of recreating a duplicate.
  do
    local entry = MyDSL.Windows and MyDSL.Windows.registry and MyDSL.Windows.registry[F.name]
    if entry then entry.obj = container; entry.created = true end
  end

  -- REAL BUG, found live 2026-07-12 (Steven: "you can see the min/close
  -- buttons"): the constructor's old "lockStyle = 'padding'" field did
  -- nothing at all -- confirmed by reading Mudlet's actual bundled
  -- GeyserAdjustableContainer.lua: a container is only ever locked at
  -- creation if BOTH lockStyle AND locked=true are passed, and "padding"
  -- isn't even one of Mudlet's real lockStyle names ("standard"/"border"/
  -- "full"/"light") -- it silently fell back to unlocked, full native
  -- chrome (min/restore, close, lock, save, load buttons all live and
  -- visible).
  --
  -- SECOND REAL BUG, found live 2026-07-12 (same day, in MyDSL_MoonWeather
  -- .lua's identical pattern, Steven: "since we locked the window i cant
  -- resize... to fit all the text"): calling lockContainer("light") here
  -- was wrongly documented as only hiding the min/restore/close labels --
  -- that's just the *visual style*. Mudlet's own doc comment on
  -- lockContainer() in GeyserAdjustableContainer.lua is unambiguous:
  -- "lock means that your container is no longer moveable/resizable by
  -- mouse" -- ANY lockStyle sets self.locked = true, and self.locked (not
  -- lockStyle) is what the mouse-resize/move handlers actually check. So
  -- "light" was silently disabling manual resize/move here too the whole
  -- time. Fixed by never locking the container at all -- exitLabel
  -- (close) and minimizeLabel (min/restore) are just plain Geyser.Label
  -- children created unconditionally in the constructor, so hiding them
  -- directly leaves self.locked = false (mouse move/resize fully
  -- functional) while still removing the button clutter.
  pcall(function() F.ui.win.exitLabel:hide() end)
  pcall(function() F.ui.win.minimizeLabel:hide() end)

  F.ui.panel  = Geyser.Label:new({ name = F.name .. "_Panel",  x = 0, y = 0, width = "100%", height = "100%" }, F.ui.win)
  F.ui.title  = Geyser.Label:new({ name = F.name .. "_Title",  x = 0, y = "4%", width = "100%", height = "14%" }, F.ui.win)
  -- Layout reworked 2026-07-12, per Steven ("move the timer to a more
  -- visible location like bottom above the cycle counter"): tube
  -- shrunk (52% -> 38% tall, same 3%-top/3%-bottom inset for fill) to
  -- make room for the countdown text as its own distinct row clear of
  -- the tube graphic, sitting directly above the cycle-count row --
  -- confirmed this exact arrangement via AskUserQuestion before
  -- building it. render()'s fillH/fillY math below uses fill's new max
  -- height (32, was 46) to stay in sync with this.
  F.ui.tube   = Geyser.Label:new({ name = F.name .. "_Tube",   x = "35%", y = "22%", width = "30%", height = "38%" }, F.ui.win)
  F.ui.fill   = Geyser.Label:new({ name = F.name .. "_Fill",   x = "38%", y = "25%", width = "24%", height = "32%" }, F.ui.win)
  F.ui.seconds= Geyser.Label:new({ name = F.name .. "_Seconds",x = 0, y = "62%", width = "100%", height = "14%" }, F.ui.win)
  F.ui.detail = Geyser.Label:new({ name = F.name .. "_Detail", x = 0, y = "78%", width = "100%", height = "14%" }, F.ui.win)
  F.ui.strip  = Geyser.Label:new({ name = F.name .. "_Strip",  x = "18%", y = "94%", width = "64%", height = "3%" }, F.ui.win)

  F.ui.panel:setStyleSheet(stylePanel())
  F.ui.tube:setStyleSheet(styleTube())
  F.ui.title:setStyleSheet(styleText(F.config.font, titleColorCSS(), "bold"))
  F.ui.seconds:setStyleSheet(styleText(F.config.font + 3, "#eeeeee", "bold"))
  F.ui.detail:setStyleSheet(styleText(math.max(7, F.config.font - 1), "#9ba7ad", "normal"))
  F.ui.strip:setStyleSheet(styleStrip("#4a4d52"))

  if F.config.shown then F.show() else F.hide() end
  return true
end

function F.applyFont()
  if not F.ui or not F.ui.title then return end
  F.ui.title:setStyleSheet(styleText(F.config.font, titleColorCSS(), "bold"))
  F.ui.seconds:setStyleSheet(styleText(F.config.font + 3, "#eeeeee", "bold"))
  F.ui.detail:setStyleSheet(styleText(math.max(7, F.config.font - 1), "#9ba7ad", "normal"))
end

-- checkSoundWarning(zoneName) -- fires the warn/danger sound exactly
-- once per transition INTO that zone (not on every render, which would
-- fire on every affect update while already in the zone -- roughly one
-- per game tick). "off"/"ready" both clear the tracked zone so the next
-- real countdown starts fresh.
function F.checkSoundWarning(zoneName)
  if not F.config.soundEnabled then return end
  if zoneName == F._lastSoundZone then return end
  local file
  if zoneName == "danger" then file = F.config.dangerSound
  elseif zoneName == "warn" then file = F.config.warnSound end
  if file then
    local path = getMudletHomeDir() .. "/Sounds/" .. file
    local f = io.open(path, "r")
    if f then
      f:close()
      pcall(playSoundFile, { name = path, key = "alterform_warning" })
    end
  end
  F._lastSoundZone = zoneName
end

function F.render(reason)
  if not F.ensureUI() then return end

  local cycles, seconds = nil, nil
  if MyDSL.Affects and MyDSL.Affects.getRemaining then
    cycles, seconds = MyDSL.Affects.getRemaining("alterform")
  end
  local active = cycles ~= nil

  -- Full tube = "plenty of time left" -- scaled against a generous 90-cycle
  -- reference (the longest confirmed real duration in the log corpus) since
  -- (unlike Tick) there's no fixed known maximum to measure percent against.
  local pct = 0
  if active then
    pct = math.min(1, (tonumber(cycles) or 0) / 90)
  end

  local pal = F.palette(cycles, active)
  F.checkSoundWarning(pal.name)
  -- 32 = fill's max height (was 46 before the 2026-07-12 layout rework
  -- that shrunk the tube to make room for the countdown row) -- keep in
  -- sync with F.ensureUI()'s F.ui.fill height above.
  local fillH = math.floor(32 * pct + 0.5)
  if fillH < 2 and pct > 0 then fillH = 2 end
  local fillY = 25 + (32 - fillH)

  pcall(function()
    F.ui.fill:move("38%", tostring(fillY) .. "%")
    F.ui.fill:resize("24%", tostring(fillH) .. "%")
  end)

  F.ui.fill:setStyleSheet(styleFill(pal.bright, pal.main, pal.dark))
  F.ui.strip:setStyleSheet(styleStrip(pal.strip))

  local remText = active and formatHM(seconds) or "--"
  local titleText = active and "FORM" or "OFF"
  local detail = active and (tostring(cycles) .. "c") or "not active"

  F.ui.title:echo("<center>" .. titleText .. "</center>")
  F.ui.seconds:setStyleSheet(styleText(F.config.font + 3, pal.text, "bold"))
  F.ui.seconds:echo("<center>" .. remText .. "</center>")
  F.ui.detail:echo("<center>" .. detail .. "</center>")

  -- Auto-hide when not active -- added 2026-07-11, per Steven ("alterform
  -- window should only display when its active"). Overrides the initial
  -- design (always-visible dim "OFF" state, "stale data beats spam") on
  -- his explicit direction for this one window. F.config.shown remains
  -- the user's own manual override via "toggle alterform"/"focus hide" --
  -- if they've explicitly hidden it, it stays hidden regardless of active
  -- state; otherwise it auto-follows whether the affect is up.
  if F.ui.win then
    pcall(function()
      if F.config.shown and active then F.ui.win:show()
      else F.ui.win:hide() end
    end)
  end

  F.lastReason = reason or "render"
end

-- Registry-synced visibility, same pattern as TickView/MoonWeather (both
-- fixed 2026-07-11 for the same reason): WindowRegistry's loadState() can
-- show/hide the underlying Geyser object directly, bypassing F.show()/
-- hide() entirely, so toggle() must consult the real registry state
-- rather than trust only its own locally-persisted flag.
local function syncRegistryVisible(visible)
  local entry = MyDSL.Windows and MyDSL.Windows.registry and MyDSL.Windows.registry[F.name]
  if entry then entry.visible = visible end
end

function F.show()
  F.config.shown = true
  syncRegistryVisible(true)
  if F.ui and F.ui.win then pcall(function() F.ui.win:show() end) end
  F.render("show")
  F.saveSettings()
end

function F.hide()
  F.config.shown = false
  syncRegistryVisible(false)
  if F.ui and F.ui.win then pcall(function() F.ui.win:hide() end) end
  F.saveSettings()
end

-- "toggle alterform" -- matches this profile's PNP-derived bare
-- "toggle <module>" convention (see MyDSL_TickView.lua/MyDSL_CombatView.lua
-- for the same pattern); "alterform" isn't a real PNP module name (this
-- widget has no PNP equivalent) so this is a new, not reused, module name.
function F.toggle()
  local entry = MyDSL.Windows and MyDSL.Windows.registry and MyDSL.Windows.registry[F.name]
  local shown = entry and entry.visible
  if shown == nil then shown = F.config.shown end
  if shown then F.hide() else F.show() end
end

-- Internal-only as of 2026-08-26 (command-parity sweep) -- the
-- standalone "mydsl alterform rebuild" alias was removed (no evidence
-- it was ever needed on its own), but "mydsl alterform reload settings"
-- genuinely needs this to apply a freshly-loaded font/config to the
-- live UI, so the function itself stays.
function F.rebuild()
  if F.ui and F.ui.win then pcall(function() F.ui.win:hide() end) end
  F.ui = {}
  F.ensureUI()
  F.render("rebuild")
end

function F.setFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl alterform font <size>"); return end
  F.config.font = size
  F.applyFont()
  F.render("font")
  F.saveSettings()
  ce("font=" .. tostring(size))
end

function F.setSoundEnabled(enabled)
  F.config.soundEnabled = enabled == true
  F.saveSettings()
  ce("Alterform warning sound " .. (F.config.soundEnabled and "enabled." or "disabled."))
end

function F.setTitle(title, silent)
  title = trim(title)
  if title == "" then title = "-= Alterform =-" end
  F.title = title
  if F.ui and F.ui.win and F.ui.win.setTitle then pcall(function() F.ui.win:setTitle(title) end) end
  F.saveSettings()
  if not silent then ce("title=" .. title) end
end

function F.status()
  local cycles, seconds = nil, nil
  if MyDSL.Affects and MyDSL.Affects.getRemaining then
    cycles, seconds = MyDSL.Affects.getRemaining("alterform")
  end
  ce("version=" .. F.version ..
     "; shown=" .. tostring(F.config.shown) ..
     "; font=" .. tostring(F.config.font) ..
     "; active=" .. tostring(cycles ~= nil) ..
     "; cycles=" .. tostring(cycles) ..
     "; seconds=" .. tostring(seconds) ..
     "; settingsLoaded=" .. tostring(F.settingsLoaded) ..
     "; settingsFile=" .. tostring(F.settingsFilePath or F.settingsFile()) ..
     "; reason=" .. tostring(F.lastReason))
end

function F.installHandlers()
  if F.handlersInstalled then return end
  F.handlersInstalled = true
  F.handlers = F.handlers or {}
  -- Same 1/sec shared heartbeat Tick/Live/Affects already ride (see
  -- MyDSL_TickSource.lua's MyDSL.Timers.Slow) -- alterform's countdown
  -- only ever shows whole minutes/hours, so 1/sec is already more than
  -- enough, not a new polling rate being introduced. (Confirmed via grep:
  -- AffectsView raises no dedicated "affects updated" event of its own to
  -- listen for instead -- this heartbeat is the real mechanism.)
  local ok, id = pcall(function()
    return registerAnonymousEventHandler("MyDSL.Timers.Slow", function() F.render("MyDSL.Timers.Slow") end)
  end)
  if ok and id then table.insert(F.handlers, id) end

  local ok, id = pcall(function()
    return registerAnonymousEventHandler("MyDSL.theme.changed", function()
      if not (F.ui and F.ui.panel) then return end
      pcall(function() F.ui.panel:setStyleSheet(stylePanel()) end)
      F.applyFont()
    end)
  end)
  if ok and id then table.insert(F.handlers, id) end
end

function F.installAliases()
  if F.aliasesInstalled then return end
  tempAlias([[^mydsl alterform status$]], [[MyDSL.AlterformView.status()]])
  tempAlias([[^mydsl alterform save$]], [[MyDSL.AlterformView.saveSettings(); MyDSL.AlterformView.status()]])
  tempAlias([[^mydsl alterform reload settings$]], [[MyDSL.AlterformView.loadSettings(); MyDSL.AlterformView.rebuild(); MyDSL.AlterformView.status()]])
  tempAlias([[^mydsl alterform show$]], [[MyDSL.AlterformView.show()]])
  tempAlias([[^mydsl alterform hide$]], [[MyDSL.AlterformView.hide()]])
  tempAlias([[^toggle alterform$]], [[if MyDSL and MyDSL.AlterformView then MyDSL.AlterformView.toggle() end]])
  tempAlias([[^mydsl alterform font (\d+)$]], [[MyDSL.AlterformView.setFont(matches[2])]])
  tempAlias([[^mydsl alterform title (.+)$]], [[MyDSL.AlterformView.setTitle(matches[2])]])
  tempAlias([[^mydsl alterform sound (on|off)$]], [[MyDSL.AlterformView.setSoundEnabled(matches[2] == "on")]])
  F.aliasesInstalled = true
end

function F.boot()
  F.loadSettings()
  F.installAliases()
  F.installHandlers()
  F.ensureUI()
  -- Force-unlock on every boot (script reload), not just first creation.
  -- Fixed 2026-07-12, per Steven's identical complaint about MoonWeather
  -- ("since we locked the window i cant resize... to fit all the text"):
  -- F.ensureUI()'s container-build code (where the lockContainer fix
  -- lives) only runs once -- the container is a Geyser object that
  -- survives script reloads, so anyone who already hit the old
  -- lockContainer("light") bug is stuck locked even after this fix
  -- reloads. Calling unlockContainer() unconditionally here, every boot(),
  -- fixes an already-locked live container immediately without needing a
  -- full profile restart, and is a harmless no-op if it was never locked.
  if F.ui and F.ui.win then
    pcall(function() F.ui.win:unlockContainer() end)
    pcall(function() F.ui.win.exitLabel:hide() end)
    pcall(function() F.ui.win.minimizeLabel:hide() end)
  end
  F.render("boot")
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. F.version) end
end

F.boot()
