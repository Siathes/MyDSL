
--[[=====================================================================
  MyDSL LiveView v1A14
  ----------------------------------------------------------------------
  Low-profile Room / Vitals window for MyDSL Alpha 1.

  Contract:
    - Display only.
    - Reads existing data sources:
        MyDSL.DB.live
        MyDSL.DB.score
        MyDSL.DB.xp
        MyDSL.DB.improve
        MyDSL.DB.time
        MyDSL.DB.timers
        MyDSL.Location.roomData()
        MyDSL.DB.room fallback
        gmcp room fallback
    - Does not parse score/improve/time itself.
    - Does not send game commands.
    - Uses Label-based bars, not Geyser.Gauge, to avoid GeyserColor issues.
    - Persists its own settings.
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.LiveView = MyDSL.LiveView or {}

local L = MyDSL.LiveView
L.version = "LiveView v1A14"
L.name = L.name or "MyDSL_Live"
L.title = L.title or "-= Live =-"

L.config = L.config or {}
L.config.shown = L.config.shown ~= false
L.config.font = tonumber(L.config.font or 10) or 10
L.config.titleFont = tonumber(L.config.titleFont or 12) or 12
L.config.barFont = tonumber(L.config.barFont or 8) or 8
L.config.mode = L.config.mode or "compact"
L.config.width = L.config.width or "34%"
L.config.height = L.config.height or "13%"
L.config.debug = L.config.debug == true

L.ui = L.ui or {}

local function ce(msg)
  cecho("\n<cyan>[MyDSL.Live]</cyan> " .. tostring(msg) .. "\n")
end

local function trim(s)
  s = tostring(s or "")
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function safeNum(v)
  v = tonumber(v)
  if v ~= nil then return v end
  return nil
end

local function pct(cur, max)
  cur, max = safeNum(cur), safeNum(max)
  if not cur or not max or max <= 0 then return 0 end
  local p = cur / max
  if p < 0 then p = 0 end
  if p > 1 then p = 1 end
  return p
end

local function percentNumber(s, fallback)
  local n = tostring(s or ""):match("([%d%.]+)%%")
  return tonumber(n) or fallback or 100
end


local function fmtNum(n)
  n = tonumber(n)
  if not n then return "--" end
  local s = tostring(math.floor(n))
  local left, num, right = string.match(s, "^([^%d]*%d)(%d*)(.-)$")
  if not left then return s end
  return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local function profileDir()
  local root = getMudletHomeDir and getMudletHomeDir() or "."
  return root .. "/MyDSL"
end

local function ensureDir(path)
  if lfs and lfs.mkdir then pcall(lfs.mkdir, path) end
  if os and os.execute then pcall(os.execute, "mkdir -p " .. string.format("%q", path)) end
end

function L.settingsFile()
  return profileDir() .. "/live_settings.lua"
end

function L.serializeSettings()
  local out = { "return {\n" }
  table.insert(out, string.format("  savedAt = %q,\n", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(out, string.format("  shown = %s,\n", L.config.shown and "true" or "false"))
  table.insert(out, string.format("  title = %q,\n", tostring(L.title or "-= Live =-")))
  table.insert(out, string.format("  font = %d,\n", tonumber(L.config.font) or 10))
  table.insert(out, string.format("  titleFont = %d,\n", tonumber(L.config.titleFont) or 12))
  table.insert(out, string.format("  barFont = %d,\n", math.max(8, tonumber(L.config.barFont) or 8)))
  table.insert(out, string.format("  mode = %q,\n", tostring(L.config.mode or "compact")))
  table.insert(out, "}\n")
  return table.concat(out)
end

function L.saveSettings()
  ensureDir(profileDir())
  local file = L.settingsFile()
  local f = io.open(file, "w")
  if not f then ce("could not save settings: " .. tostring(file)); return false end
  f:write(L.serializeSettings())
  f:close()
  L.settingsLoaded = true
  L.settingsFilePath = file
  return true
end

function L.loadSettings()
  local file = L.settingsFile()
  local f = io.open(file, "r")
  if not f then L.settingsLoaded = false; L.settingsFilePath = file; return false end
  f:close()

  local ok, data = pcall(dofile, file)
  if not ok or type(data) ~= "table" then
    ce("could not load settings: " .. tostring(data))
    L.settingsLoaded = false
    L.settingsFilePath = file
    return false
  end

  if data.shown ~= nil then L.config.shown = data.shown == true end
  if data.title and tostring(data.title) ~= "" then L.title = tostring(data.title) end
  L.config.font = tonumber(data.font or L.config.font) or L.config.font
  L.config.titleFont = tonumber(data.titleFont or L.config.titleFont) or L.config.titleFont
  L.config.barFont = tonumber(data.barFont or L.config.barFont) or L.config.barFont
  if data.mode == "compact" or data.mode == "full" then L.config.mode = data.mode end
  L.settingsLoaded = true
  L.settingsFilePath = file
  return true
end

local function stylePanel()
  return [[
    background-color: #0b1013;
    border: 1px solid #33434a;
    border-radius: 8px;
  ]]
end

local function styleText(size, color, weight, align)
  return string.format([[
    background-color: rgba(0,0,0,0);
    color: %s;
    border: 0px;
    font-family: "DejaVu Sans Mono", "Ubuntu Mono", monospace;
    font-size: %dpt;
    font-weight: %s;
    qproperty-alignment: '%s';
  ]], color or "#dbe7ea", tonumber(size or L.config.font) or 9, weight or "normal", align or "AlignLeft")
end

local function styleDivider()
  return [[
    background-color: #2b363b;
    border: 0px;
  ]]
end

local function styleBarBack()
  return [[
    background-color: #10171b;
    border: 1px solid #43545c;
    border-radius: 5px;
  ]]
end

local function styleBarFill(c1, c2, c3)
  return string.format([[
    background-color: QLinearGradient(
      x1: 0, y1: 0, x2: 0, y2: 1,
      stop: 0 %s,
      stop: 0.48 %s,
      stop: 0.52 %s,
      stop: 1 %s
    );
    border: 1px solid #111111;
    border-radius: 5px;
  ]], c1, c2, c3, c2)
end

local function styleBarText()
  return string.format([[
    background-color: rgba(0,0,0,0);
    color: #050607;
    border: 0px;
    font-family: "DejaVu Sans Mono", "Ubuntu Mono", monospace;
    font-size: %dpt;
    font-weight: bold;
    qproperty-alignment: 'AlignCenter';
  ]], math.max(6, tonumber(L.config.barFont) or 8))
end

function L.colorSet(kind)
  if kind == "hp" then return "#ff7777", "#cc2525", "#7d1010" end
  if kind == "mana" then return "#78baff", "#2a77d4", "#0d356d" end
  if kind == "move" then return "#83ff80", "#2baa39", "#0d5b18" end
  if kind == "improve" then return "#d7a7ff", "#8758c7", "#35204f" end
  if kind == "xp" then return "#d8b96a", "#a77426", "#4d3312" end
  return "#d0d0d0", "#808080", "#404040"
end

function L.roomData()
  if MyDSL and MyDSL.Location and MyDSL.Location.roomData then
    local ok, data = pcall(MyDSL.Location.roomData)
    if ok and type(data) == "table" then return data end
  end

  local candidates = {
    MyDSL and MyDSL.DB and MyDSL.DB.room,
    MyDSL and MyDSL.DB and MyDSL.DB.currentRoom,
    MyCore and MyCore.state and MyCore.state.gmcp and MyCore.state.gmcp.room_data,
    gmcp and gmcp.room_data,
    gmcp and gmcp.Room and gmcp.Room.Info,
  }

  for _, d in ipairs(candidates) do
    if type(d) == "table" then
      return {
        room = d.room or d.name or d.title,
        area = d.area or d.zone,
        terrain = d.terrain or d.sector,
        exits = d.exits,
        roomId = d.num or d.vnum or d.id,
        source = "fallback",
      }
    end
  end

  return {}
end

local function exitsText(exits)
  if type(exits) == "table" then
    local out = {}
    for k, v in pairs(exits) do
      if type(k) == "string" and v then table.insert(out, k)
      elseif type(v) == "string" then table.insert(out, v) end
    end
    table.sort(out)
    if #out > 0 then return table.concat(out, " ") end
  end
  return tostring(exits or "--")
end

function L.data()
  local db = MyDSL and MyDSL.DB or {}
  local live = db.live or {}
  local score = db.score or {}
  local timers = db.timers or {}
  local room = L.roomData() or {}
  local tm = timers.worldTime or db.time or {}
  local imp = timers.improve or db.improve or {}
  local xp = db.xp or {}
  local prompt = db.prompt or {}
  local pnpPrompt = _G.dslpnp and _G.dslpnp.prompt or nil

  local hp = live.hp or score.hp
  local maxhp = live.maxhp or score.maxhp
  local mana = live.mana or score.mana
  local maxmana = live.maxmana or score.maxmana
  local move = live.move or score.move
  local maxmove = live.maxmove or score.maxmove

  local xptotal = xp.total or score.xp or (pnpPrompt and tonumber(pnpPrompt.curxp))
  local xpToLevel = xp.toLevel or score.xpToLevel or score.xpToLevelText or prompt.xptnl or (pnpPrompt and tonumber(pnpPrompt.xptnl))
  local xppct = xp.percent or score.xpPercent
  if not xppct and score.level and tonumber(score.level) >= 51 then xppct = nil end

  local rawPromptExits = prompt.exits or (pnpPrompt and pnpPrompt.exits)

  return {
    roomName = trim(room.room or room.name or "Unknown Room"),
    area = trim(room.area or "--"),
    terrain = trim(room.terrain or "--"),
    exits = rawPromptExits or exitsText(room.exits),
    roomId = room.roomId or room.id or room.vnum,
    clock = tm.clock or (db.time and db.time.clock) or "--",
    day = tm.day or (db.time and db.time.day) or "",
    dayName = tm.dayName or (db.time and db.time.dayName) or "",
    ordinal = tm.ordinal or (db.time and db.time.ordinal) or "",
    month = tm.month or (db.time and db.time.month) or "",
    monthName = tm.monthName or (db.time and db.time.monthName) or "",
    hp = hp, maxhp = maxhp,
    mana = mana, maxmana = maxmana,
    move = move, maxmove = maxmove,
    xp = xptotal, xpPercent = xppct, xpToLevel = xpToLevel,
    improveText = imp.text or (imp.skill and (tostring(imp.skill) .. " " .. tostring(imp.percent or "?") .. "%")),
    improveSkill = imp.skill,
    improvePercent = imp.percent,
    improveRemaining = imp.remaining,
    combat = live.combat,
    stance = score.stance or live.stance,
    language = score.language or live.language,
    riding = live.riding,
    flying = live.flying,
    fighting = live.fighting,
  }
end

function L.ensureUI()
  if L.ui.win and L.ui.panel then return true end

  local WinClass = Geyser and (Geyser.UserWindow or Geyser.Window)
  if not WinClass then ce("Geyser.UserWindow unavailable"); return false end

  L.ui.win = WinClass:new({
    name = L.name,
    x = "32%",
    y = "77%",
    width = L.config.width,
    height = L.config.height,
  })

  if L.ui.win.setTitle then pcall(function() L.ui.win:setTitle(L.title) end) end

  L.ui.panel = Geyser.Label:new({ name=L.name.."_Panel", x=0, y=0, width="100%", height="100%" }, L.ui.win)

  -- v1A14 layout:
  -- Room title spans the full top. Left card carries terrain/exits, time,
  -- and XP/TNL. Right side bars are pushed down so the title can breathe.
  L.ui.roomTitle = Geyser.Label:new({ name=L.name.."_RoomTitle", x="3%", y="4%",  width="93%", height="18%" }, L.ui.win)
  -- Full-width passthrough exits line directly below the room name.
  L.ui.exitsCon  = Geyser.MiniConsole:new({ name=L.name.."_ExitsCon", x="3%", y="24%", width="93%", height="12%" }, L.ui.win)

  -- Left lower card: terrain, time, XP/TNL.
  L.ui.roomMeta  = Geyser.Label:new({ name=L.name.."_RoomMeta",  x="4%", y="43%", width="40%", height="10%" }, L.ui.win)
  L.ui.timeLine  = Geyser.Label:new({ name=L.name.."_Time",      x="4%", y="57%", width="40%", height="18%" }, L.ui.win)
  L.ui.xpLine    = Geyser.Label:new({ name=L.name.."_XPLine",    x="4%", y="80%", width="40%", height="12%" }, L.ui.win)
  L.ui.vDivider  = Geyser.Label:new({ name=L.name.."_Divider",   x="48%", y="43%", width="1px", height="49%" }, L.ui.win)

  L.ui.bars = {}
  L.ui.bars.hp      = L.makeBar("HP",      "hp",      "53%", "43%", "42%", "10%")
  L.ui.bars.mana    = L.makeBar("Mana",    "mana",    "53%", "56%", "42%", "10%")
  L.ui.bars.move    = L.makeBar("Move",    "move",    "53%", "69%", "42%", "10%")
  L.ui.bars.improve = L.makeBar("Improve", "improve", "53%", "82%", "42%", "10%")

  L.applyStyles()

  if L.config.shown then L.show(false) else L.hide(false) end
  return true
end

function L.makeBar(label, key, x, y, w, h)
  local bar = {}
  bar.maxWidth = percentNumber(w, 42)
  bar.back = Geyser.Label:new({ name=L.name.."_"..key.."_Back", x=x, y=y, width=w, height=h }, L.ui.win)
  bar.fill = Geyser.Label:new({ name=L.name.."_"..key.."_Fill", x=x, y=y, width="1%", height=h }, L.ui.win)
  bar.text = Geyser.Label:new({ name=L.name.."_"..key.."_Text", x=x, y=y, width=w, height=h }, L.ui.win)
  return bar
end

function L.applyStyles()
  if not L.ui.panel then return end
  L.ui.panel:setStyleSheet(stylePanel())
  L.ui.roomTitle:setStyleSheet(styleText(L.config.titleFont, "#ffd166", "bold", "AlignLeft"))
  L.ui.roomMeta:setStyleSheet(styleText(math.max(12, L.config.font + 2), "#a8ccd1", "bold", "AlignLeft"))
  if L.ui.exitsCon then
    pcall(function()
      L.ui.exitsCon:setFontSize(math.max(8, tonumber(L.config.font) or 10))
      L.ui.exitsCon:setColor(11, 16, 19)
      L.ui.exitsCon:setWrap(false)
    end)
  end
  L.ui.timeLine:setStyleSheet(styleText(math.max(12, L.config.font + 2), "#f2d27a", "bold", "AlignLeft"))
  if L.ui.xpLine then L.ui.xpLine:setStyleSheet(styleText(math.max(12, L.config.font + 2), "#d8b96a", "bold", "AlignLeft")) end
  L.ui.vDivider:setStyleSheet(styleDivider())

  for key, bar in pairs(L.ui.bars or {}) do
    bar.back:setStyleSheet(styleBarBack())
    local c1, c2, c3 = L.colorSet(key)
    bar.fill:setStyleSheet(styleBarFill(c1, c2, c3))
    bar.text:setStyleSheet(styleBarText())
  end
end

local function html(s)
  s = tostring(s or "")
  s = s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;")
  return s
end

local function infoFont()
  return math.max(12, (tonumber(L.config.font) or 10) + 2)
end

local function infoStyle(color, weight)
  return "font-size:" .. tostring(infoFont()) .. "pt; color:" .. tostring(color or "#dbe7ea") ..
         "; font-weight:" .. tostring(weight or "bold") .. ";"
end


local function exitBadgeText(exits)
  -- Do not invent exit colors here. DSL/PNP can provide color-coded prompt
  -- exits, but GMCP/mapper exits are plain text. Until we have raw prompt
  -- color markup wired directly to the label, keep this neutral.
  exits = tostring(exits or "--")
  if exits == "" then exits = "--" end
  return "<span style='" .. infoStyle("#d7e6e9", "bold") .. "'>" .. html(exits) .. "</span>"
end

local function terrainBadge(t)
  t = trim(t or "--")
  if t == "" then t = "--" end
  return "<span style='" .. infoStyle("#74d3e0", "bold") .. "'>" .. html(t) .. "</span>"
end


local function splitRoomName(s)
  s = tostring(s or "Unknown Room")
  if #s <= 34 then return html(s) end

  local target = math.floor(#s / 2)
  local best = nil
  for pos = 16, #s - 10 do
    if s:sub(pos, pos) == " " then
      if not best or math.abs(pos - target) < math.abs(best - target) then best = pos end
    end
  end

  if best and #s <= 72 then
    return html(s:sub(1, best - 1)) ..
           "<br><span style='font-size:" .. tostring(math.max(10, L.config.titleFont - 2)) .. "pt; color:#ffd98a;'>" ..
           html(s:sub(best + 1)) .. "</span>"
  end

  return html(s:sub(1, 42)) .. "..."
end

local function compactDateText(d)
  local clock = (d.clock and d.clock ~= "--") and d.clock or "--"
  local day = (d.dayName and d.dayName ~= "") and ("Day of " .. d.dayName) or ""
  local month = ""
  if d.ordinal and d.ordinal ~= "" and d.monthName and d.monthName ~= "" then
    month = tostring(d.ordinal) .. " Month of the " .. tostring(d.monthName)
  elseif d.month and d.month ~= "" then
    month = tostring(d.month)
  end

  local sep = "<span style='font-size:" .. tostring(infoFont()) .. "pt; color:#6f7d82; font-weight:bold;'>|</span>"
  if day ~= "" and month ~= "" then
    return "<span style='" .. infoStyle("#f2d27a", "bold") .. "'>" .. html(clock) .. "</span>" ..
           " &nbsp; " .. sep .. " &nbsp; " ..
           "<span style='" .. infoStyle("#f2d27a", "bold") .. "'>" .. html(day) .. "</span>" ..
           "<br><span style='" .. infoStyle("#c6b36f", "bold") .. "'>" .. html(month) .. "</span>"
  elseif day ~= "" then
    return "<span style='" .. infoStyle("#f2d27a", "bold") .. "'>" .. html(clock) .. "</span>" ..
           " &nbsp; " .. sep .. " &nbsp; " ..
           "<span style='" .. infoStyle("#f2d27a", "bold") .. "'>" .. html(day) .. "</span>"
  end

  return "<span style='" .. infoStyle("#f2d27a", "bold") .. "'>" .. html(clock) .. "</span>"
end

function L.setBar(key, cur, max, text)
  local bar = L.ui.bars and L.ui.bars[key]
  if not bar then return end
  local p = pct(cur, max)
  local width = math.floor((tonumber(bar.maxWidth) or 42) * p + 0.5)
  if width < 1 and p > 0 then width = 1 end
  pcall(function() bar.fill:resize(tostring(width).."%", nil) end)
  bar.text:echo("<center>" .. html(text or "") .. "</center>")
end

function L.setBarPercent(key, percent, text)
  local bar = L.ui.bars and L.ui.bars[key]
  if not bar then return end
  local p = tonumber(percent)
  if not p then p = 0 end
  if p > 1 then p = p / 100 end
  if p < 0 then p = 0 end
  if p > 1 then p = 1 end
  local width = math.floor((tonumber(bar.maxWidth) or 42) * p + 0.5)
  if width < 1 and p > 0 then width = 1 end
  pcall(function() bar.fill:resize(tostring(width).."%", nil) end)
  bar.text:echo("<center>" .. html(text or "") .. "</center>")
end

local function dateText(d)
  local a = {}
  if d.clock and d.clock ~= "--" then table.insert(a, d.clock) end
  if d.dayName and d.dayName ~= "" then table.insert(a, "Day of " .. d.dayName) end
  if d.ordinal and d.ordinal ~= "" and d.monthName and d.monthName ~= "" then
    table.insert(a, tostring(d.ordinal) .. " Month of the " .. tostring(d.monthName))
  elseif d.month and d.month ~= "" then
    table.insert(a, tostring(d.month))
  end
  if #a == 0 then return "--" end
  return table.concat(a, "<br>")
end


function L.setColoredExitsFromCurrentLine()
  if not L.ensureUI() then return false end

  local line = getCurrentLine and getCurrentLine() or ""
  if not tostring(line):match("^%s*%[Exits:%s*") then return false end

  MyDSL = MyDSL or {}
  MyDSL.DB = MyDSL.DB or {}
  MyDSL.DB.room = MyDSL.DB.room or {}
  MyDSL.DB.room.exitsColoredSource = "room-line"
  MyDSL.DB.room.exitsColoredUpdatedAt = os.time()
  MyDSL.DB.room.exitsLine = tostring(line)

  if L.ui and L.ui.exitsCon then
    pcall(function()
      clearWindow(L.name .. "_ExitsCon")
      selectCurrentLine()
      copy()
      appendBuffer(L.name .. "_ExitsCon")
      deselect()
    end)
  end

  raiseEvent("MyDSL.Live.ExitsColoredUpdated")
  return true
end

function L.setNeutralExitsLine(d)
  if not L.ui or not L.ui.exitsCon then return end
  pcall(function()
    clearWindow(L.name .. "_ExitsCon")
    cecho(L.name .. "_ExitsCon", "<grey>[Exits: <white>" .. tostring(d.exits or "--") .. "<grey> ]")
  end)
end

function L.render(reason)
  if not L.ensureUI() then return end
  local d = L.data()

  L.ui.roomTitle:echo("<span style='font-size:" .. tostring(L.config.titleFont) .. "pt; font-weight:bold; color:#ffd166;'>" .. splitRoomName(d.roomName) .. "</span>")

  local metaBits = {}
  if d.terrain and d.terrain ~= "" and d.terrain ~= "--" then
    table.insert(metaBits, terrainBadge(d.terrain))
  end
  L.ui.roomMeta:echo(table.concat(metaBits, " "))
  if not (MyDSL and MyDSL.DB and MyDSL.DB.room and MyDSL.DB.room.exitsColoredSource == "room-line") then
    L.setNeutralExitsLine(d)
  end

  L.ui.timeLine:echo(compactDateText(d))

  local xpLine = d.xp and ("XP " .. fmtNum(d.xp)) or "XP --"
  if d.xpToLevel then xpLine = xpLine .. "   TNL " .. fmtNum(d.xpToLevel) end
  if L.ui.xpLine then L.ui.xpLine:echo("<span style='" .. infoStyle("#d8b96a", "bold") .. "'>" .. html(xpLine) .. "</span>") end

  L.setBar("hp", d.hp, d.maxhp, "HP " .. fmtNum(d.hp) .. " / " .. fmtNum(d.maxhp) .. " (" .. tostring(math.floor(pct(d.hp,d.maxhp)*100+0.5)) .. "%)")
  L.setBar("mana", d.mana, d.maxmana, "Mana " .. fmtNum(d.mana) .. " / " .. fmtNum(d.maxmana) .. " (" .. tostring(math.floor(pct(d.mana,d.maxmana)*100+0.5)) .. "%)")
  L.setBar("move", d.move, d.maxmove, "Move " .. fmtNum(d.move) .. " / " .. fmtNum(d.maxmove) .. " (" .. tostring(math.floor(pct(d.move,d.maxmove)*100+0.5)) .. "%)")

  local impText = d.improveText and ("Imp " .. tostring(d.improveText)) or "Imp --"
  L.setBarPercent("improve", tonumber(d.improvePercent) or 0, impText)

  -- XP is rendered on the left identity card, not as a comparison bar.
  L.lastReason = reason or "render"
end

function L.show(save)
  L.config.shown = true
  if L.ui and L.ui.win then pcall(function() L.ui.win:show() end) end
  L.render("show")
  if save ~= false then L.saveSettings() end
end

function L.hide(save)
  L.config.shown = false
  if L.ui and L.ui.win then pcall(function() L.ui.win:hide() end) end
  if save ~= false then L.saveSettings() end
end

function L.rebuild()
  if L.ui and L.ui.win then pcall(function() L.ui.win:hide() end) end
  L.ui = {}
  L.ensureUI()
  L.render("rebuild")
end

function L.setFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl live font <size>"); return end
  if size < 6 then size = 6 end
  if size > 18 then size = 18 end
  L.config.font = size
  L.applyStyles()
  L.render("font")
  L.saveSettings()
  ce("font=" .. tostring(size))
end

function L.setTitleFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl live titlefont <size>"); return end
  if size < 8 then size = 8 end
  if size > 24 then size = 24 end
  L.config.titleFont = size
  L.applyStyles()
  L.render("titlefont")
  L.saveSettings()
  ce("titleFont=" .. tostring(size))
end

function L.setBarFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl live barfont <size>"); return end
  if size < 6 then size = 6 end
  if size > 14 then size = 14 end
  L.config.barFont = size
  L.applyStyles()
  L.render("barfont")
  L.saveSettings()
  ce("barFont=" .. tostring(size))
end

function L.setTitle(title, silent)
  title = trim(title or "")
  if title == "" then title = "-= Live =-" end
  L.title = title
  if L.ui and L.ui.win and L.ui.win.setTitle then pcall(function() L.ui.win:setTitle(title) end) end
  L.saveSettings()
  if not silent then ce("title=" .. title) end
end

function L.setMode(mode)
  mode = trim(mode):lower()
  if mode ~= "compact" and mode ~= "full" then ce("usage: mydsl live mode compact|full"); return end
  L.config.mode = mode
  L.render("mode")
  L.saveSettings()
  ce("mode=" .. mode)
end

function L.status()
  local d = L.data()
  ce("version=" .. L.version ..
     "; shown=" .. tostring(L.config.shown) ..
     "; room=" .. tostring(d.roomName) ..
     "; hp=" .. tostring(d.hp) .. "/" .. tostring(d.maxhp) ..
     "; mana=" .. tostring(d.mana) .. "/" .. tostring(d.maxmana) ..
     "; move=" .. tostring(d.move) .. "/" .. tostring(d.maxmove) ..
     "; time=" .. tostring(d.clock) ..
     "; xp=" .. tostring(d.xp) ..
     "; xptnl=" .. tostring(d.xpToLevel) ..
     "; exits=" .. tostring(d.exits) ..
     "; exitsColored=" .. tostring(MyDSL and MyDSL.DB and MyDSL.DB.room and MyDSL.DB.room.exitsColoredSource or "nil") ..
     "; improve=" .. tostring(d.improveText) ..
     "; settingsLoaded=" .. tostring(L.settingsLoaded) ..
     "; settingsFile=" .. tostring(L.settingsFilePath or L.settingsFile()) ..
     "; aliasVersion=" .. tostring(L.aliasVersion) ..
     "; reason=" .. tostring(L.lastReason))
end

function L.installHandlers()
  if L.handlersInstalled then return end
  L.handlersInstalled = true
  L.handlers = L.handlers or {}
  local events = {
    "MyDSL.Live.Updated",
    "MyDSL.Status.Updated",
    "MyDSL.Score.Updated",
    "MyDSL.Time.Updated",
    "MyDSL.Improve.Updated",
    "MyDSL.Progress.Updated",
    "MyDSL.Timers.Updated",
    "MyDSL.Room.Updated",
    "gmcp.room_data",
    "gmcp.Room.Info",
  }

  for _, ev in ipairs(events) do
    if registerAnonymousEventHandler then
      local ok, id = pcall(function()
        return registerAnonymousEventHandler(ev, function() if MyDSL and MyDSL.LiveView then MyDSL.LiveView.render(ev) end end)
      end)
      if ok and id then table.insert(L.handlers, id) end
    end
  end
end

function L.installAliases()
  -- Versioned temp aliases. Older LiveView revisions may leave
  -- L.aliasesInstalled=true in memory, so do not rely on that flag alone.
  if L.aliasVersion == L.version then return end
  L.aliasVersion = L.version

  tempAlias([[^mydsl live status$]], [[MyDSL.LiveView.status()]])
  tempAlias([[^mydsl live show$]], [[MyDSL.LiveView.show()]])
  tempAlias([[^mydsl live hide$]], [[MyDSL.LiveView.hide()]])
  tempAlias([[^mydsl live rebuild$]], [[MyDSL.LiveView.rebuild()]])
  tempAlias([[^mydsl live refresh$]], [[MyDSL.LiveView.render("manual")]])
  tempAlias([[^mydsl live save$]], [[MyDSL.LiveView.saveSettings(); MyDSL.LiveView.status()]])
  tempAlias([[^mydsl live reload settings$]], [[MyDSL.LiveView.loadSettings(); MyDSL.LiveView.rebuild(); MyDSL.LiveView.status()]])
  tempAlias([[^mydsl live font ([0-9]+)$]], [[MyDSL.LiveView.setFont(matches[2])]])
  tempAlias([[^mydsl live titlefont ([0-9]+)$]], [[MyDSL.LiveView.setTitleFont(matches[2])]])
  tempAlias([[^mydsl live barfont ([0-9]+)$]], [[MyDSL.LiveView.setBarFont(matches[2])]])
  tempAlias([[^mydsl live title (.+)$]], [[MyDSL.LiveView.setTitle(matches[2])]])
  tempAlias([[^mydsl live mode (compact|full)$]], [[MyDSL.LiveView.setMode(matches[2])]])
  tempAlias([[^mydsl live layout$]], [[MyDSL.LiveView.rebuild(); MyDSL.LiveView.status()]])
  L.aliasesInstalled = true
end

function L.installExitsTrigger()
  if L.exitsTriggerInstalled and L.exitsTriggerVersion == L.version then return end
  if tempRegexTrigger then
    tempRegexTrigger([[^\s*\[Exits:\s*.*\]\s*$]], [[if MyDSL and MyDSL.LiveView and MyDSL.LiveView.setColoredExitsFromCurrentLine then MyDSL.LiveView.setColoredExitsFromCurrentLine() end]])
  elseif tempTrigger then
    tempTrigger("[Exits:", [[if MyDSL and MyDSL.LiveView and MyDSL.LiveView.setColoredExitsFromCurrentLine then MyDSL.LiveView.setColoredExitsFromCurrentLine() end]])
  end
  L.exitsTriggerInstalled = true
  L.exitsTriggerVersion = L.version
end

function L.boot()
  L.loadSettings()
  L.installAliases()
  L.installHandlers()
  L.installExitsTrigger()
  L.ensureUI()
  L.render("boot")
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. L.version) end
end

L.boot()
