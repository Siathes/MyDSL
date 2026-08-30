
--[[=====================================================================
  MyDSL.AffectsView v4C16 QuietBoot
  ----------------------------------------------------------------------
  Compact affects window for MyDSL v4C.

  Design:
    - GMCP-first from gmcp.affect_data.affects.
    - Text fallback from the `affects` command.
    - Uses MyDSL WindowCore when present; falls back to Geyser.UserWindow.
    - Per-character profiles:
        <profile>/MyDSL/affects/<CharacterName>.lua
    - Strictly saves/loads tracked list, settings, custom commands, and lastAffects snapshot per character; new characters start with an empty tracked list.
    - Manual interactions only: PNP-style click links, respell, and spellup commands.
    - No automatic recast, no SpellCore changes, no RPscript tie-in.
    - Compact layout:
        no top "Affects | name" header
        no top separator
        missing line wraps instead of scrolling off-screen

  Commands:
    mydsl affects status
    mydsl affects profile
    mydsl affects save
    mydsl affects sync
    mydsl affects refresh
    mydsl affects show
    mydsl affects hide
    mydsl affects clear
    mydsl affects font <size>
    mydsl affects wrap <columns>
    mydsl affects columns <count>
    mydsl affects width <columns>
    mydsl affects cast <name>
    mydsl affects respell [optional,list,!excluded]
    mydsl affects command <name> <command>
    mydsl affects track <name>
    mydsl affects untrack <name>
    mydsl affects tracked
    mydsl affects reset tracked
    mydsl affects clear tracked

  Short aliases:
    affdebug
    affsync
    affrefresh
=====================================================================]]--

MyDSL = MyDSL or {}
MyDSL.Affects = MyDSL.Affects or {}

local A = MyDSL.Affects
A.version = "AffectsView v4C16 QuietBoot"

local DEFAULT_CONFIG = {
  windowId = "Affects",
  windowName = "MyDSL_Affects",
  title = "Affects",
  fontSize = 8,
  columns = 2,
  columnWidth = 28,
  missingWrapWidth = 56,
  lowCycles = 5,
  castCommand = "cast",
  timerMode = "cycles",
  useGmcp = true,
  useTextFallback = true,
  debug = false,
}

A.config = A.config or {}
A.config.windowId = A.config.windowId or "Affects"
A.config.windowName = A.config.windowName or "MyDSL_Affects"
A.config.title = A.config.title or "Affects"
A.config.fontSize = tonumber(A.config.fontSize or 8) or 8
A.config.columns = tonumber(A.config.columns or 2) or 2
A.config.columnWidth = tonumber(A.config.columnWidth or 28) or 28
A.config.missingWrapWidth = tonumber(A.config.missingWrapWidth or 56) or 56
A.config.lowCycles = tonumber(A.config.lowCycles or 5) or 5
A.config.castCommand = A.config.castCommand or "cast"
-- Display mode follows old/PNP style by default:
--   cycles = show DSL affect cycles only
--   time   = show estimated real-time countdown only
--   both   = show cycles plus estimated real-time countdown
A.config.timerMode = A.config.timerMode or "cycles"
A.config.useGmcp = A.config.useGmcp ~= false
A.config.useTextFallback = A.config.useTextFallback ~= false
A.config.debug = A.config.debug == true

A.list = A.list or {}
A.tracked = A.tracked or {}
A.state = A.state or {
  source = "none",
  capture = false,
  captureCount = 0,
  lastSync = nil,
  lastError = nil,
  loadedCharacter = nil,
}
A.ids = A.ids or {}
A.handlers = A.handlers or {}
A.aliasesInstalled = A.aliasesInstalled or false
A.customCommands = A.customCommands or {}

-- PNP/old myAffects command routing.
A.songs = A.songs or {
  ["song of war"] = true,
  ["no eyes"] = true,
  ["weakness within"] = true,
  ["we come, we come"] = true,
  ["lullaby"] = true,
  ["nightmare"] = true,
  ["shield of words"] = true,
  ["song of charm"] = true,
  ["green leaf"] = true,
}

A.skills = A.skills or {
  ["berserk"] = true,
  ["sneak"] = true,
}

-- Optional starter list retained for future import/seed commands; no longer auto-applied.
local DEFAULT_TRACKED = {
  "armor",
  "bless",
  "detect evil",
  "detect good",
  "detect hidden",
  "detect invis",
  "detect magic",
  "fly",
  "frenzy",
  "inspire",
  "sanctuary",
  "shield",
  "stone skin",
  "haste",
  "giant strength",
  "bark skin",
  "nature growth",
}

local function ce(msg) cecho("\n<cyan>[MyDSL.Affects]<reset> " .. tostring(msg) .. "\n") end
local function dbg(msg) if A.config.debug then ce("<grey>" .. tostring(msg) .. "<reset>") end end
local function trim(s) s = tostring(s or ""); return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function lower(s) return string.lower(trim(s or "")) end

function A.charName()
  if gmcp and gmcp.login_data and gmcp.login_data.name and gmcp.login_data.name ~= "" then
    return tostring(gmcp.login_data.name)
  end
  if MyCore and MyCore.getChar then
    local ok, name = pcall(MyCore.getChar)
    if ok and name and name ~= "" then return tostring(name) end
  end
  return "Unknown"
end

local function profileDir()
  local root = getMudletHomeDir and getMudletHomeDir() or "."
  return root .. "/MyDSL"
end

local function affectsDir()
  return profileDir() .. "/affects"
end

local function safeFileName(s)
  s = tostring(s or "Unknown"):gsub("[^%w_%-%.]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "Unknown" end
  return s
end

function A.dataFile()
  return affectsDir() .. "/" .. safeFileName(A.charName()) .. ".lua"
end

local function mkdir(path)
  if lfs and lfs.mkdir then pcall(lfs.mkdir, path) end
end

local function ensureDirs()
  mkdir(profileDir())
  mkdir(affectsDir())
end

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t or {}) do table.insert(keys, k) end
  table.sort(keys)
  return keys
end

local function serializeProfile()
  local out = { "return {\n" }
  table.insert(out, string.format("  character = %q,\n", A.charName()))
  table.insert(out, string.format("  savedAt = %q,\n", os.date("%Y-%m-%d %H:%M:%S")))

  table.insert(out, "  settings = {\n")
  table.insert(out, string.format("    title = %q,\n", tostring(A.config.title or "Affects")))
  table.insert(out, string.format("    fontSize = %d,\n", tonumber(A.config.fontSize) or 8))
  table.insert(out, string.format("    columns = %d,\n", tonumber(A.config.columns) or 2))
  table.insert(out, string.format("    columnWidth = %d,\n", tonumber(A.config.columnWidth) or 28))
  table.insert(out, string.format("    missingWrapWidth = %d,\n", tonumber(A.config.missingWrapWidth) or 56))
  table.insert(out, string.format("    timerMode = %q,\n", tostring(A.config.timerMode or "cycles")))
  table.insert(out, string.format("    castCommand = %q,\n", tostring(A.config.castCommand or "cast")))
  table.insert(out, "  },\n")

  table.insert(out, "  customCommands = {\n")
  for _, k in ipairs(sortedKeys(A.customCommands or {})) do
    if A.customCommands[k] then table.insert(out, string.format("    [%q] = %q,\n", k, tostring(A.customCommands[k]))) end
  end
  table.insert(out, "  },\n")

  table.insert(out, "  tracked = {\n")
  for _, k in ipairs(sortedKeys(A.tracked)) do
    if A.tracked[k] then table.insert(out, string.format("    [%q] = true,\n", k)) end
  end
  table.insert(out, "  },\n")

  table.insert(out, "  lastAffects = {\n")
  for _, k in ipairs(sortedKeys(A.list)) do
    local e = A.list[k]
    table.insert(out, string.format("    [%q] = { name = %q, duration = %s, source = %q },\n",
      k, tostring(e.name or k), tostring(tonumber(e.duration) or -1), tostring(e.source or "unknown")))
  end
  table.insert(out, "  }\n}\n")
  return table.concat(out)
end

function A.save()
  ensureDirs()
  local f = io.open(A.dataFile(), "w")
  if not f then ce("<red>save failed: " .. A.dataFile() .. "<reset>"); return false end
  f:write(serializeProfile())
  f:close()
  return true
end

function A.resetProfileState()
  -- Per-character state. Window identity stays global, spell tracking/options do not.
  A.list = {}
  A.tracked = {}
  A.customCommands = {}

  A.config.title = DEFAULT_CONFIG.title or "Affects"
  A.config.fontSize = tonumber(DEFAULT_CONFIG.fontSize) or 8
  A.config.columns = tonumber(DEFAULT_CONFIG.columns) or 2
  A.config.columnWidth = tonumber(DEFAULT_CONFIG.columnWidth) or 28
  A.config.missingWrapWidth = tonumber(DEFAULT_CONFIG.missingWrapWidth) or 56
  A.config.lowCycles = tonumber(DEFAULT_CONFIG.lowCycles) or 5
  A.config.castCommand = DEFAULT_CONFIG.castCommand or "cast"
  A.config.timerMode = DEFAULT_CONFIG.timerMode or "cycles"
  A.config.useGmcp = DEFAULT_CONFIG.useGmcp ~= false
  A.config.useTextFallback = DEFAULT_CONFIG.useTextFallback ~= false

  A.state.source = "profile-reset"
  A.state.capture = false
  A.state.captureCount = 0
  A.state.lastSync = nil
  A.state.lastError = nil
end

function A.loadData()
  ensureDirs()
  local file = A.dataFile()
  local f = io.open(file, "r")
  if not f then return false end
  f:close()

  local ok, data = pcall(dofile, file)
  if ok and type(data) == "table" then
    if type(data.tracked) == "table" then A.tracked = data.tracked end
    if type(data.settings) == "table" then
      if data.settings.title and tostring(data.settings.title) ~= "" then A.config.title = tostring(data.settings.title) end
      A.config.fontSize = tonumber(data.settings.fontSize or A.config.fontSize) or A.config.fontSize
      A.config.columns = tonumber(data.settings.columns or A.config.columns) or A.config.columns
      A.config.columnWidth = tonumber(data.settings.columnWidth or A.config.columnWidth) or A.config.columnWidth
      A.config.missingWrapWidth = tonumber(data.settings.missingWrapWidth or A.config.missingWrapWidth) or A.config.missingWrapWidth
      if data.settings.timerMode == "cycles" or data.settings.timerMode == "time" or data.settings.timerMode == "both" then
        A.config.timerMode = data.settings.timerMode
      end
      if data.settings.castCommand then A.config.castCommand = tostring(data.settings.castCommand) end
    end
    if type(data.customCommands) == "table" then A.customCommands = data.customCommands end
    return true
  end
  return false
end

function A.profile()
  A.checkCharacterProfile()
  ce("character=" .. A.charName() ..
     "; loadedCharacter=" .. tostring(A.state.loadedCharacter) ..
     "; profileLoaded=" .. tostring(A.state.profileLoaded) ..
     "; file=" .. A.dataFile())
end

function A.ensureDefaults()
  -- v4C8: profiles start clean. Old versions seeded DEFAULT_TRACKED,
  -- but different DSL classes/characters track different buffs.
  A.tracked = A.tracked or {}
end

function A.loadProfileForCurrentChar(force)
  local char = A.charName()
  if not force and A.state.loadedCharacter == char then return false end

  -- Save the previous character profile before switching, but never save Unknown.
  if A.state.loadedCharacter and A.state.loadedCharacter ~= "Unknown" and A.state.loadedCharacter ~= char then
    pcall(function() A.save() end)
  end

  A.resetProfileState()
  local loaded = A.loadData()
  A.ensureDefaults()
  A.state.loadedCharacter = char
  A.state.profileLoaded = loaded == true
  A.state.source = loaded and "profile" or "profile-defaults"
  return true
end

function A.checkCharacterProfile()
  return A.loadProfileForCurrentChar(false)
end

local function killId(id) if id and killTrigger then pcall(killTrigger, id) end end

local function clearWin()
  pcall(function() if clearWindow then clearWindow(A.config.windowName) end end)
  pcall(function() if A.window and A.window.clear then A.window:clear() end end)
end

local function wcecho(text)
  local ok = pcall(function() cecho(A.config.windowName, text) end)
  if not ok then cecho(text) end
end

local function colorForDuration(d)
  d = tonumber(d)
  if not d then return "<grey>" end
  if d <= A.config.lowCycles then return "<red>" end
  if d <= 10 then return "<yellow>" end
  return "<green>"
end

function A.ensureWindow()
  if MyDSL and MyDSL.Windows and type(MyDSL.Windows.ensure) == "function" then
    local ok, win = pcall(function()
      return MyDSL.Windows.ensure(A.config.windowName)
    end)
    if ok then
      -- Fixed 2026-07-11, per Steven ("fix all window titles/names"):
      -- this branch always returned here before setTitle() ever ran,
      -- so the window kept Mudlet's raw default title ("User window -
      -- DSL2 - MyDSL_Affects") despite this file having real title-
      -- setting code below -- that code was dead in the normal case
      -- (WindowRegistry always present), only reachable if
      -- MyDSL.Windows.ensure() didn't exist at all.
      if win and win.setTitle then pcall(function() win:setTitle(A.config.title) end) end
      return true
    end
  end

  if A.window then
    if A.window.setTitle then pcall(function() A.window:setTitle(A.config.title) end) end
    return true
  end
  if Geyser and Geyser.UserWindow then
    local ok, win = pcall(function()
      return Geyser.UserWindow:new({
        name = A.config.windowName,
        titleText = A.config.title,
        x = "70%", y = "35%", width = "30%", height = "25%",
      })
    end)
    if ok and win then A.window = win; return true end
  end
  return false
end

function A.applyFont()
  pcall(function() if setMiniConsoleFontSize then setMiniConsoleFontSize(A.config.windowName, A.config.fontSize) end end)
  pcall(function() if A.window and A.window.setFontSize then A.window:setFontSize(A.config.fontSize) end end)
end

-- applyTheme() -- added 2026-07-11. Affects has no MiniConsole child (it
-- cecho()s straight into the UserWindow itself via wcecho() above), so
-- there's no Geyser object to hand to MyDSL.Theme.styleConsole() -- this
-- uses the same raw-function-by-name style already established by
-- applyFont() (setMiniConsoleFontSize(name, ...) works on a plain
-- UserWindow's own console too, not just a MiniConsole child).
function A.applyTheme()
  if not (MyDSL and MyDSL.Theme) then return end
  local bg = MyDSL.Theme.get(A.config.windowName, "bgColor")
  if bg then
    pcall(function() setBackgroundColor(A.config.windowName, bg.r, bg.g, bg.b, bg.a) end)
  end
  local font = MyDSL.Theme.get(A.config.windowName, "font")
  if font then
    pcall(function() if setFont then setFont(A.config.windowName, font) end end)
  end
end

function A.clearList() A.list = {} end

function A.add(name, duration, source, mod)
  name = lower(name)
  if name == "" then return end
  local entry = A.list[name] or { name = name, mods = {} }
  entry.duration = tonumber(duration) or duration or -1
  entry.source = source or entry.source or "unknown"
  entry.updated = os.time()
  if type(mod) == "table" then table.insert(entry.mods, mod) end
  A.list[name] = entry
end

function A.activeCount()
  local n = 0
  for _ in pairs(A.list or {}) do n = n + 1 end
  return n
end

function A.trackedCount()
  local n = 0
  for _, v in pairs(A.tracked or {}) do if v then n = n + 1 end end
  return n
end

function A.missingList()
  local missing = {}
  for name, v in pairs(A.tracked or {}) do
    if v and not A.list[name] then table.insert(missing, name) end
  end
  table.sort(missing)
  return missing
end

function A.getGmcpRoot()
  local candidates = {}
  if MyCore and MyCore.state and MyCore.state.gmcp then table.insert(candidates, MyCore.state.gmcp) end
  if gmcp then table.insert(candidates, gmcp) end
  for _, root in ipairs(candidates) do
    if type(root) == "table" and root.affect_data and type(root.affect_data.affects) == "table" then return root end
  end
  return nil
end

function A.gmcpEntryToAffect(entry, source)
  if type(entry) ~= "table" then return end
  local name = entry.n or entry.name
  if not name or name == "" then return end
  A.add(name, entry.d, source or "gmcp", { lc = entry.lc, m = entry.m, t = entry.t })
end

function A.syncGmcpFull()
  if not A.config.useGmcp then return false end
  local root = A.getGmcpRoot()
  if not root or not root.affect_data or type(root.affect_data.affects) ~= "table" then return false end
  A.clearList()
  for _, entry in ipairs(root.affect_data.affects) do A.gmcpEntryToAffect(entry, "gmcp") end
  A.state.source = "gmcp"
  A.state.lastSync = os.time()
  A.display()
  A.save()
  if raiseEvent then pcall(raiseEvent, "MyDSL.Affects.Updated") end
  return true
end

function A.gmcpAdd()
  if not gmcp or type(gmcp.add_affect) ~= "table" then return false end
  A.gmcpEntryToAffect(gmcp.add_affect, "gmcp-add")
  A.state.source = "gmcp-add"
  A.state.lastSync = os.time()
  A.display()
  A.save()
  return true
end

function A.gmcpRemove()
  if not gmcp or type(gmcp.remove_affect) ~= "table" then return false end
  local name = gmcp.remove_affect.n or gmcp.remove_affect.name
  if name then
    A.list[lower(name)] = nil
    A.state.source = "gmcp-remove"
    A.state.lastSync = os.time()
    A.display()
    A.save()
    if raiseEvent then pcall(raiseEvent, "MyDSL.Affects.Updated") end
    return true
  end
  return false
end

function A.onGmcpEvent(event)
  event = tostring(event or "")
  if event == "gmcp.add_affect" or event == "add_affect" then
    if not A.gmcpAdd() then A.syncGmcpFull() end
  elseif event == "gmcp.remove_affect" or event == "remove_affect" then
    if not A.gmcpRemove() then A.syncGmcpFull() end
  else
    A.syncGmcpFull()
  end
end

function A.startCapture()
  if not A.config.useTextFallback then return end
  A.state.capture = true
  A.state.captureCount = 0
  A.clearList()
end

function A.finishCapture(reason)
  if not A.state.capture then return end
  A.state.capture = false
  A.state.source = "text"
  A.state.lastSync = os.time()
  A.display()
  A.save()
  if raiseEvent then pcall(raiseEvent, "MyDSL.Affects.Updated") end
end

function A.captureSpellLine(name, modName, modValue, cycles)
  if not A.state.capture then return end
  A.state.captureCount = (A.state.captureCount or 0) + 1
  A.add(name, tonumber(cycles) or -1, "text", { lc = modName, m = tonumber(modValue) or modValue })
end

-- captureSpellLineBare(name) -- real gap found 2026-08-24 (confirmed via
-- a cross-profile log scan): "Song : song of war" / "Spell: toughness"
-- with no "modifies ... by ... for ... cycles" clause at all is a real,
-- corpus-confirmed variant of this same header's output -- matches
-- neither A.ids.triggers.song nor .spell below, both of which require
-- that clause. Cross-checked against Steven's own separate note (MyDSL
-- notes_utf8.txt, PERSONAL/GAME NOTES section: "low level charcaters
-- cant see timers for affects, can we add the affects without a timer
-- and let them update with affects since we dont know when they fll
-- off excpet through echosa") -- this is very likely the SAME real
-- mechanism: a lower-level character's `affects` text fallback doesn't
-- print modifier/duration info at all, not a separate spell-shape.
-- No duration/modifier data exists in this form, so this adds the
-- affect as present-but-unknown-duration (-1, matching A.add()'s own
-- "no known expiry" convention) with no modifier extra -- exactly the
-- "show it, update it via echoes, don't fake a timer" behavior Steven
-- asked for in that same note.
function A.captureSpellLineBare(name)
  if not A.state.capture then return end
  A.state.captureCount = (A.state.captureCount or 0) + 1
  A.add(name, -1, "text", nil)
end

function A.captureNone()
  A.clearList()
  A.state.capture = false
  A.state.source = "text-none"
  A.state.lastSync = os.time()
  A.display()
  A.save()
  if raiseEvent then pcall(raiseEvent, "MyDSL.Affects.Updated") end
end

function A.installCaptureTriggers()
  for _, id in pairs(A.ids.triggers or {}) do killId(id) end
  A.ids.triggers = {}
  A.ids.triggers.start = tempRegexTrigger([[^You are affected by the following spells:$]], [[if MyDSL and MyDSL.Affects then MyDSL.Affects.startCapture() end]])
  A.ids.triggers.none = tempRegexTrigger([[^You are not affected by any spells\.$]], [[if MyDSL and MyDSL.Affects then MyDSL.Affects.captureNone() end]])
  A.ids.triggers.spell = tempRegexTrigger([[^Spell:\s+(.+?)\s+:\s+modifies\s+(.+?)\s+by\s+(-?\d+)\s+for\s+(-?\d+)\s+cycles.*$]], [[if MyDSL and MyDSL.Affects then MyDSL.Affects.captureSpellLine(matches[2], matches[3], matches[4], matches[5]) end]])
  A.ids.triggers.song = tempRegexTrigger([[^Song\s*:\s+(.+?)\s+:\s+modifies\s+(.+?)\s+by\s+(-?\d+)\s+for\s+(-?\d+)\s+cycles.*$]], [[if MyDSL and MyDSL.Affects then MyDSL.Affects.captureSpellLine(matches[2], matches[3], matches[4], matches[5]) end]])
  -- Modifier-less variant -- real gap found 2026-08-24, see
  -- captureSpellLineBare()'s own comment. Negative lookahead excludes
  -- any line the .spell/.song triggers above already match (confirmed
  -- via both Python re AND real PCRE via perl -e that these two forms
  -- never double-fire on the same line).
  A.ids.triggers.spellBare = tempRegexTrigger([[^Spell:\s*(?!.*modifies)(.+?)\s*$]], [[if MyDSL and MyDSL.Affects then MyDSL.Affects.captureSpellLineBare(matches[2]) end]])
  A.ids.triggers.songBare = tempRegexTrigger([[^Song\s*:\s*(?!.*modifies)(.+?)\s*$]], [[if MyDSL and MyDSL.Affects then MyDSL.Affects.captureSpellLineBare(matches[2]) end]])
  A.ids.triggers.blank = tempRegexTrigger([[^\s*$]], [[if MyDSL and MyDSL.Affects and MyDSL.Affects.state and MyDSL.Affects.state.capture then MyDSL.Affects.finishCapture("blank") end]])
end


-- =========================
-- Interactions: manual recast / respell / clickable cells
-- =========================
local function splitCommandSequence(cmd)
  cmd = tostring(cmd or "")
  local out = {}
  for part in string.gmatch(cmd, "([^|]+)") do
    part = trim(part)
    if part ~= "" then table.insert(out, part) end
  end
  if #out == 0 and trim(cmd) ~= "" then table.insert(out, trim(cmd)) end
  return out
end

function A.sendCommandSequence(cmd)
  local parts = splitCommandSequence(cmd)
  if #parts == 0 then return false end

  for i, part in ipairs(parts) do
    local delay = (i - 1) * 0.25
    if delay <= 0 then
      send(part)
    elseif tempTimer then
      tempTimer(delay, function() send(part) end)
    else
      send(part)
    end
  end

  return true
end

function A.commandFor(name)
  name = lower(name)
  if name == "" then return nil end
  if A.customCommands and A.customCommands[name] and A.customCommands[name] ~= "" then
    return tostring(A.customCommands[name])
  elseif A.songs and A.songs[name] then
    return "sing '" .. name .. "'"
  elseif A.skills and A.skills[name] then
    return name
  end
  return tostring(A.config.castCommand or "cast") .. " '" .. name .. "'"
end

function A.recast(name)
  name = lower(name)
  if name == "" then return end
  local cmd = A.commandFor(name)
  if not cmd or cmd == "" then ce("no command for " .. name); return end
  A.sendCommandSequence(cmd)
end

function A.setCommand(name, cmd)
  name = lower(name)
  cmd = trim(cmd or "")
  if name == "" or cmd == "" then
    ce("usage: mydsl affects command <affect> <command>  (use | between sequence steps)")
    return
  end
  A.customCommands[name] = cmd
  A.save()
  ce(name .. " command=" .. cmd)
  -- Hint added 2026-08-29, per Steven's live-test note ("adding a skill
  -- to the affects command... not intuitive, don't think i did it
  -- correctly"): a custom recast command and being tracked/displayed are
  -- two separate settings (this file's own `tracked` table vs.
  -- `customCommands`) -- setting one doesn't imply the other, and there
  -- was previously no feedback pointing that out.
  if not A.tracked[name] then
    ce(name .. " is not currently tracked/displayed -- run 'mydsl affects track " .. name .. "' to show it.")
  end
end

function A.clearCommand(name)
  name = lower(name)
  if name == "" then ce("usage: mydsl affects command clear <affect>"); return end
  A.customCommands[name] = nil
  A.save()
  ce("cleared command for " .. name)
end

function A.parseRespellList(text)
  local out = {}
  text = trim(text or "")
  if text == "" then return out end
  for item in string.gmatch(text, "([^,]+)") do
    item = lower(item)
    if item ~= "" then
      if string.sub(item, 1, 1) == "!" then out[string.sub(item, 2)] = -1
      else out[item] = 0 end
    end
  end
  return out
end

function A.respell(text)
  local spellList = A.parseRespellList(text)
  for name, enabled in pairs(A.tracked or {}) do
    if enabled and spellList[name] == nil then spellList[name] = 0 end
  end

  local castList = {}
  for name, state in pairs(spellList) do
    if state ~= -1 then
      local e = A.list and A.list[name]
      local duration = e and tonumber(e.duration)
      if not e or not duration or duration <= 0 then table.insert(castList, name) end
    end
  end

  table.sort(castList)
  if #castList == 0 then ce("Nothing missing from respell list."); return end
  ce("respell: " .. table.concat(castList, ", "))
  for _, name in ipairs(castList) do A.recast(name) end
end

function A.spellup(text)
  -- In PNP, "respell" recasts missing tracked affects; "character spellup"
  -- was an equipment bless/fireproof workflow. In MyDSL affects, spellup is
  -- a friendly synonym for respell so it only casts missing tracked/listed buffs.
  A.respell(text)
end

local function luaQuote(s)
  return string.format("%q", tostring(s or ""))
end

local function rememberLink(displayText, affectName)
  displayText = tostring(displayText or "")
  affectName = tostring(affectName or "")
  if displayText == "" or affectName == "" then return end
  A._linkTargets = A._linkTargets or {}
  A._linkTargets[displayText] = affectName
end

function A.applyLinks()
  -- PNP-style linking: first cecho colored text, then scan the rendered
  -- UserWindow and use selectString/setLink. This avoids cechoLink printing
  -- literal <> color tags in UserWindows.
  if not (setLink and selectString and moveCursor and getCurrentLine) then return false end
  if type(A._linkTargets) ~= "table" then return false end

  local window = A.config.windowName
  -- Row 0, not 1: unlike PNP's make_links() (PNP files/DSL_PNP_Affects.lua),
  -- which prints a leading blank line + header before any affect rows (so
  -- its row 0 is blank), A.display() clears the window and writes the first
  -- affect row immediately -- row 0 here IS real content. Starting at 1
  -- skipped it, which with the default 2-column layout meant the first two
  -- affects were never clickable (found live 2026-07-16).
  local index = 0

  while index <= 300 do
    local okMove, moved = pcall(moveCursor, window, 0, index)
    if not okMove or not moved then break end

    local okLine, lineText = pcall(getCurrentLine, window)
    lineText = okLine and tostring(lineText or "") or ""
    local lowerLine = lower(lineText)

    for display, name in pairs(A._linkTargets or {}) do
      if display ~= "" and lowerLine:find(lower(display), 1, true) then
        local okSel, selected = pcall(selectString, window, display, 1)
        if okSel and selected then
          pcall(setLink, window, "MyDSL.Affects.recast(" .. luaQuote(name) .. ")", "Recast " .. tostring(name) .. " -> " .. tostring(A.commandFor(name) or ""))
        end
      end
    end

    index = index + 1
  end
  return true
end

local function activeEntries()
  local rows = {}
  for _, e in pairs(A.list or {}) do table.insert(rows, e) end
  table.sort(rows, function(a,b)
    local ad = tonumber(a.duration) or 999999
    local bd = tonumber(b.duration) or 999999
    if ad == bd then return tostring(a.name) < tostring(b.name) end
    return ad < bd
  end)
  return rows
end

local function padRight(s, width)
  s = tostring(s or "")
  if #s >= width then return s:sub(1, width) end
  return s .. string.rep(" ", width - #s)
end

local function cutText(s, width)
  s = tostring(s or "")
  width = tonumber(width) or #s
  if #s <= width then return s end
  if width <= 1 then return s:sub(1, width) end
  return s:sub(1, width - 1) .. "~"
end


-- Fixed 2026-07-07: this used to look up MyDSL.DB.timers.affects[name].text,
-- but nothing anywhere ever populated that table -- "time"/"both" modes
-- silently always fell back to the cycles-only display.
--
-- Real bug found and fixed 2026-07-11, while building MyDSL_AlterformView.lua
-- (whose whole purpose is showing this real-time conversion prominently,
-- unlike here where it's hidden behind a non-default "time"/"both" mode).
-- This used to convert affect-duration cycles into real seconds using
-- TickSource's combat/skill-improve tick average (~40s) -- but a DSL
-- "affect cycle" is a completely different, unrelated timing unit that
-- just happens to share the English word. Confirmed via log-corpus grep
-- across 80 unique real examples with zero deviation: 1 affect cycle =
-- exactly 1800 real seconds (30 minutes) -- e.g. "for 90 cycles, (45
-- hours)", "for 73 cycles, (36 1/2 hours)", every single one exactly
-- 0.5 hours/cycle. Using the combat-tick average instead understated real
-- remaining time by roughly 45x for a typical multi-hour buff. The old
-- partial-tick blending is dropped too -- it was smoothing against the
-- wrong unit's sub-interval, and we have no finer-than-one-cycle real data
-- for affects anyway (unlike the combat tick, which TickSource tracks
-- continuously).
local AFFECT_CYCLE_SECONDS = 1800

local function realSecondsRemaining(cycles)
  if cycles < 0 then return nil end
  return cycles * AFFECT_CYCLE_SECONDS
end

-- Hour formatting added 2026-07-11 alongside the AFFECT_CYCLE_SECONDS fix
-- above -- now that real durations are genuinely correct (up to tens of
-- hours for a long buff like alterform), "2700m20s" would've been the old
-- unreadable result without this.
local function formatRealTime(totalSeconds)
  totalSeconds = math.max(0, math.floor(totalSeconds + 0.5))
  local hours = math.floor(totalSeconds / 3600)
  local mins = math.floor((totalSeconds % 3600) / 60)
  local secs = totalSeconds % 60
  if hours > 0 then return string.format("%dh%02dm", hours, mins) end
  if mins > 0 then return string.format("%dm%02ds", mins, secs) end
  return string.format("%ds", secs)
end

local function timerTextForAffect(e)
  local d = tonumber(e and e.duration) or -1
  local cycles = d >= 0 and (tostring(d) .. "c") or "?"
  local secs = d >= 0 and realSecondsRemaining(d) or nil
  local timeText = secs and formatRealTime(secs) or nil

  local mode = A.config.timerMode or "cycles"
  if mode == "time" then
    return timeText and tostring(timeText) or cycles
  elseif mode == "both" then
    if timeText then return cycles .. " " .. tostring(timeText) end
    return cycles
  end

  -- Default: old/PNP-style cycle display.
  return cycles
end

-- MyDSL.Affects.getRemaining(name) -- public, added 2026-07-11 for the new
-- MyDSL_AlterformView.lua ("an alterform timer like tick, beside it").
-- Returns cycles, realSeconds for any tracked affect by name (nil, nil if
-- not currently active) -- reuses the exact same tick-average conversion
-- every other countdown in this profile already uses (realSecondsRemaining
-- above), so a new per-affect timer widget never needs its own duplicate
-- copy of that math.
function A.getRemaining(name)
  local e = A.list and A.list[lower(name or "")]
  if not e then return nil, nil end
  local d = tonumber(e.duration)
  if not d or d < 0 then return nil, nil end
  return d, realSecondsRemaining(d)
end

local function affectCell(e)
  local dText = timerTextForAffect(e)
  local name = tostring(e.name or "?")
  local width = A.config.columnWidth
  local nameWidth = width - (#dText + 2)
  if nameWidth < 10 then nameWidth = 10 end
  local displayName = cutText(name, nameWidth)
  rememberLink(displayName, name)
  return string.format("%s %s", padRight(displayName, nameWidth), dText)
end

local function echoActiveRows()
  local rows = activeEntries()
  if #rows == 0 then wcecho("<grey>No active affects.\n"); return end

  local cols = math.max(1, tonumber(A.config.columns) or 2)
  local col = 0
  for _, e in ipairs(rows) do
    col = col + 1
    wcecho(colorForDuration(e.duration) .. affectCell(e) .. "<reset>")
    if col >= cols then
      wcecho("\n")
      col = 0
    else
      wcecho("  ")
    end
  end
  if col ~= 0 then wcecho("\n") end
end

local function echoMissingRows(missing)
  if #missing == 0 then
    wcecho("<green>missing: none<reset>\n")
    return
  end

  local max = tonumber(A.config.missingWrapWidth) or 56
  if max < 30 then max = 30 end

  local currentLen = 9
  wcecho("<grey>missing: <reset>")

  for i, name in ipairs(missing) do
    local sep = i == 1 and "" or " -- "
    local displayName = cutText(name, math.max(10, max - 10))
    local pieceLen = #sep + #displayName

    if currentLen + pieceLen > max and currentLen > 9 then
      wcecho("\n<grey>         <reset>")
      currentLen = 9
      sep = ""
      pieceLen = #displayName
    end

    if sep ~= "" then wcecho("<grey>" .. sep .. "<reset>") end
    rememberLink(displayName, name)
    wcecho("<DarkSlateGrey>" .. displayName .. "<reset>")
    currentLen = currentLen + pieceLen
  end

  wcecho("\n")
end

function A.display()
  A.checkCharacterProfile()
  A.ensureWindow()
  A.applyFont()
  clearWin()
  A._linkTargets = {}

  echoActiveRows()

  local missing = A.missingList()
  local active = A.activeCount()
  local tracked = A.trackedCount()

  wcecho("<DarkSlateGrey>------------------------------------------------------------<reset>\n")
  wcecho(string.format("<grey>%d active / %d tracked / %d missing<reset>\n", active, tracked, #missing))

  echoMissingRows(missing)

  -- Links must be applied after text has actually rendered into the window.
  -- Immediate + delayed pass covers Mudlet/UserWindow timing.
  A.applyLinks()
  if tempTimer then tempTimer(0.05, function() if MyDSL and MyDSL.Affects then MyDSL.Affects.applyLinks() end end) end
end

function A.status()
  A.checkCharacterProfile()
  ce("version=" .. A.version ..
     "; active=" .. tostring(A.activeCount()) ..
     "; tracked=" .. tostring(A.trackedCount()) ..
     "; missing=" .. tostring(#A.missingList()) ..
     "; source=" .. tostring(A.state.source or "none") ..
     "; gmcp=" .. tostring(gmcp and gmcp.affect_data and gmcp.affect_data.affects ~= nil) ..
     "; title=" .. tostring(A.config.title) ..
     "; font=" .. tostring(A.config.fontSize) ..
     "; columns=" .. tostring(A.config.columns) ..
     "; wrap=" .. tostring(A.config.missingWrapWidth) ..
     "; timerMode=" .. tostring(A.config.timerMode) ..
     "; castCommand=" .. tostring(A.config.castCommand) ..
     "; customCommands=" .. tostring(table.size(A.customCommands or {})) ..
     "; aliasVersion=" .. tostring(A.aliasVersion) ..
     "; links=" .. tostring(table.size(A._linkTargets or {})) ..
     "; character=" .. tostring(A.charName()) ..
     "; file=" .. tostring(A.dataFile()))
end

function A.refresh() send("affects") end
function A.show() A.ensureWindow(); if MyDSL and MyDSL.Windows and MyDSL.Windows.show then pcall(MyDSL.Windows.show, A.config.windowId) end; pcall(function() if A.window and A.window.show then A.window:show() end end); A.display() end
function A.hide() if MyDSL and MyDSL.Windows and MyDSL.Windows.hide then pcall(MyDSL.Windows.hide, A.config.windowId) end; pcall(function() if A.window and A.window.hide then A.window:hide() end end) end
-- A.toggle() -- added 2026-07-11, command-surface retrofit (docs/TODO.md
-- "OPEN — Command-surface retrofit"). Wires PNP's real bare "toggle
-- <module>" command (DSL_PNP_Support.lua's native Toggle Alias) using
-- PNP's own module name ("affects", confirmed via DSL_PNP_Affects.lua's
-- `dslpnp.toggle("affects", ...)` call). Reads current visibility from
-- WindowRegistry's own registry table (same access pattern already used
-- in MyDSL_RouteHelper.lua) rather than tracking a second, separate
-- shown/hidden flag here.
function A.toggle()
  local entry = MyDSL.Windows and MyDSL.Windows.registry and MyDSL.Windows.registry[A.config.windowId]
  if entry and entry.visible then A.hide() else A.show() end
end
function A.clear() A.clearList(); A.display(); A.save() end

-- Removed 2026-08-23 (Claude.ai review pass): this used to also try
-- MyDSL.Windows.setTitle(), guarded against a "spam" feedback loop
-- (Affects redraws every TimerSource pulse) -- but that function was
-- never actually built anywhere in MyDSL_WindowRegistry.lua, and no
-- other View module calls it either (confirmed via grep: every other
-- module just calls win:setTitle() directly, same as the line below).
-- It was always a guarded no-op, not a real registry notification.
-- Dropped the localOnly param along with it -- it had no other use, and
-- the only real call site (the "mydsl affects title <x>" alias) never
-- passed it anyway.
function A.setTitle(title, silent)
  title = trim(title or "")
  if title == "" then title = "Affects" end

  local changed = A.config.title ~= title
  A.config.title = title

  if A.window and A.window.setTitle then pcall(function() A.window:setTitle(title) end) end
  if changed then A.save() end
  if not silent then ce("title=" .. title) end
  return true
end


function A.setFont(size)
  size = tonumber(size)
  if not size then ce("usage: mydsl affects font <size>"); return end
  A.config.fontSize = size
  A.applyFont()
  A.display()
  A.save()
  ce("font=" .. tostring(size))
end

function A.setTimerMode(mode)
  mode = lower(mode or "")
  if mode ~= "cycles" and mode ~= "time" and mode ~= "both" then
    ce("usage: mydsl affects timer mode cycles|time|both")
    return
  end
  A.config.timerMode = mode
  A.display()
  A.save()
  ce("timerMode=" .. mode)
end

function A.setWrap(width)
  width = tonumber(width)
  if not width then ce("usage: mydsl affects wrap <columns>"); return end
  if width < 30 then width = 30 end
  if width > 160 then width = 160 end
  A.config.missingWrapWidth = width
  A.display()
  A.save()
  ce("wrap=" .. tostring(width))
end

function A.setColumns(n)
  n = tonumber(n)
  if not n then ce("usage: mydsl affects columns <1-4>"); return end
  if n < 1 then n = 1 end
  if n > 4 then n = 4 end
  A.config.columns = n
  A.display()
  A.save()
  ce("columns=" .. tostring(n))
end

function A.setColumnWidth(n)
  n = tonumber(n)
  if not n then ce("usage: mydsl affects width <columns>"); return end
  if n < 18 then n = 18 end
  if n > 60 then n = 60 end
  A.config.columnWidth = n
  A.display()
  A.save()
  ce("columnWidth=" .. tostring(n))
end

function A.track(name, value)
  name = lower(name)
  if name == "" then ce("usage: mydsl affects track <name>"); return end

  -- Old myAffects/PNP behavior: tracking an already-tracked affect toggles it off.
  if value == nil then value = not A.tracked[name] end
  A.tracked[name] = value and true or nil

  A.save()
  A.display()

  if A.tracked[name] then
    ce("tracking " .. name)
  else
    ce("untracked " .. name)
  end
end

function A.untrack(name)
  name = lower(name)
  if name == "" then ce("usage: mydsl affects untrack <name>"); return end
  A.track(name, false)
end

function A.clearTracked()
  A.tracked = {}
  A.save()
  A.display()
  ce("tracked list cleared for " .. A.charName())
end

function A.resetTracked()
  -- v4C8: reset means clean per-character slate, not default seeded list.
  A.clearTracked()
end

function A.seedDefaultTracked()
  A.tracked = {}
  for _, name in ipairs(DEFAULT_TRACKED) do A.tracked[name] = true end
  A.save()
  A.display()
  ce("seeded default tracked list for " .. A.charName())
end

function A.printTracked()
  local keys = sortedKeys(A.tracked)
  if #keys == 0 then
    ce("tracked (0) for " .. A.charName() .. ": none")
  else
    ce("tracked (" .. tostring(#keys) .. ") for " .. A.charName() .. ": " .. table.concat(keys, ", "))
  end
end

function A.installAliases()
  -- Versioned temp aliases. Older revisions set A.aliasesInstalled=true and
  -- skipped new aliases like spellup on hot reload, which caused "Huh?".
  if A.aliasVersion == A.version then return end

  if type(A.ids.aliases) == "table" then
    for _, id in ipairs(A.ids.aliases) do
      if id and killAlias then pcall(killAlias, id) end
    end
  end
  A.ids.aliases = {}

  local function addAlias(pattern, code)
    local id = tempAlias(pattern, code)
    table.insert(A.ids.aliases, id)
    return id
  end

  addAlias([[^toggle affects$]], [[if MyDSL and MyDSL.Affects then MyDSL.Affects.toggle() end]])
  addAlias([[^mydsl affects status$]], [[MyDSL.Affects.status()]])
  addAlias([[^mydsl affects profile$]], [[MyDSL.Affects.profile()]])
  addAlias([[^mydsl affects reload profile$]], [[MyDSL.Affects.loadProfileForCurrentChar(true); MyDSL.Affects.display(); MyDSL.Affects.profile()]])
  addAlias([[^mydsl affects save$]], [[MyDSL.Affects.save(); MyDSL.Affects.profile()]])
  addAlias([[^mydsl affects sync$]], [[MyDSL.Affects.syncGmcpFull()]])
  addAlias([[^mydsl affects refresh$]], [[MyDSL.Affects.refresh()]])
  addAlias([[^mydsl affects show$]], [[MyDSL.Affects.show()]])
  addAlias([[^mydsl affects hide$]], [[MyDSL.Affects.hide()]])
  addAlias([[^mydsl affects clear$]], [[MyDSL.Affects.clear()]])
  addAlias([[^mydsl affects title (.+)$]], [[MyDSL.Affects.setTitle(matches[2])]])
  addAlias([[^mydsl affects font (\d+)$]], [[MyDSL.Affects.setFont(matches[2])]])
  addAlias([[^mydsl affects wrap (\d+)$]], [[MyDSL.Affects.setWrap(matches[2])]])
  addAlias([[^mydsl affects columns (\d+)$]], [[MyDSL.Affects.setColumns(matches[2])]])
  addAlias([[^mydsl affects width (\d+)$]], [[MyDSL.Affects.setColumnWidth(matches[2])]])
  addAlias([[^mydsl affects cast (.+)$]], [[MyDSL.Affects.recast(matches[2])]])
  addAlias([[^mydsl affects recast (.+)$]], [[MyDSL.Affects.recast(matches[2])]])
  addAlias([[^mydsl affects respell ?(.*)$]], [[MyDSL.Affects.respell(matches[2])]])
  addAlias([[^mydsl affects spellup ?(.*)$]], [[MyDSL.Affects.spellup(matches[2])]])
  addAlias([[^mydsl affects command clear (.+)$]], [[MyDSL.Affects.clearCommand(matches[2])]])
  addAlias([[^mydsl affects command (.+?) (.+)$]], [[MyDSL.Affects.setCommand(matches[2], matches[3])]])
  addAlias([[^respell ?(.*)$]], [[MyDSL.Affects.respell(matches[2])]])
  addAlias([[^spellup ?(.*)$]], [[MyDSL.Affects.spellup(matches[2])]])
  addAlias([[^mydsl affects timer mode (cycles|time|both)$]], [[MyDSL.Affects.setTimerMode(matches[2])]])
  addAlias([[^mydsl affects mode (cycles|time|both)$]], [[MyDSL.Affects.setTimerMode(matches[2])]])
  addAlias([[^mydsl affects track (.+)$]], [[MyDSL.Affects.track(matches[2])]])
  addAlias([[^mydsl affects untrack (.+)$]], [[MyDSL.Affects.untrack(matches[2])]])
  addAlias([[^mydsl affects tracked$]], [[MyDSL.Affects.printTracked()]])
  addAlias([[^mydsl affects reset tracked$]], [[MyDSL.Affects.resetTracked()]])
  addAlias([[^mydsl affects clear tracked$]], [[MyDSL.Affects.clearTracked()]])
  addAlias([[^mydsl affects seed tracked$]], [[MyDSL.Affects.seedDefaultTracked()]])
  addAlias([[^affdebug$]], [[MyDSL.Affects.config.debug = not MyDSL.Affects.config.debug; cecho("\n<cyan>[MyDSL.Affects]<reset> debug=" .. tostring(MyDSL.Affects.config.debug) .. "\n")]])
  addAlias([[^affsync$]], [[MyDSL.Affects.syncGmcpFull()]])
  addAlias([[^affrefresh$]], [[MyDSL.Affects.refresh()]])

  A.aliasesInstalled = true
  A.aliasVersion = A.version
end


function A.registerHandlerOnce(key, eventName, funcName)
  A.handlers = A.handlers or {}
  if A.handlers[key] then return end
  if registerAnonymousEventHandler then
    registerAnonymousEventHandler(eventName, funcName)
    A.handlers[key] = true
  end
end

function A.onThemeChanged()
  A.applyTheme()
end

function A.onTimersUpdated()
  -- Fires once/sec (MyDSL.Timers.Slow, see MyDSL_TickSource.lua) -- redraw
  -- to show live buff countdowns (the real-time portion recomputes smoothly
  -- on every call via realSecondsRemaining() above -- this alone was
  -- already wired in, but nothing ever decremented the whole-cycle count
  -- between GMCP updates, see onTickUpdated() below).
  --
  -- Narrowed 2026-07-12, per Steven asking (after seeing a debug dump full
  -- of repeated identical Affects selectSection()/link-rescan calls) "does
  -- affects need to update that often also?" -- the default display mode
  -- is "cycles" (timerTextForAffect() just shows the bare "Nc" count),
  -- which only actually changes once per real game tick (~40s, decremented
  -- by onTickUpdated() below, which already redraws itself when it does).
  -- Forcing the full A.display() -- "a full window clear+redraw plus an
  -- up-to-300-line link-rescan" per its own registerHandlers() comment --
  -- every single real second in that mode was pure wasted repaint with the
  -- displayed text unchanged ~39 times out of 40. Only "time"/"both" modes
  -- actually show a real-time-interpolated seconds countdown that needs
  -- this 1/sec redraw to look smooth.
  local mode = A.config.timerMode or "cycles"
  if mode ~= "time" and mode ~= "both" then return end
  A.display()
end

function A.onTickUpdated()
  -- Fixed 2026-07-07, then fixed again same day after live testing showed
  -- affects counting down in ~2-3 real seconds instead of ~40: "MyDSL.Tick.
  -- Updated" does NOT mean "one real game tick happened" -- MyDSL_TickSource.
  -- lua's T.publish() raises it unconditionally from every caller, including
  -- T.updateTimer()'s own ~0.25s internal progress-bar loop (reason="timer"),
  -- not just T.onGameTick() (reason="tick", the actual once-per-~40s event).
  -- No reason string is passed through the event, so the only reliable way
  -- to tell a real tick apart from the frequent pulse is MyDSL.DB.tick.ticks
  -- itself -- an integer T.onGameTick() increments once per real tick and
  -- nothing else touches. Guard on that actually changing before
  -- decrementing, instead of decrementing on every call.
  local db = MyDSL and MyDSL.DB and MyDSL.DB.tick
  local ticks = db and tonumber(db.ticks)
  if not ticks then return end
  if A._lastTickCount == nil then A._lastTickCount = ticks; return end
  if ticks == A._lastTickCount then return end
  A._lastTickCount = ticks

  -- Ported from PNP's DSL_PNP_Affects.bar.lua decrement_affects() (hooked
  -- to its own "onTick" there). Purely local state -- no server command
  -- involved. GMCP add/remove events remain authoritative and always
  -- overwrite this on the next real change (A.add()/A.gmcpRemove() set
  -- entry.duration directly), so this can never drift permanently, it
  -- just fills the gap between those events instead of freezing.
  local changed = false
  for _, e in pairs(A.list or {}) do
    local d = tonumber(e.duration)
    if d and d > 0 then
      e.duration = d - 1
      changed = true
    end
  end
  if changed then A.display() end
end

function A.onCharacterChanged()
  if A.loadProfileForCurrentChar(false) then
    if not A.syncGmcpFull() then A.display(); A.save() end
  end
end

function A.registerHandlers()
  A.registerHandlerOnce("char_login_data", "gmcp.login_data", "MyDSL.Affects.onCharacterChanged")
  A.registerHandlerOnce("char_data", "gmcp.char_data", "MyDSL.Affects.onCharacterChanged")
  -- Switched from "MyDSL.Timers.Updated" (0.25s, TickView's own animation
  -- cadence) to "MyDSL.Timers.Slow" (throttled to 1/sec in TickSource) --
  -- confirmed real inefficiency 2026-07-11: A.display() is a full window
  -- clear+redraw plus an up-to-300-line link-rescan, and the countdown text
  -- only ever shows whole seconds anyway, so redrawing faster than 1/sec
  -- was pure wasted work with zero visible difference.
  A.registerHandlerOnce("timers_updated", "MyDSL.Timers.Slow", "MyDSL.Affects.onTimersUpdated")
  A.registerHandlerOnce("tick_updated", "MyDSL.Tick.Updated", "MyDSL.Affects.onTickUpdated")
  A.registerHandlerOnce("gmcp_affect_data", "gmcp.affect_data", "MyDSL.Affects.onGmcpEvent")
  A.registerHandlerOnce("gmcp_affect_data_affects", "gmcp.affect_data.affects", "MyDSL.Affects.onGmcpEvent")
  A.registerHandlerOnce("gmcp_add_affect", "gmcp.add_affect", "MyDSL.Affects.onGmcpEvent")
  A.registerHandlerOnce("gmcp_remove_affect", "gmcp.remove_affect", "MyDSL.Affects.onGmcpEvent")
  A.registerHandlerOnce("add_affect", "add_affect", "MyDSL.Affects.onGmcpEvent")
  A.registerHandlerOnce("remove_affect", "remove_affect", "MyDSL.Affects.onGmcpEvent")
  A.registerHandlerOnce("save_exit", "sysExitEvent", "MyDSL.Affects.save")
  A.registerHandlerOnce("save_disc", "sysDisconnectionEvent", "MyDSL.Affects.save")
  A.registerHandlerOnce("theme_changed", "MyDSL.theme.changed", "MyDSL.Affects.onThemeChanged")
end

function A.install()
  A.loadProfileForCurrentChar(true)
  A.ensureWindow()
  A.applyFont()
  A.applyTheme()
  A.installAliases()
  A.installCaptureTriggers()
  A.registerHandlers()
  if not A.syncGmcpFull() then A.display(); A.save() end
  if MyDSL and MyDSL.Alpha and MyDSL.Alpha.verbose then ce("loaded " .. A.version .. " (strict per-character profiles; GMCP-first; live timer countdowns; command sequences)") end
end

A.install()
