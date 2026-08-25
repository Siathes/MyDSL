-- Structural test coverage for MyDSL_DataLayer_Combat.lua's
-- avoid/condition/death/end/proc parse functions and the
-- combatRoundFlush handler -- flagged as a real gap since slice 2 of
-- the MyDSL_DataLayer.lua split-by-domain refactor (2026-08-25): only
-- damage parsing had dedicated coverage, everything else in this file
-- had zero, both before and after the split. Confirmed via grep this
-- domain otherwise has no test file at all.
--
-- Every fixture line below is a real corpus string, confirmed via grep
-- against log/*.txt / log/*.html: "an office worker is DEAD!!"
-- (2026-07-01), "A rabbit hits the ground ... DEAD." (2026-07-03),
-- "student dodges your attack." (2026-07-01), "The quadrone has quite
-- a few wounds" (2026-06-30), "You flee from combat!" /
-- "You cannot escape from combat!!!" (2026-07-02).
--
-- Run: luajit test/test_datalayer_combat_lifecycle.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

-- mudlet_mock.lua's default registerAnonymousEventHandler is a no-op
-- (doesn't store the function) -- override to actually record handlers
-- so combatRoundFlush can be invoked manually below, same technique
-- test_identify_source_scoping.lua/test_mapper_gmcp_and_doorverb.lua
-- already established.
local eventHandlers = {}
function _G.registerAnonymousEventHandler(event, fn)
  eventHandlers[event] = eventHandlers[event] or {}
  table.insert(eventHandlers[event], fn)
  return #eventHandlers[event]
end
local function fireEvent(event, ...)
  for _, fn in ipairs(eventHandlers[event] or {}) do fn(event, ...) end
end

_G.matches = _G.matches or {}
MyDSL = MyDSL or {}
dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_DataLayer_Combat.lua")

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

local function resetCombat()
  MyDSL.State.combat = {
    active = {}, history = {}, history_max = 5, round_data = {},
    rage = { damage = 0, vamp = 0 },
    last_attacker = nil, last_target = nil, last_noun = nil,
    pending_condition = nil, last_updated = 0,
  }
  _G.__raisedEvents = {}
end

------------------------------------------------------------------------
-- parseCombatAvoidLine
------------------------------------------------------------------------
resetCombat()
-- Real corpus dodge line shape: "A student dodges your attack." ->
-- trigger captures (evader="A student", verb="dodge", attacker="your").
local ok1 = pcall(MyDSL.parseCombatAvoidLine, "A student", "dodge", "your")
check("parseCombatAvoidLine (3-arg dodge form) doesn't crash", ok1)
check("dodge creates an active entry for the evader",
  MyDSL.State.combat.active["student"] ~= nil)
check("dodge records an (evade) swing under the attacker key",
  MyDSL.State.combat.active["student"].by_attacker["you"]
    and MyDSL.State.combat.active["student"].by_attacker["you"]["(evade)"].swings == 1)

resetCombat()
-- 1-arg whole-line form (sense triggers).
local ok2 = pcall(MyDSL.parseCombatAvoidLine,
  "A gnome senses a gnome factory worker's attack coming and avoids its blow.")
check("parseCombatAvoidLine (1-arg sense form) doesn't crash", ok2)
check("sense-avoid creates an active entry keyed by the evader",
  MyDSL.State.combat.active["gnome"] ~= nil)

------------------------------------------------------------------------
-- parseCombatConditionLine
------------------------------------------------------------------------
resetCombat()
-- Real corpus line: "The quadrone has quite a few wounds"
local ok3 = pcall(MyDSL.parseCombatConditionLine, "The quadrone has quite a few wounds")
check("parseCombatConditionLine doesn't crash on a real corpus line", ok3)
check("pending_condition is set after a condition line",
  MyDSL.State.combat.pending_condition ~= nil)
check("pending_condition's screen text names the target and label",
  MyDSL.State.combat.pending_condition
    and MyDSL.State.combat.pending_condition.screen:find("quadrone", 1, true) ~= nil
    and MyDSL.State.combat.pending_condition.screen:find("quite a few", 1, true) ~= nil)

-- Condition updates an already-active target's target_condition field.
resetCombat()
MyDSL.State.combat.active["quadrone"] = {
  target_display = "The quadrone", target_condition = "unknown", by_attacker = {}, started_at = 0,
}
MyDSL.parseCombatConditionLine("The quadrone has quite a few wounds")
check("condition line updates an existing active entry's target_condition",
  MyDSL.State.combat.active["quadrone"].target_condition == "quite a few")

-- getTargetCondition() public API reflects the same update.
local label, pct, order = MyDSL.getTargetCondition("The quadrone")
check("getTargetCondition returns the label set by the condition line", label == "quite a few")
check("getTargetCondition returns the matching percent range", pct == "50-74%")
check("getTargetCondition returns a numeric ordering", type(order) == "number")

------------------------------------------------------------------------
-- parseCombatDeathLine
------------------------------------------------------------------------
resetCombat()
-- normalizeKey() strips the leading article, so "an office worker"
-- keys as "office worker" -- confirmed via its own gsub("^an%s+", "").
MyDSL.State.combat.active["office worker"] = {
  target_display = "an office worker", target_condition = "awful", by_attacker = {}, started_at = 0,
}
-- Real corpus line: "an office worker is DEAD!!"
local ok4 = pcall(MyDSL.parseCombatDeathLine, "an office worker is DEAD!!")
check("parseCombatDeathLine (\"is DEAD!!\" form) doesn't crash", ok4)
check("death clears the active entry (snapshotted to history)",
  MyDSL.State.combat.active["office worker"] == nil)
check("death moves the snapshot into history",
  #MyDSL.State.combat.history == 1 and MyDSL.State.combat.history[1].target_display == "an office worker")

local sawEnded, sawDied = false, false
for _, e in ipairs(_G.__raisedEvents) do
  if e.name == "MyDSL.combat.ended" then sawEnded = true end
  if e.name == "MyDSL.combat.died" then sawDied = true end
end
check("death raises MyDSL.combat.ended", sawEnded)
check("death raises MyDSL.combat.died", sawDied)

-- Second confirmed real death form: "A rabbit hits the ground ... DEAD."
resetCombat()
MyDSL.State.combat.active["rabbit"] = {
  target_display = "A rabbit", target_condition = "awful", by_attacker = {}, started_at = 0,
}
local ok5 = pcall(MyDSL.parseCombatDeathLine, "A rabbit hits the ground ... DEAD.")
check("parseCombatDeathLine (\"hits the ground ... DEAD.\" form) doesn't crash", ok5)
check("the ground-hit death form also clears the active entry",
  MyDSL.State.combat.active["rabbit"] == nil)

-- Death with no matching active entry: snapshotFight no-ops, but
-- MyDSL.combat.died must still raise (per this file's own comment: "our
-- own damage tracking might never have started... but the creature
-- still died").
resetCombat()
MyDSL.parseCombatDeathLine("a random gnat is DEAD!!")
local sawDiedNoActive = false
for _, e in ipairs(_G.__raisedEvents) do
  if e.name == "MyDSL.combat.died" then sawDiedNoActive = true end
end
check("death with no prior active entry still raises MyDSL.combat.died", sawDiedNoActive)

------------------------------------------------------------------------
-- parseCombatEndLine
------------------------------------------------------------------------
resetCombat()
MyDSL.State.combat.active["a gnoll"] = {
  target_display = "a gnoll", target_condition = "unknown",
  by_attacker = { you = {} }, started_at = 0,
}
-- Real corpus line: "You flee from combat!"
local ok6 = pcall(MyDSL.parseCombatEndLine, "You flee from combat!")
check("parseCombatEndLine (flee) doesn't crash", ok6)
check("fleeing clears the fight where you are the attacker",
  MyDSL.State.combat.active["a gnoll"] == nil)

resetCombat()
MyDSL.State.combat.active["a gnoll"] = {
  target_display = "a gnoll", target_condition = "unknown", by_attacker = {}, started_at = 0,
}
MyDSL.parseCombatEndLine("A gnoll rescues you!")
check("rescue clears the first active fight",
  MyDSL.State.combat.active["a gnoll"] == nil)

resetCombat()
MyDSL.State.combat.active["gnoll"] = {
  target_display = "a gnoll", target_condition = "unknown", by_attacker = {}, started_at = 0,
}
MyDSL.parseCombatEndLine("A gnoll has fled!")
check("mob fleeing clears its own active fight",
  MyDSL.State.combat.active["gnoll"] == nil)

-- Real corpus line, escape-fail: state must be unchanged (no active
-- entry touched, no crash).
resetCombat()
MyDSL.State.combat.active["a gnoll"] = {
  target_display = "a gnoll", target_condition = "unknown", by_attacker = {}, started_at = 0,
}
local ok7 = pcall(MyDSL.parseCombatEndLine, "You cannot escape from combat!!!")
check("parseCombatEndLine (escape fail) doesn't crash", ok7)
check("escape fail does NOT clear the active fight",
  MyDSL.State.combat.active["a gnoll"] ~= nil)

------------------------------------------------------------------------
-- parseCombatProcLine
------------------------------------------------------------------------
resetCombat()
-- Set up as if a damage line just fired (last_attacker/target/noun),
-- matching PNP's real attribution technique this function relies on.
MyDSL.State.combat.last_attacker = "you"
MyDSL.State.combat.last_target   = "a gnoll"
MyDSL.State.combat.last_noun     = "sword"
MyDSL.State.combat.active["a gnoll"] = {
  target_display = "a gnoll", target_condition = "unknown",
  by_attacker = { you = { sword = { swings = 1, hits = 1, misses = 0, score_total = 10.5, flags = {} } } },
  started_at = 0,
}
local ok8 = pcall(MyDSL.parseCombatProcLine, "C")
check("parseCombatProcLine doesn't crash", ok8)
check("proc attaches its flag to the last-attacker/noun entry",
  MyDSL.State.combat.active["a gnoll"].by_attacker.you.sword.flags["C"] == 1)

-- No prior damage line this round (last_attacker/target/noun all nil):
-- must no-op safely, not crash.
resetCombat()
local ok9 = pcall(MyDSL.parseCombatProcLine, "F")
check("parseCombatProcLine with no prior damage line doesn't crash", ok9)

-- Vampiric (H) proc from the player adds to rage.vamp.
resetCombat()
MyDSL.State.combat.last_attacker = "you"
MyDSL.State.combat.last_target   = "a gnoll"
MyDSL.State.combat.last_noun     = "bite"
MyDSL.parseCombatProcLine("H")
check("a vampiric proc from the player accumulates rage.vamp",
  MyDSL.State.combat.rage.vamp == 2.5)

-- Drowning/freeze false-positive guard (C proc code + exact line text).
-- Active entry pre-populated (same as the earlier real-proc case) so the
-- guard's effect is actually observable -- an empty active table would
-- make the "no C flag" check trivially true whether or not the guard
-- fired at all.
resetCombat()
_G.line = "The panic of drowning freezes you in your tracks!"
MyDSL.State.combat.last_attacker = "you"
MyDSL.State.combat.last_target   = "a gnoll"
MyDSL.State.combat.last_noun     = "bite"
MyDSL.State.combat.active["a gnoll"] = {
  target_display = "a gnoll", target_condition = "unknown",
  by_attacker = { you = { bite = { swings = 1, hits = 1, misses = 0, score_total = 10.5, flags = {} } } },
  started_at = 0,
}
MyDSL.parseCombatProcLine("C")
check("the drowning false-positive guard suppresses the Frost (C) proc",
  not MyDSL.State.combat.active["a gnoll"].by_attacker.you.bite.flags["C"])
_G.line = ""

------------------------------------------------------------------------
-- combatRoundFlush (registered on MyDSL.char.updated)
------------------------------------------------------------------------
resetCombat()
MyDSL.CombatView = MyDSL.CombatView or {}
MyDSL.CombatView.config = { summarize_damage = true }
MyDSL.State.char = MyDSL.State.char or {}
MyDSL.State.char.hp_raw = "42"
MyDSL.State.combat.round_data = {
  ["you→a gnoll→sword"] = { attacker = "you", target = "a gnoll", noun = "sword", score = 50.5, swings = 3, hits = 3 },
}
local okFlush = pcall(fireEvent, "MyDSL.char.updated")
check("combatRoundFlush doesn't crash when summarize_damage is on", okFlush)
check("combatRoundFlush clears round_data after flushing",
  next(MyDSL.State.combat.round_data) == nil)
local sawUpdated = false
for _, e in ipairs(_G.__raisedEvents) do
  if e.name == "MyDSL.combat.updated" then sawUpdated = true end
end
check("combatRoundFlush raises MyDSL.combat.updated", sawUpdated)

-- summarize_damage off: round_data still clears, but no crash, and
-- rage.damage should still be reset since hp_raw isn't "???".
resetCombat()
MyDSL.CombatView.config = { summarize_damage = false }
MyDSL.State.char.hp_raw = "42"
MyDSL.State.combat.round_data = {
  ["you→a gnoll→sword"] = { attacker = "you", target = "a gnoll", noun = "sword", score = 10.5, swings = 1, hits = 1 },
}
MyDSL.State.combat.rage.damage = 5
local okFlush2 = pcall(fireEvent, "MyDSL.char.updated")
check("combatRoundFlush doesn't crash with summarize_damage off", okFlush2)
check("combatRoundFlush still clears round_data with summarize_damage off",
  next(MyDSL.State.combat.round_data) == nil)
check("rage.damage resets to 0 once HP is visible again (not hidden)",
  MyDSL.State.combat.rage.damage == 0)

-- Hidden-HP rage event: hp_raw == "???" must raise MyDSL.combat_rage
-- instead of silently resetting the accumulated rage numbers.
resetCombat()
MyDSL.CombatView.config = { summarize_damage = false }
MyDSL.State.char.hp_raw = "???"
MyDSL.State.combat.rage.damage = 25
MyDSL.State.combat.rage.vamp = 5
fireEvent("MyDSL.char.updated")
local sawRageEvent = false
for _, e in ipairs(_G.__raisedEvents) do
  if e.name == "MyDSL.combat_rage" then sawRageEvent = true end
end
check("hidden HP raises MyDSL.combat_rage instead of resetting rage", sawRageEvent)
check("rage.damage is NOT reset while HP is hidden", MyDSL.State.combat.rage.damage == 25)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
