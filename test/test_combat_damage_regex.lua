-- Regression test for the 2026-07-20 real live bug (Steven: "combat
-- remains in the main window, the readicates and others should be
-- going to combat with the condenser"). Root cause: MyDSL_DataLayer.lua's
-- combatDamage trigger regex required the line to end in one or more
-- literal "."/"!" characters, but DSL's real current combat text always
-- ends with a parenthesized (possibly decimal) damage number instead --
-- confirmed via direct PCRE-equivalent testing against the real captured
-- Olyndros session corpus that NOT ONE of these lines matched the old
-- pattern. Since nothing matched, parseCombatDamageLine() never ran for
-- ordinary swings, so combat never got summarized/gagged -- it all
-- leaked raw to the main console, matching the reported symptom exactly.
--
-- Mudlet's tempRegexTrigger uses PCRE (via Qt's QRegularExpression), which
-- this Lua-only harness can't execute directly -- the fixed pattern was
-- verified against every real corpus line via Python's `re` module
-- (near-identical PCRE semantics for the lookahead/lookbehind/alternation
-- constructs used here; see the fix's own comment in MyDSL_DataLayer.lua
-- for the full list). What CAN be verified here, and what has real
-- regression value, is the downstream parsing function this trigger
-- feeds -- confirming parseCombatDamageLine() correctly accumulates
-- round_data and doesn't choke when handed a "(340)"-shaped punct
-- argument, which it never received before this fix (the trigger always
-- passed a literal "."/"!"/"" previously).
--
-- Run: luajit test/test_combat_damage_regex.lua

package.path = package.path .. ";./test/?.lua"
require("mudlet_mock")

dofile("MyDSL_DataLayer.lua")
dofile("MyDSL_DataLayer_Combat.lua")  -- Combat capture split out here 2026-08-25

local failures = 0
local function check(name, cond)
  if cond then print("PASS: " .. name) else print("FAIL: " .. name); failures = failures + 1 end
end

MyDSL.State.combat = MyDSL.State.combat or {}
MyDSL.State.combat.round_data = {}
MyDSL.State.combat.active = {}

-- Real corpus line: "Your wrath do UNSPEAKABLE things to Tinker gnome
-- janitor (340)" -- the fixed regex's own capture groups for this line.
local ok1 = pcall(MyDSL.parseCombatDamageLine, "You", "wrath", "UNSPEAKABLE", "Tinker gnome janitor", "(340)")
check("parseCombatDamageLine doesn't crash on a real '(340)'-shaped punct arg", ok1)
check("a swing with a parenthesized-number punct still accumulates round_data",
  next(MyDSL.State.combat.round_data) ~= nil)

MyDSL.State.combat.round_data = {}

-- Real corpus line: "Beautiful white charger's bite wounds Tinker gnome
-- janitor (14.5)" -- a pet/mount-assisted swing (third-party attacker,
-- possessive 's, decimal damage number).
local ok2 = pcall(MyDSL.parseCombatDamageLine, "Beautiful white charger", "bite", "wound", "Tinker gnome janitor", "(14.5)")
check("a pet/mount-assisted swing with a decimal '(14.5)' punct doesn't crash", ok2)
check("the pet-assisted swing accumulates round_data too", next(MyDSL.State.combat.round_data) ~= nil)

MyDSL.State.combat.round_data = {}

-- Real corpus line: "Tinker gnome janitor's misses You (0)" -- a
-- third-party miss against the player.
local ok3 = pcall(MyDSL.parseCombatDamageLine, "Tinker gnome janitor", "", "miss", "You", "(0)")
check("a third-party miss with '(0)' punct doesn't crash", ok3)

-- The old literal-punctuation form (e.g. the charge skill's own
-- "<<< ERADICATES >>> ...instructor!") must still work unchanged.
MyDSL.State.combat.round_data = {}
local ok4 = pcall(MyDSL.parseCombatDamageLine, "You", "charge", "ERADICATE", "a gnome philosophy instructor", "!")
check("the old literal '.'/'!' punct form still works (not a regression)", ok4)
check("the literal-punct form still accumulates round_data", next(MyDSL.State.combat.round_data) ~= nil)

print("")
if failures == 0 then
  print("ALL PASS")
  os.exit(0)
else
  print(failures .. " FAILURE(S)")
  os.exit(1)
end
