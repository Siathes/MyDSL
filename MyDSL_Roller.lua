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

MyDSL.Roller._triggers = MyDSL.Roller._triggers or {}
MyDSL.Roller._aliases  = MyDSL.Roller._aliases  or {}
local function deregister()
  for _, id in pairs(MyDSL.Roller._triggers) do pcall(killTrigger, id) end
  for _, id in pairs(MyDSL.Roller._aliases) do pcall(killAlias, id) end
  MyDSL.Roller._triggers = {}
  MyDSL.Roller._aliases = {}
end
deregister()

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

function R.reset()
  R.rolls = { str = {}, int = {}, wis = {}, dex = {}, con = {}, total = {} }
  echo("Roller stats reset.\n")
end

function R.showStats()
  local order = { "str", "int", "wis", "dex", "con", "total" }
  if #R.rolls.total == 0 then echo("No rolls recorded yet.\n"); return end
  echo(string.format("Rolls: %d\n", #R.rolls.total))
  echo(string.format("%-5s %5s %5s %5s %7s\n", "", "MIN", "MAX", "AVG", "STDEV"))
  for _, stat in ipairs(order) do
    local arr = R.rolls[stat]
    local min, max, sum = arr[1], arr[1], 0
    for _, v in ipairs(arr) do
      if v < min then min = v end
      if v > max then max = v end
      sum = sum + v
    end
    local avg = round(sum / #arr)
    echo(string.format("%-5s %5d %5d %5d %7.1f\n",
      stat:sub(1,1):upper() .. stat:sub(2), min, max, avg, stdev(arr)))
  end
end

local function newRoll(str, int, wis, dex, con)
  str, int, wis, dex, con = tonumber(str), tonumber(int), tonumber(wis), tonumber(dex), tonumber(con)
  if not (str and int and wis and dex and con) then return end
  local total = str + int + wis + dex + con

  table.insert(R.rolls.str, str)
  table.insert(R.rolls.int, int)
  table.insert(R.rolls.wis, wis)
  table.insert(R.rolls.dex, dex)
  table.insert(R.rolls.con, con)
  table.insert(R.rolls.total, total)

  cecho(string.format(
    "\n<cyan>[Roll Total: %d]<reset> Str=%d Int=%d Wis=%d Dex=%d Con=%d\n",
    total, str, int, wis, dex, con))

  if total < R.goal then
    cecho(string.format(
      "<red>[Reject]<reset> Total is %d, below goal %d. Sending n.\n",
      total, R.goal))
    -- Small delay so it answers after the Keep prompt appears (same
    -- timing as the native trigger).
    tempTimer(0.2, function() send("n") end)
  else
    cecho(string.format(
      "<green>[PAUSE]<reset> Total is %d, goal is %d or higher. Review manually!\n",
      total, R.goal))
    -- Attention sound/visual only -- never auto-sends "y". The decision
    -- to keep a roll always stays with the player.
    raiseEvent("onAlert", "Mudlet - DSL", "Rolled: " .. total, false, false)
  end
end

MyDSL.Roller._triggers.roll = tempRegexTrigger(
  [[\[?Str:\s*(\d+)\s+Int:\s*(\d+)\s+Wis:\s*(\d+)\s+Dex:\s*(\d+)\s+Con:\s*(\d+)\]?]],
  function()
    newRoll(matches[2], matches[3], matches[4], matches[5], matches[6])
  end
)

-- Reuses PNP's own command vocabulary verbatim (set goal/roll stats/
-- reset roll), per CLAUDE.md's command-surface mandate.
MyDSL.Roller._aliases.setGoal = tempAlias([[^set goal (.*)$]], [[MyDSL.Roller.setGoal(matches[2])]])
MyDSL.Roller._aliases.rollStats = tempAlias([[^roll stats$]], [[MyDSL.Roller.showStats()]])
MyDSL.Roller._aliases.resetRoll = tempAlias([[^reset roll$]], [[MyDSL.Roller.reset()]])

debugc("[MyDSL] Roller loaded.")
