-- =============================================================================
-- MyDSL_Roller.lua  --  Character-creation stat-reroll assistant
-- =============================================================================
-- Ported 2026-07-07 as part of the PNP/EMCO cannibalization pass (Phase C).
-- "Our roller" was never a MyDSL_*.lua module -- it was a bare native
-- trigger literally named "roller" in current/autosave.xml, sitting
-- unorganized among unrelated itemstats aliases. That trigger:
--   pattern: ^\[Str:\s*(\d+)\s+Int:\s*(\d+)\s+Wis:\s*(\d+)\s+Dex:\s*(\d+)\s+Con:\s*(\d+)\]$
--   behavior: sums the five stats; if below a hardcoded goal (241), sends
--     "n" (reject) automatically; if at/above goal, pauses for manual
--     review only (never auto-sends "y" -- the decision to keep a roll
--     always stays with the player).
-- DSL_PNP_Roller.lua (PNP files/) does the same core thing but adds real
-- functionality the native version never had: a user-adjustable goal
-- ("set goal <n>"), running min/max/avg/stdev stats across every roll
-- this session ("roll stats"), and a reset ("reset roll"). Ported that
-- value-add here near-verbatim, reusing PNP's own command vocabulary
-- per CLAUDE.md's mandate, while keeping the native trigger's already-
-- tuned goal (241, this profile's own chosen value) as the default
-- instead of PNP's generic reference default (230).
--
-- PNP's own trigger pattern ("Str: (\d+)  Int: (\d+) ..." -- no brackets,
-- double space, no anchors) could not be verified against any real log --
-- character creation is a one-time event and none of the available logs
-- happen to capture it. Kept the pattern tolerant of both forms (optional
-- brackets, \s+ instead of a fixed space count) rather than picking one
-- unverifiable guess over another.
--
-- Not character-bound (see CLAUDE.md's character-binding section) --
-- rolling happens before a character exists, so there is no character
-- name to key this data by, same reasoning as ThemeEngine being
-- intentionally shared rather than per-character.
-- =============================================================================

MyDSL         = MyDSL         or {}
MyDSL.Roller  = MyDSL.Roller  or {}

local R = MyDSL.Roller
R.goal = R.goal or 241
R.rolls = R.rolls or { str = {}, int = {}, wis = {}, dex = {}, con = {}, total = {} }
-- Per-stat floors -- added 2026-07-17, per user request ("set min command
-- that they can enter the minimum value of each stat"). Independent of
-- R.goal (the total-sum threshold, unchanged): a roll can meet the goal
-- and still get rejected if any one stat is below its own configured
-- minimum, since a high total can hide one crippled stat. Not present in
-- PNP's own DSL_PNP_Roller.lua (checked -- it only ever had the total
-- goal), so this is new functionality, not a port. nil means "no floor
-- set" for that stat.
R.mins = R.mins or { str = nil, int = nil, wis = nil, dex = nil, con = nil }
local STAT_ORDER = { "str", "int", "wis", "dex", "con" }

MyDSL.Roller._triggers = MyDSL.Roller._triggers or {}
MyDSL.Roller._aliases  = MyDSL.Roller._aliases  or {}
-- ID of the currently pending automatic-rejection timer, and a generation
-- counter bumped on every roll -- added 2026-07-18 after a live bug: a
-- roll that failed goal scheduled a delayed send("n"); before that timer
-- fired, the next roll came in and passed goal (paused for manual
-- review), but the stale timer fired anyway and rejected the good roll
-- out from under the player. The generation check in scheduleReject()
-- lets a stale timer recognize it belongs to an old roll and no-op.
MyDSL.Roller._rejectTimer = MyDSL.Roller._rejectTimer or nil
MyDSL.Roller._rollGeneration = tonumber(MyDSL.Roller._rollGeneration) or 0
MyDSL.Roller.paused = false
local function cancelRejectTimer()
  if not MyDSL.Roller._rejectTimer then return end
  pcall(killTimer, MyDSL.Roller._rejectTimer)
  MyDSL.Roller._rejectTimer = nil
end
local function deregister()
  cancelRejectTimer()
  for _, id in pairs(MyDSL.Roller._triggers) do pcall(killTrigger, id) end
  for _, id in pairs(MyDSL.Roller._aliases) do pcall(killAlias, id) end
  MyDSL.Roller._triggers = {}
  MyDSL.Roller._aliases = {}
  MyDSL.Roller.paused = false
end
deregister()

-- Disable the old permanent native GUI trigger this module replaced (see
-- file header) -- added 2026-07-18 after confirming live that it was
-- never actually killed on port, so it kept running in parallel with
-- this script and independently sent "n" to the game (with its own,
-- separately-configured goal) even when this module correctly judged a
-- roll good and paused. Without this, a qualifying roll can still get
-- auto-rejected by the leftover native trigger regardless of anything
-- this file does.
if type(exists) == "function" and exists("roller", "trigger") > 0 then
  disableTrigger("roller")
  debugc("[MyDSL] Disabled legacy native trigger named 'roller'.")
end

local function round(n) return math.floor(n + 0.5) end

local function stdev(arr)
  local n = #arr
  if n < 2 then return 0 end
  local sum = 0
  for _, v in ipairs(arr) do sum = sum + v end
  local mean = sum / n
  local sqsum = 0
  for _, v in ipairs(arr) do sqsum = sqsum + (v - mean) ^ 2 end
  return math.sqrt(sqsum / (n - 1))
end

function R.setGoal(goal)
  goal = tonumber(goal)
  if not goal then echo("usage: set goal <number>\n"); return end
  R.goal = goal
  echo("Roller goal set to: " .. R.goal .. ".\n")
end

-- setMin(stat, value) -- sets stat's own floor. A value of 0 (or anything
-- <= 0) clears the floor entirely (every real stat is always > 0, so 0
-- is meaningless as a requirement) -- lets "set min str 0" undo a floor
-- without needing a separate "clear min" alias.
function R.setMin(stat, value)
  stat = tostring(stat or ""):lower()
  local isValidStat = false
  for _, s in ipairs(STAT_ORDER) do
    if s == stat then isValidStat = true; break end
  end
  if not isValidStat then
    echo("usage: set min <str|int|wis|dex|con> <number>\n")
    return
  end
  local n = tonumber(value)
  if not n then
    echo("usage: set min <str|int|wis|dex|con> <number>\n")
    return
  end
  if n <= 0 then
    R.mins[stat] = nil
    echo(string.format("Roller minimum for %s cleared.\n", stat:sub(1,1):upper() .. stat:sub(2)))
  else
    R.mins[stat] = n
    echo(string.format("Roller minimum for %s set to: %d.\n", stat:sub(1,1):upper() .. stat:sub(2), n))
  end
end

function R.reset()
  R.rolls = { str = {}, int = {}, wis = {}, dex = {}, con = {}, total = {} }
  -- R.mins (like R.goal) intentionally survives a reset -- "reset roll"
  -- clears accumulated roll statistics, not your configured targets.
  echo("Roller stats reset.\n")
end

function R.showStats()
  local order = { "str", "int", "wis", "dex", "con", "total" }
  if #R.rolls.total == 0 then echo("No rolls recorded yet.\n"); return end
  echo(string.format("Rolls: %d\n", #R.rolls.total))
  echo(string.format("%-5s %5s %5s %5s %7s %7s\n", "", "MIN", "MAX", "AVG", "STDEV", "MIN REQ"))
  for _, stat in ipairs(order) do
    local arr = R.rolls[stat]
    local min, max, sum = arr[1], arr[1], 0
    for _, v in ipairs(arr) do
      if v < min then min = v end
      if v > max then max = v end
      sum = sum + v
    end
    local avg = round(sum / #arr)
    local reqStr = stat == "total" and tostring(R.goal) or tostring(R.mins[stat] or "--")
    echo(string.format("%-5s %5d %5d %5d %7.1f %7s\n",
      stat:sub(1,1):upper() .. stat:sub(2), min, max, avg, stdev(arr), reqStr))
  end
end

local function scheduleReject()
  cancelRejectTimer()
  local generation = R._rollGeneration
  R._rejectTimer = tempTimer(0.2, function()
    R._rejectTimer = nil
    if generation ~= R._rollGeneration then return end -- superseded by a newer roll
    if R.paused then return end -- this roll already qualified, don't reject it
    send("n")
  end)
end

local function newRoll(str, int, wis, dex, con)
  str, int, wis, dex, con = tonumber(str), tonumber(int), tonumber(wis), tonumber(dex), tonumber(con)
  if not (str and int and wis and dex and con) then return end
  local total = str + int + wis + dex + con

  R._rollGeneration = R._rollGeneration + 1
  R.paused = false
  cancelRejectTimer()

  table.insert(R.rolls.str, str)
  table.insert(R.rolls.int, int)
  table.insert(R.rolls.wis, wis)
  table.insert(R.rolls.dex, dex)
  table.insert(R.rolls.con, con)
  table.insert(R.rolls.total, total)

  cecho(string.format(
    "\n<cyan>[Roll Total: %d]<reset> Str=%d Int=%d Wis=%d Dex=%d Con=%d\n",
    total, str, int, wis, dex, con))

  -- Per-stat floor check -- added 2026-07-17. Checked independently of
  -- the total/goal check below: a roll can clear the goal and still get
  -- rejected if any one stat is under its own configured minimum, since
  -- a high total can hide one crippled stat. Reports the FIRST failing
  -- stat (in Str/Int/Wis/Dex/Con order) -- a roll failing on multiple
  -- stats at once doesn't need every failure listed, just enough to
  -- explain the reject.
  local statValues = { str = str, int = int, wis = wis, dex = dex, con = con }
  local failedStat, failedValue, failedMin = nil, nil, nil
  for _, stat in ipairs(STAT_ORDER) do
    local minReq = R.mins[stat]
    if minReq and statValues[stat] < minReq then
      failedStat, failedValue, failedMin = stat, statValues[stat], minReq
      break
    end
  end

  if failedStat then
    cecho(string.format(
      "<red>[Reject]<reset> %s is %d, below its minimum of %d. Sending n.\n",
      failedStat:sub(1,1):upper() .. failedStat:sub(2), failedValue, failedMin))
    -- Small delay so it answers after the Keep prompt appears (same
    -- timing as the native trigger).
    scheduleReject()
  elseif total < R.goal then
    cecho(string.format(
      "<red>[Reject]<reset> Total is %d, below goal %d. Sending n.\n",
      total, R.goal))
    scheduleReject()
  else
    cancelRejectTimer()
    R.paused = true
    cecho(string.format(
      "<green>[PAUSE]<reset> Total is %d, goal is %d or higher. Review manually!\n",
      total, R.goal))
    -- Attention sound/visual only -- never auto-sends "y". The decision
    -- to keep a roll always stays with the player.
    raiseEvent("onAlert", "Mudlet - DSL", "Rolled: " .. total, false, false)
  end
end

-- Anchored 2026-07-18 -- unanchored, this could match a stat block embedded
-- inside unrelated output instead of only a stat-roll line by itself.
MyDSL.Roller._triggers.roll = tempRegexTrigger(
  [[^\s*\[?Str:\s*(\d+)\s+Int:\s*(\d+)\s+Wis:\s*(\d+)\s+Dex:\s*(\d+)\s+Con:\s*(\d+)\]?\s*]],
  function()
    newRoll(matches[2], matches[3], matches[4], matches[5], matches[6])
  end
)

-- Reuses PNP's own command vocabulary verbatim (set goal/roll stats/
-- reset roll), per CLAUDE.md's command-surface mandate. "set min <stat>
-- <n>" is new (see R.mins comment above) but matches "set goal <n>"'s
-- own shape so it doesn't feel like a bolted-on command.
MyDSL.Roller._aliases.setGoal = tempAlias([[^set goal (.*)$]], [[MyDSL.Roller.setGoal(matches[2])]])
MyDSL.Roller._aliases.setMin = tempAlias([[^set min (str|int|wis|dex|con) (.*)$]], [[MyDSL.Roller.setMin(matches[2], matches[3])]])
MyDSL.Roller._aliases.rollStats = tempAlias([[^roll stats$]], [[MyDSL.Roller.showStats()]])
MyDSL.Roller._aliases.resetRoll = tempAlias([[^reset roll$]], [[MyDSL.Roller.reset()]])

debugc("[MyDSL] Roller loaded.")
