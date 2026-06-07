--[[=====================================================================
  MyDSL.ChatWrapper v4C11 QuietWindowSetup
  ----------------------------------------------------------------------
  Minimal MyDSL wrapper for Demonnic EMCOChat using the proven Emberline
  creation model:

    demonnic.chat = emco:new(config, MyDSL_Chat_UserWindow)

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
    - Does NOT disable stock EMCO triggers.
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

function C.settingsFile()
  return profileDir() .. "/chat_settings.lua"
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


local function requireEMCO()
  local ok, emco = pcall(require, "EMCOChat.emco")
  if ok and emco then
    C._emcoClass = emco
    return true
  end

  ok, emco = pcall(require, "EMCOChat")
  if ok and emco then
    C._emcoClass = emco.emco or emco
    return true
  end

  return err("EMCOChat not found. Install EMCOChat first.")
end

local function haveWindowCore()
  return MyDSL and MyDSL.Windows and type(MyDSL.Windows.ensure) == "function"
end

local function getWindowEntry()
  if not (MyDSL and MyDSL.Windows) then return nil end

  -- WindowCore v4C stores UserWindow records in registry.
  local reg = MyDSL.Windows.registry or MyDSL.Windows.windows or {}
  return reg[C.config.windowId]
      or reg[C.config.windowName]
      or reg.Chat
      or reg["Chat"]
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
      if MyDSL.Windows.setFont then MyDSL.Windows.setFont(C.config.windowId, C.config.fontSize, true) end
      if MyDSL.Windows.setTitle then MyDSL.Windows.setTitle(C.config.windowId, "-= Chat =-", true) end
    end)

    if ok then
      local obj = getWindowObject()
      if obj then
        C.window = obj
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
      x = "65%",
      y = "0%",
      width = "35%",
      height = "35%",
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

  -- One final create after the layout has almost certainly restored. This is
  -- the automatic equivalent of "mydsl chat rebuild", but only during startup.
  tempTimer(5.0, function()
    if MyDSL and MyDSL.Chat then
      C.createInWindow()
      C.state.lastAction = "startup-final-create"
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

function C.installAliases()
  if C.aliasesInstalled then return end

  tempAlias([[^mydsl chat status$]], [[MyDSL.Chat.status()]])
  tempAlias([[^mydsl chat save$]], [[MyDSL.Chat.saveSettings(); MyDSL.Chat.status()]])
  tempAlias([[^mydsl chat reload settings$]], [[MyDSL.Chat.loadSettings(); MyDSL.Chat.applyFont(); MyDSL.Chat.applyWrap(); MyDSL.Chat.applyTimestamp(); MyDSL.Chat.status()]])
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

  C.aliasesInstalled = true
end

function C.install()
  C.loadSettings()
  C.installAliases()
  C.ensureWindow()

  if C.config.rebuildOnLoad then
    C.startupSync()
  else
    if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. C.version .. " (rebuildOnLoad off; no capture triggers)") end
  end
end

C.install()
