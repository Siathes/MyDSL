--[[=====================================================================
  MyDSL.ChatWrapper v4C11 QuietWindowSetup
  ----------------------------------------------------------------------
  Creates/configures the MyDSL-owned chat tab console using the proven
  Emberline creation model:

    demonnic.chat = emco:new(config, MyDSL_Chat_UserWindow)

  As of 2026-07-17, "emco" here is MyDSL.EMCO -- the real EMCO class
  ported directly into MyDSL_EMCO.lua (Steven: "fold emco into mydsl...
  cannibalize emco like we did pnp"), not the separate EMCOChat package.
  A fresh-install test came back "missing emco" -- confirmed the whole
  chat window depended on a package this project never actually captured
  anywhere. This file's own logic/API surface is unchanged; only
  requireEMCO() (below) changed, from require("EMCOChat...") to reading
  MyDSL.EMCO directly.

  v4C4 fix:
    - v4C3 created correctly, but append() failed in EMCOChat/emco.lua with:
        bad argument #2 to 'format' (string expected, got nil)
    - This version keeps the EMCO command line disabled and restores timestamp as an explicit option
      from the created object. The Chat window is display-only, and existing
      triggers still use:
        demonnic.chat:append("<tab>")

  v4C5 fix:
    - WindowCore stores the Geyser.UserWindow object as rec.win.
    - v4C4 getWindowObject() did not check rec.win, so EMCO could be parented
      to the WindowCore record table instead of the real UserWindow.
    - This version returns entry.win first, then existing aliases.

  Design:
    - Creates/recreates demonnic.chat inside MyDSL_Chat UserWindow.
    - Keeps normal EMCO append API.
    - Does NOT install chat capture triggers.
    - Does NOT route channels.
    - Does NOT disable stock EMCO triggers, EXCEPT "emco update" (2026-07-05:
      confirmed live self-uninstaller, disabled as a safety exception -- see
      disableEmcoUpdateAlias()).
    - Does NOT use Geyser.changeContainer.
    - Does NOT dock/move EMCOPrebuiltChatContainer.
    - Does NOT use EMCO mapTab.
    - Uses tabs:
        All, Local, City, OOC, Tells, Group
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.Chat = MyDSL.Chat or {}

local C = MyDSL.Chat
C.version = "ChatWrapper v4C11 QuietWindowSetup"

-- _handlers holds IDs from registerAnonymousEventHandler; safe-reload
-- kills a leftover handler from a previous load before re-registering.
C._handlers = C._handlers or {}
if C._handlers.characterIdentified then
  pcall(killAnonymousEventHandler, C._handlers.characterIdentified)
  C._handlers.characterIdentified = nil
end

C.config = C.config or {}
C.config.windowId = C.config.windowId or "Chat"
C.config.windowName = C.config.windowName or "MyDSL_Chat"
C.config.title = C.config.title or "Chat"
C.config.fontSize = tonumber(C.config.fontSize or 9) or 9
C.config.autoWrap = C.config.autoWrap ~= false
C.config.wrapAt = tonumber(C.config.wrapAt or 120) or 120
C.config.timestamp = C.config.timestamp == true
C.config.timestampFormat = C.config.timestampFormat or "HH:mm:ss"
C.config.timestampFGColor = C.config.timestampFGColor or "grey"
C.config.timestampBGColor = C.config.timestampBGColor or "black"
C.config.debug = C.config.debug == true
C.config.rebuildOnLoad = C.config.rebuildOnLoad ~= false
C.config.tabs = C.config.tabs or { "All", "Local", "City", "OOC", "Tells", "Group" }

C.state = C.state or {
  windowReady = false,
  createdEmco = false,
  replacedExisting = false,
  lastError = nil,
  lastAction = nil,
}

C.aliasesInstalled = C.aliasesInstalled or false

local function ce(msg)
  cecho("\n<cyan>[MyDSL.Chat]<reset> " .. tostring(msg) .. "\n")
end

local function trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function err(msg)
  C.state.lastError = tostring(msg or "")
  ce("<red>" .. C.state.lastError .. "<reset>")
  return false
end

local function tabListString()
  return table.concat(C.config.tabs or {}, ",")
end

local function profileDir()
  local root = getMudletHomeDir and getMudletHomeDir() or "."
  return root .. "/MyDSL"
end

local function ensureDir(path)
  if lfs and lfs.mkdir then pcall(lfs.mkdir, path) end
  if os and os.execute then pcall(os.execute, "mkdir -p " .. string.format("%q", path)) end
end

-- Character-bound as of 2026-07-07 (was a single shared file) -- matches
-- the project's recorded decision that all settings should be
-- character-bound, and the same charName()/safeFileName() pattern already
-- used by MyDSL_TargetView.lua/MyDSL_AffectsView.lua.
local function charName()
  if gmcp and gmcp.login_data and gmcp.login_data.name and gmcp.login_data.name ~= "" then
    return tostring(gmcp.login_data.name)
  end
  if MyCore and MyCore.getChar then
    local ok, name = pcall(MyCore.getChar)
    if ok and name and name ~= "" then return tostring(name) end
  end
  return "Unknown"
end

local function safeFileName(s)
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

function C.settingsFile()
  return profileDir() .. "/chat_settings_" .. safeFileName(charName()) .. ".lua"
end

function C.serializeSettings()
  local out = { "return {\n" }
  table.insert(out, string.format("  savedAt = %q,\n", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(out, string.format("  fontSize = %d,\n", tonumber(C.config.fontSize) or 9))
  table.insert(out, string.format("  autoWrap = %s,\n", C.config.autoWrap and "true" or "false"))
  table.insert(out, string.format("  wrapAt = %d,\n", tonumber(C.config.wrapAt) or 120))
  table.insert(out, string.format("  timestamp = %s,\n", C.config.timestamp and "true" or "false"))
  table.insert(out, string.format("  timestampFormat = %q,\n", tostring(C.config.timestampFormat or "HH:mm:ss")))
  table.insert(out, string.format("  timestampFGColor = %q,\n", tostring(C.config.timestampFGColor or "grey")))
  table.insert(out, string.format("  timestampBGColor = %q,\n", tostring(C.config.timestampBGColor or "black")))
  table.insert(out, "}\n")
  return table.concat(out)
end

function C.saveSettings()
  ensureDir(profileDir())
  local file = C.settingsFile()
  local f = io.open(file, "w")
  if not f then err("could not save settings: " .. tostring(file)); return false end
  f:write(C.serializeSettings())
  f:close()
  C.state.settingsFile = file
  return true
end

function C.loadSettings()
  local file = C.settingsFile()
  local f = io.open(file, "r")
  if not f then C.state.settingsFile = file; C.state.settingsLoaded = false; return false end
  f:close()

  local ok, data = pcall(dofile, file)
  if not ok or type(data) ~= "table" then
    err("could not load settings: " .. tostring(data))
    C.state.settingsLoaded = false
    return false
  end

  C.config.fontSize = tonumber(data.fontSize or C.config.fontSize) or C.config.fontSize
  if data.autoWrap ~= nil then C.config.autoWrap = data.autoWrap == true end
  C.config.wrapAt = tonumber(data.wrapAt or C.config.wrapAt) or C.config.wrapAt
  if data.timestamp ~= nil then C.config.timestamp = data.timestamp == true end
  C.config.timestampFormat = tostring(data.timestampFormat or C.config.timestampFormat or "HH:mm:ss")
  C.config.timestampFGColor = tostring(data.timestampFGColor or C.config.timestampFGColor or "grey")
  C.config.timestampBGColor = tostring(data.timestampBGColor or C.config.timestampBGColor or "black")

  C.state.settingsFile = file
  C.state.settingsLoaded = true
  return true
end


-- requireEMCO() -- rewritten 2026-07-17, per Steven ("fold emco into
-- mydsl... clean rip... cannibalize emco like we did pnp"). Real blocker
-- found live: a fresh-install test came back "missing emco" -- this used
-- to require() the separate EMCOChat package, an external dependency
-- never actually captured anywhere in this project. EMCO's real class
-- (MIT licensed) is now ported directly into MyDSL_EMCO.lua (dofile()'d
-- earlier in the load order, exposes itself as MyDSL.EMCO) -- no more
-- external package dependency for chat at all. Kept the same function
-- name/signature/call sites below unchanged so nothing else in this file
-- needed to change.
local function requireEMCO()
  if MyDSL and MyDSL.EMCO then
    C._emcoClass = MyDSL.EMCO
    return true
  end
  return err("MyDSL.EMCO not found -- MyDSL_EMCO.lua must load before MyDSL_ChatWrapper.lua.")
end

local function haveWindowCore()
  return MyDSL and MyDSL.Windows and type(MyDSL.Windows.ensure) == "function"
end

local function getWindowEntry()
  -- WindowRegistry canonical key is "MyDSL_Chat" (C.config.windowName).
  -- Old code tried 4 keys starting with reg["Chat"] (via windowId) which is
  -- always nil — registry never uses the short name. Two keys max now.
  local reg = MyDSL.Windows and MyDSL.Windows.registry
  if not reg then return nil end
  return reg[C.config.windowName] or reg["MyDSL_Chat"]
end

local function getWindowObject()
  local entry = getWindowEntry()
  if type(entry) == "table" then
    return entry.obj or entry.win or entry.window or entry.userWindow or entry.container or entry
  end
  return C.window
end

function C.ensureWindow()
  if haveWindowCore() then
    local ok = pcall(function()
      MyDSL.Windows.ensure(C.config.windowName)
      -- MyDSL.Windows.setFont/setTitle were dead references -- neither
      -- function has ever existed on WindowRegistry, so both guarded
      -- calls silently no-op'd forever. Fixed 2026-07-11, per Steven
      -- ("fix all window titles/names") -- call setTitle directly on the
      -- real window object instead, same pattern every other module uses.
    end)

    if ok then
      local obj = getWindowObject()
      if obj then
        C.window = obj
        if obj.setTitle then pcall(function() obj:setTitle("-= Chat =-") end) end
        C.state.windowReady = true
        return true
      end
    end
  end

  if C.window then
    C.state.windowReady = true
    return true
  end

  if not (Geyser and Geyser.UserWindow) then
    return err("Geyser.UserWindow unavailable and WindowCore did not provide Chat window.")
  end

  local ok, win = pcall(function()
    return Geyser.UserWindow:new({
      name = C.config.windowName,
      titleText = C.config.title,
      x = "78%",
      y = "0%",
      width = "22%",
      height = "46%",
    })
  end)

  if not ok or not win then
    return err("failed to create MyDSL_Chat UserWindow: " .. tostring(win))
  end

  C.window = win
  C.state.windowReady = true
  return true
end

function C.hideOldPrebuilt()
  local root = Geyser and Geyser.windowList and Geyser.windowList.EMCOPrebuiltChatContainer
  pcall(function() if root and root.hide then root:hide() end end)
end

function C.createInWindow()
  C.state.lastError = nil

  if not requireEMCO() then return false end
  if not C.ensureWindow() then return false end

  demonnic = demonnic or {}

  local old = demonnic.chat
  if old and old ~= C.emco then
    C.oldChat = old
    C.state.replacedExisting = true
    pcall(function() if old.hide then old:hide() end end)
  end

  C.hideOldPrebuilt()

  local emcoClass = C._emcoClass
  local win = getWindowObject() or C.window
  if not win then return err("no MyDSL Chat window object available") end

  local cfg = {
    name = "MyDSL_EMCO_Chat",
    x = 0,
    y = 0,
    width = "100%",
    height = "100%",
    consoles = C.config.tabs,

    allTab = true,
    allTabName = "All",
    allTabExclusions = {},

    -- Safe/minimal display-only settings. These avoid EMCO optional layers
    -- that can call string.format with nil internals in this version.
    commandLine = false,
    timestamp = C.config.timestamp,
    timestampFormat = C.config.timestampFormat,
    customTimestampColor = true,
    timestampFGColor = C.config.timestampFGColor,
    timestampBGColor = C.config.timestampBGColor,
    mapTab = false,

    blankLine = false,
    blink = false,
    bufferSize = 10000,
    fontSize = C.config.fontSize,
    autoWrap = C.config.autoWrap,
    wrapAt = C.config.wrapAt,

    consoleColor = "black",
    activeTabCSS = "background-color: black; border-color: green; border-style: solid; border-width: 2px;",
    inactiveTabCSS = "background-color: black; border-color: grey; border-style: solid; border-width: 1px;",
    activeTabFGColor = "green",
    inactiveTabFGColor = "grey",
  }

  local ok, obj = pcall(function()
    if type(emcoClass) == "table" and type(emcoClass.new) == "function" then
      return emcoClass:new(cfg, win)
    elseif type(emcoClass) == "function" then
      return emcoClass(cfg, win)
    end
    return nil
  end)

  if not ok or not obj then
    return err("failed to create MyDSL-owned EMCOChat object: " .. tostring(obj))
  end

  demonnic.chat = obj
  C.emco = obj
  C.state.createdEmco = true
  C.state.lastAction = "createInWindow"

  C.resize()
  C.applyFont()
  C.applyWrap()
  C.applyTimestamp()

  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("created demonnic.chat inside MyDSL_Chat with tabs: " .. tabListString()) end
  return true
end

function C.resize()
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then return false end

  pcall(function() if ch.move then ch:move(0, 0) end end)
  pcall(function() if ch.resize then ch:resize("100%", "100%") end end)
  pcall(function() if ch.reposition then ch:reposition() end end)
  if C.applyWrap then C.applyWrap() end

  return true
end

function C.revive(reason)
  C.ensureWindow()

  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then
    C.state.lastAction = "revive-create:" .. tostring(reason or "")
    return C.createInWindow()
  end

  pcall(function() if C.window and C.window.show then C.window:show() end end)
  pcall(function() if ch.show then ch:show() end end)
  C.resize()
  C.applyFont()
  C.applyWrap()
  C.applyTimestamp()

  C.state.lastAction = "revive:" .. tostring(reason or "")
  return true
end

function C.startupSync()
  -- UserWindow layout restoration can finish after scripts load. Creating EMCO
  -- too early can leave its child consoles visually blank/behind until manual
  -- rebuild. These delayed passes recreate once after layout settles, then only
  -- resize/revive.
  local delays = { 0.4, 1.5, 3.5 }
  for _, delay in ipairs(delays) do
    tempTimer(delay, function()
      if not (MyDSL and MyDSL.Chat) then return end
      if not C.emco or not (demonnic and demonnic.chat) then
        C.createInWindow()
      elseif delay >= 1.5 then
        C.revive("startup-" .. tostring(delay))
      end
    end)
  end

  -- Final check after layout has almost certainly restored.
  -- Only force-rebuild if something is genuinely broken; otherwise revive()
  -- (gentle resize/reposition — no content wipe). Old code always rebuilt,
  -- wiping any chat text that arrived in the first 5 seconds of the session.
  tempTimer(5.0, function()
    if not MyDSL or not MyDSL.Chat then return end
    if not C.emco or not (demonnic and demonnic.chat) or not C.state.windowReady then
      C.createInWindow()
      C.state.lastAction = "startup-final-guard-create"
    else
      C.revive("startup-5s-check")
    end
  end)

  -- Second-chance guard, added 2026-07-16 per Steven ("no chat is being
  -- captured? had to use mydsl chat rebuild"). The 5s guard above assumes
  -- layout restoration always finishes within 5 seconds; if it doesn't
  -- (system under heavier load, more windows to restore, etc.), nothing
  -- after that ever retries, and chat stays silently un-routed until a
  -- manual "mydsl chat rebuild". One more check, far enough out that a
  -- slow boot has every reasonable chance to have finished by then.
  tempTimer(15.0, function()
    if not MyDSL or not MyDSL.Chat then return end
    if not C.emco or not (demonnic and demonnic.chat) or not C.state.windowReady then
      C.createInWindow()
      C.state.lastAction = "startup-15s-guard-create"
    end
  end)
end

function C.applyFont()
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then return false end

  local size = tonumber(C.config.fontSize) or 9
  pcall(function() if ch.setFontSize then ch:setFontSize(size) end end)

  for _, key in ipairs({ "mc", "consoles", "tabs" }) do
    local t = ch[key]
    if type(t) == "table" then
      for _, obj in pairs(t) do
        pcall(function()
          if type(obj) == "table" and obj.setFontSize then
            obj:setFontSize(size)
          elseif type(obj) == "table" and obj.name and setMiniConsoleFontSize then
            setMiniConsoleFontSize(obj.name, size)
          elseif type(obj) == "string" and setMiniConsoleFontSize then
            setMiniConsoleFontSize(obj, size)
          end
        end)
      end
    end
  end

  return true
end

function C.applyWrap()
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then return false end

  if C.config.autoWrap then
    pcall(function() if ch.enableAutoWrap then ch:enableAutoWrap() end end)
  else
    pcall(function() if ch.disableAutoWrap then ch:disableAutoWrap() end end)
    pcall(function() if ch.setWrap then ch:setWrap(C.config.wrapAt) end end)
  end

  -- Also touch child consoles directly, because some EMCO/Mudlet builds
  -- require wrap applied after resize/create.
  if type(ch.mc) == "table" then
    for _, obj in pairs(ch.mc) do
      pcall(function()
        if C.config.autoWrap and obj.enableAutoWrap then obj:enableAutoWrap()
        elseif obj.setWrap then obj:setWrap(C.config.wrapAt) end
      end)
    end
  end

  return true
end

function C.applyTimestamp()
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then return false end

  pcall(function() if ch.setTimestampFormat then ch:setTimestampFormat(C.config.timestampFormat) end end)
  pcall(function() if ch.setTimestampFGColor then ch:setTimestampFGColor(C.config.timestampFGColor) end end)
  pcall(function() if ch.setTimestampBGColor then ch:setTimestampBGColor(C.config.timestampBGColor) end end)

  if C.config.timestamp then
    pcall(function() if ch.enableTimestamp then ch:enableTimestamp() end end)
  else
    pcall(function() if ch.disableTimestamp then ch:disableTimestamp() end end)
  end

  return true
end

function C.setTimestamp(mode)
  mode = trim(mode or ""):lower()
  if mode == "on" or mode == "true" or mode == "yes" or mode == "1" then
    C.config.timestamp = true
  elseif mode == "off" or mode == "false" or mode == "no" or mode == "0" then
    C.config.timestamp = false
  else
    ce("usage: mydsl chat timestamp on|off")
    return false
  end

  C.applyTimestamp()
  C.saveSettings()
  ce("timestamp=" .. tostring(C.config.timestamp))
  return true
end

function C.setTimestampFormat(fmt)
  fmt = trim(fmt or "")
  if fmt == "" then fmt = "HH:mm:ss" end
  C.config.timestampFormat = fmt
  C.applyTimestamp()
  C.saveSettings()
  ce("timestampFormat=" .. tostring(fmt))
  return true
end

function C.setWrap(mode, amount)
  mode = trim(mode or "")
  amount = tonumber(amount)

  if mode == "auto" or mode == "on" then
    C.config.autoWrap = true
  elseif mode == "fixed" or mode == "manual" or mode == "off" then
    C.config.autoWrap = false
    if amount then C.config.wrapAt = amount end
  elseif tonumber(mode) then
    C.config.autoWrap = false
    C.config.wrapAt = tonumber(mode)
  else
    ce("usage: mydsl chat wrap auto | mydsl chat wrap fixed <columns> | mydsl chat wrap <columns>")
    return false
  end

  C.applyWrap()
  C.resize()
  C.saveSettings()
  ce("wrap=" .. (C.config.autoWrap and "auto" or ("fixed " .. tostring(C.config.wrapAt))))
  return true
end

function C.status()
  local ch = C.emco or (demonnic and demonnic.chat)
  local tabCount = 0
  if type(ch) == "table" then
    local src = ch.consoles or ch.mc or ch.tabs
    if type(src) == "table" then
      for _ in pairs(src) do tabCount = tabCount + 1 end
    end
  end

  ce("version=" .. C.version ..
     "; demonnic.chat=" .. tostring(ch ~= nil) ..
     "; windowReady=" .. tostring(C.state.windowReady) ..
     "; createdEmco=" .. tostring(C.state.createdEmco) ..
     "; replacedExisting=" .. tostring(C.state.replacedExisting) ..
     "; tabs=" .. tostring(tabCount) ..
     "; tabList=" .. tabListString() ..
     "; font=" .. tostring(C.config.fontSize) ..
     "; wrap=" .. (C.config.autoWrap and "auto" or tostring(C.config.wrapAt)) ..
     "; timestamp=" .. tostring(C.config.timestamp) ..
     "; timestampFormat=" .. tostring(C.config.timestampFormat) ..
     "; settingsLoaded=" .. tostring(C.state.settingsLoaded) ..
     "; settingsFile=" .. tostring(C.state.settingsFile or C.settingsFile()) ..
     "; lastAction=" .. tostring(C.state.lastAction or "nil") ..
     "; lastError=" .. tostring(C.state.lastError or "nil"))
end

function C.show()
  C.ensureWindow()
  if MyDSL and MyDSL.Windows and MyDSL.Windows.show then pcall(MyDSL.Windows.show, C.config.windowId) end
  pcall(function() if C.window and C.window.show then C.window:show() end end)
  C.resize()
end

function C.hide()
  if MyDSL and MyDSL.Windows and MyDSL.Windows.hide then pcall(MyDSL.Windows.hide, C.config.windowId) end
  pcall(function() if C.window and C.window.hide then C.window:hide() end end)
end

function C.clear()
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat to clear"); return end
  pcall(function() if ch.clearAll then ch:clearAll() end end)
  pcall(function() if ch.clear then ch:clear() end end)
  ce("clear requested")
end

-- Numeric size here maps to EMCO's "fontSize" verb, not its "font" verb
-- (which takes a font *name*) -- native `emco fontSize <n>` calls the same
-- ch:setFontSize() on this same live demonnic.chat object (MyDSL reassigns
-- that global at createInWindow(), so the native alias's fresh per-call
-- `demonnic.chat` read hits MyDSL's instance too). Kept as its own entry
-- point anyway since this one also persists to MyDSL's own settings file,
-- which `emco fontSize` never touches -- don't "fix" this into calling a
-- differently-named EMCO method, they're already calling the same one.
function C.setFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl chat font <size>"); return end
  C.config.fontSize = size
  C.applyFont()
  C.saveSettings()
  if not C.state or C.state.userCommand == true then ce("font=" .. tostring(size)) end
end

function C.rebuild()
  C.createInWindow()
end


function C.echoTest(tab, msg)
  tab = trim(tab or "OOC")
  msg = tostring(msg or "EMCO direct echo test.")
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end

  local ok, why = pcall(function()
    if ch.cecho then
      ch:cecho(tab, "<cyan>" .. msg .. "\n")
    elseif ch.echo then
      ch:echo(tab, msg .. "\n")
    end
  end)

  if not ok then
    err("echo failed: " .. tostring(why))
    return
  end

  ce("direct echo sent to " .. tab)
end

function C.test(tab, msg)
  tab = trim(tab or "All")
  msg = tostring(msg or "MyDSL ChatWrapper v4C4 test line.")
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end

  echo("\n" .. msg)
  selectCurrentLine()
  copy()

  local ok, why = pcall(function()
    ch:append(tab)
  end)

  if not ok then
    err("append failed: " .. tostring(why))
    return
  end

  ce("test appended to " .. tab)
end

-- ---- EMCO-vocabulary handlers, ported 2026-07-17 -----------------------
-- Cannibalized from EMCOChat's own native alias tree (per Steven, "clean
-- rip... cannibalize emco like we did pnp"), adapted to operate on
-- MyDSL's real chat object/window instead of demonnic.container (the old
-- native Adjustable.Container this project has hidden forever -- see
-- C.hideOldPrebuilt()). Real EMCOChat source (for comparison):
-- ~/Downloads/EMCO-2.9.0.zip, src/aliases/EMCO/*.lua. Original aliases
-- read demonnic.helpers.echo/setConfig and demonnic.config -- none of
-- that "prebuilt EMCO" convenience layer exists here (it was part of the
-- separate package's own Code.lua bootstrap, never MyDSL's), so each
-- handler below calls the real EMCO instance methods directly instead.
-- Not ported: "emco update" (self-uninstaller, explicitly excluded per
-- CLAUDE.md), "emco lock"/"emco unlock" (lockContainer()/
-- unlockContainer() are an Adjustable.Container-specific API this
-- project has already been burned by misapplying to the wrong object
-- type twice -- MyDSL_AlterformView.lua/MyDSL_MoonWeather.lua -- not
-- risking a third time on an unconfirmed Geyser.UserWindow equivalent).

function C.addTab(tabName, pos)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  if table.contains(ch.consoles, tabName) then
    ce(tostring(tabName) .. " already exists!")
    return
  end
  ch:addTab(tabName, tonumber(pos))
  ce("added tab: " .. tostring(tabName))
end

function C.remTab(tabName)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  if not table.contains(ch.consoles, tabName) then
    ce(tostring(tabName) .. " does not exist to remove. Current tabs: " .. table.concat(ch.consoles, ", "))
    return
  end
  ch:removeTab(tabName)
  ce("removed tab: " .. tostring(tabName))
end

function C.addGag(pattern)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  if ch:addGag(pattern) then
    ce("Successfully added '" .. tostring(pattern) .. "' as a gag pattern")
  else
    ce("Unable to add '" .. tostring(pattern) .. "' as a gag pattern, this is usually because it's already added.")
  end
end

function C.removeGag(pattern)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  if ch:removeGag(pattern) then
    ce("Successfully removed '" .. tostring(pattern) .. "' as a gag pattern")
  else
    ce("Unable to remove '" .. tostring(pattern) .. "' as a gag pattern, this is usually because it hasn't been set.")
  end
end

function C.gagList()
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  local patterns = {}
  for pattern in pairs(ch.gags or {}) do patterns[#patterns + 1] = pattern end
  table.sort(patterns)
  ce("Gagging report (Lua patterns, not regex):")
  if #patterns == 0 then
    ce("  (none)")
  else
    for _, pattern in ipairs(patterns) do ce("  " .. pattern) end
  end
end

function C.addNotifyTab(tabName)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  local ok = ch:addNotifyTab(tabName)
  if ok then
    ce("Enabled OS notifications for tab " .. tostring(tabName))
  elseif ok == false then
    ce("Tab " .. tostring(tabName) .. " already had notifications enabled!")
  else
    ce("Tab " .. tostring(tabName) .. " does not exist")
  end
end

function C.removeNotifyTab(tabName)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  local ok = ch:removeNotifyTab(tabName)
  if ok then
    ce("Disabled OS notifications for tab " .. tostring(tabName))
  elseif ok == false then
    ce("Tab " .. tostring(tabName) .. " already had notifications disabled!")
  else
    ce("Tab " .. tostring(tabName) .. " does not exist")
  end
end

function C.setBlink(value)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  if ch:fuzzyBoolean(value) then ch:enableBlink() else ch:disableBlink() end
  ce("blink=" .. tostring(ch:fuzzyBoolean(value)))
end

function C.setBlankLine(value)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  if ch:fuzzyBoolean(value) then ch:enableBlankLine() else ch:disableBlankLine() end
  ce("blankLine=" .. tostring(ch:fuzzyBoolean(value)))
end

-- "emco color <option> <value>" -- the original read/wrote a shared
-- demonnic.config table that EMCO's constructor consulted for defaults;
-- MyDSL's chat window is already built (createInWindow()'s own explicit
-- cfg table), so mutating a config table nothing re-reads would silently
-- do nothing. Calls the matching live EMCO setter directly instead.
local EMCO_COLOR_SETTERS = {
  activeBorder = "setActiveTabCSS",
  activeColor = "setActiveTabBGColor",
  inactiveColor = "setInactiveTabBGColor",
  activeText = "setActiveTabFGColor",
  inactiveText = "setInactiveTabFGColor",
  background = "setConsoleColor",
  windowBorder = "setTabBoxCSS",
  title = nil, -- not a color; handled by "emco title" separately
}

function C.setColor(option, value)
  local ch = C.emco or (demonnic and demonnic.chat)
  if not ch then ce("no demonnic.chat"); return end
  local setter = EMCO_COLOR_SETTERS[option]
  if not setter or not ch[setter] then
    local names = {}
    for k in pairs(EMCO_COLOR_SETTERS) do if EMCO_COLOR_SETTERS[k] then names[#names+1] = k end
    end
    table.sort(names)
    ce("Unknown color option '" .. tostring(option) .. "'. Valid options: " .. table.concat(names, ", "))
    return
  end
  ch[setter](ch, value)
  ce("Set color for " .. option .. " to " .. tostring(value))
end

function C.installAliases()
  if C.aliasesInstalled then return end

  tempAlias([[^mydsl chat status$]], [[MyDSL.Chat.status()]])
  tempAlias([[^mydsl chat save$]], [[MyDSL.Chat.saveSettings(); MyDSL.Chat.status()]])
  tempAlias([[^mydsl chat reload settings$]], [[MyDSL.Chat.loadSettings(); MyDSL.Chat.applyFont(); MyDSL.Chat.applyWrap(); MyDSL.Chat.applyTimestamp(); MyDSL.Chat.status()]])
  -- Not a duplicate of native `emco show`/`hide`: those toggle
  -- demonnic.container, the original Adjustable.Container that
  -- C.hideOldPrebuilt() hides forever -- MyDSL's real chat lives in its
  -- own C.window (WindowRegistry-integrated) instead. See docs/TODO.md's
  -- closed "emco <verb>" item for the full trace.
  tempAlias([[^mydsl chat show$]], [[MyDSL.Chat.show()]])
  tempAlias([[^mydsl chat hide$]], [[MyDSL.Chat.hide()]])
  tempAlias([[^mydsl chat clear$]], [[MyDSL.Chat.clear()]])
  tempAlias([[^mydsl chat font (\d+)$]], [[MyDSL.Chat.setFont(matches[2])]])
  tempAlias([[^mydsl chat wrap (auto|on)$]], [[MyDSL.Chat.setWrap("auto")]])
  tempAlias([[^mydsl chat wrap (fixed|manual|off) (\d+)$]], [[MyDSL.Chat.setWrap("fixed", matches[3])]])
  tempAlias([[^mydsl chat wrap (\d+)$]], [[MyDSL.Chat.setWrap(matches[2])]])
  tempAlias([[^mydsl chat timestamp (on|off)$]], [[MyDSL.Chat.setTimestamp(matches[2])]])
  tempAlias([[^mydsl chat timestamp format (.+)$]], [[MyDSL.Chat.setTimestampFormat(matches[2])]])
  tempAlias([[^mydsl chat rebuild$]], [[MyDSL.Chat.rebuild()]])
  tempAlias([[^mydsl chat revive$]], [[MyDSL.Chat.revive("alias")]])
  tempAlias([[^mydsl chat echo (\S+)\s+(.+)$]], [[MyDSL.Chat.echoTest(matches[2], matches[3])]])
  tempAlias([[^mydsl chat echo$]], [[MyDSL.Chat.echoTest("OOC", "EMCO direct echo test.")]])
  tempAlias([[^mydsl chat test (\S+)\s+(.+)$]], [[MyDSL.Chat.test(matches[2], matches[3])]])
  tempAlias([[^mydsl chat test$]], [[MyDSL.Chat.test("All", "MyDSL ChatWrapper v4C4 test line.")]])

  -- ---- EMCO vocabulary, ported 2026-07-17 -- see the handler functions'
  -- own header comment above for what changed and why. "emco show"/
  -- "emco hide"/"emco title" now genuinely work (unlike the old native
  -- versions, which acted on the dead demonnic.container) since MyDSL
  -- owns the whole stack now -- no more split-brain "which show/hide is
  -- the real one" situation, so these are direct synonyms for the
  -- existing "mydsl chat show/hide" handlers, not new logic.
  tempAlias([[^emco addtab (\S+)(?:\s+(\d+))?$]], [[MyDSL.Chat.addTab(matches[2], matches[3])]])
  tempAlias([[^emco remtab (.+)$]], [[MyDSL.Chat.remTab(matches[2])]])
  tempAlias([[^emco gag (.+)$]], [[MyDSL.Chat.addGag(matches[2])]])
  tempAlias([[^emco ungag (.+)$]], [[MyDSL.Chat.removeGag(matches[2])]])
  tempAlias([[^emco gaglist$]], [[MyDSL.Chat.gagList()]])
  tempAlias([[^emco notify (.+)$]], [[MyDSL.Chat.addNotifyTab(matches[2])]])
  tempAlias([[^emco unnotify (.+)$]], [[MyDSL.Chat.removeNotifyTab(matches[2])]])
  tempAlias([[^emco blink (\S+)$]], [[MyDSL.Chat.setBlink(matches[2])]])
  tempAlias([[^emco blankLine (\S+)$]], [[MyDSL.Chat.setBlankLine(matches[2])]])
  tempAlias([[^emco color (\S+) (.+)$]], [[MyDSL.Chat.setColor(matches[2], matches[3])]])
  tempAlias([[^emco fontSize (\d+)$]], [[MyDSL.Chat.setFont(matches[2])]])
  tempAlias([[^emco timestamp (\S+)$]], [[MyDSL.Chat.setTimestamp(matches[2])]])
  tempAlias([[^emco save$]], [[MyDSL.Chat.saveSettings(); MyDSL.Chat.status()]])
  tempAlias([[^emco load$]], [[MyDSL.Chat.loadSettings(); MyDSL.Chat.applyFont(); MyDSL.Chat.applyWrap(); MyDSL.Chat.applyTimestamp(); MyDSL.Chat.status()]])
  tempAlias([[^emco show$]], [[MyDSL.Chat.show()]])
  tempAlias([[^emco hide$]], [[MyDSL.Chat.hide()]])
  tempAlias([[^emco title (.+)$]], [[
    local title = matches[2]
    if title == "clear" then title = "-= Chat =-" end
    if MyDSL and MyDSL.Chat and MyDSL.Chat.window and MyDSL.Chat.window.setTitle then
      pcall(function() MyDSL.Chat.window:setTitle(title) end)
    end
  ]])

  C.aliasesInstalled = true
end

-- Neutralize EMCO's own "emco update" alias, IF the separate EMCOChat
-- package happens to also be installed for some other reason -- confirmed
-- live (pre-2026-07-17) that alias silently uninstalls EMCOChat and
-- reinstalls a vanilla copy from GitHub, wiping any customization. Not a
-- real dependency anymore as of 2026-07-17 (EMCO's actual class is now
-- ported directly into MyDSL_EMCO.lua, no separate package needed at
-- all), but harmless to leave as a defensive no-op -- exists() just
-- returns 0 and this does nothing if that alias was never installed.
local function disableEmcoUpdateAlias()
  local ok, id = pcall(exists, "emco update", "alias")
  if ok and id and id ~= 0 then
    pcall(disableAlias, id)
  end
end

function C.install()
  C.loadSettings()
  C.installAliases()
  C.ensureWindow()
  disableEmcoUpdateAlias()

  if C.config.rebuildOnLoad then
    C.startupSync()
  else
    if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. C.version .. " (rebuildOnLoad off; no capture triggers)") end
  end
end

C.install()

-- Re-load once the real character is known -- fixed 2026-07-07. install()
-- above (via loadSettings()) runs at script-boot time, which on a
-- genuinely fresh Mudlet start happens before login, so it loads
-- "Unknown"'s settings (or bare defaults) and would otherwise never pick
-- up this character's real saved chat settings. MyDSL_DataLayer.lua's
-- gmcp.login_data handler raises "MyDSL.character.identified" once the
-- real name is known; re-run the exact same sequence "mydsl chat reload
-- settings" already uses.
C._handlers.characterIdentified = registerAnonymousEventHandler(
  "MyDSL.character.identified",
  function()
    C.loadSettings()
    C.applyFont()
    C.applyWrap()
    C.applyTimestamp()
  end
)
