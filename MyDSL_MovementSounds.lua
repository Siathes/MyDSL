-- =============================================================================
-- MyDSL_MovementSounds.lua
-- Movement key sound selector for DSL
-- Depends on MyDSL_DataLayer when available, falls back to raw GMCP.
-- =============================================================================

MyDSL = MyDSL or {}
MyDSL.MoveSound = MyDSL.MoveSound or {}

MyDSL.MoveSound.config = {
  enabled = true,
  volume = 75,

  -- Put your sound files in:
  -- getMudletHomeDir() .. "/Sounds/"
  base = getMudletHomeDir() .. "/Sounds/",

  files = {
    walk = "characterwalking.mp3",
    ride = "characterriding.mp3",
    fly  = "characterflapping.mp3",
    swim = "characterswimming.mp3",
  },

  -- Only "swim" is enabled because you said the room sector tag contains "swim".
  -- Add "ocean" or "water" later only if DSL's GMCP sector proves those are needed.
  swim_keywords = {
    "swim",
  },

  sound_key = "dsl_movement_step",
  sound_tag = "dsl_movement",
  priority  = 20,
}

local function trim(s)
  return tostring(s or ""):match("^%s*(.-)%s*$")
end

local function truthy(v)
  if v == true or v == 1 then return true end

  if type(v) == "string" then
    local s = v:lower()
    return s == "true" or s == "1" or s == "yes" or s == "y" or s == "on"
  end

  return false
end

local function dataGet(section, field)
  -- Preferred source: your MyDSL DataLayer API.
  if MyDSL and MyDSL.get then
    local v = MyDSL.get(section, field)
    if v ~= nil then return v end
  end

  -- Fallback source: raw GMCP, only if DataLayer is unavailable or stale.
  if type(gmcp) == "table" then
    if section == "char" and type(gmcp.char_data) == "table" then
      return gmcp.char_data[field]
    end

    if section == "room" and type(gmcp.room_data) == "table" then
      if field == "name" then
        return gmcp.room_data.room
      else
        return gmcp.room_data[field]
      end
    end
  end

  return nil
end

local function containsText(value, needle)
  needle = tostring(needle or ""):lower()
  if needle == "" or value == nil then return false end

  if type(value) == "table" then
    for k, v in pairs(value) do
      if containsText(k, needle) or containsText(v, needle) then
        return true
      end
    end
    return false
  end

  return tostring(value):lower():find(needle, 1, true) ~= nil
end

function MyDSL.MoveSound.isSwimmingSector()
  local sector = dataGet("room", "sector")
  local keywords = MyDSL.MoveSound.config.swim_keywords or { "swim" }

  for _, word in ipairs(keywords) do
    if containsText(sector, word) then
      return true
    end
  end

  return false
end

function MyDSL.MoveSound.mode()
  local riding = truthy(dataGet("char", "is_riding"))
  local flying = truthy(dataGet("char", "is_flying"))
  local swimming = MyDSL.MoveSound.isSwimmingSector()

  -- Priority order:
  -- riding first, then flying, then swimming, then normal walking.
  -- Change this order if you want flying to override riding.
  if riding then return "ride" end
  if flying then return "fly" end
  if swimming then return "swim" end

  return "walk"
end

function MyDSL.MoveSound.soundPath(mode)
  local cfg = MyDSL.MoveSound.config
  local file = cfg.files[mode] or cfg.files.walk

  -- Full Linux path already supplied.
  if file:match("^/") then
    return file
  end

  return cfg.base .. file
end

function MyDSL.MoveSound.play(mode)
  local cfg = MyDSL.MoveSound.config
  if cfg.enabled == false then return end

  mode = mode or MyDSL.MoveSound.mode()
  local path = MyDSL.MoveSound.soundPath(mode)

  -- Prevent the previous movement step from stacking over the next one.
  stopSounds({
    key = cfg.sound_key,
  })

  playSoundFile({
    name = path,
    volume = cfg.volume,
    key = cfg.sound_key,
    tag = cfg.sound_tag,
    priority = cfg.priority,
  })
end

function MyDSL.MoveSound.normalizeDir(dir)
  dir = trim(dir):lower()

  local dirs = {
    n  = "north",
    s  = "south",
    e  = "east",
    w  = "west",
    u  = "up",
    d  = "down",
    ne = "northeast",
    nw = "northwest",
    se = "southeast",
    sw = "southwest",

    north     = "north",
    south     = "south",
    east      = "east",
    west      = "west",
    up        = "up",
    down      = "down",
    northeast = "northeast",
    northwest = "northwest",
    southeast = "southeast",
    southwest = "southwest",
  }

  return dirs[dir]
end

function MyDSL.MoveSound.go(dir)
  local d = MyDSL.MoveSound.normalizeDir(dir)

  if not d then
    cecho("\n<red>[MoveSound] Invalid direction: " .. tostring(dir) .. "\n")
    return
  end

  send(d)
  MyDSL.MoveSound.play()
end

function MyDSL.MoveSound.status()
  local sector = dataGet("room", "sector")

  cecho("\n<cyan>[MoveSound]")
  cecho(" mode=<white>" .. MyDSL.MoveSound.mode())
  cecho(" <cyan>riding=<white>" .. tostring(dataGet("char", "is_riding")))
  cecho(" <cyan>flying=<white>" .. tostring(dataGet("char", "is_flying")))
  cecho(" <cyan>sector=<white>" .. tostring(sector) .. "\n")
end

cecho("\n<green>[MyDSL] Movement sounds loaded.\n")