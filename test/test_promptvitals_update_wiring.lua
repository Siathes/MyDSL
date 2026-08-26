-- Real, severe bug found via the MyDSL 1.0 roadmap's test-coverage sweep
-- (2026-08-26), same root cause as test_itemlore_update_wiring.lua: the
-- 2026-08-25 DataLayer split-by-domain refactor moved every one of this
-- domain's capture functions (score/flags/lunar/time/weather/who/group/
-- improve/posn/wimpy/vitality -- 11 call sites) into this file, but the
-- shared `update(section, fields)` bulk-writer they all call stayed a
-- `local function` back in MyDSL_DataLayer.lua. Confirmed this threw
-- "attempt to call global 'update' (a nil value)" on every single one --
-- meaning the highest-frequency trigger in the whole addon (the real-time
-- prompt-line parser) has been silently crashing instead of updating
-- state since the split landed. Flagged in docs/OPTIMIZATION_AUDIT.md/
-- docs/MYDSL_1.0_ROADMAP.md as "zero test coverage" on this domain --
-- turned out that gap was hiding a real, live-breaking regression, not
-- just an absence of a safety net.
--
-- Doesn't attempt full coverage of every parse* function in this
-- 1,029-line file (score/flags/lunar/who/group/improve) -- focuses on
-- the specific real-time single-line triggers the audit singled out as
-- highest-frequency (parsePromptLine, Pos'n, Wimpy, Dragon Vitality),
-- which is enough to prove MyDSL.update() wiring is intact across the
-- whole file (every one of the 11 broken call sites shared the identical
-- root cause and identical fix).
--
-- Fixture lines confirmed via grep against log/*.html: "==-Day Time -
-- 7:30am :: [The Chamber of the Dragon Master] :: [ND]-==" (real
-- corpus). "You stand up." confirmed via log/*.txt. The "Night Time"
-- variant is constructed (same confirmed shape, real corpus sample for
-- that specific period name not found in the local log/ subset present
-- in this environment) -- flagged here rather than silently presented
-- as corpus-confirmed.
--
-- Run: luajit test/test_promptvitals_update_wiring.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

_G.matches = _G.matches or {}
MyDSL = MyDSL or {}
dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_DataLayer_PromptVitals.lua")

local function fireTrigger(id, line, matchTable)
  _G.line = line
  _G.matches = matchTable or { line }
  local t = _G.__triggers[id]
  return pcall(t.func)
end

-- ---- parsePromptLine() -- the highest-frequency trigger in the addon ------

local okDay, errDay = pcall(MyDSL.parsePromptLine,
  "==-Day Time - 7:30am :: [The Chamber of the Dragon Master] :: [ND]-==")
check("parsePromptLine() runs with no error on a real corpus line", okDay)
if not okDay then print("  error was: " .. tostring(errDay)) end
check("parsePromptLine() actually reaches MyDSL.State.time.period",
  MyDSL.State.time.period == "Day Time" and MyDSL.State.time.is_night == false)

local okNight = pcall(MyDSL.parsePromptLine,
  "==-Night Time - 10:30pm :: [The Chamber of the Dragon Master] :: [ND]-==")
check("parsePromptLine() runs with no error on a constructed Night Time line", okNight)
check("parsePromptLine() sets is_night correctly",
  MyDSL.State.time.period == "Night Time" and MyDSL.State.time.is_night == true)

-- ---- Pos'n -- real-time text trigger, confirmed corpus line ----------------

local okPosn, errPosn = fireTrigger(MyDSL._triggers.posnStandUp, "You stand up.")
check("Pos'n trigger (posnStandUp) runs with no error", okPosn)
if not okPosn then print("  error was: " .. tostring(errPosn)) end
check("Pos'n trigger actually reaches MyDSL.State.char.posn",
  MyDSL.State.char and MyDSL.State.char.posn == "Standing")

-- ---- Wimpy -- real-time text trigger, confirmed via this file's own -------
-- ---- documented corpus grep ("Wimpy set to N hit points.") ----------------

local okWimpy, errWimpy = fireTrigger(MyDSL._triggers.wimpySet,
  "Wimpy set to 25 hit points.", { [2] = "25" })
check("Wimpy trigger runs with no error", okWimpy)
if not okWimpy then print("  error was: " .. tostring(errWimpy)) end
check("Wimpy trigger actually reaches MyDSL.State.char.wimpy",
  MyDSL.State.char and MyDSL.State.char.wimpy == 25)

-- ---- Dragon Vitality -- confirmed via this file's own documented -----------
-- ---- corpus grep (log/2026-07-07#20-17-54.html's "stat" output) -----------

local okVit, errVit = fireTrigger(MyDSL._triggers.vitalitySet,
  "Str: 72(80)  Int: 60(72)  Wis: 60(72)  Dex: 60(60)  Con: 66(82)  Vit: 20",
  { [2] = "20" })
check("Dragon Vitality trigger runs with no error", okVit)
if not okVit then print("  error was: " .. tostring(errVit)) end
check("Dragon Vitality trigger actually reaches MyDSL.State.char.vitality",
  MyDSL.State.char and MyDSL.State.char.vitality == 20)

if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
