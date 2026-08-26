
--[[=====================================================================
  MyDSL.PortraitView v4C4 CoverDefault
  ----------------------------------------------------------------------
  Character portrait window for the MyDSL v4C UI stack.

  Design:
    - Canonical module: MyDSL.Portrait
    - Isolated visual module: no mapper, source, route, affects, target,
      right-here, chat, roomdesc, location, or HUD changes.
    - Uses WindowCore when available, otherwise creates its own
      Geyser.UserWindow.
    - Adds the useful behavior from the older CharPic script:
        * character-name based automatic file lookup
        * spaces become underscores: Example Name -> Example_Name.png
        * configurable portrait directory
        * probe command
        * missing caption|blank mode
        * optional charpic compatibility aliases
    - Project-standard default directory:
        <profile>/MyDSL/portraits
    - Project-standard profile file:
        <profile>/MyDSL/portraits/portrait_profiles.lua

  Commands:
    mydsl portrait
    mydsl portrait status
    mydsl portrait show
    mydsl portrait hide
    mydsl portrait refresh
    mydsl portrait rebuild
    mydsl portrait set <absolute-or-profile-relative-path>
    mydsl portrait clear
    mydsl portrait font <size>
    mydsl portrait frame on|off
    mydsl portrait fit stretch|contain|cover
    mydsl portrait dir
    mydsl portrait dir <absolute-or-profile-relative-path>
    mydsl portrait name <character name>
    mydsl portrait probe [character name]
    mydsl portrait missing caption|blank
    mydsl portrait title <title text>

  Compatibility aliases:
    charpic refresh/show/hide/reset/dump/dir/dir <path>/probe [name]
    charpic set <name>
    charpic fit fill|contain
    charpic missing caption|blank
    charpic title <title text>
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.Portrait = MyDSL.Portrait or {}

local P = MyDSL.Portrait
P.version = "PortraitView v4C4 CoverDefault"

P.config = P.config or {}
P.config.windowId = P.config.windowId or "Portrait"
P.config.windowName = P.config.windowName or "MyDSL_Portrait"
P.config.title = P.config.title or "-= Portrait =-"
P.config.fontSize = tonumber(P.config.fontSize or 9) or 9
P.config.debug = P.config.debug == true
P.config.enabled = P.config.enabled ~= false
P.config.frame = P.config.frame ~= false
-- Default changed 2026-07-12 to "contain" then same day to "stretch" --
-- see containImageHTML()/stretchImageHTML() above. Steven tried contain
-- (letterboxed) live and preferred the image filling the whole window
-- exactly ("i prefer the old images stretching to fill, not fond of this
-- border lookin location and portrait"), even with minor distortion.
-- cover still exists but uses the older, confirmed-unreliable border-image
-- renderer -- not fixed this pass.
P.config.fit = P.config.fit or "stretch"
P.config.defaultExt = P.config.defaultExt or "png"
P.config.missingMode = P.config.missingMode or "caption" -- caption|blank
P.config.caption = P.config.caption ~= false
P.config.imgDir = P.config.imgDir or nil

P.state = P.state or {}
P.state.charName = P.state.charName or nil
P.state.currentPath = P.state.currentPath or nil
P.state.currentFile = P.state.currentFile or nil
P.state.currentName = P.state.currentName or nil
P.state.pathExists = P.state.pathExists or false
P.state.pathSource = P.state.pathSource or nil
P.state.lastReason = P.state.lastReason or "load"
P.state.lastError = P.state.lastError or nil
P.state.windowReady = P.state.windowReady or false

P.data = P.data or { characters = {}, settings = {} }
P.aliasesInstalled = P.aliasesInstalled or false
P.handlers = P.handlers or {}

-- ----------------------------------------------------------------------
-- Small helpers
-- ----------------------------------------------------------------------

local function ce(msg)
  cecho("\n<cyan>[MyDSL.Portrait]<reset> " .. tostring(msg) .. "\n")
end

local function trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function safeStr(s)
  s = trim(s)
  if s == "" then return nil end
  return s
end

local function lower(s)
  return string.lower(trim(s or ""))
end

local function escHtml(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  s = s:gsub('"', "&quot;"):gsub("'", "&#39;")
  return s
end

local function cssPath(path)
  path = tostring(path or "")
  path = path:gsub("\\", "/")
  path = path:gsub('"', '\\"')
  return path
end

local function fileExists(path)
  path = trim(path)
  if path == "" then return false end
  if io and io.exists then
    local ok, exists = pcall(io.exists, path)
    if ok then return exists == true end
  end
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function dirExists(path)
  path = trim(path)
  if path == "" then return false end
  if lfs and lfs.attributes then
    local ok, mode = pcall(lfs.attributes, path, "mode")
    return ok and mode == "directory"
  end
  local f = io.open(path, "rb")
  if f then f:close() end
  return false
end

local function safeMkdir(path)
  path = trim(path)
  if path == "" then return false end
  if dirExists(path) then return true end
  if lfs and lfs.mkdir then
    local ok = pcall(lfs.mkdir, path)
    if ok then return true end
  end
  return false
end

local function joinPath(a, b)
  a = tostring(a or ""):gsub("/+$", "")
  b = tostring(b or ""):gsub("^/+", "")
  if a == "" then return b end
  if b == "" then return a end
  return a .. "/" .. b
end

local function profileDir()
  local ok, dir = pcall(getMudletHomeDir)
  if ok and dir and tostring(dir) ~= "" then return tostring(dir) end
  return "."
end

local function normalizePath(path)
  path = trim(path)
  if path == "" then return "" end
  path = path:gsub("^~", os.getenv("HOME") or "~")
  if path:sub(1, 1) == "/" then return path end
  return joinPath(profileDir(), path)
end

local function defaultDir()
  return joinPath(joinPath(profileDir(), "MyDSL"), "portraits")
end

function P.baseDir()
  return normalizePath(P.config.imgDir or defaultDir())
end

function P.dataFile()
  return joinPath(defaultDir(), "portrait_profiles.lua")
end

local function ensureDirs()
  safeMkdir(joinPath(profileDir(), "MyDSL"))
  safeMkdir(defaultDir())
  safeMkdir(P.baseDir())
end

local function serializeValue(v, indent)
  indent = indent or ""
  local t = type(v)
  if t == "number" or t == "boolean" then return tostring(v) end
  if t == "string" then return string.format("%q", v) end
  if t ~= "table" then return "nil" end

  local nextIndent = indent .. "  "
  local out = { "{" }
  for k, val in pairs(v) do
    local key
    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
      key = k
    else
      key = "[" .. serializeValue(k, nextIndent) .. "]"
    end
    table.insert(out, "\n" .. nextIndent .. key .. " = " .. serializeValue(val, nextIndent) .. ",")
  end
  table.insert(out, "\n" .. indent .. "}")
  return table.concat(out, "")
end

function P.save()
  ensureDirs()
  P.data.characters = P.data.characters or {}
  P.data.settings = P.data.settings or {}
  P.data.settings.fontSize = P.config.fontSize
  P.data.settings.frame = P.config.frame
  P.data.settings.fit = P.config.fit
  P.data.settings.title = P.config.title
  P.data.settings.missingMode = P.config.missingMode
  P.data.settings.caption = P.config.caption
  P.data.settings.imgDir = P.config.imgDir

  local f, err = io.open(P.dataFile(), "w")
  if not f then
    P.state.lastError = "save failed: " .. tostring(err)
    return false
  end
  f:write("return ")
  f:write(serializeValue(P.data, ""))
  f:write("\n")
  f:close()
  return true
end

function P.load()
  ensureDirs()
  local path = P.dataFile()
  if not fileExists(path) then
    P.data = P.data or { characters = {}, settings = {} }
    P.data.characters = P.data.characters or {}
    P.data.settings = P.data.settings or {}
    return true
  end

  local fn, err = loadfile(path)
  if not fn then
    P.state.lastError = "load failed: " .. tostring(err)
    return false
  end

  local ok, data = pcall(fn)
  if ok and type(data) == "table" then
    P.data = data
    P.data.characters = P.data.characters or {}
    P.data.settings = P.data.settings or {}
    P.config.fontSize = tonumber(P.data.settings.fontSize or P.config.fontSize) or P.config.fontSize
    P.config.frame = P.data.settings.frame ~= false
    P.config.fit = P.data.settings.fit or P.config.fit
    P.config.title = P.data.settings.title or P.config.title
    P.config.missingMode = P.data.settings.missingMode or P.config.missingMode
    P.config.caption = P.data.settings.caption ~= false
    P.config.imgDir = P.data.settings.imgDir or P.config.imgDir
    return true
  end

  P.state.lastError = "load returned invalid data"
  return false
end

-- ----------------------------------------------------------------------
-- Character/path resolution
-- ----------------------------------------------------------------------

function P.getCharName()
  if MyCore and type(MyCore.getChar) == "function" then
    local ok, name = pcall(MyCore.getChar)
    if ok and trim(name) ~= "" then return trim(name) end
  end

  local candidates = {}
  if MyCore and MyCore.state and MyCore.state.gmcp then
    local g = MyCore.state.gmcp
    if type(g.char_data) == "table" then
      table.insert(candidates, g.char_data.name)
      table.insert(candidates, g.char_data.character_name)
    end
    if type(g.login_data) == "table" then
      table.insert(candidates, g.login_data.name)
      table.insert(candidates, g.login_data.character_name)
    end
  end
  if gmcp then
    if type(gmcp.char_data) == "table" then
      table.insert(candidates, gmcp.char_data.name)
      table.insert(candidates, gmcp.char_data.character_name)
    end
    if type(gmcp.login_data) == "table" then
      table.insert(candidates, gmcp.login_data.name)
      table.insert(candidates, gmcp.login_data.character_name)
    end
  end

  for _, v in ipairs(candidates) do
    v = trim(v)
    if v ~= "" then return v end
  end
  return "unknown"
end

function P.fileForName(name)
  name = safeStr(name)
  if not name then return nil end
  name = name:gsub("%s+", "_")
  return name .. "." .. tostring(P.config.defaultExt or "png")
end

function P.defaultPathFor(charName)
  charName = trim(charName or P.getCharName())
  if charName == "" or charName == "unknown" then return "" end
  return joinPath(P.baseDir(), P.fileForName(charName) or "")
end

function P.pathForName(charName)
  local file = P.fileForName(charName)
  if not file then return nil, nil end
  return joinPath(P.baseDir(), file), file
end

function P.pathFor(charName)
  charName = trim(charName or P.getCharName())
  local key = lower(charName)
  local rec = P.data and P.data.characters and P.data.characters[key]
  if type(rec) == "table" and trim(rec.path) ~= "" then
    return normalizePath(rec.path), "configured", rec.file
  end
  local path, file = P.pathForName(charName)
  return path or "", "auto", file
end

function P.setPath(path, charName)
  charName = trim(charName or P.getCharName())
  if charName == "" or charName == "unknown" then
    P.state.lastError = "cannot set portrait: character name unknown"
    return false
  end

  local normalized = normalizePath(path)
  P.data.characters = P.data.characters or {}
  P.data.characters[lower(charName)] = {
    name = charName,
    path = normalized,
    file = normalized:match("([^/]+)$"),
    updated = os.date("%Y-%m-%d %H:%M:%S"),
  }
  P.save()
  return P.refresh("set")
end

function P.clearPath(charName)
  charName = trim(charName or P.getCharName())
  if P.data and P.data.characters then
    P.data.characters[lower(charName)] = nil
  end
  P.save()
  return P.refresh("clear")
end

function P.setDir(path)
  path = safeStr(path)
  if not path then
    ce("directory=" .. tostring(P.baseDir()) .. " ; default=" .. tostring(P.defaultPathFor(P.getCharName())))
    return true
  end
  P.config.imgDir = normalizePath(path)
  P.save()
  ce("directory set to " .. tostring(P.baseDir()))
  return P.refresh("dir")
end

function P.setTitle(title)
  title = safeStr(title)
  if not title then
    ce("<red>usage: mydsl portrait title <title text><reset>")
    return false
  end
  P.config.title = title
  P.save()
  if MyDSL.Windows and MyDSL.Windows.ensureHeader then
    MyDSL.Windows.ensureHeader(P.config.windowName, title)
  else
    if P.window and P.window.setTitle then pcall(function() P.window:setTitle(title) end) end
    if P.window and P.window.setWindowTitle then pcall(function() P.window:setWindowTitle(title) end) end
  end
  return P.refresh("title")
end

function P.setMissing(mode)
  mode = lower(mode)
  if mode ~= "caption" and mode ~= "blank" then
    ce("<red>usage: mydsl portrait missing caption|blank<reset>")
    return false
  end
  P.config.missingMode = mode
  P.save()
  return P.refresh("missing")
end

function P.setByName(name)
  name = safeStr(name)
  if not name then
    P.state.lastError = "no character name supplied"
    return P.renderMissing("name-missing")
  end
  local path, source, file = P.pathFor(name)
  local exists = fileExists(path)
  P.state.charName = name
  P.state.currentName = name
  P.state.currentPath = path
  P.state.currentFile = file
  P.state.pathSource = source
  P.state.pathExists = exists
  if exists then return P.renderImage(path, "name") end
  return P.renderMissing("name-missing")
end

function P.probe(name)
  name = safeStr(name) or P.getCharName()
  local path, source, file = P.pathFor(name)
  ce("probe\n  name=" .. tostring(name)
    .. "\n  file=" .. tostring(file or P.fileForName(name))
    .. "\n  source=" .. tostring(source)
    .. "\n  dir=" .. tostring(P.baseDir())
    .. "\n  path=" .. tostring(path)
    .. "\n  exists=" .. tostring(fileExists(path) and "YES" or "NO"))
end

function P.dump()
  ce("status\n  version=" .. tostring(P.version)
    .. "\n  title=" .. tostring(P.config.title)
    .. "\n  imgDir=" .. tostring(P.baseDir())
    .. "\n  fit=" .. tostring(P.config.fit)
    .. "\n  missing=" .. tostring(P.config.missingMode)
    .. "\n  frame=" .. tostring(P.config.frame)
    .. "\n  currentName=" .. tostring(P.state.currentName)
    .. "\n  currentFile=" .. tostring(P.state.currentFile)
    .. "\n  currentPath=" .. tostring(P.state.currentPath)
    .. "\n  loginName=" .. tostring(P.getCharName()))
end

-- ----------------------------------------------------------------------
-- Window/rendering
-- ----------------------------------------------------------------------

local function haveWindowCore()
  return MyDSL and MyDSL.Windows and type(MyDSL.Windows.ensure) == "function"
end

local function getWindowEntry()
  if not (MyDSL and MyDSL.Windows and MyDSL.Windows.registry) then return nil end
  return MyDSL.Windows.registry[P.config.windowId]
      or MyDSL.Windows.registry[P.config.windowName]
      or MyDSL.Windows.registry.Portrait
end

local function getWindowObject()
  local entry = getWindowEntry()
  if type(entry) == "table" then
    return entry.obj or entry.win or entry.window or entry.userWindow or entry.container or entry
  end
  return P.window
end

function P.ensureWindow()
  if haveWindowCore() then
    local ok = pcall(function()
      MyDSL.Windows.ensure(P.config.windowName)
    end)
    if ok then
      local obj = getWindowObject()
      if obj then
        P.window = obj
        P.state.windowReady = true
      end
    end
  end

  if not P.window then
    if not (Geyser and Geyser.UserWindow) then
      P.state.lastError = "Geyser.UserWindow unavailable"
      return false
    end
    local ok, win = pcall(function()
      return Geyser.UserWindow:new({
        name = P.config.windowName,
        titleText = P.config.title,
        x = "0%",
        y = "0%",
        width = "20%",
        height = "30%",
      })
    end)
    if not ok or not win then
      P.state.lastError = "failed to create portrait window: " .. tostring(win)
      return false
    end
    P.window = win
    P.state.windowReady = true
  end

  -- Visual pass v2 "Direction A+" (locked spec, HANDOFF.md 2026-08-26).
  -- Portrait is the one window with a genuinely user-customizable title
  -- ("mydsl portrait title <text>", P.setTitle() below) -- ensureHeader()
  -- gets P.config.title verbatim (whatever Steven set, not a hardcoded
  -- "Portrait") specifically to preserve that existing feature, not the
  -- plain window-name-only text every other window uses.
  if MyDSL.Windows and MyDSL.Windows.ensureHeader then
    MyDSL.Windows.ensureHeader(P.config.windowName, P.config.title)
  else
    if P.window and P.window.setTitle then pcall(function() P.window:setTitle(P.config.title) end) end
    if P.window and P.window.setWindowTitle then pcall(function() P.window:setWindowTitle(P.config.title) end) end
  end

  local parent = getWindowObject() or P.window

  if not P.label then
    if not (Geyser and Geyser.Label) then
      P.state.lastError = "Geyser.Label unavailable"
      return false
    end
    local ok, lbl = pcall(function()
      return Geyser.Label:new({
        name = "MyDSL_Portrait_ImageLabel",
        x = 0,
        y = "10%",
        width = "100%",
        height = "90%",
      }, parent)
    end)
    if ok and lbl then
      P.label = lbl
    else
      P.state.lastError = "failed to create portrait image label: " .. tostring(lbl)
      return false
    end
  end

  if not P.caption then
    local ok, cap = pcall(function()
      return Geyser.Label:new({
        name = "MyDSL_Portrait_CaptionLabel",
        x = "1%",
        y = "88%",
        width = "98%",
        height = "11%",
      }, parent)
    end)
    if ok and cap then P.caption = cap end
  end

  return true
end

-- Migrated 2026-07-11 to pull background/border color from MyDSL.Theme
-- instead of the hardcoded literals repeated across the four style
-- functions below. Font/radius/padding stay as this window's own
-- deliberate choices (Portrait is primarily an image display, not text).
local function frameColorCSS()
  if MyDSL.Theme then
    local ok, css = pcall(MyDSL.Theme.colorToCSS, MyDSL.Theme.get(P.config.windowName, "borderColor"))
    if ok and css then return css end
  end
  return "#2f5f5f"
end

local function panelBgCSS()
  if MyDSL.Theme then
    local ok, css = pcall(MyDSL.Theme.colorToCSS, MyDSL.Theme.get(P.config.windowName, "bgColor"))
    if ok and css then return css end
  end
  return "#050808"
end

local function baseStyle()
  local border = P.config.frame and ("border: 1px solid " .. frameColorCSS() .. ";") or "border: 0px;"
  -- Mudlet/Geyser labels are more reliable when the stylesheet is applied
  -- directly, without a QLabel selector. This follows the old working
  -- CharPic renderer.
  return [[
    background-color: ]] .. panelBgCSS() .. [[;
    color: #b8d8d8;
    ]] .. border .. [[
    border-radius: 3px;
    padding: 4px;
    font-family: "Noto Sans Mono", monospace;
    font-size: ]] .. tostring(P.config.fontSize) .. [[pt;
  ]]
end

local function captionStyle()
  return [[
    background-color: rgba(0, 0, 0, 165);
    color: rgba(245, 235, 210, 235);
    qproperty-alignment: 'AlignVCenter | AlignLeft';
    padding-left: 6px;
    font-family: "Noto Sans Mono", monospace;
    font-size: ]] .. tostring(P.config.fontSize) .. [[pt;
    border-bottom-left-radius: 3px;
    border-bottom-right-radius: 3px;
  ]]
end

local function imageStyleFill(path)
  path = cssPath(path)
  local border = P.config.frame and ("border: 1px solid " .. frameColorCSS() .. ";") or "border: 0px;"
  -- This is intentionally the old CharPic method. It has proven reliable
  -- in Mudlet UserWindows on Linux.
  return [[
    background-color: ]] .. panelBgCSS() .. [[;
    ]] .. border .. [[
    border-radius: 3px;
    border-image: url("]] .. path .. [[");
    padding: 0px;
  ]]
end

local function imageStyleContainFallback(path)
  path = cssPath(path)
  local border = P.config.frame and ("border: 1px solid " .. frameColorCSS() .. ";") or "border: 0px;"
  return [[
    background-color: ]] .. panelBgCSS() .. [[;
    ]] .. border .. [[
    border-radius: 3px;
    background-image: url("]] .. path .. [[");
    background-repeat: no-repeat;
    background-position: center center;
    qproperty-alignment: AlignCenter;
    padding: 0px;
  ]]
end

local function imageStyleContainAfterSetBackground()
  local border = P.config.frame and ("border: 1px solid " .. frameColorCSS() .. ";") or "border: 0px;"
  return [[
    background-color: ]] .. panelBgCSS() .. [[;
    ]] .. border .. [[
    border-radius: 3px;
    qproperty-alignment: AlignCenter;
    padding: 0px;
  ]]
end

-- containImageHTML(path) -- added 2026-07-12, real bug fix. Steven: "the
-- portrait is supposed to shrink kien's .png to fit the window." The old
-- imageStyleFill()/border-image renderer below doesn't actually scale a
-- picture to fit its box at all -- CSS border-image paints into the
-- border area (a 9-slice UI-frame technique), not the label's content area,
-- so without matching border-image-slice/width values it only ever showed
-- a small, blown-up sliver of the source image instead of the whole
-- picture shrunk down (confirmed live via screenshot: a tiny corner of the
-- portrait, not the whole character). Building the image into the label's
-- actual rich-text content instead, the same mechanism MyDSL_MoonWeather.lua
-- already uses successfully for its moon-phase icons (an <img> tag via
-- echo(), not setBackgroundImage() -- a completely different Mudlet
-- pathway, so this isn't affected by whatever setBackgroundImage()
-- reliability issue the old approach was originally working around).
-- Computes a true aspect-preserving "contain" fit (whole image visible,
-- shrunk to fit, letterboxed on whichever axis doesn't match) using two
-- real Mudlet/Geyser APIs: getImageSize(path) (native pixel dimensions of
-- the file) and label:get_width()/get_height() (the label's actual live
-- rendered pixel size, confirmed real via Mudlet's own bundled
-- GeyserContainer.lua).
local function containImageHTML(label, path)
  local boxW, boxH = label:get_width(), label:get_height()
  if not boxW or not boxH or boxW <= 0 or boxH <= 0 then return nil end
  local ok, imgW, imgH = pcall(getImageSize, path)
  if not ok or not imgW or not imgH or imgW <= 0 or imgH <= 0 then return nil end
  local scale  = math.min(boxW / imgW, boxH / imgH)
  local dispW  = math.max(1, math.floor(imgW * scale))
  local dispH  = math.max(1, math.floor(imgH * scale))
  return string.format(
    '<div align="center" style="padding-top:%dpx;"><img src="file:///%s" width="%d" height="%d"/></div>',
    math.max(0, math.floor((boxH - dispH) / 2)), cssPath(path), dispW, dispH)
end

-- stretchImageHTML(label, path) -- added 2026-07-12, per Steven ("i prefer
-- the old images stretching to fill, not fond of this border lookin
-- location and portrait") -- he tried "contain" (letterboxed, whole image
-- visible) and preferred the image filling the whole window exactly, even
-- if that means the picture's proportions get slightly distorted to match
-- the window's own shape. Same reliable <img>-via-echo() mechanism as
-- containImageHTML() above, just without any aspect-ratio math at all --
-- width/height are simply the label's own live pixel size, so the image
-- always exactly fills the box with no letterboxing and no cropping.
local function stretchImageHTML(label, path)
  local boxW, boxH = label:get_width(), label:get_height()
  if not boxW or not boxH or boxW <= 0 or boxH <= 0 then return nil end
  return string.format(
    '<img src="file:///%s" width="%d" height="%d"/>',
    cssPath(path), math.floor(boxW), math.floor(boxH))
end

local function updateCaption(text, visible)
  if not P.caption then return end
  if visible == false or P.config.caption == false then
    pcall(function() P.caption:echo("") end)
    pcall(function() if P.caption.hide then P.caption:hide() end end)
    return
  end
  pcall(function() if P.caption.show then P.caption:show() end end)
  pcall(function() P.caption:setStyleSheet(captionStyle()) end)
  pcall(function() P.caption:echo(escHtml(text or "")) end)
end

function P.renderMissing(reason)
  if not P.ensureWindow() then
    ce("<red>" .. tostring(P.state.lastError or "window unavailable") .. "<reset>")
    return false
  end

  if P.config.missingMode == "blank" then
    pcall(function() P.label:setStyleSheet(baseStyle()) end)
    pcall(function() P.label:echo("") end)
    updateCaption("", false)
    P.state.lastReason = reason or "missing-blank"
    return false
  end

  local charName = P.state.charName or P.getCharName()
  local path = P.state.currentPath or P.defaultPathFor(charName)
  local msg = "<center><span style='color:#66e0e0; font-weight:bold;'>" .. escHtml(charName) .. "</span><br>"
      .. "<span style='color:#b8d8d8;'>No portrait image found.</span><br><br>"
      .. "<span style='color:#888;'>Expected:</span><br>"
      .. "<span style='color:#aaa;'>" .. escHtml(path) .. "</span><br><br>"
      .. "<span style='color:#888;'>Use:</span><br>"
      .. "<span style='color:#ccc;'>mydsl portrait dir &lt;path&gt;</span><br>"
      .. "<span style='color:#ccc;'>mydsl portrait set /path/to/image.png</span></center>"

  pcall(function() P.label:setStyleSheet(baseStyle()) end)
  pcall(function() P.label:echo(msg) end)
  updateCaption("", false)
  P.state.lastReason = reason or "missing"
  return true
end

function P.renderImage(path, reason)
  if not P.ensureWindow() then
    ce("<red>" .. tostring(P.state.lastError or "window unavailable") .. "<reset>")
    return false
  end

  local fit = lower(P.config.fit)
  local renderFit = fit
  local rendered = false

  if renderFit == "contain" then
    -- Real fix 2026-07-12 -- see containImageHTML()'s comment above for the
    -- full root-cause writeup. Falls back to the legacy border-image
    -- renderer only if getImageSize()/get_width()/get_height() genuinely
    -- fail (e.g. an unreadable file) -- never silently shows nothing.
    local html = containImageHTML(P.label, path)
    if html then
      pcall(function() P.label:setStyleSheet(baseStyle()) end)
      pcall(function() P.label:echo(html) end)
      rendered = true
    end
  elseif renderFit == "stretch" or renderFit == "fill" then
    -- Real fix 2026-07-12, per Steven ("i prefer the old images stretching
    -- to fill, not fond of this border lookin location and portrait") --
    -- see stretchImageHTML()'s comment above.
    local html = stretchImageHTML(P.label, path)
    if html then
      pcall(function() P.label:setStyleSheet(baseStyle()) end)
      pcall(function() P.label:echo(html) end)
      rendered = true
    end
  end

  if not rendered then
    -- cover (and contain/stretch, if the real renderers above couldn't
    -- run) use the old CharPic-style border-image renderer. Confirmed to
    -- not actually scale-to-fit correctly (see containImageHTML()'s
    -- comment) -- left as the fallback path, not redesigned this pass.
    pcall(function() P.label:setStyleSheet(imageStyleFill(path)) end)
    pcall(function() P.label:echo("") end)
    rendered = true
  end

  updateCaption(P.state.currentName or P.state.charName or P.getCharName(), true)
  P.state.lastReason = reason or "image"
  P.state.renderMode = renderFit
  return rendered
end

function P.refresh(reason)
  if P.config.enabled == false then return false end
  P.state.lastError = nil

  local charName = P.getCharName()
  local path, source, file = P.pathFor(charName)
  local exists = fileExists(path)

  P.state.charName = charName
  P.state.currentName = charName
  P.state.currentPath = path
  P.state.currentFile = file
  P.state.pathSource = source
  P.state.pathExists = exists
  P.state.lastReason = reason or "refresh"

  if exists then
    return P.renderImage(path, reason or "refresh")
  else
    return P.renderMissing(reason or "missing")
  end
end

function P.show()
  if not P.ensureWindow() then return false end
  pcall(function() if P.window and P.window.show then P.window:show() end end)
  return P.refresh("show")
end

function P.hide()
  pcall(function() if P.window and P.window.hide then P.window:hide() end end)
  return true
end

function P.rebuild()
  pcall(function() if P.label and P.label.hide then P.label:hide() end end)
  pcall(function() if P.caption and P.caption.hide then P.caption:hide() end end)
  P.label = nil
  P.caption = nil
  P.window = getWindowObject() or P.window
  return P.refresh("rebuild")
end

function P.reset()
  for key, id in pairs(P.handlers or {}) do
    pcall(killAlias, id)
    pcall(killAnonymousEventHandler, id)
    P.handlers[key] = nil
  end
  pcall(function() if P.label and P.label.hide then P.label:hide() end end)
  pcall(function() if P.caption and P.caption.hide then P.caption:hide() end end)
  P.label = nil
  P.caption = nil
  P.aliasesInstalled = false
  P.init()
end

function P.status()
  local currentPath = P.state.currentPath or P.pathFor(P.getCharName())
  local msg = "version=" .. tostring(P.version)
    .. "; enabled=" .. tostring(P.config.enabled)
    .. "; char=" .. tostring(P.state.charName or P.getCharName())
    .. "; file=" .. tostring(P.state.currentFile or P.fileForName(P.getCharName()))
    .. "; exists=" .. tostring(P.state.pathExists)
    .. "; source=" .. tostring(P.state.pathSource)
    .. "; fit=" .. tostring(P.config.fit)
    .. "; missing=" .. tostring(P.config.missingMode)
    .. "; frame=" .. tostring(P.config.frame)
    .. "; font=" .. tostring(P.config.fontSize)
    .. "; reason=" .. tostring(P.state.lastReason)
    .. "; render=" .. tostring(P.state.renderMode or "none")
    .. "; dir=" .. tostring(P.baseDir())
    .. "; path=" .. tostring(currentPath)
  if P.state.lastError then msg = msg .. "; error=" .. tostring(P.state.lastError) end
  ce(msg)
end

function P.setFont(size)
  size = tonumber(size)
  if not size or size < 5 or size > 28 then
    ce("<red>usage: mydsl portrait font <5-28><reset>")
    return false
  end
  P.config.fontSize = size
  P.save()
  return P.refresh("font")
end

function P.setFrame(value)
  value = lower(value)
  if value == "on" or value == "true" or value == "1" then P.config.frame = true
  elseif value == "off" or value == "false" or value == "0" then P.config.frame = false
  else ce("<red>usage: mydsl portrait frame on|off<reset>"); return false end
  P.save()
  return P.refresh("frame")
end

function P.setFit(value)
  value = lower(value)
  if value == "fill" then value = "cover" end -- old CharPic compatibility
  if value ~= "stretch" and value ~= "contain" and value ~= "cover" then
    ce("<red>usage: mydsl portrait fit stretch|contain|cover<reset>")
    return false
  end
  P.config.fit = value
  P.save()
  return P.refresh("fit")
end

-- ----------------------------------------------------------------------
-- Aliases/events/compatibility
-- ----------------------------------------------------------------------

local function installAlias(name, pattern, fn)
  if P.handlers[name] then
    pcall(killAlias, P.handlers[name])
    P.handlers[name] = nil
  end
  P.handlers[name] = tempAlias(pattern, fn)
end

function P.installAliases()
  installAlias("status", [[^mydsl portrait status$]], function() P.refresh("status"); P.status() end)
  installAlias("show", [[^mydsl portrait show$]], function() P.show() end)
  installAlias("hide", [[^mydsl portrait hide$]], function() P.hide(); ce("hidden") end)
  installAlias("refresh", [[^mydsl portrait refresh$]], function() P.refresh("manual") end)
  installAlias("rebuild", [[^mydsl portrait rebuild$]], function() P.rebuild(); ce("rebuilt") end)
  installAlias("set", [[^mydsl portrait set\s+(.+)$]], function() P.setPath(matches[2]) end)
  installAlias("clear", [[^mydsl portrait clear$]], function() P.clearPath(); ce("cleared portrait path for " .. tostring(P.getCharName())) end)
  installAlias("font", [[^mydsl portrait font\s+(\d+)$]], function() P.setFont(matches[2]) end)
  installAlias("frame", [[^mydsl portrait frame\s+(on|off|true|false|1|0)$]], function() P.setFrame(matches[2]) end)
  installAlias("fit", [[^mydsl portrait fit\s+(stretch|contain|cover|fill)$]], function() P.setFit(matches[2]) end)
  installAlias("dir_show", [[^mydsl portrait dir$]], function() P.setDir() end)
  installAlias("dir_set", [[^mydsl portrait dir\s+(.+)$]], function() P.setDir(matches[2]) end)
  installAlias("name", [[^mydsl portrait name\s+(.+)$]], function() P.setByName(matches[2]) end)
  installAlias("probe", [[^mydsl portrait probe(?:\s+(.+))?$]], function() P.probe(matches[2]) end)
  installAlias("missing", [[^mydsl portrait missing\s+(caption|blank)$]], function() P.setMissing(matches[2]) end)
  installAlias("title", [[^mydsl portrait title\s+(.+)$]], function() P.setTitle(matches[2]) end)
  installAlias("dump", [[^mydsl portrait dump$]], function() P.dump() end)
  installAlias("help", [[^mydsl portrait(?: help)?$]], function()
    ce("commands: status | show | hide | refresh | rebuild | set <path> | clear | font <size> | frame on|off | fit stretch|contain|cover (contain maps to cover) | dir [path] | name <character> | probe [character] | missing caption|blank | title <text>")
  end)

  -- CharPic compatibility wrappers from the old script. These intentionally
  -- route to MyDSL.Portrait so there is one canonical implementation.
  installAlias("charpic_refresh", [[^charpic refresh$]], function() P.refresh("charpic-refresh") end)
  installAlias("charpic_set", [[^charpic set\s+(.+)$]], function() P.setByName(matches[2]) end)
  installAlias("charpic_probe", [[^charpic probe(?:\s+(.+))?$]], function() P.probe(matches[2]) end)
  installAlias("charpic_dump", [[^charpic dump$]], function() P.dump() end)
  installAlias("charpic_show", [[^charpic show$]], function() P.show() end)
  installAlias("charpic_hide", [[^charpic hide$]], function() P.hide(); ce("hidden") end)
  installAlias("charpic_reset", [[^charpic reset$]], function() P.reset() end)
  installAlias("charpic_dir_show", [[^charpic dir$]], function() P.setDir() end)
  installAlias("charpic_dir_set", [[^charpic dir\s+(.+)$]], function() P.setDir(matches[2]) end)
  installAlias("charpic_fit", [[^charpic fit\s+(fill|contain|cover|stretch)$]], function() P.setFit(matches[2]) end)
  installAlias("charpic_title", [[^charpic title\s+(.+)$]], function() P.setTitle(matches[2]) end)
  installAlias("charpic_missing", [[^charpic missing\s+(caption|blank)$]], function() P.setMissing(matches[2]) end)

  P.aliasesInstalled = true
end

local function registerHandler(key, eventName, fn)
  if P.handlers[key] then
    pcall(killAnonymousEventHandler, P.handlers[key])
    P.handlers[key] = nil
  end
  P.handlers[key] = registerAnonymousEventHandler(eventName, fn)
end

function P.installEvents()
  registerHandler("gmcp_char_data", "gmcp.char_data", function() tempTimer(0.15, function() P.refresh("gmcp.char_data") end) end)
  registerHandler("gmcp_login_data", "gmcp.login_data", function() tempTimer(0.15, function() P.refresh("gmcp.login_data") end) end)
  registerHandler("sys_connection", "sysConnectionEvent", function() tempTimer(1.0, function() P.refresh("connection") end) end)
  -- Re-apply background/border/caption colors when the active theme
  -- switches. Added 2026-07-11 alongside named ThemeEngine presets.
  registerHandler("theme_changed", "MyDSL.theme.changed", function()
    pcall(function() P.caption:setStyleSheet(captionStyle()) end)
    P.refresh("theme.changed")
  end)
end

function P.installCompatGlobal()
  CharPic = CharPic or {}
  CharPic.refresh = function() return P.refresh("CharPic.refresh") end
  CharPic.setByName = function(name) return P.setByName(name) end
  CharPic.setImage = function(path, caption)
    P.state.currentName = caption or P.getCharName()
    P.state.currentPath = normalizePath(path)
    P.state.pathExists = fileExists(P.state.currentPath)
    if P.state.pathExists then return P.renderImage(P.state.currentPath, "CharPic.setImage") end
    return P.renderMissing("CharPic.setImage-missing")
  end
  CharPic.fileForName = function(name) return P.fileForName(name) end
  CharPic.pathForName = function(name) return P.pathForName(name) end
  CharPic.probe = function(name) return P.probe(name) end
  CharPic.dump = function() return P.dump() end
  CharPic.show = function() return P.show() end
  CharPic.hide = function() return P.hide() end
  CharPic.reset = function() return P.reset() end
  CharPic.setDir = function(path) return P.setDir(path) end
  CharPic.setFit = function(mode) return P.setFit(mode) end
  CharPic.setTitle = function(title) return P.setTitle(title) end
  CharPic.setMissing = function(mode) return P.setMissing(mode) end
  CharPic.boot = function() return P.init() end
end

function P.init()
  P.load()
  P.installCompatGlobal()
  P.installAliases()
  P.installEvents()
  tempTimer(0.2, function() P.refresh("load") end)
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. P.version) end
end

P.init()

        