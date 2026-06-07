
--[[=====================================================================
  MyDSL.LocationView v4C3 RoomPicCanonical
  ----------------------------------------------------------------------
  Dockable room/location picture window for the MyDSL v4C UI stack, using the old RoomPic behavior as inspiration.

  Design:
    - Canonical module: MyDSL.Location
    - Separate visual module: no mapper, roomdesc, source, route, bridge,
      target, right-here, affects, chat, portrait, or HUD changes.
    - Uses current MyDSL room state first, then GMCP, then Mudlet mapper
      room id/name fallback. This avoids nil room names after login when
      gmcp.room_data is empty but the mapper knows the current room.
    - Uses proven PortraitView/old CharPic render path:
        border-image: url("...")
      because setBackgroundImage()/contain is unreliable in Mudlet 4.20.1
      on Linux UserWindows.
    - Project-standard default directory:
        <profile>/MyDSL/roompics
    - Filename convention:
        Exact Room Name -> Exact_Room_Name.png
      with old RoomPic-compatible and safer fallback filenames.
    - Optional exact-room mapping file:
        <profile>/MyDSL/roompics/location_profiles.lua

  Commands:
    mydsl location
    mydsl location status
    mydsl location show
    mydsl location hide
    mydsl location refresh
    mydsl location rebuild
    mydsl location dir
    mydsl location dir <absolute/path>
    mydsl location probe
    mydsl location probe <room name>
    mydsl location name <room name>
    mydsl location set <absolute/image/path>
    mydsl location map <room name> = <absolute/image/path>
    mydsl location unmap <room name>
    mydsl location maps
    mydsl location fit cover|stretch|contain|fill
    mydsl location missing caption|blank
    mydsl location title <title text>
    mydsl location debug on|off

  Compatibility aliases:
    roompic ...
    locpic ...
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.Location = MyDSL.Location or {}

local M = MyDSL.Location
M.version = "LocationView v4C3 RoomPicCanonical"
M.windowName = M.windowName or "MyDSL_Location"
M.title = M.title or "-= Location =-"

M.config = M.config or {}
if M.config.enabled == nil then M.config.enabled = true end
if M.config.shown == nil then M.config.shown = true end
M.config.x = M.config.x or 740
M.config.y = M.config.y or 80
M.config.w = M.config.w or 380
M.config.h = M.config.h or 280
M.config.fit = M.config.fit or "cover"
M.config.missing = M.config.missing or "blank"
M.config.font = M.config.font or 8
M.config.debug = M.config.debug or false
M.config.frame = M.config.frame
if M.config.frame == nil then M.config.frame = true end

M.theme = M.theme or {
  bg          = "rgba(8,8,8,255)",
  border      = "rgba(220,200,150,145)",
  captionBg   = "rgba(0,0,0,170)",
  captionText = "rgba(245,235,210,235)",
  warnText    = "rgba(255,190,100,235)",
}

local function trim(s)
  return tostring(s or ""):gsub("^%s*(.-)%s*$", "%1")
end

local function safeStr(s)
  if s == nil then return nil end
  s = trim(s)
  if s == "" then return nil end
  return s
end

local function echoC(msg)
  cecho("\n<cyan>[MyDSL.Location]<reset> " .. tostring(msg) .. "\n")
end

local function echoR(msg)
  cecho("\n<red>[MyDSL.Location]<reset> " .. tostring(msg) .. "\n")
end

local function exists(path)
  if not path then return false end
  if io and io.exists then return io.exists(path) end
  local f = io.open(path, "rb")
  if f then f:close(); return true end
  return false
end

local function join(dir, file)
  dir = safeStr(dir); file = safeStr(file)
  if not dir or not file then return nil end
  if string.sub(dir, -1) == "/" then return dir .. file end
  return dir .. "/" .. file
end

local function cssPath(path)
  return tostring(path or ""):gsub("\\", "/"):gsub('"', '\\"')
end

local function profileDir()
  local base = getMudletHomeDir and getMudletHomeDir() or "."
  return base
end

local function ensureDir(path)
  if not path or path == "" then return end
  pcall(function() os.execute('mkdir -p "' .. tostring(path):gsub('"', '\\"') .. '"') end)
end

local function serializeScalar(v)
  if type(v) == "number" or type(v) == "boolean" then return tostring(v) end
  return string.format("%q", tostring(v or ""))
end

local function saveTable(path, tbl)
  local f, err = io.open(path, "w")
  if not f then return false, err end
  f:write("return {\n")
  for k, v in pairs(tbl or {}) do
    if type(v) == "table" then
      f:write("  [", serializeScalar(k), "] = {\n")
      for kk, vv in pairs(v) do
        f:write("    [", serializeScalar(kk), "] = ", serializeScalar(vv), ",\n")
      end
      f:write("  },\n")
    else
      f:write("  [", serializeScalar(k), "] = ", serializeScalar(v), ",\n")
    end
  end
  f:write("}\n")
  f:close()
  return true
end

local function loadTable(path)
  if not exists(path) then return nil end
  local fn, err = loadfile(path)
  if not fn then return nil, err end
  local ok, data = pcall(fn)
  if ok and type(data) == "table" then return data end
  return nil
end

function M.defaultDir()
  return join(profileDir(), "MyDSL/roompics")
end

function M.profileFile()
  return join(M.dir or M.defaultDir(), "location_profiles.lua")
end

function M.loadProfiles()
  M.dir = M.dir or M.defaultDir()
  ensureDir(M.dir)
  local data = loadTable(M.profileFile()) or {}
  M.roomMap = data.roomMap or M.roomMap or {}
  M.config.fit = data.fit or M.config.fit or "cover"
  M.config.missing = data.missing or M.config.missing or "caption"
  M.title = data.title or M.title or "-= Location =-"
  M.config.shown = (data.shown ~= nil) and data.shown or M.config.shown
  M.config.font = tonumber(data.font or M.config.font) or M.config.font
  M.config.frame = (data.frame ~= nil) and data.frame or M.config.frame
end

function M.saveProfiles()
  M.dir = M.dir or M.defaultDir()
  ensureDir(M.dir)
  local data = {
    roomMap = M.roomMap or {},
    fit = M.config.fit,
    missing = M.config.missing,
    title = M.title,
    shown = M.config.shown,
    font = M.config.font,
    frame = M.config.frame,
  }
  return saveTable(M.profileFile(), data)
end

local function flattenExits(exits)
  if type(exits) ~= "table" then return safeStr(exits) end
  local t = {}
  for k, v in pairs(exits) do
    if type(k) == "string" then
      table.insert(t, k)
    elseif type(v) == "string" then
      table.insert(t, v)
    end
  end
  table.sort(t)
  local out = table.concat(t, " ")
  return safeStr(out)
end

local function roomDataFromTable(r, sourceName)
  if type(r) ~= "table" then return nil end
  local room = safeStr(r.room or r.name or r.title)
  local area = safeStr(r.area or r.zone)
  local terrain = safeStr(r.terrain or r.sector)
  local exits = safeStr(r.exitsText or r.exitText or r.exits_text) or flattenExits(r.exits)
  if room then
    return { room = room, area = area, terrain = terrain, exits = exits, source = sourceName }
  end
  return nil
end

local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, ret = pcall(fn, ...)
  if ok then return ret end
  return nil
end

local function validRoomId(id)
  if id == nil then return nil end
  local s = tostring(id)
  if s == "" or s == "0" or s == "-1" or s == "nil" then return nil end
  return id
end

local function mapperRoomId()
  local id = validRoomId(call(_G.getPlayerRoom))
  if id then return id end

  -- A few mapper packages store the current room id in their own globals.
  -- These checks are intentionally defensive and no-op if those globals do not exist.
  local candidates = {
    _G.currentRoom,
    _G.current_room,
    _G.currentRoomID,
    _G.current_room_id,
    _G.map and (_G.map.currentRoom or _G.map.current_room or _G.map.room or _G.map.currentRoomID),
    _G.mapper and (_G.mapper.currentRoom or _G.mapper.current_room or _G.mapper.room or _G.mapper.currentRoomID),
    _G.mapper and (_G.mapper.currentRoom or _G.mapper.current_room or _G.mapper.room or _G.mapper.currentRoomID),
  }
  for _, v in ipairs(candidates) do
    id = validRoomId(v)
    if id then return id end
  end
  return nil
end

local function mapperAreaName(roomId)
  if not roomId then return nil end
  local area = call(_G.getRoomArea, roomId)
  if not area then return nil end
  if type(area) == "string" then return safeStr(area) end
  local name = call(_G.getRoomAreaName, area)
  if name then return safeStr(name) end

  local areas = call(_G.getAreaTable)
  if type(areas) == "table" then
    for areaName, areaId in pairs(areas) do
      if tostring(areaId) == tostring(area) then return safeStr(areaName) end
    end
  end
  return safeStr(area)
end

local function roomDataFromMapper()
  local id = mapperRoomId()
  if not id then return nil end
  local room = call(_G.getRoomName, id)
  room = safeStr(room)
  if not room then return nil end

  local exits = call(_G.getRoomExits, id)
  return {
    room = room,
    area = mapperAreaName(id),
    terrain = safeStr(call(_G.getRoomUserData, id, "terrain") or call(_G.getRoomUserData, id, "sector")),
    exits = flattenExits(exits),
    roomId = id,
    source = "mapper",
  }
end

function M.roomData()
  local sources = {
    { MyDSL and MyDSL.DB and MyDSL.DB.room, "MyDSL.DB.room" },
    { MyDSL and MyDSL.DB and MyDSL.DB.currentRoom, "MyDSL.DB.currentRoom" },
    { MyDSL and MyDSL.State and MyDSL.State.room, "MyDSL.State.room" },
    { MyDSL and MyDSL.State and MyDSL.State.roomdesc, "MyDSL.State.roomdesc" },
    { MyCore and MyCore.state and MyCore.state.gmcp and MyCore.state.gmcp.room_data, "MyCore.gmcp.room_data" },
    { MyCore and MyCore.state and MyCore.state.gmcp and MyCore.state.gmcp.Room and MyCore.state.gmcp.Room.Info, "MyCore.gmcp.Room.Info" },
    { gmcp and gmcp.room_data, "gmcp.room_data" },
    { gmcp and gmcp.Room and gmcp.Room.Info, "gmcp.Room.Info" },
  }

  for _, pair in ipairs(sources) do
    local data = roomDataFromTable(pair[1], pair[2])
    if data then return data end
  end

  return roomDataFromMapper()
end

function M.currentRoomName()
  local r = M.roomData()
  return r and r.room or nil
end

function M.fileForRoom(room)
  -- Project-safe filename.  This is the preferred v4C filename.
  room = safeStr(room)
  if not room then return nil end
  local file = room:gsub("%s+", "_")
  file = file:gsub("[^%w_%-]", "")
  file = file:gsub("_+", "_")
  file = file:gsub("^_+", ""):gsub("_+$", "")
  if file == "" then return nil end
  return file .. ".png"
end

function M.legacyFileForRoom(room)
  -- Old RoomPic convention: only spaces become underscores.
  room = safeStr(room)
  if not room then return nil end
  local file = room:gsub("%s+", "_")
  if file == "" then return nil end
  return file .. ".png"
end

function M.candidatePathsForRoom(room)
  room = safeStr(room)
  if not room then return {} end
  local out, seen = {}, {}
  local function add(path, source, file)
    if path and not seen[path] then
      table.insert(out, { path = path, source = source, file = file })
      seen[path] = true
    end
  end

  M.roomMap = M.roomMap or {}
  local mapped = safeStr(M.roomMap[room])
  if mapped then add(mapped, "mapped", nil) end

  local safeFile = M.fileForRoom(room)
  local legacyFile = M.legacyFileForRoom(room)
  local primaryDir = M.dir or M.defaultDir()
  local legacyDir = join(profileDir(), "RoomPics")

  -- Try old RoomPic-compatible names first, then safer v4C names.
  add(join(primaryDir, legacyFile), "auto", legacyFile)
  add(join(primaryDir, safeFile), "auto-safe", safeFile)
  add(join(legacyDir, legacyFile), "legacy", legacyFile)
  add(join(legacyDir, safeFile), "legacy-safe", safeFile)
  return out
end

function M.pathForRoom(room)
  local candidates = M.candidatePathsForRoom(room)
  for _, c in ipairs(candidates) do
    if exists(c.path) then return c.path, c.source, c.file end
  end
  local first = candidates[1]
  if first then return first.path, first.source, first.file end
  return nil, nil, nil
end

function M.captionForRoom(roomData, path, source)
  roomData = roomData or {}
  local room = roomData.room or M.currentRoomName() or "Unknown room"
  local meta = {}
  if roomData.area then table.insert(meta, roomData.area) end
  if roomData.terrain then table.insert(meta, roomData.terrain) end
  if roomData.exits then table.insert(meta, "[" .. tostring(roomData.exits) .. "]") end
  local line2 = table.concat(meta, "  |  ")
  if line2 ~= "" then return room .. "\n" .. line2 end
  return room
end

local function getWindowEntry()
  if not (MyDSL and MyDSL.Windows and MyDSL.Windows.registry) then return nil end
  local reg = MyDSL.Windows.registry
  return reg["MyDSL_RoomPicture"] or reg[M.windowName] or reg["Location"]
end

local function getWindowObject()
  local entry = getWindowEntry()
  if type(entry) == "table" then
    return entry.obj or entry.win or entry.window or entry.userWindow or entry.container
  end
  return M.ui and M.ui.win or nil
end

function M.ensureUI()
  M.loadProfiles()
  M.ui = M.ui or {}
  if M.ui.win and M.ui.image and M.ui.caption then return true end

  -- Check DSL2 registry first — avoids creating a duplicate window
  local existing = getWindowObject()
  if existing then
    M.ui.win = existing
  else
    local WinClass = Geyser and (Geyser.UserWindow or Geyser.Window)
    if not WinClass then
      echoR("Geyser.UserWindow/Geyser.Window is unavailable.")
      return false
    end
    M.ui.win = WinClass:new({
      name = M.windowName,
      x = M.config.x,
      y = M.config.y,
      width = M.config.w,
      height = M.config.h,
      restoreLayout = true,
      autoDock = true,
    })
  end

  if not M.ui.win then return false end

  if M.ui.win.setTitle then
    pcall(function() M.ui.win:setTitle(M.title) end)
  end

  M.ui.image = Geyser.Label:new({
    name = M.windowName .. "_Image",
    x = 0, y = 0, width = "100%", height = "100%",
  }, M.ui.win)

  M.ui.caption = Geyser.Label:new({
    name = M.windowName .. "_Caption",
    x = "1%", y = "82%", width = "98%", height = "17%",
  }, M.ui.win)

  M.applyBaseStyle()
  if M.config.shown then M.show(false) else M.hide(false) end
  return true
end

function M.applyBaseStyle()
  if not (M.ui and M.ui.image and M.ui.caption) then return end
  local border = M.config.frame and ("1px solid " .. M.theme.border) or "0px solid rgba(0,0,0,0)"
  M.ui.image:setStyleSheet(string.format([[
    background-color: %s;
    border: %s;
    border-radius: 6px;
  ]], M.theme.bg, border))

  M.ui.caption:setStyleSheet(string.format([[
    background-color: %s;
    color: %s;
    qproperty-alignment: 'AlignVCenter | AlignLeft';
    padding-left: 6px;
    padding-right: 6px;
    font-size: %dpt;
    border-bottom-left-radius: 6px;
    border-bottom-right-radius: 6px;
  ]], M.theme.captionBg, M.theme.captionText, tonumber(M.config.font) or 8))
end

function M.show(save)
  M.config.shown = true
  if save ~= false then M.saveProfiles() end
  if M.ui and M.ui.win then pcall(function() M.ui.win:show() end) end
end

function M.hide(save)
  M.config.shown = false
  if save ~= false then M.saveProfiles() end
  if M.ui and M.ui.win then pcall(function() M.ui.win:hide() end) end
end

function M.clear(caption)
  M.ensureUI()
  if not (M.ui and M.ui.image and M.ui.caption) then return end
  M.applyBaseStyle()
  M.ui.caption:echo(caption or "")
  M.currentPath = nil
  M.currentRoom = nil
  M.currentSource = nil
end

function M.render(path, caption, source, room)
  M.ensureUI()
  if not (M.ui and M.ui.image and M.ui.caption) then return false end

  caption = caption or ""
  if not path or not exists(path) then
    if M.config.missing == "blank" then
      M.clear("")
    else
      M.clear("No room picture" .. (room and (": " .. room) or ""))
    end
    M.lastReason = "missing"
    return false
  end

  local p = cssPath(path)
  local border = M.config.frame and ("1px solid " .. M.theme.border) or "0px solid rgba(0,0,0,0)"
  -- Reliable path for Mudlet 4.20.1 Linux UserWindows.  Even if the requested
  -- fit is contain, render with border-image to avoid black/unpainted labels.
  M.ui.image:setStyleSheet(string.format([[
    background-color: %s;
    border: %s;
    border-radius: 6px;
    border-image: url("%s");
  ]], M.theme.bg, border, p))

  M.ui.caption:echo(caption)
  M.currentPath = path
  M.currentRoom = room
  M.currentSource = source
  M.renderMode = "cover"
  return true
end

function M.refresh(reason)
  M.ensureUI()
  local data = M.roomData()
  if not data or not data.room then
    M.clear("Waiting for room data ...")
    M.lastReason = reason or "no-room-data"
    return false
  end
  local path, source, file = M.pathForRoom(data.room)
  M.currentFile = file
  M.currentSource = source
  M.lastReason = reason or "refresh"
  return M.render(path, M.captionForRoom(data, path, source), source, data.room)
end

function M.setByName(room)
  room = safeStr(room)
  if not room then
    echoR("Usage: mydsl location name <room name>")
    return false
  end
  local data = { room = room }
  local path, source, file = M.pathForRoom(room)
  M.currentFile = file
  M.lastReason = "name"
  return M.render(path, M.captionForRoom(data, path, source), source, room)
end

function M.setImage(path)
  path = safeStr(path)
  if not path then
    echoR("Usage: mydsl location set <absolute/image/path>")
    return false
  end
  M.manualPath = path
  M.lastReason = "manual"
  return M.render(path, "Manual location image", "manual", "manual")
end

function M.setDir(path)
  path = safeStr(path)
  if not path then
    echoC("directory=" .. tostring(M.dir or M.defaultDir()) .. " ; default=" .. tostring(M.defaultDir()))
    return
  end
  M.dir = path
  ensureDir(M.dir)
  M.saveProfiles()
  echoC("Directory set to: " .. M.dir)
  M.refresh("dir")
end

function M.setFit(mode)
  mode = safeStr(mode)
  if mode ~= "cover" and mode ~= "stretch" and mode ~= "contain" and mode ~= "fill" then
    echoR("Usage: mydsl location fit cover|stretch|contain|fill")
    return
  end
  if mode == "fill" then mode = "cover" end
  M.config.fit = mode
  M.saveProfiles()
  echoC("Fit mode set to: " .. mode .. " ; render=cover")
  M.refresh("fit")
end

function M.setMissing(mode)
  mode = safeStr(mode)
  if mode ~= "caption" and mode ~= "blank" then
    echoR("Usage: mydsl location missing caption|blank")
    return
  end
  M.config.missing = mode
  M.saveProfiles()
  echoC("Missing mode set to: " .. mode)
  M.refresh("missing")
end

function M.setTitle(title)
  title = safeStr(title)
  if not title then
    echoR("Usage: mydsl location title <title text>")
    return
  end
  M.title = title
  M.saveProfiles()
  if M.ui and M.ui.win and M.ui.win.setTitle then pcall(function() M.ui.win:setTitle(M.title) end) end
  echoC("Title set to: " .. M.title)
end

function M.setDebug(mode)
  mode = safeStr(mode)
  if mode == "on" then M.config.debug = true elseif mode == "off" then M.config.debug = false else
    echoR("Usage: mydsl location debug on|off")
    return
  end
  echoC("debug=" .. tostring(M.config.debug))
end

function M.mapRoom(room, path)
  room = safeStr(room); path = safeStr(path)
  if not room or not path then
    echoR("Usage: mydsl location map <room name> = <absolute/image/path>")
    return false
  end
  M.roomMap = M.roomMap or {}
  M.roomMap[room] = path
  M.saveProfiles()
  echoC("Mapped room: " .. room .. " -> " .. path)
  if M.currentRoomName() == room then M.refresh("map") end
  return true
end

function M.unmapRoom(room)
  room = safeStr(room)
  if not room then
    echoR("Usage: mydsl location unmap <room name>")
    return false
  end
  M.roomMap = M.roomMap or {}
  M.roomMap[room] = nil
  M.saveProfiles()
  echoC("Unmapped room: " .. room)
  M.refresh("unmap")
  return true
end

function M.listMaps()
  M.roomMap = M.roomMap or {}
  cecho("\n<cyan>[MyDSL.Location maps]<reset>\n")
  local n = 0
  for room, path in pairs(M.roomMap) do
    n = n + 1
    cecho("  <green>" .. tostring(room) .. "<reset> -> " .. tostring(path) .. "\n")
  end
  if n == 0 then cecho("  none\n") end
end

function M.probe(room)
  room = safeStr(room) or M.currentRoomName()
  local path, source, file = M.pathForRoom(room)
  cecho(string.format(
    "\n<cyan>[MyDSL.Location]<reset> probe\n  room=%s\n  file=%s\n  source=%s\n  dir=%s\n  path=%s\n  exists=%s\n",
    tostring(room), tostring(file), tostring(source), tostring(M.dir or M.defaultDir()),
    tostring(path), tostring(path and exists(path) and "YES" or "NO")
  ))
  local candidates = M.candidatePathsForRoom(room)
  if #candidates > 1 then
    cecho("  candidates:\n")
    for _, c in ipairs(candidates) do
      cecho(string.format("    [%s] %s  exists=%s\n", tostring(c.source), tostring(c.path), tostring(exists(c.path) and "YES" or "NO")))
    end
  end
end

function M.status()
  local data = M.roomData() or {}
  cecho(string.format(
    "\n<cyan>[MyDSL.Location]<reset> version=%s; enabled=%s; shown=%s; room=%s; area=%s; fit=%s; render=%s; missing=%s; exists=%s; source=%s; reason=%s; mapperRoom=%s;\n  dir=%s; legacyDir=%s; file=%s; path=%s;\n",
    tostring(M.version), tostring(M.config.enabled), tostring(M.config.shown), tostring(data.room), tostring(data.area),
    tostring(M.config.fit), tostring(M.renderMode or "cover"), tostring(M.config.missing),
    tostring(M.currentPath and exists(M.currentPath)), tostring(M.currentSource or data.source), tostring(M.lastReason), tostring(mapperRoomId()),
    tostring(M.dir or M.defaultDir()), tostring(join(profileDir(), "RoomPics")), tostring(M.currentFile), tostring(M.currentPath)
  ))
end

function M.help()
  cecho([[ 
<cyan>[MyDSL.Location commands]<reset>
  mydsl location status|dump
  mydsl location show|hide|refresh|rebuild|reset
  mydsl location dir [absolute/path]
  mydsl location probe [room name]
  mydsl location name <room name>
  mydsl location set <absolute/image/path>
  mydsl location map <room name> = <absolute/image/path>
  mydsl location unmap <room name>
  mydsl location maps
  mydsl location fit cover|stretch|contain|fill
  mydsl location missing caption|blank
  mydsl location title <title text>
  mydsl location debug on|off
]])
end

function M.rebuild()
  if M.ui and M.ui.win then pcall(function() M.ui.win:hide() end) end
  M.ui = nil
  M.ensureUI()
  M.refresh("rebuild")
end

function M.onRoomData()
  if M.config.enabled then M.refresh("gmcp.room_data") end
end

function M.installEvents()
  if M.handlersInstalled then return end
  if registerAnonymousEventHandler then
    M.h1 = registerAnonymousEventHandler("gmcp.room_data", "MyDSL.Location.onRoomData")
    M.h2 = registerAnonymousEventHandler("gmcp.Room.Info", "MyDSL.Location.onRoomData")
    M.h3 = registerAnonymousEventHandler("onNewRoom", "MyDSL.Location.onRoomData")
  end
  M.handlersInstalled = true
end

local function locationCommand(rest)
  rest = trim(rest or "")
  if rest == "" or rest == "help" then M.help(); return end
  if rest == "status" or rest == "dump" then M.status(); return end
  if rest == "show" then M.show(); M.refresh("show"); return end
  if rest == "hide" then M.hide(); return end
  if rest == "refresh" then M.refresh("manual"); return end
  if rest == "rebuild" or rest == "reset" then M.rebuild(); return end
  if rest == "dir" then M.setDir(); return end
  local dir = rest:match("^dir%s+(.+)$"); if dir then M.setDir(dir); return end
  if rest == "probe" then M.probe(); return end
  local probe = rest:match("^probe%s+(.+)$"); if probe then M.probe(probe); return end
  local name = rest:match("^name%s+(.+)$"); if name then M.setByName(name); return end
  local setp = rest:match("^set%s+(.+)$"); if setp then M.setImage(setp); return end
  local mapRoom, mapPath = rest:match("^map%s+(.+)%s+=%s+(.+)$")
  if mapRoom and mapPath then M.mapRoom(mapRoom, mapPath); return end
  local unmap = rest:match("^unmap%s+(.+)$"); if unmap then M.unmapRoom(unmap); return end
  if rest == "maps" then M.listMaps(); return end
  local fit = rest:match("^fit%s+(%S+)$"); if fit then M.setFit(fit); return end
  local miss = rest:match("^missing%s+(%S+)$"); if miss then M.setMissing(miss); return end
  local title = rest:match("^title%s+(.+)$"); if title then M.setTitle(title); return end
  local dbg = rest:match("^debug%s+(%S+)$"); if dbg then M.setDebug(dbg); return end
  echoR("Unknown command. Try: mydsl location help")
end

function M.makeAliases()
  if M.aliasesMade then return end
  tempAlias([[^mydsl location(?:\s+(.*))?$]], [[MyDSL.Location._cmd(matches[2])]])
  tempAlias([[^mydsl loc(?:\s+(.*))?$]], [[MyDSL.Location._cmd(matches[2])]])
  tempAlias([[^roompic(?:\s+(.*))?$]], [[MyDSL.Location._cmd(matches[2])]])
  tempAlias([[^locpic(?:\s+(.*))?$]], [[MyDSL.Location._cmd(matches[2])]])
  M.aliasesMade = true
end

function M._cmd(rest)
  locationCommand(rest)
end

function M.boot()
  M.loadProfiles()
  M.ensureUI()
  M.installEvents()
  M.makeAliases()
  M.refresh("boot")
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then cecho("\n<cyan>[MyDSL.Location]</cyan> loaded " .. M.version .. "\n") end
end

-- Compatibility: old scripts/aliases may call RoomPic.*.  Keep this as an alias to the canonical module.
RoomPic = M

M.boot()

        