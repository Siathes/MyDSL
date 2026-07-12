
--[[=====================================================================
  MyDSL TickView v4C5 QuietBoot
  ----------------------------------------------------------------------
  Display-only tick countdown window.

  Reviewed source:
    - PNP DSL_PNP_Ticktimer.lua:
      vertical gauge, color changes near tick, average tick display,
      warning thresholds at close/warn.
    - Current MyDSL TickView v4C1:
      already reads MyDSL.DB.tick / MyDSL.DB.timers and does not own timing.

  This version keeps the clean architecture:
    TickSource owns timing.
    TickView only renders MyDSL.DB.tick / MyDSL.DB.timers.tick.
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.TickView = MyDSL.TickView or {}

local V = MyDSL.TickView
V.version = "TickView v4C5 QuietBoot"

V.name = V.name or "MyDSL_Tick"
V.title = V.title or "-= Tick =-"

V.config = V.config or {}
V.config.shown = V.config.shown ~= false
V.config.font = tonumber(V.config.font or 9) or 9
V.config.mode = V.config.mode or "compact" -- compact | full
V.config.debug = V.config.debug == true

V.ui = V.ui or {}

local function ce(msg)
  cecho("\n<cyan>[MyDSL.TickView]<reset> " .. tostring(msg) .. "\n")
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

function V.settingsFile()
  return profileDir() .. "/tickview_settings.lua"
end

function V.serializeSettings()
  local out = { "return {\n" }
  table.insert(out, string.format("  savedAt = %q,\n", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(out, string.format("  shown = %s,\n", V.config.shown and "true" or "false"))
  table.insert(out, string.format("  font = %d,\n", tonumber(V.config.font) or 9))
  table.insert(out, string.format("  mode = %q,\n", tostring(V.config.mode or "compact")))
  table.insert(out, string.format("  title = %q,\n", tostring(V.title or "-= Tick =-")))
  table.insert(out, "}\n")
  return table.concat(out)
end

function V.saveSettings()
  ensureDir(profileDir())
  local file = V.settingsFile()
  local f = io.open(file, "w")
  if not f then ce("<red>could not save settings: " .. tostring(file) .. "<reset>"); return false end
  f:write(V.serializeSettings())
  f:close()
  V.settingsLoaded = true
  V.settingsFilePath = file
  return true
end

function V.loadSettings()
  local file = V.settingsFile()
  local f = io.open(file, "r")
  if not f then V.settingsLoaded = false; V.settingsFilePath = file; return false end
  f:close()

  local ok, data = pcall(dofile, file)
  if not ok or type(data) ~= "table" then
    ce("<red>could not load settings: " .. tostring(data) .. "<reset>")
    V.settingsLoaded = false
    V.settingsFilePath = file
    return false
  end

  if data.shown ~= nil then V.config.shown = data.shown == true end
  V.config.font = tonumber(data.font or V.config.font) or V.config.font
  if data.mode == "compact" or data.mode == "full" then V.config.mode = data.mode end
  if data.title and tostring(data.title) ~= "" then V.title = tostring(data.title) end
  V.settingsLoaded = true
  V.settingsFilePath = file
  return true
end


local function tickData()
  local out = {}
  local db = MyDSL and MyDSL.DB or {}
  local t = db.tick or {}
  local timers = db.timers or {}

  if type(t) == "table" then
    for k, v in pairs(t) do out[k] = v end
  end
  if type(timers.tick) == "table" then
    for k, v in pairs(timers.tick) do if out[k] == nil then out[k] = v end end
  end

  return out
end

local function clamp(n, lo, hi)
  n = tonumber(n) or 0
  if n < lo then return lo end
  if n > hi then return hi end
  return n
end

-- Migrated 2026-07-11 to pull from MyDSL.Theme -- was byte-for-byte
-- duplicated in MyDSL_LiveView.lua; both now read the same ThemeEngine
-- preset, so a theme switch reaches both. Falls back to the original
-- literal if ThemeEngine isn't loaded (load-order safety).
local function stylePanel()
  if MyDSL.Theme and MyDSL.Theme.panelCSS then
    return MyDSL.Theme.panelCSS(V.name)
  end
  return [[
    background-color: #0b1013;
    border: 1px solid #33434a;
    border-radius: 8px;
  ]]
end

local function titleColorCSS()
  if MyDSL.Theme then
    local ok, css = pcall(MyDSL.Theme.colorToCSS, MyDSL.Theme.get(V.name, "titleColor"))
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
  ]], color or "#eeeeee", tonumber(size or V.config.font) or 9, weight or "normal")
end

local function styleStrip(color)
  return string.format([[
    background-color: %s;
    border: 0px;
    border-radius: 2px;
  ]], color or "#69f542")
end

function V.palette(rem, running)
  rem = tonumber(rem)
  if not running then
    return {
      name = "wait",
      main = "#77838a",
      bright = "#aab4ba",
      dark = "#3d464c",
      text = "#c7d0d5",
      strip = "#77838a",
    }
  end

  if rem and rem <= 5 then
    return {
      name = "danger",
      main = "#ff4040",
      bright = "#ff8989",
      dark = "#8c1515",
      text = "#ffd1d1",
      strip = "#ff4040",
    }
  elseif rem and rem <= 15 then
    return {
      name = "warn",
      main = "#ffd84a",
      bright = "#fff09b",
      dark = "#8a6d00",
      text = "#fff3bc",
      strip = "#ffd84a",
    }
  end

  return {
    name = "ready",
    main = "#69f542",
    bright = "#c7ff88",
    dark = "#1d7f1d",
    text = "#d9ffd0",
    strip = "#69f542",
  }
end

function V.ensureUI()
  if V.ui.win and V.ui.panel and V.ui.tube and V.ui.fill and V.ui.title and V.ui.seconds then return true end

  local WinClass = Geyser and (Geyser.UserWindow or Geyser.Window)
  if not WinClass then ce("Geyser.UserWindow unavailable"); return false end

  V.ui.win = WinClass:new({
    name = V.name,
    x = "80%", y = "70%",
    width = "7%", height = "18%",
  })

  if V.ui.win.setTitle then pcall(function() V.ui.win:setTitle(V.title) end) end

  V.ui.panel  = Geyser.Label:new({ name = V.name .. "_Panel",  x = 0, y = 0, width = "100%", height = "100%" }, V.ui.win)
  V.ui.title  = Geyser.Label:new({ name = V.name .. "_Title",  x = 0, y = "4%", width = "100%", height = "14%" }, V.ui.win)
  V.ui.tube   = Geyser.Label:new({ name = V.name .. "_Tube",   x = "35%", y = "22%", width = "30%", height = "52%" }, V.ui.win)
  V.ui.fill   = Geyser.Label:new({ name = V.name .. "_Fill",   x = "38%", y = "25%", width = "24%", height = "46%" }, V.ui.win)
  V.ui.seconds= Geyser.Label:new({ name = V.name .. "_Seconds",x = 0, y = "43%", width = "100%", height = "16%" }, V.ui.win)
  V.ui.detail = Geyser.Label:new({ name = V.name .. "_Detail", x = 0, y = "75%", width = "100%", height = "20%" }, V.ui.win)
  V.ui.strip  = Geyser.Label:new({ name = V.name .. "_Strip",  x = "18%", y = "94%", width = "64%", height = "3%" }, V.ui.win)

  V.ui.panel:setStyleSheet(stylePanel())
  V.ui.tube:setStyleSheet(styleTube())
  V.ui.title:setStyleSheet(styleText(V.config.font, titleColorCSS(), "bold"))
  V.ui.seconds:setStyleSheet(styleText(V.config.font + 4, "#eeeeee", "bold"))
  V.ui.detail:setStyleSheet(styleText(math.max(7, V.config.font - 1), "#9ba7ad", "normal"))
  V.ui.strip:setStyleSheet(styleStrip("#77838a"))

  if V.config.shown then V.show() else V.hide() end
  return true
end

function V.applyFont()
  if not V.ui or not V.ui.title then return end
  V.ui.title:setStyleSheet(styleText(V.config.font, titleColorCSS(), "bold"))
  V.ui.seconds:setStyleSheet(styleText(V.config.font + 4, "#eeeeee", "bold"))
  V.ui.detail:setStyleSheet(styleText(math.max(7, V.config.font - 1), "#9ba7ad", "normal"))
end

function V.render(reason)
  if not V.ensureUI() then return end

  -- Real bug, found live 2026-07-12 via screenshot sequence (Steven:
  -- "tick bar 'blank'... opening further and further till it snaps into
  -- center, then back to docked"): the docked window showed nothing at
  -- all (or a near-zero-width sliver), but rendered perfectly the moment
  -- it was manually dragged to a larger floating size. Geyser.Container:
  -- reposition() (confirmed via Mudlet's own bundled GeyserContainer.lua)
  -- is the function that recomputes a window's own geometry and cascades
  -- the recompute down to every percentage-sized child Label -- its own
  -- doc comment says it's "called on window resize events." A real
  -- native drag-resize reliably fires that event; whatever event a
  -- UserWindow settling into its *docked* size fires apparently doesn't,
  -- at least not reliably under this Mudlet version, leaving every
  -- percentage-based child (tube/fill/seconds/detail/strip) stuck with
  -- whatever geometry existed at creation time. Forcing reposition() here
  -- -- every render(), which already fires once/sec off MyDSL.Timers.Slow
  -- -- means the layout self-corrects the moment the window's real size
  -- is available, without requiring the user to manually drag it.
  pcall(function() V.ui.win:reposition() end)

  local t = tickData()
  local rem = tonumber(t.remaining)
  local avg = tonumber(t.average or t.configured) or 40
  local running = t.running == true
  local pct = tonumber(t.percent)

  if not pct and rem and avg > 0 then pct = rem / avg end
  pct = clamp(pct or 0, 0, 1)

  local pal = V.palette(rem, running)
  local fillH = math.floor(46 * pct + 0.5)
  if fillH < 2 and pct > 0 then fillH = 2 end
  local fillY = 25 + (46 - fillH)

  pcall(function()
    V.ui.fill:move("38%", tostring(fillY) .. "%")
    V.ui.fill:resize("24%", tostring(fillH) .. "%")
  end)

  V.ui.fill:setStyleSheet(styleFill(pal.bright, pal.main, pal.dark))
  V.ui.strip:setStyleSheet(styleStrip(pal.strip))

  local remText = rem and (tostring(math.floor(rem + 0.5)) .. "s") or "--"
  local title = running and "TICK" or "WAIT"

  local detail
  if V.config.mode == "full" then
    detail = string.format("avg %.1fs<br>#%s<br>%s", avg, tostring(t.ticks or 0), tostring(t.source or "none"))
  else
    detail = string.format("avg %.1fs<br>#%s", avg, tostring(t.ticks or 0))
  end

  V.ui.title:echo("<center>" .. title .. "</center>")
  V.ui.seconds:setStyleSheet(styleText(V.config.font + 4, pal.text, "bold"))
  V.ui.seconds:echo("<center>" .. remText .. "</center>")
  V.ui.detail:echo("<center>" .. detail .. "</center>")

  V.lastReason = reason or "render"
end

-- Fixed 2026-07-11, code-review finding: V.config.shown used to be the ONLY
-- visibility flag toggle() consulted, but it's independently persisted (its
-- own settings file, V.saveSettings()/loadSettings()) from WindowRegistry's
-- real state (MyDSL.Windows.registry["MyDSL_Tick"].visible, saved to a
-- SEPARATE state file and applied directly to the underlying Geyser object
-- by MyDSL.Windows.loadState() -- confirmed this bypasses V.show()/hide()
-- entirely, since MyDSL_Tick is a real WindowRegistry entry). Two
-- independently-persisted flags for one window can drift apart across a
-- reload. Now writes into the registry too (not just its own settings
-- file), so a later "toggle ticktimer" sees the same state WindowRegistry
-- itself last set, not a possibly-stale local copy.
local function syncRegistryVisible(visible)
  local entry = MyDSL.Windows and MyDSL.Windows.registry and MyDSL.Windows.registry["MyDSL_Tick"]
  if entry then entry.visible = visible end
end

function V.show()
  V.config.shown = true
  syncRegistryVisible(true)
  if V.ui and V.ui.win then pcall(function() V.ui.win:show() end) end
  V.render("show")
  V.saveSettings()
end

function V.hide()
  V.config.shown = false
  syncRegistryVisible(false)
  if V.ui and V.ui.win then pcall(function() V.ui.win:hide() end) end
  V.saveSettings()
end

-- V.toggle() -- added 2026-07-11, command-surface retrofit (docs/TODO.md
-- "OPEN — Command-surface retrofit"). Wires PNP's real bare "toggle
-- <module>" command using PNP's own module name for the tick timer
-- ("ticktimer", confirmed via DSL_PNP_Ticktimer.lua's
-- `dslpnp.toggle("ticktimer", ...)` call). Prefers WindowRegistry's real
-- state over the local flag when both exist, since WindowRegistry is the
-- one other code (loadState() at startup, any other module) can actually
-- change without going through V.show()/hide().
function V.toggle()
  local entry = MyDSL.Windows and MyDSL.Windows.registry and MyDSL.Windows.registry["MyDSL_Tick"]
  local shown = entry and entry.visible
  if shown == nil then shown = V.config.shown end
  if shown then V.hide() else V.show() end
end

function V.rebuild()
  if V.ui and V.ui.win then pcall(function() V.ui.win:hide() end) end
  V.ui = {}
  V.ensureUI()
  V.render("rebuild")
end

function V.setFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl tickview font <size>"); return end
  V.config.font = size
  V.applyFont()
  V.render("font")
  V.saveSettings()
  ce("font=" .. tostring(size))
end

function V.setMode(mode)
  mode = trim(mode):lower()
  if mode ~= "compact" and mode ~= "full" then
    ce("usage: mydsl tickview mode compact|full")
    return
  end
  V.config.mode = mode
  V.render("mode")
  V.saveSettings()
  ce("mode=" .. mode)
end

function V.setTitle(title, silent)
  title = trim(title)
  if title == "" then title = "-= Tick =-" end
  V.title = title
  if V.ui and V.ui.win and V.ui.win.setTitle then pcall(function() V.ui.win:setTitle(title) end) end
  V.saveSettings()
  if not silent then ce("title=" .. title) end
end

function V.status()
  local t = tickData()
  ce("version=" .. V.version ..
     "; shown=" .. tostring(V.config.shown) ..
     "; mode=" .. tostring(V.config.mode) ..
     "; font=" .. tostring(V.config.font) ..
     "; tick=" .. tostring(t.remaining) ..
     "; avg=" .. tostring(t.average) ..
     "; running=" .. tostring(t.running) ..
     "; source=" .. tostring(t.source) ..
     "; settingsLoaded=" .. tostring(V.settingsLoaded) ..
     "; settingsFile=" .. tostring(V.settingsFilePath or V.settingsFile()) ..
     "; reason=" .. tostring(V.lastReason))
end

function V.installHandlers()
  if V.handlersInstalled then return end
  V.handlersInstalled = true
  V.handlers = V.handlers or {}
  for _, ev in ipairs({ "MyDSL.Tick.Updated", "MyDSL.Timers.Updated" }) do
    local ok, id = pcall(function()
      return registerAnonymousEventHandler(ev, function() V.render(ev) end)
    end)
    if ok and id then table.insert(V.handlers, id) end
  end

  -- Re-apply panel/title colors when the active theme switches.
  -- Added 2026-07-11 alongside named ThemeEngine presets.
  local ok, id = pcall(function()
    return registerAnonymousEventHandler("MyDSL.theme.changed", function()
      if not (V.ui and V.ui.panel) then return end
      pcall(function() V.ui.panel:setStyleSheet(stylePanel()) end)
      V.applyFont()
    end)
  end)
  if ok and id then table.insert(V.handlers, id) end
end

function V.installAliases()
  if V.aliasesInstalled then return end
  tempAlias([[^mydsl tickview status$]], [[MyDSL.TickView.status()]])
  tempAlias([[^mydsl tickview save$]], [[MyDSL.TickView.saveSettings(); MyDSL.TickView.status()]])
  tempAlias([[^mydsl tickview reload settings$]], [[MyDSL.TickView.loadSettings(); MyDSL.TickView.rebuild(); MyDSL.TickView.status()]])
  tempAlias([[^mydsl tickview show$]], [[MyDSL.TickView.show()]])
  tempAlias([[^mydsl tickview hide$]], [[MyDSL.TickView.hide()]])
  tempAlias([[^toggle ticktimer$]], [[if MyDSL and MyDSL.TickView then MyDSL.TickView.toggle() end]])
  tempAlias([[^mydsl tickview rebuild$]], [[MyDSL.TickView.rebuild()]])
  tempAlias([[^mydsl tickview font (\d+)$]], [[MyDSL.TickView.setFont(matches[2])]])
  tempAlias([[^mydsl tickview mode (compact|full)$]], [[MyDSL.TickView.setMode(matches[2])]])
  tempAlias([[^mydsl tickview title (.+)$]], [[MyDSL.TickView.setTitle(matches[2])]])
  V.aliasesInstalled = true
end

function V.boot()
  V.loadSettings()
  V.installAliases()
  V.installHandlers()
  V.ensureUI()
  V.render("boot")
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. V.version) end
end

V.boot()
