
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
    mydsl location variants
    mydsl location variants <room name>
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
-- Default changed 2026-07-12 to "contain" then same day to "stretch" --
-- see containImageHTML()/stretchImageHTML() above, matching
-- MyDSL_PortraitView.lua's identical fix. Steven tried contain
-- (letterboxed) live and preferred the image filling the whole window
-- exactly ("i prefer the old images stretching to fill, not fond of this
-- border lookin location and portrait"). cover still exists but uses the
-- older, confirmed-unreliable border-image renderer.
M.config.fit = M.config.fit or "stretch"
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

-- themeBg()/themeBorder() -- added 2026-07-11. This file had its own
-- ad-hoc M.theme table (a per-window static theme, unrelated to the
-- shared MyDSL_ThemeEngine.lua) before ThemeEngine gained named presets.
-- These two read live from ThemeEngine when available, falling back to
-- M.theme's original static literals otherwise (load-order safety, and
-- captionBg/captionText/warnText stay as-is -- those are about caption
-- legibility over a photo, not window chrome, so they're left alone).
local function themeBg()
  if MyDSL.Theme then
    local ok, css = pcall(MyDSL.Theme.colorToCSS, MyDSL.Theme.get(M.windowName, "bgColor"))
    if ok and css then return css end
  end
  return M.theme.bg
end

local function themeBorder()
  if MyDSL.Theme then
    local ok, css = pcall(MyDSL.Theme.colorToCSS, MyDSL.Theme.get(M.windowName, "borderColor"))
    if ok and css then return css end
  end
  return M.theme.border
end

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

-- roomVariants uses a SEPARATE file via Mudlet's own table.save()/
-- table.load() -- added 2026-07-17, see M.resolveVariant() below.
-- This file's own hand-rolled saveTable()/loadTable() above only
-- serializes two levels deep (a table of scalars); roomVariants needs a
-- real nested structure (room name -> array of variant records, each
-- with its own color sub-table), which saveTable() would silently
-- mangle (it calls serializeScalar() on a table value, producing a
-- useless "table: 0x..." string). table.save()/table.load() are
-- Mudlet's real, fully-recursive serializer, already used everywhere
-- else in this codebase for exactly this shape of data (CreatureLore's
-- DB, ItemLore, affects files) -- reused here rather than extending the
-- shallow custom one.
function M.variantsFile()
  return join(M.dir or M.defaultDir(), "location_variants.lua")
end

function M.loadProfiles()
  M.dir = M.dir or M.defaultDir()
  ensureDir(M.dir)
  local data = loadTable(M.profileFile()) or {}
  M.roomMap = data.roomMap or M.roomMap or {}
  M.config.fit = data.fit or M.config.fit or "stretch"
  M.config.missing = data.missing or M.config.missing or "caption"
  M.title = data.title or M.title or "-= Location =-"
  M.config.shown = (data.shown ~= nil) and data.shown or M.config.shown
  M.config.font = tonumber(data.font or M.config.font) or M.config.font
  M.config.frame = (data.frame ~= nil) and data.frame or M.config.frame

  M.roomVariants = M.roomVariants or {}
  if exists(M.variantsFile()) then
    pcall(function() table.load(M.variantsFile(), M.roomVariants) end)
  end
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

function M.saveVariants()
  M.dir = M.dir or M.defaultDir()
  ensureDir(M.dir)
  pcall(table.save, M.variantsFile(), M.roomVariants or {})
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
  -- description/descColor -- added 2026-07-17, for same-name-room
  -- disambiguation (see M.resolveVariant() below). Only MyDSL.State.room
  -- (MyDSL_DataLayer.lua's captureRoomDescription()) ever populates
  -- these; other sources (gmcp.room_data direct, mapper fallback) simply
  -- won't have them, which resolveVariant() treats as "no disambiguating
  -- data this time" rather than a mismatch.
  local description = safeStr(r.description)
  local descColor = r.descColor
  if room then
    return {
      room = room, area = area, terrain = terrain, exits = exits,
      description = description, descColor = descColor, source = sourceName,
    }
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
    { gmcp and gmcp.room_data, "gmcp.room_data" },
    { gmcp and gmcp.Room and gmcp.Room.Info, "gmcp.Room.Info" },
  }

  for _, pair in ipairs(sources) do
    local data = roomDataFromTable(pair[1], pair[2])
    if data then
      -- Backfill description/descColor from MyDSL.State.room -- real bug
      -- found 2026-07-18 via location_variants.lua: MyDSL.DB.room (this
      -- loop's first, near-always-present source, rebuilt on every
      -- DataBridge sync()) never carries a description at all, so it won
      -- this loop before MyDSL.State.room (the only source
      -- captureRoomDescription() ever populates) was even checked --
      -- 0 of 137 saved variant records ever had a description. That left
      -- resolveVariant() running on exits-only comparison, and exits
      -- change when a door/gate opens or closes, so a door being open vs.
      -- closed on revisit looked like a different room and spawned a
      -- spurious "new variant" notice. Filling these in here (without
      -- changing which source wins for room/exits/etc.) lets the
      -- description tier -- checked first in resolveVariant() -- match
      -- again for a room whose static description never changed.
      if not data.description then
        local stateRoom = MyDSL and MyDSL.State and MyDSL.State.room
        -- safeStr() both sides -- ultrareview found stateRoom.name is set
        -- raw from GMCP (MyDSL_DataLayer.lua's gmcp.room_data handler),
        -- with no trim, while data.room already went through safeStr()
        -- above. If DSL's GMCP room field is ever whitespace-padded, a
        -- raw-vs-trimmed comparison would silently fail to match the same
        -- room and this whole backfill would no-op with no visible error.
        if stateRoom and safeStr(stateRoom.name) == data.room then
          data.description = safeStr(stateRoom.description) or data.description
          data.descColor = stateRoom.descColor or data.descColor
        end
      end
      return data
    end
  end

  return roomDataFromMapper()
end

function M.currentRoomName()
  local r = M.roomData()
  return r and r.room or nil
end

function M.fileForRoom(room)
  -- Preferred filename convention, changed 2026-07-12 per Steven ("id
  -- like to be able to match the room name and file without appending _
  -- for spaces, then rename all the files to match"). Was underscore-
  -- joined + alphanumeric-only; now the literal room name (spaces,
  -- apostrophes, capitalization preserved) with only genuinely
  -- filesystem-illegal characters stripped -- matches every real
  -- MyDSL/roompics/ filename after the same-day rename pass (confirmed
  -- via directory audit: 248 files -> 215 after removing exact-duplicate
  -- underscore/space pairs, all renamed to this convention).
  room = safeStr(room)
  if not room then return nil end
  local file = room:gsub('[/\\:%*%?"<>|]', "")
  file = trim(file)
  if file == "" then return nil end
  return file .. ".png"
end

function M.legacyFileForRoom(room)
  -- Old RoomPic/pre-2026-07-12 convention: spaces become underscores.
  -- Kept as a fallback lookup only -- every real file on disk was
  -- renamed off this convention 2026-07-12, but this costs nothing to
  -- leave in place in case a not-yet-captured room's image ever shows
  -- up in this shape from an external source.
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

  -- Order flipped 2026-07-12 alongside M.fileForRoom()'s convention
  -- change -- safeFile (the literal-room-name convention) now matches
  -- every real file on disk, so it's tried first; legacyFile
  -- (underscore-joined) is the fallback now, not the primary.
  add(join(primaryDir, safeFile), "auto-safe", safeFile)
  add(join(primaryDir, legacyFile), "auto", legacyFile)
  add(join(legacyDir, safeFile), "legacy-safe", safeFile)
  add(join(legacyDir, legacyFile), "legacy", legacyFile)
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

------------------------------------------------------------------------
-- Same-name room disambiguation -- added 2026-07-17
------------------------------------------------------------------------
-- Per Steven: two rooms can share a name but differ in description/exits
-- (confirmed the generic_mapper package itself already keeps these as
-- properly separate rooms on the map -- this is purely a LocationView
-- picture-resolution problem, nothing here talks to the mapper at all).
--
-- variantDisplayName(room, index) is the one convention used for BOTH
-- the picture filename and the manual `mydsl location map` override key,
-- so they always agree: index 1 (the first-seen variant of any room
-- name) keeps the plain name -- e.g. "Wall Road" -> "Wall Road.png" --
-- so every one of the existing ~215 real picture files needs zero
-- renaming. Each later-discovered distinct variant gets the next slot:
-- "Wall Road (2)" -> "Wall Road (2).png", and so on.
function M.variantDisplayName(room, index)
  room = safeStr(room) or "Unknown room"
  index = tonumber(index) or 1
  if index <= 1 then return room end
  return room .. " (" .. index .. ")"
end

-- Three-value comparison: true (confirmed same), false (confirmed
-- different), nil (not enough data on one or both sides to say either
-- way). Keeping "unknown" distinct from "different" is what lets
-- resolveVariant() below fall back to the original room instead of
-- spawning a spurious new variant when a particular capture just didn't
-- have full data (e.g. a fallback data source with no description).
local function tristateMatch(a, b)
  if a == nil or b == nil or a == "" or b == "" then return nil end
  return a == b
end

-- resolveVariant(room, data) -- the actual matching ladder: description
-- first, exits as the deeper fallback (per Steven: "go deeper to exit
-- comparison if needed"), color stored per-variant for a future manual
-- tiebreak but not auto-split on today -- real per-line coloring is
-- confirmed to exist in DSL's output (title vs. body print in
-- consistently different colors), but there's no confirmed real case
-- yet of two SAME-NAMED rooms differing only in body color, so this
-- isn't wired into the automatic decision until one actually shows up.
-- No disambiguating data at all (neither description nor exits present
-- on this particular capture) resolves to the original variant #1
-- rather than guessing -- "stale/default beats a fabricated split."
function M.resolveVariant(room, data)
  room = safeStr(room)
  if not room then return nil end
  data = data or {}
  M.roomVariants = M.roomVariants or {}
  local list = M.roomVariants[room]

  if not list or #list == 0 then
    M.roomVariants[room] = {
      { description = data.description, exits = data.exits, color = data.descColor, seen = 1 },
    }
    M.saveVariants()
    return { name = room, index = 1, isNew = true }
  end

  for idx, v in ipairs(list) do
    if tristateMatch(data.description, v.description) == true then
      v.seen = (v.seen or 0) + 1
      return { name = M.variantDisplayName(room, idx), index = idx, isNew = false }
    end
  end
  for idx, v in ipairs(list) do
    if tristateMatch(data.exits, v.exits) == true
    and tristateMatch(data.description, v.description) ~= false then
      v.seen = (v.seen or 0) + 1
      return { name = M.variantDisplayName(room, idx), index = idx, isNew = false }
    end
  end

  if data.description == nil and data.exits == nil then
    return { name = M.variantDisplayName(room, 1), index = 1, isNew = false }
  end

  local idx = #list + 1
  table.insert(list, { description = data.description, exits = data.exits, color = data.descColor, seen = 1 })
  M.saveVariants()
  return { name = M.variantDisplayName(room, idx), index = idx, isNew = true }
end

function M.listVariants(room)
  room = safeStr(room)
  M.roomVariants = M.roomVariants or {}
  local names = {}
  if room then
    names = { room }
  else
    for r in pairs(M.roomVariants) do table.insert(names, r) end
    table.sort(names)
  end

  cecho("\n<cyan>[MyDSL.Location variants]<reset>\n")
  local shown = 0
  for _, r in ipairs(names) do
    local list = M.roomVariants[r]
    if list and (room or #list > 1) then
      shown = shown + 1
      cecho("  <green>" .. tostring(r) .. "<reset>\n")
      for idx, v in ipairs(list) do
        local file = M.variantDisplayName(r, idx) .. ".png"
        local descPreview = v.description and (v.description:sub(1, 60) .. (#v.description > 60 and "..." or "")) or "(none captured)"
        cecho(string.format(
          "    [%d] file=%-28s seen=%-4s exits=%-20s desc=%s\n",
          idx, file, tostring(v.seen or 0), tostring(v.exits or "(none)"), descPreview))
      end
    end
  end
  if shown == 0 then
    cecho(room and "  no variants recorded for that room yet\n" or "  no rooms have more than one variant yet\n")
  end
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
  return reg[M.windowName] or reg["Location"]
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

-- containImageHTML(label, path) -- added 2026-07-12, same real bug fix as
-- MyDSL_PortraitView.lua's function of the same name (see its comment for
-- the full root-cause writeup): border-image CSS paints into the *border*
-- area (a 9-slice UI-frame technique), not the label's content area, so it
-- never actually scaled a room picture into the box on any Mudlet version
-- -- confirmed here too since this file's own header comment says it
-- copied "the proven PortraitView/old CharPic render path" verbatim,
-- meaning it inherited the identical bug. Uses the same two real Mudlet/
-- Geyser APIs Portrait's fix uses: getImageSize(path) (native pixel
-- dimensions) and label:get_width()/get_height() (live rendered pixel
-- size), drawn via an <img> tag through label:echo() -- the same
-- mechanism MyDSL_MoonWeather.lua already uses successfully for its moon
-- icons.
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
-- location and portrait") -- same fix as MyDSL_PortraitView.lua's
-- function of the same name: fills the whole label exactly (no
-- letterboxing, no cropping), even if that distorts the picture's
-- proportions slightly to match the window's own shape.
local function stretchImageHTML(label, path)
  local boxW, boxH = label:get_width(), label:get_height()
  if not boxW or not boxH or boxW <= 0 or boxH <= 0 then return nil end
  return string.format(
    '<img src="file:///%s" width="%d" height="%d"/>',
    cssPath(path), math.floor(boxW), math.floor(boxH))
end

function M.applyBaseStyle()
  if not (M.ui and M.ui.image and M.ui.caption) then return end
  local border = M.config.frame and ("1px solid " .. themeBorder()) or "0px solid rgba(0,0,0,0)"
  M.ui.image:setStyleSheet(string.format([[
    background-color: %s;
    border: %s;
    border-radius: 6px;
  ]], themeBg(), border))

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
  -- Real bug found 2026-07-16 (investigating Steven's "something has
  -- changed in location and portrait" report): this never actually
  -- cleared M.ui.image, only updated the caption text -- entering a room
  -- with no picture right after one that HAD a picture left the previous
  -- room's stale image on screen instead of showing blank/missing state.
  M.ui.image:echo("")
  M.ui.caption:echo(caption or "")
  M.currentPath = nil
  M.currentRoom = nil
  M.currentSource = nil
  M.currentCaption = nil
end

function M.render(path, caption, source, room, missingCaption)
  M.ensureUI()
  if not (M.ui and M.ui.image and M.ui.caption) then return false end

  caption = caption or ""
  if not path or not exists(path) then
    -- missingCaption -- added 2026-07-17, per Steven ("mydsl location
    -- message needs to not goto main display but the location window").
    -- Lets a caller (M.refresh()'s new-variant notice) show its own
    -- specific text on the window's own caption label instead of this
    -- function's generic "No room picture" fallback -- this used to be
    -- the ONLY option, which is why that notice was going to the main
    -- console via echoC() instead: this branch previously had no way to
    -- surface caller-provided text at all. Takes priority over the
    -- blank/caption "missing" setting -- that toggle is about the
    -- routine "this room just has no picture" case; a new-variant notice
    -- is an actionable diagnostic the user needs regardless of whether
    -- they've turned off the routine chatter.
    if missingCaption then
      M.clear(missingCaption)
    elseif M.config.missing == "blank" then
      M.clear("")
    else
      M.clear("No room picture" .. (room and (": " .. room) or ""))
    end
    M.lastReason = "missing"
    return false
  end

  local p = cssPath(path)
  local border = M.config.frame and ("1px solid " .. themeBorder()) or "0px solid rgba(0,0,0,0)"

  local rendered = false
  if M.config.fit == "contain" then
    -- Real fix 2026-07-12 -- see containImageHTML()'s comment above for the
    -- full root-cause writeup (identical bug to MyDSL_PortraitView.lua).
    -- Falls back to the legacy border-image renderer only if
    -- getImageSize()/get_width()/get_height() genuinely fail.
    local html = containImageHTML(M.ui.image, path)
    if html then
      M.ui.image:setStyleSheet(string.format([[
        background-color: %s;
        border: %s;
        border-radius: 6px;
      ]], themeBg(), border))
      M.ui.image:echo(html)
      rendered = true
    end
  elseif M.config.fit == "stretch" or M.config.fit == "fill" then
    -- Real fix 2026-07-12, per Steven ("i prefer the old images stretching
    -- to fill, not fond of this border lookin location and portrait") --
    -- see stretchImageHTML()'s comment above.
    local html = stretchImageHTML(M.ui.image, path)
    if html then
      M.ui.image:setStyleSheet(string.format([[
        background-color: %s;
        border: %s;
        border-radius: 6px;
      ]], themeBg(), border))
      M.ui.image:echo(html)
      rendered = true
    end
  end

  if not rendered then
    -- cover (and contain/stretch, if the real renderers above couldn't
    -- run) use the old CharPic-style border-image renderer. Confirmed to
    -- not actually scale-to-fit correctly (see containImageHTML()'s
    -- comment) -- left as the fallback path, not redesigned this pass.
    M.ui.image:setStyleSheet(string.format([[
      background-color: %s;
      border: %s;
      border-radius: 6px;
      border-image: url("%s");
    ]], themeBg(), border, p))
    M.ui.image:echo("")
  end

  M.ui.caption:echo(caption)
  M.currentPath = path
  M.currentRoom = room
  M.currentSource = source
  M.currentCaption = caption
  -- Real bug fixed 2026-07-19, found during a full review: this was
  -- hardcoded to "cover" unconditionally, so `mydsl location status`'s
  -- render= field always claimed "cover" even when stretch/contain's own
  -- real renderer above actually ran successfully. Now reflects which
  -- path actually rendered this image.
  if rendered then
    M.renderMode = M.config.fit
  else
    M.renderMode = "cover"
  end
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

  local variant = M.resolveVariant(data.room, data)
  local displayName = (variant and variant.name) or data.room
  local path, source, file = M.pathForRoom(displayName)
  M.currentFile = file
  M.currentSource = source
  M.lastReason = reason or "refresh"

  local missingCaption = nil
  if variant and variant.isNew and variant.index > 1 and not (path and exists(path)) then
    -- A genuinely new variant of an already-known room name, and no
    -- picture exists for it yet -- surfaced directly in the Location
    -- window's own caption (fixed 2026-07-17, per Steven: "needs to not
    -- goto main display but the location window" -- this used to be an
    -- echoC() to the main console, easy to miss/spam-y; kept as compact
    -- as the title-bar fallback he floated, since the window's caption
    -- area is small) rather than the main console.
    missingCaption = string.format("No picture for this variant.\nExpected: \"%s\"",
      file or (displayName .. ".png"))
  end

  return M.render(path, M.captionForRoom(data, path, source), source, displayName, missingCaption)
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
  mydsl location variants [room name]
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

-- Re-apply background/border colors when the active theme switches.
-- Added 2026-07-11 alongside named ThemeEngine presets.
function M.onThemeChanged()
  M.applyBaseStyle()
  -- Real bug fixed 2026-07-19, found during a full review: passed a bare
  -- `nil` caption here, and since render() had nowhere to recover the
  -- last real caption text from, it defaulted to "" -- blanking the
  -- caption label on every single theme switch until the next room
  -- refresh. render() now stores M.currentCaption; reuse it here instead.
  if M.currentPath then M.render(M.currentPath, M.currentCaption, M.currentSource, M.currentRoom) end
end

function M.installEvents()
  if M.handlersInstalled then return end
  if registerAnonymousEventHandler then
    M.h1 = registerAnonymousEventHandler("gmcp.room_data", "MyDSL.Location.onRoomData")
    M.h2 = registerAnonymousEventHandler("gmcp.Room.Info", "MyDSL.Location.onRoomData")
    M.h3 = registerAnonymousEventHandler("onNewRoom", "MyDSL.Location.onRoomData")
    M.h4 = registerAnonymousEventHandler("MyDSL.theme.changed", "MyDSL.Location.onThemeChanged")
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
  if rest == "variants" then M.listVariants(); return end
  local variantsRoom = rest:match("^variants%s+(.+)$"); if variantsRoom then M.listVariants(variantsRoom); return end
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

        