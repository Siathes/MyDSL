-- =============================================================================
-- MyDSL_AutoWhere.lua  --  Layer 3: state-aware periodic `where` polling
-- =============================================================================
-- Replaces Steven's own native "(autowhere) AutoWhere" alias (native XML,
-- current/*.xml -- a plain send("where") on a fixed 20s tempTimer(), no
-- state awareness at all, previously "his own alias, not ours" per
-- docs/TODO.md). Per Steven (2026-07-16): "roll autowhere into mydsl but
-- improve it so it pays attention to states like sleeping, fighting,
-- blind etc (any time it doesnt work)".
--
-- Same class of user-toggled, assistive automation as
-- MyDSL_CharacterAssist.lua's rearm/spellup/standup -- the player still
-- explicitly turns this on/off; the only change from the native version
-- is skipping an individual tick when the player's own current state
-- means a `where` right now wouldn't be useful. Never decides anything
-- for the player, matches this profile's existing "automate to assist,
-- not to play" precedent -- not a new exception to "never send automatic
-- game commands."
--
-- IMPORTANT MANUAL STEP, same class as the dofile() gotcha: Steven's
-- native "(autowhere) AutoWhere" alias (current/*.xml) needs to be
-- disabled or deleted via Mudlet's Alias Editor. If both it and this
-- module stay active, "autowhere on/off/status" fires BOTH (Mudlet runs
-- every alias whose pattern matches, confirmed repeatedly this profile --
-- see the 2026-07-11 command-surface retrofit's "focus" catch-all bug),
-- running two independent timers and toggling conflicting state. This
-- file cannot do that edit itself.
-- =============================================================================

MyDSL           = MyDSL           or {}
MyDSL.AutoWhere = MyDSL.AutoWhere or {}
local AW = MyDSL.AutoWhere

if AW._timer then pcall(killTimer, AW._timer) end
AW._timer = nil

AW.config = AW.config or { enabled = false, interval = 20 }

-- Skip conditions -- ordered list of named checks. Each returns true if
-- `where` should be SKIPPED this tick. Sleeping/fighting/blind are per
-- Steven's own direct in-game knowledge (2026-07-16), not independently
-- log-corpus-confirmed the way most of this profile's other patterns
-- are -- add more here if another state turns out to matter too.
local SKIP_CHECKS = {
  { name = "sleeping", fn = function()
      return MyDSL.State and MyDSL.State.char and MyDSL.State.char.posn == "Sleeping"
    end },
  { name = "fighting", fn = function()
      return MyDSL.State and MyDSL.State.char and MyDSL.State.char.is_fighting == true
    end },
  -- Reuses MyDSL_CharacterAssist.lua's own confirmed vision check
  -- (MyDSL.State.room.name == "darkness") instead of re-deriving
  -- blindness detection a second way.
  { name = "blind/no light", fn = function()
      return MyDSL.CharacterAssist and MyDSL.CharacterAssist.checkVision
         and MyDSL.CharacterAssist.checkVision() ~= "can see"
    end },
}

-- skipReason() -- returns the name of the first matching skip condition, or nil.
local function skipReason()
  for _, check in ipairs(SKIP_CHECKS) do
    local ok, skip = pcall(check.fn)
    if ok and skip then return check.name end
  end
  return nil
end

local function tick()
  if not AW.config.enabled then return end
  if not skipReason() then send("where", false) end
  AW._timer = tempTimer(AW.config.interval, tick)
end

function AW.start()
  if AW.config.enabled then
    echo("\n[AutoWhere] Already running every " .. AW.config.interval .. " seconds.\n")
    return
  end
  AW.config.enabled = true
  if not skipReason() then send("where", false) end
  if AW._timer then pcall(killTimer, AW._timer) end
  AW._timer = tempTimer(AW.config.interval, tick)
  echo("\n[AutoWhere] ON: sending 'where' every " .. AW.config.interval ..
       " seconds, skipping while sleeping/fighting/blind.\n")
end

function AW.stop()
  AW.config.enabled = false
  if AW._timer then pcall(killTimer, AW._timer); AW._timer = nil end
  echo("\n[AutoWhere] OFF.\n")
end

function AW.status()
  if AW.config.enabled then
    local reason = skipReason()
    echo("\n[AutoWhere] ON: every " .. AW.config.interval .. " seconds" ..
         (reason and (" (currently skipping: " .. reason .. ")") or "") .. ".\n")
  else
    echo("\n[AutoWhere] OFF.\n")
  end
end

-- Reuses the exact same alias vocabulary as Steven's native version
-- ("autowhere on|off|status"), per CLAUDE.md's command-surface mandate --
-- no muscle-memory change for switching to this replacement.
MyDSL._aliases = MyDSL._aliases or {}
if MyDSL._aliases.autowhere then pcall(killAlias, MyDSL._aliases.autowhere) end
MyDSL._aliases.autowhere = tempAlias(
  "^autowhere(?:\\s+(on|off|status))?$",
  [[
    local arg = (matches[2] or ""):lower()
    if arg == "" then arg = MyDSL.AutoWhere.config.enabled and "off" or "on" end
    if arg == "on" then MyDSL.AutoWhere.start()
    elseif arg == "off" then MyDSL.AutoWhere.stop()
    elseif arg == "status" then MyDSL.AutoWhere.status() end
  ]]
)

debugc("[MyDSL] AutoWhere loaded.")
